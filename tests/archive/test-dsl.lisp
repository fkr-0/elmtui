;;;===============================================================
;;; File: tests/v2/test-dsl.lisp
;;; FiveAM Unit Tests for elmtui.view.dsl
;;;===============================================================

(uiop:define-package :elmtui-test-dsl
  (:use :cl :fiveam)
  (:import-from :elmtui.view.dsl
                #:define-view
                #:*dsl-element-map*)
  (:import-from :elmtui.view.core
                #:ui-node
                #:ui-node-type
                #:ui-node-props
                #:ui-node-children)
  (:import-from :elmtui.view.styled
                #:make-styled-node
                #:styled-ui-node)
  (:import-from :elmtui.state
                #:make-application-state
                #:state-ref
                #:set-state)
  (:export :run-elmtui-test-dsl))

(in-package :elmtui-test-dsl)

(def-suite elmtui-test-dsl-suite
  :description "Unit tests for elmtui.view.dsl")
(in-suite elmtui-test-dsl-suite)

;;; --- Basic DSL Functionality ---

(test basic-elements
  "Test basic element creation in the DSL"
  (define-view test-basic-view (app-state dispatch)
    (:div :id "container" :class "main"
          (:h1 "Title")
          (:p "Paragraph text")))

  ;; Create a simple app state
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg) (declare (ignore msg))))
         (view (test-basic-view app-state dispatch-fn)))

    ;; Validate the structure
    (is (eq (ui-node-type view) :div))
    (is (equal (getf (ui-node-props view) :id) "container"))
    (is (equal (getf (ui-node-props view) :class) "main"))
    (is (= (length (ui-node-children view)) 2))

    ;; Check first child (h1)
    (let ((h1 (first (ui-node-children view))))
      (is (eq (ui-node-type h1) :h1))
      (is (= (length (ui-node-children h1)) 1))
      (is (eq (ui-node-type (first (ui-node-children h1))) :text))
      (is (equal (getf (ui-node-props (first (ui-node-children h1))) :value) "Title")))

    ;; Check second child (p)
    (let ((p (second (ui-node-children view))))
      (is (eq (ui-node-type p) :p))
      (is (= (length (ui-node-children p)) 1))
      (is (eq (ui-node-type (first (ui-node-children p))) :text))
      (is (equal (getf (ui-node-props (first (ui-node-children p))) :value) "Paragraph text")))))

(test control-structures
  "Test control structures in the DSL"
  (define-view test-control-structures (app-state dispatch)
    (:div :id "container" :class "controls"
          (if (state-ref app-state :show-header)
              (:h1 "Header Is Visible")
              (:h2 "Header Is Hidden"))

          (when (state-ref app-state :show-content)
            (:p "This content is conditional"))

          (unless (state-ref app-state :hide-footer)
            (:footer "Footer"))))

  ;; Test with different app states
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg) (declare (ignore msg)))))

    ;; Setup state
    (set-state app-state :show-header t)
    (set-state app-state :show-content t)
    (set-state app-state :hide-footer nil)

    ;; Test full view
    (let ((view (test-control-structures app-state dispatch-fn)))
      (is (eq (ui-node-type view) :div))
      (is (= (length (ui-node-children view)) 3))

      ;; Check h1 is visible (from if branch)
      (let ((h1 (first (ui-node-children view))))
        (is (eq (ui-node-type h1) :h1))
        (is (equal (getf (ui-node-props (first (ui-node-children h1))) :value) "Header Is Visible")))

      ;; Check content is visible (from when)
      (let ((p (second (ui-node-children view))))
        (is (eq (ui-node-type p) :p))
        (is (equal (getf (ui-node-props (first (ui-node-children p))) :value) "This content is conditional")))

      ;; Check footer is visible (from unless)
      (let ((footer (third (ui-node-children view))))
        (is (eq (ui-node-type footer) :footer))
        (is (equal (getf (ui-node-props (first (ui-node-children footer))) :value) "Footer"))))

    ;; Change state and test different branches
    (set-state app-state :show-header nil)
    (set-state app-state :show-content nil)
    (set-state app-state :hide-footer t)

    (let ((view (test-control-structures app-state dispatch-fn)))
      (is (eq (ui-node-type view) :div))
      ;; Only h2 should be visible now, other conditionals should be false
      (is (= (length (ui-node-children view)) 1))

      ;; Check h2 is visible (from if branch)
      (let ((h2 (first (ui-node-children view))))
        (is (eq (ui-node-type h2) :h2))
        (is (equal (getf (ui-node-props (first (ui-node-children h2))) :value) "Header Is Hidden"))))))

