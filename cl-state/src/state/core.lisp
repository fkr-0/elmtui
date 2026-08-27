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
  (observers nil)
  (frozen-p nil))

(setf (documentation 'application-state-data 'function)
      "Low-level representation accessor for APPLICATION-STATE.

This accessor exposes the live backing container and is intentionally confined
to CL-STATE.CORE. Application code should use STATE-REF for a borrowed path
read, STATE-VALUE for an owned path value, or STATE-SNAPSHOT for an owned whole
model. Destructive mutation through this representation accessor bypasses state
locking, versioning, observers, history, and strict snapshot guarantees.")

(defparameter *state-mutation-policy* :allow
  "Dynamic policy for APPLICATION-STATE mutation through the CL-STATE API.

:ALLOW permits mutation. :FORBID signals STATE-MUTATION-FORBIDDEN before a
supported mutator changes logical state. ElmTUI binds :FORBID while executing
strict-Elm user decision/view/subscription code, then restores :ALLOW for the
internal fresh-state commit.")

(define-condition state-mutation-forbidden (error)
  ((state :initarg :state :reader state-mutation-forbidden-state)
   (path :initarg :path :initform nil :reader state-mutation-forbidden-path)
   (operation :initarg :operation :initform :mutation
              :reader state-mutation-forbidden-operation))
  (:documentation
   "Signaled when a supported CL-STATE mutator is used during a read-only state phase.")
  (:report
   (lambda (condition stream)
     (format stream "State mutation ~S is forbidden~@[ at path ~S~]; the state is frozen or the current state policy is read-only."
             (state-mutation-forbidden-operation condition)
             (state-mutation-forbidden-path condition)))))

(setf (documentation 'state-mutation-forbidden 'type)
      "Condition signaled when supported state mutation is forbidden by the current dynamic policy."
      (documentation 'state-mutation-forbidden-state 'function)
      "Return the APPLICATION-STATE whose mutation was rejected."
      (documentation 'state-mutation-forbidden-path 'function)
      "Return the state path associated with a rejected mutation, or NIL when not path-specific."
      (documentation 'state-mutation-forbidden-operation 'function)
      "Return the operation keyword describing the rejected state mutation.")

(defun assert-state-mutation-allowed (state &key path (operation :mutation))
  "Signal STATE-MUTATION-FORBIDDEN when STATE is frozen or dynamically read-only."
  (when (and (application-state-p state)
             (or (application-state-frozen-p state)
                 (eq *state-mutation-policy* :forbid)))
    (error 'state-mutation-forbidden
           :state state
           :path path
           :operation operation))
  state)

(defun %normalize-backend (backend)
  (ecase backend
    (:hash-table :hash-table)
    (:plist :plist)))

(defun %coerce-initial (initial backend)
  (let ((backend* (%normalize-backend backend)))
    (cond
      ((null initial) (coerce-data nil backend*))
      ((application-state-p initial)
       (coerce-data (copy-state-value (application-state-data initial)) backend*))
      ((hash-table-p initial)
       (coerce-data (copy-state-value initial) backend*))
      ((listp initial)
       (when (and (eq backend* :hash-table)
                  (not (cl-state.utils::%plist-like-p initial)))
         (error "Expected plist-like initial state for :HASH-TABLE backend, got ~S" initial))
       (coerce-data (copy-state-value initial) backend*))
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
+ Supported mutable containers in ~:initial~ are recursively copied before storage, so the new state owns its container graph.
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
  (assert-state-mutation-allowed state :operation :set-backend)
  (let* ((backend* (%normalize-backend backend))
          (data (coerce-data (application-state-data state) backend*)))
    (setf (application-state-data state) data
      (application-state-backend state) backend*)
    state))

(defvar *transaction-active* nil
  "True while a CL-STATE transaction boundary is active.")

(defvar *transaction-states* nil
  "Stack of APPLICATION-STATE values currently owned by transaction boundaries.")

(defun transaction-active-p (&optional state)
  "Return true when a transaction is active, optionally for STATE specifically."
  (and *transaction-active*
       (or (null state)
           (member state *transaction-states* :test #'eq))))

(defun deep-copy-data (data)
  "Compatibility alias for COPY-STATE-VALUE.

New state-boundary code should call COPY-STATE-VALUE explicitly so custom leaf
specializations participate in ownership transfer."
  (copy-state-value data))

(defun deep-copy-application-state (app)
  (let ((data (application-state-data app)))
    (make-application-state
      :data (deep-copy-data data)
      :backend (application-state-backend app)
      :lock (bt:make-lock "cl-state.lock")
      :log (deep-copy-data (application-state-log app))
      :history (copy-list (application-state-history app))
      :undone (copy-list (application-state-undone app))
      :version (application-state-version app)
      :observers (copy-list (application-state-observers app))
      :frozen-p nil)))


(defun valid-state-path-p (path)
  "Return true when PATH is a symbol or a proper list of non-NIL symbols."
  (or (symbolp path)
      (and (listp path)
           (every (lambda (part) (and part (symbolp part))) path))))

(defun assert-valid-state-path (path)
  (unless (valid-state-path-p path)
    (error "Invalid state path ~S. Expected a symbol or proper list of non-NIL symbols." path))
  path)

(defgeneric state-ref (place key &optional default)
  (:documentation "Return the logical value at KEY without copying it.

For APPLICATION-STATE this is a borrowed read: container values may be shared
with strict snapshots and must not be destructively modified. Use STATE-VALUE
when the caller needs an owned mutable copy."))

(defmethod state-ref ((state application-state) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key (application-state-data state) default))

(defmethod state-ref ((state hash-table) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key state default))

(defmethod state-ref ((state list) (key t) &optional default)
  (assert-valid-state-path key)
  (get-path key state default))

(defun state-value (state key &optional default)
  "Return an owned logical copy of the value at KEY in STATE.

Unlike STATE-REF, the returned value can be destructively modified without
changing STATE, subject to COPY-STATE-VALUE methods for custom leaf types."
  (copy-state-value (state-ref state key default)))

(defun state-snapshot (state)
  "Return an owned copy of STATE's complete logical model.

APPLICATION-STATE metadata such as locks, observers, history, and undo stacks is
not part of this value. Raw hash-table/list inputs are copied directly."
  (etypecase state
    (application-state (copy-state-value (application-state-data state)))
    (hash-table (copy-state-value state))
    (list (copy-state-value state))))

(defun state-frozen-p (state)
  "Return true when STATE is a frozen APPLICATION-STATE snapshot."
  (and (application-state-p state)
       (application-state-frozen-p state)))

(defmethod get-path (path (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod get-path ((path list) (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod get-path ((path symbol) (state application-state) &optional default)
  (cl-state.utils:get-path path (application-state-data state) default))

(defmethod (setf state-ref) (value (state application-state) (key t))
  "Atomically store VALUE at KEY inside STATE and log the change."
  (assert-valid-state-path key)
  (assert-state-mutation-allowed state :path key :operation :set)
  (bt:with-lock-held ((application-state-lock state))
    (let* ((data (application-state-data state))
           (old (get-path key data :not-present))
           (data* (set-path data key value)))
      (setf (application-state-data state) data*)
      (push (list key old value) (application-state-log state))
      (incf (application-state-version state))
      (unless (transaction-active-p state)
        (cl-state.observer:notify-observers
         state key old value :phase :direct-mutation))
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
  "Set VALUE at KEY through the supported STATE-REF mutation path.

For APPLICATION-STATE this mutates logical state, appends a log entry, increments
VERSION, and notifies observers after the mutation unless STATE is inside its
own transaction. Observer failure does not undo a direct mutation. Strict or
frozen application states reject before mutation. Example: use STATE-SET with
KEY (:USER :NAME) and VALUE Ada to update a nested user name."
  (setf (state-ref state key) value))

(defun application-state-plist (state)
  "Return an owned plist representation of STATE's logical model."
  (let ((data (state-snapshot state)))
    (if (hash-table-p data)
        (hash-table->plist data)
        data)))

(defgeneric get-component-by-path (app-state component-id-path)
  (:documentation "Retrieve a component instance from APP-STATE using its ID path."))

(defmethod get-component-by-path ((app-state application-state) component-id-path)
  (declare (type list component-id-path))
  (let ((components-path (append '(:components) component-id-path '(:component-instance))))
    (get-path components-path (application-state-data app-state) nil)))
