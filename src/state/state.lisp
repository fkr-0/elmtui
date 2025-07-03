;;;===============================================================
;;; File: src/state/state.lisp
;;; Comprehensive Elm State Management (Transactional, Observable, Thread-safe)
;; Public package for state management
(uiop:define-package :elmtui.state
  (:use :cl )
  (:import-from :elmtui.state.api ; Import from the central API
   :application-state :make-application-state :state-ref :get-state :set-state

   #:application-state-data #:state-data #:state-data-data
   :with-transaction :undo-last-transaction
   :update-result :make-update-result :ur-patches :ur-commands
   :ur-has-command-p)
  (:import-from :elmtui.core.globals
   :*app-state*)
  ;; Import the conditions package directly to avoid qualified references
  (:import-from :elmtui.core.conditions
   :async-task-error :log-condition)
  ;; Import lower-level statelib components if they are not exposed via elmtui.state.api
  ;; but are needed for the implementation details within elmtui.state.
  (:import-from :elmtui.state.api
   ;; :application-state :make-application-state :state-ref :get-state :set-state ; Now from API
   #:app-state
                :with-state :with-comp-state :state-if-unset-else ; Keep if specific to this level
                #:app-state-p
                :application-state-observers :application-state-lock
                :application-state-transaction-log :application-state-transaction-history
                :log-state-data)
  (:import-from :elmtui.statelib.transaction
   :start-transaction :commit-transaction :rollback-transaction ; Keep if specific
                :transaction-open-p)
  ;; (:import-from :elmtui.statelib.observe ...) ; If needed

  ;; Define what this package EXPORTS. Since elmtui.state.api is the public interface,
  ;; this package might not need to export much, or it re-exports specific API symbols
  ;; if it provides the canonical implementation for them.
  ;; For now, assuming elmtui.state.api handles all public exports.
  ;; If elmtui.state defines functions that are part of the API, they should be exported there.
  (:export
   :with-async-restarts ; This is a utility for async task handling, not part of the API
   ;; Functions defined here that are exported to the public API
   :merge-patch :merge-patches
   :get-path :set-path :remove-path
   :get-component-by-path :store-component-at-path :remove-component-at-path
   :rollback-state 
   ;; Re-exports from other packages that are part of this package's interface
   :update-result :make-update-result :ur-patches :ur-commands
   :ur-has-command-p
   :application-state :make-application-state :state-ref :get-state :set-state
   :with-transaction
   ))

(in-package :elmtui.state)

(declaim (ftype (function () t) rollback-state))
;;;--------------------------------------------------------------
;;; Update Result Structure (defined here, exported via API)
;;;--------------------------------------------------------------

;; Define the rollback function expected by with-async-restarts
(defun rollback-state ()
  "Rolls back the last transaction on the global *app-state*."
  ;; undo-last-transaction is now imported from elmtui.state.api,
  ;; which should export it from elmtui.state.transactions.
  (undo-last-transaction elmtui.core.globals:*app-state*))

;;;--------------------------------------------------------------
;;; Path Utilities for Plists (Functional: return new plists on change)
;;; (defined here, exported via API)
;;;--------------------------------------------------------------
;; (declaim (ftype (function ((or list hash-table application-state elmtui.state.api:app-state) list &optional t) t) get-path))
(defun get-path (data path &optional default)
  "Retrieves a value from nested data using a list of keys (path).
Supports plists, hash-tables, application-state, and app-state structures."
  (declare (type (or list hash-table application-state app-state) data)
           (type list path)
           (type t default))
  (cond
    ;; Enhanced app-state structure
    ((app-state-p data)
     (elmtui.state.api:get-path-enhanced data path default))
    ;; Application-state structure
    ((app-state-p data)
     (elmtui.state.api:get-path-enhanced data path default))
    ;; Direct hash-table
    ;; ((hash-table-p data)
    ;;  (elmtui.state.api:resolve-path-in-hash data path default))
    ;; Plist (original implementation)
    ((listp data)
     (check-type path list)
     (loop with current-data = data
           for key in path
           do (if (and (listp current-data) (evenp (length current-data)))
                  (multiple-value-bind (value foundp) (getf current-data key)
                    (declare (ignore foundp))
                    (setf current-data value))
                  (return default))
           finally (return current-data)))
    ;; (t (error "Unsupported data type for get-path: ~S" (type-of data)))
    ))

