(uiop:define-package :elmtui.ui.api
  (:use :cl )
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.utils #:ensure-keyword)
  (:export
   ;; Component Class & Generics
   #:component #:component-id #:component-type
   #:init #:update #:view #:destroy ;; Core lifecycle
   #:component-children #:component-width #:component-height
   #:resolve-component-node
   #:id-from-path #:get-path
   ;; State Helpers
   #:component-state-path #:get-component-property #:make-state-patch #:component-state-map-path
   ;; Update Macro and its local functions
   #:with-update-patch #:add-patch #:add-command #:get-property
   ;; Note: elmtui.state:update-result is the return type for update methods
   ))
(in-package :elmtui.ui.api)

;;;---------------------------------------------------------------
;;; Base Component Class & Type
;;;---------------------------------------------------------------
(defclass component ()
  ((id :initarg :id :reader component-id
       :documentation "A unique identifier for the component instance. This ID is crucial for namespacing its state within the global app-state."))
  (:documentation "Base class for UI components. Instances primarily serve as typed holders of an ID. All behavioral state is in app-state."))

(defgeneric component-type (component)
  (:documentation "Returns a symbol representing the type of the component, used for namespacing state and potentially for type-specific logic if not covered by method dispatch.")
  (:method ((component component))
    (type-of component)))

