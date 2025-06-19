;;;===============================================================
;;; File: src/ui/widgets/textinput.lisp
;;; Standardized Elm-style Text Input Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.textinput
  (:use :cl) ; Added alexandria
  (:import-from :elmtui.ui.defcomponent
                #:defcomponent #:id-from-path) ; Removed unused imports
  (:import-from :elmtui.ui.api ; Added for component base class
                #:component
                #:make-state-patch)
  (:import-from :elmtui.state ; For make-update-result
                #:make-update-result)
  (:import-from :elmtui.utils
                #:ensure-list #:ensure-keyword)
  (:import-from :elmtui.view.styled #:make-styled-node)
  ;; (:import-from :elmtui.state.msg #:defmsg) ; defmsg not used, messages are keywords
  ;; (:import-from :elmtui.core.async #:cmd #:cmd-payload) ; Not directly used for commands here
  ;; (:import-from :elmtui.core.events #:send-message) ; Not directly used
  (:export #:textinput #:make-textinput ; Class name and constructor
           ;; Messages (keywords)
           #:msg-textinput-key-press
           #:msg-textinput-set-value
           #:msg-textinput-submit
           ))

(in-package :elmtui.ui.widgets.textinput)

;; No defcomponent needed if we define class and methods manually
(defclass textinput (component) ()
  (:documentation "A text input widget that manages its state (value, cursor position, etc.) externally in the application state."))

(defun make-textinput (&key id)
  "Creates a new textinput component instance. ID is for direct use, but in DSL, it's derived."
  (make-instance 'textinput :id id))

;;;---------------------------------------------------------------
;;; Messages (Keywords) - Standardized as plain keywords for simplicity
;;;---------------------------------------------------------------
(defparameter msg-textinput-key-press :textinput-key-press)
(defparameter msg-textinput-set-value :textinput-set-value)
(defparameter msg-textinput-submit :textinput-submit)

;;;---------------------------------------------------------------
;;; Init Method
;;;---------------------------------------------------------------
(defmethod init ((component textinput) &key id-path
                                         (initial-value "")
                                         (initial-placeholder "")
                                         (initial-cursor-pos 0)
                                         initial-on-change
                                         initial-on-submit
                                         (initial-disabled nil)
                 &allow-other-keys)
  (let ((component-id (id-from-path id-path)))
    (values component
            (list (make-state-patch `(:components ,component-id)
                                    `(:type ,(type-of component)
                                      :id ,component-id
                                      :value ,initial-value
                                      :placeholder ,initial-placeholder
                                      :cursor-pos ,initial-cursor-pos
                                      :on-change ,initial-on-change
                                      :on-submit ,initial-on-submit
                                      :disabled ,initial-disabled)))
            nil))) ; No initial commands by default

;;;---------------------------------------------------------------
;;; Update Method
;;;---------------------------------------------------------------
(defmethod update ((component textinput) state msg &key id-path)
  (let* ((component-id (id-from-path id-path))
         (component-state-path `(:components ,component-id))
         (props (getf state component-state-path)) ; Get all props for this component
         (current-value (getf props :value ""))
         (current-cursor-pos (getf props :cursor-pos 0))
         (current-on-change (getf props :on-change))
         (current-on-submit (getf props :on-submit))
         (current-disabled (getf props :disabled nil))
         (patches nil)
         (commands nil)
         (value-changed nil))
    (declare (ignore current-on-change)) ; state is not used directly in this method

    (unless props
      (warn "Textinput ~A state not found at ~S" component-id component-state-path)
      (return-from update (make-update-result :patches nil :commands nil)))

    (etypecase msg
      ;; 1. (:textinput-key-press :key <key-data>)
      ((cons (eql msg-textinput-key-press) t)
       (unless current-disabled
         (let* ((key-data (getf (rest msg) :key))
                (char (getf key-data :char))
                (key-sym (getf key-data :key-sym)))
           (cond
             (char ; Printable character
              (push (make-state-patch (append component-state-path '(:value))
                                      (concatenate 'string
                                                   (subseq current-value 0 current-cursor-pos)
                                                   (string char)
                                                   (subseq current-value current-cursor-pos))) patches)
              (push (make-state-patch (append component-state-path '(:cursor-pos)) (1+ current-cursor-pos)) patches)
              (setf value-changed t))
             ((eq key-sym :backspace)
              (when (> current-cursor-pos 0)
                (push (make-state-patch (append component-state-path '(:value))
                                        (concatenate 'string
                                                     (subseq current-value 0 (1- current-cursor-pos))
                                                     (subseq current-value current-cursor-pos))) patches)
                (push (make-state-patch (append component-state-path '(:cursor-pos)) (1- current-cursor-pos)) patches)
                (setf value-changed t)))
             ((eq key-sym :delete)
              (when (< current-cursor-pos (length current-value))
                (push (make-state-patch (append component-state-path '(:value))
                                        (concatenate 'string
                                                     (subseq current-value 0 current-cursor-pos)
                                                     (subseq current-value (1+ current-cursor-pos)))) patches)
                (setf value-changed t)))
             ((eq key-sym :left)
              (when (> current-cursor-pos 0)
                (push (make-state-patch (append component-state-path '(:cursor-pos)) (1- current-cursor-pos)) patches)))
             ((eq key-sym :right)
              (when (< current-cursor-pos (length current-value))
                (push (make-state-patch (append component-state-path '(:cursor-pos)) (1+ current-cursor-pos)) patches)))
             ((eq key-sym :home)
              (push (make-state-patch (append component-state-path '(:cursor-pos)) 0) patches))
             ((eq key-sym :end)
              (push (make-state-patch (append component-state-path '(:cursor-pos)) (length current-value)) patches))
             ((eq key-sym :enter)
              (when current-on-submit
                (push current-on-submit commands)))))))

      ;; 2. (:textinput-set-value :new-value "new text")
      ((cons (eql msg-textinput-set-value) t)
       (unless current-disabled
         (let ((new-val (getf (rest msg) :new-value)))
           (unless (string= current-value new-val)
             (push (make-state-patch (append component-state-path '(:value)) new-val) patches)
             (push (make-state-patch (append component-state-path '(:cursor-pos)) (length new-val)) patches) ; Move cursor to end
             (setf value-changed t)))))

      ;; 3. Bare keyword :textinput-submit
      ((eql msg-textinput-submit)
       (unless current-disabled
         (when current-on-submit
           (push current-on-submit commands))))

      ;; 4. Direct property mutation for external control (e.g., from a form)
      ;;    (:set-property :property-name <value>)
      ((cons (eql :set-property) t)
       (let ((prop-key (second msg))
             (prop-val (third msg)))
         (case prop-key
           (:value
            (unless (string= current-value prop-val)
              (push (make-state-patch (append component-state-path '(:value)) prop-val) patches)
              (push (make-state-patch (append component-state-path '(:cursor-pos)) (length prop-val)) patches)
              (setf value-changed t)))
           (:placeholder
            (push (make-state-patch (append component-state-path '(:placeholder)) prop-val) patches))
           (:cursor-pos
            (push (make-state-patch (append component-state-path '(:cursor-pos)) prop-val) patches))
           (:on-change
            (push (make-state-patch (append component-state-path '(:on-change)) prop-val) patches))
           (:on-submit
            (push (make-state-patch (append component-state-path '(:on-submit)) prop-val) patches))
           (:disabled
            (push (make-state-patch (append component-state-path '(:disabled)) prop-val) patches))
           (t (warn "Unknown property for textinput set-property: ~S" prop-key))))))))
