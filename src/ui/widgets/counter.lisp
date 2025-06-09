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
                #:component-id #:init #:update #:view #:make-state-patch #:get-path #:id-from-path)
  (:import-from :elmtui.state.api #:make-update-result )
  (:import-from :log4cl #:log-warn)
  (:export #:counter
           #:counter-value
           #:counter-initial-value))
(in-package :elmtui.ui.widgets.counter)

(defcomponent counter ()
    ((value :accessor counter-value :initarg :value :initform 0 :type integer
            :documentation "The current value of the counter.")
     (initial-value :accessor counter-initial-value :initarg :initial-value :initform 0 :type integer
                    :documentation "The initial value for resetting the counter."))
    (:documentation "A simple counter widget that can be incremented, decremented, and reset."))

(defmethod init ((self counter) &key id-path (initial-value 0) &allow-other-keys)
  "Initializes the counter component.
   The :initial-value keyarg sets both the starting value and the reset value."
  (multiple-value-bind (instance initial-patches commands)
      (call-next-method self
                        :id-path id-path
                        :value initial-value        ;; Set the 'value' slot to initial-value
                        :initial-value initial-value ;; Set the 'initial-value' slot to initial-value
                        )
    (declare (ignore commands)) ; Base init from defcomponent likely returns nil commands

    (let* ((component-id (id-from-path id-path))
           (keymap-name (symbol-name (gensym (format nil "~A-KEYMAP-" component-id))))
           (keymap (make-keymap :name keymap-name
                                :bindings
                                `(((,(parse-key-string "+") . (:increment))
                                   (,(parse-key-string "=") . (:increment)) ; Alias for +
                                   ((,(parse-key-string "-") . (:decrement))
                                    ((,(parse-key-string "Enter") . (:reset))))))))
           ;; The path to this component's state in the global app-state is id-path itself
           ;; as per defcomponent's init method structure.
           (keymap-patch (make-state-patch :path id-path
                                           :value `(:active-keymap ,keymap)
                                           :strategy :merge))) ; Merge with existing state
      (values instance
              (append initial-patches (list keymap-patch))
              nil))))

(defmethod update ((self counter) app-state message &key id-path)
  "Updates the counter component's state based on a message."
  (declare (ignore id-path)) ; id-path is for routing, state access via component-id
  (let* ((component-id (component-id self))
         (component-state-path `(:components ,component-id)) ; Path to this component's state data
         (current-state (get-path app-state component-state-path))
         (current-value (getf current-state :value))
         (initial-val (getf current-state :initial-value)) ; Should always exist after init
         (new-value current-value))

    (case (if (listp message) (first message) message)
      (:increment (setf new-value (1+ current-value)))
      (:decrement (setf new-value (1- current-value)))
      (:reset (setf new-value initial-val))
      (otherwise (log-warn "COUNTER-WIDGET (~S): Unknown message: ~S" component-id message)))

    (if (eql new-value current-value)
        (make-update-result) ; No change, no patches, no commands
        (make-update-result
         :patches (list (make-state-patch component-state-path
                                          `(:value ,new-value)))))))


(defmethod view ((self counter) app-state &key id-path)
  "Returns a UI-NODE representation of the counter component."
  (declare (ignore id-path)) ; id-path for context if needed, data from app-state via component-id
  (let* ((component-id (component-id self))
         (component-state-path `(:components ,component-id))
         (current-state (get-path app-state component-state-path))
         (current-value (getf current-state :value)))
    (make-instance 'ui-node :type :counter ; Using :counter as the ui-node type
                            :props (list :widget-id component-id
                                         :focusable t
                                         :value current-value)
                            :children (list
                                       (make-instance 'ui-node :type :text
                                                               :props (list :value (format nil "Counter [~A]: ~A (+, -, Enter to reset)"
                                                                                           component-id
                                                                                           current-value)))))))
