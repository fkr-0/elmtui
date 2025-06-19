(uiop:define-package :elmtui.utils
  (:use :cl :log4cl)
  ;; State Management
  ;; UI Utilities
  (:export :ensure-list
   :ensure-keyword
           :hex-str-to-rgb
           ))


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
