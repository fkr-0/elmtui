(defpackage :elmtui.driver.tests
  (:use :cl :fiveam :bt)
  (:import-from :cl-inputs.device.api #:make-device)
  (:import-from :cl-inputs.loop #:make-input-source)
  (:import-from :cl-inputs.util #:string-to-utf-8-bytes)
  (:import-from :cl-inputs.device.faketerm #:faketerm-inject!)
  (:import-from :elmtui.platform.driver
    #:make-driver-context #:start-driver-input-loop #:stop-driver-input-loop)
  (:export #:run-driver-tests))

(in-package :elmtui.driver.tests)

(def-suite :driver
  :description "Driver-level tests using cl-inputs faketerm.")

(defmacro with-faketerm-context (&body body)
  `(let* ((device (cl-inputs.device.api:make-device :faketerm))
          (source (cl-inputs.loop:make-input-source :device device))
          (events '())
          (ctx (make-driver-context
                :backend nil
                :device device
                :input-source source
                :publish-fn (lambda (evt) (push evt events)))))
     (let ((thread (start-driver-input-loop ctx)))
       (unwind-protect
            (progn ,@body)
         (stop-driver-input-loop ctx)
         (ignore-errors (bt:join-thread thread)))) ; Ensure thread stops before exit
     events))

(in-suite :driver)

(test share-publisher-in-driver-context
  (let ((events (with-faketerm-context
                  (cl-inputs.device.faketerm::faketerm-inject!
                   (driver-context-device ctx)
                   (string-to-utf-8-bytes "a"))
                  (sleep 0.05))))
    (is (plusp (length events)) "Driver context should publish at least one event.")))

(defun run-driver-tests ()
  (fiveam:run! 'driver-suite))
