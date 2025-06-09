;;;===============================================================
;;; File: examples/rainbow-app-canvas.lisp
;;; Example application demonstrating colored vertical stripes
;;; using the canvas renderer, quitting on any key press.
;;; Adapted to modern app design with defapplication.
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app-canvas
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state #:make-update-result)
  (:import-from :elmtui.view.canvas #:make-canvas-node)
  (:export
   :main))

(in-package :elmtui.examples.rainbow-app-canvas)

;;;--------------------------------------------------------------
;;; Canvas Drawing and Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (values
   ;; Initial application state
   (list :should-quit nil)
   ;; No initial commands
   nil))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
   Any key press will quit the application."
  (log-info "RAINBOW-APP-CANVAS: app-update called with message: ~S (Type: ~A)" message (type-of message))
  (cond
    ((typep message 'elmtui.core.event-types:key-event)
     (log-info "RAINBOW-APP-CANVAS: Key event condition met for ~A, setting :should-quit to t." message)
     (list :should-quit t)) ; Patch to set should-quit to t

    ((and (listp message) (eq (first message) :app-quit-requested))
     (log-info "RAINBOW-APP-CANVAS: :APP-QUIT-REQUESTED condition met for ~A, setting :should-quit to t." message)
     (list :should-quit t)) ; Patch to set should-quit to t

    (t nil))) ; No changes, return nil for no patches

(defun rainbow-canvas-view (app-state)
  "Defines the UI DSL for the rainbow canvas app's content."
  (declare (ignore app-state))
  (make-canvas-node
   :id :rainbow-canvas
   :width :fill
   :height :fill
   :draw-fn (lambda (canvas width height)
              (declare (ignore width height)) ; Canvas dimensions are handled by the canvas itself
              (let* ((colors '((255 0 0) (255 192 203) (255 165 0) (255 255 0) (0 255 0) (0 0 255) (75 0 130) (238 130 238)))
                     (num-colors (length colors))
                     (stripe-width (floor (elmtui.view.canvas:canvas-width canvas) num-colors)))
                (loop for i from 0 below num-colors
                      for color in colors
                      for x = (* i stripe-width)
                      do (elmtui.view.canvas:draw-filled-rect canvas x 0 stripe-width (elmtui.view.canvas:canvas-height canvas) :color color))))))

(defapplication rainbow-canvas-example-app
  :root-viewport-id :rainbow-canvas-root-vp
  :initial-state-plist (app-init)
  :root-component-dsl (rainbow-canvas-view nil) ; Initial DSL for the content
  :update-fn 'app-update
  :view-fn 'rainbow-canvas-view
  :subscriptions-fn (lambda (model)
                      (declare (ignore model))
                      (log-debug "RAINBOW-APP-CANVAS: Subscriptions function called.")))
