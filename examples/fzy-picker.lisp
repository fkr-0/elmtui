;;;===============================================================
;;; File: examples/fzy-picker.lisp
;;;
;;; Description: A clean fzy/fzf-like picker using cl-fzy and ElmTUI
;;; Demonstrates fuzzy finding, keyboard navigation, and state management
;;;===============================================================

(uiop:define-package :elmtui.examples.fzy-picker
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.state.msg #:msg-type #:msg-data)
  (:import-from :elmtui.core.event-types
    #:key-event #:key-event-key #:key-event-char #:key-event-modifiers)
  (:import-from :cl-fzy
    #:choices #:options #:choices-init #:choices-add #:choices-search
    #:choices-available #:choices-get)
  (:export #:run-fzy-picker #:run-fzy-picker-with-stdin #:main))

(in-package :elmtui.examples.fzy-picker)

;;;===============================================================
;;; Parameters and Helpers
;;;===============================================================

(defparameter *fzy-input-lines* nil
  "Captured stdin lines for the picker.")

(defparameter *picker-height* 10
  "Default height of the picker display.")

(defun read-stdin-lines ()
  "Read all lines from standard input until EOF."
  (let ((lines '()))
    (loop for line = (read-line *standard-input* nil nil)
      while line do (push line lines))
    (nreverse lines)))

(defun safe-print-selected (s)
  "Safely print the selected item to stdout."
  (when s
    (format t "~a~%" s)
    (finish-output)))

(defun piclamp (x lo hi)
  "Clamp X between LO and HI (inclusive)."
  (max lo (min x hi)))

;;;===============================================================
;;; State Initialization
;;;===============================================================

(defun initial-state ()
  "Create the initial state for the fzy picker."
  (let* ((opts (make-instance 'options))
          (chs (make-instance 'choices)))
    (choices-init chs opts)
    ;; Add lines from the captured stdin list
    (dolist (l *fzy-input-lines*)
      (choices-add chs l))
    (choices-search chs "")
    ;; Return initial state plist
    (list :choices chs
      :query ""
      :height *picker-height*
      :selected-index (if (> (choices-available chs) 0) 0 nil)
      :should-quit nil)))

;;;===============================================================
;;; Update Function
;;;===============================================================

(defun fzy-update (message app-state)
  "Handle application messages following Elm architecture."
  (let* ((chs (state-ref app-state :choices))
          (height (state-ref app-state :height *picker-height*))
          (query (state-ref app-state :query ""))
          (avail (choices-available chs)))

    (labels
      ;; Helper: Create quit result
      ((quit-result ()
         (make-update-result :patches '((:should-quit t))))

        ;; Helper: Extract key-event info from either a struct or a keyevent app message.
        (extract-key-event (msg)
          (cond
            ((typep msg 'key-event)
              (values (key-event-key msg)
                (key-event-char msg)
                (key-event-modifiers msg)))
            ((and (listp msg) (eq (msg-type msg) :keyevent))
              (let ((evt (msg-data msg :event)))
                (if (typep evt 'key-event)
                  (values (key-event-key evt)
                    (key-event-char evt)
                    (key-event-modifiers evt))
                  (values (msg-data msg :key)
                    (msg-data msg :char)
                    (msg-data msg :modifiers)))))
            (t (values nil nil nil))))

        ;; Helper: Handle Enter key - print selection and quit
        (handle-enter ()
          (let* ((sel (state-ref app-state :selected-index))
                  (picked (and sel (choices-get chs sel))))
            (safe-print-selected picked)
            (quit-result)))

        ;; Helper: Update query and recompute search
        (update-query (new-query)
          (choices-search chs new-query)
          (let* ((new-avail (choices-available chs))
                  (new-sel (if (> new-avail 0) 0 nil)))
            (make-update-result
              :patches `((:query ,new-query)
                          (:selected-index ,new-sel)))))

        ;; Helper: Navigate selection
        (navigate (delta)
          (let* ((sel (or (state-ref app-state :selected-index) 0))
                  (visible (min avail height))
                  (new-sel (if (> visible 0)
                             (piclamp (+ sel delta) 0 (1- visible))
                             nil)))
            (make-update-result
              :patches `((:selected-index ,new-sel))))))

      ;; Message dispatch
      (cond
        ((or (typep message 'key-event)
           (and (listp message) (eq (msg-type message) :keyevent)))
          (multiple-value-bind (key ch modifiers)
            (extract-key-event message)
            (cond
              ((or (eq key :escape)
                 (and (eq key #\c) (member :ctrl modifiers))
                 (eq key :q))
                (quit-result))
              ((member key '(:enter :return) :test #'eq)
                (handle-enter))
              ((member key '(:up :down :k :j) :test #'eq)
                (let ((delta (case key
                               ((:up :k) -1)
                               ((:down :j) 1)
                               (t 0))))
                  (navigate delta)))
              ((member key '(:backspace :delete) :test #'eq)
                (let* ((current-len (length query))
                        (new-query (if (> current-len 0)
                                     (subseq query 0 (1- current-len))
                                     query)))
                  (update-query new-query)))
              ((and ch (>= (char-code ch) 32))
                (let ((new-query (concatenate 'string query (string ch))))
                  (update-query new-query)))
              (t (make-update-result)))))

        ;; Default: no-op
        (t (make-update-result))))))

;;;===============================================================
;;; View Function
;;;===============================================================

(defun fzy-view (app-state)
  "Render the fzy picker interface."
  (let* ((chs (state-ref app-state :choices))
          (query (state-ref app-state :query ""))
          (height (state-ref app-state :height *picker-height*))
          (avail (choices-available chs))
          (visible (min avail height))
          (sel (or (state-ref app-state :selected-index) 0)))

    `(:container
       :id :fzy-widget
       :style (:display :flex
                :flex-direction :column
                :width :auto
                :height :auto
                :min-width 20
                :min-height 3
                :border t
                :border-style :solid
                :border-width 1)
       :children
       ((:text
          :id :prompt
          :content ,(format nil "> ~a" query)
          :style (:bold t))
         ,@(loop for i from 0 below visible
             for it = (choices-get chs i)
             for selected = (= i sel)
             collect `(:text
                        :id ,(intern (format nil "item-~d" i) :keyword)
                        :content ,(format nil "~a~a"
                                    (if selected "> "   " ")
                                    it)
                        :style ,(when selected '(:bold t))))))))

;;;===============================================================
;;; Application Definition
;;;===============================================================

(defapplication fzy-picker
  :root-viewport-id :fzy-root
  :initial-state-plist (initial-state)
  :root-component-dsl '(:root-viewport :id :fzy-root :anchor :below-cursor
                         :height 12 :child-dsl-spec (:view nil))
  :update-fn 'fzy-update
  :view-fn 'fzy-view)

;;;===============================================================
;;; Entry Points
;;;===============================================================

(defun run-fzy-picker-with-stdin (&rest args)
  "Run the fzy picker application."
  (let* ((is-tty (ignore-errors
                   (let ((pkg (find-package :sb-posix)))
                     (when pkg
                       (let ((fn (find-symbol "ISATTY" pkg)))
                         (and fn (fboundp fn) (funcall fn 0)))))))
          (lines (if is-tty '() (read-stdin-lines))))
    (let ((*fzy-input-lines* lines))
      (apply #'run-fzy-picker args))))

(defun main ()
  "Main entry point for the fzy picker."
  (run-fzy-picker-with-stdin :platform :tty))

;; To run from REPL:
;; (elmtui.examples.fzy-picker:run-fzy-picker)
;;
;; To run with stdin input:
;; echo -e "apple\nbanana\ncherry" | sbcl --load run-clpm.lisp --eval '(elmtui.examples.fzy-picker:main)'
