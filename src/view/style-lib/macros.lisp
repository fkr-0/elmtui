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
                     (:export :defstyle :defstylegroup
                              #:*stylegroup-registry*
                              #:define-stylegroup
                              #:lookup-stylegroup
                              #:expand-stylegroups))

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
       (defmethod valid-style-value-p ((p ,property-class-name) value)
         (let ((spec ,value-specifier))
           (cond
             ;; Case 1: Spec is a list of explicit keywords, e.g., (list :foo :bar)
             ((and (listp spec) (every #'keywordp spec))
              (member value spec))
             ;; Case 2: Spec is a symbol (e.g., 'integer) or a complex type specifier list (e.g., '(or integer string))
             ((or (symbolp spec) (consp spec)) ; consp covers lists like (or ...) and (integer 0 *)
              (typep value spec))
             ;; Case 3: Spec is a function (predicate)
             ((functionp spec)
              (funcall spec value))
             (t (error "Invalid value specifier for style property ~A: ~S" (property-name p) spec)))))
       ;; (defmethod initialize-instance :after
       ;;     ((property ,property-class-name) &key value)
       ;;   ;; Initialize-instance for property doesn't usually take :value.
       ;;   ;; Validation should happen when a style object is made with this property.
       ;;   ;; Let's remove this :after method for property, or ensure it's harmless.
       ;;   ;; For now, commenting out to avoid potential issues if :value isn't passed to make-instance 'property-class-name
       ;;   #|
       ;;   (unless (valid-style-value-p property value)
       ;;     (error "Invalid value: ~A for property: ~A" value ',name))
       ;;   |#
       ;;   )
       (defclass ,value-class-name (value)
         ((value :initarg :value :accessor value-value)
          (type :initform ',value-specifier ; Store the original specifier
                :initarg :type
                :accessor value-type)
          (possible-values :initform ,(if (and (listp value-specifier) (every #'keywordp value-specifier))
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
       (defmethod make-style ((property-key (eql ,property-key-name)) value)
         (let ((prop-instance (make-instance ',property-class-name)))
           (unless (valid-style-value-p prop-instance value)
             (error "Invalid value ~S for style property ~S." value property-key))
           (make-instance 'style
                          :property prop-instance
                          :value (make-instance ',value-class-name :value value :type ',value-specifier))))
       (unless (eql ,default :unset)
         (defmethod default-styling ((kw (eql ,property-key-name)))
           (make-style kw ,default))))))


;; (defmacro defstylegroup
;;     ((&key (groups nil) (decorating-after nil) (docstring ""))
;;      &body body)
;;   "Group a set of defined styles. The styles are expected to carry the same
;; prefix. The prefix is removed from the style name and the style is added to the group with the
;; remaining name. The common prefix is added as style with the truncated sub styles as sub-styles. The
;; body is expected to implement a parser for values passed to the parent style allowing instancing the
;; parent style with sensible values for the grouped styles or subsets. The body binds the passed value
;; to value is expected to return a style instance with a list of sub-styles. If it returns nil, the
;; semantics are equivalent of passing a value that is not of the expected type to a regular style and
;; results in a validation error. Example: (defstylegroup :groups
;; (:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle)
;;  :docstring \"groups padding and accepts 1-3 integers as argument.\""
;;   (let* (;; (groups '(:padding-top :padding-bottom :padding-left :padding-right :padding-char :padding-charstyle))
;;          (split-groups (mapcar #'keyword-split groups))
;;          (common-prefixes
;;            (car
;;             (mapcar
;;              (lambda (kw-list)
;;                (remove-if-not (lambda (x) (member x (car split-groups)))
;;                               kw-list))
;;              (cdr split-groups))))
;;          ;; TODO use those?
;;          (suffix-styles
;;            (mapcar
;;             (lambda (kw-list)
;;               (remove-if (lambda (x) (member x common-prefixes)) kw-list))
;;             split-groups))
;;          (group-name-key (keyword-concat common-prefixes))
;;          (group-name (intern (string-upcase (string group-name-key)))))
;;     (declare (ignorable suffix-styles))
;;     `(progn
;;        ;; (log-info "GroupName: ~A, GroupNameKey: ~A" (quote ,group-name) (quote ,group-name-key))
;;        (defclass ,group-name (style-group)
;;          ((sub-styles :initform (list ,@groups) :accessor style-sub-styles)
;;           (property :initform (make-instance 'property
;;                                              :name (symbol-name ',group-name))
;;                     :accessor style-property))
;;          (:documentation ,docstring))
;;        (when ,decorating-after
;;          (defmethod apply-after
;;              ((property (eql ,group-name-key)) (stylelist list))
;;            "Return the style that needs to be applied before this style, or nil if
;;                            no style needs to be applied before this style.

;;                            Args:
;;                            stylelist: The list of styles that
;;                            are applied to the widget after this style.
;;                            Returns:
;;                            The first style that needs to be applied before this style, or nil if no style needs
;;                            to be applied before this style."
;;            (and ,decorating-after
;;                 (let ((d
;;                         (if (listp ,decorating-after)
;;                             ,decorating-after
;;                             (list ,decorating-after))))
;;                   (dolist (s stylelist)
;;                     (when (member s d)
;;                       (return-from apply-after s))))))
;;          (defmethod implement-style
;;              ((stylable (eql (find-class 'stylable))) (style ,group-name)
;;               value)
;;            (when (next-method-p)
;;              (call-next-method))))
;;        (defmethod group-styles ((style-group-key (eql ,group-name-key)))
;;          (list ,@groups))
;;        `(progn
;;           ,(dolist (grouped-style ',groups)
;;              ;; reset implementations TODO why exactly again?
;;              ;; `(defmethod implement-style
;;              ;;   ((stylable stylable) (style ,(intern (symbol-name grouped-style))) value)
;;              ;;   (log-info "whoop")
;;              ;;   nil)
;;              (defmethod style-group-key ((style (eql grouped-style)))
;;                ,group-name-key)))
;;        (defmethod from-style-set ((grouped-style (eql ,group-name-key)) styles)
;;          (let ((props (group-styles ,group-name-key))
;;                (s (make-instance ',group-name)))
;;            (dolist (prop props)
;;              (push (style-of styles prop) (style-sub-styles s)))
;;            s))

;;        (defmethod make-style ((property (eql ,group-name-key)) value)
;;          (let ((result (progn ,@body))) ; result is the list of sub-style objects
;;            (if result
;;                (let ((inst (make-instance ',group-name
;;                                           ;; The :property slot is initialized by the group-name class's defclass initform.
;;                                           ;; The :value initarg is inherited from the 'style' class.
;;                                           ;; We need to wrap the raw 'value' (the shorthand) into a 'value' object.
;;                                           :value (make-instance 'value :value value :type t))))
;;                  ;; The 'result' (list of parsed sub-style objects) is set to the sub-styles slot.
;;                  (setf (style-sub-styles inst) result)
;;                  inst)
;;                (signal 'illegal-group-value
;;                        :style ',group-name
;;                        :value value)))))))

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
;;; == elmtui/style/registry.lisp ==
;;; == elmtui/style/macros.lisp ==





(defstruct stylegroup
  key
  expander
  leafs
  axes
  synonyms
  doc)

(defparameter *stylegroup-registry* (make-hash-table :test 'eq))

(defun define-stylegroup (key &key expander leafs axes synonyms doc)
  (setf (gethash key *stylegroup-registry*)
        (make-stylegroup :key key :expander expander
                         :leafs leafs :axes axes :synonyms synonyms :doc doc))
  key)

(defun lookup-stylegroup (key)
  (gethash key *stylegroup-registry*))

;; Expand *all* registered groups on a style plist.
;; Safe to call multiple times; order is irrelevant due to put-if-absent.
(defun expand-stylegroups (style)
  (let ((out style))
    (maphash
     (lambda (_k sg)
       (declare (ignore _k))
       (let ((exp (stylegroup-expander sg)))
         (setf out (funcall exp out))))
     *stylegroup-registry*)
    out))

;;; == end/registry.lisp ==
;; ---------------------------------------------------------------------------
;; DEFSTYLEGROUP
;; Declares a style group with:
;;  - :name            keyword for the group (e.g., :padding)
;;  - :doc             docstring
;;  - :leaf-keys       final concrete keys produced by expansion
;;  - :axes            axis keywords and the set of leafs they map to (e.g., :x -> (:left :right))
;;  - :synonyms        optional extra entry keys that alias the group (e.g., :p aliases :padding)
;;  - :tuple->map      lambda that converts a tuple form into a plist of leaf assignments
;;  - :normalizers     alist of (key . fn) to normalize incoming values for specific leafs
;; Generates and registers an expansion function that:
;;   - reads group, axis, and leaf-level shorthands
;;   - applies precedence: leaf > axis > group
;;   - merges into the working plist without clobbering existing specific keys
;; ---------------------------------------------------------------------------
(defmacro defstylegroup (name &key doc leaf-keys axes synonyms tuple->map normalizers)
  "Define a stylegroup NAME and register its expander.

  Declares a style group with:
    - :name            keyword for the group (e.g., :padding)
    - :doc             docstring
    - :leaf-keys       final concrete keys produced by expansion
    - :axes            axis keywords and the set of leafs they map to (e.g., :x -> (:left :right
    - :synonyms        optional extra entry keys that alias the group (e.g., :p aliases :padding
    - :tuple->map      lambda that converts a tuple form into a plist of leaf assignments
    - :normalizers     alist of (key . fn) to normalize incoming values for specific leafs
    Generates and registers an expansion function that:
    - reads group, axis, and leaf-level shorthands
    - applies precedence: leaf > axis > group
    - merges into the working plist without clobbering existing specific keys
    Example:
        (defstylegroup :padding
            :doc \"Padding stylegroup with axes and leaves.\"
            :leaf-keys (:top :bottom :left :right)
            :axes ((:x (:left :right)) (:y (:top :bottom)))
            :synonyms (:p)
            :tuple->map (lambda (t) (list :top (first t) :bottom (second t)))
            :normalizers ((:top . normalize-top) (:bottom . normalize-bottom)))
    This defines a stylegroup `:padding` that can be expanded from a style plist.
    The expansion function will handle:
    - Single scalar values for the group (applies to all leaves)
    - 2-tuple values for axes (e.g., (:x 10) applies 10 to both :left and :right
    - 3-tuple values for axes (e.g., (:y 5 15) applies 5 to :top and 15 to :bottom
    - 4-tuple values for axes (e.g., (:padding 5 10 15 20) applies to all four leaves
    - Leaf-specific values (e.g., (:top 5) applies 5 to :top only
    The expansion function will also normalize values for specific leaves using the provided
    normalizers, if any. (Note: The normalizers are applied after the group and axis expansions."
  (let* ((fname (intern (string-upcase (format nil "expand-~a" name)) *package*))
         (group-key name)
         (syns (or synonyms)))
    `(progn
       (defun ,fname (style)
         ,(or doc (format nil "Expand stylegroup ~a." name))
         (labels
             ((put-if-absent (plist key val)
                ;; do not clobber explicit value already present
                (if (getf plist key)
                    plist
                    (list* key val plist)))

              (apply-mapping (plist pairs)
                (loop for (k v) on pairs by #'cddr
                      do (setf plist (put-if-absent plist k v))
                      finally (return plist))))

           ;; 1) Collect raw inputs (group, axes, leaves, synonyms)
           (let* ((group-val (or (getf style ,group-key)
                                 ,@(when syns
                                     `((or ,@(mapcar (lambda (s) `(getf style ,s)) syns))))))
                  (axis-vals (list
                              ,@(loop for (ax . leaves) in axes
                                      collect `(list ,ax (getf style ,ax) ',leaves))))
                  (leaf-vals (list
                              ,@(loop for leaf in leaf-keys
                                      collect `(list ,leaf (getf style ,leaf)))))
                  (result style))
             (declare (ignorable leaf-vals))
             ;; 2) Group-level (lowest precedence). Accepts:
             ;;    - single scalar (applies to all leaves)
             ;;    - 2-tuple (y x)
             ;;    - 3-tuple (top x bottom)
             ;;    - 4-tuple (top right bottom left)
             (when group-val
               (let* ((gmap
                        (cond
                          ((and (consp group-val) ,(if tuple->map t nil))
                           (funcall ,tuple->map group-val))
                          (t
                           ;; broadcast scalar to all leaves
                           (loop for leaf in ',leaf-keys append (list leaf group-val))))))
                 (setf result (apply-mapping result gmap))))

             ;; 3) Axis-level (middle precedence). Each axis assigns a subset of leaves.
             (dolist (ax axis-vals)
               (destructuring-bind (ax-key ax-val leaves) ax
                 (declare (ignore ax-key))
                 (when ax-val
                   (let ((pairs (loop for leaf in leaves append (list leaf ax-val))))
                     (setf result (apply-mapping result pairs))))))

             ;; 4) Leaf-level (highest precedence) — do nothing here because put-if-absent
             ;;    already preserved explicit leafs. We only optionally normalize.
             (when ,(not (null normalizers))
               (dolist (spec ',normalizers)
                 (destructuring-bind (k . fn) spec
                   (let ((v (getf result k :__missing)))
                     (unless (eq v :__missing)
                       (setf (getf result k) (funcall fn v)))))))

             ;; 5) Remove group & axes entry keys from the surface (idempotent output)
             (dolist (k (append (list ,group-key ,@syns)
                                (list ,@(mapcar #'car axes))))
               (remf result k))

             result)))

       ;; 6) Register with the global registry
       (define-stylegroup ,group-key
         :expander #',fname
         :leafs ',leaf-keys
         :axes ',(mapcar #'car axes)
         :synonyms ',syns
         :doc ,doc))))
