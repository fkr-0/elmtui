(uiop:define-package :elmtui.tea-state
  (:use :cl :elmtui.tea-state.api)
  ;; Import from the implementation packages
  (:import-from :elmtui.tea-state.state
                #:state-ref
                #:get-state
                #:get-path
                #:application-state
                #:application-state-version
                #:tx)
  (:import-from :elmtui.tea-state.transactions
                #:with-transaction
                #:apply-patches
                #:undo
                #:redo)
  (:import-from :elmtui.tea-state.observers
                #:add-observer
                #:remove-observer)
  (:reexport #:elmtui.tea-state.observers)
  (:reexport #:elmtui.tea-state.api)
  (:reexport #:elmtui.tea-state.state)
  (:reexport #:elmtui.tea-state.update)
  (:reexport #:elmtui.tea-state.transactions)
  (:reexport #:elmtui.tea-state.msg)
  (:reexport #:elmtui.tea-state.model)
  ;; Export the public interface
  (:export
   #:defupdate
   ;; State creation & introspection
   ;; #:make-state
   ;; #:get-state
   #:get-path
   ;; #:tx
   #:state-ref


   ;; Application state
   #:application-state
   #:application-state-p
   #:make-application-state
   #:application-state-p
   #:application-state-data
   #:application-state-lock
   #:application-state-log
   #:application-state-history
   #:application-state-undone
   #:application-state-version
   #:application-state-observers
   #:handle-async-command

   ;; Transactions
   #:with-transaction
   #:apply-patches
   #:undo
   #:redo
   #:tx
   #:make-tx
   #:tx-p
   #:tx-id
   #:tx-name
   #:tx-changes

   ;; Observers
   #:add-observer
   #:remove-observer))
(in-package :elmtui.tea-state)
