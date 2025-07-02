;;;; Minimal component initialization tests
;;;; Tests basic component setup functionality

(uiop:define-package :elmtui.tests.component-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app
                #:defapplication)
  (:import-from :elmtui.ui.api
                #:component)
  (:import-from :elmtui.ui.defcomponent
                #:defcomponent
                #:defcomponent-slots)
  (:import-from :elmtui.state.api
                #:make-update-result
                #:state-ref)
  (:import-from :elmtui.ui.api
                #:id-from-path
                #:component-id)
  (:import-from :elmtui.ui.widgets.viewport #:viewport-rect)
  (:import-from :elmtui.ui.widgets.viewport #:viewport)
  (:import-from :elmtui.ui.widgets.layout #:layout)
  (:import-from :elmtui.ui.widgets.label #:label)
  (:export #:component-init-tests))

(in-package :elmtui.tests.component-init)

(def-suite component-init-tests

  :in elmtui.tests:elmtui-test
  :description "Basic tests for component initialization")

(in-suite component-init-tests)

;; Basic smoke test
(test component-class-exists
  "Test that component class exists"
  (is (find-class 'component nil)))


;; (def-suite component-init-tests
;;   :description "Tests for component initialization using defcomponent and the new API.")
;; (in-suite component-init-tests)

;;;------------------------------------------------------------------------------------
;;; Test Application and State Setup
;;;------------------------------------------------------------------------------------

(defclass test-app-state ()
  ((components :initform nil :accessor components-store ; A plist: (:comp1 state1 :comp2 state2)
               :documentation "A plist storing component states, keyed by component ID.")))

(defun my-app-update (state msg) ; Changed from &key id-path to standard update signature
  "Default update function for the test application."
  (declare (ignore msg state))
  ;; For testing, we just return the state unchanged and no commands
  (elmtui.state.api:make-update-result))

(defun my-app-view (state) ; Changed from &key id-path
  "Default view function for the test application."
  (declare (ignore state))
  ;; For testing, we return a simple view
  ;; This should be the DSL for the child of the root viewport
  `(:type elmtui.ui.widgets.label:label ; Use the actual component type
    :id :test-label
    :text "Hello, Component Init Tests!"))

(defun my-app-command-processor (command app-state app-instance)
  "Default command processor for the test application."
  (declare (ignore command app-state app-instance))
  nil)

(defapplication test-application
  :root-viewport-id :main-viewport ; This ID is for the root-viewport component itself
  :root-component-dsl `(elmtui.ui.widgets.label:label :id :test-label :text "Initial Label") ; DSL for the child of root-viewport
  :initial-state-plist `((:components . nil) (:app-specific-data "test"))
  :update-fn 'my-app-update ; Pass as symbol
  :view-fn 'my-app-view     ; Pass as symbol
  :command-processor-fn 'my-app-command-processor)

;; (defmethod elmtui.ui.api:init ((app test-application)) ...) ; This is for component init, not app init.
;; App initialization is handled by defapplication's generated INITIALIZE-APP-STATE-*

(defmethod elmtui.state.api:state-ref ((s test-app-state) key &optional default)
  (case key
    (:components (components-store s))
    ;; Add other top-level state keys if your test-app-state has them
    (t (getf (list) key default)))) ; Simplified: assume other keys might be in a different part of state or handled by get-path

(defmethod elmtui.state.api:get-state ((s test-app-state) key)
  (case key
    (:components (components-store s))
    ;; Add other top-level state keys if your test-app-state has them
    (t nil)))

;; Helper to get component state from the app's component store (which is a plist in test-app-state)
(defun get-component-state (app-state-instance component-id)
  (getf (components-store app-state-instance) component-id))

;; Helper to apply patches to the app state (test-app-state instance)
(defun apply-patches (app-state-instance patches)
  (dolist (patch patches)
    (let ((path (first patch))
          (value-plist (second patch)))
      (if (and (listp path) (= 2 (length path)) (eq (first path) :components) (keywordp (second path)))
          (let* ((component-id (second path))
                 (current-components-plist (components-store app-state-instance)))
            (setf (getf current-components-plist component-id) value-plist)
            (setf (components-store app-state-instance) current-components-plist))
          (warn "Apply-patches: Unhandled patch structure for path: ~S in test helper" path)))))

;;;------------------------------------------------------------------------------------
;;; Define some test components using defcomponent
;;;------------------------------------------------------------------------------------

(defcomponent test-simple-component (elmtui.ui.api:component)
  (:state
   (type :test-simple-component)
   (id nil)
   (text "Default Text" :accessor test-simple-component-text :initarg :text)
   (count 0 :accessor test-simple-component-count :initarg :count))
  (:view (local-state-map app-state id-path)
         (declare (ignore local-state-map app-state id-path))
         `(:test-simple-component)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defcomponent test-parent-component (elmtui.ui.widgets.layout:layout)
    (:state
     (title "Default Title" :initarg :title)
     (child-ids nil)
     (child-refs nil)
     (child-components nil))))
;; Override init for test-parent-component to handle children
(defmethod elmtui.ui.api:init ((component test-parent-component) &key id-path initial-title initial-child-specs &allow-other-keys)
  (let (;; (component-id (elmtui.ui.api:id-from-path id-path))
                                        ; Use api's id-from-path
        (child-patch-lists nil) ; Store lists of patches from children
        (child-instances nil))
    (dolist (child-spec initial-child-specs)
      (destructuring-bind (child-type child-id &rest child-initargs) child-spec
        (let* ((child-instance (make-instance child-type :id child-id))
               (child-id-path `(:components ,child-id))
               ;; Call the correct init generic
               (init-values (multiple-value-list (apply #'elmtui.ui.api:init child-instance :id-path child-id-path child-initargs))))
          (push (second init-values) child-patch-lists) ; (second init-values) is the list of patches from child
          (push child-instance child-instances))))

    (multiple-value-bind (self-instance self-patches self-commands)
        (call-next-method component :id-path id-path
                                    :title initial-title
                                    ;; Other initargs for test-parent-component's own defcomponent-slots
                                    ;; are passed via &allow-other-keys and handled by defcomponent's generated init.
                                    )
      ;; self-patches is a list containing one patch: (list path value-plist)
      (let ((parent-patch (first self-patches))) ; parent-patch is (list path value-plist)
        (when parent-patch
          ;; Modify the value-plist part of the parent's patch
          (setf (getf (second parent-patch) :child-ids) (mapcar #'elmtui.ui.api:component-id child-instances))
          (setf (getf (second parent-patch) :child-refs) (reverse child-instances)))

        (values self-instance
                ;; Flatten child_patch_lists and append self_patches
                (append (apply #'append (reverse child-patch-lists)) self-patches)
                self-commands)))))

;;;------------------------------------------------------------------------------------
;;; Tests
;;;------------------------------------------------------------------------------------

(test init-simple-component
  (let* (;; Application instance is not directly used here for init,
         ;; but we need an app-state instance.
         ;; The generated init-fn from defapplication would create the initial state.
         ;; For isolated component testing, we can manually create test-app-state.
         (app-state (make-instance 'test-app-state))
         (comp-id :my-simple-comp)
         (comp-instance (make-instance 'test-simple-component :id comp-id))
         (id-path `(:components ,comp-id)))

    ;; Test with default initforms
    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init comp-instance :id-path id-path)
      (is (eq comp-instance instance))
      (is-true patches)
      (is-false commands)
      (apply-patches app-state patches)
      (let ((state (get-component-state app-state comp-id)))
        (is (listp state))
        (is (eq :test-simple-component (getf state :type)))
        (is (eq comp-id (getf state :id)))
        (is (string= "Default Text" (getf state :text)))
        (is (= 0 (getf state :count)))))

    ;; Test with provided initargs
    (setf (components-store app-state) nil) ; Reset component store
    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init comp-instance :id-path id-path :initial-text "Hello" :initial-count 42)
      (is (eq comp-instance instance))
      (apply-patches app-state patches)
      (let ((state (get-component-state app-state comp-id)))
        (is (listp state))
        (is (string= "Hello" (getf state :text)))
        (is (= 42 (getf state :count)))))))

(test init-parent-component-no-children
  (let* ((app-state (make-instance 'test-app-state))
         (comp-id :my-parent-comp)
         (comp-instance (make-instance 'test-parent-component :id comp-id))
         (id-path `(:components ,comp-id)))

    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init comp-instance :id-path id-path :initial-title "Test Parent")
      (is (eq comp-instance instance))
      (is-true patches)
      (is-false commands)
      (apply-patches app-state patches)
      (let ((state (get-component-state app-state comp-id)))
        (is (listp state))
        (is (eq :test-parent-component (getf state :type)))
        (is (eq comp-id (getf state :id)))
        (is (string= "Test Parent" (getf state :title)))
        (is (null (getf state :child-components)))
        (is-false (getf state :child-ids))
        (is-false (getf state :child-refs))
        ))))

(test init-parent-component-with-children
  (let* ((app-state (make-instance 'test-app-state))
         (parent-id :main-parent)
         (child1-id :child1)
         (child2-id :child2)
         (parent-instance (make-instance 'test-parent-component :id parent-id))
         (id-path `(:components ,parent-id))
         (child-specs `((test-simple-component ,child1-id :initial-text "Child One Text")
                        (test-simple-component ,child2-id :initial-count 99))))
    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init parent-instance :id-path id-path
                                            :initial-title "Parent With Children"
                                            :initial-child-specs child-specs)
      (is (eq parent-instance instance))
      (is-true patches)
      (is-false commands)
      (apply-patches app-state patches)

      ;; Check parent state
      (let ((parent-comp-state (get-component-state app-state parent-id)))
        (is (listp parent-comp-state))
        (is (eq :test-parent-component (getf parent-comp-state :type)))
        (is (string= "Parent With Children" (getf parent-comp-state :title)))
        (let ((child-ids (getf parent-comp-state :child-ids))
              (child-refs (getf parent-comp-state :child-refs)))
          (is (listp child-ids))
          (is (= 2 (length child-ids)))
          (is (member child1-id child-ids))
          (is (member child2-id child-ids))
          (is (listp child-refs))
          (is (= 2 (length child-refs)))
          (is (typep (find child1-id child-refs :key #'elmtui.ui.api:component-id) 'test-simple-component))
          (is (typep (find child2-id child-refs :key #'elmtui.ui.api:component-id) 'test-simple-component))))

      ;; Check child1 state
      (let ((child1-state (get-component-state app-state child1-id)))
        (is (listp child1-state))
        (is (eq :test-simple-component (getf child1-state :type)))
        (is (string= "Child One Text" (getf child1-state :text)))
        (is (= 0 (getf child1-state :count)))) ; Default count

      ;; Check child2 state
      (let ((child2-state (get-component-state app-state child2-id)))
        (is (listp child2-state))
        (is (eq :test-simple-component (getf child2-state :type)))
        (is (string= "Default Text" (getf child2-state :text))) ; Default text
        (is (= 99 (getf child2-state :count)))))))

(test defcomponent-accessors
  (let* ((the-app-state (make-instance 'test-app-state))
         (comp-id :accessor-test-comp)
         (comp-instance (make-instance 'test-simple-component :id comp-id)))

    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init comp-instance :id-path `(:components ,comp-id) :initial-text "Accessor Test" :initial-count 77)
      (declare (ignore instance commands))
      (apply-patches the-app-state patches))

    (is (string= "Accessor Test" (test-simple-component-text the-app-state comp-instance)))
    (is (= 77 (test-simple-component-count the-app-state comp-instance)))))

;; Example of how a standard widget like label-component would be tested
;; (assuming it's defined with defcomponent or compatible)
;; For :initial-text to be handled by test-label-component's defcomponent-generated init,
;; it must also have a 'text' slot.
;; (defcomponent test-label-component ((label)) ; Use label-component as superclass
;;   )
;; (defmethod elmtui.ui.api:init ((component test-label-component) &key id-path initial-title initial-child-specs &allow-other-keys)
;;   )

(defclass my-button (component)
  ()  ;; No state slots!
  (:documentation "Button component. State stored in app-state."))

;; State stored at: (:components :my-button-id :text) in app-state
(defmethod init ((component my-button) &key id-path initial-text &allow-other-keys)
  (values component
          ;; Patches: list of (path new-value) pairs
          (list (elmtui.ui.api:make-state-patch `(:components ,(id-from-path id-path) :text)
                                                (or initial-text "Click Me")))
          nil)) ; No commands

(defmethod update ((component my-button) app-state message &key id-path)
  (case (car message)
    (:set-text
     (make-update-result
      :patches (list (elmtui.ui.api:make-state-patch `(:components ,(id-from-path id-path) :text)
                                                     (cdr message)))))
    (t (make-update-result)))) ; No changes

(defmethod view ((component my-button) app-state &key id-path)
  ;; ✅ Returns PURE DSL DATA, not objects
  (let ((text (elmtui.ui.api:get-component-property app-state id-path :text "Click Me")))
    `(:button :id ,(id-from-path id-path) :text ,text)))
(defcomponent test-label-component (label)
  (:state
   (extra-info nil)))

(test init-label-component-via-defcomponent
  (let* ((app-state (make-instance 'test-app-state))
         (comp-id :my-label)
         (comp-instance (make-instance 'test-label-component :id comp-id))
         (id-path `(:components ,comp-id)))

    (multiple-value-bind (instance patches commands)
        (elmtui.ui.api:init comp-instance :id-path id-path :initial-text "Hello Label" :initial-extra-info "Special Info")
      (is (eq comp-instance instance))
      (apply-patches app-state patches)
      (let ((state (get-component-state app-state comp-id)))
        (is (listp state))
        (is (eq :test-label-component (getf state :type)))
        (is (string= "Hello Label" (getf state :text)))
        (is (string= "Special Info" (getf state :extra-info)))
        ))))

;; Ensure that :default-initargs in defcomponent's options are passed to defclass
(defcomponent test-default-initargs-component ()
  (:default-initargs :id :my-defaulted-id))  ; This is a class option for defclass

(test defcomponent-default-initargs-passed-to-defclass
  (let ((instance (make-instance 'test-default-initargs-component)))
    ;; This tests that the :id slot in the base 'component' class was set via :default-initargs
    (is (eq :my-defaulted-id (elmtui.ui.api:component-id instance)))))
