(uiop:define-package :elmtui.style.manager
  (:use :cl)
  (:import-from :cl-styles.sheet
                #:make-stylesheet
                #:stylesheet-rules #:stylesheet-variables #:stylesheet-namespace)
  (:export #:compute-active-stylesheet #:default-stylesheet))

(in-package :elmtui.style.manager)

(defun default-stylesheet ()
  (make-stylesheet :rules nil :variables nil :namespace nil))

(defun %cl-styles-sheet-p (x)
  (and x (string= (package-name (symbol-package (type-of x))) "CL-STYLES.SHEET")))



(defun compute-active-stylesheet (state)
  "Build the effective stylesheet for this frame from STATE.
   Sources (priority high→low):
   - state :current-stylesheet if it is a cl-styles sheet
   - otherwise a default empty sheet
   Variables can be provided at (:style-variables ...) in STATE."
  (let* ((sheet0 (or (elmtui.tea-state:get-path '(:current-stylesheet) state)
                     (default-stylesheet)))
         (sheet  (if (%cl-styles-sheet-p sheet0) sheet0 (default-stylesheet)))
         (vars   (elmtui.tea-state:get-path '(:style-variables) state)))
    (if vars
        (make-stylesheet :rules (stylesheet-rules sheet)
                         :variables vars
                         :namespace (stylesheet-namespace sheet))
        sheet)))
