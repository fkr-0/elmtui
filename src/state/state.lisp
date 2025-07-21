;;;===============================================================
;;; File: src/state/state.lisp
;;; Comprehensive Elm State Management (Transactional, Observable, Thread-safe)
;; Public package for state management
(uiop:define-package :elmtui.state
  (:use :cl )

  ;; (:import-from :elmtui.state.utils #:get-path #:set-path #:remove-path)
  ;; (:import-from :elmtui.state.api ; Import from the central API
  ;;  #:application-state #:make-application-state #:state-ref #:get-state #:set-state
  ;;  #:application-state-p
  ;;  #:application-state-data #:state-data #:state-data-data
  ;;               :with-transaction :undo-last-transaction
  ;;               :update-result :make-update-result :ur-patches :ur-commands
  ;;               :ur-has-command-p)
  (:import-from :elmtui.core.globals
   :*app-state*)
  (:import-from :elmtui.utils
                #:get-path #:set-path #:remove-path)
  ;; Import the conditions package directly to avoid qualified references
  (:import-from :elmtui.core.conditions
   :async-task-error :log-condition)
  ;; Import lower-level statelib components if they are not exposed via elmtui.state.api
  ;; but are needed for the implementation details within elmtui.state.
  (:import-from :elmtui.tea-state.state
                #:application-state-data)
  (:import-from :elmtui.tea-state.api
   ;; :application-state :make-application-state :state-ref :get-state :set-state ; Now from API
   #:undo
   #:application-state
   :with-state :with-comp-state :state-if-unset-else ; Keep if specific to this level
                :application-state-observers :application-state-lock
                :application-state-transaction-log :application-state-transaction-history
                :log-state-data)
  ;; (:import-from :elmtui.statelib.transaction
  ;;  :start-transaction :commit-transaction :rollback-transaction ; Keep if specific
  ;;               :transaction-open-p)
  ;; (:import-from :elmtui.statelib.observe ...) ; If needed

  ;; Define what this package EXPORTS. Since elmtui.state.api is the public interface,
  ;; this package might not need to export much, or it re-exports specific API symbols
  ;; if it provides the canonical implementation for them.
  ;; For now, assuming elmtui.state.api handles all public exports.
  ;; If elmtui.state defines functions that are part of the API, they should be exported there.
  (:export
   :with-async-restarts ; This is a utility for async task handling, not part of the API
   ;; Functions defined here that are exported to the public API
   #:app-state-p
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
  (undo elmtui.core.globals:*app-state*))

;;;--------------------------------------------------------------
;;; Path Utilities for Plists (Functional: return new plists on change)
;;; (defined here, exported via API)
;;;--------------------------------------------------------------
;; (declaim (ftype (function ((or list hash-table application-state elmtui.state.api:app-state) list &optional t) t) get-path))
;; (defun get-path (data path &optional default)
;;   "Recursively retrieves a value from a nested structure of plists and hash-tables."
;;   (declare (type list path))
;;   (if (null path)
;;       data
;;       (let ((key (first path))
;;             (rest-path (rest path)))
;;         (cond
;;           ((hash-table-p data)
;;            (multiple-value-bind (value foundp) (gethash key data)
;;              (if foundp
;;                  (get-path value rest-path default)
;;                  default)))
;;           ((listp data)
;;            (let ((value (getf data key default)))
;;              (if (eq value default)
;;                  default
;;                  (get-path value rest-path default))))
;;           (t default)))))
;;; -----------------------------------------
;;; 2-D dispatch: (data-type × path-type)
;;; -----------------------------------------

;; (defgeneric get-path (data path &optional default)
;;   (:documentation "Retrieve a nested value designated by PATH from DATA.
;;    Return DEFAULT when any intermediate lookup fails."))

;; ;;; ──────────────────────────────────────────
;; ;;; Base cases (PATH exhausted)
;; ;;; ──────────────────────────────────────────
;; (defmethod get-path (data (path null) &optional default)
;;   ;; PATH is NIL ⇒ we have arrived
;;   (declare (ignore default))
;;   data)

;; ;;; ──────────────────────────────────────────
;; ;;; HASH-TABLE containers
;; ;;; ──────────────────────────────────────────
;; (defmethod get-path ( (key symbol) (table hash-table) &optional default)
;;   (multiple-value-bind (val foundp) (gethash key table)
;;     (if foundp val default)))

;; (defmethod get-path ((table hash-table) (path cons) &optional default)
;;   (let* ((key  (car path))
;;          (rest (cdr path))
;;          (next (get-path table key default)))
;;     (if (eq next default)
;;         default
;;         (get-path rest next default))))

;; ;;; ──────────────────────────────────────────
;; ;;; PLIST (property-list) containers
;; ;;; ──────────────────────────────────────────
;; ;; (defmethod get-path ((plist list) (key symbol) &optional default)
;; ;;   (getf plist key default))

;; ;; (defmethod get-path ((plist list) (path cons) &optional default)
;; ;;   (let* ((key  (car path))
;; ;;          (rest (cdr path))
;; ;;          (next (get-path key plist default)))
;; ;;     (if (eq next default)
;; ;;         default
;; ;;         (get-path next rest default))))

;; (defun alist-p (obj)
;;   "Heuristic: every element is a dotted pair."
;;   (and (listp obj)
;;        (every #'consp obj)))

;; (defmethod get-path ((lst list) (key symbol) &optional default)
;;   (cond
;;     ((alist-p lst)
;;      (let ((pair (assoc key lst)))
;;        (if pair (cdr pair) default)))
;;     (t                         ; treat as plist
;;      (getf lst key default))))

;; (defmethod get-path ((lst list) (path cons) &optional default)
;;   (cond
;;     ((alist-p lst)
;;      (let* ((pair (assoc (car path) lst)))
;;        (if pair
;;            (get-path (cdr pair) (cdr path) default)
;;            default)))
;;     (t ;; plist
;;      (let* ((val (getf lst (car path) default)))
;;        (if (eq val default)
;;            default
;;            (get-path val (cdr path) default))))))
;; ;;; ──────────────────────────────────────────
;; ;;; Fallback for unsupported DATA
;; ;;; ──────────────────────────────────────────
;; (defmethod get-path ((data t) (path t) &optional default)
;;   (declare (ignore data path))
;;   default)

;; (declaim (ftype (function (list list t) list) set-path))
;; (defun set-path (data path new-value)
;;   "Sets a value in a nested structure of plists and hash-tables."
;;   (if (null path)
;;       new-value
;;       (let ((key (first path))
;;             (rest-path (rest path)))
;;         (cond
;;           ((hash-table-p data)
;;            (setf (gethash key data) (set-path (gethash key data) rest-path new-value))
;;            data)
;;           ((listp data)
;;            (let ((new-data (copy-list data)))
;;              (setf (getf new-data key) (set-path (getf data key) rest-path new-value))
;;              new-data))
;;           (t (set-path (if (keywordp key) '() (make-hash-table)) path new-value))))))

;; (declaim (ftype (function (list list) list) remove-path))
;; (defun remove-path (data path)
;;   "Removes a key-value pair from a nested plist.
;;    Returns a new plist with the modification, or original if path not found or data is nil."
;;   (declare (type list data path))
;;   (check-type data list)
;;   (check-type path list)
;;   (if (or (null path) (null data)) ;;         (setf (getf new-data key ;; Use getf to set the value
;;                                         ;                                  :test #'equal) new-value
;;       data
;;       (let ((key (car path))
;;             (rest-path (cdr path)))
;;         (if (null rest-path) ; Key to remove is at this level
;;             ;; Check if key exists before copying and remf-ing
;;             (if (getf data key nil) ; Use getf with default nil to check existence
;;                 (let ((new-data (copy-list data)))
;;                   (remf new-data key)
;;                   new-data)
;;                 data) ; Key not found, return original data
;;             (let ((child (getf data key)))
;;               (if (and (listp child) (evenp (length child))) ; If child is a plist, recurse
;;                   (let ((new-child (remove-path child rest-path)))
;;                     (if (eq child new-child) ; No change in child, return original data
;;                         data
;;                         (let ((new-data (copy-list data))) ; Child changed, create new parent
;;                           (setf (getf new-data key) new-child)
;;                           new-data)))
;;                   data)))))) ; Child not a plist or doesn't exist, no change, return original data

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
  (declare (type (or hash-table list application-state) state-data)
           (type list patches))

  ;; Use enhanced API if available, otherwise fall back to original implementation
  (cond
    ;; Enhanced app-state or application-state
    ((or (typep state-data 'hash-table)
         (typep state-data 'elmtui.tea-state.api:application-state))
     (let ((new-data (merge-patches
                      (application-state-data state-data)
                      patches)))
       (setf (application-state-data state-data) new-data)
       state-data))
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
                ((listp patches)
                 (remove-if-not (lambda (p)
                                  (and (listp p)
                                       (= (length p) 2)
                                       (listp (first p))))
                                patches))
                ;; (t (error "Invalid patches format: ~S" patches))
                )))
       (cond
         ;; ((hash-table-p state-data)
         ;;  ;; Destructively apply each patch to the hash-table
         ;;  (dolist (p patch-list state-data)
         ;;    (ignore-errors (merge-patch state-data p))))
         ((listp state-data)
          ;; Merge into new plist
          (reduce (lambda (current-state p)
                    (ignore-errors (merge-patch current-state p)))
                  patch-list
                  :initial-value state-data))
         ;; (t (error "Unsupported state type ~S for merging patches" state-data))
         )))))

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
          (get-path components-path hash-table-data)
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

(defmethod get-component-by-path (root path)
  "Fallback method for unsupported root types."
  (declare (ignore root path))
  (error "get-component-by-path is not implemented for this object type."))

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
    (if (typep app-data 'hash-table)
        ;; Since state-data.data is always a hash-table, handle it specially
        (let ((hash-table-data app-data))
          ;; Handle storing in hash-table (direct key only for simplicity)
          (if (and (listp full-path) (= (length full-path) 1))
              (progn
                (setf (gethash (first full-path) hash-table-data) component-instance)
                hash-table-data)
              ;; For now, error on nested paths in hash-tables
              (error "Nested full-paths in hash-table not supported: ~S"
                     full-path)))
        ;; If app-data is a direct plist, use set-path normally
        ;; (set-path app-data full-path component-instance)
        )))

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
    (if (typep app-data 'hash-table)
        ;; Since state-data.data is always a hash-table, handle it specially
        (let ((hash-table-data  app-data))
          ;; Handle removing from hash-table (direct key only for simplicity)
          (if (and (listp instance-path) (= (length instance-path) 1))
              (progn
                (remhash (first instance-path) hash-table-data)
                ;; Also remove the subtree key if present
                (when (and (listp state-subtree-path) (= (length state-subtree-path) 1))
                  (remhash (first state-subtree-path) hash-table-data))
                '()) ; Return empty list to represent success
              ;; For now, error on nested paths in hash-tables
              (error "Nested instance-paths in hash-table not supported: ~S"
                     instance-path)))
        ;; If app-data is a direct plist, use remove-path normally
        ;; (let ((temp-data (remove-path app-data instance-path))
        ;;       (final-data (remove-path app-data state-subtree-path)))
        ;;   final-data)
        )))

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