(test list-generation
  "Test list generation in the DSL"
  (define-view test-list-generation (app-state dispatch)
    (:ul :id "items"
         (apply
          #'append
          (loop for item in
                         (state-ref app-state :items)
                collect  (list (list :li (format nil "Item: ~A" item)))))))

  ;; Test with items
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg)
                        (declare (ignore msg)))))

    ;; Setup state
    (set-state app-state :items '("apple" "banana" "cherry"))

    ;; Test view
    (let ((view (test-list-generation app-state dispatch-fn)))
      (is (eq (ui-node-type view) :ul))
      (is (= (length (ui-node-children view)) 3))

      ;; Check individual items
      (is (eq (ui-node-type (first (ui-node-children view))) :li))
      (is (equal (getf (ui-node-props (first (ui-node-children (first (ui-node-children view))))) :value)
                 "Item: apple"))

      (is (eq (ui-node-type (second (ui-node-children view))) :li))
      (is (equal (getf (ui-node-props (first (ui-node-children (second (ui-node-children view))))) :value)
                 "Item: banana"))

      (is (eq (ui-node-type (third (ui-node-children view))) :li))
      (is (equal (getf (ui-node-props (first (ui-node-children (third (ui-node-children view))))) :value)
                 "Item: cherry")))))

;;; --- Event Handling ---

