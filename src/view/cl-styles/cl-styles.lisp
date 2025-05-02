(in-package :cl-user)

;;; ───────────────────────── 8. Public Facade ─────────────────────────────
(uiop:define-package :cl-styles
  (:use :cl)
  (:reexport
   :cl-styles.util :cl-styles.types :cl-styles.styles
   :cl-styles.style-set :cl-styles.stylable
   :cl-styles.selector :cl-styles.sheet
   :cl-styles.styled-string))

(in-package :cl-styles)

;;; quick sanity demo (disabled at compile-time) ---------------------------
#+nil
(let* ((btn (make-instance 'stylable :classes '("button") :id "btn1"))
       (sheet (defstylesheet
                (defrule (cls> "button") :bold t :fg-color :red)
                (defrule (and> (cls> "button") (id> "btn1")) :fg-color :green))))
  (format t "~&Merged styles: ~a~%" (cl-styles.style-set:styles-list
                                     (cl-styles.sheet:query-stylesheet sheet btn))))

;;; ────────────────────────────────────────────────────────────────────────
