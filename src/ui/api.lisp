(uiop:define-package :elmtui.ui.api
  (:use :cl #:log4cl)
  (:import-from :elmtui.state.api #:state-ref #:make-update-result)
  (:import-from :elmtui.utils #:ensure-keyword #:get-path)
  (:export
   ;; Component Class & Generics
   #:initialize-components-from-dsl
   #:instantiate-component-from-dsl
   #:component #:component-id #:component-type
   #:init #:update #:view #:destroy ;; Core lifecycle
   #:component-children #:component-width #:component-height
   #:resolve-component-node
   #:layout-node
   #:id-from-path #:get-path
   ;; State Helpers
   #:+component-state-root+
   #:component-state-path #:get-component-property #:make-state-patch #:component-state-map-path
   ;; Update Macro and its local functions
   #:with-update-patch #:add-patch #:add-command #:get-property
   #:normalize-update-args
   ;; Note: elmtui.state:update-result is the return type for update methods
   #:id ; Export the new generic function
   #:make-update-result
   ))
(in-package :elmtui.ui.api)
;;; ===================================================================
;;; INTERFACE SECTION - Public API declarations
;;; ===================================================================

;;;---------------------------------------------------------------
;;; Base Component Class & Type
;;;---------------------------------------------------------------
(defclass component ()
  ((id
    :initarg :id
    :accessor component-id
    :type list ; Path list
    :documentation
    "A unique identifier for the component instance.
       Arguments:
         ID -- (list) Path list uniquely identifying this component instance.
       Returns:
         (list) The component's ID.
       Example:
         (component-id my-component) ; => '(:my-app :main-layout :submit-button)
       (list) => list (pure, no side-effects)
       Side-effects: none (must be pure)"))
  (:documentation
   "Base class for UI components.
    Arguments:
      ID -- (list) Path list uniquely identifying this component instance.
    Returns:
      COMPONENT instance.
    Example:
      (make-instance 'component :id '(:my-app :main-layout :submit-button))
    (list) => component (pure, no side-effects)
    Side-effects: none (must be pure)"))

;; (declaim (ftype (function (component) t) id))
(defgeneric id (object)
  (:documentation  "Returns the ID of a component or UI node.

   Arguments:
     OBJECT -- (component or ui-node) The object to query.

   Returns:
     (list) The ID path of the object.

   Example:
     (id my-component) ; => '(:my-app :main-layout :submit-button)

   (component|ui-node) => list (pure, no side-effects)
   Side-effects: none (must be pure)
  ")
  (:method ((component component))
    ;; Return the ID slot for a component instance
    (component-id component)))

;; (declaim (ftype (function (component &key (:id-path list) (:dsl list) &allow-other-keys) list) init))
;;; ===================================================================
;;; IMPLEMENTATION SECTION
;;; ===================================================================
;; (defmethod init ((component component) &key id-path dsl &allow-other-keys)
;;   "Default init for all components: stores DSL form in state patch."
;;   (declare (type component component)
;;            (type list id-path dsl))
;;   (check-type component component)
;;   (check-type id-path list)
;;   (check-type dsl list)
;;   (list (make-state-patch (append (component-state-map-path id-path) (list :dsl))
;;                           dsl)))


(defgeneric component-type (component)
  (:documentation
   "Returns a symbol representing the type of the component.

   Arguments:
     COMPONENT -- (component) The component instance.

   Returns:
     (symbol) The type of the component, used for namespacing state and type-specific logic.

   Example:
     (component-type my-component) ; => :button

   (component) => symbol (pure, no side-effects)
   Side-effects: none (must be pure)
  "
   )
  (:method ((component component))
    (declare (type component component))
    (check-type component component)
    ;; Return the class type symbol for the component
    (type-of component)))

;;;---------------------------------------------------------------
;;; State Path and Patch Utilities
;;;---------------------------------------------------------------
(defparameter +component-state-root+ '(:components)
  "Canonical root path for component state in app-state.")

(declaim (ftype (function (list) list) component-state-map-path))
(defun component-state-map-path (id-path)
  "Generates a path list for accessing the entire state map of a component.
   `id-path`: The path to the component's state within the :components map (e.g., '(:my-comp)).
   Path: '(:components . id-path)

   Arguments:
    `id-path`: A list of keywords/symbols representing the unique path to this component's state map within the `(:components ...)` section of the app-state.
   Returns:
    A list representing the path to the component's state map, starting with '(:components . id-path).

   Example:
    (component-state-map-path '(:my-app :main-layout :submit-button))
    => '(:components :my-app :main-layout :submit-button"
  (declare (type list id-path))
  (check-type id-path list)
  (if (and id-path (eql (car id-path) (first +component-state-root+)))
      id-path
      (append +component-state-root+ id-path)))

(declaim (ftype (function (list keyword) list) component-state-path))
(defun component-state-path (id-path property-key)
  "Generates a path list for accessing/updating a specific component property within app-state.

   Arguments:
     ID-PATH      -- (list) Path to the component's state within the :components map.
     PROPERTY-KEY -- (keyword) The key for the specific property.

   Returns:
     (list) Path to the component's property, starting with '(:components . id-path) and ending with the property-key.

   Example:
     (component-state-path '(:my-app :main-layout :submit-button) :label)
     ;; => '(:components :my-app :main-layout :submit-button :label)

   (list, keyword) => list (pure, no side-effects)
   Side-effects: none (must be pure)
  "
  (declare (type list id-path)
           (type keyword property-key))
  (check-type id-path list)
  (check-type property-key keyword)
  ;; Append the property key to the component's state map path
  (append (component-state-map-path id-path) (list property-key)))

(declaim (ftype (function (list t) list) make-state-patch))
(defun make-state-patch (path value)
  "Creates a single entry for a state patch list: (list path value)."
  (declare (type list path)
           (type t value))
  (check-type path list)
  (list path value))

;;;---------------------------------------------------------------
;;; State Access
;;;---------------------------------------------------------------
(declaim (ftype (function (t list keyword &optional t) t) get-component-property))
(defun get-component-property (app-state id-path property-key &optional default-value)
  "Retrieves a specific property for a component from its namespaced state in global app-state.
   `app-state`: The global application state.
   `id-path`: The path to the component's state within the :components map.
   `property-key`: The key for the specific property.
   Returns the value or default-value."
  (declare (type t app-state) ; Assuming app-state can be any type for now
           (type list id-path)
           (type keyword property-key)
           (type t default-value))
  (check-type id-path list)
  (check-type property-key keyword)
  (state-ref app-state (component-state-path id-path property-key) default-value))

;;;---------------------------------------------------------------
;;; `with-update-patch` Macro
;;;---------------------------------------------------------------
;; Declaiming ftype for a macro itself isn't standard, but we can for its expansion or local functions if needed.
;; For now, focusing on runtime types.
(defmacro with-update-patch
    ((app-state-accessor id-path-form ; id-path-form evaluates to the component's id-path list
      &key (patch-var   (gensym "PATCHES-"))
        (command-var (gensym "COMMANDS-")))
     &body body)
  ;; ... (macro body as before, ensuring internal calls are type-safe if possible, though harder for macros)
  ;; Type checking for app-state-accessor and id-path-form would happen at runtime when the macro-expanded code runs.
  (let ((patch-sym   patch-var)
        (command-sym command-var)
        (app-state-sym (gensym "APP-STATE-"))
        (id-path-sym (gensym "ID-PATH-")))
    `(let ((,patch-sym   nil)
           (,command-sym nil)
           (,app-state-sym ,app-state-accessor)
           (,id-path-sym ,id-path-form))
       (declare (type list ,patch-sym ,command-sym ,id-path-sym)
                (type t ,app-state-sym)) ; Or a more specific app-state type
       (check-type ,id-path-sym list)
       ;; Add check-type for app-state-sym if its type is known and constrained
       (flet ((add-patch (patch)
                (declare (type list patch)) (check-type patch list) (push patch ,patch-sym))
              (add-command (cmd)
                (declare (type t cmd)) (push cmd ,command-sym))
              (get-update-result ()
                (make-update-result
                 :patches  (nreverse ,patch-sym)
                 :commands (nreverse ,command-sym)))
              (get-component-state ()
                (unless ,app-state-sym
                  (error "No APP-STATE-ACCESSOR supplied to GET-COMPONENT-STATE."))
                (state-ref ,app-state-sym (component-state-map-path ,id-path-sym)))
              (get-property (property-name &optional default-value)
                (declare (type keyword property-name) (type t default-value))
                (check-type property-name keyword)
                (get-component-property ,app-state-sym ,id-path-sym property-name default-value)))
         ,@body
         (make-update-result
          :patches  (nreverse ,patch-sym)
          :commands (nreverse ,command-sym))))))
;;; ---------------------------------------------------------------------------
;;; Helper function to initialize components from DSL
;;; ---------------------------------------------------------------------------
(defgeneric instantiate-component-from-dsl (dsl id-path))

;; (defun initialize-components-from-dsl (dsl)
;;   "Recursively traverses a component DSL, instantiates components,
;;    and returns the accumulated patches and commands."
;;   (let ((patches nil)
;;         (commands nil))
;;     (labels ((process-node (node parent-id-path)
;;                (when (and (consp node) (keywordp (car node)))
;;                  (destructuring-bind (component-type &rest component-props) node
;;                    (declare (ignore component-type))
;;                    (let ((component-id (getf component-props :id)))
;;                      (when component-id
;;                        (let* ((current-id-path (append parent-id-path (list component-id)))
;;                               (current-id-path (if (eql (car current-id-path) :components)

;;                                                    current-id-path
;;                                                    (append '(:components) current-id-path)))
;;                               (component-instance (instantiate-component-from-dsl node current-id-path)));current-id-path)))
;;                          (when component-instance
;;                            (multiple-value-bind (instance init-patches init-commands)
;;                                (apply #'init component-instance :id-path current-id-path component-props)
;;                              (declare (ignore instance))
;;                              (setf patches (nconc patches init-patches))
;;                              (setf commands (nconc commands init-commands))))
;;                          (dolist (child (getf component-props :children))
;;                            (process-node child current-id-path)))))))))
;;       (process-node dsl '()))
;;     (log-info "Initialized components from DSL: ~A: " dsl)
;;     (log-info "patches: ~A: " patches)
;;     (values patches commands)))

(defun initialize-components-from-dsl (dsl)
  "Recursively traverses a component DSL, instantiates components,
   and returns the accumulated patches and commands."
  (let ((patches nil)
        (commands nil))
    (labels ((process-node (node parent-path)
               (when (and (consp node) (keywordp (car node)))
                 (destructuring-bind (component-type &rest component-props) node
                   (declare (ignore component-type))
                   (let ((component-id (getf component-props :id)))
                     (when component-id
                       (let* ((current-path (append parent-path (list component-id)))
                              (full-id-path (cons :components current-path))
                              (component-instance (instantiate-component-from-dsl node full-id-path)))
                         (when component-instance
                           (multiple-value-bind (instance init-patches init-commands)
                               (apply #'init component-instance :id-path full-id-path component-props)
                             (declare (ignore instance))
                             (setf patches (nconc patches init-patches))
                             (setf commands (nconc commands init-commands))))
                         ;; Recurse into children
                         (flet ((process-children (child-list)
                                  (when child-list
                                    (if (and (listp child-list) (keywordp (first child-list)))
                                        (process-node child-list current-path)
                                        (dolist (child child-list)
                                          (process-node child current-path))))))
                           (process-children (getf component-props :children))
                           (process-children (getf component-props :initial-child-spec))))))))))
      (process-node dsl '())
      (values patches commands))))

;; (defun initialize-components-from-dsl (dsl)
;;   "Recursively traverses a component DSL, instantiates components,
;;    and returns the accumulated patches and commands."
;;   (let ((patches nil)
;;         (commands nil))
;;     (labels ((process-node (node parent-path)
;;                (when (and (consp node) (keywordp (car node)))
;;                  (destructuring-bind (component-type &rest component-props) node
;;                    (declare (ignore component-type))
;;                    (let ((component-id (getf component-props :id)))
;;                      (when component-id
;;                        (let* ((current-path (append parent-path (list component-id)))
;;                               (full-id-path (cons :components current-path))
;;                               (component-instance (instantiate-component-from-dsl node full-id-path)))
;;                          (when component-instance
;;                            (multiple-value-bind (instance init-patches init-commands)
;;                                (apply #'init component-instance :id-path full-id-path component-props)
;;                              (declare (ignore instance))
;;                              (setf patches (nconc patches init-patches))
;;                              (setf commands (nconc commands init-commands))))
;;                          ;; Recurse into children
;;                          (let ((children (getf component-props :children))
;;                                (child-spec (getf component-props :initial-child-spec)))
;;                            (when children
;;                              (dolist (child children)
;;                                (process-node child current-path)))
;;                            (when child-spec
;;                              (process-node child-spec current-path))))))))))
;;       (process-node dsl '()))
;;     (values patches commands)))


;;;---------------------------------------------------------------
;;; Component Lifecycle & Behavior Generics
;;;---------------------------------------------------------------
;; (declaim (ftype (function (component &key (:id-path list) (:dsl list) &allow-other-keys) (values component list list)) init))
(defgeneric init (component &key id-path dsl &allow-other-keys)
  (:documentation "Initializes a component instance after it has been created.
   This method is responsible for setting up the component's own behavioral state
   in the global application state and for initializing any child components it manages.
   `component`: The component instance (already created by make-instance).
   `id-path`: A list of keywords/symbols representing the unique path to this component's
              state map within the `(:components ...)` section of the app-state.
              Example: '(:my-app :main-layout :submit-button)
   `initargs`: Other initargs passed during component creation.
   Returns (values component patches commands).

   Example usage:
   (init my-component :id-path '(:my-app :main-layout :submit-button)
         :dsl '(:button :label \"Submit\" :on-click #'submit-handler))")
  (:method ((component component)
            &rest initargs              ;; capture *all* remaining args
            &key id-path dsl                ;; explicitly parse :id-path
            &allow-other-keys)          ;; keep generic congruent
    "Default init: sets up its own state based on initargs (excluding :id and :id-path).
     The state is stored at `(append '(:components) id-path)`.
     It does not handle children by default. Specific parent components must override this."
    (declare (type component component)
             (type list id-path initargs))
    (check-type component component)
    (unless id-path
      (error "Component ~A init called without :id-path." component))
    (check-type id-path list)
    (check-type dsl list)
    (log-debug "Component ~A init called with id-path: ~A and dsl: ~A"
               (component-id component) id-path dsl)
    (let* ((state-props (copy-list initargs))
           (local-remove-fn (lambda (plist key) (remf plist key) plist)))
      ;; Ensure keys are keywords for remf
      ;; (format t "~&Component ~A init with id-path: ~A and dsl: ~A~%"
      ;;         component id-path dsl)
      (funcall local-remove-fn state-props :id)
      (funcall local-remove-fn state-props :id-path)
      (funcall local-remove-fn state-props :allow-other-keys)
      (log-info "State properties after cleanup: ~A~%" state-props)

      (let* ((component-base-path (component-state-map-path id-path))
             (patches (list (make-state-patch
                             (append
                              component-base-path (list :dsl))
                             dsl)))
             (commands nil))
        (log-debug "Component ~A init patches: ~A" component patches)
        (log-debug "Component ~A init state-props: ~A" component state-props)
        (loop for (key value) on state-props by #'cddr
              do (push (make-state-patch
                        (append component-base-path
                                (list (ensure-keyword key))) value)
                       patches))
        (values component (nreverse patches) (nreverse commands))))))

;; (declaim (ftype (function (component &key (:id-path list)) (values list list)) destroy))
(defgeneric destroy (component &key id-path)
  (:documentation "Prepares patches and commands to remove a component and its children from the app-state.
   Returns (values patches commands).")
  (:method ((component component) &key id-path)
    (declare (type component component)
             (type list id-path))
    (check-type component component)
    (unless id-path (error "Component ~A destroy called without :id-path." component))
    (check-type id-path list)
    (let ((instance-path (append (component-state-map-path id-path) (list :component-instance))) ; Path to the instance pointer
          (state-map-path (component-state-map-path id-path))) ; Path to the component's whole state map
      (values (list (make-state-patch instance-path :elmtui-delete-path)
                    (make-state-patch state-map-path :elmtui-delete-path))
              nil))))

;; (declaim (ftype (function (component t t &key (:id-path list)) elmtui.state.api:update-result) update))
(defgeneric update (component msg app-state &key id-path)
  (:documentation "Processes a message for a component instance. Returns an `update-result` struct.")
  (:method ((component component) msg app-state &key id-path)
    (declare (ignore msg app-state id-path))
    ;;          (type t msg app-state) ; app-state type can be more specific
    ;;          (type list id-path))
    ;; (check-type component component)
    ;; (check-type id-path list)

    (make-update-result)))

(defun normalize-update-args (msg app-state)
  "Normalize UPDATE arguments so callers may pass either (msg app-state) or (app-state msg)."
  (if (and (cl-state.core:application-state-p msg)
        (not (cl-state.core:application-state-p app-state)))
    (values app-state msg)
    (values msg app-state)))


(defmethod view ((component hash-table) app-state &key id-path)
  "Fallback view method for raw hash-tables found in state, treating them as raw DSL."
  (declare (ignore app-state id-path))
  (gethash :dsl component))
;; (declaim (ftype (function (component t &key (:id-path list)) list) view))
(defgeneric view (component app-state &key id-path &allow-other-keys)
  (:documentation "Generates a view representation (DSL spec) for a component instance.")
  (:method ((component component) app-state &key id-path children)
    (declare (type component component)
             (type t app-state) ; app-state type can be more specific
             (type list id-path))
    (log-info "Generic BASEMETHOD:view for component ~A with id-path: ~A"
              component id-path)
    (check-type component component)
    (check-type id-path list)
    (list          :container
                   :id (intern (format nil "~A-CONTAINER" (id-from-path id-path)) :keyword)

                   ;;:type (component-type component)
                   :children children)))


(defmethod view ((component null) app-state &key id-path)
  "Fallback view method for when a component is not found in the state."
  (declare (ignore app-state))
  (warn "Component with id-path ~A not found in state, rendering nil." id-path)
  nil)
;; (declaim (ftype (function (component t t &key (:id-path list)) t) resolve-component-node))
(defgeneric resolve-component-node (component app-state style-context &key id-path)
  (:documentation "Resolves a component into a concrete UI node for layout and rendering.")
  (:method ((component component) app-state style-context &key id-path)
    (declare (type component component)
             (type t app-state style-context) ; More specific types later
             (type list id-path))
    (check-type component component)
    (check-type id-path list)
    (view component app-state :id-path id-path)))


;; (declaim (ftype (function (component t &key (:id-path list)) t) component-children))
(defgeneric component-children (component app-state &key id-path)
  (:documentation "Returns a list of child component *IDs* or *instances*.
   Reads from the :children key in the component's state map in app-state,
   located at (append '(:components) id-path '(:children)).")
  (:method ((component component) app-state &key id-path)
    (declare (type component component)
             (type t app-state)
             (type list id-path))
    (check-type component component)
    (check-type id-path list)
    (get-path (append (component-state-map-path id-path) '(:children)) app-state)))

;; (declaim (ftype (function (component t &key (:id-path list)) t) component-width))
(defgeneric component-width (component app-state &key id-path)
  (:documentation "Returns the width of the component.
   Reads from the :width key in the component's state map in app-state,
   located at (append '(:components) id-path '(:width)).")
  (:method ((component component) app-state &key id-path)
    (declare (type component component)
             (type t app-state)
             (type list id-path))
    (check-type component component)
    (check-type id-path list)
    (get-path (append (component-state-map-path id-path) '(:width)) app-state )))

;; (declaim (ftype (function (component t &key (:id-path list)) t) component-height))
(defgeneric component-height (component app-state &key id-path)
  (:documentation "Returns the height of the component.
   Reads from the :height key in the component's state map in app-state,
   located at (append '(:components) id-path '(:height)).")
  (:method ((component component) app-state &key id-path)
    (declare (type component component)
             (type t app-state)
             (type list id-path))
    (check-type component component)
    (check-type id-path list)
    (get-path (append (component-state-map-path id-path) '(:height)) app-state )))

;;;---------------------------------------------------------------
;;; Path and ID Utilities
;;;---------------------------------------------------------------

;; (declaim (ftype (function (t list &optional t) t) get-path))
;; (defun get-path (full-path state  &optional default-value)
;;   "Retrieves a value from the state at the specified FULL-PATH.
;;    If the path does not exist, returns DEFAULT-VALUE (nil if not provided).
;;    Handles both application-state objects and raw data structures."
;;   (declare (type t state default-value) ; state can be any app-state type
;;            (type list full-path))
;;   (check-type full-path list)
;;   (cond
;;     ;; If state is an application-state object, get its raw data first
;;     ;; ((typep state 'elmtui.state.api:application-state)
;;     ;;  (elmtui.state.api:get-path-enhanced full-path state default-value))
;;     ;; ;; If state has a components-store slot (test case)
;;     ;; ((and (typep state 'standard-object)
;;     ;;       (slot-exists-p state 'components-store))
;;     ;;  ;; Handle test-app-state structure
;;     ;;  (case (first full-path)
;;     ;;    (:components
;;     ;;     (let ((components (slot-value state 'components-store)))
;;     ;;       (if (rest full-path)
;;     ;;           (elmtui.state:get-path (rest full-path) components default-value)
;;     ;;           (or components default-value))))
;;     ;;    (t (elmtui.state.api:state-ref state (first full-path) default-value))))
;;     ;; If state is raw data (list/plist), use the raw get-path function
;;     ((listp state)
;;      (elmtui.state:get-path full-path state default-value))
;;     ;; Fallback
;;     (t default-value)))

(declaim (ftype (function (list) (or keyword symbol)) id-from-path))
(defun id-from-path (path)
  "Extracts the last ID from a path list.
   Assumes the last element is the ID keyword or symbol."
  (declare (type list path))
  (check-type path list)
  (if (and (listp path) (not (null path)))
      (the (or keyword symbol) (car (last path))) ; Added 'the' for more specific return type
      (error "Invalid path: ~A. Cannot extract ID." path)))
