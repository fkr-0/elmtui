
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

(test buffer-dump-preserves-graphemes-without-null-padding
  (let ((buffer (make-virtual-buffer 3 1))
        (cluster (format nil "界~C" (code-char #x301))))
    (set-buffer-cell-at buffer 0 0 #\界 nil :grapheme cluster)
    (set-buffer-cell-at buffer 0 1 #\Null nil)
    (set-buffer-cell-at buffer 0 2 #\x nil)
    (is (string= (format nil "~Ax~%" cluster) (buffer->string buffer)))))

(test buffer-dump-preserves-original-condition-and-restarts
  (let ((buffer (make-virtual-buffer 1 1)) (evaluations 0)
        (condition (make-condition 'simple-error :format-control "original"))
        (dump ""))
    (let ((result
            (with-output-to-string (out)
              (let ((*error-output* out))
                (setf dump
                      (handler-bind ((error (lambda (caught)
                                              (is (eq condition caught))
                                              (invoke-restart 'continue-test))))
                        (restart-case
                            (elmtui.dev:with-buffer-dump
                                ((progn (incf evaluations) buffer))
                              (error condition))
                          (continue-test () :continued))))))))
      (is (search "Buffer state on error" result)))
    (is (eq :continued dump))
    (is (= 1 evaluations))))

(test invalid-buffer-dump-does-not-replace-original-error
  (let ((original (make-condition 'simple-error :format-control "original")))
    (handler-case
        (elmtui.dev:with-buffer-dump (:not-a-buffer) (error original))
      (error (caught) (is (eq original caught))))))

(test element-tree-inspection-is-bounded-and-cycle-safe
  (let ((root (make-instance 'container-element :id :cycle)))
    (setf (elmtui.view.base-elements:element-children root) (list root))
    (is (search "cycle" (format-element-tree root) :test #'char-equal))
    (is (search "limit" (format-element-tree root :max-nodes 1) :test #'char-equal))
    (is (search "limit" (format-element-tree root :max-depth 0) :test #'char-equal))))

(test depth-truncation-still-obeys-total-node-budget
  (let* ((root (make-instance 'container-element :id :wide
                              :children (loop repeat 1000 collect
                                          (make-instance 'text-element :content "child"))))
         (dump (format-element-tree root :max-depth 0 :max-nodes 2)))
    (is (<= (count #\Newline dump) 3))
    (is (search "node limit" dump))))

(test native-view-preview-uses-layout-and-grapheme-rendering
  (multiple-value-bind (buffer tree)
      (elmtui.dev:render-view
       '(:container :id :preview :style (:display :flex :flex-direction :column)
         :children ((:text :id :message :content "界x" :style (:height 1))))
       8 3)
    (is (search "界x" (buffer->string buffer)))
    (is (search "#PREVIEW" (format-element-tree tree)))
    (is (search "8x3" (format-element-tree tree)))))
(test runtime-snapshot-has-stable-shape
 (let ((snapshot (runtime-snapshot)))
   (is (listp (getf snapshot :event-loop)))
   (is (integerp (getf snapshot :queue-length)))
   (is (integerp (getf snapshot :subscription-count)))
   (is (listp (getf snapshot :topics)))
   (is (typep (getf snapshot :application-state-present-p) 'boolean))
   (is (search "ElmTUI runtime snapshot" (format-runtime-snapshot snapshot)))))

(test runtime-snapshot-omits-arbitrary-event-payloads
  (let ((elmtui.core.loop::*event-loop-metrics* (make-hash-table)))
    (setf (gethash :last-event elmtui.core.loop::*event-loop-metrics*)
          '(:payload :arbitrary-model-data))
    (let ((snapshot (runtime-snapshot)))
      (is (eq :process (getf snapshot :scope)))
      (is (integerp (getf snapshot :captured-at)))
      (is (null (getf (getf snapshot :event-loop) :last-event))))))
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
