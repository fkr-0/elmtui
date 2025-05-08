;;; ─────────────────────────── 0. Dependencies ───────────────────────────
(uiop:define-package :elmtui.style-lib.util
  (:use :cl)
  (:import-from :str :split :join :upcase)
  ;; (:import-from :elmtui.style-lib.types :stylable)
  (:import-from :elmtui.style-lib.api :ordered-styles)
  ;; (:import-from :elmtui.style-lib.selector :selects)
  (:export :=? :string-ci= :hash-table-keys :hash-table-values
           :keyword-split :keyword-concat
           :pad-fill-char :margin-fill-char
           :kw-split :kw-join :ensure-list
   :apply-after )) ; Export new functions

(in-package :elmtui.style-lib.util)

(defun string-ci= (a b) (string= (string a) (string b)))

(defgeneric =? (a b) (:documentation "Deep structural equality."))
(defmethod =? ((a t) (b t)) (eql a b))
(defmethod =? ((a string) (b string)) (string-ci= a b))
(defmethod =? ((a number) (b number)) (= a b))
(defmethod =? ((a list) (b list))
  (and (= (length a) (length b)) (every #'=? a b)))
(defmethod =? ((a hash-table) (b hash-table))
  (and (= (hash-table-count a) (hash-table-count b))
       (every (lambda (k) (=? (gethash k a) (gethash k b)))
              (hash-table-keys a))))

(defun hash-table-keys (ht) (loop for k being the hash-keys of ht collect k))
(defun hash-table-values (hash-table)
  "Return a list of the values in HASH-TABLE."
  (loop for key being the hash-keys of hash-table
        collect (gethash key hash-table)))
(defun ensure-list (x) (if (listp x) x (list x)))


(defparameter *pad-fill-char* #\Space)
(defparameter *margin-fill-char* #\Space)

(defun keyword-split (kw &key (sep "-") (pos nil))
  "Splits a keyword into a list of keywords. SEQ is the separating character and \"-\"
is the default. If POS is nil, returns a list of keywords. If POS is :last, returns the last keyword. If POS is :first,
returns the first keyword. Otherwise, returns the keyword at POS."
  (let ((kz
          (mapcar (lambda (x) (intern (upcase x) :keyword))
                  (split sep (symbol-name kw)))))
    (cond ((null pos) kz)
          ((eq pos 'last) (car (last kz)))
          ((eq pos 'first) (first kz))
          (t (nth pos kz)))))
(defun keyword-concat (kw-list &key (sep "-"))
  "Concatenates a list of keywords into a single keyword."
  (intern (join sep (mapcar #'symbol-name kw-list)) :keyword))

(defgeneric =? (a b)
  (:method ((a t) (b t))
    (eql a b))
  (:method ((a list) (b list))
    (and (eql (length a) (length b))
         (every #'=? a b)))
  (:method ((a symbol) (b symbol))
    (eql a b))
  (:method ((a string) (b string))
    (string= a b))
  (:method ((a number) (b number))
    (= a b))
  (:method ((a cons) (b cons))
    (and (=? (car a) (car b))
         (=? (cdr a) (cdr b))))
  (:method ((a hash-table) (b hash-table))
    (and (eql (hash-table-count a) (hash-table-count b))
         (every (lambda (key)
                  (let ((a-val (gethash key a))
                        (b-val (gethash key b)))
                    (if (and a-val b-val)
                        (=? a-val b-val)
                        (and (null a-val) (null b-val)))))
                (hash-table-keys a))))
  (:method ((a null) (b null))
    t)
  (:method ((a t) (b null))
    nil)
  (:method ((a null) (b t))
    nil)
  (:documentation "A generic equality function that compares two objects for equality."))

;; Define stub/placeholder functions for apply-after and ordered-styles
(defmethod apply-after (style-key context)
  "Placeholder: Determines application order. Returns :non-decorating, :top, :box, etc."
  (declare (ignore style-key context))
  ;; Default behavior: assume non-decorating unless specified otherwise elsewhere
  :non-decorating)

(defmethod ordered-styles (style-key-list)
  "Placeholder: Sorts a list of style keys based on application order."
  ;; Default behavior: return the list as is
  style-key-list)
