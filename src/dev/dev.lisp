(uiop:define-package :elmtui.dev
  (:use :cl)
  (:import-from :elmtui.core.loop #:get-event-loop-status #:get-event-queue-length)
  (:import-from :elmtui.core.topic-registry #:subscription-count #:get-topics-with-subscribers)
  (:import-from :elmtui.core.globals #:*app-state*)
  (:import-from :elmtui.view.base-elements
                #:base-element #:element-id #:element-children #:element-style
                #:element-layout-rect #:dsl-element-type)
  (:import-from :elmtui.view.geo #:x #:y #:w #:h)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:buffer-height #:buffer-width #:buffer-cell-at #:buffer-cell-char
                #:buffer-cell-grapheme)
  (:export #:buffer->string #:with-buffer-dump #:runtime-snapshot
           #:format-runtime-snapshot #:format-element-tree #:render-view #:dev-main))
(in-package :elmtui.dev)

(defun buffer->string (buffer)
  "Return plain Unicode rows, preserving graphemes and omitting wide-cell tails.
No terminal I/O or ANSI styling is performed. Each row ends with a newline."
  (with-output-to-string (out)
    (dotimes (row (buffer-height buffer))
      (dotimes (col (buffer-width buffer))
        (let* ((cell (buffer-cell-at buffer row col)) (ch (buffer-cell-char cell)))
          (unless (char= ch #\Null)
            (write-string (or (buffer-cell-grapheme cell) (string ch)) out))))
      (terpri out))))

(defmacro with-buffer-dump ((buffer &key (stream '*error-output*)) &body body)
  "Dump BUFFER to STREAM on an error, preserving the condition and its restarts.
BUFFER and STREAM are evaluated once. Dump failures cannot replace the original
error. This macro never invokes the debugger itself; normal error handling applies.
Use a file/string stream when debugging a running terminal UI."
  (let ((value (gensym "BUFFER")) (output (gensym "STREAM")) (dumped (gensym "DUMPED")))
    `(let ((,value ,buffer) (,output ,stream) (,dumped nil))
       (handler-bind
           ((error (lambda (condition)
                     (declare (ignore condition))
                     (unless ,dumped
                       (setf ,dumped t)
                       (handler-case
                           (format ,output "~%Buffer state on error:~%~A" (buffer->string ,value))
                         (error () nil))))))
         ,@body))))

(defun runtime-snapshot ()
  "Return approximate process-level runtime diagnostics without the model payload.
Counters are sampled separately, not as an atomic transaction or per-app profile."
  (list :scope :process :captured-at (get-universal-time)
        :lisp-implementation (format nil "~A ~A" (lisp-implementation-type)
                                     (lisp-implementation-version))
        :event-loop (loop for (key value) on (get-event-loop-status) by #'cddr
                          unless (eq key :last-event)
                            append (list key value))
        :queue-length (get-event-queue-length)
        :subscription-count (subscription-count)
        :topics (copy-list (get-topics-with-subscribers))
        :application-state-present-p (not (null *app-state*))))

(defun format-runtime-snapshot (&optional (snapshot (runtime-snapshot)))
  "Format a captured runtime snapshot without sampling the runtime again."
  (with-output-to-string (out)
    (let ((loop-status (getf snapshot :event-loop)))
      (format out "ElmTUI runtime snapshot (process counters)~%")
      (format out "  implementation: ~A~%" (getf snapshot :lisp-implementation "unknown"))
      (format out "  consumer-thread-active: ~S~%" (getf loop-status :consumer-thread-active))
      (format out "  shutdown-requested: ~S~%" (getf loop-status :shutdown-requested))
      (format out "  active-channels: ~D~%" (or (getf loop-status :active-channels) 0))
      (format out "  queue-length: ~D~%" (getf snapshot :queue-length 0))
      (format out "  processed-events: ~D~%" (getf loop-status :processed-event-count 0))
      (format out "  average-processing-time-ms: ~,3F~%"
              (coerce (getf loop-status :average-processing-time-ms 0.0) 'double-float))
      (format out "  subscriptions: ~D~%" (getf snapshot :subscription-count 0))
      (format out "  topics: ~S~%" (getf snapshot :topics))
      (format out "  application-state-present: ~S~%" (getf snapshot :application-state-present-p)))))

(defun format-element-tree (root &key (include-style nil) (max-depth 20) (max-nodes 500))
  "Format lowered BASE-ELEMENT nodes, IDs, rectangles and optional styles.
Traversal is bounded and marks cycles, including circular sibling lists.
MAX-DEPTH counts element levels starting at zero; MAX-NODES limits visited nodes."
  (check-type max-depth (integer 0 *))
  (check-type max-nodes (integer 1 *))
  (let ((active (make-hash-table :test #'eq)) (count 0) (limited nil)
        (*print-circle* t) (*print-level* 4) (*print-length* 20))
    (with-output-to-string (out)
      (labels ((line (depth text) (format out "~V@T~A~%" (* depth 2) text))
               (siblings (nodes depth)
                 (let ((tails (make-hash-table :test #'eq)))
                   (loop for tail = nodes then (cdr tail)
                         while (and tail (not limited))
                         do (cond
                              ((atom tail) (walk tail depth) (return))
                              ((gethash tail tails) (line depth "<cycle: sibling list>") (return))
                              (t (setf (gethash tail tails) t) (walk (car tail) depth))))))
               (walk (node depth)
                 (cond
                   (limited nil)
                   ((>= count max-nodes) (line depth "<node limit>") (setf limited t))
                   ((> depth max-depth) (incf count) (line depth "<depth limit>"))
                   ((and node (gethash node active)) (incf count) (line depth "<cycle>"))
                   ((typep node 'base-element)
                    (incf count)
                    (setf (gethash node active) t)
                    (unwind-protect
                         (let ((rect (element-layout-rect node)))
                           (format out "~V@T- ~S" (* depth 2) (dsl-element-type node))
                           (when (element-id node) (format out " #~A" (element-id node)))
                           (when rect (format out " @ (~D,~D) ~Dx~D" (x rect) (y rect) (w rect) (h rect)))
                           (when include-style (format out " style=~S" (element-style node)))
                           (terpri out)
                           (siblings (element-children node) (1+ depth)))
                      (remhash node active)))
                   ((consp node)
                    (incf count)
                    (setf (gethash node active) t)
                    (unwind-protect (siblings node depth) (remhash node active)))
                   (t (incf count) (line depth (format nil "- ~S" node))))))
        (walk root 0)))))

(defun render-view (dsl width height)
  "Preview lowered :CONTAINER/:TEXT DSL using ElmTUI layout and rendering.
Return a virtual buffer and laid-out tree, without a backend or terminal writes.
Component lifecycle/state lowering belongs to the application runtime; supply
its resulting base-element DSL here. WIDTH and HEIGHT are positive cell counts."
  (check-type width (integer 1 *))
  (check-type height (integer 1 *))
  (let* ((rect (elmtui.view.geo:make-rectangle
                :pos (elmtui.view.geo:make-pos :x 0 :y 0)
                :size (elmtui.view.geo:make-size :w width :h height)))
         (tree (elmtui.view.tree-transforms:process-tree
                (elmtui.view.base-elements:dsl->objects dsl)
                :ctx (elmtui.contracts:make-app-context :viewport-rect rect) :root-rect rect))
         (buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer width height)))
    (elmtui.platform.tree-renderer:render-laid-out-tree-to-buffer (list tree) :buffer buffer)
    (values buffer tree)))

(defun dev-main (&optional (stream *standard-output*))
  "Print process diagnostics to STREAM and return the captured snapshot."
  (let ((snapshot (runtime-snapshot)))
    (write-string (format-runtime-snapshot snapshot) stream)
    snapshot))
