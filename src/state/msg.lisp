;;;===============================================================
;;; File: src/state/msg.lisp
;;; Message Definition Macro with Variant Registration & Constructors
;;;===============================================================
(uiop:define-package :elmtui.state.msg
  (:use :cl :alexandria :log4cl)
  (:export :defmsg :message-variant-p :*message-schemas*)) ; Exporting registry for potential introspection
(in-package :elmtui.state.msg)

(defvar *message-schemas* (make-hash-table :test 'eq)
  "Global registry for message types and their variants defined by defmsg.")

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
  (name nil :type symbol)
  (type t :type T)
  (keyword nil :type symbol))

(defun %parse-variant-args (arg-specs)
  "Parses variant argument specifications into a list of arg-def structs."
  (loop for spec in arg-specs
        collect (etypecase spec
                  (symbol ; Simple argument name (type T)
                   (make-arg-def :name spec :type t :keyword (make-keyword spec)))
                  (list ; Keyword argument with type (e.g., :value integer)
                   (unless (and (= (length spec) 2) (keywordp (first spec)))
                     (error "Invalid keyword argument spec: ~S. Should be (:keyword type)." spec))
                   (make-arg-def :name (intern (symbol-name (first spec))) ; Use symbol name for binding
                                 :type (second spec)
                                 :keyword (first spec))))))

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
                             :constructor-name constructor-name)))

(defmacro defmsg (name (&key docstring) &rest variant-specs)
  "Defines a message type, registers its allowed variants, and generates constructor functions.

   This macro registers a schema for the message type `NAME` and defines helper
   functions `make-<variant>-<name>` for constructing valid message instances.
   Using these constructors is the recommended way to create messages, as they
   can perform basic validation.

   Variant Specification:
     Each variant can be:
     - A simple symbol: `Increment` (represents a message with no data)
     - A list: `(SetValue :value integer)` or `(AddUser :name string :id fixnum)`
       (represents a message carrying data). Arguments are specified as keyword/type
       pairs. The generated constructor will accept these as keyword arguments.

   Registration:
     The schema is stored globally in `*message-schemas*`.

   Constructors:
     For each variant (e.g., `(SetValue :value integer)` within `(defmsg AppMsg ...)`),
     a constructor function `make-set-value-app-msg` is generated. It takes
     corresponding keyword arguments (e.g., `&key (value nil)`), performs basic
     type checks based on the spec, and returns the standard message list format
     `'(:set-value :value the-value)`.

   Runtime Validation:
     Use `message-variant-p` to check if a message list starts with a valid
     variant keyword for the given message type. Full argument validation is
     best handled by using the generated constructors.

   Usage:
     ;; Define the message type, variants, and generate constructors
     (defmsg AppMsg (:docstring \"Messages for the main application\")
       Increment
       Decrement
       (SetValue :value integer)
       (AddUser :name string :id fixnum))

     ;; Create messages using generated constructors (Recommended)
     (make-increment-app-msg) ; => (:INCREMENT)
     (make-set-value-app-msg :value 10) ; => (:SET-VALUE :VALUE 10)
     (make-add-user-app-msg :name \"Roo\" :id 123) ; => (:ADD-USER :NAME \"Roo\" :ID 123)
     ;; (make-set-value-app-msg :value \"not-an-int\") ; => Signals type error

     ;; Basic runtime check (e.g., in dispatch)
     (message-variant-p 'AppMsg '(:increment)) ; => T
     (message-variant-p 'AppMsg '(:set-value :value 10)) ; => T
     (message-variant-p 'AppMsg '(:unknown)) ; => NIL

   Args:
     NAME: The symbol naming the message type (e.g., AppMsg).
     DOCSTRING: An optional documentation string for the message type.
     VARIANT-SPECS: A list of variant specifications.

   Returns:
     The symbol `NAME`."
  (let* ((schema-name name)
         (variants (mapcar (lambda (spec) (%parse-variant spec schema-name)) variant-specs))
         (schema (make-message-schema :name schema-name
                                      :variants variants
                                      :docstring (or docstring ""))))

    ;; Store the schema globally
    `(progn
       (setf (gethash ',schema-name *message-schemas*) ,schema)

       ;; Define Constructor Functions for each variant
       ,@(loop for variant in variants
               collect
               (let* ((constructor (variant-definition-constructor-name variant))
                      (variant-key (variant-definition-name variant))
                      (args (variant-definition-args variant))
                      (lambda-list (if args
                                       `(&key ,@(mapcar (lambda (arg) `(,(arg-def-name arg) nil)) args))
                                       nil)))
                 `(defun ,constructor ,lambda-list
                    ,(format nil "Constructor for the ~S variant of the ~S message type."
                             (subseq (symbol-name variant-key) 1) ; Remove leading ':'
                             schema-name)
                    ;; Perform type checks
                    ,@(loop for arg in args
                            collect `(check-type ,(arg-def-name arg) ,(arg-def-type arg)))
                    ;; Construct the message list
                    (list ',variant-key
                          ,@(loop for arg in args
                                  collect (arg-def-keyword arg) ; The keyword symbol
                                  collect (arg-def-name arg))))))) ; The bound variable

       ;; Placeholder for observer/dispatcher integration based on variants
       ;; (format t ";; TODO: Register variants for ~S with observer/dispatcher~%" ',schema-name)
       ',schema-name)))

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
