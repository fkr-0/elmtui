;;;===============================================================
;;; File: src/state/msg.lisp
;;; Message Definition Macro with Variant Registration & Constructors
;;;===============================================================
(uiop:define-package :elmtui.state.msg
  (:use :cl :log4cl)
  (:import-from #:sb-int
    #:symbolicate)
  (:export
    #:msg-data #:msg-type
    #:defmsg #:message-variant-p #:canonicalize-message-variant
    :message-schema #:message-schema-name #:message-schema-variants #:message-schema-docstring
    #:make-focusnext-appmsg #:make-focusprevious-appmsg #:make-keyevent-appmsg
    :variant-definition #:variant-definition-name #:variant-definition-args #:variant-definition-arg-spec #:variant-definition-constructor-name
    :arg-def #:arg-def-type #:arg-def-keyword
    :AppMsg :StateChangeMsg))
(in-package :elmtui.state.msg)

(defvar *message-schemas* (make-hash-table :test 'eq)
  "Global registry for message types and their variants defined by defmsg.")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defstruct message-schema
    "Represents the schema for a message type defined by defmsg."
    (name nil :type symbol)
    (variants (list) :type list)
    (docstring "" :type string))

  (defstruct variant-definition
    "Represents a single message variant definition."
    (name nil :type symbol)
    (args nil :type list)
    (arg-spec nil :type T)
    (constructor-name nil :type symbol))

  (defstruct arg-def
    "Represents a single argument in a variant definition."
    (type t :type T)
    (keyword nil :type symbol))

  (defun %variant-name-to-keyword (sym)
    (let ((name (symbol-name sym)))
      (intern (string-upcase name) :keyword)))

  (defun %parse-variant (spec msg-type)
    "Return a VARIANT-DEFINITION for SPEC."
    (etypecase spec
      (symbol
        (make-variant-definition
          :name (%variant-name-to-keyword spec)
          :args nil
          :constructor-name
          (sb-int:symbolicate "MAKE-" (string spec) "-" msg-type)))
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
              :name (%variant-name-to-keyword head)
              :args (nreverse args)
              :constructor-name
              (sb-int:symbolicate "MAKE-" (string head) "-" msg-type))))))))

(defmacro defmsg (name (&key docstring) &rest variant-specs)
  "Define a message type NAME with variants and auto-generated constructors."
  (unless (and (symbolp name) (not (keywordp name)))
    (error "Message type name must be a (non-keyword) symbol, not ~S" name))
  (let* ((parsed-variants
           (mapcar (lambda (spec) (%parse-variant spec name)) variant-specs))
          (zipped (mapcar #'cons variant-specs parsed-variants)))
    `(progn
       (eval-when (:compile-toplevel :load-toplevel :execute)
         ,@(loop for (spec . vdef) in zipped
             collect
             (let* ((ctor (variant-definition-constructor-name vdef))
                     (args (variant-definition-args vdef))
                     (raw-name (if (consp spec) (first spec) spec))
                     (vkey (%variant-name-to-keyword raw-name))
                     (params (loop for a in args
                               for kw = (intern (symbol-name (arg-def-keyword a)) *package*)
                               for kww = (arg-def-keyword a)
                               for var = (gensym (string-downcase (symbol-name kw)))
                               collect (list kw kww var)))
                     (doc (format nil "Constructor for ~A variant of ~A." raw-name `,name)))
               `(defun ,ctor ,(when params
                                `(&key ,@(mapcar #'car params)))
                  ,doc
                  ,@(loop for a in args
                      for p in params
                      collect `(check-type ,(first p) ,(arg-def-type a)))
                  (list ,vkey
                    ,@(mapcan (lambda (p) (list (second p) (first p))) params))))))
       ,@(loop for (spec . vdef) in zipped
           collect
           (let* ((raw-name (if (consp spec) (first spec) spec))
                   (vkey (%variant-name-to-keyword raw-name))
                   (pred (sb-int:symbolicate
                           (format nil "~A-~A-P"
                             (symbol-name (variant-definition-name vdef))
                             (symbol-name `,name)))))
             `(defun ,pred (msg)
                ,(format nil "Predicate for ~A variant of ~A." raw-name `,name)
                (and (listp msg)
                  (keywordp (car msg))
                  (eq (car msg) ',vkey)))))
       (eval-when (:load-toplevel :execute)
         (let* ((load-variants
                  (mapcar (lambda (spec)
                            (%parse-variant spec ',name))
                    ',variant-specs))
                 (schema (make-message-schema :name ',name
                           :variants load-variants
                           :docstring ,(or docstring ""))))
           (setf (gethash ',name *message-schemas*) schema)))
       ,@(loop for vdef in parsed-variants
           collect `(export ',(variant-definition-constructor-name vdef) ,*package*))
       ,@(loop for vdef in parsed-variants
           collect `(export ',(sb-int:symbolicate (format nil "~A-P" (symbol-name (variant-definition-name vdef)))) ,*package*))
       ',name)))

(defun message-variant-p (message-type message-instance)
  "Check whether MESSAGE-INSTANCE uses a registered variant keyword for MESSAGE-TYPE."
  (not (null (canonicalize-message-variant message-type message-instance))))

(defun canonicalize-message-variant (message-type message-instance)
  "Return MESSAGE-INSTANCE with canonical keyword variant head for MESSAGE-TYPE.
Accepts symbol heads from any package as long as their names match a declared variant.
Returns NIL when MESSAGE-INSTANCE is not a recognized variant for MESSAGE-TYPE."
  (let ((schema (gethash message-type *message-schemas*)))
    (when (and schema (listp message-instance) (symbolp (car message-instance)))
      (let* ((head-name (string-upcase (symbol-name (car message-instance))))
             (variant
               (find head-name
                     (message-schema-variants schema)
                     :key (lambda (v) (string-upcase (symbol-name (variant-definition-name v))))
                     :test #'string=)))
        (when variant
          (cons (variant-definition-name variant) (cdr message-instance)))))))

(defun msg-data (msg &optional key default)
  "Return the data part of message MSG.
If KEY is provided, return the value for KEY in the plist (cdr MSG),
or DEFAULT if KEY is not present. If KEY is not provided, return the plist itself."
  (let ((data (cdr msg)))
    (if key
      (getf data key default)
      data)))

(defun msg-type (msg)
  "Returns the type of the message MSG."
  (car msg))

(defmsg AppMsg (:docstring "Main application messages")
  IncrementCounter
  DecrementCounter
  (SetCounterLabel :new-label string)
  (ActivateUser :user-id integer)
  (DeactivateUser :user-id integer)
  (RequestFocus :widget-id t)
  FocusNext
  FocusPrevious
  (SetTheme :stylesheet t)
  (StateChanged :model symbol :slot keyword :value t)
  (AsyncProgressUpdate :task-id symbol :progress t)
  (KeyEvent :event t :key symbol :char t :modifiers list)
  (MouseEvent :type keyword :button integer :row integer :col integer :modifiers list)
  (WindowResize :width integer :height integer)
  (CursorPosition :row integer :col integer)
  (Scroll :amounti integer)
  (UpdateFocusableIds :ids list))