(declaim (ftype (function (list list t) list) set-path))
(defun set-path (data path new-value)
  "Sets a value in a nested plist using a list of keys (path).
   Creates intermediate plists if they don't exist.
   Returns a new plist with the modification."
  (declare (type list data path)
           (type t new-value))
  (check-type data list)
  (check-type path list)
  (if (null path) (error "Path cannot be empty for set-path"))
  (let ((key (car path))
        (rest-path (cdr path)))
    (let ((new-data (copy-list  data ))) ; Copy current level
      (if (null rest-path) ; At the level to set the value
          (setf (getf new-data key) new-value)
          (let ((current-child (getf new-data key)))
            ;; Ensure child is a plist for recursion, otherwise start fresh
            (unless (and (listp current-child) (evenp (length current-child)))
              (setf current-child nil))
            (setf (getf new-data key) (set-path current-child rest-path new-value))))
      new-data)))

(declaim (ftype (function (list list) list) remove-path))
(defun remove-path (data path)
  "Removes a key-value pair from a nested plist.
   Returns a new plist with the modification, or original if path not found or data is nil."
  (declare (type list data path))
  (check-type data list)
  (check-type path list)
  (if (or (null path) (null data)) (return-from remove-path data))
  (let ((key (car path))
        (rest-path (cdr path)))
    (if (null rest-path) ; Key to remove is at this level
        ;; Check if key exists before copying and remf-ing
        (if (getf data key nil) ; Use getf with default nil to check existence
            (let ((new-data (copy-list data)))
              (remf new-data key)
              new-data)
            data) ; Key not found, return original data
        (let ((child (getf data key)))
          (if (and (listp child) (evenp (length child))) ; If child is a plist, recurse
              (let ((new-child (remove-path child rest-path)))
                (if (eq child new-child) ; No change in child, return original data
                    data
                    (let ((new-data (copy-list data))) ; Child changed, create new parent
                      (setf (getf new-data key) new-child)
                      new-data)))
              data))))) ; Child not a plist or doesn't exist, no change, return original data

;;;--------------------------------------------------------------
;;; State Patching and Component Path Management
;;; (defined here, exported via API)
;;;--------------------------------------------------------------
;; Use the same FTYPE signature as defined in the API
;; Ensure FTYPE matches the API expectation
(declaim (ftype (function ((or list hash-table) list) (or list hash-table)) merge-patch))
(defun merge-patch (state-data patch)
  "Merges a single patch into the state data. Returns updated data.
Patch is a list: (path-list new-value). If new-value is :elmtui-delete-path, removes the path.
Supports both hash-table and plist based state-data."
  ;; Handle both hash-tables and lists directly, not state-data structs
  (declare (type (or hash-table list) state-data)
           (type list patch))
  (check-type state-data (or hash-table list))
  (check-type patch list)
  (unless (and (= (length patch) 2) (listp (first patch)))
    (error "Invalid patch format. Expected (path-list new-value), got ~S" patch))
  
  (let ((path (first patch))
        (value (second patch)))
    (cond
      ;; Hash-table backing: only simple top-level keys supported
      ((hash-table-p state-data)
       (if (and (listp path) (= (length path) 1))
           (let ((key (first path)))
             (if (eq value :elmtui-delete-path)
                 (remhash key state-data)
                 (setf (gethash key state-data) value))
             state-data)
           (error "Unsupported nested path on hash-table state: ~S" path)))
      ;; Plist backing: delegate to existing utilities
      ((listp state-data)
       (if (eq value :elmtui-delete-path)
           (remove-path state-data path)
           (set-path state-data path value)))
      ;; (t (error "Unsupported state type ~S for merging patch" state-data))
      )))

