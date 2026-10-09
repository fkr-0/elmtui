;;;; NILMSP Nano visual port using ElmTUI's maintained editor state machine.
;;;; The editor provides Unicode input, safe save-as and dirty-buffer dialogs.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((base (or *load-truename* *compile-file-truename*)))
    (unless (find-package :elmtui.examples.neon-kit)
      (load (merge-pathnames #P"neon-kit.lisp" base)))
    (unless (find-package :elmtui.examples.mini-text-editor)
      (load (merge-pathnames #P"mini-text-editor.lisp" base)))))
(uiop:define-package :elmtui.examples.neon-nano
  (:use :cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:state-ref)
  (:import-from :elmtui.examples.neon-kit
                #:control-p #:screen #:line #:clip #:numbered-line)
  (:export #:run-neon-nano #:nano-update #:nano-view #:initial-state))
(in-package :elmtui.examples.neon-nano)

(defvar *nano-path* nil)

(defun initial-state ()
  ;; The existing editor owns validation, loading and initial cursor state.
  (let ((elmtui.examples.mini-text-editor::*editor-path* *nano-path*))
    (elmtui.examples.mini-text-editor::%initial-state)))

(defun nano-update (message state)
  "Nano bindings take precedence unless a save/quit modal has keyboard focus."
  (cond
    ((state-ref state :modal)
     (elmtui.examples.mini-text-editor:editor-update message state))
    ((control-p message #\x 24)
     (elmtui.examples.mini-text-editor::%request-quit state))
    ((control-p message #\o 15)
     (cond ((state-ref state :saving) (elmtui.state.api:make-update-result))
           ((state-ref state :path)
            (elmtui.examples.mini-text-editor::%start-save
             state (state-ref state :path)))
           (t (elmtui.examples.mini-text-editor::%show-save-dialog state))))
    (t (elmtui.examples.mini-text-editor:editor-update message state))))

(defun %nano-row (state index)
  (let* ((lines (state-ref state :lines))
         (active-row (state-ref state :row))
         (top (state-ref state :top))
         (line-index (+ top index)))
    (if (< line-index (length lines))
        (let* ((text (aref lines line-index))
               (active (= line-index active-row))
               (display (substitute
                         #\▌ #\|
                         (elmtui.examples.mini-text-editor::%row-display
                          text (state-ref state :col) active))))
          (numbered-line line-index (if active
                                        (concatenate 'string "▸ " display)
                                        (concatenate 'string "  " display))
                         :width 54))
        (numbered-line line-index "~" :width 54))))

(defun nano-view (state)
  (let* ((lines (state-ref state :lines))
         (row (state-ref state :row))
         (col (state-ref state :col))
         (path (state-ref state :path))
         (modal (state-ref state :modal))
         (bytes (length (elmtui.examples.mini-text-editor:join-editor-lines lines))))
    (screen
     :neon-nano-root
     (append
      (list
       (line " NANO NL  /  MIDNIGHT EDITOR                     WORKSPACE 03  ● EDIT"
             :title)
       (line (format nil " ~A   UTF-8 MODE   ~D CHARS   ~A"
                     (clip (or path "UNTITLED BUFFER") 34)
                     bytes (if (state-ref state :dirty) "MODIFIED ◆" "SAVED ◇"))
             :accent)
       (line " ┌────┬────────────────────────────────────────────────────────┐"
             :border))
      (loop for n below 12
            unless (and modal (< 4 n 9))
              append (if (and modal (= n 4))
                         (elmtui.ui.widgets.modal-dialog:modal-dialog-view
                          modal :width 66)
                         (list (line (%nano-row state n)
                                     (if (= (+ n (state-ref state :top)) row)
                                         :signal :body)))))
      (list
       (line " └────┴────────────────────────────────────────────────────────┘"
             :border)
       (line (format nil " ~A"
                     (clip (or (state-ref state :status) "Ready") 68))
             (if (state-ref state :dirty) :accent :signal))
       (line (format nil " POS ~D    LINE ~D/~D    CHARS ~D"
                     col (1+ row) (length lines) bytes) :muted)
       (line " ^O SAVE    ^X EXIT    ARROWS MOVE    ENTER NEWLINE    ^S SAVE"
             :footer)))
     :height 19)))

(defapplication neon-nano-app
  :root-viewport-id :neon-nano-vp
  :root-component-dsl '(:root-viewport :id :neon-nano-vp
                        :anchor :below-cursor :width 74 :height 19
                        :blank-on-exit t :child-dsl-spec (:view nil))
  :initial-state-fn #'initial-state
  :update-fn #'nano-update
  :view-fn #'nano-view)

(defun run-neon-nano (&key (backend-type :terminal) path)
  (let ((*nano-path* (or path (uiop:getenv "ELMTUI_NANO_FILE"))))
    (run-neon-nano-app :platform backend-type)))
