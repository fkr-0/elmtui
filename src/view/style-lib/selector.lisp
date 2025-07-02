;;; ───────────────────────── 2. Selector Engine ──────────────────────────
(uiop:define-package :elmtui.style-lib.selector
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.types :elmtui.style-lib.api :elmtui.view.core)
  (:import-from :elmtui.style-lib.api
   :selector :selects :specificity :stylable)
  (:import-from :elmtui.view.api :ui-node-type )
  (:export
   ;; selector classes
   :selector :type-selector :class-selector :id-selector
   :combined-selector :or-selector :child-selector :desc-selector
   ;; reader macros
   :type> :cls> :id> :and> :or> :child> :descendant> ; Added type>, removed cl-cls>
   ;; Accessors
   :sel-type :sel-class :sel-id :subs :parent :child :anc :desc
   ;; API
   :specificity
   :node-type))  ; Export the new generic function

(in-package :elmtui.style-lib.selector)


;;; base + generics ------------------------------------------------
;;; imported from style-lib/api

(defmethod print-object ((selector selector) stream)
  "Print a representation of the selector."
  (format stream "<~a:>" (type-of selector)))


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
(defmethod specificity ((s id-selector)) 100)

;; New Type Selector
(defclass type-selector (selector)
  ((node-type :initarg :node-type :reader sel-type :type keyword)))

(defmethod selects ((s type-selector) o)
  "Match by node type for any UI node (including styled ones)"
  (eq (sel-type s) (ui-node-type o)))

;; (defgeneric node-type (object)
;;   (:method ((node ui-node))
;;     (ui-node-type node))
;;   (:method ((node stylable))
;;     (when (slot-boundp node 'ui-node-type)
;;       (slot-value node 'ui-node-type)))
;;   (:method (object)
;;     nil))

(defmethod selects ((s type-selector) (o t))
  "Fallback for type selectors on any object"
  (eq (sel-type s) (ui-node-type o)))
(defmethod specificity ((s type-selector)) 1) ; Specificity like an element type

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
(defmacro type> (kw) `(make-instance 'type-selector :node-type ,kw)) ; New macro for type selector
(defmacro and> (&rest subs) `(make-instance 'combined-selector :subs (list ,@subs)))
(defmacro or>  (&rest subs) `(make-instance 'or-selector       :subs (list ,@subs)))
(defmacro child> (p c) `(make-instance 'child-selector :parent ,p :child ,c))
(defmacro descendant> (a d) `(make-instance 'desc-selector :anc ,a :desc ,d))

;;; Type Selector (using keywords)
;;; Universal Selector (using a specific class might be cleaner, but eql specializer works)
(defmethod selects ((selector (eql :*)) o)
  "The universal selector '*' matches everything."
  (declare (ignore o))
  t)
(defmethod specificity ((selector (eql :*))) 0)

;;; fallback for selector classes against non-stylable objects
(defmethod selects ((s selector) (o t))
  (declare (ignore s o))
  nil)

;;; fallback specificity
(defmethod specificity ((s t)) 0) ; Specificity for anything not explicitly defined
