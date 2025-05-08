(uiop:define-package :elmtui.style-lib.macros (:use #:cl)
                     (:nicknames :elmtui.style-lib.styles.macros)
                     (:import-from :log4cl :log-info :log-debug)
                     (:import-from :str :upcase :substring :split :join)
                     (:import-from :elmtui.style-lib.util :keyword-concat :keyword-split)
                     (:import-from :elmtui.style-lib.util :=?)
                     ;; (:import-from :elmtui.style-lib.stylable
                     ;;   :implement-style :can-implement-style)
                     (:import-from :elmtui.style-lib.styles :valid-style-value-p :style-group-key
                      :apply-after :style-sub-styles :illegal-group-value
                                   :style-group :property :value :group-styles)
                     (:import-from :elmtui.style-lib.style-set :style-of)
                     (:import-from :elmtui.style-lib.api :style-set :from-style-set :implement-style
                                   :stylable :make-style :value-value :name :style :default-styling)
                     (:export :defstyle :defstylegroup))

(in-package :elmtui.style-lib.macros)

(defmacro defstyle
    (name value-specifier
     &key (default :unset) (decorating-after nil) ; :around :pre :post :content
       (docstring ""))
  "Defines a new style property with the specified name and value specifier.
   The value specifier can either be a type or a list of keywords. The keyword
   :after can be used to specify a list of styles that need to be applied before
   this style. The docstring is used to document the style.

   Args:
     name: The name of the style property.
     value-specifier: The value specifier of the style property.
     default: The default value of the style property.
     after: A list of styles that need to be applied before this style.
     docstring: The docstring of the style property.
   Returns:
     A list of the style property and the value class of the style property.
   Example:
     (defstyle :background-color 'color :after (:foreground-color)
     :docstring \"The background color of a widget.\")
     => (BACKGROUND-COLOR-STYLE BACKGROUND-COLOR-VALUE"

  (let ((property-class-name (intern (string-upcase (string name))))
        (property-key-name (intern (string-upcase (string name)) :keyword))
        (value-class-name
          (intern (string-upcase (string (concatenate 'string (string name) "-value"))))))
    `(progn
       (defclass ,property-class-name (property)
         ((name :initform ,(string name)
                :initarg :name
                :accessor property-name))
         (:documentation ,docstring))
       (defmethod valid-style-value-p ((style ,property-class-name) value)
         (typecase ,value-specifier
           (list (member value ,value-specifier))
           (symbol (typep value ,value-specifier))
           (function (funcall ,value-specifier value))
           (t (error "Invalid value specifier: ~A" ,value-specifier))))
       (defmethod initialize-instance :after
           ((property ,property-class-name) &key value)
         (unless (valid-style-value-p property value)
           (error "Invalid value: ~A for property: ~A" value ',name)))
       (defclass ,value-class-name (value)
         ((value :initarg :value :accessor value-value)
          (type :initform ,(if (listp value-specifier)
                               ''keyword
                               (eval value-specifier))
                :initarg :type
                :accessor value-type)
          (possible-values :initform ,(if (listp value-specifier)
                                          value-specifier
                                          'nil)
                           :initarg :possible-values
                           :accessor value-possible-values)))
       (defmethod implement-style
           ((widget stylable) (style ,property-class-name) value)
         (error "Style ~A is unimplemented in stylable ~A."
                (property-name style) (type-of widget)))
       (when ,decorating-after
         (defmethod apply-after
             ((property (eql ,property-key-name)) (stylelist list))
           (and ,decorating-after
                (let ((d (if (listp ,decorating-after)
                             ,decorating-after
                             (list ,decorating-after))))
                  (dolist (s stylelist)
                    (when (member s d)
                      (return-from apply-after s))))))
         (defmethod implement-style
             ((stylable (eql (find-class 'stylable)))
              (style ,property-class-name) value)
           (when (next-method-p)
             (call-next-method))))
       (defmethod make-style ((property (eql ,property-key-name)) value)
         (make-instance 'style
                        :property (make-instance ',property-class-name :value value)
                        :value (make-instance ',value-class-name :value value)))
       (unless (eql ,default :unset)
         (defmethod default-styling ((kw (eql ,property-key-name)))
           (make-style kw ,default))))))


(defmacro defstylegroup
    ((&key (groups nil) (decorating-after nil) (docstring ""))
     &body body)
  "Group a set of defined styles. The styles are expected to carry the same
prefix. The prefix is removed from the style name and the style is added to the group with the
remaining name. The common prefix is added as style with the truncated sub styles as sub-styles. The
body is expected to implement a parser for values passed to the parent style allowing instancing the
parent style with sensible values for the grouped styles or subsets. The body binds the passed value
to value is expected to return a style instance with a list of sub-styles. If it returns nil, the
semantics are equivalent of passing a value that is not of the expected type to a regular style and
results in a validation error. Example: (defstylegroup :groups
(:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle)
 :docstring \"groups padding and accepts 1-3 integers as argument.\""
  (let* (;; (groups '(:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle))
         (split-groups (mapcar #'keyword-split groups))
         (common-prefixes
           (car
            (mapcar
             (lambda (kw-list)
               (remove-if-not (lambda (x) (member x (car split-groups)))
                              kw-list))
             (cdr split-groups))))
         ;; TODO use those?
         (suffix-styles
           (mapcar
            (lambda (kw-list)
              (remove-if (lambda (x) (member x common-prefixes)) kw-list))
            split-groups))
         (group-name-key (keyword-concat common-prefixes))
         (group-name (intern (string-upcase (string group-name-key)))))
    (declare (ignorable suffix-styles))
    `(progn
       ;; (log-info "GroupName: ~A, GroupNameKey: ~A" (quote ,group-name) (quote ,group-name-key))
       (defclass ,group-name (style-group)
         ((sub-styles :initform (list ,@groups) :accessor style-sub-styles)
          (property :initform (make-instance 'property
                                             :name (symbol-name ',group-name))
                    :accessor style-property))
         (:documentation ,docstring))
       (when ,decorating-after
         (defmethod apply-after
             ((property (eql ,group-name-key)) (stylelist list))
           "Return the style that needs to be applied before this style, or nil if
                           no style needs to be applied before this style.

                           Args:
                           stylelist: The list of styles that
                           are applied to the widget after this style.
                           Returns:
                           The first style that needs to be applied before this style, or nil if no style needs
                           to be applied before this style."
           (and ,decorating-after
                (let ((d
                        (if (listp ,decorating-after)
                            ,decorating-after
                            (list ,decorating-after))))
                  (dolist (s stylelist)
                    (when (member s d)
                      (return-from apply-after s))))))
         (defmethod implement-style
             ((stylable (eql (find-class 'stylable))) (style ,group-name)
              value)
           (when (next-method-p)
             (call-next-method))))
       (defmethod group-styles ((style-group-key (eql ,group-name-key)))
         (list ,@groups))
       `(progn
          ,(dolist (grouped-style ',groups)
             ;; reset implementations TODO why exactly again?
             ;; `(defmethod implement-style
             ;;   ((stylable stylable) (style ,(intern (symbol-name grouped-style))) value)
             ;;   (log-info "whoop")
             ;;   nil)
             (defmethod style-group-key ((style (eql grouped-style)))
               ,group-name-key)))
       (defmethod from-style-set ((grouped-style (eql ,group-name-key)) styles)
         (let ((props (group-styles ,group-name-key))
               (s (make-instance ',group-name)))
           (dolist (prop props)
             (push (style-of styles prop) (style-sub-styles s)))
           s))

       (defmethod make-style ((property (eql ,group-name-key)) value)
         (let ((result (progn ,@body)))
           (if result
               (let ((inst (make-instance ',group-name :value value)))
                 (setf (style-sub-styles inst) result)
                 inst)
               (signal 'illegal-group-value
                       :style ',group-name
                       :value value)))))))

;; -- Refactored defstylegroup macro --
;; (defmacro defstylegroup (group-name group-members (&key decorating-after docstring) &body body)
;;   "Define a style group with GROUP-NAME which aggregates the style properties in GROUP-MEMBERS.
;; DECORATING-AFTER is an optional style to be applied before this group.
;; DOCSTRING documents the style group.
;; BODY is evaluated to compute the grouped styles based on a provided value."
;;   (declare (ignorable decorating-after docstring))
;;   (let ((group-class (intern (concatenate 'string (string-upcase (string group-name)) "-GROUP"))))
;;     `(progn
;;        (defclass ,group-class (style-group)
;;          ((sub-styles :initform (list ,@group-members) :accessor style-sub-styles)
;;            (property :initform (make-instance 'property :name ,(string-upcase (string group-name)))
;;              :accessor style-property))
;;          (:documentation ,docstring))
;;        (defmethod group-styles ((style-group-key (eql ,group-name)))
;;          (list ,@group-members))
;;        (defmethod make-style ((property (eql ,group-name)) value)
;;          (let ((result (progn ,@body)))
;;            (if result
;;              (let ((inst (make-instance ',group-class :value value)))
;;                (setf (style-sub-styles inst) result)
;;                inst)
;;              (signal 'illegal-group-value :style ,group-name :value value)))))))
;; ;; End of macros.lisp
