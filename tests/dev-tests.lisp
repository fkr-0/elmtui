
(uiop/package:define-package :elmtui.dev.tests (:use :cl :fiveam)
                             (:import-from :elmtui.dev #:buffer->string
                              #:runtime-snapshot #:format-runtime-snapshot
                              #:format-element-tree)
                             (:import-from
                              :elmtui.platform.backend.common.virtual-buffer
                              #:make-virtual-buffer #:set-buffer-cell-at)
                             (:import-from :elmtui.view.base-elements
                              #:container-element #:text-element)
                             (:export #:run-dev-tests))
(in-package :elmtui.dev.tests)
(def-suite dev-test-suite :description
 "Tests for maintained ElmTUI developer introspection utilities.")
(in-suite dev-test-suite)
(test buffer-to-string-is-pure
 (let ((buffer (make-virtual-buffer 3 2)) (captured nil) (result nil))
   (set-buffer-cell-at buffer 0 0 #\A nil)
   (set-buffer-cell-at buffer 1 2 #\B nil)
   (setf captured
           (with-output-to-string (out)
             (let ((*standard-output* out))
               (setf result (buffer->string buffer)))))
   (is (string= captured ""))
   (is (string= result (format nil "A  ~%  B~%")))))
(test runtime-snapshot-has-stable-shape
 (let ((snapshot (runtime-snapshot)))
   (is (listp (getf snapshot :event-loop)))
   (is (integerp (getf snapshot :queue-length)))
   (is (integerp (getf snapshot :subscription-count)))
   (is (listp (getf snapshot :topics)))
   (is (typep (getf snapshot :application-state-present-p) 'boolean))
   (is (search "ElmTUI runtime snapshot" (format-runtime-snapshot snapshot)))))
(test element-tree-format-shows-structure
 (let* ((child (make-instance 'text-element :id :label :content "hello"))
        (root
         (make-instance 'container-element :id :root :children (list child)))
        (output (format-element-tree root)))
   (is (search ":CONTAINER" output))
   (is (search "#ROOT" output))
   (is (search ":TEXT" output))
   (is (search "#LABEL" output))))

(defun %maintained-runtime-lisp-files ()
  "Return runtime Lisp files, excluding developer/tool-only source trees."
  (let ((src-root (merge-pathnames #P"src/" (asdf:system-source-directory "elmtui"))))
    (labels ((walk (directory)
               (append (uiop:directory-files directory #P"*.lisp")
                       (mapcan #'walk
                               (remove-if
                                (lambda (subdir)
                                  (member (string-downcase
                                           (car (last (pathname-directory subdir))))
                                          '("dev" "tools" "workbench")
                                          :test #'string=))
                                (uiop:subdirectories directory))))))
      (walk src-root))))

(defun %active-ignore-errors-lines (pathname)
  "Return non-comment source lines that invoke IGNORE-ERRORS in PATHNAME."
  (with-open-file (stream pathname :direction :input)
    (loop for line = (read-line stream nil nil)
          for line-number from 1
          while line
          for trimmed = (string-left-trim '(#\Space #\Tab) line)
          when (and (not (or (string= trimmed "")
                             (char= (char trimmed 0) #\;)))
                    (search "IGNORE-ERRORS" line :test #'char-equal))
            collect (list pathname line-number line))))

(test maintained-runtime-does-not-silently-ignore-errors
  (let ((violations
          (mapcan #'%active-ignore-errors-lines
                  (%maintained-runtime-lisp-files))))
    (is (null violations) "Runtime IGNORE-ERRORS policy violations: ~S" violations)))

(defun run-dev-tests ()
  "Run the maintained developer utility tests."
  (run! 'dev-test-suite))