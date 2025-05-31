;;;===============================================================
;;; File: src/ui/widgets/textinput.lisp
;;; Standardized Elm-style Text Input Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.textinput
  (:use :cl :alexandria)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message)
  (:import-from :elmtui.ui.widgets.utils 
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  (:export #:textinput-model #:make-textinput-model ; Struct and its constructor
           ;; Accessors
           #:textinput-model-id
           #:textinput-model-value
           #:textinput-model-placeholder
           #:textinput-model-cursor-pos
           #:textinput-model-on-change
           #:textinput-model-on-submit
           #:textinput-model-disabled
           ;; Core TEA functions
           #:init-textinput #:update-textinput #:view-textinput
           ;; Message types 
           #:msg-textinput-key-press
           #:msg-textinput-set-value
           #:msg-textinput-submit))
(in-package :elmtui.ui.widgets.textinput)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (textinput-model (:constructor %make-textinput-model))
  "Model for a text input widget.
   ID: Unique identifier.
   VALUE: Current text content.
   PLACEHOLDER: Text to show when empty.
   CURSOR-POS: Current cursor position.
   ON-CHANGE: Message to dispatch when value changes.
   ON-SUBMIT: Message to dispatch on submit (e.g., Enter key).
   DISABLED: Whether the input is disabled."
  (id (error "ID must be provided.") :type T :read-only t)
  (value "" :type string)
  (placeholder "" :type string)
  (cursor-pos 0 :type unsigned-byte)
  (on-change nil :type T) 
  (on-submit nil :type T)
  (disabled nil :type boolean))

;;;---------------------------------------------------------------
;;; Messages (Keywords)
;;;---------------------------------------------------------------
(defparameter msg-textinput-key-press :textinput-key-press)
(defparameter msg-textinput-set-value :textinput-set-value)
(defparameter msg-textinput-submit :textinput-submit)

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-textinput (id &key 
                            (value "")
                            (placeholder "")
                            (on-change nil)
                            (on-submit nil)
                            (disabled nil))
  "Initializes a new text input model.
   Returns (values textinput-model initial-command)."
  (values (%make-textinput-model :id id
                                 :value value
                                 :placeholder placeholder
                                 :cursor-pos (length value) ; Cursor at end by default
                                 :on-change on-change
                                 :on-submit on-submit
                                 :disabled disabled)
          nil)) ; No initial commands

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-textinput (msg model)
  "Updates the textinput model based on a message.
   MSG: The message to process.
   MODEL: The current textinput-model instance.
   Returns (values new-textinput-model command-list)."
  (check-type model textinput-model)
  (let ((new-model (copy-structure model))
        (commands nil)
        (value-changed nil))

    (etypecase msg
      ;; (:textinput-key-press :key <key-data>) 
      ((cons (eql msg-textinput-key-press))
       (unless (textinput-model-disabled new-model)
         (let* ((key-data (getf (rest msg) :key))
                (char (getf key-data :char))
                (key-sym (getf key-data :key-sym))
                (current-value (textinput-model-value new-model))
                (cursor (textinput-model-cursor-pos new-model)))

           (cond
             (char ; Printable character
              (setf (textinput-model-value new-model)
                    (concatenate 'string
                                 (subseq current-value 0 cursor)
                                 (string char)
                                 (subseq current-value cursor)))
              (setf (textinput-model-cursor-pos new-model) (1+ cursor))
              (setf value-changed t))
             ((eq key-sym :backspace)
              (when (> cursor 0)
                (setf (textinput-model-value new-model)
                      (concatenate 'string
                                   (subseq current-value 0 (1- cursor))
                                   (subseq current-value cursor)))
                (setf (textinput-model-cursor-pos new-model) (1- cursor))
                (setf value-changed t)))
             ((eq key-sym :delete)
              (when (< cursor (length current-value))
                (setf (textinput-model-value new-model)
                      (concatenate 'string
                                   (subseq current-value 0 cursor)
                                   (subseq current-value (1+ cursor))))
                (setf value-changed t)))
             ((eq key-sym :left)
              (when (> cursor 0)
                (setf (textinput-model-cursor-pos new-model) (1- cursor))))
             ((eq key-sym :right)
              (when (< cursor (length current-value))
                (setf (textinput-model-cursor-pos new-model) (1+ cursor))))
             ((eq key-sym :home)
              (setf (textinput-model-cursor-pos new-model) 0))
             ((eq key-sym :end)
              (setf (textinput-model-cursor-pos new-model) (length current-value)))
             ((eq key-sym :enter)
              (when (textinput-model-on-submit new-model)
                (push (cmd-async #'send-message :args (textinput-model-on-submit new-model)) commands)))))))

      ;; (:textinput-set-value :value "new text")
      ((cons (eql msg-textinput-set-value))
       (unless (textinput-model-disabled new-model)
         (let ((new-val (getf (rest msg) :value)))
           (unless (string= (textinput-model-value new-model) new-val)
             (setf (textinput-model-value new-model) new-val)
             (setf (textinput-model-cursor-pos new-model) (length new-val)) ; Move cursor to end
             (setf value-changed t)))))

      ((eql msg-textinput-submit) 
       (unless (textinput-model-disabled new-model)
         (when (textinput-model-on-submit new-model)
           (push (cmd-async #'send-message :args (textinput-model-on-submit new-model)) commands)))))

    ;; Handle on-change command if value changed
    (when value-changed
      (when (textinput-model-on-change new-model)
        (let ((on-change-msg (textinput-model-on-change new-model)))
          (if (listp on-change-msg) ; If it's a message template
              (push (cmd-async #'send-message
                               :args (append on-change-msg (list :value (textinput-model-value new-model))))
                    commands)
              (push (cmd-async #'send-message :args on-change-msg) commands)))))

    (values new-model commands)))

;;;---------------------------------------------------------------
;;; View (STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-textinput (app-state
                                :model-var model
                                :widget-id-var widget-id
                                :add-args (
                                           value placeholder
                                           on-change on-submit
                                           disabled
                                           tooltip aria-label
                                           class width height)
                                :documentation
                                "Creates a UI representation of a text input field.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this text input (required).
   VALUE: Text content. Defaults to model's value if not provided.
   PLACEHOLDER: Text to show when input is empty.
   ON-CHANGE: Message to dispatch when value changes.
   ON-SUBMIT: Message to dispatch on submit (e.g., Enter key).
   DISABLED: Whether the input is disabled.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.
   WIDTH: Width in columns.
   HEIGHT: Height in rows.")

  ;; Determine effective values from model and/or provided props
  (let* ((effective-value (or value 
                              (when model (textinput-model-value model))
                              ""))
         (effective-placeholder (or placeholder
                                    (when model (textinput-model-placeholder model))
                                    ""))
         (effective-on-change (or on-change
                                  (when model (textinput-model-on-change model))
                                  nil))
         (effective-on-submit (or on-submit
                                  (when model (textinput-model-on-submit model))
                                  nil))
         (effective-disabled (or disabled
                                 (when model (textinput-model-disabled model))
                                 nil))
         (effective-cursor-pos (when model (textinput-model-cursor-pos model)))
         (is-focused (widget-focused-p widget-id app-state))
         
         ;; Build CSS classes
         (base-class "textinput")
         (focused-class (when is-focused "textinput-focused"))
         (disabled-class (when effective-disabled "textinput-disabled"))
         (custom-class class)
         (all-classes (remove nil (list base-class focused-class disabled-class custom-class))))
    
    ;; Create the styled node representing the text input
    (make-styled-node
     :type :text-input
     :props (list* :id widget-id
                   :value effective-value
                   :placeholder effective-placeholder
                   :cursor-pos effective-cursor-pos
                   :on-change effective-on-change
                   :on-submit effective-on-submit
                   :disabled effective-disabled
                   :focusable (not effective-disabled)
                   :class (format nil "~{~A~^ ~}" all-classes) ; Join classes with spaces
                   :aria-role "textbox"
                   :aria-disabled (if effective-disabled "true" "false")
                   ;; Include optional properties only if provided
                   (append
                    (when width (list :width width))
                    (when height (list :height height))
                    (when tooltip (list :title tooltip))
                    (when aria-label (list :aria-label aria-label))))
     :children nil)))

;;;---------------------------------------------------------------
;;; Backward Compatibility Wrapper
;;;---------------------------------------------------------------
;; This is a temporary function to maintain backward compatibility
;; during transition to the new widget pattern
;; (defun view-textinput (model &key current-focus-id dispatch-fn)
;;   "DEPRECATED: Use view-textinput instead."
;;   (warn "view-textinput is deprecated. Use view-textinput with app-state and :widget-id instead.")
;;   (let ((widget-id (textinput-model-id model))
;;         (is-focused (eq widget-id current-focus-id)))
;;     (make-styled-node
;;      :type :text-input
;;      :props (list :id widget-id
;;                   :value (textinput-model-value model)
;;                   :placeholder (textinput-model-placeholder model)
;;                   :cursor-pos (textinput-model-cursor-pos model)
;;                   :is-focused is-focused
;;                   :disabled nil ; Old model doesn't have this property
;;                   :focusable t
;;                   :class (if is-focused
;;                              "textinput textinput-focused"
;;                              "textinput")
;;                   :aria-role "textbox"
;;                   :aria-disabled "false"
;;                   ;; Events handling
;;                   )
;;      :children nil)))
