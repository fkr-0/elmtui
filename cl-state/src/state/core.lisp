;;; cl-state/src/state/core.lisp
(in-package :cl-state.core)

(defstruct application-state
  (data (make-hash-table :test 'equal))
  (backend :hash-table)
  (lock (bt:make-lock "cl-state.lock"))
  (log nil)
  (history nil)
  (undone nil)
  (version 0)
  (observers nil))

(defun %normalize-backend (backend)
  (ecase backend
    (:hash-table :hash-table)
    (:plist :plist)))

(defun %coerce-initial (initial backend)
  (let ((backend* (%normalize-backend backend)))
    (cond
      ((null initial) (coerce-data nil backend*))
      ((application-state-p initial)
        (coerce-data (application-state-data initial) backend*))
      ((hash-table-p initial) (coerce-data initial backend*))
      ((listp initial)
        (when (and (eq backend* :hash-table)
                (not (cl-state.utils::%plist-like-p initial)))
          (error "Expected plist-like initial state for :HASH-TABLE backend, got ~S" initial))
        (coerce-data initial backend*))
      (t (error "Unsupported initial state type ~S" (type-of initial))))))

(defun make-state (&key (initial nil) (backend :hash-table))
  "Create an application state object.

Arguments:
+ ~:initial~ — The initial data to populate the state. This can be any data structure compatible with the chosen backend.
+ ~:backend~ — The backend type for storing the state. Defaults to ~:hash-table~. Other supported backends depend on your implementation of ~%normalize-backend~.

Returns:
+ A new application state object created by ~make-application-state~, initialized with the given data and backend.

Usage:
  (make-state :initial '((:foo . 42) (:bar . 99)))
  (make-state :initial '((:foo . 42)) :backend :alist)

Notes:
+ All arguments are keyword arguments; you must use ~:initial~ and ~:backend~ when calling the function.
+ The function expects that ~%normalize-backend~ and ~%coerce-initial~ are defined elsewhere and handle backend normalization and data coercion.

See Also:
+ ~%normalize-backend~
+ ~%coerce-initial~
+ ~make-application-state~
"

  (let* ((backend* (%normalize-backend backend))
          (data (%coerce-initial initial backend*)))
    (make-application-state :data data :backend backend*)))

(defun set-application-state-backend (state backend)
  "Convert STATE data to BACKEND and update the application-state slot."
  (let* ((backend* (%normalize-backend backend))
          (data (coerce-data (application-state-data state) backend*)))
    (setf (application-state-data state) data
      (application-state-backend state) backend*)
    state))

(defun deep-copy-application-state (app)
  (let ((data (application-state-data app)))
    (make-application-state
      :data (if (hash-table-p data) (copy-hash-table data) (copy-list data))
      :backend (application-state-backend app)
      :lock (bt:make-lock "cl-state.lock")
      :log (copy-list (application-state-log app))
      :history (copy-list (application-state-history app))
      :undone (copy-list (application-state-undone app))
      :version (application-state-version app)
      :observers (copy-list (application-state-observers app)))))


(defun valid-state-path-p (path)
  "Return true when PATH is a symbol or a proper list of non-NIL symbols."
  (or (symbolp path)
      (and (listp path)
           (every (lambda (part) (and part (symbolp part))) path))))

(defun assert-valid-state-path (path)
  (unless (valid-state-path-p path)
    (error "Invalid state path ~S. Expected a symbol or proper list of non-NIL symbols." path))
  path)

(defgeneric state-ref (place key &optional default))

(defmethod state-ref ((state application-state) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key (application-state-data state) default))

(defmethod state-ref ((state hash-table) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key state default))

(defmethod state-ref ((state list) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key state default))

(defmethod get-path (path (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod get-path ((path list) (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod get-path ((path symbol) (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod (setf state-ref) (value (state application-state) (key t))
  "Atomically store VALUE at KEY inside STATE and log the change."
  (assert-valid-state-path key)
  (bt:with-lock-held ((application-state-lock state))
    (let* ((data (application-state-data state))
            (old (get-path key data :not-present))
            (data* (set-path data key value)))
      (setf (application-state-data state) data*)
      (push (list key old value) (application-state-log state))
      (incf (application-state-version state))
      (ignore-errors
        (cl-state.observer:notify-observers state key old value))
      value)))

(defmethod (setf state-ref) (value (state hash-table) (key t))
  (assert-valid-state-path key)
  (set-path state key value))

(defmethod (setf state-ref) (value (state list) (key t))
  (assert-valid-state-path key)
  (set-path state key value))

(defun get-state (state key &optional default)
  "Convenience wrapper for state-ref."
  (state-ref state key default))

(defun state-set (state key value)
  "Convenience wrapper for (setf state-ref)."
  (setf (state-ref state key) value))

(defun application-state-plist (state)
  "Return the application-state data as a plist."
  (let ((data (application-state-data state)))
    (if (hash-table-p data)
      (hash-table->plist data)
      data)))

(defgeneric get-component-by-path (app-state component-id-path)
  (:documentation "Retrieve a component instance from APP-STATE using its ID path."))

(defmethod get-component-by-path ((app-state application-state) component-id-path)
  (declare (type list component-id-path))
  (let ((components-path (append '(:components) component-id-path '(:component-instance))))
    (get-path components-path (application-state-data app-state) nil)))
