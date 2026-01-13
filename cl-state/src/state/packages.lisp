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
   #:get-state
   #:state-set
   #:make-state
   #:set-application-state-backend
   #:deep-copy-application-state
   #:application-state-plist
   #:get-component-by-path))

(uiop:define-package :cl-state.patch
  (:use :cl :alexandria :cl-state.utils)
  (:export
   #:patch
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
  (:use :cl :alexandria :cl-state.core :cl-state.patch)
  (:export
   #:tx
   #:make-tx
   #:tx-p
   #:tx-id
   #:tx-name
   #:tx-changes
   #:with-transaction
   #:apply-patches
   #:undo
   #:redo
   #:state-set))

(uiop:define-package :cl-state.undo
  (:use :cl :alexandria)
  (:export
   #:history
   #:make-history
   #:history-past
   #:history-future
   #:push-snapshot
   #:undo
   #:redo))

(uiop:define-package :cl-state.observer
  (:use :cl :alexandria :cl-state.core)
  (:export
   #:add-observer
   #:remove-observer
   #:notify-observers))

(uiop:define-package :cl-state.api
  (:use :cl
        :cl-state.utils
        :cl-state.core
        :cl-state.patch
        :cl-state.tx
        :cl-state.observer)
  (:import-from :cl-state.undo
    #:history
    #:make-history
    #:history-past
    #:history-future
    #:push-snapshot)
  (:reexport :cl-state.utils
             :cl-state.core
             :cl-state.patch
             :cl-state.tx
             :cl-state.observer))
