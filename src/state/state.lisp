;;;===============================================================
;;; File: src/state/state.lisp
;;; Comprehensive Elm State Management (Transactional, Observable, Thread-safe)
(uiop:define-package :elmtui.state
  (:use :cl)
  (:import-from :elmtui.core.globals
   :*app-state*)
  (:import-from :elmtui.statelib.state
   :application-state :make-application-state :state-ref :get-state :set-state
                :merge-state :with-state :with-comp-state :state-if-unset-else
                :application-state-observers :application-state-lock
                :application-state-transaction-log :application-state-transaction-history
                :log-state-data )
  (:import-from :elmtui.statelib.transaction
   :start-transaction :commit-transaction :rollback-transaction
                :undo-last-transaction :transaction-open-p :with-transaction)
  (:import-from :elmtui.statelib.observe
                ;; :subscribe-to-state :unsubscribe-from-state
                )
  (:export
   ;; Core state types and accessors
   :application-state :make-application-state :state-ref :get-state :set-state
   :merge-state :with-state :with-comp-state :state-if-unset-else
   :application-state-observers :application-state-lock ;; :set-state!
   :application-state-transaction-log :application-state-transaction-history
   :log-state-data
   ;; Transactions
   :start-transaction :commit-transaction :rollback-transaction
   :transaction-open-p :with-transaction
   ;; Observability (future: subscribe-to-state, unsubscribe-from-state)
   :*app-state* ; Export the global state variable
   :rollback-state ; Export the rollback function
   ))

(in-package :elmtui.state)

;; Define the global application state instance
;; (defvar *app-state* (make-application-state)
;;   "The global application state instance.")

;; Define the rollback function expected by with-async-restarts
(defun rollback-state ()
  "Rolls back the last transaction on the global *app-state*."
  (undo-last-transaction elmtui.core.globals:*app-state*))

;;; API CONTRACTS:
;; - All state is stored in an application-state struct (hash-table-based, thread-safe).
;; - All mutations are transactional and can be committed/rolled back.
;; - Observers can be registered for reactive updates (future).
;; - Macros provide idiomatic, scoped, and performant state access.
;; - State supports undo/redo, time-travel, and logging.
;; - All access is thread-safe and suitable for concurrent TUI/event loop use.

;;; USAGE EXAMPLES:
;; (defparameter *app-state* (make-application-state))
;; (setf (state-ref *app-state* 'counter) 0)
;; (with-transaction (*app-state*)
;;   (incf (state-ref *app-state* 'counter)))
;; (log-state-data *app-state*)

;;; EXTENSIONS:
;; - To add Elm-style subscriptions, wrap observer API for view/model coupling.
;; - For undo/redo, use transaction-history and rollback/commit as needed.
;; - For fine-grained view updates, use observer interest/callback patterns.

;;; PERFORMANCE:
;; - Hash-table storage ensures O(1) access.
;; - Transactions batch updates for atomicity.
;; - Thread safety via mutexes.
;; - Observers allow efficient, reactive UI updates.

