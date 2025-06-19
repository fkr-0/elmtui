;;;===============================================================
;;; File: src/ui/widgets/counter.lisp
;;; A simple counter widget example using defcomponent
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.counter
  (:use :cl :alexandria)
  (:import-from :elmtui.core.keymap #:make-keymap #:parse-key-string)
  (:import-from :elmtui.view.core #:ui-node)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api
                #:component-id #:init #:update #:view #:get-path #:id-from-path)
  (:import-from :elmtui.state.api #:make-update-result)
  ;; Removed :make-state-patch as defcomponent handles patch creation from :update return values
  ;; Removed :log-warn as unhandled messages are handled by defcomponent's :on-unhandled-message
  (:export #:counter))
(in-package :elmtui.ui.widgets.counter)

(defcomponent counter ()
    () ;; No direct CLOS slots, state is managed by :state clause
    (:state
     (value 0 :type integer :documentation "The current value of the counter."
              :initarg :value :accessor counter-value)
     (initial-value 0 :type integer :documentation "The initial value for resetting the counter."
                      :initarg :initial-value :accessor counter-initial-value)
     (active-keymap nil :type (or null elmtui.core.keymap:keymap) :documentation "Component-specific keymap."))
  (:documentation "A simple counter widget that can be incremented, decremented, and reset using the new defcomponent style.")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
   "Initializes the counter component.
    The :initial-value prop (from make-instance) sets both the starting value and the reset value.
    If :value is also provided via make-instance, :initial-value takes precedence for setting the initial :value state."
   (let* ((init-val (getf props :initial-value ; Use :initial-value from props if present
                          (getf props :value 0))) ; Otherwise use :value from props, or default to 0
          (reset-val (getf props :initial-value 0)) ; Reset value is always from :initial-value prop or 0
          (component-id (id-from-path self-id-path))
          (keymap-name (symbol-name (gensym (format nil "~A-KEYMAP-" component-id))))
          (keymap (make-keymap :name keymap-name
                               :bindings
                               `(((,(parse-key-string "+") . (:increment))
                                  (,(parse-key-string "=") . (:increment)) ; Alias for +
                                  (,(parse-key-string "-") . (:decrement))
                                  (,(parse-key-string "Enter") . (:reset)))))))
     (values `(:value ,init-val
               :initial-value ,reset-val
               :active-keymap ,keymap)
             nil))) ; No initial commands

  (:update (message local-state app-state self-id-path)
   "Updates the counter component's state based on a message."
   (declare (ignore app-state self-id-path)) ; Not used in this simple update
   (let ((current-value (getf local-state :value))
         (initial-val (getf local-state :initial-value)))
     (:increment ()
      (values `(:value ,(1+ current-value)) nil))
     (:decrement ()
      (values `(:value ,(1- current-value)) nil))
     (:reset ()
      (values `(:value ,initial-val) nil))
     ;; :otherwise clause is implicitly handled by :on-unhandled-message :log
     ))

  (:view (local-state app-state self-id-path)
   "Returns a UI-NODE representation of the counter component."
   (declare (ignore app-state)) ; Not used in this simple view
   (let ((component-id (id-from-path self-id-path))
         (current-value (getf local-state :value)))
     (make-instance 'ui-node :type :counter
                             :props (list :widget-id component-id
                                          :focusable t
                                          :value current-value)
                             :children (list
                                        (make-instance 'ui-node :type :text
                                                                :props (list :value (format nil "Counter [~A]: ~A (+, -, Enter to reset)"
                                                                                            component-id
                                                                                            current-value))))))))
