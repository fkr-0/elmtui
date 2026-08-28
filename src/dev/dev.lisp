
(uiop/package:define-package :elmtui.dev (:use :cl)
                             (:import-from :elmtui.core.loop
                              #:get-event-loop-status #:get-event-queue-length)
                             (:import-from :elmtui.core.topic-registry
                              #:subscription-count
                              #:get-topics-with-subscribers)
                             (:import-from :elmtui.core.globals #:*app-state*)
                             (:import-from :elmtui.view.base-elements
                              #:base-element #:element-id #:element-children
                              #:element-style #:element-layout-rect
                              #:dsl-element-type)
                             (:import-from :elmtui.view.geo #:x #:y #:w #:h)
                             (:import-from
                              :elmtui.platform.backend.common.virtual-buffer
                              #:buffer-height #:buffer-width #:buffer-cell-at
                              #:buffer-cell-char)
                             (:export #:buffer->string #:with-buffer-dump
                              #:runtime-snapshot #:format-runtime-snapshot
                              #:format-element-tree #:dev-main))
(in-package :elmtui.dev)
(defun buffer->string (buffer)
  "Return BUFFER as plain text without writing to *STANDARD-OUTPUT*."
  (with-output-to-string (out)
    (dotimes (row (buffer-height buffer))
      (dotimes (col (buffer-width buffer))
        (write-char (buffer-cell-char (buffer-cell-at buffer row col)) out))
      (terpri out))))
(defmacro with-buffer-dump ((buffer) &body body)
  "Run BODY and print BUFFER to *ERROR-OUTPUT* before entering the debugger on error."
  `(handler-bind ((error
                   (lambda (condition)
                     (format *error-output* "~%Buffer state on error:~%~A"
                             (buffer->string ,buffer))
                     (invoke-debugger condition))))
     ,@body))
(defun runtime-snapshot ()
  "Return a side-effect-free snapshot of the maintained runtime diagnostics."
  (list :event-loop (get-event-loop-status) :queue-length
        (get-event-queue-length) :subscription-count (subscription-count)
        :topics (get-topics-with-subscribers) :application-state-present-p
        (not (null *app-state*))))
(defun format-runtime-snapshot (&optional (snapshot (runtime-snapshot)))
  "Format SNAPSHOT returned by RUNTIME-SNAPSHOT for interactive REPL use."
  (with-output-to-string (out)
    (let ((loop-status (getf snapshot :event-loop)))
      (format out "ElmTUI runtime snapshot~%")
      (format out "  consumer-thread-active: ~S~%"
              (getf loop-status :consumer-thread-active))
      (format out "  active-channels: ~S~%"
              (getf loop-status :active-channels))
      (format out "  queue-length: ~D~%" (getf snapshot :queue-length 0))
      (format out "  processed-events: ~D~%"
              (getf loop-status :processed-event-count 0))
      (format out "  average-processing-time-ms: ~,3F~%"
              (coerce (getf loop-status :average-processing-time-ms 0.0)
                      'double-float))
      (format out "  subscriptions: ~D~%"
              (getf snapshot :subscription-count 0))
      (format out "  topics: ~S~%" (getf snapshot :topics))
      (format out "  application-state-present: ~S~%"
              (getf snapshot :application-state-present-p)))))
(defun format-element-tree (root &key (include-style nil))
  "Render a compact textual view of a lowered BASE-ELEMENT tree.
ROOT may be one BASE-ELEMENT or a list of sibling elements.  Layout coordinates
are included when available; INCLUDE-STYLE adds the resolved style plist."
  (with-output-to-string (out)
    (labels ((walk (node depth)
               (cond
                ((typep node 'base-element)
                 (let ((rect (element-layout-rect node)))
                   (format out "~A- ~S"
                           (make-string depth :initial-element #\ )
                           (dsl-element-type node))
                   (when (element-id node)
                     (format out " #~A" (element-id node)))
                   (when rect
                     (format out " @ (~D,~D) ~Dx~D" (x rect) (y rect) (w rect)
                             (h rect)))
                   (when include-style
                     (format out " style=~S" (element-style node)))
                   (terpri out)
                   (dolist (child (element-children node))
                     (walk child (+ depth 2)))))
                ((listp node) (dolist (child node) (walk child depth)))
                (t
                 (format out "~A- ~S~%"
                         (make-string depth :initial-element #\ ) node)))))
      (walk root 0))))
(defun dev-main ()
  "Print and return a current runtime snapshot."
  (let ((snapshot (runtime-snapshot)))
    (write-string (format-runtime-snapshot snapshot))
    snapshot))