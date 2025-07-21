(uiop:define-package :elmtui.tea-state.api
  (:use :cl)
  ;; Import from the implementation packages
  (:import-from :elmtui.tea-state.state
                #:make-state
                #:get-state
                #:get-path
                #:application-state
                #:application-state-version
                #:application-state-p
                #:state-ref
                #:tx)
  (:import-from :elmtui.tea-state.transactions
                #:with-transaction
                #:apply-patches
                #:undo
                #:redo)
  (:import-from :elmtui.tea-state.observers
                #:add-observer
                #:remove-observer)
  ;; Export the public interface
  (:export
   ;; State creation & introspection
   #:make-state
   #:get-state
   #:get-path
   #:application-state
   #:tx
   #:state-ref
   #:application-state-p

   ;; Transactions
   #:with-transaction
   #:apply-patches
   #:undo
   #:redo

   ;; Observers
   #:add-observer
   #:remove-observer))
(in-package :elmtui.tea-state.api)
