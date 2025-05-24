;;;===============================================================
;;; File: src/ui/widgets/counter.lisp
;;; A simple counter widget example
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.counter
  (:use :cl :alexandria)
  (:import-from :elmtui.core.keymap #:create-keymap-from-definitions)
  (:import-from :elmtui.view.core #:ui-node) ; Assuming ui-node is the way to define view parts
  (:export #:init
    #:update
    #:view
    #:counter-widget-id ; For referencing
    ))
(in-package :elmtui.ui.widgets.counter)

(defparameter counter-widget-id :my-counter "Default ID for the counter widget instance.")

;; Model: (list :value integer :active-keymap keymap-struct :id symbol)

(defun init (&key (initial-value 0) (id counter-widget-id))
  "Initializes the counter widget's model."
  (let ((keymap (create-keymap-from-definitions
                  (symbolicate id '-keymap) ; Name for the keymap
                  '(("+"    :type :message :target '(:increment) :description "Increment counter")
                     ("Enter" :type :message :target '(:increment) :description "Increment counter (Enter)")
                     ("-"    :type :message :target '(:decrement) :description "Decrement counter"))
                  id))) ; Source identifier for bindings
    ;; Returns the initial model plist for this widget
    (list :value initial-value
      :active-keymap keymap
      :id id)))

(defun update (model message)
  "Updates the counter widget's model based on a message.
   Returns (values new-model-plist commands-list)."
  (let ((new-value (getf model :value)))
    (case (if (listp message) (first message) message)
      (:increment (setf new-value (1+ (getf model :value))))
      (:decrement (setf new-value (1- (getf model :value))))
      (otherwise (log:warn "COUNTER-WIDGET: Unknown message: ~S" message)))

    ;; Return the plist representing the changed parts of the model, and any commands
    (values (list :value new-value) ; Only value changes
      nil))) ; No commands

(defun view (model)
  "Returns a UI-NODE representation of the counter widget."
  (make-instance 'ui-node :type :counter-widget
    :props (list :widget-id (getf model :id)
             :focusable t ; Important for receiving key events via focus
             :value (getf model :value))
    :children (list
                (make-instance 'ui-node :type :text
                  :props (list :value (format nil "Counter [~A]: ~A (+/- or Enter)"
                                        (getf model :id)
                                        (getf model :value)))))))