;; Declare the function type that matches the API expectation

(defun merge-patches (state-data patches)
  "Merges a list of patches or a property list into the state data.
Handles hash-tables, plists, application-state, and app-state structures.
Returns the updated state-data."
  (declare (type (or hash-table list application-state app-state) state-data)
           (type list patches))

  ;; Use enhanced API if available, otherwise fall back to original implementation
  (cond
    ;; Enhanced app-state or application-state
    ((or (app-state-p state-data)
         (app-state-p state-data))
     (elmtui.state.api:apply-patches-enhanced state-data patches))
    ;; Hash-table or plist (original implementation with normalization)
    (t
     (check-type state-data (or hash-table list))
     (check-type patches list)

     ;; Normalize property list form '(:k1 v1 :k2 v2 ...)' into list of patch pairs ((k1) v1) ...
     (let* ((patch-list
              (cond
                ((and (listp patches)
                      (every #'atom patches)
                      (evenp (length patches)))
                 (loop for (k v) on patches by #'cddr
                       collect (list (list k) v)))
                ((listp patches) patches)
                ;; (t (error "Invalid patches format: ~S" patches))
                )))
       (cond
         ((hash-table-p state-data)
          ;; Destructively apply each patch to the hash-table
          (dolist (p patch-list state-data)
            (merge-patch state-data p)))
         ((listp state-data)
          ;; Merge into new plist
          (reduce (lambda (current-state p)
                    (merge-patch current-state p))
                  patch-list
                  :initial-value state-data))
         ;; (t (error "Unsupported state type ~S for merging patches" state-data))
         )))))

(declaim (ftype (function (application-state list) t) get-component-by-path))
(defun get-component-by-path (app-state component-id-path)
  "Retrieves a component instance from the application state using its ID path.
   The component itself is stored under '(:components <id1> <id2> ... :component-instance)."
  (declare (type application-state app-state)
           (type list component-id-path))
  (check-type app-state application-state)
  (check-type component-id-path list)
  
  ;; Get the raw application state data
  (let* ((app-data (application-state-data app-state))
         (components-path (append '(:components) component-id-path '(:component-instance))))
    ;; If app-data is a state-data struct, get its hash-table data
    (if (typep app-data 'state-data)
        ;; Since state-data.data is always a hash-table, handle it specially
        (let ((hash-table-data (state-data-data app-data)))
          ;; Use get-path which will handle hash-table data
          (if (and (listp components-path) (= (length components-path) 1))
              (gethash (first components-path) hash-table-data)
              ;; For nested paths in a hash-table (not well supported)
              (error "Nested paths in hash-table not supported: ~S" components-path)))
        ;; If app-data is a direct plist, use get-path normally
        (get-path app-data components-path))))

(declaim (ftype (function (application-state list t) (or list hash-table)) store-component-at-path))
(defun store-component-at-path (app-state component-id-path component-instance)
  "Stores a component instance in the application state at the given ID path. Returns new app-state data (plist or hash-table)."
  (declare (type application-state app-state)
           (type list component-id-path)
           (type t component-instance))
  (check-type app-state application-state)
  (check-type component-id-path list)
  
  ;; Get the raw application state data and modify it
  (let* ((app-data (application-state-data app-state))
         (full-path (append '(:components) component-id-path '(:component-instance))))
    ;; If app-data is a state-data struct, get its hash-table data
    (if (typep app-data 'state-data)
        ;; Since state-data.data is always a hash-table, handle it specially
        (let ((hash-table-data (state-data-data app-data)))
          ;; Handle storing in hash-table (direct key only for simplicity)
          (if (and (listp full-path) (= (length full-path) 1))
              (progn 
                (setf (gethash (first full-path) hash-table-data) component-instance)
                hash-table-data)
              ;; For now, error on nested paths in hash-tables 
              (error "Nested paths in hash-table not supported: ~S" full-path)))
        ;; If app-data is a direct plist, use set-path normally
        (set-path app-data full-path component-instance))))

(declaim (ftype (function (application-state list) list) remove-component-at-path))
(defun remove-component-at-path (app-state component-id-path)
  "Removes a component instance and its state from the application state at the given ID path.
   This removes the specific :component-instance and the entire state subtree for that component ID path.
   Returns new app-state data plist."
  (declare (type application-state app-state)
           (type list component-id-path))
  (check-type app-state application-state)
  (check-type component-id-path list)
  
  ;; Get the raw application state data
  (let* ((app-data (application-state-data app-state))
         (instance-path (append '(:components) component-id-path '(:component-instance)))
         (state-subtree-path (append '(:components) component-id-path)))
    
    ;; If app-data is a state-data struct, get its hash-table data
    (if (typep app-data 'state-data)
        ;; Since state-data.data is always a hash-table, handle it specially
        (let ((hash-table-data (state-data-data app-data)))
          ;; Handle removing from hash-table (direct key only for simplicity)
          (if (and (listp instance-path) (= (length instance-path) 1))
              (progn
                (remhash (first instance-path) hash-table-data)
                ;; Also remove the subtree key if present
                (when (and (listp state-subtree-path) (= (length state-subtree-path) 1))
                  (remhash (first state-subtree-path) hash-table-data))
                '()) ; Return empty list to represent success
              ;; For now, error on nested paths in hash-tables
              (error "Nested paths in hash-table not supported: ~S" instance-path)))
        ;; If app-data is a direct plist, use remove-path normally
        (let ((temp-data (remove-path app-data instance-path))
              (final-data (remove-path app-data state-subtree-path)))
          final-data))))

;; Ensure application-state-data is accessible if used directly
;; This might need to be an exported accessor from elmtui.statelib.state if not already.
;; For now, assuming it's available or elmtui.state.api :application-state implies the structure.

;;; API CONTRACTS (adjusted for new flow):
;; - The public API is defined in elmtui.state.api.
;; - State is managed in an `application-state` object (internally a hash-table based plist).
;; - Mutations are typically done via `defupdate` which uses `with-transaction`.
;; - `update-result` structs carry patches `((path value) ...)` and commands.
;; - `merge-patches` applies these patches to a state plist.
;; - `defupdate` should be responsible for taking the `application-state` object,
;;   extracting its data, applying `merge-patches` to this data, and then
;;   setting the new data back into the `application-state` object, all within a transaction.


(defmacro with-async-restarts ((condition-var) &body forms) ; Renamed body to forms
  "Handle async task failures with DRY restarts: ignore, rollback, replace, provide result."
  `(block with-async-restarts
     (handler-bind
         ((async-task-error
            (lambda (,condition-var)
              (log-condition ,condition-var)
              (restart-case
                  (signal ,condition-var)
                (ignore-task ()
                  :report "Ignore/discard this async task."
                  (return-from with-async-restarts nil))
                (rollback-state ()
                  :report "Rollback state to previous checkpoint."
                  ;; Use fully qualified name as state is loaded first now
                  (when (fboundp 'elmtui.state:rollback-state) (funcall #'rollback-state))
                  (return-from with-async-restarts nil))
                (replace-task (new-task)
                  :report "Replace the async task interactively or programmatically."
                  ;; Return the new task value, don't funcall body
                  (return-from with-async-restarts new-task))
                (provide-result (result)
                  :report "Provide a custom result for this task."
                  (return-from with-async-restarts result))
                (retry ()
                  :report "Retry the async task."
                  (return-from with-async-restarts (progn ,@forms))))))) ; Use forms
       ,@forms))) ; Use forms
