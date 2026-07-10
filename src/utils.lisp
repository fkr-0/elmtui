(uiop:define-package :elmtui.utils
  (:use :cl)
  (:export
   #:ensure-list
   #:trim-string
   #:blank-string-p
   #:string-prefix-p
   #:split-string-literal
   #:copy-hash-table
   #:split-props/children
   #:parse-plist-and-children
   #:as
   #:get-path
   #:set-path
   #:remove-path
   #:ensure-keyword
   #:struct->plist
   #:coerce-fn
   #:hex-str-to-rgb
   #:format-duration
   #:format-percentage))

(in-package :elmtui.utils)

;;; General helpers

(defun struct->plist (object)
  "Return OBJECT's effective slots and values as a property list."
  (loop for slot in (mapcar #'sb-mop:slot-definition-name
                            (sb-mop:class-slots (class-of object)))
        append (list slot (slot-value object slot))))

(defun copy-hash-table (table)
  "Return a shallow copy of TABLE that preserves its hash-table policy."
  (check-type table hash-table)
  (let ((copy (make-hash-table :test (hash-table-test table)
                               :size (hash-table-size table)
                               :rehash-size (hash-table-rehash-size table)
                               :rehash-threshold
                               (hash-table-rehash-threshold table))))
    (maphash (lambda (key value)
               (setf (gethash key copy) value))
             table)
    copy))

(defun ensure-list (value)
  "Return VALUE as a list; NIL remains NIL."
  (cond
    ((null value) nil)
    ((listp value) value)
    (t (list value))))

(defparameter +whitespace-characters+
  '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout))

(defun trim-string (value)
  "Remove surrounding whitespace from VALUE, preserving NIL."
  (when value
    (string-trim +whitespace-characters+ value)))

(defun blank-string-p (value)
  "Return true when VALUE is NIL, empty, or contains only whitespace."
  (or (null value)
      (zerop (length (trim-string value)))))

(defun string-prefix-p (prefix value &key (test #'char=))
  "Return true when VALUE starts with PREFIX according to TEST."
  (let* ((prefix (string prefix))
         (prefix-length (length prefix)))
    (and (stringp value)
         (<= prefix-length (length value))
         (loop for index below prefix-length
               always (funcall test
                               (char prefix index)
                               (char value index))))))

(defun split-string-literal (separator value &key limit (omit-empty nil))
  "Split VALUE on literal SEPARATOR, optionally limiting the number of fields.

LIMIT follows CL-STR's field-count convention: a limit of three performs at
most two splits. Empty fields, including a trailing field, are preserved unless
OMIT-EMPTY is true."
  (check-type value string)
  (let* ((separator (string separator))
         (separator-length (length separator)))
    (when (zerop separator-length)
      (error "SEPARATOR must not be empty."))
    (when (and limit (or (not (integerp limit)) (< limit 1)))
      (error "LIMIT must be NIL or a positive integer, got ~S." limit))
    (let ((start 0)
          (splits 0)
          (maximum-splits (and limit (1- limit)))
          (pieces nil))
      (labels ((emit (end)
                 (let ((piece (subseq value start end)))
                   (unless (and omit-empty (zerop (length piece)))
                     (push piece pieces)))))
        (loop
          for position = (and (or (null maximum-splits)
                                  (< splits maximum-splits))
                              (search separator value :start2 start))
          while position
          do (emit position)
             (setf start (+ position separator-length))
             (incf splits)
          finally (emit (length value)))
        (nreverse pieces)))))

(defun ensure-keyword (value)
  "Return VALUE as an uppercase keyword."
  (etypecase value
    (keyword value)
    (string (intern (string-upcase value) :keyword))
    (symbol (intern (string-upcase (symbol-name value)) :keyword))))

(defun hex-str-to-rgb (value)
  "Parse a #RRGGBB string and return (R G B), or NIL for invalid input."
  (when (and (stringp value)
             (= (length value) 7)
             (char= (char value 0) #\#))
    (handler-case
        (list (parse-integer value :start 1 :end 3 :radix 16)
              (parse-integer value :start 3 :end 5 :radix 16)
              (parse-integer value :start 5 :end 7 :radix 16))
      (parse-error () nil))))

(defun coerce-fn (value)
  "Quote a symbolic or lambda function designator for macro expansion."
  (cond
    ((symbolp value) `',value)
    ((and (consp value) (eq (first value) 'lambda)) `',value)
    (t value)))

(defun format-duration (seconds)
  "Format SECONDS as a compact human-readable duration."
  (let ((seconds (or seconds 0.0)))
    (cond
      ((< seconds 1.0) (format nil "~,3fs" seconds))
      ((< seconds 60.0) (format nil "~,1fs" seconds))
      (t
       (multiple-value-bind (minutes remainder) (floor seconds 60)
         (format nil "~dm ~,1fs" minutes remainder))))))

(defun format-percentage (value &optional (total 100.0))
  "Format VALUE as a percentage of TOTAL."
  (cond
    ((null value) "0.0%")
    ((and total (not (zerop total)))
     (format nil "~,1f%%" (* 100.0 (/ value total))))
    (t
     (format nil "~,1f%%" (* 100.0 value)))))

;;; cl-state compatibility boundary
;;;
;;; Generic path traversal belongs to cl-state.  These wrappers preserve the
;;; historical elmtui.utils API for applications while avoiding a second path
;;; engine in the toolkit.

(defgeneric get-path (path data &optional default)
  (:documentation "Read PATH from DATA through cl-state's canonical path API."))

(defmethod get-path (path data &optional default)
  (cl-state.utils:get-path path data default))

(defmethod get-path (path (state cl-state.core:application-state) &optional default)
  (cl-state.utils:get-path path
                           (cl-state.core:application-state-data state)
                           default))

(defun set-path (data path value &key (createp t))
  "Store VALUE at PATH using cl-state's canonical path implementation.

For an APPLICATION-STATE, update its data slot and return the state.  For raw
containers, return the updated container."
  (if (cl-state.core:application-state-p data)
      (progn
        (setf (cl-state.core:application-state-data data)
              (cl-state.utils:set-path
               (cl-state.core:application-state-data data)
               path value :createp createp))
        data)
      (cl-state.utils:set-path data path value :createp createp)))

(defun remove-path (data path &key (prune-empty t))
  "Remove PATH through cl-state and return UPDATED-DATA, REMOVEDP."
  (if (cl-state.core:application-state-p data)
      (multiple-value-bind (updated removedp)
          (cl-state.utils:remove-path
           (cl-state.core:application-state-data data)
           path :prune-empty prune-empty)
        (setf (cl-state.core:application-state-data data) updated)
        (values data removedp))
      (cl-state.utils:remove-path data path :prune-empty prune-empty)))

;;; Small conversion protocol

(defun %alist-p (value)
  (and (consp value) (every #'consp value)))

(defun %plist-p (value)
  (and (listp value)
       (evenp (length value))
       (loop for tail on value by #'cddr
             always (symbolp (first tail)))))

(defun %alist->plist (alist)
  (loop for (key . value) in alist
        append (list (ensure-keyword key) value)))

(defun %hash-table->plist (table)
  (let (result)
    (maphash (lambda (key value)
               (setf result (list* (ensure-keyword key) value result)))
             table)
    (nreverse result)))

(defun %plist->hash-table (plist)
  (let ((table (make-hash-table :test 'equal)))
    (loop for (key value) on plist by #'cddr
          do (setf (gethash key table) value))
    table))

(defun %conversion-failed (object target default err)
  (if err
      (error "Cannot convert ~S to ~S." object target)
      default))

(defgeneric as (enforced-type object &key default err &allow-other-keys)
  (:documentation "Convert OBJECT to ENFORCED-TYPE, or return DEFAULT."))

(defmethod as (enforced-type object &key default err &allow-other-keys)
  (%conversion-failed object enforced-type default err))

(defmethod as ((type (eql 'keyword)) object &key default err &allow-other-keys)
  (declare (ignore type default err))
  (ensure-keyword (if (or (stringp object) (symbolp object))
                      object
                      (princ-to-string object))))

(defmethod as ((type (eql :keyword)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'keyword object arguments))

(defmethod as ((type (eql 'kw)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'keyword object arguments))

(defmethod as ((type (eql :kw)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'keyword object arguments))

(defmethod as ((type (eql 'string)) object &key default err &allow-other-keys)
  (declare (ignore type default err))
  (if (stringp object) object (princ-to-string object)))

(defmethod as ((type (eql :string)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'string object arguments))

(defmethod as ((type (eql 'plist)) (object list)
               &key default err &allow-other-keys)
  (declare (ignore type))
  (cond
    ((%plist-p object) object)
    ((%alist-p object) (%alist->plist object))
    (t (%conversion-failed object 'plist default err))))

(defmethod as ((type (eql 'plist)) (object hash-table)
               &key default err &allow-other-keys)
  (declare (ignore type default err))
  (%hash-table->plist object))

(defmethod as ((type (eql :plist)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'plist object arguments))

(defmethod as ((type (eql 'hash-table)) (object hash-table)
               &key default err &allow-other-keys)
  (declare (ignore type default err))
  object)

(defmethod as ((type (eql 'hash-table)) (object list)
               &key default err &allow-other-keys)
  (declare (ignore type))
  (let ((plist (as 'plist object :default nil :err nil)))
    (if plist
        (%plist->hash-table plist)
        (%conversion-failed object 'hash-table default err))))

(defmethod as ((type (eql :hash-table)) object &rest arguments &key &allow-other-keys)
  (declare (ignore type))
  (apply #'as 'hash-table object arguments))

;;; DSL argument helpers

(defun split-props/children (arguments)
  "Split leading keyword/value pairs from positional child forms.

An explicit :CHILDREN property replaces positional children, including when its
value is NIL."
  (let ((remaining arguments)
        (properties nil))
    (loop while (and remaining (keywordp (first remaining)))
          do (unless (rest remaining)
               (error "Property ~S has no value in ~S."
                      (first remaining) arguments))
             (setf properties
                   (append properties (list (pop remaining) (pop remaining)))))
    (let ((marker (gensym "MISSING-CHILDREN-")))
      (let ((explicit (getf properties :children marker)))
        (if (eq explicit marker)
            (values properties remaining)
            (values (alexandria:remove-from-plist properties :children)
                    explicit))))))

(defun parse-plist-and-children (arguments)
  "Compatibility alias for SPLIT-PROPS/CHILDREN."
  (split-props/children arguments))
