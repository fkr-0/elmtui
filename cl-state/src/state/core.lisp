(uiop:define-package :elmtui.tea-state.state
  (:use :cl)
  (:import-from :elmtui.tea-state.api :state-ref :application-state
                #:tx
                #:make-tx
                #:tx-p
                #:tx-id
                #:make-state
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
                )
  (:import-from :elmtui.utils #:get-path #:set-path #:as
                #:copy-hash-table)
  (:export #:application-state
           #:state-set
           #:make-state
           #:get-state))

(in-package :elmtui.tea-state.state)

(defgeneric state-ref (place key &optional default))

(defstruct application-state
  (data (make-hash-table :test 'equal))
  (lock (sb-thread:make-mutex))
  (log nil) (history nil) (undone nil) (version 0) (observers nil))

(defgeneric make-state (initial)
  (:documentation "Creates a new application state with the given INITIAL data."))

(defstruct (update-result (:conc-name ur-))
  "Represents the result of an update operation, containing patches to apply to the state
and commands to be executed."
  (patches nil :type list)
  (commands nil :type list)
  (handled nil :type (or boolean null))) ; Indicates if the result has been handled

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

;; (defun -tabl-to-str (tabl &optional (level 0))
;;   (loop for key being the hash-keys of tabl
;;         collect (cons key
;;                       (let ((value (gethash key tabl)))
;;                         (if (hash-table-p value)
;;                             (progn
;;                               (incf level 1)
;;                               (let ((v (format nil "~A</H~A>"
;;                                                (format nil "~&~%~A<H~A>~A"
;;                                                        (str:repeat level  " ")
;;                                                        level
;;                                                        (-tabl-to-str value level))
;;                                                (- level 0))))
;;                                 (decf level 1)
;;                                 v))
;;                             (format nil "~A" value))))))

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

;; ────────────────────────────────  Application‑state  ─────────────────────────
(defmethod print-object ((obj application-state) stream)
  (print-unreadable-object (obj stream :type t)
    (format stream "data: ~D, history: ~D"
            (hash-table-count (application-state-data obj))
            (length (application-state-history obj)))))

;; Deep copy helper (unchanged)
(defun deep-copy-application-state (app)
  (make-application-state
   :data (copy-hash-table (application-state-data app))
   :lock (sb-thread:make-mutex)
   :log (copy-list (application-state-log app))
   :history (copy-list (application-state-history app))
   :undone (copy-list (application-state-undone app))
   :observers (copy-list (application-state-observers app))))

;; ───────────────────────────────  Public accessors  ───────────────────────────
(defmethod state-ref ((state application-state) (key t) &optional default)
  (get-path key (application-state-data state) default))

(defmethod state-ref ((state hash-table) (key t) &optional default)
  (get-path key state default))

(defmethod state-ref ((state list) (key t) &optional default)
  (get-path key state default))

(defmethod (setf state-ref) (value (state application-state) (key t))
  "Atomically store VALUE at KEY inside STATE and log the change.
   The change log stores (KEY OLD NEW) triples in most‑recent‑first order.

   This method is thread-safe and uses a mutex to ensure atomicity.

   Arguments:
    - VALUE: The new value to store.
    - STATE: The application state to modify.
    - KEY: The key at which to store the value.

    Returns the VALUE just stored.

    If the KEY does not exist, it is created with the VALUE.

    Example:
    (setf (state-ref my-app-state :counter) 42) => 42"

  (sb-thread:with-mutex ((application-state-lock state))
    (let* ((data   (application-state-data state))
           (old    (get-path key data :not-present))
           (data*  (set-path data key value)))
      (setf (application-state-data state) data*)
      (push (list key old value) (application-state-log state))
      (incf (application-state-version state))
      value)))                                        ; return the value just stored

(defmethod get-path (path (data application-state) &optional default)
  (or (if (null path)
          (application-state-data data)
          (get-path path (application-state-data data) default)
          ;; (let ((next
          ;;         (get-path path (application-state-data data) default)))
          ;;   (if (eq next default)
          ;;       default
          ;;       (get-path (cdr path) next default)))
          )
      default))

;; (defmethod get-path (path (state application-state) &optional default)
;;   "Gets value at PATH from application-state."
;;   (let ((data (application-state-data state)))
;;     (get-path path data default)))

(defmethod get-path ((path t) (state application-state) &optional default)
  "Gets value at PATH from application-state."
  (let ((data (application-state-data state)))
    (get-path path data default)))
(defmethod get-path ((path list) (state application-state) &optional default)
  "Gets value at PATH from application-state."
  (let ((data (application-state-data state)))
    (get-path path data default)))

(defun get-state (app key &optional (default nil))
  (state-ref app key default))
;;; Convenience wrapper that now delegates to the new logging setter
(defun state-set (state key new)
  "Shorthand for `(setf (state-ref STATE KEY) NEW)`."
  (setf (state-ref state key) new))
;; (defmethod (setf state-ref) (value (state application-state) (key t))
;;   (setf (application-state-data state)
;;         (set-path (application-state-data state) key value)))

;; (defmethod (setf state-ref) (value (state hash-table) (key t))
;;   (set-path state key value))

;; (defmethod (setf state-ref) (value (state list) (key t))
;;   (set-path state key value))

;; Atomic setter that logs the change (same semantics as original)
;; (defun state-set (app key new)
;;   (sb-thread:with-mutex ((application-state-lock app))
;;     (let ((old (state-ref app key :not-present)))
;;       (setf (state-ref app key) new)
;;       (push (list key old new) (application-state-log app))
;;       new)))






;;;── Factory ──────────────────────────────────────────────────
(defmethod make-state ((initial hash-table))
  (elmtui.tea-state.api:make-application-state
   :data initial))

(defmethod make-state ((initial null))
  (elmtui.tea-state.api:make-application-state
   :data
   (make-hash-table :test 'equal)))

(defmethod make-state ((initial list))
  (elmtui.tea-state.api:make-application-state
   :data
   (as :hash-table initial :test 'equal)))
