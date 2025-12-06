(uiop:define-package :elmtui.backend.urxvt
  (:use :cl)
  (:import-from :log4cl #:log-info)
  (:import-from :cl-inputs.device.api #:make-device)
  (:import-from :elmtui.platform.backend.terminal #:make-terminal-instance-for-device)
  (:import-from :elmtui.core.errors #:signal-backend-operation-failed)
  (:export #:initialize-backend))

(in-package :elmtui.backend.urxvt)

;; Thin shim that reuses the cl-inputs URXVT device and the shared terminal backend pipeline.
(defmethod elmtui.platform.api:initialize-backend ((backend-type (eql :urxvt))
                                                   &key publish-fn (initial-clear t) (device nil) &allow-other-keys)
  (declare (ignore backend-type))
  (handler-case
      (let ((dev (or device (make-device :urxvt))))
        (log-info "URXVT: Using cl-inputs device ~A" dev)
        (make-terminal-instance-for-device :device dev :publish-fn publish-fn :initial-clear initial-clear))
    (error (e)
      (signal-backend-operation-failed "urxvt" "initialization" e))))
