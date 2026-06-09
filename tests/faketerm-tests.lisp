;;;; Faketerm backend contract tests

(in-package :elmtui.tests)

(in-suite elmtui-test)

(defun %faketerm-symbol (name)
  (multiple-value-bind (symbol status)
      (find-symbol name :elmtui.backend.faketerm)
    (and status symbol)))

(defun %call-faketerm-symbol (name &rest args)
  (let ((symbol (%faketerm-symbol name)))
    (unless (and symbol (fboundp symbol))
      (error "Missing faketerm API ~A" name))
    (apply symbol args)))

(test faketerm-screen-lines-snapshot-api
  "Faketerm exposes deterministic screen lines for non-interactive tests."
  (let* ((path (merge-pathnames
                (make-pathname :name (format nil "faketerm-snapshot-~A" (gensym))
                               :type "log")
                (uiop:temporary-directory)))
         (backend (elmtui.platform.api:initialize-backend
                   :faketerm :filepath path :width 8 :height 3)))
    (unwind-protect
         (progn
           (elmtui.platform.api:draw-text-at backend nil 1 2 "Hi"
                                             :style '(:fg :green :bg :black))
           (let ((lines (%call-faketerm-symbol "FAKETERM-SCREEN-LINES" backend)))
             (is (equal lines '("        " "  Hi    " "        ")))))
      (ignore-errors (elmtui.platform.api:shutdown-backend backend))
      (ignore-errors (delete-file path)))))

(test faketerm-clear-screen-uses-terminal-height
  "Clearing a non-square faketerm screen uses terminal height, not width."
  (let* ((path (merge-pathnames
                (make-pathname :name (format nil "faketerm-clear-~A" (gensym))
                               :type "log")
                (uiop:temporary-directory)))
         (backend (elmtui.platform.api:initialize-backend
                   :faketerm :filepath path :width 6 :height 2)))
    (unwind-protect
         (progn
           (elmtui.platform.api:draw-text-at backend nil 1 0 "Bottom"
                                             :style '(:fg :yellow :bg :black))
           (elmtui.platform.api:clear-screen backend)
           (let ((lines (%call-faketerm-symbol "FAKETERM-SCREEN-LINES" backend)))
             (is (equal lines '("      " "      ")))))
      (ignore-errors (elmtui.platform.api:shutdown-backend backend))
      (ignore-errors (delete-file path)))))

(test faketerm-enqueues-input-events-after-initialization
  "Faketerm exposes deterministic post-initialization input injection for harness tests."
  (let* ((path (merge-pathnames
                (make-pathname :name (format nil "faketerm-input-~A" (gensym))
                               :type "log")
                (uiop:temporary-directory)))
         (backend (elmtui.platform.api:initialize-backend
                   :faketerm :filepath path :width 10 :height 2
                   :initial-input '((:key :initial)))))
    (unwind-protect
         (progn
           (%call-faketerm-symbol "FAKETERM-ENQUEUE-INPUT" backend '(:key :a))
           (%call-faketerm-symbol "FAKETERM-ENQUEUE-INPUT" backend '(:key :b))
           (is (equal (elmtui.platform.api:peek-input-event backend) '(:key :initial)))
           (is (equal (elmtui.platform.api:peek-input-event backend) '(:key :initial)))
           (is (equal (elmtui.platform.api:poll-input-event backend) '(:key :initial)))
           (is (equal (elmtui.platform.api:poll-input-event backend) '(:key :a)))
           (is (equal (elmtui.platform.api:poll-input-event backend) '(:key :b)))
           (is (null (elmtui.platform.api:poll-input-event backend))))
      (ignore-errors (elmtui.platform.api:shutdown-backend backend))
      (ignore-errors (delete-file path)))))

(test faketerm-log-lines-snapshot-api
  "Faketerm exposes deterministic operation log lines for command-sequence assertions."
  (let* ((path (merge-pathnames
                (make-pathname :name (format nil "faketerm-log-lines-~A" (gensym))
                               :type "log")
                (uiop:temporary-directory)))
         (backend (elmtui.platform.api:initialize-backend
                   :faketerm :filepath path :width 5 :height 2)))
    (unwind-protect
         (progn
           (elmtui.platform.api:draw-text-at backend nil 0 0 "Yo" :style '(:fg :blue))
           (elmtui.platform.api:flush-output backend)
           (let ((lines (%call-faketerm-symbol "FAKETERM-LOG-LINES" backend)))
             (is (some (lambda (line) (search "Faketerm Initialized" line)) lines))
             (is (some (lambda (line) (search "DRAW_TEXT_AT" line)) lines))
             (is (every (lambda (line) (not (search "<INFO>" line))) lines))))
      (ignore-errors (elmtui.platform.api:shutdown-backend backend))
      (ignore-errors (delete-file path)))))

