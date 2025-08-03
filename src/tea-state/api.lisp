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
   #:tx
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
   #:application-state-p

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
(in-package :elmtui.tea-state.api)

(defgeneric state-ref (place key &optional default))

(defstruct application-state
  (data (make-hash-table :test 'equal))
  (lock (sb-thread:make-mutex))
  (log nil) (history nil) (undone nil) (version 0) (observers nil))

(defgeneric make-state (initial)
  (:documentation "Creates a new application state with the given INITIAL data."))

(defstruct tx
  id
  name
  changes)  ; list of (key old new)
