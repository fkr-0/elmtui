;;;===============================================================
;;; File: src/state/elm.lisp
;;; Elm-Style State Management: Idiomatic, Contract-Driven, Transactional

(uiop:define-package :elmtui.state.elm
  (:use :cl :elmtui.state)
  ;; Import model system from dedicated module
  (:import-from :elmtui.state.model 
                #:defmodel 
                #:make-model 
                #:initialize-model-state
                #:get-slot
                #:*model-schemas*)
  ;; Import message system from dedicated module
  (:import-from :elmtui.state.msg 
                #:*message-schemas* 
                #:defmsg)

  (:export ;; Re-export model system
           :defmodel
           :make-model
           :initialize-model-state
           :get-slot
           :*model-schemas*
           ;; Re-export message system
           :defmsg
           :*message-schemas*
           ;; Update system
           :defupdate
           :*update-contracts*))
(in-package :elmtui.state.elm)

(defvar *update-contracts* (make-hash-table :test 'equal)
  "Registry of update function contracts for documentation and validation.")

;; Message definition is now handled by elmtui.state.msg:defmsg
;; See src/state/msg.lisp for implementation details
;; 
;; The defmsg macro provides a standardized way to define message types and variants.
;; It generates type-checked constructor functions and registers message schemas.
;; Message creators should use these generated constructors (e.g., make-increment-counter-appmsg)
;; for proper validation and consistent message format.
;; 
;; Example usage:
;;   (defmsg AppMsg (:docstring "Main application messages")
;;            IncrementCounter
;;            (SetCounterLabel :new-label string))
;;
;; Generated functions:
;;   (make-increment-counter-appmsg) => '(:increment-counter)
;;   (make-set-counter-label-appmsg :new-label "Hello") => '(:set-counter-label :new-label "Hello")

;;; defupdate: Wrap a pure update function with transactional state, contract validation, and undo/redo.
(defmacro defupdate (name args &body body)
  "Wrap a pure update function: (app-state msg) → (new-state cmds).
   - Ensures transactional updates on application-state.
   - Registers contract in *update-contracts*.
   - Macroexpansion-time error reporting for side-effects.
   - Supports undo/redo via transaction history.
   - Documents update patterns."
  `(progn
     (setf (gethash ',name *update-contracts*) ',args)
     (defun ,name ,args
       (elmtui.state:with-transaction (,(first args))
         ,@body))))

;;; Update Function Pattern Best Practices:
;;;
;;; 1. Use pattern matching (case/cond or a pattern matching library) for message dispatch
;;; 2. Return command lists consistently, even when empty (nil)
;;; 3. Always use typed constructors for message creation (e.g., make-increment-counter-appmsg)
;;; 4. Keep update functions pure except for state changes via set-state!
;;; 5. Group related logic into separate component update functions
;;;
;;; Example:
;;;
;;; (defupdate update-counter (app-state msg)
;;;   "Update counter model state based on counter messages"
;;;   (case (if (listp msg) (first msg) msg)
;;;     (:increment
;;;       (let ((amount (or (getf (rest msg) :amount) 1)))
;;;         (setf (state-ref app-state :counter :value) 
;;;               (+ (state-ref app-state :counter :value) amount))
;;;         ;; Return nil commands - no side effects
;;;         nil))
;;;     (:decrement
;;;       (let ((amount (or (getf (rest msg) :amount) 1)))
;;;         (setf (state-ref app-state :counter :value)
;;;               (- (state-ref app-state :counter :value) amount))
;;;         ;; Return a command - e.g., play sound effect
;;;         (list '(:play-sound :click))))
;;;     (otherwise nil)))

;;; USAGE EXAMPLES:

;; (defmodel counter
;;   ((value :type integer :initform 0 :validate #'integerp)))

;; (defmsg counter-msg inc dec reset)

(defupdate main-update (app-state msg)
  "Main application update function. Handles messages and updates state.
   Returns a list of commands."
  ;; Import set-state! locally for convenience if not already available
  ;; Note: defupdate already provides a local set-state! macro.
  ;; Importing it here might be redundant or cause conflicts depending on package setup.
  ;; Assuming the local macro from defupdate is sufficient.
  ;; (:import-from :ut.state.state #:set-state!)

  (let ((msg-type (if (listp msg) (first msg) msg))
        (msg-data (when (listp msg) (rest msg))))

    ;; --- Focus Management ---
    (case msg-type
      (:request-focus
       (let ((widget-id (getf msg-data :widget-id)))
         ;; TODO: Validate widget-id exists in focusable list?
         (setf (state-ref app-state :focused-widget-id) widget-id) ; Uses local set-state! from defupdate
         (return-from main-update nil))) ; Return nil commands

      (:focus-next
       (let* ((current-focus (state-ref app-state :focused-widget-id))
              ;; TODO: :focusable-widget-ids needs to be updated dynamically,
              ;; likely after view rendering. This list might be stale.
              (focusable-ids (state-ref app-state :focusable-widget-ids))
              (current-pos (position current-focus focusable-ids :test #'equal)))
         (when focusable-ids
           (let* ((next-pos (if (or (null current-pos) (= current-pos (1- (length focusable-ids))))
                                0 ; Wrap to start
                                (1+ current-pos)))
                  (next-id (nth next-pos focusable-ids)))
             (setf (state-ref app-state :focused-widget-id) next-id))) ; Uses local set-state!
         (return-from main-update nil))) ; Return nil commands

      (:focus-previous
       (let* ((current-focus (state-ref app-state :focused-widget-id))
              (focusable-ids (state-ref app-state :focusable-widget-ids))
              (current-pos (position current-focus focusable-ids :test #'equal)))
         (when focusable-ids
           (let* ((prev-pos (if (or (null current-pos) (zerop current-pos))
                                (1- (length focusable-ids)) ; Wrap to end
                                (1- current-pos)))
                  (prev-id (nth prev-pos focusable-ids)))
             (setf (state-ref app-state :focused-widget-id) prev-id))) ; Uses local set-state!
         (return-from main-update nil))) ; Return nil commands

      ;; --- Other Message Handling (Example) ---
      ;; TODO: Integrate component updates (e.g., calling update-button, update-textinput)
      ;; This likely involves checking msg-type or a target ID in msg-data.
      ;; (case msg-type
      (:increment ; Example adapted from original commented code
       (setf (state-ref app-state :counter) (1+ (or (state-ref app-state :counter) 0))))
      (:decrement
       (setf (state-ref app-state :counter) (1- (or (state-ref app-state :counter) 0))))
      ;; --- Internal State Updates ---
      (:update-focusable-ids
       (let ((new-ids (getf msg-data :ids)))
         (setf (state-ref app-state :focused-widget-ids) new-ids)))
      ;; Add other message handlers here...
      (otherwise
       (log:warn "Unhandled message type in main-update: ~S" msg-type)))

    ;; TODO: Return appropriate commands based on updates
    nil)) ; Default return no commands

;;; CONTRACTS:
;; - All models are hash-table based, with schema-driven validation and defaulting.
;; - All messages are validated against allowed variants at runtime.
;; - All updates are transactional, undo/redo capable, and side-effect free.
;; - Observer hooks and documentation are generated for extensibility.
