;;; ───────────────────────── 4. Style-Set  ────────────────────────────────
(uiop:define-package :elmtui.style-lib.style-set
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.api #:log4cl)
  ;; Import from API (Corrected & Added)
  (:import-from :elmtui.style-lib.api #:new
                #:new #:style-set-valid #:style-set-styles #:style-set-order
                #:style-set #:make-style-set #:make-default-styling
                #:valid-value-p #:group-key #:group-styles #:stylegroup-p #:sub-styles
                #:style-property-of #:make-style #:ordered-styles ; Added make-style, ordered-styles
                #:styles-list
                ;; Import from Types (Corrected)
                #:style #:style-property #:style-value #:value-value)
  ;; Import from Util (Added apply-after explicitly)
  (:import-from :elmtui.style-lib.util
                #:hash-table-keys #:hash-table-values #:apply-after) ; Added apply-after
  (:export :style-of :value-of :set-style :merge-sets! :copy-set
   :parse-styles
           :new
   :*default-style-set*
           :default-styles
   :around-styles :ordered-around-styles))

(in-package :elmtui.style-lib.style-set)


(defun style-of (set prop)
  "Get the style object for PROP in SET."
  (gethash prop (style-set-styles set)))

(defun value-of (set prop &optional default)
  "Get the raw value of PROP in SET, returning DEFAULT if not found."
  (let ((style (style-of set prop)))
    (if style
        (value-value (style-value style)) ; Consistent access for both style and style-group
        default)))
;; (styles-list (elmtui.style-lib.api::new 'elmtui.style-lib.api:style-set
;;                :styles
;;                '(:display :flex :flex-direction
;;                   :column :width :fill :height :fill
;;                   :align-items :center :padding 1)))
;; (style-value (style-of (elmtui.style-lib.api::new 'elmtui.style-lib.api:style-set
;;                :styles
;;                '(:display :flex :flex-direction
;;                   :column :width :fill :height :fill
;;                   :align-items :center :padding 1)) :padding))
(defun set-style (set prop val)
  "Create and set a style object for PROP with VAL in SET."
  (setf (gethash prop (style-set-styles set)) (make-style prop val)))

(defun merge-sets! (into from)
  "Destructively merge styles from FROM into INTO."
  (when from ; Only proceed if 'from' is not nil
    (maphash (lambda (k v) (setf (gethash k (style-set-styles into)) v))
             (style-set-styles from)))
  into)
(defun copy-set (set) (merge-sets! (make-style-set) set))

