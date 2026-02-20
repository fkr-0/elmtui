;;;; Comprehensive tests for the defcomponent macro
;;;; Tests all aspects of defcomponent: state, init, update, view, accessors

(uiop:define-package :elmtui.tests.defcomponent

  (:use :cl :fiveam)
  (:import-from :elmtui.ui.defcomponent #:defcomponent #:cclass-name)
  (:import-from :elmtui.ui.api #:component #:component-id #:id-from-path #:init #:update #:view)
  (:import-from :elmtui.ui.component-metaclass #:class-metadata)
  (:import-from :elmtui.state.api #:get-path)
  (:import-from :elmtui.state.api
                #:make-update-result
                #:make-state
                #:ur-patches #:ur-commands)
  (:import-from :elmtui.api #:dsl-type)
  (:export #:defcomponent-tests))

(in-package :elmtui.tests.defcomponent)

(def-suite defcomponent-tests
  :in elmtui.tests:elmtui-test
  :description "Comprehensive tests for the defcomponent macro")

(in-suite defcomponent-tests)

;;; Test component definitions

;; Simple component with state slots
(defcomponent test-simple ()
  (:state
   (name "test" :type string :documentation "Component name")
   (value 42 :type integer :documentation "Component value" :accessor test-simple-value)
   (enabled t :type boolean :documentation "Component enabled state" :accessor test-simple-enabled)))

;; Component with custom init
(defcomponent test-with-init ()
  (:state
   (data (list) :type list :documentation "Component data")
   (initialized nil :type (or null boolean) :documentation "Init flag"))

  (:init (props self-id-path)
         (let ((initial-data (getf props :data '(1 2 3))))
           (values `(:data ,initial-data :initialized t)
                   nil))))

;; Component with custom update
(defcomponent test-with-update ()
  (:state
   (counter 0 :type integer :documentation "Counter value")
   (messages (list) :type list :documentation "Message history"))

  (:update (msg local-state app-state id-path)
           (:increment (amount)
                       (let ((new-counter (+ (getf local-state :counter 0) amount)))
                         (values `(:counter ,new-counter
                                   :messages ,(cons msg (getf local-state :messages)))
                                 nil)))
           (:reset ()
                   (values `(:counter 0 :messages ,(cons msg (getf local-state :messages)))
                           nil))
           (:otherwise (full-msg)
                       (values `(:messages ,(cons full-msg (getf local-state :messages)))
                               nil))))

;; Component with custom view
(defcomponent test-with-view ()
  (:state
   (label "View Test" :type string :documentation "Label text"))

  (:view (local-state app-state id-path children)
         (let ((text (getf local-state :label "Default")))
           `(:div :id ,(id-from-path id-path) :text ,text))))

;; Component with all features
(defcomponent test-complete ()
  (:state
   (name "complete" :type string :accessor complete-name)
   (data (list) :type list :accessor complete-data)
   (active t :type boolean :accessor complete-active))

  (:documentation "A complete test component")
  (:on-unhandled-message :log)

  (:init (props self-id-path)
         (values `(:name ,(getf props :name "complete")
                   :data ,(getf props :data '())
                   :active t)
                 nil))

  (:update (msg local-state app-state id-path)
           (:set-name (new-name)
                      (values `(:name ,new-name) nil))
           (:toggle-active ()
                                        ;(let ((local-state (elmtui.utils:get-path app-state id-path)))
                           (values `(:active ,(not (getf local-state :active))) nil);)
                           ))

  (:view (local-state app-state id-path children)
         `(:component :type :test-complete
                      :id ,(id-from-path id-path)
                      :name ,(getf local-state :name)
                      :active ,(getf local-state :active))))
(defcomponent test-child (test-simple)
  (:state
   (child-prop "child" :type string :documentation "Child property")))

;; Component with metadata clause
(defcomponent test-with-metadata ()
  (:state
   (label "metadata" :type string))
  (:documentation "Metadata-aware test component")
  (:metadata
   (:props ((:label string t :doc "Visible label")))
   (:documentation "Metadata for docs")
   (:examples ((:test-with-metadata :label "Example")))))
;;; Tests

(test defcomponent-class-creation
  "Test that defcomponent creates proper CLOS classes"
  (is (find-class 'test-simple nil))
  (is (subtypep 'test-simple 'component))
  (let ((instance (make-instance 'test-simple)))
    (is (typep instance 'test-simple))
    (is (typep instance 'component))))

(test defcomponent-cclass-name
  "Test that cclass-name method works correctly"
  (let ((instance (make-instance 'test-simple)))
    (is (eq :test-simple (cclass-name instance)))))

(test defcomponent-default-init
  "Test default init method generation"
  (let* ((instance (make-instance 'test-simple))
         (id-path '(:components :test1)))
    (multiple-value-bind (returned-instance patches commands)
        (init instance :id-path id-path)
      (is (eq instance returned-instance))
      (is (= 1 (length patches)))
      (is (null commands))

      (let* ((patch (first patches))
             (path (first patch))
             (state (second patch)))
        (is (equal id-path path))
        (is (eq :test-simple (gethash :type state)))
        (is (equal (id-from-path id-path) (gethash :id state)))
        (is (string= "test" (gethash :name state)))
        (is (= 42 (gethash :value state)))
        (is (eq t (gethash :enabled state)))))))

(test defcomponent-init-with-params
  "Test default init with custom parameters"
  (let* ((instance (make-instance 'test-simple))
         (id-path '(:components :test2)))
    (multiple-value-bind (returned-instance patches commands)
        (init instance :id-path id-path :initial-name "custom" :initial-value 100)
      (is (null commands))
      (is (eq instance returned-instance))
      (is (= 1 (length patches)))

      (let* ((patch (first patches))
             (state (second patch)))
        (is (string= "custom" (gethash :name state)))
        (is (= 100 (gethash :value state)))
        (is (eq t (gethash :enabled state)))))))

(test defcomponent-custom-init
  "Test component with custom init method"
  (let* ((instance (make-instance 'test-with-init))
         (id-path '(:components :test3)))
    (multiple-value-bind (returned-instance patches commands)
        (init instance :id-path id-path :data '(a b c))
      (is (eq instance returned-instance))
      (is (= 1 (length patches)))
      (is (null commands))

      (let* ((patch (first patches))
             (state (second patch)))
        (is (equal '(a b c) (gethash :data state)))
        (is (eq t (gethash :initialized state)))))))

(test defcomponent-default-update
  "Test default update method (no-op)"
  (let* ((instance (make-instance 'test-simple))
         (mock-app-state '())
         (message '(:some-message :data)))
    (let ((result (update instance mock-app-state message :id-path '(:components :test))))
      (is (typep result 'elmtui.state.api:update-result))
      (is (null (elmtui.state.api:ur-patches result)))
      (is (null (elmtui.state.api:ur-commands result))))))

(test defcomponent-custom-update
  "Test component with custom update method"
  (let* ((instance (make-instance 'test-with-update))
         (id-path '(:components :test))
         (mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:test (:counter 5 :messages () :type :test-with-update :id :test)))))))

    ;; Test increment message
    (let* ((result (update instance mock-app-state '(:increment 3) :id-path id-path))
           (patches (ur-patches result))
           (counter-patch (find '(:components :test :counter) patches :key #'first :test #'equal))
           (messages-patch (find '(:components :test :messages) patches :key #'first :test #'equal)))
      (is (typep result 'elmtui.state.api:update-result))
      (is (= 2 (length patches)))
      (is (not (null counter-patch)))
      (is (= 8 (second counter-patch)))
      (is (not (null messages-patch))))

    ;; Test reset message
    (let* ((result (update instance mock-app-state '(:reset) :id-path id-path))
           (patches (ur-patches result))
           (counter-patch (find '(:components :test :counter) patches :key #'first :test #'equal)))
      (is (typep result 'elmtui.state.api:update-result))
      (is (= 2 (length patches)))
      (is (not (null counter-patch)))
      (is (= 0 (second counter-patch))))

    ;; Test unhandled message (otherwise clause)
    (let ((result (update instance mock-app-state '(:unknown-message) :id-path id-path)))
      (is (typep result 'elmtui.state.api:update-result))
      (let ((patches (ur-patches result)))
        (is (= 1 (length patches)))))))

(test defcomponent-default-view
  "Test default view method"
  (let* ((instance (make-instance 'test-simple))
         (mock-app-state '())
         (id-path '(:components :test)))
    (let ((view-result (view instance mock-app-state :id-path id-path)))
      (is (listp view-result))
      (is (eq :test-simple (first view-result)))
      (is (getf (cdr view-result) :id))
      (is (getf (cdr view-result) :message)))))

(test defcomponent-custom-view
  "Test component with custom view method"
  (let* ((instance (make-instance 'test-with-view))
         (mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:test (:label "Custom Label"))))))
         (id-path '(:components :test)))
    (let ((view-result (view instance mock-app-state :id-path id-path)))
      (is (listp view-result))
      (is (eq :div (first view-result)))
      (is (equal (id-from-path id-path) (gethash :id (alexandria:plist-hash-table (cdr view-result)))))
      (is (string= "Custom Label" (gethash :text (alexandria:plist-hash-table (cdr view-result))))))))

(test defcomponent-accessors
  "Test generated accessor functions"
  (let* ((mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:test (:value 123 :enabled nil))))))
         (instance (make-instance 'test-simple)))
    (setf (component-id instance) :test)

    (is (= 123 (test-simple-value mock-app-state instance)))
    (is (eq nil (test-simple-enabled mock-app-state instance)))))

(test defcomponent-complete-component
  "Test component with all features enabled"
  (let* ((instance (make-instance 'test-complete))
         (id-path '(:components :complete-test)))

    ;; Test init
    (multiple-value-bind (returned-instance patches commands)
        (init instance :id-path id-path :name "my-complete" :data '(x y z))
      (is (null commands))
      (is (eq instance returned-instance))
      (is (= 1 (length patches)))

      (let* ((patch (first patches))
             (state (second patch)))
        (is (string= "my-complete" (gethash :name state)))
        (is (equal '(x y z) (gethash :data state)))
        (is (eq t (gethash :active state)))))

    ;; Test update
    (let* ((mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:complete-test (:name "test" :active t))))))
           (result (update instance mock-app-state '(:set-name "updated") :id-path id-path)))
      (is (typep result 'elmtui.state.api:update-result))
      (let ((patches (ur-patches result)))
        (is (= 1 (length patches)))
        (is (string= "updated" (second (first patches))))))

    ;; Test view
    (let* ((mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:complete-test (:name "view-test" :active nil))))))
           (view-result (view instance mock-app-state :id-path id-path)))
      (is (eq :component (first view-result)))
      (let ((props (alexandria:plist-hash-table (cdr view-result))))
        (is (eq :test-complete (gethash :type props)))
        (is (string= "view-test" (gethash :name props)))
        (is (eq nil (gethash :active props)))))

    ;; Test accessors
    ;; (let* ((instance (make-instance 'test-complete))
    ;;        (id-path '(:components :complete-test)))
    (let ((mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:complete-test (:name "accessor-test" :data (1 2 3) :active t)))))))
      (setf (component-id instance) :complete-test)
      ;; (complete-data mock-app-state instance)))
      (is (string= "accessor-test" (complete-name mock-app-state instance)))
      (is (equal (list 1 2 3) (complete-data mock-app-state instance)))
      (is (eq t (complete-active mock-app-state instance))))))

(test defcomponent-class-options
  "Test that class options are passed through correctly"
  (let ((class (find-class 'test-complete)))
    (is (string= "A complete test component"
                 (documentation class t)))))

(test defcomponent-metadata-stored-on-metaclass
  "Test that :metadata is persisted on class metaobject"
  (let* ((class (find-class 'test-with-metadata))
         (metadata (class-metadata class)))
    (is (string= "Metadata-aware test component" (documentation class t)))
    (is (listp metadata))
    (is (equal '((:label string t :doc "Visible label"))
               (getf metadata :props)))
    (is (string= "Metadata for docs"
                (getf metadata :documentation)))
    (is (equal '((:test-with-metadata :label "Example"))
               (getf metadata :examples)))))

(test defcomponent-does-not-require-widget-registry-registration
  "Test that defcomponent works without mutating legacy widget registry"
  (let* ((widgets-sym (find-symbol "*WIDGETS*" :elmtui.ui.widget-registry))
         (registry (and widgets-sym (boundp widgets-sym) (symbol-value widgets-sym)))
         (before-count (and (hash-table-p registry)
                            (hash-table-count registry))))
    (finishes
      (eval
       '(defcomponent test-no-registry-side-effect ()
          (:state
           (enabled t :type boolean))
          (:documentation "Temporary test component"))))
    (multiple-value-bind (class props)
        (dsl-type :test-no-registry-side-effect)
      (is (eq class 'test-no-registry-side-effect))
      (is (null props)))
    (when (hash-table-p registry)
      (is (= before-count (hash-table-count registry))))))


(test defcomponent-inheritance
  "Test that component inheritance works properly"


  (is (subtypep 'test-child 'test-simple))
  (is (subtypep 'test-child 'component))

  (let ((instance (make-instance 'test-child)))
    (is (typep instance 'test-child))
    (is (typep instance 'test-simple))
    (is (typep instance 'component))
    (is (eq :test-child (cclass-name instance)))

    (let* ((id-path '(:components :test-child1)))
      (multiple-value-bind (returned-instance patches commands)
          (init instance :id-path id-path)
        (is (eq instance returned-instance))
        (is (= 1 (length patches)))
        (is (null commands))
        (let* ((patch (first patches))
               (state (second patch)))
          (is (string= "test" (gethash :name state)))
          (is (= 42 (gethash :value state)))
          (is (eq t (gethash :enabled state)))
          (is (string= "child" (gethash :child-prop state))))))))
;; (init '(test-simple))

;; Lambda List: (ELMTUI.UI.DEFCOMPONENT::SELF &REST ELMTUI.UI.DEFCOMPONENT::OTHER-KEYS &KEY ELMTUI.UI.DEFCOMPONENT::ID-PATH ELMTUI.TESTS.DEFCOMPONENT::INITIAL-NAME ELMTUI.TESTS.DEFCOMPONENT::INITIAL-VALUE ELMTUI.TESTS.DEFCOMPONENT::INITIAL-ENABLED &ALLOW-OTHER-KEYS)
;; Test initialization of a simple component with custom parameters eg:
;; (init (make-instance 'test-simple) :id-path '(:my-app :main-layout :submit-button)
;;     :initial-state '(:name "Submit Button" :value 100 :enabled t)
;;                    :initial-name '(:button :label "Submit" :on-click #'submit-handler))
;; (let* ((instance (make-instance 'test-complete))
;;        (id-path '(:components :complete-test)))
;;   (let ((mock-app-state (make-state :initial (alexandria:plist-hash-table `(:components (:complete-test (:name "accessor-test" :data '(1 2 3) :active t)))))))
;;     (setf (component-id instance) :complete-test)
;;     (list '(1 2 3 ) (complete-data mock-app-state instance))))

;; Test component for DSL type auto-generation
(defcomponent test-auto-widget (component)
  (:state
   (data "auto-widget" :type string :documentation "Auto widget data")))

(test defcomponent-auto-generates-dsl-type-method
  "defcomponent automatically generates dsl-type method"
  (multiple-value-bind (class props)
      (dsl-type :test-auto-widget)
    (is (eq class 'test-auto-widget))
    (is (null props)))

  ;; Test with props
  (multiple-value-bind (class props)
      (dsl-type :test-auto-widget '(:extra "data"))
    (is (eq class 'test-auto-widget))
    (is (equal (getf props :extra) "data"))))
