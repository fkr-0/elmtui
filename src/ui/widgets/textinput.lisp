;;; Standard text input using the shared component lifecycle and patch protocol.
(uiop:define-package :elmtui.ui.widgets.textinput
  (:use :cl)
  (:import-from :elmtui.ui.api #:component #:component-id #:id-from-path
                #:init #:update #:view #:make-state-patch #:component-state-map-path)
  (:import-from :elmtui.state.api #:make-update-result #:get-path)
  (:export #:textinput #:make-textinput #:msg-textinput-key-press
           #:msg-textinput-set-value #:msg-textinput-submit))
(in-package :elmtui.ui.widgets.textinput)

(defclass textinput (component) ()
  (:documentation "Externally stored text input with a character-index cursor.
Updates return patches and optional on-change/on-submit commands. Stored callback
commands pass through unchanged; on-change runs only when the value changes."))

(defun make-textinput (&key id)
  "Create a text input component; initialize its state through INIT."
  (make-instance 'textinput :id id))

(defparameter msg-textinput-key-press :textinput-key-press)
(defparameter msg-textinput-set-value :textinput-set-value)
(defparameter msg-textinput-submit :textinput-submit)

(defmethod init ((component textinput) &key id-path
                 (initial-value "") (initial-placeholder "") (initial-cursor-pos 0)
                 initial-on-change initial-on-submit initial-disabled
                 (value initial-value) (placeholder initial-placeholder)
                 (cursor-pos initial-cursor-pos) (on-change initial-on-change)
                 (on-submit initial-on-submit) (disabled initial-disabled)
                 &allow-other-keys)
  (check-type value string)
  (check-type cursor-pos integer)
  (let* ((path (component-state-map-path (or id-path (list (component-id component)))))
         (id (id-from-path path)))
    (setf (component-id component) id)
    (values component
            (list (make-state-patch path
                    (list :type (type-of component) :id id :value value
                          :placeholder placeholder :cursor-pos (max 0 (min cursor-pos (length value)))
                          :on-change on-change :on-submit on-submit :disabled (and disabled t))))
            nil)))

(defmethod update ((component textinput) message app-state &key id-path)
  (multiple-value-bind (message state) (elmtui.ui.api:normalize-update-args message app-state)
    (let* ((path (component-state-map-path (or id-path (list (component-id component)))))
           (props (get-path path state))
           (original (get-path '(:value) props ""))
           (value original)
           (cursor (max 0 (min (get-path '(:cursor-pos) props 0) (length value))))
           (old-cursor (get-path '(:cursor-pos) props 0))
           (disabled (get-path '(:disabled) props))
           (patches nil) (commands nil))
      (unless props (return-from update (make-update-result)))
      (labels ((set-value (new)
                 (check-type new string)
                 (setf value new cursor (length new)))
               (submit ()
                 (let ((command (get-path '(:on-submit) props)))
                   (when command (push command commands))))
               (property (key new)
                 (case key
                   (:value (set-value new))
                   (:cursor-pos (check-type new integer)
                                (setf cursor (max 0 (min new (length value)))))
                   ((:placeholder :on-change :on-submit :disabled)
                    (push (make-state-patch (append path (list key)) new) patches)))))
        (cond
          ((and (consp message) (eq (first message) :set-property))
           (property (second message) (third message)))
          ((not disabled)
           (cond
             ((eq message :textinput-submit) (submit))
             ((and (consp message) (eq (first message) :textinput-set-value))
              (let ((new (getf (rest message) :new-value)))
                (unless (equal new value) (set-value new))))
             ((and (consp message) (eq (first message) :textinput-key-press))
              (let* ((data (getf (rest message) :key))
                     (character (getf data :char)) (key (getf data :key-sym)))
                (cond
                  ((characterp character)
                   (setf value (concatenate 'string (subseq value 0 cursor)
                                            (string character) (subseq value cursor)))
                   (incf cursor))
                  ((eq key :backspace)
                   (when (plusp cursor)
                     (setf value (concatenate 'string (subseq value 0 (1- cursor)) (subseq value cursor)))
                     (decf cursor)))
                  ((eq key :delete)
                   (when (< cursor (length value))
                     (setf value (concatenate 'string (subseq value 0 cursor) (subseq value (1+ cursor))))))
                  ((eq key :left) (setf cursor (max 0 (1- cursor))))
                  ((eq key :right) (setf cursor (min (length value) (1+ cursor))))
                  ((eq key :home) (setf cursor 0))
                  ((eq key :end) (setf cursor (length value)))
                  ((eq key :enter) (submit)))))))))
      (unless (string= original value)
        (push (make-state-patch (append path '(:value)) value) patches)
        (let ((command (get-path '(:on-change) props)))
          (when command (push command commands))))
      (unless (= cursor old-cursor)
        (push (make-state-patch (append path '(:cursor-pos)) cursor) patches))
      (make-update-result :patches (nreverse patches) :commands (nreverse commands)))))

(defmethod view ((component textinput) app-state &key id-path children)
  (declare (ignore children))
  (let* ((path (component-state-map-path (or id-path (list (component-id component)))))
         (props (get-path path app-state))
         (value (get-path '(:value) props ""))
         (placeholder (get-path '(:placeholder) props ""))
         (disabled (get-path '(:disabled) props)))
    (list :text :id (component-id component)
          :content (if (zerop (length value)) placeholder value)
          :props (list :id (component-id component) :value value :placeholder placeholder
                       :cursor-pos (get-path '(:cursor-pos) props 0)
                       :disabled disabled :focusable (not disabled)))))
