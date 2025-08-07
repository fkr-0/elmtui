(uiop:define-package :elmtui.utils
  (:use :cl :log4cl)
  ;; State Management
  ;; UI Utilities
  (:export #:ensure-list
           #:copy-hash-table
           #:split-props/children
           #:as
           #:get-path #:set-path
           #:parse-plist-and-children
           #:remove-path #:ensure-keyword
           #:coerce-fn #:hex-str-to-rgb))


(in-package :elmtui.utils)

(defun ensure-list (x)
  "Ensures that X is a list. If X is nil, returns an empty list.
   If X is already a list, returns it unchanged."
  (declare (type t x))
  (if (null x)
      nil
      (if (listp x)
          x
          (list x))))

(defun ensure-keyword (val)
  "Converts the value to a keyword. Strings are upcased.
Useful for ensuring path segments are keywords."
  (declare (type (or keyword string symbol) val))
  (etypecase val
    (keyword val)
    (string (intern (string-upcase val) :keyword))
    (symbol (intern (string-upcase (symbol-name val)) :keyword))))

(defun hex-str-to-rgb (hex-str)
  "Convert a hex color string (e.g., #RRGGBB) to a list of RGB integers."
  (when (and (stringp hex-str)
             (string= (subseq hex-str 0 1) "#")
             (= (length hex-str) 7))
    (let ((r (parse-integer (subseq hex-str 1 3) :radix 16))
          (g (parse-integer (subseq hex-str 3 5) :radix 16))
          (b (parse-integer (subseq hex-str 5 7) :radix 16)))
      (list r g b))))
(defun coerce-fn (v)
  "Coerce V to a symbol or lambda form."
  (cond ((symbolp v) `',v) ; Quote symbol for later evaluation
        ((and (consp v) (eq (car v) 'lambda)) `',v) ; Quote lambda form to store as cons
        ;; ((null v)
        ;;  (if err-on-nil
        ;;      (error "DEFAPPLICATION: :subscriptions-fn cannot be NIL")
        ;;      ''(lambda (model) (declare (ignore model)) nil)))
        ))






;; (defun %set-entry (container key value)
;;   "Destructively insert KEY ⇒ VALUE in CONTAINER; return (possibly new) container."
;;   (when (null key)
;;     (error "SET-ENTRY: KEY cannot be NIL"))
;;   (cond
;;     ((hash-table-p container)
;;      (setf (gethash key container) value)
;;      container)

;;     ((listp container)
;;      (if (%alist-p container)
;;          ;; -------- alist ----------
;;          (let ((pair (assoc key container)))
;;            (if pair
;;                (setf (cdr pair) value)                     ; overwrite
;;                (if container
;;                    (nconc container (list (cons key value))) ; append
;;                    (setq container (list (cons key value))))) ; first pair
;;            container)
;;          ;; -------- plist ----------
;;          (progn
;;            (setf (getf container key) value)               ; handles nil, too
;;            container)))

;;     (t (error (format nil "SET-ENTRY: unsupported container type ~S" (type-of container))))))

;; (defun %remove-entry (container key)
;;   "Remove KEY (single level).  ⇒ two values: NEW-CONTAINER, REMOVEDP."
;;   (cond
;;     ((hash-table-p container)
;;      (values container (remhash key container)))           ; REMHASH returns flag

;;     ((listp container)
;;      (if (%alist-p container)
;;          ;; -------- alist ----------
;;          (let* ((before (length container))
;;                 (new    (delete key container :key #'car :test #'eq :count 1)))
;;            (values new (/= before (length new))))
;;          ;; -------- plist ----------
;;          (let ((foundp (remf container key)))
;;            (values container foundp))))

;;     (t (values container nil))))                            ; unsupported → nothing
;; (defgeneric get-path (path data &optional default)
;;   (:documentation "Read value at PATH inside DATA; return DEFAULT if anything is missing.
;;    PATH may be a symbol/keyword (single level) or a proper list."))

;; (defmethod get-path ((path t) (data t) &optional default)
;;   (%get-path path data default))

;; (defmethod get-path ((path symbol) (data t) &optional default)
;;   (%get-path (list path) data default))

;; ;; (defmethod get-path (path (data null) &optional default)
;; ;;   (declare (ignore data))
;; ;;   default)
;; ;; ;;; 2. Public API ─────────────────────────────────────────────────────────────
;; (defun %get-path (path data &optional (default nil))
;;   "Read value at PATH inside DATA; return DEFAULT if anything is missing.
;;    PATH may be a symbol/keyword (single level) or a proper list."
;;   (cond
;;     ((null path) data)

;;     ((symbolp path)
;;      (%get-entry path data default))

;;     ((consp path)
;;      (let ((next (%get-entry (car path) data  default)))
;;        (if (eq next default)
;;            default
;;            (get-path (cdr path) next  default))))

;;     (t default)))

;; (defun set-path (data path value &key (createp nil))
;;   "Return *updated* DATA with VALUE stored at PATH.
;;    When CREATEP is NIL and an intermediate key is missing, signals an error.

;;    NB: For plists/alists the call may return a *new* top-level list
;;        (needed when DATA was NIL).  Always use the returned value."
;;   (labels ((%ensure-child (container key)
;;              ;; Return child, and container (maybe changed if we had to create)
;;              (let ((child (%get-entry key container  nil)))
;;                (cond
;;                  (child (values child container))
;;                  (createp
;;                   (let ((new-child (make-hash-table)))      ; default style
;;                     (values new-child (%set-entry container key new-child))))
;;                  (t
;;                   (error (format nil "Missing intermediate node ~A in PATH ~A (and :CREATEP NIL)"
;;                                  key path)))))))
;;     (cond
;;       ((symbolp path)                                       ; leaf
;;        (%set-entry data path value))

;;       ((consp path)
;;        (multiple-value-bind (child container*) (%ensure-child data (car path))
;;          (let* ((new-child (set-path child (cdr path) value :createp createp))
;;                 (container** (if (eq child new-child)
;;                                  container*
;;                                  (%set-entry container* (car path) new-child))))
;;            container**)))

;;       (t (error (format nil "SET-PATH: invalid PATH ~S" path))))))

;; (defun remove-path (data path &key (prune-empty t))
;;   "Delete the entry at PATH.
;;    ⇒ two values: NEW-DATA  REMOVEDP   (boolean).
;;    When PRUNE-EMPTY is true, empty containers created by the deletion
;;    are recursively removed."
;;   (cond
;;     ;; leaf --------------------------------------------------------------
;;     ((symbolp path)
;;      (%remove-entry data path))

;;     ;; interior ----------------------------------------------------------
;;     ((consp path)
;;      (let* ((key   (car path))
;;             (rest  (cdr path))
;;             (child (%get-entry key data  nil)))
;;        (if (null child)                                     ; nothing down there
;;            (values data nil)
;;            (multiple-value-bind (new-child removedp) (remove-path child rest
;;                                                                   :prune-empty prune-empty)
;;              (if (not removedp)                             ; nothing removed in branch
;;                  (values data nil)
;;                  (let* ((child-empty (%empty-container-p new-child))
;;                         (data* (cond
;;                                  ((and prune-empty child-empty)
;;                                   (car (%remove-entry data key))) ; drop branch
;;                                  (child-empty            ; keep empty shell
;;                                   (%set-entry data key (typecase child
;;                                                          (hash-table (make-hash-table))
;;                                                          (t nil)))
;;                                   )
;;                                  (t (%set-entry data key new-child)))))
;;                    (values data* t)))))))

;;     (t (values data nil))))

;; (defun keyword-split (kw &key (sep "-") (pos nil))
;;   "Splits a keyword into a list of keywords. SEQ is the separating character and \"-\"
;; is the default. If POS is nil, returns a list of keywords. If POS is :last, returns the last keyword. If POS is :first,
;; returns the first keyword. Otherwise, returns the keyword at POS."
;;   (let ((kz
;;           (mapcar (lambda (x) (intern (str:upcase x) :keyword))
;;                   (str:split sep (symbol-name kw)))))
;;     (cond ((null pos) kz)
;;           ((eq pos 'last) (car (last kz)))
;;           ((eq pos 'first) (first kz))
;;           (t (nth pos kz)))))
;; (defun keyword-concat (kw-list &key (sep "-"))
;;   "Concatenates a list of keywords into a single keyword."
;;   (intern (str:join sep (mapcar #'symbol-name kw-list)) :keyword))

;; (defgeneric =? (a b)
;;   (:method ((a t) (b t))
;;     (eql a b))
;;   (:method ((a list) (b list))
;;     (and (eql (length a) (length b))
;;          (every #'=? a b)))
;;   (:method ((a symbol) (b symbol))
;;     (eql a b))
;;   (:method ((a string) (b string))
;;     (string= a b))
;;   (:method ((a number) (b number))
;;     (= a b))
;;   (:method ((a cons) (b cons))
;;     (and (=? (car a) (car b))
;;          (=? (cdr a) (cdr b))))
;;   (:method ((a hash-table) (b hash-table))
;;     (and (eql (hash-table-count a) (hash-table-count b))
;;          (every (lambda (key)
;;                   (let ((a-val (gethash key a))
;;                         (b-val (gethash key b)))
;;                     (if (and a-val b-val)
;;                         (=? a-val b-val)
;;                         (and (null a-val) (null b-val)))))
;;                 (hash-table-keys a))))
;;   (:method ((a null) (b null))
;;     t)
;;   (:method ((a t) (b null))
;;     nil)
;;   (:method ((a null) (b t))
;;     nil)
;;   (:documentation "A generic equality function that compares two objects for equality."))
;; (defun hash-table-keys (ht) (loop for k being the hash-keys of ht collect k))
;; (defun hash-table->plist (ht)
;;   "Convert a hash-table to a list of cons cells."
;;   (loop for k being the hash-keys of ht using (hash-value v)
;;         collect (cons k v)))

;; ;;; 1. Helpers ────────────────────────────────────────────────────────────────
;; (defun %alist-p (obj)
;;   "True when OBJ is a proper association list (every element is a dotted pair)."
;;   (and (listp obj)
;;        (every #'consp obj)))

;; (defun parse-plist-and-children (args)
;;   "Parses a list of arguments into a property list and a list of children."
;;   (let ((i (or (loop for i from 0 below (length args) by 2
;;                      unless (and (< (1+ i) (length args)) (keywordp (nth i args)))
;;                        return i)
;;                (length args))))
;;     (values (subseq args 0 i) (subseq args i))))

;; (defun %empty-container-p (obj)
;;   "Predicate used by REMOVE-PATH to decide whether to prune a branch."
;;   (typecase obj
;;     (hash-table (= (hash-table-count obj) 0))
;;     (list       (null obj))
;;     (t          nil)))

;; (defun %get-entry (key container default)
;;   (cond
;;     ((hash-table-p container)
;;      (multiple-value-bind (v foundp) (gethash key container)
;;        (if foundp v default)))

;;     ((listp container)
;;      (if (%plist-p container)                  ; alist
;;          (getf container key default)
;;          (let ((pair (assoc key container)))
;;            (if pair (cdr pair) default))
;;          ))        ; plist

;;     (t default)))

;; (defun %set-entry (container key value)
;;   "Destructively insert KEY ⇒ VALUE in CONTAINER; return (possibly new) container."
;;   (when (null key)
;;     (error "SET-ENTRY: KEY cannot be NIL"))
;;   (cond
;;     ((hash-table-p container)
;;      (setf (gethash key container) value)
;;      container)

;;     ((listp container)
;;      (if (%alist-p container)
;;          ;; -------- alist ----------
;;          (let ((pair (assoc key container)))
;;            (if pair
;;                (setf (cdr pair) value)                     ; overwrite
;;                (if container
;;                    (nconc container (list (cons key value))) ; append
;;                    (setq container (list (cons key value))))) ; first pair
;;            container)
;;          ;; -------- plist ----------
;;          (progn
;;            (setf (getf container key) value)               ; handles nil, too
;;            container)))

;;     (t (error "SET-ENTRY: unsupported container type ~S" (type-of container)))))

;; (defun %remove-entry (container key)
;;   "Remove KEY (single level).  ⇒ two values: NEW-CONTAINER, REMOVEDP."
;;   (cond
;;     ((hash-table-p container)
;;      (values container (remhash key container)))           ; REMHASH returns flag

;;     ((listp container)
;;      (if (%alist-p container)
;;          ;; -------- alist ----------
;;          (let* ((before (length container))
;;                 (new    (delete key container :key #'car :test #'eq :count 1)))
;;            (values new (/= before (length new))))
;;          ;; -------- plist ----------
;;          (let ((foundp (remf container key)))
;;            (values container foundp))))

;;     (t (values container nil))))                            ; unsupported → nothing

;; (defun %alist->plist (alist)
;;   "Convert an association list to a property list."
;;   (if (%alist-p alist)
;;       (loop for (k . v) in alist
;;             collect (as :kw k) collect v)
;;       (error "Cannot convert ~S to a property list." alist)))

;; ────────────────────────────────  Low‑level helpers  ─────────────────────────

(defun %hash-table-p (x) (typep x 'hash-table))

(defun %get-entry (key container default)
  "Return the value stored at KEY inside CONTAINER (hash-table, plist or alist),
   or DEFAULT when the key is absent."
  (etypecase container
    (hash-table
     (multiple-value-bind (val presentp) (gethash key container)
       (if presentp val default)))
    ;; treat *any* proper list as a plist first and fall back to alist
    (null default)
    (list
     (if (= 0 (length container))
         default
         (let ((plist-val (getf container key :+|not-found|+)))
           (if (not (eq plist-val :+|not-found|+))
               plist-val
               (let ((pair (assoc key container :test #'equal)))
                 (if pair (cdr pair) default))))))

    ))

(defun %plist-set (plist key value)
  (let ((pos (position key plist :test #'equal)))
    (if pos
        (progn (setf (nth (1+ pos) plist) value) plist)
        (append plist (list key value)))))

(defun %set-entry (container key value)
  "Store VALUE at KEY in CONTAINER and return *new* container when needed."
  (cond
    ((%hash-table-p container) (setf (gethash key container) value) container)
    ((null container) (list key value))                         ; create fresh plist
    ((listp container) (%plist-set container key value))
    (t (error "Cannot store key ~A in object of type ~A" key (type-of container)))))


(defun %remove-entry (container key)
  "→ two values: NEW-CONTAINER  REMOVEDP (boolean)."
  (cond
    ;; ─ hash-table ------------------------------------------------------
    ((%hash-table-p container)
     (multiple-value-bind (val presentp) (gethash key container)
       (declare (ignore val))
       (when presentp (remhash key container))
       (values container presentp)))

    ;; ─ proper list (try plist first, then alist) -----------------------
    ((listp container)
     ;; —— 1. plist path: (:k v :l w …)
     (loop with out = '() and foundp = nil
           for (k v) on container by #'cddr
           do (if (equal k key)
                  (setf foundp t)                 ; skip the pair
                  (setf out (list* v k out)))
           finally (return
                     (if foundp
                         (values (nreverse out) t)
                         ;; —— 2. alist path: ((k . v) …)
                         (let* ((pair (assoc key container :test #'equal)))
                           (if pair
                               (values (remove pair container :test #'equal) t)
                               (values container nil)))))))

    (t (values container nil))))

;;;; -------------------------------------------------------------------
;;;; ❷  Completely rewritten REMOVE-PATH
;;;; -------------------------------------------------------------------

(defun remove-path (data path &key (prune-empty t))
  "Delete the entry at PATH.

Returns two values:  NEW-DATA   REMOVEDP.
When PRUNE-EMPTY is true, containers rendered empty by the deletion
are discarded recursively."
  (etypecase path
    ;; ─── leaf ----------------------------------------------------------
    (symbol
     (%remove-entry data path))

    ;; ─── list / interior ----------------------------------------------
    (cons
     (destructuring-bind (key . rest) path
       (if (null rest)
           (%remove-entry data key)                     ; single‑element list ⇒ leaf
           (let ((child (%get-entry key data nil)))
             (if (null child)                           ; nothing down there
                 (values data nil)
                 (multiple-value-bind (new-child removedp)
                     (remove-path child rest :prune-empty prune-empty)
                   (if (not removedp)                   ; untouched branch
                       (values data nil)
                       (let ((child-empty (%empty-container-p new-child)))
                         (cond
                           ;; drop branch completely
                           ((and prune-empty child-empty)
                            (multiple-value-bind (data* _) (%remove-entry data key)
                              (declare (ignore _))
                              (values data* t)))
                           ;; keep empty shell (make same type)
                           (child-empty
                            (values (%set-entry data key
                                                (typecase child
                                                  (hash-table (make-hash-table :test 'equal))
                                                  (t nil)))
                                    t))
                           ;; updated, non‑empty child
                           (t
                            (values (%set-entry data key new-child) t)))))))))))
    (t (values data nil))))

(defun %empty-container-p (obj)
  (typecase obj
    (null t)
    (hash-table (zerop (hash-table-count obj)))
    (list (null obj))
    (t nil)))

;; ───────────────────────────────  Path navigation  ────────────────────────────

(defgeneric get-path (path data &optional default)
  (:documentation "Read value at PATH inside DATA; return DEFAULT when absent.
PATH is either a symbol/keyword (single level) or a proper list."))

(defmethod get-path ((path symbol) data &optional default)
  (get-path (list path) data default))

(defmethod get-path ((path list) data &optional default)
  (if (or (null path) (equal path '(nil)) (= 0 (length path)))
      data
      (let ((next (%get-entry (car path) data default)))
        (if (eq next default)
            default
            (get-path (cdr path) next default)))))

(defun set-path (data path value &key (createp t))
  "Store VALUE at PATH inside DATA, creating intermediate nodes when CREATEP."
  (etypecase path
    (symbol (%set-entry data path value))
    (list
     (if (= 1 (length path))
         (%set-entry data (car path) value)
         (let* ((key  (car path))
                (rest (cdr path))
                (child (%get-entry key data nil)))
           (when (and (null child) (not createp))
             (error "Missing node ~S in path ~S and :CREATEP is NIL" key path))
           (let* ((child* (or child
                              (if key
                                  (make-hash-table :test 'equal)
                                  value)))
                  (new-child (set-path child* rest value :createp createp)))
             (%set-entry data key new-child)))))
    (t (error "SET-PATH: invalid PATH ~A" path))))

;; (defun remove-path (data path &key (prune-empty t))
;;   "Delete item at PATH.
;; ⇒ two values: NEW-DATA  REMOVEDP."
;;   (etypecase path
;;     (symbol (%remove-entry data path))
;;     (list
;;      (let* ((key   (car path))
;;             (rest  (cdr path))
;;             (child (%get-entry key data nil)))
;;        (if (null child)
;;            (values data nil)
;;            (multiple-value-bind (new-child removedp)
;;                (remove-path child rest :prune-empty prune-empty)
;;              (if (not removedp)
;;                  (values data nil)
;;                  (let* ((keep-child (or (not prune-empty)
;;                                         (not (%empty-container-p new-child))))
;;                         (data* (if keep-child
;;                                    (%set-entry data key new-child)
;;                                    (car (%remove-entry data key)))))
;;                    (values data* t)))))))
;;     (t (values data nil))))










(defgeneric as (enforced-type obj  &key default err &allow-other-keys)
  (:documentation "Convert OBJ to ENFORCED-TYPE, returning DEFAULT if conversion fails."))

(defmethod as ((enforced-type t) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (if (keywordp enforced-type)
      (as (intern (string-upcase (symbol-name enforced-type))) obj :default default :err err)
      (if (symbolp enforced-type)
          (if default
              default
              (if err
                  (error "Cannot convert ~S to a keyword." obj)
                  nil))

          (as (if (stringp obj)
                  (intern (string-upcase enforced-type))
                  (intern (string-upcase (format nil "~A" enforced-type))))
              obj :default default :err err)
          )))

(defmethod as ((enforced-type (eql 'keyword)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (if (keywordp obj) obj
      (if (symbolp obj)
          (intern (string-upcase (symbol-name obj)) :keyword)
          (intern (string-upcase (format nil "~A" obj)) :keyword))))

;; (defmethod as ((enforced-type (eql :keyword)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
;;   (as 'keyword obj :default default :err err))

;; (defmethod as ((enforced-type (eql :kw)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
;;   (as 'keyword obj :default default :err err))

(defmethod as ((enforced-type (eql 'kw)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (as 'keyword obj :default default :err err))

(defmethod as ((enforced-type (eql 'keyword)) (obj string) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default)) (intern (string-upcase obj) :keyword))

(defmethod as ((enforced-type (eql 'keyword)) (obj symbol) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (intern (string-upcase (symbol-name obj)) :keyword))

(defmethod as ((enforced-type (eql 'string)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a string, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (if (stringp obj) obj (format nil "~a" obj)))

;; (defmethod as ((enforced-type (eql :string)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a string, returning DEFAULT if conversion fails."
;;   (as 'string obj :default default :err err))

(defmethod as ((enforced-type (eql 'plist))  obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails."
  (if default default
      (if err (error "Cannot convert ~S to a property list." obj)
          nil)))

(defmethod as ((enforced-type (eql 'plist))  (obj hash-table) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (let* ((plist (list)))
    (maphash (lambda (k v) (push v plist)
               (push (as 'kw k) plist)) obj)
    (nreverse plist)))
(defun %alist->plist (alist)
  "Convert an association list to a property list."
  (if (%alist-p alist)
      (loop for (k . v) in alist
            collect (as :kw k) collect v)
      (error "Cannot convert ~S to a property list." alist)))
(defun %alist-p (obj)
  "True when OBJ is a proper association list (every element is a dotted pair)."
  (and (listp obj)
       (every #'consp obj)))
(defmethod as ((enforced-type (eql 'plist))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails.
This method handles conversion to plist for both property lists and association lists.

Example:
  (as 'plist '(:key1 value1 :key2 value2)) ; returns (:KEY1 value1 :KEY2 value2)
  (as 'plist '((key1 . value1) (key2 . value2))) ; returns (:KEY1 value1 :KEY2 value2)"
  (if (%plist-p obj)
      obj
      (if (%alist-p obj)
          (%alist->plist obj)
          (if default default
              (if err (error "Cannot convert ~S to a property list." obj)
                  nil)))))

(defmethod as ((enforced-type (eql 'hash-table))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a hash-table, returning DEFAULT if conversion fails."
  (let ((o (as 'plist obj :default default :err err)))
    (if o
        (let ((ht (make-hash-table :test 'equal)))
          (loop for i from 0 below (length o) by 2
                do (setf (gethash (nth i o) ht) (nth (1+ i) o)))
          ht)
        nil)))

(defun %plist-p (obj)
  "True when OBJ is a property list.

A property list is a list of alternating keys and values, where keys are keywords or nil, and values are cons cells.
Example: (:key1 value1 :key2 value2 :key3 (value3a . value3b) :key4 '('a 'b 3))."
  (and (listp obj)
       (= 0 (mod (length obj) 2))
       (every (lambda (x)  (keywordp x)) (loop for i from 0 below (length obj) by 2
                                               collect (nth i obj)))))

;; (defun %alist->plist (alist)
;;   "Convert an association list to a property list."
;;   (if (%alist-p alist)
;;       (loop for (k . v) in alist
;;             collect (as :kw k) collect v)
;;       (error (format nil "Cannot convert ~S to a property list." alist))))

(defgeneric as (enforced-type obj  &key default err &allow-other-keys)
  ;; (:method ((enforced-type symbol) obj &key (default nil) (err nil) &allow-other-keys)
  ;;   "Convert OBJ to ENFORCED-TYPE, returning DEFAULT if conversion fails."
  ;;   (declare (ignore err)))
  (:documentation "Convert OBJ to ENFORCED-TYPE, returning DEFAULT if conversion fails."))
(defmethod as ((enforced-type t) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (if (keywordp enforced-type)
      (as (intern (string-upcase (symbol-name :dud))) obj :default default :err err)
      (if (symbolp enforced-type)
          (if default
              default
              (if err
                  (error (format nil "Cannot convert ~S to a keyword." obj))
                  nil))

          (as (if (stringp obj)
                  (intern (string-upcase enforced-type))
                  (intern (string-upcase (format nil "~A" enforced-type))))
              obj :default default :err err)
          )))

(defmethod as ((enforced-type (eql 'keyword)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (if (keywordp obj) obj
      (if (symbolp obj)
          (intern (string-upcase (symbol-name obj)) :keyword)
          (intern (string-upcase (format nil "~A" obj)) :keyword))))

;; (defmethod as ((enforced-type (eql :keyword)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
;;   (as 'keyword obj :default default :err err))

;; (defmethod as ((enforced-type (eql :kw)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
;;   (as 'keyword obj :default default :err err))

(defmethod as ((enforced-type (eql 'kw)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (as 'keyword obj :default default :err err))

(defmethod as ((enforced-type (eql 'keyword)) (obj string) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default)) (intern (string-upcase obj) :keyword))

(defmethod as ((enforced-type (eql 'keyword)) (obj symbol) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a keyword, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (intern (string-upcase (symbol-name obj)) :keyword))

(defmethod as ((enforced-type (eql 'string)) obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a string, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (if (stringp obj) obj (format nil "~a" obj)))

;; (defmethod as ((enforced-type (eql :string)) obj &key (default nil) (err nil) &allow-other-keys)
;;   "Convert OBJ to a string, returning DEFAULT if conversion fails."
;;   (as 'string obj :default default :err err))

(defmethod as ((enforced-type (eql 'plist))  obj &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails."
  (if default default
      (if err (error (format nil "Cannot convert ~S to a property list." obj))
          nil)))

(defmethod as ((enforced-type (eql 'plist))  (obj hash-table) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails."
  (declare (ignore err default))
  (let* ((plist (list)))
    (maphash (lambda (k v) (push v plist)
               (push (as 'kw k) plist)) obj)
    (nreverse plist)))
;; (%plist-p (list :a 1 :b 2 :c (list 3 4)))

(defmethod as ((enforced-type (eql :plist))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  (as 'plist obj :default default :err err))
(defmethod as ((enforced-type (eql 'plist))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a property list, returning DEFAULT if conversion fails.
This method handles conversion to plist for both property lists and association lists.

Example:
  (as 'plist '(:key1 value1 :key2 value2)) ; returns (:KEY1 value1 :KEY2 value2)
  (as 'plist '((key1 . value1) (key2 . value2))) ; returns (:KEY1 value1 :KEY2 value2)"
  (if (%plist-p obj)
      obj
      (if (%alist-p obj)
          (%alist->plist obj)
          (if default default
              (if err (error (format nil "Cannot convert ~S to a property list." obj))
                  nil)))))

(defmethod as ((enforced-type (eql :hash-table))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a hash-table, returning DEFAULT if conversion fails."
  (let ((o (as 'plist obj :default default :err err)))
    (if o
        (let ((ht (make-hash-table :test 'equal)))
          (loop for i from 0 below (length o) by 2
                do (setf (gethash (nth i o) ht) (nth (1+ i) o)))
          ht)
        nil)))
(defmethod as ((enforced-type (eql 'hash-table))  (obj list) &key (default nil) (err nil) &allow-other-keys)
  "Convert OBJ to a hash-table, returning DEFAULT if conversion fails."
  (let ((o (as :plist obj :default default :err err)))
    (if o
        (let ((ht (make-hash-table :test 'equal)))
          (loop for i from 0 below (length o) by 2
                do (setf (gethash (nth i o) ht) (nth (1+ i) o)))
          ht)
        nil)))

(defun copy-hash-table (ht)
  "Create a shallow copy of the hash table HT."
  (let ((new-ht (make-hash-table :test (hash-table-test ht))))
    (maphash (lambda (k v) (setf (gethash k new-ht) v)) ht)
    new-ht))
;; == end/path-utils.lisp =====================================================
(defun split-props/children (args)
  "Splits a list of arguments into properties (a plist) and children.
   Keyword arguments are considered properties. Anything else is a child.
   The special :children property overrides positional children."
  (let ((props '())
        (children '())
        (arg-list args))
    (loop while (and arg-list (keywordp (car arg-list)))
          do
             (push (pop arg-list) props)
             (push (pop arg-list) props))
    (setf props (nreverse props))
    (setf children arg-list)
    (let ((explicit-children (getf props :children)))
      (if explicit-children
          (values (alexandria:remove-from-plist props :children) explicit-children)
          (values props children)))))
