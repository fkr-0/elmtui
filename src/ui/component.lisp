(uiop:define-package :elmtui.ui.component (:use :cl)
  (:export :component-lifecycle
           :component-lifecycle-on-init
           :component-lifecycle-on-mount
           :component-lifecycle-on-destroy
           ;; Introspective helpers
           :describe-on-init-hook-details
           :describe-on-mount-hook-details
           :describe-on-destroy-hook-details))
(in-package :elmtui.ui.component)


;; Define standard lifecycle hooks 
(defstruct component-lifecycle "Represents standard lifecycle hooks for a component." 
(on-init nil :type (or null function symbol)) ; Called when component is first created 
(on-mount nil :type (or null function symbol)) ; Called when component is added to the view 
(on-destroy nil :type (or null function symbol))) ; Called when component is removed

(defmacro define-lifecycle-invoker (name slot-name docstring)
  "Defines a function NAME that invokes a lifecycle hook stored in SLOT-NAME of a component,
and a helper function DESCRIBE-<SLOT-NAME>-HOOK-DETAILS for introspection.
The component is assumed to be a CLOS object, and SLOT-NAME is the symbol naming the slot."
  (let ((helper-name (intern (format nil "DESCRIBE-~A-HOOK-DETAILS" slot-name) *package*)))
    `(progn
       (defun ,name (component)
         ,docstring
         (when (slot-boundp component ',slot-name)
           (let ((actual-hook (slot-value component ',slot-name)))
             (when actual-hook
               (if (or (functionp actual-hook)
                       (and (symbolp actual-hook) (fboundp actual-hook)))
                   (funcall actual-hook component)
                   (warn "Stored lifecycle hook for ~S in component ~A is not a function or fboundp symbol: ~S"
                         ',slot-name component actual-hook))))))
       (defun ,helper-name (component)
         ,(format nil "Describes the configuration and status of the ~A hook for the given COMPONENT." slot-name)
         (let* ((slot-is-bound (slot-boundp component ',slot-name))
                (current-hook-value (if slot-is-bound (slot-value component ',slot-name) :unbound))
                (is-callable (and slot-is-bound
                                  current-hook-value
                                  (not (eq current-hook-value :unbound)) ; Make sure :unbound itself isn't treated as callable
                                  (or (functionp current-hook-value)
                                      (and (symbolp current-hook-value) (fboundp current-hook-value))))))
           (list :hook-name ',slot-name
                 :documentation ,docstring
                 :current-value current-hook-value
                 :is-callable (if is-callable t nil)))))))

(define-lifecycle-invoker component-lifecycle-on-init on-init
  "Invoke the on-init hook of the component if it exists.")

(define-lifecycle-invoker component-lifecycle-on-mount on-mount
  "Invoke the on-mount hook of the component if it exists.")

(define-lifecycle-invoker component-lifecycle-on-destroy on-destroy
  "Invoke the on-destroy hook of the component if it exists.")