(test event-handling
  "Test event handling in the DSL"
  (define-view test-events (app-state dispatch)
    (:div
     (:button :id "click-me"
                 :on-click :button-clicked
                 "Click Me")
     (:input :id "text-input"
             :on-change (lambda (val) (funcall dispatch (list :input-changed val)))
             :value (state-ref app-state :input-value))))
  ;; Test event handlers
  (let* ((app-state (make-application-state))
         (messages '())
         (dispatch-fn (lambda (msg) (push msg messages)))
         (view (test-events app-state dispatch-fn)))
    ;; Access button and its handler
    (let* ((button (first (ui-node-children view)))
           (on-click-handler (getf (ui-node-props button) :on-click)))

      (is (functionp on-click-handler))

      ;; Simulate clicking the button
      (funcall on-click-handler nil)
      (is (equal
           (first messages)
           :button-clicked))

      ;; Check button text
      (is
       (equal
        (getf
         (ui-node-props
          (first
           (ui-node-children button)))
         :value)
        "Click Me")))))

;;; --- Widget Integration ---

(test widget-integration
  "Test standardized widget integration with DSL"
  ;; This test depends on button being imported in the dsl
  (define-view test-button-widget (app-state dispatch)
    (:button :widget-id :test-button
                :label "Test Button"
                :on-click :button-pressed))

  ;; Test widget creation
  (let* ((app-state (make-application-state))
         (messages '())
         (dispatch-fn (lambda (msg) (push msg messages))))

    ;; Try to create the view - this might fail if the button widget view function isn't properly
    ;; registered in the DSL element map. We'll catch that error and report it.
    (handler-case
        (let ((view (test-button-widget app-state dispatch-fn)))
          ;; If we get here, the button was created successfully
          (is (not (null view)))
          (pass "Button widget was successfully created"))
      (error (e)
        (fail "Button widget creation failed: ~A" e)))))

;;; --- Advanced DSL Tests ---

(test nested-complex-structures
  "Test complex nested structure creation in the DSL"
  ;; Define a complex view with deeply nested elements and multiple attributes
  (define-view test-complex-view (app-state dispatch)
    (:div :id "app" :class "application"
          (:header :class "app-header"
                   (:h1 :class "title" "Application Title")
                   (:nav :class "main-nav"
                         (:ul :class "nav-list"
                              (:li :class "nav-item" (:a :href "#home" "Home"))
                              (:li :class "nav-item" (:a :href "#about" "About"))
                              (:li :class "nav-item" (:a :href "#contact" "Contact")))))

          (:main :id "main-content" :class "content"
                 (:section :id "dashboard"
                           (:h2 "Dashboard")
                           (:div :class "widget-container"
                                 (:div :class "widget" :data-id "w1"
                                       (:h3 "Widget 1")
                                       (:p "This is widget one content"))
                                 (:div :class "widget" :data-id "w2"
                                       (:h3 "Widget 2")
                                       (:p "This is widget two content"))
                                 (:button :id "refresh-btn" :on-click :refresh-dashboard "Refresh"))))

          (:footer :class "app-footer"
                   (:p "© 2025 ELMTUI Framework")
                   (:div :class "footer-links"
                         (:a :href "#terms" "Terms")
                         (:a :href "#privacy" "Privacy")))))

  ;; Test the complex view
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg) (declare (ignore msg))))
         (view (test-complex-view app-state dispatch-fn)))

    ;; Check top level element
    (is (eq (ui-node-type view) :div))
    (is (equal (getf (ui-node-props view) :id) "app"))
    (is (equal (getf (ui-node-props view) :class) "application"))
    (is (= (length (ui-node-children view)) 3)) ; header, main, footer

    ;; Check header
    (let ((header (first (ui-node-children view))))
      (is (eq (ui-node-type header) :header))
      (is (= (length (ui-node-children header)) 2)) ; h1, nav

      ;; Check nav section
      (let ((nav (second (ui-node-children header))))
        (is (eq (ui-node-type nav) :nav))
        ;; Check nav list (ul)
        (let ((ul (first (ui-node-children nav))))
          (is (eq (ui-node-type ul) :ul))
          (is (= (length (ui-node-children ul)) 3)) ; 3 nav items
          )))

    ;; Check main content
    (let ((main (second (ui-node-children view))))
      (is (eq (ui-node-type main) :main))
      ;; Check dashboard section
      (let ((section (first (ui-node-children main))))
        (is (eq (ui-node-type section) :section))
        ;; Check widget container
        (let* ((widget-container (third (ui-node-children section))) ; h2, then widgets
               (widgets (ui-node-children widget-container)))
          (is (= (length widgets) 3)) ; 2 widget divs + refresh button

          ;; Check the refresh button
          (let ((refresh-btn (third widgets)))
            (is (eq (ui-node-type refresh-btn) :button))
            (is (functionp (getf (ui-node-props refresh-btn) :on-click)))))))

    ;; Check footer
    (let ((footer (third (ui-node-children view))))
      (is (eq (ui-node-type footer) :footer))
      (is (= (length (ui-node-children footer)) 2)) ; p, div
      )))

(test component-composition
  "Test component composition in DSL"
  ;; Define helper component functions
  (defun header-component (app-state dispatch title)
    (declare (ignore dispatch))
    (make-styled-node
     :type :header
     :props (list :class "app-header")
     :children (list
                (make-styled-node
                 :type :h1
                 :props (list :class "title")
                 :children (list (make-styled-node
                                  :type :text
                                  :props (list :value title)))))))

  (defun footer-component (app-state dispatch)
    (declare (ignore dispatch))
    (make-styled-node
     :type :footer
     :props (list :class "app-footer")
     :children (list
                (make-styled-node
                 :type :p
                 :props nil
                 :children (list (make-styled-node
                                  :type :text
                                  :props (list :value (state-ref app-state :copyright))))))))

  ;; Define a view that uses these components
  (define-view test-composed-view (app-state dispatch)
    (:div :id "app" :class "application"
          (header-component app-state dispatch "Composed Application")

          (:main :class "content"
                 (:p "This is the main content"))

          (footer-component app-state dispatch)))

  ;; Test the composed view
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg) (declare (ignore msg)))))

    ;; Set required state
    (set-state app-state :copyright "© 2025 ELMTUI")

    (let ((view (test-composed-view app-state dispatch-fn)))
      ;; Check top structure
      (is (eq (ui-node-type view) :div))
      (is (= (length (ui-node-children view)) 3)) ; header, main, footer

      ;; Check header from component
      (let ((header (first (ui-node-children view))))
        (is (eq (ui-node-type header) :header))
        (is (equal (getf (ui-node-props header) :class) "app-header"))
        (let ((h1 (first (ui-node-children header))))
          (is (eq (ui-node-type h1) :h1))
          (is (equal (getf (ui-node-props (first (ui-node-children h1))) :value) "Composed Application"))))

      ;; Check main content
      (let ((main (second (ui-node-children view))))
        (is (eq (ui-node-type main) :main)))

      ;; Check footer from component
      (let ((footer (third (ui-node-children view))))
        (is (eq (ui-node-type footer) :footer))
        (let* ((p (first (ui-node-children footer)))
               (text (first (ui-node-children p))))
          (is (eq (ui-node-type text) :text))
          (is (equal (getf (ui-node-props text) :value) "© 2025 ELMTUI")))))))

