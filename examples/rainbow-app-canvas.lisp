;;;===============================================================
;;; File: examples/rainbow-app-canvas.lisp
;;; Example application demonstrating colored vertical stripes
;;; using the root-viewport and a styled-node with a draw-fn.
;;; Quits on any key press.
;;;===============================================================
(uiop:define-package :elmtui.examples.rainbow-app-canvas
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.app #:defapplication #:run-application)
  (:import-from :elmtui.state.update #:defupdate)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.state.transactions  #:with-transaction)
  (:import-from :elmtui.view.geo #:w)
  (:import-from :elmtui.ui.widgets.root-viewport #:make-root-viewport)
  (:import-from :elmtui.platform.api #:get-terminal-dimensions)
  (:export
    :run-rainbow-canvas-example-app))

(in-package :elmtui.examples.rainbow-app-canvas)

;;;--------------------------------------------------------------
;;; Application State and Logic
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  ;; (multiple-value-bind (term-cols term-rows)
  ;;     (get-terminal-dimensions)
  (values
    ;; Initial application state plist
    (list :root-viewport-state (list :id :rainbow-root-vp ; ID for the root-viewport
                                 :anchor :top-left
                                 :offset-x 0
                                 :offset-y 0
                                 :width 20
                                 :height 20
                                 :initial-cursor-row 0
                                 :initial-cursor-col 0)
      :terminal-width 20
      :terminal-height 20
      :should-quit nil)
    ;; No initial commands
    nil))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages.
   Any key press will quit the application."
  (log-info "RAINBOW-APP-CANVAS: app-update called with message: ~S (Type: ~A)" message (type-of message))
  (let ((should-quit (state-ref app-state :should-quit nil))
         (ctr (state-ref app-state :ctr 0))
         (patches nil))
    (log-info "RAINBOW-APP-CANVAS: Current should-quit state: ~A" should-quit)
    (cond
      ;; ((typep message 'elmtui.core.event-types:key-event)
      ;;       (progn (log-info "RAINBOW-APP-CANVAS: Key event condition met for ~A, setting :should-quit to t." message)
      ;; (push patches (list
      ;;                 :should-quit t)) ; Patch to set should-quit to t
      ;;         ) )

                                        ; Patch to set should-quit to t

      ;; ((and (listp message) (eq (first message) :app-quit-requested))
      ;;   (progn (log-info "RAINBOW-APP-CANVAS: :APP-QUIT-REQUESTED condition met for ~A, setting :should-quit to t." message)
      ;;     (list :should-quit t)))
                                        ; Patch to set should-quit to t
      ((= ctr 10)
        (push (list
                :should-quit t)
          patches )
        )
                                        ; Patch to set should-quit to t
      ((and (listp message) (eq (first message) :app-quit-requested))
        (progn (log-info "RAINBOW-APP-CANVAS: :APP-QUIT-REQUESTED condition met for ~A, setting :should-quit to t." message)
          (list :should-quit t)))
      (t nil))
    (push (list
            :counter (1+ ctr))
      patches ) ; Increment the counter)
    (log-info "RAINBOW-APP-CANVAS: Returning patches: ~S" patches)
    (make-update-result
      :patches patches
      :commands nil) ; No commands, return nil for no commands
    ) ; Return the update result with patches and commands
  ) ; No changes, return nil for no patches

;;;--------------------------------------------------------------
;;; View Definition (Child of Root Viewport)
;;;--------------------------------------------------------------

(defun rainbow-content-view (app-state)
  "Defines the UI DSL for the rainbow content, to be used as a child of the root-viewport."
  (declare (ignore app-state))
  ;; Return PURE DSL DATA instead of styled-node objects
  (let* ((colors '((255 0 0) (255 192 203) (255 165 0) (255 255 0) (0 255 0) (0 0 255) (75 0 130) (238 130 238)))
          (num-colors (length colors))
          (stripe-width 3))
    `(:container
       :id :rainbow-canvas-content ; ID for the styled node itself
       :width :fill
       :height :fill
       :children ,(loop for i from 0 below 10
                    append (loop for c in colors
                             collect `(:label ; This type is used by the renderer/event handler
                                        :id ,(intern (format nil "STRIPE-~A-~A" i (position c colors)) :keyword)
                                        :bg-color ,c
                                        :width ,stripe-width
                                        :height 1))))))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defapplication rainbow-canvas-example-app
  :root-viewport-id :rainbow-root-vp ; Matches ID in app-init for root-viewport state
  ;; :initial-state-plist ;; (app-init)

  :initial-state-plist `(:counter 0
                          :text "hello")
  :root-component-dsl (rainbow-content-view nil) ; DSL for the CHILD of the root viewport
  :update-fn 'app-update
  :view-fn 'rainbow-content-view ; Function providing DSL for the CHILD
  :subscriptions-fn (lambda (model)
                      (declare (ignore model))
                      (log-debug "RAINBOW-APP-CANVAS: Subscriptions function called."))
  :platform-options (list :quit-on-esc t :initial-terminal-dimensions '(80 . 24))) ; Default, app-init gets actual

;;;--------------------------------------------------------------
;;; Main Entry Point
;;;--------------------------------------------------------------
