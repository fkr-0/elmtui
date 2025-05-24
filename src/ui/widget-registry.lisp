(defpackage :elmtui.ui.widget-registry
  (:use :cl)
  (:export :register-widget
   :describe-widget
           :find-widget
   :list-widgets
           :register-widget-group
   :get-widget-props
           :generate-widget-docs
   :with-widget-docs))

(in-package :elmtui.ui.widget-registry)

;; Widget registry
(defvar *widgets* (make-hash-table :test #'eq)
  "Registry of available widgets")

;; Widget groups
(defvar *widget-groups* (make-hash-table :test #'eq)
  "Registry of widget groups")

;; Widget description structure
(defstruct widget-info
  (name nil :type symbol)
  (group nil :type (or null symbol))
  (constructor nil :type (or null symbol function)) 
  (props nil :type list)
  (documentation nil :type (or null string))
  (examples nil :type list))

;; Prop description structure
(defstruct prop-info
  (name nil :type symbol)
  (type nil)
  (required nil :type boolean)
  (default-value nil)
  (documentation nil :type (or null string)))

;; Register a widget
(defun register-widget (name &key group constructor props documentation examples)
  "Register a widget with metadata"
  (let ((widget-props
          (mapcar (lambda (prop-spec)
                    (destructuring-bind (prop-name prop-type required &key default doc) prop-spec
                      (make-prop-info :name prop-name
                                      :type prop-type
                                      :required required
                                      :default-value default
                                      :documentation doc)))
                  props)))
    
    (setf (gethash name *widgets*)
          (make-widget-info :name name
                            :group group
                            :constructor constructor
                            :props widget-props
                            :documentation documentation
                            :examples examples))

    ;; Add to group if specified
    (when group
      (pushnew name (gethash group *widget-groups*)))
    
    name))

;; Register a group of widgets
(defun register-widget-group (group-name &optional description)
  "Register a widget group"
  (setf (gethash group-name *widget-groups*) nil)
  (when description
    (setf (get group-name :description) description))
  group-name)

;; Find a widget by name
(defun find-widget (name)
  "Find a widget by name"
  (gethash name *widgets*))

;; List all registered widgets
(defun list-widgets (&optional group)
  "List all registered widgets, optionally filtered by group"
  (if group
      (mapcar #'find-widget (gethash group *widget-groups*))
      (let ((result nil))
        (maphash (lambda (k v)
                   (declare (ignore k))
                   (push v result)) *widgets*)
        (sort result #'string< :key (lambda (w) (symbol-name (widget-info-name w)))))))

;; Get widget props
(defun get-widget-props (name)
  "Get the props for a widget"
  (let ((widget (find-widget name)))
    (when widget
      (widget-info-props widget))))

;; Generate documentation for a widget
(defun describe-widget (name &optional (stream *standard-output*))
  "Print detailed documentation for a widget"
  (let ((widget (find-widget name)))
    (when widget
      (format stream "~&Widget: ~a~%" (widget-info-name widget))
      (when (widget-info-group widget)
        (format stream "Group: ~a~%" (widget-info-group widget)))
      (when (widget-info-documentation widget)
        (format stream "~%~a~%~%" (widget-info-documentation widget)))
      
      (format stream "~&Props:~%")
      (dolist (prop (widget-info-props widget))
        (format stream "  ~a: ~a~a~@[ (default: ~s)~]~%"
                (prop-info-name prop)
                (prop-info-type prop)
                (if (prop-info-required prop) " (required)" "")
                (prop-info-default-value prop))
        (when (prop-info-documentation prop)
          (format stream "    ~a~%" (prop-info-documentation prop))))
      
      (when (widget-info-examples widget)
        (format stream "~%Examples:~%")
        (dolist (example (widget-info-examples widget))
          (format stream "~%~a~%" example)))
      
      widget)))

;; Generate markdown documentation for all widgets
(defun generate-widget-docs (&optional (stream *standard-output*))
  "Generate markdown documentation for all widgets"
  (format stream "# ElmTUI Widget Reference~%~%")
  
  (format stream "## Widget Groups~%~%")
  (maphash (lambda (group-name widgets)
             (declare (ignore widgets))
             (format stream "- [~a](#~a)~%" 
                     group-name (string-downcase (symbol-name group-name))))
           *widget-groups*)
  
  (maphash (lambda (group-name widgets)
             (declare (ignore widgets))
             (format stream "~%## ~a~%~%" group-name)
             (when (get group-name :description)
               (format stream "~a~%~%" (get group-name :description)))
             
             (dolist (widget-name (gethash group-name *widget-groups*))
               (let ((widget (find-widget widget-name)))
                 (format stream "### ~a~%~%" widget-name)
                 (when (widget-info-documentation widget)
                   (format stream "~a~%~%" (widget-info-documentation widget)))
                 
                 (format stream "#### Props~%~%")
                 (format stream "| Name | Type | Required | Default | Description |~%")
                 (format stream "|------|------|----------|---------|-------------|~%")
                 (dolist (prop (widget-info-props widget))
                   (format stream "| `~a` | `~a` | ~a | ~a | ~a |~%"
                           (prop-info-name prop)
                           (prop-info-type prop)
                           (if (prop-info-required prop) "Yes" "No")
                           (if (prop-info-default-value prop) 
                               (format nil "`~s`" (prop-info-default-value prop))
                               "")
                           (or (prop-info-documentation prop) "")))
                 
                 (when (widget-info-examples widget)
                   (format stream "~%#### Examples~%~%")
                   (dolist (example (widget-info-examples widget))
                     (format stream "```lisp~%~a~%```~%~%" example))))))
           *widget-groups*))

;; Macro for documenting widgets
(defmacro with-widget-docs ((var &key group) &body body)
  "Execute body with VAR bound to widget documentation"
  `(let ((,var ,(if group
                    `(list-widgets ',group)
                    '(list-widgets))))
     ,@body))

;; Example usage:
#|
(register-widget-group :basic "Basic UI components")

(register-widget :button
:group :basic
:constructor 'make-button
:props '((:label string t :doc "Button text")
(:on-click function t :doc "Click handler")
(:disabled boolean nil :default nil :doc "Whether button is disabled")
(:style list nil :doc "Additional styles"))
:documentation "A clickable button component"
:examples '("(button :label \"Click me\" :on-click (lambda () (print \"Clicked!\")))"
"(button :label \"Disabled\" :disabled t)"))

(with-widget-docs (widgets :group :basic)
(dolist (widget widgets)
(describe-widget (widget-info-name widget))))

(with-open-file (out "docs/widgets.md" :direction :output :if-exists :supersede)
(generate-widget-docs out))
|#
