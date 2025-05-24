(defpackage :elmtui.ui.widgets.panel
  (:use :cl)
  (:export :panel
           :make-panel
           :with-panel
           :defpanel))

(in-package :elmtui.ui.widgets.panel)

;; Import from internal modules
(defvar *view-fn* nil "Dynamic view rendering function")

;; Panel component implementation - functional approach
(defun panel (&key title children border styles (padding 0) (width nil) (height nil))
  "Create a panel component with the given properties.
   TITLE   - (Optional) Title to display at the top of the panel
   CHILDREN - List of child components to render inside the panel
   BORDER  - Border style (:none, :single, :double, :rounded)
   STYLES  - Additional styles to apply to the panel
   PADDING - Padding inside the panel (integer or list of t/r/b/l values)
   WIDTH   - Optional fixed width
   HEIGHT  - Optional fixed height"
  (let ((props (make-panel-props
                :title title
                :border (or border :single)
                :styles (or styles '())
                :padding padding
                :width width
                :height height)))
    (funcall *view-fn* :panel props children)))

;; Structure to hold panel properties
(defstruct panel-props
  (title nil)
  (border :single :type (member :none :single :double :rounded))
  (styles '() :type list)
  (padding 0)
  (width nil)
  (height nil))

;; Constructor function
(defun make-panel (&key title children border styles (padding 0) (width nil) (height nil))
  "Create a panel component"
  (panel :title title
         :children children
         :border border
         :styles styles
         :padding padding
         :width width
         :height height))

;; Helper macro for creating panels
(defmacro with-panel ((var &rest panel-args) &body body)
  "Create a panel and bind the children to VAR"
  `(let ((,var (list ,@body)))
     (panel :children ,var ,@panel-args)))

;; Define a reusable panel component
(defmacro defpanel (name args &body body)
  "Define a reusable panel component"
  `(defun ,name ,args
     (panel ,@body)))

;; Example usage:
#|
(defpanel header-panel (title &key styles)
  :title title
  :border :rounded
  :styles (append '(:foreground :blue :background :white) styles)
  :children (list (text "Panel content")))

(with-panel (content :title "My Panel" :border :double)
  (text "Line 1")
  (text "Line 2")
  (button :label "Click me"))
|#
