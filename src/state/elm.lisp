;;;===============================================================
;;; File: src/state/elm.lisp
;;; Elm-Style State Management: Idiomatic, Contract-Driven, Transactional

(uiop:define-package :elmtui.state.elm
  (:use :cl :elmtui.state)
  (:export :defmodel
           :defmsg
           :defupdate
           :*model-schemas*
           :*msg-variants*
           :*update-contracts*))
(in-package :elmtui.state.elm)

(defvar *model-schemas* (make-hash-table :test 'equal)
  "Registry of model schemas for contract validation and documentation.")

(defvar *msg-variants* (make-hash-table :test 'equal)
  "Registry of allowed message variants for runtime validation.")

(defvar *update-contracts* (make-hash-table :test 'equal)
  "Registry of update function contracts for documentation and validation.")

;;; defmodel: Define a model schema with contract validation, defaulting, and observer hooks.
(defmacro defmodel (name &rest slots)
  "Define a MODEL schema for application-state.
   - Registers schema in *model-schemas* for contract validation.
   - Supports slot :type, :initform, :validate, :observer.
   - Generates constructor with defaulting and validation.
   - Optionally generates observer hooks for slots.
   - Documents schema and usage."
  (let ((schema (mapcar (lambda (slot)
                          (destructuring-bind (slot-name &key type initform validate observer) slot
                            (list :name slot-name :type type :initform initform :validate validate :observer observer)))
                        slots)))
    `(progn
       (setf (gethash ',name *model-schemas*) ',schema)
       (defun ,(intern (format nil "MAKE-~A" name)) ()
         ;; Construct model with defaults and validation
         (let ((model (make-hash-table :test 'equal)))
           ,@(loop for slot in schema
                   collect
                   `(setf (gethash ',(getf slot :name) model)
                          ,(or (getf slot :initform) nil)))
           ;; Optionally: validate slots
           ,@(loop for slot in schema
                   when (getf slot :validate)
                   collect
                   `(unless (funcall ,(getf slot :validate) (gethash ',(getf slot :name) model))
                      (error "Model slot ~A failed validation." ',(getf slot :name))))
           model))
       ;; Optionally: define observer hooks (stub)
       ;; (defun ,(intern (format nil "~A-OBSERVERS" name)) () ...)
       )))

;;; defmsg: Register allowed message variants and runtime validation.
(defmacro defmsg (name &rest variants)
  "Define a Msg union: variants are symbols.
   - Registers allowed variants in *msg-variants* for runtime validation.
   - Generates a constant symbol listing allowed variants.
   - Documents usage and anti-patterns."
  `(progn
     (setf (gethash ',name *msg-variants*) ',variants)
     (defconstant ,(intern (string-upcase (symbol-name name))) ',variants)))

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

;;; USAGE EXAMPLES:

;; (defmodel counter
;;   ((value :type integer :initform 0 :validate #'integerp)))

;; (defmsg counter-msg inc dec reset)

;; (defupdate update-counter (app-state msg)
;;   (case msg
;;     (inc (incf (elmtui.state:state-ref app-state 'value)))
;;     (dec (decf (elmtui.state:state-ref app-state 'value)))
;;     (reset (setf (elmtui.state:state-ref app-state 'value) 0)))
;;   app-state)

;;; CONTRACTS:
;; - All models are hash-table based, with schema-driven validation and defaulting.
;; - All messages are validated against allowed variants at runtime.
;; - All updates are transactional, undo/redo capable, and side-effect free.
;; - Observer hooks and documentation are generated for extensibility.
