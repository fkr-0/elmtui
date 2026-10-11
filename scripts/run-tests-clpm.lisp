(defvar *root* (uiop:pathname-directory-pathname (merge-pathnames "../" (uiop:pathname-directory-pathname *load-truename*))))

(require "bordeaux-threads")
(require "log4cl")

;; Reduce noisy redefinition warnings during test runs.
(declaim (sb-ext:muffle-conditions sb-kernel:redefinition-warning))

(defun elmtui-test-log-path ()
  "Return the log file path used for test-run application logging.

ELMTUI_TEST_LOG may override the default.  The default deliberately lives under
project-local test-output/ so log4cl application logs do not leak into the
process stdout/stderr stream consumed by automation and bridge servers."
  (let ((override (uiop:getenv "ELMTUI_TEST_LOG")))
    (if (and override (plusp (length override)))
        (uiop:parse-native-namestring override)
        (merge-pathnames #P"test-output/elmtui-tests.log" *root*))))

(defun configure-elmtui-test-logging ()
  "Route log4cl output away from stdout/stderr before loading/running tests."
  (let ((log-path (elmtui-test-log-path)))
    (ensure-directories-exist log-path)
    (log4cl:remove-all-appenders log4cl:*root-logger*)
    (log4cl:add-appender log4cl:*root-logger*
                         (make-instance 'log4cl:file-appender
                                        :file (namestring log-path)))
    (log4cl:set-log-level log4cl:*root-logger* :warn)
    log-path))

(defun run-elmtui-tests-for-process-status ()
  "Load and run elmtui-tests, returning T only when the suite reports success."
  (handler-case
      (progn
        (configure-elmtui-test-logging)
        (handler-bind ((sb-kernel:redefinition-warning #'muffle-warning))
          (asdf:load-system "elmtui-tests"))
        (uiop:symbol-call :elmtui.tests :run-all-elmtui-tests))
    (error (condition)
      (format *error-output*
              "~&[FATAL] elmtui test runner failed before producing a clean test result: ~A~%"
              condition)
      nil)))

(uiop:quit (if (run-elmtui-tests-for-process-status) 0 1))
