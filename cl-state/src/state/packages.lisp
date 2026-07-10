;;; cl-state/src/state/packages.lisp
(uiop:define-package :cl-state.utils
  (:use :cl :alexandria)
  (:export
   #:get-path
   #:set-path
   #:remove-path
   #:plist->hash-table
   #:hash-table->plist
   #:coerce-data))

(uiop:define-package :cl-state.core
  (:use :cl :alexandria :cl-state.utils)
  (:export
   #:application-state
   #:application-state-p
   #:make-application-state
   #:application-state-data
   #:application-state-backend
   #:application-state-log
   #:application-state-history
   #:application-state-undone
   #:application-state-version
   #:application-state-lock
   #:application-state-observers
   #:state-ref
    #:valid-state-path-p
    #:assert-valid-state-path
    #:valid-state-path-p
    #:assert-valid-state-path
   #:get-state
   #:state-set
   #:make-state
   #:set-application-state-backend
   #:deep-copy-application-state
   #:application-state-plist
   #:get-component-by-path
   #:*transaction-active*))

(uiop:define-package :cl-state.patch
  (:use :cl :alexandria :cl-state.utils :cl-state.core)
  (:export
   #:patch
   #:patch-p
   #:make-patch
   #:patch-path
   #:patch-op
   #:patch-value
   #:apply-patch
   #:apply-patches
   #:merge-patch
   #:merge-patches
   #:diff-states
   #:normalize-patches))

(uiop:define-package :cl-state.tx
  (:use :cl :alexandria :cl-state.utils :cl-state.core)
  (:export
   #:tx
   #:tx-p
   #:make-tx
   #:tx-id
   #:tx-name
   #:tx-changes
   #:with-transaction
   #:state-set
   #:undo
   #:redo
   #:*transaction-active*))

(uiop:define-package :cl-state.undo
  (:use :cl :alexandria)
  (:export
   #:history
   #:make-history
   #:history-past
   #:history-future
   #:push-snapshot
   #:history-undo
   #:history-redo))

(uiop:define-package :cl-state.observer
  (:use :cl :alexandria :cl-state.core)
  (:export
   #:add-observer
   #:remove-observer
   #:notify-observers))

(uiop:define-package :cl-state.schema
  (:use :cl)
  (:export :register-type-predicate
           :define-type-predicate
           :lookup-type-predicate
           :list-registered-types
           :validate-type
           :make-enum-predicate
           :register-enum-type))

(uiop:define-package :cl-state.validation
  (:use :cl)
  (:export :validate-nested
           :validate-field
           :with-validation
           :define-validator
           :register-type-validator
           :validate-model-schema
           :make-validator
           :type-predicate
           :validation-error))

(uiop:define-package :cl-state.api
  (:use :cl
        :cl-state.utils
        :cl-state.core
        :cl-state.patch
        :cl-state.observer
        :cl-state.tx
        :cl-state.schema
        :cl-state.validation)
  (:shadowing-import-from :cl-state.undo
    #:history
    #:make-history
    #:history-past
    #:history-future
    #:push-snapshot)
  (:import-from :cl-state.undo
    #:history-undo
    #:history-redo)
  ;; Re-export all public symbols from subsystems
  (:export
   ;; From cl-state.utils
   #:get-path
   #:set-path
   #:remove-path
   #:plist->hash-table
   #:hash-table->plist
   #:coerce-data
   ;; From cl-state.core
   #:application-state
   #:application-state-p
   #:make-application-state
   #:application-state-data
   #:application-state-backend
   #:application-state-log
   #:application-state-history
   #:application-state-undone
   #:application-state-version
   #:application-state-lock
   #:application-state-observers
   #:state-ref
   #:get-state
   #:state-set
   #:make-state
   #:set-application-state-backend
   #:deep-copy-application-state
   #:application-state-plist
   #:get-component-by-path
   ;; From cl-state.patch
   #:patch
   #:patch-p
   #:make-patch
   #:patch-path
   #:patch-op
   #:patch-value
   #:apply-patch
   #:apply-patches
   #:merge-patch
   #:merge-patches
   #:diff-states
   #:normalize-patches
   ;; From cl-state.tx
   #:tx
   #:make-tx
   #:tx-p
   #:tx-id
   #:tx-name
   #:tx-changes
   #:with-transaction
   #:undo
   #:redo
   ;; From cl-state.observer
   #:add-observer
   #:remove-observer
   #:notify-observers
   ;; From cl-state.undo
   #:history
   #:make-history
   #:history-past
   #:history-future
   #:push-snapshot
   #:history-undo
   #:history-redo
   ;; From cl-state.schema
   #:register-type-predicate
   #:define-type-predicate
   #:lookup-type-predicate
   #:list-registered-types
   #:validate-type
   #:make-enum-predicate
   #:register-enum-type
   ;; From cl-state.validation
   #:validate-nested
   #:validate-field
   #:with-validation
   #:define-validator
   #:register-type-validator
   #:validate-model-schema
   #:make-validator
   #:type-predicate
   #:validation-error))
