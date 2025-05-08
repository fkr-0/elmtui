(in-package :cl-user)

;;; ───────────────────────── 8. Public Facade ─────────────────────────────
(uiop:define-package :elmtui.style-lib
  (:use :cl)
  (:reexport
   :elmtui.style-lib.util
   :elmtui.style-lib.types
   :elmtui.style-lib.styles
   :elmtui.style-lib.stylable
   :elmtui.style-lib.style-set
   :elmtui.style-lib.selector
   :elmtui.style-lib.sheet
   :elmtui.style-lib.styled-strings
   :elmtui.style-lib.api))

(in-package :elmtui.style-lib)

;;; quick sanity demo (disabled at compile-time) ---------------------------
#+nil
(let* ((btn (make-instance 'stylable :classes '("button") :id "btn1"))
       (sheet (defstylesheet
                  (defrule (cls> "button") :bold t :fg-color :red)
                  (defrule (and> (cls> "button") (id> "btn1")) :fg-color :green))))
  (format t "~&Merged styles: ~a~%" (elmtui.style-lib.style-set:styles-list
                                     (elmtui.style-lib.sheet:query-stylesheet sheet btn))))

;;; ────────────────────────────────────────────────────────────────────────
