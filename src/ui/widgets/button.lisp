;;;===============================================================
;;; File: src/ui/widgets/button.lisp
;;; Elm-style Button Widget with Standardized Interface
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.button
  (:use :cl :elmtui.ui.defcomponent)
  (:import-from :elmtui.ui.api #:id-from-path #:app-state) ; Keep only used API functions
  (:import-from :elmtui.state.api #:make-update-result)
  ;; Removed :elmtui.core.async and :elmtui.core.events as commands are now data.
  ;; Removed :elmtui.state.msg :defmsg as the specific ButtonMsg is not used internally by the refactored component.
  (:export #:button)) ; Export only the component name

(in-package :elmtui.ui.widgets.button)
;; (defmethod cclass-name ((cmp (eql 'lurch)))
;;   "lurch")
;; Define component with its state properties
(defcomponent button ()
  (:state
   (label "Button" :type string :documentation "The text displayed on the button."
                   :initarg :label :accessor button-label)
   (on-click-msg nil :type (or null t) :documentation "The message to dispatch when the button is clicked."
                     :initarg :on-click-msg :accessor button-on-click-msg)
   (disabled nil :type (or null boolean) :documentation "Whether the button is disabled."
                 :initarg :disabled :accessor button-disabled-p)
   (focused nil :type (or boolean null ) :documentation "Whether the button currently has focus.")
   ;; Lightweight enhanced features
   (variant :default :type keyword :documentation "Visual variant (e.g., :default, :primary).")
   (size :medium :type keyword :documentation "Visual size (e.g., :small, :medium, :large).")
   (aria-label nil :type (or null string) :documentation "Screen-reader label override.")
   (tooltip nil :type (or null string) :documentation "Tooltip text.")
   )
  (:documentation "A clickable button widget, refactored to the new defcomponent style.")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
         ;; (declare (ignore self-id-path))
         ;; :initargs :label, :on-click-msg, :disabled (if provided to make-instance)
         ;; are handled by defcomponent's default initarg processing.
         ;; This inline :init can still override or supplement.
         ;; Here, we allow :initial-label, :initial-on-click-msg, :initial-disabled as aliases from props.
         (values `(:label ,(getf props :label (getf props :initial-label "Button"))
                   ;; Allow :action as alias for on-click-msg
                   :on-click-msg ,(or (getf props :on-click-msg)
                                      (getf props :initial-on-click-msg)
                                      (getf props :action))
                   :disabled ,(getf props :disabled (getf props :initial-disabled nil))
                   :focused nil ; Focused state always starts as nil
                   :variant ,(getf props :variant :default)
                   :size ,(getf props :size :medium)
                   :aria-label ,(getf props :aria-label)
                   :tooltip ,(getf props :tooltip))
                 nil)) ; No initial commands

  (:update (message local-state app-state self-id-path)
           ;; (declare (ignore app-state self-id-path))
           (:button-click ()
                          (if (or (getf local-state :disabled) (not (getf local-state :on-click-msg)))
                              (values nil nil) ; No action if disabled or no on-click-msg
                              (values nil (list (getf local-state :on-click-msg)))))
           (:set-label (new-label)
                       (values `(:label ,new-label) nil))
           (:set-disabled (new-disabled-state)
                          (values `(:disabled ,(not (not new-disabled-state))) nil)) ; Ensure boolean
           (:focus ()
                   (values `(:focused t) nil))
           (:blur ()
                  (values `(:focused nil) nil)))

  (:view (local-state app-state self-id-path children)
         ;; (declare (ignore app-state))
                                        ; app-state not directly used
         (let* ((component-id (id-from-path self-id-path))
                (label (getf local-state :label))
                (disabled (getf local-state :disabled))
                (focused (getf local-state :focused))
                (variant (getf local-state :variant :default))
                (size (getf local-state :size :medium))
                (aria-label (getf local-state :aria-label))
                (tooltip (getf local-state :tooltip))
                (base-class "button")
                (variant-class (format nil "button-variant-~(~a~)" variant))
                (size-class (format nil "button-size-~(~a~)" size))
                (disabled-class (when disabled "button-disabled"))
                (focused-class (when focused "button-focused"))
                (all-classes (remove nil (list base-class variant-class size-class disabled-class focused-class))))
           (list :container
                 ;; :type :button ; This type is used by the renderer/event handler
                 :props (list :id component-id
                              :focusable (not disabled) ; Can't focus if disabled
                              :label label
                              :disabled disabled
                              ;; The view's :on-click should send a message to this component's update
                              :on-click (unless disabled '(:button-click))
                              :class (format nil "~{~A~^ ~}" all-classes)
                              :aria-role "button"
                              :aria-disabled (if disabled "true" "false")
                              :aria-label aria-label
                              :title tooltip)
                 :children nil))))

;; To make a button instance:
;; (make-instance 'button :id :my-button
;;                        :label "Click Me!"
;;                        :on-click-msg '(:my-app-action :payload "data")
;;                        :disabled nil)
