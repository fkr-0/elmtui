;;;===============================================================
;;; File: src/state/api.lisp
;;; Public API for the ElmTUI state management system.
;;;===============================================================
(uiop:define-package :elmtui.state.api
  (:use :cl :log4cl :cl-state.api)
  (:reexport :cl-state.api :elmtui.state.update)
  (:import-from :elmtui.state.update
                #:malformed-update-result-error
                #:malformed-update-result-fn-name
                #:malformed-update-result-reason
                #:malformed-update-result-values)
  (:export
    #:malformed-update-result-error
    #:malformed-update-result-fn-name
    #:malformed-update-result-reason
    #:malformed-update-result-values
    #:get-component-by-path
    #:store-component-at-path
    #:remove-component-at-path
    #:set-state-ref
    #:invoke-update
    #:update-result
    #:make-update-result
    #:ur-patches
    #:ur-commands
    #:ur-handled
    #:ur-has-command-p
    #:ur-add-command
    #:*update-contracts*
    #:plist-to-application-state
    #:pprinc-application-state))

(in-package :elmtui.state.api)

(defvar *update-contracts* (make-hash-table :test 'equal)
  "Registry of update function contracts for documentation and validation.")

(defstruct (update-result (:conc-name ur-))
  "Represents the result of an update operation, containing patches and commands."
  (patches nil :type list)
  (commands nil :type list)
  (handled nil :type (or boolean null)))

(defgeneric ur-has-command-p (result command)
  (:documentation "Checks if the update result contains a specific command."))

(defmethod ur-has-command-p ((result update-result) command)
  (declare (type update-result result)
    (type t command))
  (check-type result update-result)
  (member command (ur-commands result) :test #'equal))

(defgeneric ur-add-command (result command)
  (:documentation "Adds a command to the update result."))

(defmethod ur-add-command ((result update-result) command)
  (declare (type update-result result)
    (type t command))
  (check-type result update-result)
  (setf (ur-commands result) (cons command (ur-commands result)))
  result)

(defun plist-to-application-state (plist &key (backend :hash-table))
  "Convert a plist to an application-state with BACKEND."
  (make-state :initial plist :backend backend))

(defun set-state-ref (state path value)
  "Set VALUE at PATH in STATE."
  (setf (state-ref state path) value))

(defun store-component-at-path (app-state component-id-path value)
  "Store VALUE at COMPONENT-ID-PATH through the normal state transaction protocol."
  (let ((path (append '(:components) component-id-path '(:component-instance))))
    (apply-patches app-state
                   (list (make-patch :path path :op :set :value value))))
  value)

(defun remove-component-at-path (app-state component-id-path)
  "Remove COMPONENT-ID-PATH through the normal state transaction protocol."
  (let ((path (append '(:components) component-id-path '(:component-instance))))
    (apply-patches app-state
                   (list (make-patch :path path :op :remove)))
    nil))

(defun pprinc-application-state (state)
  "Pretty print the application state."
  (format nil "~&~%Application State:~%Data:~%~S~%"
    (application-state-plist state)))

(defun invoke-update (update-fn msg state &key base-path)
  "Invoke UPDATE-FN with an update context and return an UPDATE-RESULT.

Malformed return shapes consistently signal MALFORMED-UPDATE-RESULT-ERROR so
callers can inspect the function designator, reason, and original values."
  (let* ((ctx (elmtui.state.update:make-update-context state :base-path base-path))
         (values (multiple-value-list (funcall update-fn msg ctx)))
         (ctx-patches (elmtui.state.update:context-patches ctx))
         (ctx-commands (elmtui.state.update:context-commands ctx))
         (handled nil)
         (extra-patches nil)
         (extra-commands nil))
    (cond
      ((and (= (length values) 1)
            (typep (first values) 'update-result))
       (let ((ur (first values)))
         (setf handled (ur-handled ur)
               extra-patches (ur-patches ur)
               extra-commands (ur-commands ur))))
      ((= (length values) 2)
       (multiple-value-setq (extra-patches extra-commands)
         (elmtui.state.update:process-update-result
           values :update-fn-name update-fn :log-p nil)))
      ((or (null values) (equal values '(nil)))
       (setf extra-patches nil
             extra-commands nil))
      (t
       (error 'elmtui.state.update:malformed-update-result-error
              :update-fn-name update-fn
              :reason "Expected UPDATE-RESULT, two values (patches commands), or NIL"
              :returned-values values)))
    (make-update-result
      :patches (append ctx-patches extra-patches)
      :commands (append ctx-commands extra-commands)
      :handled handled)))