;; Test for recursive element generation
(test recursive-component-generation
  "Test recursive component generation in DSL"
  ;; Define a recursive menu generator
  (defun generate-menu (items depth)
    (when items
      (make-styled-node
       :type :ul
       :props (list :class (format nil "menu-depth-~A" depth))
       :children
       (loop for (label . children) in items
             collect
             (make-styled-node
              :type :li
              :props (list :class "menu-item")
              :children
              (append
               (list
                (make-styled-node
                 :type :span
                 :props nil
                 :children (list (make-styled-node
                                  :type :text
                                  :props (list :value label)))))
               (when children
                 (list (generate-menu children (1+ depth))))))))))

  ;; Define a view that uses this recursive generator
  (define-view test-recursive-view (app-state dispatch)
    (:div :class "menu-container"
          (generate-menu (state-ref app-state :menu-structure) 0)))

  ;; Test the recursive view
  (let* ((app-state (make-application-state))
         (dispatch-fn (lambda (msg) (declare (ignore msg))))
         (menu-structure
           '(("Home" . nil)
             ("Products" . (("Electronics" . (("Phones" . nil)
                                              ("Computers" . nil)))
                            ("Books" . nil)))
             ("About" . (("Company" . nil)
                         ("Team" . nil)
                         ("Locations" . (("New York" . nil)
                                         ("London" . nil))))))))

    ;; Set required state
    (set-state app-state :menu-structure menu-structure)

    (let ((view (test-recursive-view app-state dispatch-fn)))
      ;; Check container
      (is (eq (ui-node-type view) :div))
      (is (= (length (ui-node-children view)) 1))

      ;; Check top level menu
      (let ((top-menu (first (ui-node-children view))))
        (is (eq (ui-node-type top-menu) :ul))
        (is (equal (getf (ui-node-props top-menu) :class) "menu-depth-0"))
        (is (= (length (ui-node-children top-menu)) 3)) ; Home, Products, About

        ;; Check Products submenu (second item)
        (let* ((products-item (second (ui-node-children top-menu)))
               (products-children (ui-node-children products-item))
               (products-submenu (second products-children))) ; span, then submenu
          (is (eq (ui-node-type products-submenu) :ul))
          (is (equal (getf (ui-node-props products-submenu) :class) "menu-depth-1"))
          (is (= (length (ui-node-children products-submenu)) 2)) ; Electronics, Books

          ;; Check Electronics submenu (first item in products)
          (let* ((electronics-item (first (ui-node-children products-submenu)))
                 (electronics-children (ui-node-children electronics-item))
                 (electronics-submenu (second electronics-children))) ; span, then submenu
            (is (eq (ui-node-type electronics-submenu) :ul))
            (is (equal (getf (ui-node-props electronics-submenu) :class) "menu-depth-2"))
            (is (= (length (ui-node-children electronics-submenu)) 2)))) ; Phones, Computers

        ;; Check About submenu depth (third item at top level)
        (let* ((about-item (third (ui-node-children top-menu)))
               (about-children (ui-node-children about-item))
               (about-submenu (second about-children)) ; span, then submenu
               (locations-item (third (ui-node-children about-submenu)))
               (locations-children (ui-node-children locations-item))
               (locations-submenu (second locations-children)))
          (is (eq (ui-node-type locations-submenu) :ul))
          (is (equal (getf (ui-node-props locations-submenu) :class) "menu-depth-2"))
          (is (= (length (ui-node-children locations-submenu)) 2))))))) ; NY, London

(defun run-elmtui-test-dsl ()
  (fiveam:run! 'elmtui-test-dsl-suite))
