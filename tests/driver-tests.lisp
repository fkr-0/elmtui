(defpackage :elmtui.driver.tests
  (:use :cl :fiveam :bt)
  (:import-from :cl-inputs.util #:string-to-utf-8-bytes)
  (:import-from :cl-inputs.device.faketerm #:faketerm-inject!)
  (:import-from :cl-inputs.tokens
    #:make-token
    #:+k-key+)
  (:import-from :elmtui.core.event-types
    #:key-event
    #:key-event-key
    #:key-event-char)
  (:import-from :elmtui.backend.faketerm
    #:initialize-backend)
  (:import-from :elmtui.platform.api
    #:backend-input-device #:backend-input-source #:shutdown-backend)
  (:import-from :elmtui.platform.driver
    #:make-driver-context #:driver-context-device
    #:start-driver-input-loop #:stop-driver-input-loop
    #:driver-context-stop-flag)
  (:import-from :uiop
    #:with-temporary-file)
  (:export #:run-driver-tests))

(in-package :elmtui.driver.tests)

(def-suite :driver
  :description "Driver-level tests using cl-inputs faketerm.")


(defmacro with-faketerm-context (&body body)
  (with-temporary-file (:pathname tmp-file )
    `(let* (
             (backend (initialize-backend :faketerm :filepath ,tmp-file))
             (device (backend-input-device backend))
             (source (backend-input-source backend))
             (events '())
             (ctx (make-driver-context
                    :backend backend
                    :device device
                    :input-source source
                    :publish-fn (lambda (evt) (push evt events)))))
       (let ((thread (start-driver-input-loop ctx)))
         (unwind-protect
           (progn ,@body)
           (stop-driver-input-loop ctx)
           (ignore-errors (bt:join-thread thread))
           (ignore-errors (shutdown-backend backend))
           (ignore-errors (delete-file ,tmp-file)))) ; Ensure thread stops before exit
       events)))

(in-suite :driver)

(test share-publisher-in-driver-context
  (let ((events (with-faketerm-context
                  (cl-inputs.device.faketerm::faketerm-inject!
                    (driver-context-device ctx)
                    (string-to-utf-8-bytes "a"))
                  (sleep 0.05))))
    (is (plusp (length events)) "Driver context should publish at least one event.")))

(test start-driver-input-loop-requires-input-source
  "Strict cl-inputs contract: driver input loop must not start without input-source."
  (let ((ctx (make-driver-context
              :backend nil
              :device nil
              :input-source nil
              :publish-fn (lambda (_evt) (declare (ignore _evt)) nil))))
    (signals error
      (start-driver-input-loop ctx))))

(test driver-loop-polls-cl-inputs-source-and-publishes-events
  "Driver loop should poll via cl-inputs.loop:next-token and publish converted events."
  (let* ((ctx (make-driver-context
               :backend nil
               :device nil
               :input-source :fake-source
               :publish-fn (lambda (_evt) nil)))
         (published nil)
         (poll-calls 0)
         (orig-next (symbol-function 'cl-inputs.loop:next-token)))
    (unwind-protect
         (progn
           (setf (slot-value ctx 'elmtui.platform.driver::publish-fn)
                 (lambda (evt)
                   (push evt published)))
           (setf (symbol-function 'cl-inputs.loop:next-token)
                 (lambda (_source &key timeout)
                   (declare (ignore _source timeout))
                   (incf poll-calls)
                   (setf (driver-context-stop-flag ctx) t)
                   (make-token +k-key+ '(:code #\a :mods ()) 0)))
           (elmtui.platform.driver::driver-context-input-loop ctx)
           (is (>= poll-calls 1))
           (is (= 1 (length published)))
           (is-true (typep (first published) 'key-event))
           (is (eql :A (key-event-key (first published))))
           (is (eql #\a (key-event-char (first published)))))
      (setf (symbol-function 'cl-inputs.loop:next-token) orig-next))))

(defun run-driver-tests ()
  (fiveam:run! 'driver-suite))
