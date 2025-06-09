;;;===============================================================
;;; File: src/state/state.lisp
;;; Comprehensive Elm State Management (Transactional, Observable, Thread-safe)
(uiop:define-package :elmtui.state
  (:use :cl)
  (:import-from :elmtui.state.api ; Import from the central API
   :application-state :make-application-state :state-ref :get-state :set-state
   #:application-state-data
   :with-transaction :undo-last-transaction
   :update-result :make-update-result :ur-patches :ur-commands
   :merge-patch :merge-patches
   :get-path :set-path :remove-path
                :get-component-by-path :store-component-at-path :remove-component-at-path
   :ur-has-command-p :ur-add-command)
  (:import-from :elmtui.core.globals
   :*app-state*)
  ;; Import lower-level statelib components if they are not exposed via elmtui.state.api
  ;; but are needed for the implementation details within elmtui.state.
  (:import-from :elmtui.statelib.state
   ;; :application-state :make-application-state :state-ref :get-state :set-state ; Now from API
   :with-state :with-comp-state :state-if-unset-else ; Keep if specific to this level
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
   ;; If any symbols defined *directly* in this file (elmtui.state) are meant to be part of the API,
   ;; they should be exported from elmtui.state.api.
   ;; For example, if merge-patch, get-path etc. are defined here, they are exported via elmtui.state.api.
   ;; The `update-result` struct and its methods are defined here and exported via the API.
   :update-result :make-update-result :ur-patches :ur-commands
   :ur-has-command-p :ur-add-command
   :merge-patch :merge-patches
   :get-path :set-path :remove-path
   :get-component-by-path :store-component-at-path :remove-component-at-path
   :rollback-state ; Defined here, should be in API exports if public
   ;; Also, re-export core types if this is their canonical definition point for the API
   :application-state :make-application-state :state-ref :get-state :set-state
   :with-transaction
   ))

(in-package :elmtui.state)

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
(defun get-path (data path &optional default)
  "Retrieves a value from a nested plist using a list of keys (path)."
  (loop with current-data = data
        for key in path
        do (if (and (listp current-data) (evenp (length current-data)))
               (multiple-value-bind (value foundp) (getf current-data key)
                 (declare (ignore foundp)) ; Ignore foundp, we just want the value
                 (setf current-data value)) ; Key not found in path
               (return default)) ; Path broken (non-plist encountered)
        finally (return current-data)))

(defun set-path (data path new-value)
  "Sets a value in a nested plist using a list of keys (path).
   Creates intermediate plists if they don't exist.
   Returns a new plist with the modification."
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

(defun remove-path (data path)
  "Removes a key-value pair from a nested plist.
   Returns a new plist with the modification, or original if path not found or data is nil."
  (if (or (null path) (null data)) (return-from remove-path data))
  (let ((key (car path))
        (rest-path (cdr path)))
    (if (null rest-path) ; Key to remove is at this level
        (if (nth-value 1 (getf data key)) ; Check if key exists before copying and remf-ing
            nil
            ;; (let ((new-data (copy-list data))) ;; MODIFIED: was nil, now proper remf
            ;;   (remf new-data key)
            ;;   new-data)
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
(defun merge-patch (state-plist patch)
  "Merges a single patch into the state plist. Returns new state-plist.
A patch is a list: (path-list new-value).
If new-value is :elmtui-delete-path, the path is removed."
  (let ((path (first patch))
        (value (second patch)))
    (if (eq value :elmtui-delete-path)
        (remove-path state-plist path)
        (set-path state-plist path value))))

(defun merge-patches (state-plist patches)
  "Merges a list of patches into the state plist. Returns new state-plist."
  (reduce #'(lambda (current-state p) (merge-patch current-state p))
          patches
          :initial-value state-plist))

(defun get-component-by-path (app-state component-id-path)
  "Retrieves a component instance from the application state using its ID path.
   The component itself is stored under '(:components <id1> <id2> ... :component-instance)."
  (get-path (application-state-data app-state) ; Operate on the internal data plist
            (append '(:components) component-id-path '(:component-instance))))

(defun store-component-at-path (app-state component-id-path component-instance)
  "Stores a component instance in the application state at the given ID path. Returns new app-state data plist."
  (let ((full-path (append '(:components) component-id-path '(:component-instance))))
    ;; This should operate on the internal data of app-state and return the new data plist
    ;; The caller (e.g. defupdate) would then update the app-state struct.
    ;; OR, if this is meant to be a direct mutation, it needs to use the transaction mechanism.
    ;; For now, assuming it returns a new plist for functional purity within merge-patches.
    (set-path (application-state-data app-state) full-path component-instance)))

(defun remove-component-at-path (app-state component-id-path)
  "Removes a component instance and its state from the application state at the given ID path.
   This removes the specific :component-instance and the entire state subtree for that component ID path.
   Returns new app-state data plist."
  (let* ((instance-path (append '(:components) component-id-path '(:component-instance)))
         (state-subtree-path (append '(:components) component-id-path))
         (current-data (application-state-data app-state))
         (temp-data (remove-path current-data instance-path))
         (final-data (remove-path temp-data state-subtree-path)))
    final-data))

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

