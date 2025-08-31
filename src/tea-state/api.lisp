(uiop:define-package :elmtui.tea-state.api
  (:use :cl)
  ;; Import from the implementation packages
  (:export
   #:state-ref
   #:application-state
   #:make-state
   #:tx
   #:make-tx
   #:tx-p
   #:tx-id
   #:tx-name
   #:tx-changes
   #:make-application-state
   #:application-state-data
   #:application-state-log
   #:application-state-history
   #:application-state-undone
   #:application-state-observers
   #:application-state-version
   #:application-state-lock
   #:application-state-p
   #:get-component-by-path

   #:ur-has-command-p
   #:ur-add-command
   #:update-result
   #:make-update-result
   #:ur-patches
   #:ur-commands))
(in-package :elmtui.tea-state.api)

(defgeneric state-ref (place key &optional default))

(defstruct application-state
  (data (make-hash-table :test 'equal))
  (lock (sb-thread:make-mutex))
  (log nil) (history nil) (undone nil) (version 0) (observers nil))

(defgeneric make-state (initial)
  (:documentation "Creates a new application state with the given INITIAL data."))

(defstruct tx
  id
  name
  changes)  ; list of (key old new)

(defstruct (update-result (:conc-name ur-))
  "Represents the result of an update operation, containing patches to apply to the state
and commands to be executed."
  (patches nil :type list)
  (commands nil :type list)
  (handled nil :type (or boolean null))) ; Indicates if the result has been handled
;; (:constructor make-update-result (patches commands &optional handled))
;; (:copier nil) ; Prevent copying to avoid unintended side effects
;; (:predicate ur-p))

;; (defgeneric app-state-p (state))
;; (defmethod app-state-p ((state t))
;;   nil)
;; (defmethod app-state-p ((state null))
;;   nil)
;; Define a generic function with proper FTYPE
(defgeneric ur-has-command-p (result command)
  (:documentation "Checks if the update result contains a specific command."))

;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================
(defmethod ur-has-command-p ((result update-result) command)
  "Checks if the update result contains a specific command."
  (declare (type update-result result)
           (type t command))
  (check-type result update-result)
  (member command (ur-commands result) :test #'equal)) ; Added :test for robustness

;; Define a generic function with proper FTYPE
;; (declaim (ftype (function (update-result t) (values update-result &rest t)) ur-add-command))
(defgeneric ur-add-command (result command)
  (:documentation "Adds a command to the update result."))
(defmethod ur-add-command ((result update-result) command)
  "Adds a command to the update result."
  (declare (type update-result result)
           (type t command))
  (check-type result update-result)
  (setf (ur-commands result) (cons command (ur-commands result)))
  result)
(defmethod get-component-by-path ((app-state application-state) component-id-path)
  "Retrieves a component instance from the application state using its ID path.
   The component itself is stored under '(:components <id1> <id2> ... :component-instance)."
  (declare (type application-state app-state)
           (type list component-id-path))
  (check-type app-state application-state)
  (check-type component-id-path list)
  (let* ((app-data (application-state-data app-state))
         (components-path (append '(:components) component-id-path '(:component-instance))))
    (if (typep app-data 'hash-table)
        (let ((hash-table-data app-data))
          (
           elmtui.utils:get-path hash-table-data components-path )
          ;; (if (and (listp components-path) (= (length components-path) 1))
          ;;     (gethash (first components-path) hash-table-data)
          ;;     ;; Old: error on list-paths
          ;;     ;; (error (format nil "Nested component-paths in hash-table not supported: ~A~%"
          ;;     ;;                components-path))
          ;;     ;; New: resolve first, then get the component instance
          ;;     ;; components-path is '(:components <id1> <id2> ... :component-instance).
          ;;     ;; (let ((components-path (append '(:components) path '(:component-instance))))
          ;;     ;;   (declare (type list path))
          ;;     ;;   (declare (type list path))
          ;;     ;;   (get-path root components-path nil))
          ;;                               ; Use get-path to resolve the path)
          ;;     )
          )
        ;; (get-path app-data components-path)
        )))

(defun plist-to-application-state (plist)
  "Convert a plist to an app-state structure."
  (let ((state-data (make-hash-table :test 'equal)))
    (loop for (key value) on plist by #'cddr
          do (setf (gethash key state-data) value))
    (make-application-state :data state-data)))

(defgeneric get-component-by-path (root path)
  (:documentation
   "Retrieve a component instance by path from a root object.
    Specialized for application-state. For other types, signals an error.
    The path is a list of component IDs. For application-state, the component is stored under
    '(:components <id1> <id2> ... :component-instance)."))

(defmethod get-component-by-path ((app-state application-state) component-id-path)
  "Retrieves a component instance from the application state using its ID path.
   The component itself is stored under '(:components <id1> <id2> ... :component-instance)."
  (declare (type application-state app-state)
           (type list component-id-path))
  (check-type app-state application-state)
  (check-type component-id-path list)
  (let* ((app-data (application-state-data app-state))
         (components-path (append '(:components) component-id-path '(:component-instance))))
    (if (typep app-data 'hash-table)
        (let ((hash-table-data app-data))
          (elmtui.utils:get-path hash-table-data components-path )))))

(defun pprinc-application-state (state)
  "Pretty print the application state."
  (labels ((-tabl-to-str (tabl &optional (level 0))
             (loop for key being the hash-keys of tabl
                   collect (cons key
                                 (let ((value (gethash key tabl)))
                                   (if (hash-table-p value)
                                       (progn
                                         (incf level 1)
                                         (let ((v (format nil "~A</H~A>"
                                                          (format nil "~&~%~A<H~A>~A"
                                                                  (str:repeat level  " ")
                                                                  level
                                                                  (-tabl-to-str value))
                                                          (- level 0))))
                                           (decf level 1)
                                           v))
                                       (format nil "~A" value)))))))
    (let ((data (-tabl-to-str  (application-state-data state))))
      ;; Correct FTYPE declarations for application-state constructor with proper keyword parameters
      (format nil "~&~% ~A~%Data:~%~A~%" (format nil "~&Application State:~%") data))))
