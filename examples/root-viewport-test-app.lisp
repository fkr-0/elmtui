(uiop:define-package :elmtui.examples.root-viewport-test-app
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication #:run-application #:quit)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.style-lib.styles #:rgb)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.core.event-types #:key-event #:key-code #:key-name)
  (:import-from :elmtui.state #:make-update-result #:get-path #:application-state-plist)
  (:import-from :elmtui.ui.widgets.root-viewport #:root-viewport #:make-root-viewport)
  (:import-from :elmtui.platform.api #:get-terminal-dimensions)
  (:export #:main))

(in-package :elmtui.examples.root-viewport-test-app)

;;;--------------------------------------------------------------
;;; Application Constants
;;;--------------------------------------------------------------
(defconstant +rect-width+ 10
  "Width of the movable rectangle.")
(defconstant +rect-height+ 5
  "Height of the movable rectangle.")
(defvar *rect-color* (rgb '(0 255 0))
  "Color of the movable rectangle (green).")

;;;--------------------------------------------------------------
;;; Application State
;;;--------------------------------------------------------------
;; To be defined: app-init, app-update, app-view
(defun app-init ()
  "Initializes the application model."
  (multiple-value-bind (term-cols term-rows)
      (get-terminal-dimensions) ; Get actual terminal dimensions
    (let ((initial-offset-x (floor (- term-cols +rect-width+) 2))
          (initial-offset-y (floor (- term-rows +rect-height+) 2)))
      (values
       ;; Initial application state plist
       (list :root-viewport-state (list :id :movable-root-vp
                                        :anchor :top-left ; For direct offset control
                                        :offset-x initial-offset-x
                                        :offset-y initial-offset-y
                                        :width term-cols  ; Root viewport usually spans full terminal
                                        :height term-rows ; or a section based on anchor
                                        :initial-cursor-row 0 ; Not directly used for :top-left
                                        :initial-cursor-col 0) ; Not directly used for :top-left
             :terminal-width term-cols
             :terminal-height term-rows
             :should-quit nil)
       ;; No initial commands
       nil))))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
Arrow keys move the root viewport's effective offsets. 'q' quits."
  (let* ((current-plist (application-state-plist app-state))
         (rvp-state (getf current-plist :root-viewport-state))
         (current-offset-x (getf rvp-state :offset-x))
         (current-offset-y (getf rvp-state :offset-y))
         (term-width (getf current-plist :terminal-width))
         (term-height (getf current-plist :terminal-height)))

    (cond
      ((typep message 'key-event)
       (let ((key (key-name message)))
         (cond
           ((eq key :up)
            (list `(:root-viewport-state :offset-y ,(max 0 (1- current-offset-y)))))
           ((eq key :down)
            (list `(:root-viewport-state :offset-y ,(min (- term-height +rect-height+) (1+ current-offset-y)))))
           ((eq key :left)
            (list `(:root-viewport-state :offset-x ,(max 0 (1- current-offset-x)))))
           ((eq key :right)
            (list `(:root-viewport-state :offset-x ,(min (- term-width +rect-width+) (1+ current-offset-x)))))
           ((or (eq key :q) (eq key :Q))
            (list '(:should-quit . t)))
           (t nil))))
      ((and (listp message) (eq (first message) :app-quit-requested))
       (list '(:should-quit . t)))
      (t nil))))

(defun app-view (app-state)
  "Defines the UI DSL for the root viewport's child content (the movable rectangle)."
  (declare (ignore app-state)) ; app-state is not directly used to construct this static child
  (make-styled-node
   :type :container ; This will be the rectangle
   :props (list :id :moving-rect
                :style (list :width +rect-width+
                             :height +rect-height+
                             :bg-color *rect-color*))))

(defapplication root-viewport-test-app
  :root-viewport-id :movable-root-vp ; Matches the ID used in app-init for state
  :initial-state-plist (app-init)
  :root-component-dsl (app-view nil) ; The DSL for the child of the root viewport
  :update-fn 'app-update
  :view-fn 'app-view ; This function provides the DSL for the *child* of the root viewport
  :subscriptions-fn (lambda (model)
                      (declare (ignore model))
                      nil) ; No subscriptions needed for this simple app
  :quit-on-esc t
  :initial-terminal-dimensions '(80 . 24)) ; Default, but app-init gets actual

(defun main ()
  "Runs the root-viewport test application."
  (run-application 'root-viewport-test-app))
;; defapplication
;; main function