(defun parse-styles (&rest raw)
  (loop for (k v) on raw by #'cddr collect (make-style k v)))

;; (defun styles-list (set)
;;   (loop for k in (sort (hash-table-keys (style-set-styles set))
;;                        (lambda (a b) (string< (symbol-name a) (symbol-name b))))
;;         collect k and collect (value-of set k)))
(defmethod styles-list (set)
  (loop for k in (sort (hash-table-keys (style-set-styles set))
                       (lambda (a b)
                         (string< (symbol-name a) (symbol-name b))))
        append (list k (value-of set k)))) ; builds plist


;; (defun around-styles (set) (hash-table-keys (style-set-styles set)))
;; (defun ordered-around-styles (set) (or (style-set-order set)
;;                                        (setf (style-set-order set) (around-styles set))))

;;; defaults ---------------------------------------------------------------

;;; Fix style-set-valid to use valid-value-p and recursively validate style-groups
(defmethod style-set-valid ((set style-set))
  "Check if all styles in the style-set have valid values.
   For style-groups, this means all their sub-styles must be valid."
  (and (hash-table-p (style-set-styles set))
       (every (lambda (style-object) ; Can be a 'style or 'style-group instance
                (if (stylegroup-p style-object)
                    ;; For a style-group, it's valid if all its sub-styles are valid.
                    ;; Each sub-style is expected to be a regular 'style' object.
                    (every (lambda (sub-s)
                             (and sub-s ; Sub-style itself must exist
                                  (typep sub-s 'style) ; Must be a style object
                                  (style-property sub-s) ; Its property slot must be bound
                                  (style-value sub-s)    ; Its value slot (a value object) must be bound
                                  (valid-value-p (style-property sub-s)
                                                 (value-value (style-value sub-s)))))
                           (sub-styles style-object))
                    ;; For a regular 'style' object
                    (and (style-property style-object) ; Its property slot must be bound
                         (style-value style-object)    ; Its value slot (a value object) must be bound
                         (valid-value-p (style-property style-object)
                                        (value-value (style-value style-object))))))
              (hash-table-values (style-set-styles set)))))

;;; Define *default-style-set* after default-style-set function
;;; (defparameter *default-style-set* (make-style-set)) ; Moved down

(defun style-list-to-hash (style-list)
  "Convert a style specification list to a hash table for a style-set.
   If the input is a plist (e.g., '(:padding 1 :color :red)), it creates style objects.
   If the input is a list of style objects, it uses them directly.
   If a style object is a style-group, its sub-styles are also added to the hash table."
  (let ((hash (make-hash-table :test #'equal)))
    (if (keywordp (car style-list))
        ;; Input is a plist, e.g., '(:padding 1 :color :red)
        (loop for (key value-spec) on style-list by #'cddr
              do (let ((style-object (make-style key value-spec)))
                   (setf (gethash key hash) style-object)
                   (when (stylegroup-p style-object)
                     (dolist (sub-style (sub-styles style-object))
                       ;; Ensure sub-style is not nil and is a style object before proceeding
                       (when (and sub-style (typep sub-style 'style))
                         (setf (gethash (style-property-of sub-style) hash) sub-style))))))
        ;; Input is a list of pre-created style objects
        (dolist (style-object style-list)
          (when (and style-object (typep style-object 'style)) ; Ensure it's a valid style object
            ;; Add the main style/group object.
            ;; style-property-of should give the primary key for both simple styles and style groups.
            (setf (gethash (style-property-of style-object) hash) style-object)
            (when (stylegroup-p style-object)
              (dolist (sub-style (sub-styles style-object))
                (when (and sub-style (typep sub-style 'style))
                  (setf (gethash (style-property-of sub-style) hash) sub-style)))))))
    hash))
;; (defun styles-list (set)
;;   (loop for k in (sort (hash-table-keys (style-set-styles set))
;;                    (lambda (a b) (string< (symbol-name a) (symbol-name b))))
;;     collect (list k (value-of set k))))
;; (styles-list (elmtui.style-lib.api::new 'elmtui.style-lib.api:style-set
;;                :styles
;;                '(:display :flex :flex-direction
;;                   :column :width :fill :height :fill
;;                   :align-items :center :padding 1)))
;; (defmethod new ((class (eql 'style-rule)) &key selector styles)
;;   "Create a new style rule."
;;   (let* ((styles-map (if (listp styles) (style-list-to-hash styles) styles))
;;           (rule (make-instance 'style-rule :selector selector :styles styles-map)))
;;     (when (style-rule-valid rule) rule)))

(defmethod new ((class (eql 'style-set)) &key styles)
  "Create a new style set."
  (let ((set (make-instance 'elmtui.style-lib.api:style-set)))
    (setf (style-set-styles set)
          (if (listp styles) (style-list-to-hash styles)
              styles))
    (when (style-set-valid set) set)))
;; (make-style :padding '(2))
;; (defvar *default-styles*
;;   (default-style-set)
;;   "Default style set containing all default styles.")

(defmethod print-object ((set style-set) stream)
  "Print a representation of the style-set to the given stream."
  (format stream "#<STYLE-SET ~A>" (styles-list set)))

;;; Fix around-styles to use group-key and apply-after correctly
(defmethod around-styles ((set style-set))
  "Return the list of decorator styles (properties/group keys) in the given style set."
  (let ((decorator-styles nil))
    (maphash
     (lambda (k v) ; k is property keyword, v is style object
       (let ((group-key (when (stylegroup-p v) (group-key v))) ; Check if it's a group and get its key
             (prop-key k))
         (if group-key
             (unless (member group-key decorator-styles) ; Add group key only once
               ;; Check apply-after for the group key
               (unless (eql (apply-after group-key nil) :non-decorating)
                 (push group-key decorator-styles)))
             ;; If not a group, check apply-after for the property key
             (unless (eql (apply-after prop-key nil) :non-decorating)
               (push prop-key decorator-styles)))))
     (style-set-styles set))
    (nreverse decorator-styles))) ; Return in a consistent order

;;; Fix ordered-around-styles call (assuming ordered-styles is in API or Util)
(defmethod ordered-around-styles ((set style-set))
  "Return the decorator styles of the given style set in order."
  ;; Assuming ordered-styles is available (imported from API now)
  (let ((order (or (style-set-order set) (ordered-styles (around-styles set)))))
    (setf (style-set-order set) order)
    order))

;;; Fix (setf value-of) to use valid-value-p and imported style-property
(defmethod (setf value-of) (new-value (set style-set) property)
  "Set the raw value of the given property in the given style set.
   Creates the style if it doesn't exist. Removes if new-value is nil."
  (if (null new-value)
      ;; Remove the style if value is nil
      (remhash property (style-set-styles set))
      ;; Otherwise, update or create the style
      (let ((existing-style (style-of set property)))
        (if existing-style
            ;; Update existing style's value if valid
            (progn
              (unless (valid-value-p (style-property existing-style) new-value)
                (error "Invalid value: ~S for property ~S" new-value property))
              (setf (value-value (style-value existing-style)) new-value))
            ;; Create new style if valid
            (let ((new-style (make-style property new-value))) ; make-style handles validation
              (setf (gethash property (style-set-styles set)) new-style)))))
  new-value)

;;; Fix (setf style-of) to use style-property-of instead of tuple-prop
(defmethod (setf style-of) (style-instance (set style-set) (property symbol) &optional args)
  "Set the style instance for the given property keyword in the given style set.
   If the style-instance is a style-group, also sets its sub-styles."
  (declare (ignore args))
  (check-type style-instance (or style null)) ; Allow setting to nil to remove

  (if (null style-instance)
      (remhash property (style-set-styles set))
      (progn
        ;; Set the main style/group itself
        (setf (gethash property (style-set-styles set)) style-instance)
        ;; If it's a group, also set its sub-styles individually
        (when (stylegroup-p style-instance)
          (dolist (sub-style (sub-styles style-instance))
            (setf (style-of set (style-property-of sub-style)) sub-style))))))

(defmethod (setf style-of)
    (values (set style-set) (properties list) &optional args)
  "Set multiple styles in the given style set."
  (declare (ignore args))
  (loop for property in properties
        for value in values
        do (setf (style-of set property) value)))

(defmethod merge-styles! ((set style-set) (other style-set))
  "Merge the styles from another style set into this one."
  (maphash (lambda (k v) (setf (style-of set k) v)) (style-set-styles other))
  set)

(defgeneric copy (set)
  (:method ((set null))
    (make-style-set))
  (:method ((set t))
    (make-style-set))
  (:documentation "Return a copy of the given style set."))

(defmethod copy ((set style-set))
  "Return a copy of the given style set."
  (let ((copy (make-style-set)))
    (merge-sets! copy set) ; Corrected from merge-styles!
    copy))

;;; Define *default-style-set* after default-style-set function
(defparameter *default-style-set* (make-style-set))

(defun default-style-set ()
  "Create a default style set derived from all styles that define a default value."
  (new 'style-set :styles (make-default-styling)))

(defvar *default-styles*
  (default-style-set)
  "Default style set containing all default styles.")

(defmethod print-object ((set style-set) stream)
  "Print a representation of the style-set to the given stream."
  (format stream "#<STYLE-SET ~A>" (styles-list set)))


;;; Fix invert-colors! to use the value-of function correctly
(defmethod invert-colors! ((set style-set))
  "Mutate the given style set by inverting the foreground and background colors."
  (let ((fg (value-of set :fg-color))
        (bg (value-of set :bg-color)))
    (setf (value-of set :fg-color) bg) ; Use (setf value-of)
    (setf (value-of set :bg-color) fg) ; Use (setf value-of)
    set))

(defmethod invert-colors ((set style-set))
  "Return a new style set with the foreground and background colors inverted."
  (invert-colors! (copy set)))

;; End of style-set.lisp
