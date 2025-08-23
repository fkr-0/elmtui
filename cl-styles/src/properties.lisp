(in-package :cl-styles.properties)

(define-condition style-contract-violation (error)
  ((expected :initarg :expected :reader expected)
   (got      :initarg :got      :reader got)
   (where    :initarg :where    :reader where))
  (:report (lambda (c s)
             (format s "Style contract violation at ~A: expected ~A, got ~S"
                     (where c) (expected c) (got c)))))

(defparameter *property-registry* (make-hash-table :test 'eql))
(defparameter *groups* (make-hash-table :test 'eql))
(defparameter *layout-groups* (make-hash-table :test 'eql))

(defun register-property (name def)
  (setf (gethash name *property-registry*) def))

(defun property-definition (name)
  (gethash name *property-registry*))

(defmacro defproperty (name &key type enum synonyms group default doc)
  `(register-property ,name (list :type ,(if (and (consp type) (eq (car type) 'lambda))
                                            `#',type
                                            `',type)
                                   :enum ',enum :synonyms ',synonyms :group ',group :default ',default :doc ,doc)))

(defun define-group (group &rest props)
  (setf (gethash group *groups*) (remove-duplicates props :test 'eql)))

(defun properties-for-group (group)
  (copy-list (or (gethash group *groups*))))

(defun groups-for-layout (layout &rest groups)
  (setf (gethash layout *layout-groups*) (remove-duplicates groups :test 'eql)))

(defun properties-for-layout (layout)
  (let ((gs (or (gethash layout *layout-groups*) )))
    (remove-duplicates (apply #'append (mapcar #'properties-for-group gs)) :test 'eql)))

;; basic type predicates
(defun %keyword-p (x) (and (symbolp x) (keywordp x)))
(defun %number-p (x) (numberp x))
(defun %string-p (x) (stringp x))
(defun %length-p (x)
  (and (consp x) (member (first x) '(:px :percent :em :rem :ch))))

(defun %ensure-keyword (x)
  (cond
    ((keywordp x) x)
    ((symbolp x) (intern (string-upcase (symbol-name x)) :keyword))
    ((stringp x) (intern (string-upcase x) :keyword))
    (t x)))

(defun %normalize-key (k)
  (%ensure-keyword k))

(defun %normalize-value (prop v)
  (let* ((def (property-definition prop))
         (syns (getf def :synonyms nil))
         (vv (%ensure-keyword v)))
    (cond
      ((and syns (hash-table-p syns))
       (multiple-value-bind (m present) (gethash vv syns)
         (if present m vv)))
      (t vv))))

(defun %check-type (prop v)
  (let* ((def (property-definition prop))
         (type (getf def :type nil))
         (enum (getf def :enum nil))
         (nv (%normalize-value prop v)))
    (flet ((fail (expected)
             (error 'style-contract-violation :expected expected :got nv :where prop)))
      (when enum
        (unless (member nv enum :test 'eql)
          (fail `(one-of ,@enum))))
      (when type
        (cond
          ((keywordp type)
           (case type
             (:keyword (unless (%keyword-p nv) (fail :keyword)))
             (:number  (unless (%number-p nv)  (fail :number)))
             (:length  (unless (%length-p nv)  (fail :length)))
             (:string  (unless (%string-p nv)  (fail :string)))
             (t (error "Unknown keyword property type: ~A" type))))
          ((functionp type)
           (unless (funcall type nv)
             (fail type)))
          (t (error "Invalid type specifier: ~A" type)))))
    nv))

(defun normalize-declarations (plist)
  (let ((out (copy-list (or plist nil))))
    (loop for (k v) on out by #'cddr do
      (let* ((kk (%normalize-key k))
             (vv (%normalize-value kk v)))
        (setf (getf out kk) vv)
        (setf (getf out k) vv)))
    out))

(defun validate-declarations (plist)
  (loop for (k v) on plist by #'cddr do
    (let* ((kk (%normalize-key k))
           (vv (%normalize-value kk v)))
      (when (property-definition kk)
        (%check-type kk vv))))
  plist)

(defun ensure-declarations (plist)
  (validate-declarations (normalize-declarations plist)))

;;; ----------------- seed: groups + common properties ----------------------

;; box groups
(define-group :padding :padding :padding-top :padding-right :padding-bottom :padding-left)
(define-group :margin  :margin  :margin-top  :margin-right  :margin-bottom  :margin-left)
(define-group :border  :border :border-width :border-top-width :border-right-width :border-bottom-width :border-left-width)
(apply #'define-group :box
       (append (properties-for-group :padding)
               (properties-for-group :margin)
               (properties-for-group :border)))

;; layout groups
(define-group :flex :display :flex-direction :flex-wrap :justify-content :align-items :align-content :gap :row-gap :column-gap :order :flex-grow :flex-shrink :flex-basis)
(define-group :grid :display :grid-template-columns :grid-template-rows :grid-template-areas :grid-auto-flow :grid-auto-columns :grid-auto-rows :gap :grid-gap :row-gap :column-gap :justify-items :align-items :justify-content :align-content)
(define-group :block :display :width :height :min-width :max-width :min-height :max-height)

;; layout -> groups mapping
(groups-for-layout :flex :box :flex)
(groups-for-layout :grid :box :grid)
(groups-for-layout :block :box :block)

;; common properties and enums
(defun %mk-syns (&rest pairs)
  (let ((ht (make-hash-table :test 'equal)))
    (loop for (a b) on pairs by #'cddr do (setf (gethash a ht) b)) ht))

(defproperty :display :type :keyword :enum (:block :flex :grid :none))
(defproperty :width   :type :number)
(defproperty :height  :type :number)
(defproperty :min-width  :type :number)
(defproperty :max-width  :type :number)
(defproperty :min-height :type :number)
(defproperty :max-height :type :number)

;; flex props
(defproperty :flex-direction :type :keyword :enum (:row :row-reverse :column :column-reverse))
(defproperty :flex-wrap      :type :keyword :enum (:nowrap :wrap :wrap-reverse))
(defproperty :justify-content :type :keyword :enum (:flex-start :flex-end :center :space-between :space-around :space-evenly)
  :synonyms (%mk-syns :start :flex-start :end :flex-end))
(defproperty :align-items    :type :keyword :enum (:stretch :flex-start :flex-end :center :baseline)
  :synonyms (%mk-syns :start :flex-start :end :flex-end))
(defproperty :align-content  :type :keyword :enum (:stretch :flex-start :flex-end :center :space-between :space-around :space-evenly)
  :synonyms (%mk-syns :start :flex-start :end :flex-end))
(defproperty :gap :type :number)
(defproperty :row-gap :type :number)
(defproperty :column-gap :type :number)
(defproperty :order :type :number)
(defproperty :flex-grow :type :number)
(defproperty :flex-shrink :type :number)
(defproperty :flex-basis :type :number)

;; grid props
(defproperty :grid-template-columns :type (lambda (v) (or (null v) (listp v))))
(defproperty :grid-template-rows    :type (lambda (v) (or (null v) (listp v))))
(defproperty :grid-template-areas   :type (lambda (v) (or (null v) (listp v))))
(defproperty :grid-auto-flow        :type :keyword :enum (:row :column :row-dense :column-dense))
(defproperty :grid-auto-columns     :type (lambda (v) (or (null v) (listp v) (numberp v))))
(defproperty :grid-auto-rows        :type (lambda (v) (or (null v) (listp v) (numberp v))))
(defproperty :justify-items         :type :keyword :enum (:start :end :center :stretch))

;; box props
(defproperty :padding :type (lambda (v) (or (numberp v) (listp v))))
(defproperty :padding-top :type :number)
(defproperty :padding-right :type :number)
(defproperty :padding-bottom :type :number)
(defproperty :padding-left :type :number)
(defproperty :margin :type (lambda (v) (or (numberp v) (listp v))))
(defproperty :margin-top :type :number)
(defproperty :margin-right :type :number)
(defproperty :margin-bottom :type :number)
(defproperty :margin-left :type :number)
(defproperty :border :type (lambda (v) (or (numberp v) (listp v))))
(defproperty :border-width :type :number)
(defproperty :border-top-width :type :number)
(defproperty :border-right-width :type :number)
(defproperty :border-bottom-width :type :number)
(defproperty :border-left-width :type :number)

;; border style and color
(defproperty :border-style :type :keyword :enum (:none :solid :dashed :dotted :double))
(defproperty :border-top-style :type :keyword :enum (:none :solid :dashed :dotted :double))
(defproperty :border-right-style :type :keyword :enum (:none :solid :dashed :dotted :double))
(defproperty :border-bottom-style :type :keyword :enum (:none :solid :dashed :dotted :double))
(defproperty :border-left-style :type :keyword :enum (:none :solid :dashed :dotted :double))
(defproperty :border-color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v))))
(defproperty :border-top-color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v))))
(defproperty :border-right-color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v))))
(defproperty :border-bottom-color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v))))
(defproperty :border-left-color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v))))

;; text properties
(defproperty :color :type (lambda (v) (or (keywordp v) (cl-styles.tokens:color-p v) (and (consp v) (eq (car v) 'cl-styles.tokens:var)))))
(defproperty :font-family :type :string)
(defproperty :font-size :type :number)
(defproperty :font-weight :type :keyword :enum (:normal :bold :bolder :lighter :inherit))
