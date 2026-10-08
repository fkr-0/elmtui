(uiop:define-package :elmtui.render.presentation
  (:use :cl)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:virtual-terminal-buffer #:buffer-width #:buffer-height #:make-virtual-buffer)
  (:import-from :elmtui.platform.backend.terminal
    #:terminal-instance #:terminal-instance-cl-device)
  (:import-from :elmtui.platform.api #:term-stream)
  (:import-from :elmtui.platform.backend.terminal.diff-renderer
    #:apply-diff-to-backend)
  (:import-from :elmtui.render.diff #:compute-buffer-diff)
  (:export #:presenter-ready-p #:present-diff #:compute-frame-operations
           #:present-frame #:recording-presenter #:make-recording-presenter
           #:recorded-presentations #:clear-recordings))
(in-package :elmtui.render.presentation)

(defgeneric presenter-ready-p (presenter)
  (:documentation "Whether PRESENTER can accept a diff now. Unsupported presenters return NIL."))
(defmethod presenter-ready-p ((presenter t))
  nil)
(defmethod presenter-ready-p ((presenter terminal-instance))
  (let ((stream (term-stream presenter)))
    (or (and (streamp stream) (open-stream-p stream))
        (not (null (terminal-instance-cl-device presenter))))))

(defstruct (recording-presenter (:constructor make-recording-presenter ()))
  (records nil))
(defmethod presenter-ready-p ((presenter recording-presenter))
  t)

(defgeneric present-diff (presenter operations origin-row origin-col)
  (:documentation "Apply OPERATIONS at the zero-based origin; return true only after success."))
(defmethod present-diff ((presenter terminal-instance) operations origin-row origin-col)
  (apply-diff-to-backend operations presenter origin-row origin-col))
(defmethod present-diff ((presenter recording-presenter) operations origin-row origin-col)
  (push (list :row origin-row :col origin-col :operations (copy-tree operations))
        (recording-presenter-records presenter))
  t)

(defun recorded-presentations (presenter)
  "Return recording entries in presentation order, without consuming the log."
  (check-type presenter recording-presenter)
  (nreverse (copy-list (recording-presenter-records presenter))))
(defun clear-recordings (presenter)
  "Discard recorded presentations and return PRESENTER."
  (check-type presenter recording-presenter)
  (setf (recording-presenter-records presenter) nil)
  presenter)

(defun compute-frame-operations (previous next)
  "Return pure (values operations metrics) for NEXT relative to PREVIOUS.
Missing front and incompatible sizes explicitly request initial-frame logic;
no global first-call flag, allocations of dummy front buffers or terminal I/O."
  (check-type next virtual-terminal-buffer)
  (when previous (check-type previous virtual-terminal-buffer))
  (let ((initial-frame-p
          (or (null previous)
              (/= (buffer-width previous) (buffer-width next))
              (/= (buffer-height previous) (buffer-height next)))))
    (compute-buffer-diff (unless initial-frame-p previous) next
                         :initial-frame-p initial-frame-p)))

(defun present-frame (presenter previous next &key (origin-row 0) (origin-col 0))
  "Present only changed cells. Return (values OPERATIONS T DIFF-METRICS).
Callers may commit their front frame only after successful acknowledgement.
No-operation frames never call PRESENT-DIFF and cannot write to the backend."
  (check-type origin-row (integer 0 *))
  (check-type origin-col (integer 0 *))
  (unless (presenter-ready-p presenter)
    (error "Presenter is not ready: ~S" presenter))
  (multiple-value-bind (operations metrics)
      (compute-frame-operations previous next)
    (when operations
      (unless (present-diff presenter operations origin-row origin-col)
        (error "Presenter failed to acknowledge frame: ~S" presenter)))
    (values operations t metrics)))
