;;;===============================================================
;;; File: src/state/msg.lisp
;;; Message Definition Macro with Variant Registration & Constructors
;;;===============================================================
(uiop:define-package :elmtui.state.msg
  (:use :cl :alexandria :log4cl)
  (:export :defmsg :message-variant-p :*message-schemas*
           ;; Potentially export message type names if needed elsewhere
           :AppMsg :StateChangeMsg)) ; Example export
(in-package :elmtui.state.msg)

(defvar *message-schemas* (make-hash-table :test 'eq)
  "Global registry for message types and their variants defined by defmsg.")

;; Structs and Helper functions needed at compile time by the defmsg macro
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defstruct message-schema
    "Represents the schema for a message type defined by defmsg."
    (name nil :type symbol)
    (variants (list) :type list) ; List of variant-definition structs
    (docstring "" :type string))

  (defstruct variant-definition
    "Represents a single message variant definition."
    (name nil :type symbol) ; The keyword symbol for the variant (e.g., :increment)
    (args nil :type list) ; Parsed argument definitions (list of arg-def structs)
    (arg-spec nil :type T) ; Original spec for reference
    (constructor-name nil :type symbol)) ; Name of the generated constructor function

  (defstruct arg-def
    "Represents a single argument in a variant definition."
    ;; var-name is removed as we will use gensyms in the macro expansion
    (type t :type T)            ; The type specifier
    (keyword nil :type symbol)) ; The keyword used in the message list

  (defun %parse-variant-args (arg-specs)
    "Parses variant argument specifications into a list of arg-def structs."
    (loop for spec in arg-specs
          collect (etypecase spec
                    (symbol ; Simple argument name (type T) - Treat as keyword arg for consistency
                     (let ((kw (make-keyword spec)))
                       (make-arg-def :type t :keyword kw))) ; Store only keyword and type
                    (list ; Keyword argument with type (e.g., :value integer)
                     (unless (and (= (length spec) 2) (keywordp (first spec)))
                       (error "Invalid keyword argument spec: ~S. Should be (:keyword type)." spec))
                     (let ((kw (first spec))
                           (type (second spec)))
                       (make-arg-def :type type :keyword kw)))))) ; Store only keyword and type

  (defun %parse-variant (variant-spec message-type-name)
    "Parses a defmsg variant specification into a variant-definition struct."
    (let* ((name-sym (if (listp variant-spec) (first variant-spec) variant-spec))
           (arg-specs (when (listp variant-spec) (rest variant-spec)))
           (variant-keyword (make-keyword name-sym))
           (constructor-name (symbolicate "MAKE-" name-sym "-" message-type-name))) ; Make constructor name unique
      (unless (symbolp name-sym)
        (error "Message variant name must be a symbol: ~S" name-sym))
      (make-variant-definition :name variant-keyword
                               :args (%parse-variant-args arg-specs)
                               :arg-spec variant-spec
                               :constructor-name constructor-name))))

(defmacro defmsg (name (&key docstring) &rest variant-specs)
  "Defines a message type, registers its allowed variants, and generates constructor functions.
   See docstring in source for more details."
  (let* ((schema-name name)
         ;; Parse variants at compile time to generate constructors
         (variants (mapcar (lambda (spec) (%parse-variant spec schema-name)) variant-specs)))

    `(progn
       ;; Generate Constructor Functions at compile time
       ,@(loop for variant in variants
               collect
               (let* ((constructor (variant-definition-constructor-name variant))
                      (variant-key (variant-definition-name variant))
                      (args (variant-definition-args variant))
                      ;; Generate gensyms for local variables
                      (gensym-vars (loop for arg in args collect (gensym (symbol-name (arg-def-keyword arg)))))
                      ;; Generate lambda list using keywords and gensyms
                      (lambda-list (if args
                                       `(&key ,@(loop for arg in args
                                                      for g in gensym-vars
                                                      collect (list g nil))) ; Use gensyms here: (G123 nil)
                                       nil)))
                 `(defun ,constructor ,lambda-list
                    ,(format nil "Constructor for the ~S variant of the ~S message type."
                             (subseq (symbol-name variant-key) 1) ; Remove leading ':'
                             schema-name)
                    ;; Perform type checks using gensyms and type from arg-def
                    ,@(loop for arg in args
                            for g in gensym-vars
                            collect `(check-type ,g ,(arg-def-type arg))) ; Use gensym here
                    ;; Construct the message list using keyword from arg-def and gensym
                    (list ',variant-key
                          ,@(loop for arg in args
                                  for g in gensym-vars
                                  collect (arg-def-keyword arg) ; Use the original keyword
                                  collect g))))) ; Use the gensym holding the value

       ;; Register the schema at load time to avoid dumping struct object
       (eval-when (:load-toplevel :execute)
         (let* (;; Re-parse variants at load time to create the schema object
                (load-time-variants (mapcar (lambda (spec) (%parse-variant spec ',schema-name)) ',variant-specs))
                (schema (make-message-schema :name ',schema-name
                                             :variants load-time-variants
                                             :docstring ,(or docstring ""))))
           (setf (gethash ',schema-name *message-schemas*) schema)))

       ',schema-name))) ; Return the message type name

;; Example AppMsg definition including Focus messages
(defmsg AppMsg (:docstring "Main application messages")
  ;; Counter Example Messages
  IncrementCounter
  DecrementCounter
  (SetCounterLabel :new-label string)
  ;; User Example Messages
  (ActivateUser :user-id integer)
  (DeactivateUser :user-id integer)
  ;; Focus Management Messages
  (RequestFocus :widget-id t) ; ID can be symbol, string, etc.
  FocusNext
  FocusPrevious
  ;; Theme Message
  (SetTheme :stylesheet t) ; Stylesheet object (type depends on style-lib)
  ;; Observer/Async Messages (Examples)
  (StateChanged :model symbol :slot keyword :value t)
  (AsyncProgressUpdate :task-id symbol :progress t)
  ;; Input Event Messages (Mapped from platform backends)
  (KeyEvent :key symbol :char t :modifiers list) ; Changed type for :char to t
  (MouseEvent :type keyword :button integer :row integer :col integer :modifiers list)
  (WindowResize :width integer :height integer))


;; Example StateChangeMsg definition (Alternative to :state-changed in AppMsg)
(defmsg StateChangeMsg (:docstring "Wraps state changes detected by observers")
  (Changed :model symbol :slot keyword :value t))


(defun message-variant-p (message-type message-instance)
  "Checks if MESSAGE-INSTANCE is a list starting with a valid registered
   variant keyword for MESSAGE-TYPE.

   Note: This function only checks the initial keyword, not the arguments.
   Use the generated `make-<variant>-<type>` constructors for argument validation.

   Args:
     message-type: The symbol naming the message type (e.g., 'AppMsg).
     message-instance: The message instance to validate (e.g., '(:increment)).

   Returns:
     T if the instance uses a registered variant keyword for the type, NIL otherwise."
  (let ((schema (gethash message-type *message-schemas*)))
    (when schema
      (and (listp message-instance)
           (keywordp (car message-instance))
           (find (car message-instance)
                 (message-schema-variants schema)
                 :key #'variant-definition-name)))))
