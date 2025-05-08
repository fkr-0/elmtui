;;; ───────────────────────── 2. Selector Engine ──────────────────────────
(uiop:define-package :elmtui.style-lib.selector
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.types :elmtui.style-lib.api)
  (:export
   ;; selector classes
   :selector :class-selector :id-selector :lisp-class-selector
   :combined-selector :or-selector :child-selector :desc-selector
   ;; reader macros
   :cls> :id> :cl-cls> :and> :or> :child> :descendant>
   ;; API
   :selects :specificity))

(in-package :elmtui.style-lib.selector)

(defclass selector () ())

;;; base + generics
(defgeneric selects (selector target)
  (:documentation
   "Return T if the given selector selects the given target, NIL otherwise."))

(defmethod print-object ((selector selector) stream)
  "Print a representation of the selector."
  (format stream "<~a:>" (type-of selector)))

(defgeneric specificity (sel))

;;; simple selectors -------------------------------------------------------
(defclass class-selector (selector)
  ((class :initarg :class :reader sel-class)))
(defmethod selects ((s class-selector) (o stylable))
  (member (sel-class s) (classes o) :test #'string-ci=))
(defmethod specificity ((s class-selector)) 10)

(defclass id-selector (selector)
  ((id :initarg :id :reader sel-id)))
(defmethod selects ((s id-selector) (o stylable))
  (string-ci= (sel-id s) (stylable-id o)))
(defmethod specificity ((s id-selector)) 100)

(defclass lisp-class-selector (selector)
  ((klass :initarg :klass :reader sel-klass)))
(defmethod selects ((s lisp-class-selector) o)
  (typep o (sel-klass s)))
(defmethod specificity ((s lisp-class-selector)) 1)

;;; combinators ------------------------------------------------------------
(defclass combined-selector (selector)
  ((subs :initarg :subs :reader subs)))
(defmethod selects ((s combined-selector) o)
  (every (lambda (sub) (selects sub o)) (subs s)))
(defmethod specificity ((s combined-selector))
  (reduce #'+ (mapcar #'specificity (subs s))))

(defclass or-selector (selector) ((subs :initarg :subs :reader subs)))
(defmethod selects ((s or-selector) o)
  (some (lambda (sub) (selects sub o)) (subs s)))
(defmethod specificity ((s or-selector))
  (reduce #'max (mapcar #'specificity (subs s))))

(defclass child-selector (selector)
  ((parent :initarg :parent :reader parent)
   (child  :initarg :child  :reader child)))
(defmethod selects ((s child-selector) (o stylable))
  (and (selects (child s) o)
       (let ((p (first (parents-of o))))
         (and p (selects (parent s) p)))))
(defmethod specificity ((s child-selector))
  (+ 1 (specificity (parent s)) (specificity (child s))))

(defclass desc-selector (selector)
  ((anc :initarg :anc :reader anc)
   (desc :initarg :desc :reader desc)))
(defmethod selects ((s desc-selector) (o stylable))
  (and (selects (desc s) o)
       (some (lambda (p) (selects (anc s) p)) (parents-of o))))
(defmethod specificity ((s desc-selector))
  (+ (specificity (anc s)) (specificity (desc s))))

;;; reader convenience -----------------------------------------------------
(defmacro cls> (name) `(make-instance 'class-selector :class ,name))
(defmacro id>  (name) `(make-instance 'id-selector    :id    ,name))
(defmacro cl-cls> (sym) `(make-instance 'lisp-class-selector :klass ,sym))
(defmacro and> (&rest subs) `(make-instance 'combined-selector :subs (list ,@subs)))
(defmacro or>  (&rest subs) `(make-instance 'or-selector       :subs (list ,@subs)))
(defmacro child> (p c) `(make-instance 'child-selector :parent ,p :child ,c))
(defmacro descendant> (a d) `(make-instance 'desc-selector :anc ,a :desc ,d))

;;; fallback
(defmethod selects ((_ selector) (_x t)) nil)
(defmethod specificity ((_ selector)) 0)
