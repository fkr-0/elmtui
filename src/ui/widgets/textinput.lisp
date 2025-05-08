;;;===============================================================
;;; File: src/ui/widgets/textinput.lisp
;;; Elm-style TextInput Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.textinput
  (:use :cl :alexandria)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:import-from :elmtui.core.events #:cmd) ; For potential commands like :on-change or :on-submit
  ;; TODO: Import specific key symbols if needed from elmtui.core.input-events
  (:export #:textinput-model #:make-textinput-model ; Struct and its constructor
           ;; Accessors
           #:textinput-model-id
           #:textinput-model-value
           #:textinput-model-placeholder
           #:textinput-model-cursor-pos
           #:textinput-model-is-focused
           #:textinput-model-on-change ;; Message to send when value changes
           #:textinput-model-on-submit ;; Message to send on enter
           ;; Core TEA functions
           #:init-textinput #:update-textinput #:view-textinput
           ;; Message types (keywords for now, could be defmsg'd later if complex)
           #:msg-textinput-key-press
           #:msg-textinput-set-value
           #:msg-textinput-focus
           #:msg-textinput-blur
           #:msg-textinput-submit))
(in-package :elmtui.ui.widgets.textinput)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (textinput-model (:constructor %make-textinput-model))
  "Model for a text input widget."
  (id (error "ID must be provided.") :type T :read-only t)
  (value "" :type string)
  (placeholder "" :type string)
  (cursor-pos 0 :type unsigned-byte)
  (is-focused nil :type boolean)
  (on-change nil :type T) ; Message to dispatch on value change
  (on-submit nil :type T)) ; Message to dispatch on submit (e.g., Enter key)

;;;---------------------------------------------------------------
;;; Messages (Keywords - can be expanded with defmsg if needed)
;;;---------------------------------------------------------------
;; (:key-press :key <key-event-data>) - from platform, handled by parent, then passed here
;; (:set-value :value <new-string>) - direct manipulation
;; (:focus) - from parent
;; (:blur) - from parent
;; (:submit) - internal, or from parent if enter key is handled globally

(defparameter msg-textinput-key-press :textinput-key-press)
(defparameter msg-textinput-set-value :textinput-set-value)
(defparameter msg-textinput-focus :textinput-focus)
(defparameter msg-textinput-blur :textinput-blur)
(defparameter msg-textinput-submit :textinput-submit)


;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-textinput (id &key (value "") (placeholder "") (on-change nil) (on-submit nil))
  "Initializes a new textinput model.
   Returns (values textinput-model initial-command)."
  (values (%make-textinput-model :id id
                                 :value value
                                 :placeholder placeholder
                                 :cursor-pos (length value) ; Cursor at end by default
                                 :is-focused nil
                                 :on-change on-change
                                 :on-submit on-submit)
          nil)) ; No initial commands

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-textinput (msg model)
  "Updates the textinput model based on a message.
   Returns (values new-textinput-model command-list)."
  (check-type model textinput-model)
  (let ((new-model (copy-structure model))
        (commands nil)
        (value-changed nil))

    (etypecase msg
      ;; (:textinput-key-press (key-event)) - msg is like '(:key-press :key <key-data>)
      ((cons (eql msg-textinput-key-press)) ; e.g. '(:textinput-key-press :key <key-obj>)
       (when (textinput-model-is-focused new-model)
         (let* ((key-data (getf (rest msg) :key)) ; Assuming key-data has :char, :key-sym
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
                ;; Cursor position does not change for delete
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
                (push (textinput-model-on-submit new-model) commands)))))))

      ((cons (eql msg-textinput-set-value)) ; e.g. '(:textinput-set-value :value "new text")
       (let ((new-val (getf (rest msg) :value)))
         (unless (string= (textinput-model-value new-model) new-val)
           (setf (textinput-model-value new-model) new-val)
           (setf (textinput-model-cursor-pos new-model) (length new-val)) ; Move cursor to end
           (setf value-changed t))))

      ((eql msg msg-textinput-focus)
       (setf (textinput-model-is-focused new-model) t))

      ((eql msg msg-textinput-blur)
       (setf (textinput-model-is-focused new-model) nil))

      ;; msg-textinput-submit is handled internally by :key-press :enter
      ;; but could be sent by a parent if needed.
      ((eql msg msg-textinput-submit)
       (when (textinput-model-on-submit new-model)
         (push (textinput-model-on-submit new-model) commands))))

    (when value-changed
      (when (textinput-model-on-change new-model)
        ;; The on-change message might need the new value
        ;; Assuming on-change is a message template that can be completed or is a simple signal
        (let ((on-change-msg (textinput-model-on-change new-model)))
          (if (listp on-change-msg) ; If it's a list, assume it's a message template like '(:my-change-event :value nil)
              (push (append on-change-msg (list :value (textinput-model-value new-model))) commands)
              (push on-change-msg commands))))) ; If not a list, assume it's a simple message type

    (values new-model commands)))

;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-textinput (model dispatch-fn) ; Removed is-focused arg, using model's slot directly
  "Creates a UI-NODE representation of the textinput.
   MODEL: The current textinput-model instance.
   DISPATCH-FN: A function to call to dispatch messages.
   Returns a UI-NODE."
  (check-type model textinput-model)
  (let ((is-focused (textinput-model-is-focused model)))
    (make-ui-node
     :type :text-input ; A specific type for renderers to handle cursor, etc.
     :props (list :widget-id (textinput-model-id model)
                  :value (textinput-model-value model)
                  :placeholder (textinput-model-placeholder model)
                  :cursor-pos (textinput-model-cursor-pos model)
                  :is-focused is-focused ; Pass focus state to renderer
                  :class (if is-focused
                             "textinput textinput-focused"
                             "textinput")
                  :focusable t
                  ;; Events for focus/blur, key presses are typically handled by parent/platform
                  ;; and translated into messages for this component's update function.
                  ;; However, :click could trigger a focus request.
                  :events (list (list :click
                                      (lambda () (funcall dispatch-fn (list :request-focus :widget-id (textinput-model-id model))))))) ; Use :widget-id
     :children nil))) ; Text inputs are usually leaf nodes in terms of Elm component children
