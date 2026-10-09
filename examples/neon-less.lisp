;;;; Read-only document viewer, ported from nilmsp-tea/poc-apps/less.nl.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((base (or *load-truename* *compile-file-truename*)))
    (unless (find-package :elmtui.examples.neon-kit)
      (load (merge-pathnames #P"neon-kit.lisp" base)))
    (unless (find-package :elmtui.examples.mini-text-editor)
      (load (merge-pathnames #P"mini-text-editor.lisp" base)))))
(uiop:define-package :elmtui.examples.neon-less
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.examples.neon-kit
                #:pressed-p #:quit-message-p #:screen #:line #:clip
                #:numbered-line)
  (:export #:run-neon-less #:less-update #:less-view #:initial-state))
(in-package :elmtui.examples.neon-less)

(defconstant +page-size+ 16)
(defvar *less-path* nil)

(defun %demo-document ()
  (format nil "LESS NL demo. Supply a text filename to open.~%~{~A~%~}"
          (loop for i from 1 to 40
                collect (format nil "Sample paragraph line ~D" i))))

(defun initial-state ()
  (let* ((path *less-path*)
         (content (if path
                      (uiop:read-file-string path :external-format :utf-8)
                      (%demo-document))))
    (list :lines (elmtui.examples.mini-text-editor:split-editor-lines content)
          :path path :scroll 0 :should-quit nil)))

(defun %last-top (state)
  (max 0 (- (length (state-ref state :lines)) +page-size+)))

(defun %scroll (state delta)
  (let* ((old (state-ref state :scroll))
         (new (max 0 (min (%last-top state) (+ old delta)))))
    (if (= old new)
        (make-update-result)
        (make-update-result :patches `(((:scroll) ,new))))))

(defun less-update (message state)
  (cond
    ((or (quit-message-p message)
         (pressed-p message :char #\q :keys '(:escape)))
     (make-update-result :patches '(((:should-quit) t))))
    ((pressed-p message :char #\j :keys '(:down :arrow-down))
     (%scroll state 1))
    ((pressed-p message :char #\k :keys '(:up :arrow-up))
     (%scroll state -1))
    ((or (pressed-p message :char #\f :keys '(:page-down :pagedown))
         (pressed-p message :char #\Space))
     (%scroll state +page-size+))
    ((pressed-p message :char #\b :keys '(:page-up :pageup))
     (%scroll state (- +page-size+)))
    ((pressed-p message :char #\g :keys '(:home))
     (%scroll state (- (state-ref state :scroll))))
    ((pressed-p message :char #\G :keys '(:end))
     (%scroll state (%last-top state)))
    (t (make-update-result))))

(defun less-view (state)
  (let* ((lines (state-ref state :lines))
         (total (length lines))
         (top (state-ref state :scroll))
         (bottom (min total (+ top +page-size+))))
    (screen
     :neon-less-root
     (append
      (list
       (line " LESS NL  /  DEEP FILE VIEWER                   READER 04  ● LIVE"
             :title)
       (line (format nil " ~A   LINES ~D   VIEWPORT ~D–~D   READ ONLY"
                     (clip (or (state-ref state :path) "DEMO DOCUMENT") 24)
                     total (1+ top) bottom)
             :accent)
       (line " ┌────┬────────────────────────────────────────────────────────┐"
             :border))
      (loop for n below +page-size+
            for i = (+ top n)
            collect (line
                     (numbered-line i (if (< i total) (aref lines i) "~")
                                    :width 54)
                     (if (= n 0) :signal :body)))
      (list
       (line " └────┴────────────────────────────────────────────────────────┘"
             :border)
       (line (format nil " LINE ~D/~D    ◆  ~A"
                     (1+ top) total
                     (cond ((= top 0) "TOP OF FILE")
                           ((>= top (%last-top state)) "END OF FILE")
                           (t "SCROLLING")))
             :signal)
       (line " J/K  SCROLL   F/SPACE  PAGE   B  BACK   G  TOP   G(SHIFT) END"
             :footer)
       (line " Q  QUIT      ARROWS / PAGE KEYS ALSO SUPPORTED" :muted)))
     :height 24)))

(defapplication neon-less-app
  :root-viewport-id :neon-less-vp
  :root-component-dsl '(:root-viewport :id :neon-less-vp
                        :anchor :below-cursor :width 74 :height 24
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'less-update
  :view-fn #'less-view)

(defun run-neon-less (&key (backend-type :terminal) path)
  "With no PATH and no ELMTUI_LESS_FILE, show a 40-line demo document."
  (let ((*less-path* (or path (uiop:getenv "ELMTUI_LESS_FILE"))))
    (run-neon-less-app :platform backend-type)))
