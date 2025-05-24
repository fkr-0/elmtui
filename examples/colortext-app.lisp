;;;===============================================================
;;; File: examples/colortext-app.lisp
;;; Example application demonstrating various foreground and
;;; background color combinations in a grid, using stylesheets.
;;;===============================================================

;; (in-package :cl)
;; (asdf:load-asd "../elmtui.asd")
;; (asdf:load-system :elmtui)
(uiop:define-package :elmtui.examples.colortext-app
  (:use :cl #:alexandria)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.state #:state-ref)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.view.core #:ui-node #:make-ui-node)
  (:import-from :elmtui.core.keymap #:key-event->normalized-key #:parse-key-string #:normalized-key=)
  ;; Stylesheet and selector imports
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.style-lib.selector #:type> #:id> #:cls>)
  (:import-from :elmtui.style-lib.rule #:defrule) ; Use defrule
  (:export #:main #:colortext-stylesheet #:colortext-example-app))
(in-package :elmtui.examples.colortext-app)

(defparameter *ansi-colors*
  '(:black :red :green :yellow :blue :magenta :cyan :white
    :bright-black :bright-red :bright-green :bright-yellow :bright-blue :bright-magenta :bright-cyan :bright-white)
  "Extended ANSI colors for testing.")

(defparameter *color-cell-width* 10)
(defparameter *header-cell-width* 5)


;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
(defun generate-color-style-rule-forms ()
  "Generates a list of (defrule ...) forms for fg/bg colors."
  (let ((rule-forms nil))
    (dolist (color *ansi-colors*)
      (let ((color-name (string-downcase (symbol-name color))))
        (push `(defrule ,(cls> (format nil "fg-~A" color-name)) :fg-color ,color) rule-forms)
        (push `(defrule ,(cls> (format nil "bg-~A" color-name)) :bg-color ,color) rule-forms)))
    (nreverse rule-forms)))
(defparameter colortext-stylesheet
  (eval
   `(defstylesheet
      (defrule (id> :colortext-root)
        :display :flex
        :flex-direction :column
        :width :fill
        :height :fill
        :align-items :center ; Center the grid horizontally
        ;; :padding 1
        )
      (defrule (type> :instruction-text)
        :margin-bottom 1)
      ;; (defrule (id> :color-grid-container)
      ;;   :display :grid
      ;;   ;; +1 for header row/column
      ;;   :grid-template-columns ,(format nil "repeat(~D, auto)" (+ 1 (length *ansi-colors*)))
      ;;   :grid-template-rows ,(format nil "repeat(~D, auto)" (+ 1 (length *ansi-colors*)))
      ;;   :grid-gap 0)
      (defrule (cls> "color-cell")
        :width ,*color-cell-width*
        :height 1
        ;; :padding '(0 1)
        )
      (defrule (cls> "header-cell")
        :width ,*header-cell-width*
        :height 1
        ;; :padding '(0 1)
        )
      ,@(generate-color-style-rule-forms))))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (values (list :should-quit nil
                :current-stylesheet colortext-stylesheet) ; Add stylesheet
          nil))

(defupdate app-update (app-state message)
  "Main application update function."
  ;; (declare (ignore app-state))
  (let ((patch-list nil) (commands-list nil))
    (case (if (listp message) (first message) message)
      (:key-event
       (log:info "COLORTEXT-APP: Key event, requesting quit.")
       (push :should-quit patch-list) (push t patch-list)
       (setf commands-list (list '(:app-quit-requested (:source :key-event)))))
      (:app-quit-requested
       (push :should-quit patch-list) (push t patch-list)
       (log:info "COLORTEXT-APP: Quit requested."))
      (otherwise (log:debug "COLORTEXT-APP: Unhandled message: ~S" message)))
    (values (nreverse patch-list) commands-list)))

(defun app-view (app-state dispatch-fn)
  "Main application view function. Returns a raw ui-node tree."
  (declare (ignore app-state dispatch-fn))
  (let ((grid-children nil)
        (cell-text-value "Text")
        (header-symbols (mapcar (lambda (c) (subseq (symbol-name c) 0 (min 3 (length (symbol-name c)))))
                                *ansi-colors*)))

    ;; Top-left empty cell
    (push (make-ui-node :type :text :props (list :classes "header-cell" :value " ")) grid-children)

    ;; Column Headers (Background Colors)
    (dolist (bg-sym header-symbols)
      (push (make-ui-node :type :text :props (list :classes "header-cell"
                                                   :value (format nil "~A" bg-sym)))
            grid-children))

    ;; Rows
    (loop for fg-color in *ansi-colors*
          for fg-sym in header-symbols
          do
             ;; Row Header (Foreground Color)
             (push (make-ui-node :type :text :props (list :classes "header-cell"
                                                          :value (format nil "~A" fg-sym)))
                   grid-children)
             ;; Color Cells
             (dolist (bg-color *ansi-colors*)
               (let ((fg-class (format nil "fg-~A" (string-downcase (symbol-name fg-color))))
                     (bg-class (format nil "bg-~A" (string-downcase (symbol-name bg-color)))))
                 (push (make-ui-node :type :text
                                     :props (list :classes (list "color-cell" fg-class bg-class) ; Use list for multiple classes
                                                  :value cell-text-value))
                       grid-children))))

    (make-ui-node :type :app-root-container
                  :props (list :id :colortext-root)
                  :children (list
                             (make-ui-node :type :instruction-text
                                           :props (list :value "Color Grid. Any key to quit."))
                             (make-ui-node :type :grid-visual
                                           :props (list :id :color-grid-container)
                                           :children (nreverse grid-children))))))

(def-elm-app colortext-example-app
  :init #'app-init
  :update #'app-update
  :view #'app-view)

(defun main ()
  "Run the colortext example application."
  (elmtui.runtime:run-app :app-name 'colortext-example-app
                          ;; :stylesheet #'colortext-stylesheet ; Pass to runtime
                          ))
