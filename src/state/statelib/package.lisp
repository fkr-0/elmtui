(uiop:define-package :elmtui.statelib (:use :cl)
                     (:nicknames :elmtui.statelib)
                     ;; Re-export core state and transaction symbols
                     (:reexport :elmtui.statelib.state)
                                        ;#:*application-state-exports*) ; Assuming state.lisp defines this
                     (:reexport :elmtui.statelib.transaction)
                                        ;#:*transaction-exports*) ; Assuming transaction.lisp defines this
                     ;; Re-export observer symbols
                     (:reexport :elmtui.statelib.observe))
                                        ;#:*observer-exports*)) ; Assuming observe.lisp defines this

;; Define the exports for each sub-package to be included above
;; (defpackage :ut.state.state (:use)) ; Placeholder for actual definition
;; (in-package :ut.state.state)
;; (defparameter *application-state-exports*
;;   '(:make-application-state :state-ref :get-state :set-state :application-state
;;     :application-state-transaction-log :transaction-id
;;     :application-state-observers :application-state-data
;;     :application-state-lock
;;     :state-data :state-data-data
;;     :merge-state :with-state :with-comp-state
;;     :state-if-unset-else :log-state-data
;;     :application-state-transaction-history
;;     :application-state-undone-history
;;     :transaction-log :transaction-history :undone-history)
;;   "Symbols exported from ut.state.state.")

;; (defpackage :ut.state.transaction (:use)) ; Placeholder
;; (in-package :ut.state.transaction)
;; (defparameter *transaction-exports*
;;   '(:transaction :transaction-id :transaction-changes
;;     :transaction-timestamp :make-transaction :record-change :apply-transaction
;;     :revert-transaction :with-transaction :undo-last-transaction
;;     :redo-last-transaction :clear-transaction-history
;;     :notify-observers) ; Keep notify-observers exported from here for now
;;   "Symbols exported from ut.state.transaction.")

;; (defpackage :ut.state.observe (:use)) ; Placeholder
;; (in-package :ut.state.observe)
;; (defparameter *observer-exports*
;;   '(:observer :observer-key :observer-callback :observer-id
;;     :add-observer :remove-observer)
;;   ;; Note: notify-observers is handled by transaction.lisp currently
;;   "Symbols exported from ut.state.observe.")

;; Switch back to the main package for safety
(in-package :cl-user)
