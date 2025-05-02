;;; ───────────────────────── 3. Style DSL  ────────────────────────────────
(uiop:define-package :cl-styles.styles
  (:use :cl :cl-styles.util :cl-styles.types)
  (:export
   :defstyle :defstylegroup :make-style :style-p
   :default-styles))

(in-package :cl-styles.styles)

(defun style-p (x) (typep x 'style))

;;; defstyle macro ---------------------------------------------------------
(defmacro defstyle (keyword spec &key default docstring)
  (let* ((pk (intern (string-upcase (string keyword)) :cl-styles.styles))
         (vk (intern (format nil "~a-VALUE" pk) :cl-styles.styles))
         (kwsym (intern (string keyword) :keyword)))
    `(progn
       (defclass ,pk (property) ()
         (:default-initargs :name ,(string keyword))
         (:documentation ,docstring))
       (defclass ,vk (value) ())
       (defmethod valid-value-p ((p ,pk) v)
         ,(cond ((listp spec) `(member v ',spec))
                ((symbolp spec) `(typep v ',spec))
                ((and (consp spec) (eq (first spec) 'function)) spec)
                (t `(error "Invalid value spec ~a" ',spec))))
       (defun ,(intern (format nil "MAKE-STYLE/~a" keyword) :cl-styles.styles) (val)
         (unless (valid-value-p (make-instance ',pk) val)
           (error "Invalid value ~a for ~a" val ',keyword))
         (make-instance 'style
                        :property (make-instance ',pk)
                        :value    (make-instance ',vk :value val :type ',spec)))
       (defmethod make-style ((sym (eql ',kwsym)) val)
         (,(intern (format nil "MAKE-STYLE/~a" keyword) :cl-styles.styles) val))
       ,@(when (not (eq default :unset))
           `((defmethod default-styles ()
               (cons (make-style ',kwsym ,default) (call-next-method))))))))

(defgeneric default-styles () (:method () nil))

;;; defstylegroup macro ----------------------------------------------------
(defmacro defstylegroup (group &rest members &key docstring &allow-other-keys)
  (let* ((kw (intern (string group) :keyword))
         (cls (intern (string-upcase (string group)) :cl-styles.styles)))
    `(progn
       (defclass ,cls (style-group) ())
       (defmethod group-key ((obj ,cls)) ',kw)
       (defmethod make-style ((sym (eql ',kw)) value)
         ;; naive CSS quad semantics (1–4 ints)
         (let ((vals (ensure-list value)) (subs '()))
           (labels ((push4 (ks v) (dolist (k ks) (push (make-style k v) subs))))
             (case (length vals)
               (1 (push4 ',members (first vals)))
               (2 (progn (push4 ',(subseq members 0 (/ (length members) 2)) (first vals))
                         (push4 ',(subseq members (/ (length members) 2)) (second vals))))
               (3 (progn (push (make-style (first ',members) (first vals)) subs)
                         (push (make-style (second ',members) (second vals)) subs)
                         (push (make-style (third ',members) (third vals)) subs)))
               (4 (loop for k in ',members
                        for v in vals
                        do (push (make-style k v) subs)))
               (t (error "Cannot split ~a into ~a" vals ',group))))
           (make-instance ',cls
                          :property (make-instance 'property :name ,(string kw))
                          :value    (make-instance 'value :value value)
                          :sub-styles (nreverse subs)))))))

;;; fallback make-style ----------------------------------------------------
(defmethod make-style (k v)
  (make-instance 'style
                 :property (make-instance 'property :name (string k))
                 :value    (make-instance 'value :value v :type (type-of v))))
