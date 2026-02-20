;;;; Variant Examples for Polymorphic DSL Resolution
;;;;
;;;; This file demonstrates the new polymorphic DSL resolution system
;;;; where DSL types are resolved via CLOS generic functions instead of
;;;; static hash-table registries.

(cl:in-package :elmtui.tests)

;;=======================================================================
;; Example 1: Basic Component with Auto-generated DSL Type
;;=======================================================================

(elmtui.ui.defcomponent:defcomponent primary-button ()
  (:state
    (label "Click me" :type string :documentation "Button text")
    (on-click nil :type (or null function) :documentation "Click handler")
    (disabled nil :type boolean :documentation "Whether button is disabled"))
  (:metadata
    (:props ((:label string t :doc "Button text")
             (:on-click function nil :doc "Click handler function")
             (:disabled boolean nil :doc "Whether button is disabled")))
    (:documentation "A primary action button with default styling.")
    (:examples '((:primary-button :label "Submit")
                 (:primary-button :label "Save" :on-click save-form))))
  (:view (local-state-map app-state self-id-path children)
    `(:button :id (elmtui.ui.api:id-from-path self-id-path)
              :text (getf local-state-map :label "Click")
              :on-click (getf local-state-map :on-click)
              :disabled (getf local-state-map :disabled)
              :class "btn-primary"))))

;; The defcomponent macro automatically generates:
;; (defmethod dsl-type ((type (eql :primary-button)) &optional props)
;;   (values 'primary-button props))

;;=======================================================================
;; Example 2: DSL Type Variant with Default Props
;;=======================================================================

;; Define a variant that adds default props to the base component
(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :large-primary-button)) &optional props)
  "A large primary button variant."
  (elmtui.api:dsl-type :primary-button (append props '(:size :large))))

;; Usage:
;; (:large-primary-button :label "Submit")
;; Expands to: (:primary-button :label "Submit" :size :large)

;;=======================================================================
;; Example 3: DSL Type Alias
;;=======================================================================

;; Create an alias for a component
(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :btn)) &optional props)
  "Short alias for button."
  (elmtui.api:dsl-type :primary-button props))

;; Usage:
;; (:btn :label "Click")
;; Same as: (:primary-button :label "Click")

;;=======================================================================
;; Example 4: Chained Variants
;;=======================================================================

;; Define a disabled button variant
(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :disabled-button)) &optional props)
  "A permanently disabled button."
  (elmtui.api:dsl-type :primary-button (append props '(:disabled t))))

;; Chain with large variant
(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :large-disabled-button)) &optional props)
  "A large, permanently disabled button."
  (elmtui.api:dsl-type :large-primary-button
    (append props '(:disabled t))))

;; Usage:
;; (:large-disabled-button :label "Can't Click")
;; Expands through chain: :large-disabled-button → :large-primary-button
;; → :primary-button with props '(:size :large :disabled t)

;;=======================================================================
;; Example 5: Component with Metadata
;;=======================================================================

(elmtui.ui.defcomponent:defcomponent counter-widget ()
  (:state
    (count 0 :type integer :documentation "Current count value")
    (step 1 :type integer :documentation "Increment step size"))
  (:metadata
    (:props ((:count integer t :doc "Initial count value")
             (:step integer nil :doc "Increment/decrement amount"))
    (:documentation "A counter widget that can increment and decrement.")
    (:examples '((:counter-widget :count 0)
                 (:counter-widget :count 10 :step 5))))
  (:update (msg state app-state id-path)
    (:increment (amount)
      (values `(:count ,(+ (getf state :count 0) amount)) nil))
    (:decrement (amount)
      (values `(:count ,(- (getf state :count 0) amount)) nil))
    (:reset ()
      (values `(:count 0) nil)))
  (:view (local-state-map app-state self-id-path children)
    `(:text :id (elmtui.ui.api:id-from-path self-id-path)
              :content (format nil "Count: ~D" (getf local-state-map :count 0)))))

;; Access metadata:
;; (elmtui.ui.component-metaclass:class-metadata (find-class 'counter-widget))
;; Returns: (:props (...) :documentation "..." :examples (...))

;;=======================================================================
;; Example 6: Layout Component Variants
;;=======================================================================

;; The layout component is already defined in elmtui.ui.widgets.layout
;; We can create variants for common layouts:

(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :row)) &optional props)
  "Alias for layout with horizontal direction."
  (elmtui.api:dsl-type :layout (append props '(:direction :row))))

(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :column)) &optional props)
  "Alias for layout with vertical direction."
  (elmtui.api:dsl-type :layout (append props '(:direction :column))))

(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :center-row)) &optional props)
  "A row that centers its children."
  (elmtui.api:dsl-type :row (append props '(:justify-content :center))))

;; Usage:
;; (:row (:text "Left") (:text "Right"))
;; (:column (:text "Top") (:text "Bottom"))
;; (:center-row (:text "Centered"))

;;=======================================================================
;; Example 7: Variant with Style Injection
;;=======================================================================

(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :danger-button)) &optional props)
  "A red button for destructive actions."
  (elmtui.api:dsl-type :primary-button
    (append props '(:color :red :bg-color :darkred))))

(elmtui.ui.dsl-resolution:defmethod elmtui.api:dsl-type
    ((type (eql :success-button)) &optional props)
  "A green button for success actions."
  (elmtui.api:dsl-type :primary-button
    (append props '(:color :green :bg-color :darkgreen))))

;;=======================================================================
;; Summary of Benefits
;;=======================================================================

;; 1. No Explicit Registration:
;;    - No need to call register-dsl-component-type
;;    - defcomponent auto-generates dsl-type methods
;;
;; 2. Type Safety:
;;    - Compile-time checking of DSL types
;;    - Errors caught at macroexpansion time
;;
;; 3. Easy Variants:
;;    - Define variant with single defmethod
;;    - Chain variants for complex defaults
;;    - Create aliases for convenience
;;
;; 4. Metadata Support:
;;    - Store component info in class metaobject
;;    - Access via (class-metadata (find-class 'component-name))
;;    - Support for props, documentation, examples
;;
;; 5. Composability:
;;    - Variants can build on other variants
;;    - Props are accumulated through chain
;;    - Flexible DSL design

;;=======================================================================
;; Example Application Using Variants
;;=======================================================================

(elmtui.app:defapplication variant-example-app
  :root-component-dsl
  '(:root-viewport :id :main-viewport
     :initial-terminal-dimensions (80 24)
     :initial-cursor-pos (1 1)
     :children
     ((:row :id :button-row :justify-content :center
        :children
        ((:primary-button :id :submit-btn :label "Submit")
          (:danger-button :id :cancel-btn :label "Cancel")
          (:success-button :id :ok-btn :label "OK")))))
     :view-fn variant-example-view
     :root-viewport-id :rv)

(defun variant-example-view (app-state)
  (declare (ignore app-state))
  '(:text :content "Variant Example App"))
