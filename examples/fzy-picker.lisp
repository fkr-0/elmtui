;;; examples/fzy-picker.lisp
;;; Minimal fzy/fzf-like picker using cl-fzy and ElmTUI

(uiop:define-package :elmtui.examples.fzy-picker
  (:use :cl)
  (:import-from :log4cl #:log-info #:log-warn)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char #:key-event-modifiers)
  (:import-from :cl-fzy
                #:choices #:options #:choices-init #:choices-add #:choices-search
                #:choices-available #:choices-get)
  (:import-from :elmtui.keymaps #:keymap! #:add-keybinding)
  (:export #:run))

(in-package :elmtui.examples.fzy-picker)

(defparameter *fzy-input-lines* nil)

(defun read-stdin-lines ()
  (let ((lines '()))
    (loop for line = (read-line *standard-input* nil nil)
          while line do (push line lines))
    (nreverse lines)))

(defun safe-print-selected (s)
  (when s
    (format t "~a~%" s)
    (finish-output)))

(defun initial-state ()
  (let* ((opts (make-instance 'options))
         (chs  (make-instance 'choices))
         (height 10))
    (choices-init chs opts)
    ;; Add lines from the captured stdin list
    (dolist (l *fzy-input-lines*)
      (choices-add chs l))
    (choices-search chs "")
    (list :choices chs
          :query   ""
          :height  height
          :selected-index (if (> (choices-available chs) 0) 0 nil))))

(defun clamp (x lo hi)
  (max lo (min x hi)))

(defun recompute-after-query (state)
  (let* ((chs (getf state :choices))
         (q   (getf state :query "")))
    (choices-search chs q)
    (let* ((avail (choices-available chs))
           (visible (min avail (getf state :height 10)))
           (sel (if (> visible 0) 0 nil)))
      ;; Return a proper plist by copying state and updating selected-index
      (copy-list (list* :selected-index sel (remove-property :selected-index state))))))

(defun remove-property (key plist)
  "Remove a property from a plist, returning a new plist."
  (loop for (k v) on plist by #'cddr
        unless (eq k key)
        collect k and collect v))

(defun fzy-update (message app-state)
  (let* ((chs (state-ref app-state :choices))
         (height (state-ref app-state :height 10)))
    (cond
      ;; Quit on ESC
      ((and (typep message 'key-event)
            (eq (key-event-key message) :escape))
       (make-update-result :patches '((:should-quit t))))

      ;; Handle Enter: print selected item and quit
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:enter :return) :test #'eq))
       (let* ((sel (state-ref app-state :selected-index))
              (picked (and sel (choices-get chs sel))))
         (safe-print-selected picked)
         (make-update-result :patches '((:should-quit t)))))

      ;; Navigation (up/down or j/k)
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:up :down :k :j) :test #'eq))
       (let* ((avail (choices-available chs))
              (visible (min avail height))
              (sel (or (state-ref app-state :selected-index) 0))
              (delta (case (key-event-key message)
                       ((:up :k) -1)
                       ((:down :j) 1)
                       (t 0)))
              (new-sel (if (> visible 0)
                           (clamp (+ sel delta) 0 (1- visible))
                           nil)))
         (make-update-result :patches `((:selected-index ,new-sel)))))

      ;; Quit commands
      ((and (typep message 'key-event)
            (or (eq (key-event-key message) :escape)
                (and (eq (key-event-key message) #\c)
                     (member :ctrl (key-event-modifiers message)))
                (eq (key-event-key message) #\q)))
       (make-update-result :patches '((:should-quit t))))

      ;; Enter key - select current item
      ((and (typep message 'key-event)
            (eq (key-event-key message) :enter))
       (let* ((chs (state-ref app-state :choices))
              (sel (state-ref app-state :selected-index))
              (avail (choices-available chs)))
         (if (and sel (< sel avail))
             ;; Print selected item and quit
             (progn
               (format t "~A~%" (choices-get chs sel))
               (make-update-result :patches '((:should-quit t))))
             ;; No selection available
             (make-update-result))))

      ;; Backspace
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:backspace :delete) :test #'eq))
       (let* ((q (state-ref app-state :query ""))
              (new-q (if (plusp (length q)) (subseq q 0 (1- (length q))) q))
              (chs (state-ref app-state :choices)))
         ;; Update search with new query
         (choices-search chs new-q)
         (let ((avail (choices-available chs)))
           (make-update-result :patches `((:query ,new-q)
                                          (:selected-index ,(if (> avail 0) 0 nil)))))))

      ;; Printable characters append to query
      ((typep message 'key-event)
       (let ((ch (key-event-char message)))
         (if (and ch (>= (char-code ch) 32))
             (let* ((current-q (state-ref app-state :query ""))
                    (new-q (concatenate 'string current-q (string ch))))
               ;; Recompute search after query change
               (let ((chs (state-ref app-state :choices)))
                 (choices-search chs new-q)
                 (let ((avail (choices-available chs)))
                   (make-update-result :patches `((:query ,new-q)
                                                  (:selected-index ,(if (> avail 0) 0 nil)))))))
             (make-update-result))))

      (t (make-update-result)))))

(defun fzy-view (app-state &key root-id)
  (declare (ignore root-id))
  (let* ((chs (state-ref app-state :choices))
         (q (state-ref app-state :query ""))
         (height (state-ref app-state :height 10))
         (avail (choices-available chs))
         (visible (min avail height))
         (sel (or (state-ref app-state :selected-index) 0)))
    `(:container
      :id :fzy-widget
      :style (:display :flex :flex-direction :column :width :auto :height :auto
              :min-width 20 :min-height 3
              :border t :border-style :solid :border-width 1)
      :children
      ((:text :content ,(format nil "> ~a" q))
       ,@(loop for i from 0 below visible
               for it = (choices-get chs i)
               for selected = (= i sel)
               collect `(:text :content ,(if selected (format nil "> ~a" it)
                                             (format nil "  ~a" it))
                               :props (list :selected selected)))))))

(defapplication fzy-picker
  :root-viewport-id :fzy-root
  :initial-state-plist (let ((init-state (initial-state)))
                         (list :choices (getf init-state :choices)
                               :query (getf init-state :query)
                               :height (getf init-state :height)
                               :selected-index (getf init-state :selected-index)
                               :should-quit nil))
  :root-component-dsl '(:container :id :fzy-widget)
  :update-fn 'fzy-update
  :view-fn 'fzy-view)

(defun run ()
  (let* ((is-tty (ignore-errors
                  (let ((pkg (find-package :sb-posix)))
                    (when pkg
                      (let ((fn (find-symbol "ISATTY" pkg)))
                        (and fn (fboundp fn) (funcall fn 0)))))))
         (lines (if is-tty '() (read-stdin-lines))))
    (let ((*fzy-input-lines* lines))
      (RUN-FZY-PICKER :platform :terminal))))

(defun run-mini-fzy-picker ()
  "Run the fzy-picker example."
  (run))
