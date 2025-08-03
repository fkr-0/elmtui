;;;===============================================================
;;; File: src/state/msg.lisp
;;; Message Definition Macro with Variant Registration & Constructors
;;;===============================================================
(uiop:define-package :elmtui.state.msg
  (:use :cl :log4cl)
  (:import-from :elmtui.core.globals
                #:*message-schemas*) ; Global hash table for message schemas
  (:import-from #:sb-int
                #:symbolicate) ; For symbol manipulation
  (:export
   #:msg-data #:msg-type
   #:defmsg #:message-variant-p
   ;; Structs and their accessors for schema introspection
   :message-schema #:message-schema-name #:message-schema-variants #:message-schema-docstring
   #:make-focusnext-appmsg #:make-focusprevious-appmsg
   :variant-definition #:variant-definition-name #:variant-definition-args #:variant-definition-arg-spec #:variant-definition-constructor-name
   :arg-def #:arg-def-type #:arg-def-keyword
   ;; Example message type names
   :AppMsg :StateChangeMsg))
(in-package :elmtui.state.msg)

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

  ;;   (defstruct arg-def
  ;;     keyword   ;; e.g. :new-label
  ;;     type)     ;; e.g. STRING

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
        :name        (%variant-name-to-keyword spec)
        :args        nil
        :constructor-name
        (sb-int:symbolicate "MAKE-" (string spec) "-" msg-type)))
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
            :name        (%variant-name-to-keyword head)
            :args        (nreverse args)
            :constructor-name
            (sb-int:symbolicate "MAKE-" (string head) "-" msg-type)))))))

;;; ------------------------------------------------------------------
;;; Constructor generation (excerpt)
;;; ------------------------------------------------------------------

  (defun %variant-name-to-keyword (sym)
    (let ((name (symbol-name sym)))
      (intern (string-upcase name) 'keyword)))
  )
;;; Primary macro: define a message type and its constructors.
(defmacro defmsg (name (&key docstring) &rest variant-specs)
  "Define a message type NAME with variants and auto‑generated
   constructor functions.

   Each variant may be a bare symbol or a list of the form
   (VariantName :arg1 type1 :arg2 type2 ...).  For each variant, a
   constructor named MAKE-<variant-name>-<message-name> is created.  The
   constructor accepts keyword arguments as specified by the variant
   and returns a list beginning with the variant's keyword tag.

   A schema describing the message type and its variants is stored in
   the global *MESSAGE-SCHEMAS* table at load time.  The optional
   DOCSTRING is stored in the schema.
   "
  ;; Sanity check: message type name must be a symbol.
  (unless (and (symbolp name) (not (keywordp name)))
    (error "Message type name must be a (non-keyword) symbol, not ~S" name))
  ;; Parse all variant specifications into internal variant-definition
  ;; objects.  We collect both the original spec and its parsed form
  ;; so we can derive names and keywords cleanly below.
  (let* ((parsed-variants
           (mapcar (lambda (spec) (%parse-variant spec name)) variant-specs))
         (zipped (mapcar #'cons variant-specs parsed-variants)))
    `(progn
       ;; ──────────────── constructor generation ────────────────
       (eval-when (:compile-toplevel :load-toplevel :execute)
         ,@(loop for (spec . vdef) in zipped
                 collect
                 (let* ((ctor  (variant-definition-constructor-name vdef))
                        (args  (variant-definition-args vdef))
                        ;; Extract the raw variant name from the spec.  If
                        ;; SPEC is a list (VariantName ...), take the first
                        ;; element; otherwise use SPEC itself.
                        (raw-name (if (consp spec) (first spec) spec))
                        ;; Compute a keyword tag for the message.  We
                        ;; downcase the symbol name to account for the
                        ;; Common Lisp reader's case folding and avoid
                        ;; per‑character hyphenation.
                        (vkey (%variant-name-to-keyword raw-name))
                        ;; Build a parameter list (keyword var) for each
                        ;; argument in the variant definition.  Each arg-def
                        ;; provides a keyword (e.g. :width), and we generate
                        ;; a fresh local variable to hold its value.  We
                        ;; capture both the parameter keyword to use in the
                        ;; lambda list (kw), the original keyword (kww) and
                        ;; the gensymed variable name (var).
                        (params (loop for a in args
                                      for kw  = (intern (symbol-name (arg-def-keyword a)) *package*)
                                      for kww = (arg-def-keyword a)
                                      for var = (gensym (string-downcase (symbol-name kw)))
                                      collect (list kw kww var)))
                        ;; Build a docstring referencing the original
                        ;; variant and message type names.
                        (doc (format nil "Constructor for ~A variant of ~A." raw-name `,name)))
                   `(defun ,ctor ,(when params
                                    `(&key ,@(mapcar #'car params)))
                      ,doc
                      ;; Type checks for each argument: call CHECK-TYPE
                      ;; using the gensymed variable names.  If no args,
                      ;; nothing is emitted here.
                      ,@(loop for a in args
                              for p in params
                              collect `(check-type ,(first p) ,(arg-def-type a)))
                      ;; Assemble the message list: the first element is
                      ;; the keyword tag, followed by each argument
                      ;; keyword and its value.
                      (list ,vkey
                            ,@(mapcan (lambda (p) (list (second p) (first p))) params))))))
       ;; ──────────────── schema registration ────────────────
       (eval-when (:load-toplevel :execute)
         (let* ((load-variants
                  (mapcar (lambda (spec)
                            (%parse-variant spec ',name))
                          ',variant-specs))
                (schema (make-message-schema :name ',name
                                             :variants load-variants
                                             :docstring ,(or docstring ""))))
           (setf (gethash ',name *message-schemas*) schema)))
       ;; ──────────────── export constructors ────────────────
       ,@(loop for vdef in parsed-variants
               collect `(export ',(variant-definition-constructor-name vdef) ,*package*))
       ',name)))

(defun msg-data (msg &optional key)
  "Returns the data part of a message MSG.
   If KEY is provided, returns the value associated with that key
   in the message's data.  Otherwise, returns the entire data list.

   The message is expected to be a list where the first element is
   the message type keyword, followed by keyword-value pairs.
   Example:
     (msg-data '(:increment-counter :count 42)) ⇒ (:count 42)
     (msg-data '(:increment-counter :count 42) :count) ⇒ 42
     (msg-data '(:set-label :new-label \"Hello\")) ⇒ (new-label \"Hello\")"

  (if key (getf (cdr msg) key)
      (cdr msg)))

(defun msg-type (msg)
  "Returns the type of the message MSG.
     The message is expected to be a list where the first element is
     the message type keyword.  Example:
         (msg-type '(:increment-counter :count 42)) ⇒ :increment-counter
         (msg-type '(:set-label :new-label \"Hello\")) ⇒ :set-label"
  (car msg))


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
