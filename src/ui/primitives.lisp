;;;===============================================================
;;; File: src/ui/primitives.lisp
;;; Primitive Widgets
;;;===============================================================
(uiop:define-package :elmtui.ui.primitives
  (:use :cl :elmtui.ui.base :elmtui.view.core) ; Keep :use for elm-widget class
  (:import-from :elmtui.ui.base #:widget-id #:widget-props #:widget-handlers #:widget-render) ; Explicitly import accessors/generics
  (:import-from :elmtui.core.events #:cmd #:message #:send-message #:message-type) ; Added message-type
  (:import-from :elmtui.core.async #:cmd-async #:cmd-batch) ; For potential commands
  (:export :button-widget
   :input-widget
           :label-widget))
(in-package :elmtui.ui.primitives)

;;;---------------------------------------------------------------
;;; Label Widget
;;;---------------------------------------------------------------

(defclass label-widget (elm-widget)
  ()
  (:documentation "A static text label.
   Contract: implements init/update/render per base API.
   Props: expects :text or :value for the label content."))

(defmethod widget-render ((w label-widget) &key &allow-other-keys)
  "Renders the label as a :text ui-node."
  (let ((text (or (getf (widget-props w) :text)
                  (getf (widget-props w) :value) ; Allow :value as well
                  ""))) ; Default to empty string
    ;; Basic render: just a text node. Styling will handle appearance.
    (make-ui-node :type :text
                  :props (list :value text :widget-id (widget-id w)) ; Pass ID for potential targeting
                  :children nil)))

(defmethod widget-update ((w label-widget) msg &key &allow-other-keys)
  "Labels are static, update does nothing."
  (declare (ignore msg))
  (values w nil)) ; Return self, no command

;;;---------------------------------------------------------------
;;; Button Widget
;;;---------------------------------------------------------------

(defclass button-widget (elm-widget)
  ()
  (:documentation "A clickable button.
   Contract: implements init/update/render per base API.
   Props: expects :label for the button text.
   Handlers: expects :on-click for the message to send on activation."))

(defmethod widget-render ((w button-widget) &key &allow-other-keys)
  "Renders the button, typically as a container with text.
   Adds a 'button' class for styling."
  (let ((label (getf (widget-props w) :label "Button")))
    ;; Render as a container with text inside.
    ;; Add a class for styling. Props are passed down.
    (make-ui-node :type :container ; Or :box if defined and styled
                  :props (list* :class "button" :widget-id (widget-id w) (widget-props w))
                  :children (list (make-ui-node :type :text
                                                :props (list :value label)
                                                :children nil)))))

(defmethod widget-update ((w button-widget) msg &key &allow-other-keys)
  "Handles messages, specifically :click.
   If :click is received, sends the message specified in :on-click handler."
  (let ((msg-type (if (typep msg 'message) (message-type msg) msg))) ; Handle raw keywords or message structs
    (case msg-type
      (:click ; Assuming an interaction system sends :click
       (let ((on-click-msg (getf (widget-handlers w) :on-click)))
         (if on-click-msg
             ;; Return self, and a command to send the specified message
             (values w (cmd-async #'send-message on-click-msg))
             ;; No handler, do nothing
             (values w nil))))
      (otherwise
       ;; Ignore other messages for now
       (values w nil)))))

;;;---------------------------------------------------------------
;;; Input Widget
;;;---------------------------------------------------------------

(defclass input-widget (elm-widget)
  (;; Potential internal state (alternative to pure Elm model state)
   ;; (cursor-pos :initform 0 :accessor input-cursor-pos)
   ;; (current-value :initform "" :accessor input-current-value)
   )
  (:documentation "A text input field.
   Contract: implements init/update/render per base API.
   Props: :value (current text), potentially :placeholder.
   Handlers: :on-change (when value changes), :on-submit (on Enter)."))

(defmethod widget-render ((w input-widget) &key &allow-other-keys)
  "Renders the input field, showing current value and potentially cursor.
   Needs styling for appearance (border, background, cursor)."
  (let ((value (getf (widget-props w) :value "")))
    ;; Basic render: show the value. Cursor/focus requires platform integration.
    (make-ui-node :type :container ; Represent the input box
                  :props (list* :class "input" :widget-id (widget-id w) (widget-props w))
                  :children (list (make-ui-node :type :text
                                                :props (list :value value)
                                                :children nil)))))

(defmethod widget-update ((w input-widget) msg &key &allow-other-keys)
  "Handles key presses, focus changes, etc. (Complex).
   Should update internal state/value prop and potentially send :on-change/:on-submit."
  ;; Stub implementation - requires significant event handling logic
  (warn "input-widget update not fully implemented.")
  (values w nil))

(defmethod widget-init ((w input-widget) &key &allow-other-keys)
  "Initialize input widget state if necessary."
  ;; Stub
  w)
