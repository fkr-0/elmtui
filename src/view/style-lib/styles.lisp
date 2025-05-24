;;; ───────────────────────── 3. Style DSL  ────────────────────────────────
(uiop:define-package :elmtui.style-lib.styles
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.types)
  (:import-from :elmtui.style-lib.api
   :style :property :value :style-group
   :style-set :make-style :style-value :valid-style-value-p :stylegroup-p)
  ;; (:import-from :elmtui.style-lib.stylable
  ;;  :stylable-id)
  (:export
   :rgb
   :defstyle :defstylegroup  :style-p
   :default-styles))

(in-package :elmtui.style-lib.styles)

(defun style-p (x) (typep x 'style))
(defun rgb (x) (if (and (listp x) (= (length x) 3) (every #'numberp x))
                   x
                   nil))

;;; defstyle macro ---------------------------------------------------------
(defmacro defstyle (keyword spec &key default docstring)
  "Define a new style with the given KEYWORD and SPEC.
The KEYWORD is used to create a class and a function for creating instances of the style.
The SPEC defines the valid values for the style, which can be a list of symbols, a type specifier, or a function.
The DEFAULT value is used to set a default style if provided.
The DOCSTRING is used to document the style class.

The macro generates a class for the style, a value class, and a method to validate the value.
It also generates a function to create an instance of the style with the given value.
The generated function checks if the value is valid according to the SPEC and raises an error if not.
The generated function is named MAKE-STYLE/KEYWORD, where KEYWORD is the keyword provided.
The macro also generates a method to create a style instance based on the keyword and value.

Example usage:
  (defstyle my-style '(red green blue)
    :default 'red
    :docstring \"A style that can be red, green, or blue.\"
    :default 'red"
  (let* ((pk (intern (string-upcase (string keyword)) :elmtui.style-lib.styles))
         (vk (intern (format nil "~a-VALUE" pk) :elmtui.style-lib.styles))
         (kwsym (intern (string keyword) :keyword)))
    `(progn
       (defclass ,pk (property) ()
         (:default-initargs :name ,(string keyword))
         (:documentation ,docstring))
       (defclass ,vk (value) ())
       (defmethod valid-value-p ((p ,pk) v)
         (cond ((listp spec) `(member v ',spec))
               ((symbolp spec) `(typep v ',spec))
               ((and (consp spec) (eq (first spec) 'function)) spec)
               (t `(error "Invalid value spec ~a" ',spec))))
       (defun ,(intern (format nil "MAKE-STYLE/~a" keyword) :elmtui.style-lib.styles) (val)
         (unless (valid-value-p (make-instance ',pk) val)
           (error "Invalid value ~a for ~a" val ',keyword))
         (make-instance 'style
                        :property (make-instance ',pk)
                        :value    (make-instance ',vk :value val :type ',spec)))
       (defmethod make-style ((sym (eql ',kwsym)) val)
         (,(intern (format nil "MAKE-STYLE/~a" keyword) :elmtui.style-lib.styles) val))
       ,@(when (not (eq default :unset))
           `((defmethod default-styles ()
               (cons (make-style ',kwsym ,default) (call-next-method))))))))

(defgeneric default-styles () (:method () nil))

;;; defstylegroup macro ----------------------------------------------------
;;; Modified to accept &body body for custom value processing logic
(defmacro defstylegroup (group-spec &body body)
  (let* (;; Parse group-spec which can be 'group-name or '((:groups (...)) :option ...)
         (group-name (if (listp group-spec) (getf (car group-spec) :groups) group-spec))
         (members (when (listp group-spec) (getf (car group-spec) :groups)))
         (options (when (listp group-spec) (cdr group-spec))) ; Other options like :decorating-after, :docstring
         (docstring (getf options :docstring))
         ;; Ensure group-name is a symbol for intern
         (group-sym (if (keywordp group-name) (intern (symbol-name group-name)) group-name))
         (kw (intern (string group-sym) :keyword))
         (cls (intern (string-upcase (string group-sym)) :elmtui.style-lib.styles)))
    ;; Use members from :groups if provided, otherwise signal error if body is also empty?
    ;; For now, assume members must be provided via :groups if body is used for logic.
    ;; If body is meant to *replace* default logic, members might not be needed in spec.
    `(progn
       (defclass ,cls (style-group) () (:documentation ,docstring))
       (defmethod group-key ((obj ,cls)) ',kw)
       (defmethod make-style ((sym (eql ',kw)) value) ; 'value' is the input to the group style
         ;; Body provided to defstylegroup executes here, can modify 'value'
         ;; or return the list of sub-styles directly.
         (let ((processed-result (progn ,@body)))
           ;; Check if the body returned a list of styles (intended for sub-styles)
           (if (and (listp processed-result) (every #'style-p processed-result))
               ;; Body generated the sub-styles list
               (make-instance ',cls
                              :property (make-instance 'property :name ,(string kw))
                              ;; Store the original input value for potential inspection
                              :value    (make-instance 'value :value value)
                              :sub-styles processed-result)
               ;; If body didn't return a list of styles, assume it modified 'value' (or did nothing)
               ;; and run default logic if members were provided.
               ,(if members
                    `(let ((vals (ensure-list value)) (subs '())) ; Use potentially modified 'value'
                       (labels ((push4 (ks v) (dolist (k ks) (push (make-style k v) subs))))
                         (case (length vals)
                           (1 (push4 ',members (first vals)))
                           (2 (progn (push4 ',(subseq members 0 (floor (/ (length members) 2))) (first vals)) ; Use floor
                                     (push4 ',(subseq members (floor (/ (length members) 2))) (second vals))))
                           ;; Add cases 3 and 4 if needed, or rely on body providing sub-styles
                           (t (error "Default logic cannot split ~a into ~a members. Body must return sub-styles list." vals ',group-sym))))
                       (make-instance ',cls
                                      :property (make-instance 'property :name ,(string kw))
                                      :value    (make-instance 'value :value value) ; Store original/modified value
                                      :sub-styles (nreverse subs)))
                    ;; If no members provided and body didn't return styles, create empty group
                    `(make-instance ',cls
                      :property (make-instance 'property :name ,(string kw))
                      :value    (make-instance 'value :value value)
                      :sub-styles nil))))))))

;;; fallback make-style ----------------------------------------------------
(defmethod make-style (k v)
  (make-instance 'style
                 :property (make-instance 'property :name (string k))
                 :value    (make-instance 'value :value v :type (type-of v))))
