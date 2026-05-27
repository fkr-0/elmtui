(uiop:define-package :elmtui.runtime.protocol
  (:use :cl)
  (:import-from :log4cl
                #:log-info
                #:log-warn)
  (:import-from :elmtui.app.api
                #:run-application
                #:get-component-instance
                #:app-config-message-queue)
  (:import-from :elmtui.ui.api
                #:update)
  (:import-from :elmtui.state.api
                #:update-result
                #:ur-patches
                #:ur-commands)
  (:export
   #:run-application
   #:get-component-instance
   #:app-config-message-queue
   #:dispatch-root-message))

(in-package :elmtui.runtime.protocol)

(defun dispatch-root-message (msg state root-id)
  "Deliver MSG to the component tree rooted at ROOT-ID.
Returns two values: PATCHES and COMMANDS."
  (let* ((id-path (list :components root-id))
         (root (get-component-instance id-path state)))
    (log-info "Dispatching message ~S to root component ~A with id-path ~S"
              msg root-id id-path)
    (if (null root)
        (progn
          (log-warn "Root component ~A not found - message dropped: ~S"
                    root-id msg)
          (values nil nil))
        (let ((raw-result (multiple-value-list
                           (update root msg state :id-path id-path))))
          (cond
            ((and raw-result
                  (= (length raw-result) 1)
                  (typep (first raw-result) 'update-result))
             (values (ur-patches (first raw-result))
                     (ur-commands (first raw-result))))
            ((= (length raw-result) 2)
             (values (first raw-result) (second raw-result)))
            (t
             (log-warn "Component ~A returned unexpected update result: ~S"
                       root-id raw-result)
             (values nil nil)))))))
