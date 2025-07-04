;;;===============================================================
;;; File: src/state/msg.lisp
;;; Message Definition Macro with Variant Registration & Constructors
;;;===============================================================
(uiop:define-package :elmtui.state.msg
  (:use :cl :alexandria :log4cl)
  (:export :defmsg :message-variant-p :*message-schemas*
   ;; Structs and their accessors for schema introspection
   :message-schema #:message-schema-name #:message-schema-variants #:message-schema-docstring
   :variant-definition #:variant-definition-name #:variant-definition-args #:variant-definition-arg-spec #:variant-definition-constructor-name
           :arg-def #:arg-def-type #:arg-def-keyword
           ;; Example message type names
   :AppMsg :StateChangeMsg))
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

;;; ------------------------------------------------------------------
;;; Variant parsing helpers
;;; ------------------------------------------------------------------

  ;; (defstruct arg-def
  ;;   keyword   ;; e.g. :new-label
  ;;   type)     ;; e.g. STRING

  (defstruct arg-def
    "Represents a single argument in a variant definition."
    ;; var-name is removed as we will use gensyms in the macro expansion
    (type t :type T)            ; The type specifier
    (keyword nil :type symbol)) ; The keyword used in the message list

  (defun %parse-variant (spec msg-type)
    "Return a VARIANT-DEFINITION for SPEC.
   SPEC forms:
     SYMBOL                     ; ⇒ simple keyword :symbol
     (Symbol kw1 typ1 kw2 typ2) ; ⇒ keyword args
   The list of tail elements must be an *even* number of keyword/type pairs."
    (etypecase spec
      ;; 1. lone symbol ⇒ no args
      (symbol
       (make-variant-definition
        :name        (intern (string spec) :keyword)
        :args        nil
        :constructor-name
        (symbolicate "MAKE-" spec "-" msg-type)))
      ;; 2. list ⇒ variant plus (kw type) pairs
      (cons
       (destructuring-bind (head &rest rest) spec
         (unless (evenp (length rest))
           (error "Variant specification ~S has an odd number of tail elements." spec))
         (let ((args '()))
           (loop for (kw typ) on rest by #'cddr
                 do (unless (keywordp kw)
                      (error "Expected keyword in ~S, got ~S." spec kw))
                 do (push (make-arg-def :keyword kw :type typ) args))
           (make-variant-definition
            :name        (intern (string head) :keyword)
            :args        (nreverse args)
            :constructor-name
            (symbolicate "MAKE-" head "-" msg-type)))))))

;;; ------------------------------------------------------------------
;;; Constructor generation (excerpt)
;;; ------------------------------------------------------------------




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

  ;; (defun %parse-variant (variant-spec message-type-name)
  ;;   "Parses a defmsg variant specification into a variant-definition struct.
  ;;    Handles both simple and complex variant specifications.
  ;;    - Simple: (IncrementCounter) => :increment-counter
  ;;    - Complex: (SetCounterLabel :new-label string) => :set-counter-label"
  ;;   (let* ((name-sym (if (listp variant-spec) (first variant-spec) variant-spec))
  ;;          (arg-specs (when (listp variant-spec) (rest variant-spec)))
  ;;          (variant-keyword (make-keyword name-sym))
  ;;          (constructor-name (symbolicate "MAKE-" name-sym "-" message-type-name))) ; Make constructor name unique
  ;;     (unless (symbolp name-sym)
  ;;       (error "Message variant name must be a symbol: ~S" name-sym))
  ;;     (make-variant-definition :name variant-keyword
  ;;                              :args (%parse-variant-args arg-specs)
  ;;                              :arg-spec variant-spec
  ;;                              :constructor-name constructor-name)))
  )

(defmacro defmsg (name (&key docstring) &rest variant-specs)
  "Define a message type NAME with variants and auto-generated
   constructor functions.  See source for full doc.

Example:
  (defmsg AppMsg (:docstring \"Main application messages\")
          IncrementCounter
          DecrementCounter
          (SetCounterLabel :new-label string)
          (ActivateUser :user-id integer)
          (DeactivateUser :user-id integer)
          (RequestFocus :widget-id t))
    This macro generates:
    - Constructor functions for each variant, named `make-<variant-name>-<message-type-name>`.
    - Each constructor checks argument types based on the variant specification.
    - Registers the message type and its variants in the global *message-schemas* hash table.
    The schema includes the name, variants, and an optional docstring.
    The variants are stored as a list of variant-definition structs, each containing:
    - The variant name (as a keyword
    - The argument definitions (list of arg-def structs
    - The original argument specification (for reference
    - The constructor name (for the generated function
    The constructor functions are generated at compile time, and the schema is registered
    at load time to avoid dumping the struct object.
"
  ;; sanity
  (unless (and (symbolp name) (not (keywordp name)))
    (error "Message type name must be a (non-keyword) symbol, not ~S" name))

  (let* ((schema-name name)
         (variants     (mapcar (lambda (spec)
                                 (%parse-variant spec schema-name))
                               variant-specs)))

    `(progn
       ;; ───────────────── constructors ─────────────────
       ,@(loop for v in variants
               collect
               (let* ((ctor   (variant-definition-constructor-name v))
                      (vkey   (variant-definition-name v))
                      (args   (variant-definition-args v))
                      ;; build one (keyword var) spec per argument
                      (params (loop for a in args
                                    for kw  = (intern (symbol-name (arg-def-keyword a)) *package*)
                                    for kww  =  (arg-def-keyword a)
                                    for var = (gensym (string-downcase (symbol-name kw)))  ; <- gensym!
                                    collect (list kw kww var))))
                 `(defun ,ctor ,(when params `(&key ,@(mapcar #'car  params)))
                    ,(format nil "Constructor for ~A variant of ~A." vkey `,schema-name)
                    ;; type checks
                    ,@(loop for a in args
                            for p in params
                            collect
                            `(check-type ,(first p) ,(arg-def-type a)))
                    ;; message list
                    (list ,vkey
                          ,@(mapcan (lambda (p) (list (second p) (first p))) params)))))

       ;; ───────────────── schema registration ──────────
       (eval-when (:load-toplevel :execute)
         (let* ((load-variants (mapcar (lambda (spec)
                                         (%parse-variant spec ',schema-name))
                                       ',variant-specs))
                (schema (make-message-schema :name ',schema-name
                                             :variants load-variants
                                             :docstring ,(or docstring ""))))
           (setf (gethash ',schema-name *message-schemas*) schema)))

       ;; ───────────────── export constructors ──────────
       ,@(loop for v in variants
               collect `(export ',(variant-definition-constructor-name v)
                         ,*package*))

       ',schema-name)))
;; (defun dud (&key a)
;;   (format nil "a: ~A" a)) (dud :a 2)


(defmsg SnAppMsg (:docstring "Main application messages")
        (ActivateUser :user-id integer))
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
        (WindowResize :width integer :height integer)
        ;; Internal message for updating focus list
        (UpdateFocusableIds :ids list))


;; Example StateChangeMsg definition (Alternative to :state-changed in AppMsg)
;; (defmsg StateChangeMsg (:docstring "Wraps state changes detected by observers")
;;         (Changed :model symbol :slot keyword :value t))

;; Example: a button widget could define when clicked:
;; (defmsg ButtonMsg (:docstring "Messages for button interactions")
;;        ButtonClick)


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

;; helper for runtime
;; src/runtime.lisp:15:  (:import-from :elmtui.state.msg #:make-update-focusable-ids-app-msg) ; Constructor for the message
;; (defun make-update-focusable-ids-app-msg (ids)
;;   "Creates an UpdateFocusableIds message with the given list of IDs."
;;   (make-update-focusable-ids-app-msg ids))

;; (defmethod new ((msg-type (eql 'AppMsg)) (msg-name (eql :update-focusable-ids)) ids)
;;   "Creates an UpdateFocusableIds message with the given list of IDs."
;;   (make-update-focusable-ids-app-msg ids))
