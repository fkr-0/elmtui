;;;; Minimal component initialization tests
;;;; Tests basic component setup functionality

(uiop:define-package :elmtui.tests.component-init
  (:use :cl :fiveam)
  (:import-from :elmtui.app
    #:defapplication)
  (:import-from :elmtui.state.api
    #:get-path
    #:make-state
    #:make-update-result
    #:state-ref)
  (:import-from #:cl-state.tx
    #:apply-patches)
  (:import-from :elmtui.ui.api
    #:component)
  (:import-from :elmtui.ui.defcomponent
    #:defcomponent
    #:defcomponent-slots)
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

(defun my-app-update (state msg)
  "Default update function for the test application."
  (declare (ignore msg state))
  (make-update-result))

(defun my-app-view (state)
  "Default view function for the test application."
  (declare (ignore state))
  `(:label :id :test-label :text "Hello, Component Init Tests!"))

(defapplication test-application
  :root-viewport-id :main-viewport
  :root-component-dsl `(:label :id :test-label :text "Initial Label")
  :initial-state-plist `((:components . nil) (:app-specific-data "test"))
  :update-fn 'my-app-update
  :view-fn 'my-app-view)

;; Helper to get component state from the app's component store
(defun get-component-state (app-state component-id)
  (get-path `(:components ,component-id) app-state))

;; The new apply-patches from elmtui.state will be used directly.

;;;------------------------------------------------------------------------------------
;;; Define some test components using defcomponent
;;;------------------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defcomponent test-simple-component (elmtui.ui.api:component)
    (:state
      (type :test-simple-component)
      (id nil)
      (text "Default Text" :accessor test-simple-component-text :initarg :text)
      (count 0 :accessor test-simple-component-count :initarg :count))
    (:view (local-state-map app-state id-path children)
      ;; (declare (ignore local-state-map app-state id-path))
      `(:test-simple-component)))

  (defcomponent test-parent-component (elmtui.ui.widgets.layout:layout)
    (:state
      (title "Default Title" :initarg :title)
      (child-ids nil)
      (child-refs nil)
      (child-components nil)))
  )
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

    ;; First call the defcomponent-generated init for this component's slots
    (multiple-value-bind (self-instance self-patches self-commands)
      ;; Call the defcomponent-generated init by calling the next method after layout's init
      ;; We need to bypass the layout's custom init and call the defcomponent one directly
      (call-next-method component :id-path id-path)

      ;; Handle the title slot manually since the layout's init method interferes
      (let ((parent-patch (first self-patches))) ; parent-patch is (list path value-hashtable)
        (when parent-patch
          (let ((value-ht (second parent-patch)))
            ;; Set the title directly in the patch
            (when initial-title
              (setf (gethash :title value-ht) initial-title))
            ;; Modify the value-ht part of the parent's patch
            (setf (gethash :child-ids value-ht) (mapcar #'elmtui.ui.api:component-id child-instances))
            (setf (gethash :child-refs value-ht) (reverse child-instances))))

        (values self-instance
          ;; Flatten child_patch_lists and append self_patches
          (append (apply #'append (reverse child-patch-lists)) self-patches)
          self-commands)))))

;;;------------------------------------------------------------------------------------
;;; Tests
;;;------------------------------------------------------------------------------------

(test init-simple-component
  (let* (;; Application instance is not directly used here for init,
          (app-state (make-state))
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
        (is (hash-table-p state))
        (is (eq :test-simple-component (gethash :type state)))
        (is (eq comp-id (gethash :id state)))
        (is (string= "Default Text" (gethash :text state)))
        (is (= 0 (gethash :count state)))))

    ;; Test with provided initargs
    (setf (elmtui.state:application-state-data app-state) (make-hash-table :test 'equal)) ; Reset state
    (multiple-value-bind (instance patches commands)
      (elmtui.ui.api:init comp-instance :id-path id-path :initial-text "Hello" :initial-count 42)
      (declare (ignore commands)) ; No commands expected
      (is (eq comp-instance instance))
      (apply-patches app-state patches)
      (let ((state (get-component-state app-state comp-id)))
        (is (hash-table-p state))
        (is (string= "Hello" (gethash :text state)))
        (is (= 42 (gethash :count state))))))
  )

(test init-parent-component-no-children
  (let* ((app-state (make-state))
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
        (is (hash-table-p state))
        (is (eq :test-parent-component (gethash :type state)))
        (is (eq comp-id (gethash :id state)))
        (is (string= "Test Parent" (gethash :title state)))
        (is (null (gethash :child-components state)))
        (is-false (gethash :child-ids state))
        (is-false (gethash :child-refs state))))))

(test init-parent-component-with-children
  (let* ((app-state (make-state))
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
        (is (hash-table-p parent-comp-state))
        (is (eq :test-parent-component (gethash :type parent-comp-state)))
        (is (string= "Parent With Children" (gethash :title parent-comp-state)))
        (let ((child-ids (gethash :child-ids parent-comp-state))
               (child-refs (gethash :child-refs parent-comp-state)))
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
        (is (hash-table-p child1-state))
        (is (eq :test-simple-component (gethash :type child1-state)))
        (is (string= "Child One Text" (gethash :text child1-state)))
        (is (= 0 (gethash :count child1-state)))) ; Default count

      ;; Check child2 state
      (let ((child2-state (get-component-state app-state child2-id)))
        (is (hash-table-p child2-state))
        (is (eq :test-simple-component (gethash :type child2-state)))
        (is (string= "Default Text" (gethash :text child2-state))) ; Default text
        (is (= 99 (gethash :count child2-state)))))))

(test defcomponent-accessors
  (let* ((the-app-state (make-state))
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
  (let* ((app-state (make-state))
          (comp-id :my-label)
          (comp-instance (make-instance 'test-label-component :id comp-id))
          (id-path `(:components ,comp-id)))

    (multiple-value-bind (instance patches commands)
      (elmtui.ui.api:init comp-instance
        :id-path id-path :initial-text "Hello Label"
        :initial-extra-info "Special Info")
      (declare (ignore commands)) ; No commands expected
      (is (eq comp-instance instance))
      (apply-patches app-state patches)
      (is (string= "Hello Label" (state-ref  app-state (append id-path '(:text)))))
      (let ((state (get-component-state app-state comp-id)))
        (is (hash-table-p state))
        (is (eq :test-label-component (gethash :type state)))
        (is (string= "Special Info" (gethash :extra-info state)))))))

;; Ensure that :default-initargs in defcomponent's options are passed to defclass
(defcomponent test-default-initargs-component (elmtui.ui.api:component)
  (:state
    (type :test-simple-component)
    (id :my-defaulted-id :accessor test-default-initargs-component-id :initarg :id)
    (text "Default Text" :accessor test-simple-component-text :initarg :text)
    (count 0 :accessor test-simple-component-count :initarg :count))
  (:view (local-state-map app-state id-path children)
    ;; (declare (ignore local-state-map app-state id-path))
    `(:test-simple-component)))
;; (:default-initargs :id :my-defaulted-id)

(test defcomponent-default-initargs-passed-to-defclass
  (let ((instance (make-instance 'test-default-initargs-component))
         (state (make-state)))
    (elmtui.ui.api:init instance :id-path `(:components :my-defaulted-id))
    state
    ;; This tests that the :id slot in the base 'component' class was set via :default-initargs
    (is (eq :my-defaulted-id (test-default-initargs-component-id state instance)))))
