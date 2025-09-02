;;; examples/fzy-picker.lisp
;;; Minimal fzy/fzf-like picker using cl-fzy and ElmTUI

(uiop:define-package :elmtui.examples.fzy-picker
  (:use :cl)
  (:import-from :log4cl #:log-info #:log-warn)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char)
  (:import-from :cl-fzy
                #:choices #:options #:choices-init #:choices-add #:choices-search
                #:choices-available)
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
      (list* :selected-index sel state))))

(defun fzy-update (message app-state)
  (let* ((state-pl (state-ref app-state :fzy-state))
         (chs (getf state-pl :choices))
         (height (getf state-pl :height 10)))
    (cond
      ;; Quit on ESC
      ((and (typep message 'key-event)
            (eq (key-event-key message) :escape))
       (make-update-result :patches '(((:should-quit) t))))

      ;; Handle Enter: print selected item and quit
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:enter :return) :test #'eq))
       (let* ((sel (getf state-pl :selected-index))
              (picked (and sel (cl-fzy::choices-get chs sel))))
         (safe-print-selected picked)
         (make-update-result :patches '(((:should-quit) t)))))

      ;; Navigation (up/down or j/k)
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:up :down :k :j) :test #'eq))
       (let* ((avail (choices-available chs))
              (visible (min avail height))
              (sel (or (getf state-pl :selected-index) 0))
              (delta (case (key-event-key message)
                       ((:up :k) -1)
                       ((:down :j) 1)
                       (t 0)))
              (new-sel (if (> visible 0)
                           (clamp (+ sel delta) 0 (1- visible))
                           nil)))
         (make-update-result :patches `(((:fzy-state) ,(list* :selected-index new-sel state-pl))))))

      ;; Backspace
      ((and (typep message 'key-event)
            (member (key-event-key message) '(:backspace :delete) :test #'eq))
       (let* ((q (getf state-pl :query ""))
              (new-q (if (plusp (length q)) (subseq q 0 (1- (length q))) q))
              (new-state (list* :query new-q state-pl)))
         (make-update-result :patches `(((:fzy-state) ,(recompute-after-query new-state))))))

      ;; Printable characters append to query
      ((typep message 'key-event)
       (let ((ch (key-event-char message)))
         (if (and ch (>= (char-code ch) 32))
             (let* ((new-q (concatenate 'string (getf state-pl :query "") (string ch)))
                    (new-state (list* :query new-q state-pl)))
               (make-update-result :patches `(((:fzy-state) ,(recompute-after-query new-state)))))
             (make-update-result))))

      (t (make-update-result)))))

(defun fzy-view (app-state &key root-id)
  (declare (ignore root-id))
  (let* ((st (state-ref app-state :fzy-state))
         (chs (getf st :choices))
         (q (getf st :query ""))
         (height (getf st :height 10))
         (avail (choices-available chs))
         (visible (min avail height))
         (sel (or (getf st :selected-index) 0)))
    `(:container
      :id :fzy-root
      :style (:display :flex :flex-direction :column :width :auto :height :auto
              :min-width 20 :min-height 3)
      :children
      ((:text :content ,(format nil "> ~a" q))
       ,@(loop for i from 0 below visible
               for it = (cl-fzy::choices-get chs i)
               for selected = (= i sel)
               collect `(:text :content ,(if selected (format nil "> ~a" it)
                                             (format nil "  ~a" it))
                               :props (list :selected selected)))))))

(defapplication fzy-picker
  :root-viewport-id :fzy-root
  :root-component-dsl '(:container :id :fzy-root)
  :initial-state-fn #'(lambda () (list :fzy-state (initial-state)))
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
      (run-fzy-picker :platform :terminal))))