;;;---------------------------------------------------------------
;;; State Path and Patch Utilities
;;;---------------------------------------------------------------
(defun component-state-map-path (id-path)
  "Generates a path list for accessing the entire state map of a component.
   `id-path`: The path to the component's state within the :components map (e.g., '(:my-comp)).
   Path: '(:components . id-path)"
  (append '(:components) id-path))

(defun component-state-path (id-path property-key)
  "Generates a path list for accessing/updating a specific component property within app-state.
   `id-path`: The path to the component's state within the :components map.
   `property-key`: The key for the specific property.
   Path: '(:components . id-path . (list property-key))"
  (append '(:components) id-path (list property-key)))

(defun make-state-patch (path value)
  "Creates a single entry for a state patch list: (list path value)."
  (list path value))

;;;---------------------------------------------------------------
;;; State Access
;;;---------------------------------------------------------------
(defun get-component-property (app-state id-path property-key &optional default-value)
  "Retrieves a specific property for a component from its namespaced state in global app-state.
   `app-state`: The global application state.
   `id-path`: The path to the component's state within the :components map.
   `property-key`: The key for the specific property.
   Returns the value or default-value."
  (state-ref app-state (component-state-path id-path property-key) default-value))

;;;---------------------------------------------------------------
;;; `with-update-patch` Macro
;;;---------------------------------------------------------------
(defmacro with-update-patch
    ((app-state-accessor id-path-form ; id-path-form evaluates to the component's id-path list
      &key (patch-var   (gensym "PATCHES-"))
        (command-var (gensym "COMMANDS-")))
     &body body)
  "Execute BODY while collecting UI-state PATCHES and side-effect COMMANDS.
`app-state-accessor`: A form that evaluates to the global application state.
`id-path-form`: A form that evaluates to the component's ID path (list of keywords/symbols relative to :components).

Inside BODY the following *local functions* are available:
  • (add-patch   PATCH)           – push PATCH onto the accumulator
  • (add-command CMD)             – push CMD   onto the accumulator
  • (get-update-result)           – returns current UPDATE-RESULT
  • (get-component-state)         – fetch component's state map using `id-path-form`
  • (get-property KEY &optional DEFAULT) – fetch property from component's state using `id-path-form`

The macro finally returns an UPDATE-RESULT containing all accumulated
patches and commands."
  (let ((patch-sym   patch-var)
        (command-sym command-var))
    `(let ((,patch-sym   nil)
           (,command-sym nil))
       (flet ((add-patch   (patch) (push patch ,patch-sym))
              (add-command (cmd)   (push cmd   ,command-sym))
              (get-update-result ()
                (make-update-result
                 :patches  (nreverse ,patch-sym)
                 :commands (nreverse ,command-sym)))
              (get-component-state ()
                (if ,app-state-accessor
                    (state-ref ,app-state-accessor (component-state-map-path ,id-path-form))
                    (error "No APP-STATE-ACCESSOR supplied to GET-COMPONENT-STATE.")))
              (get-property (property-name &optional default-value)
                (get-component-property ,app-state-accessor ,id-path-form property-name default-value)))
         ,@body
         (make-update-result
          :patches  (nreverse ,patch-sym)
          :commands (nreverse ,command-sym))))))

;;;---------------------------------------------------------------
;;; Component Lifecycle & Behavior Generics
;;;---------------------------------------------------------------
(defgeneric init (component &key id-path &allow-other-keys)
  (:documentation "Initializes a component instance after it has been created.
   This method is responsible for setting up the component's own behavioral state
   in the global application state and for initializing any child components it manages.
   `component`: The component instance (already created by make-instance).
   `id-path`: A list of keywords/symbols representing the unique path to this component's
              state map within the `(:components ...)` section of the app-state.
              Example: '(:my-app :main-layout :submit-button)
   `initargs`: Other initargs passed during component creation.
   Returns (values component patches commands).")
  (:method ((component component)
            &rest initargs              ;; capture *all* remaining args
            &key id-path                ;; explicitly parse :id-path
            &allow-other-keys)          ;; keep generic congruent
    "Default init: sets up its own state based on initargs (excluding :id and :id-path).
     The state is stored at `(append '(:components) id-path)`.
     It does not handle children by default. Specific parent components must override this."
    (unless id-path
      (error "Component ~A init called without :id-path." component))
    (let* ((state-props (copy-list initargs))
           (local-remove-fn (lambda (plist key) (remf plist key) plist)))
      (funcall local-remove-fn state-props :id)
      (funcall local-remove-fn state-props :id-path)
      (funcall local-remove-fn state-props :allow-other-keys)
      ;; Create a patch for the component's main state map if state-props is not empty,
      ;; or to ensure the map exists.
      ;; Individual properties are patched as keys within this map.
      (let ((component-base-path (append '(:components) id-path))
            (patches nil))
        ;; Patch each property into the component's state map
        (loop for (key value) on state-props by #'cddr
              do (push (make-state-patch (append component-base-path (list key)) value) patches))
        ;; If there were any properties, or to ensure the component's map exists,
        ;; we could add a patch for the map itself, but individual key patches are usually sufficient.
        ;; For example, to ensure the map exists:
        ;; (push (make-state-patch component-base-path (if state-props state-props nil)) patches)
        ;; However, merge-patches should create intermediate maps.
        ;; The current loop creates patches like (:components id-path key) value, which is correct.
        (values component (nreverse patches) nil)))))

(defgeneric destroy (component &key id-path)
  (:documentation "Prepares patches and commands to remove a component and its children from the app-state.
   Returns (values patches commands).")
  (:method ((component component) &key id-path)
    (unless id-path (error "Component ~A destroy called without :id-path." component))
    (let ((instance-path (append '(:components) id-path '(:component-instance))) ; Path to the instance pointer
          (state-map-path (append '(:components) id-path))) ; Path to the component's whole state map
      (values (list (make-state-patch instance-path :elmtui-delete-path) ; Command to delete the instance entry
                    (make-state-patch state-map-path :elmtui-delete-path)) ; Command to delete the state map
              nil))))

(defgeneric update (component msg app-state &key id-path)
  (:documentation "Processes a message for a component instance. Returns an `update-result` struct.")
  (:method ((component component) msg app-state &key id-path)
    (declare (ignore msg app-state id-path))
    (make-update-result)))


(defgeneric view (component app-state &key id-path)
  (:documentation "Generates a view representation (DSL spec) for a component instance.")
  (:method ((component component) app-state &key id-path)
    (declare (ignore app-state))
    (list (component-type component) :id (id-from-path id-path))))


(defgeneric resolve-component-node (component app-state style-context &key id-path)
  (:documentation "Resolves a component into a concrete UI node for layout and rendering.")
  (:method ((component component) app-state style-context &key id-path)
    (declare (ignore style-context))
    (view component app-state :id-path id-path)))


(defgeneric component-children (component app-state &key id-path)
  (:documentation "Returns a list of child component *IDs* or *instances*.
   Reads from the :children key in the component's state map in app-state,
   located at (append '(:components) id-path '(:children)).")
  (:method ((component component) app-state &key id-path)
    (get-path app-state (append '(:components) id-path '(:children)))))

(defgeneric component-width (component app-state &key id-path)
  (:documentation "Returns the width of the component.
   Reads from the :width key in the component's state map in app-state,
   located at (append '(:components) id-path '(:width)).")
  (:method ((component component) app-state &key id-path)
    (get-path app-state (append '(:components) id-path '(:width)))))

(defgeneric component-height (component app-state &key id-path)
  (:documentation "Returns the height of the component.
   Reads from the :height key in the component's state map in app-state,
   located at (append '(:components) id-path '(:height)).")
  (:method ((component component) app-state &key id-path)
    (get-path app-state (append '(:components) id-path '(:height)))))

;;;---------------------------------------------------------------
;;; Path and ID Utilities
;;;---------------------------------------------------------------

(defun get-path (state full-path &optional default-value)
  "Retrieves a value from the state at the specified FULL-PATH.
   If the path does not exist, returns DEFAULT-VALUE (nil if not provided).
   This is a wrapper around elmtui.state.api:state-ref."
  (elmtui.state.api:state-ref state full-path default-value))

(defun id-from-path (path)
  "Extracts the last ID from a path list.
   Assumes the last element is the ID keyword or symbol."
  (if (and (listp path) (not (null path)))
      (car (last path))
      (error "Invalid path: ~A. Cannot extract ID." path)))
