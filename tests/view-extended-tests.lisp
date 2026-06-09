;;;; VIEW Module Extended Tests
;;;; Test suite for elmtui view system beyond basic functionality

(uiop:define-package :elmtui.view.extended-tests
  (:use :cl :fiveam :elmtui.view.dsl :elmtui.view.diff)
  (:export #:run-view-extended-tests))

(in-package :elmtui.view.extended-tests)

(def-suite view-extended-test-suite
  :description "Test suite for elmtui view system (extended)")

(in-suite view-extended-test-suite)

;; Test for view diff functionality
(test view-diff-basic
  "Test view diffing functionality"
  (when (fboundp 'elmtui.view.diff:diff-views)
    (let ((old-view '(:container (:text "Hello") (:text "World")))
           (new-view '(:container (:text "Hello") (:text "Universe"))))
      (let ((diff (elmtui.view.diff:diff-views old-view new-view)))
        (is (not (null diff))
          "Diff should be generated")
        (when diff
          (is (> (length diff) 0)
            "Diff should contain changes")
          ;; Check that text change is detected
          (is (some (lambda (change)
                      (and (eq (getf change :type) :modify)
                        (equal (getf change :path) '(1 0))))
                diff)
            "Text change should be detected"))))))

(test view-diff-complex
  "Test complex view diffing"
  (when (fboundp 'elmtui.view.diff:diff-views)
    (let ((old-view '(:root
                       (:header (:text "Title") (:button "Close"))
                       (:content
                         (:list (:item "A") (:item "B") (:item "C")))
                       (:footer (:text "Status"))))
           (new-view '(:root
                        (:header (:text "New Title") (:button "Close") (:button "Help"))
                        (:content
                          (:list (:item "A") (:item "B") (:item "D") (:item "E")))
                        (:footer (:text "Updated Status")))))
      (let ((diff (elmtui.view.diff:diff-views old-view new-view)))
        (is (not (null diff))
          "Diff should be generated")
        (when diff
          ;; Check for header title change
          (is (some (lambda (change)
                      (and (eq (getf change :type) :modify)
                        (equal (getf change :path) '(0 0 0))))
                diff)
            "Header title change should be detected")

          ;; Check for new help button
          (is (some (lambda (change)
                      (and (eq (getf change :type) :add)
                        (equal (getf change :path) '(0 2))))
                diff)
            "New help button should be detected")

          ;; Check for list item changes
          (is (some (lambda (change)
                      (and (eq (getf change :type) :remove)
                        (equal (getf change :path) '(1 0 2))))
                diff)
            "Removed list item should be detected")

          (is (some (lambda (change)
                      (and (eq (getf change :type) :add)
                        (equal (getf change :path) '(1 0 3))))
                diff)
            "Added list item should be detected"))))))

;; Test for view memoization
(test view-memoization-basic
  "Test view memoization functionality"
  (when (fboundp 'elmtui.view.dsl:make-memo-cache)
    (let ((memo-cache (elmtui.view.dsl:make-memo-cache))
           (render-count 0))
      (is (not (null memo-cache))
        "Memo cache should be created")
      (when memo-cache
        ;; Test memoized view creation if function exists
        (when (fboundp 'elmtui.view.dsl:make-memoized-view)
          (let ((view-fn (elmtui.view.dsl:make-memoized-view
                           (lambda (model)
                             (incf render-count)
                             `(:text ,(getf model :message))))))
            (is (not (null view-fn))
              "Memoized view should be created")

            ;; First call - should render
            (let ((result1 (funcall view-fn '(:message "Hello"))))
              (is (string= (getf result1 :message) "Hello")
                "View should render correctly")
              (is (= render-count 1)
                "View should be rendered once"))

            ;; Second call with same input - should use cache
            (let ((result2 (funcall view-fn '(:message "Hello"))))
              (is (equal result1 result2)
                "Cached result should be returned")
              (is (= render-count 1)
                "View should not be re-rendered"))

            ;; Different input - should re-render
            (let ((result3 (funcall view-fn '(:message "World"))))
              (is (string= (getf result3 :message) "World")
                "View should render with new input")
              (is (= render-count 2)
                "View should be re-rendered for different input"))))))))

;; Test for view position calculations
(test view-position-basic
  "Test view position calculations"
  (let ((view-tree '(:root
                      (:header (:text "Title") :width 80 :height 3)
                      (:content
                        (:container :x 5 :y 5 :width 70 :height 15
                          (:text "Content text")
                          (:button "Submit" :width 10 :height 1)))
                      (:footer (:text "Footer") :width 80 :height 2))))

    ;; Test getting element position if function exists
    (when (fboundp 'elmtui.view.dsl:get-element-position)
      (let ((header-pos (elmtui.view.dsl:get-element-position view-tree '(0))))
        (is (not (null header-pos))
          "Header position should be found")
        (when header-pos
          (is (= (getf header-pos :x) 0)
            "Header x position should be 0")
          (is (= (getf header-pos :y) 0)
            "Header y position should be 0")
          (is (= (getf header-pos :width) 80)
            "Header width should be 80")
          (is (= (getf header-pos :height) 3)
            "Header height should be 3")))

      ;; Test nested element position
      (let ((button-pos (elmtui.view.dsl:get-element-position view-tree '(1 0 1))))
        (is (not (null button-pos))
          "Button position should be found")
        (when button-pos
          (is (= (getf button-pos :x) 5)
            "Button x position should be 5")
          (is (= (getf button-pos :y) 5)
            "Button y position should be 5")))))

  ;; Test position with relative coordinates
  (let ((relative-view '(:root
                          (:absolute :x 10 :y 10 :width 20 :height 5)
                          (:relative
                            (:text "Relative content")))))

    (when (fboundp 'elmtui.view.dsl:get-element-position)
      (let ((relative-pos (elmtui.view.dsl:get-element-position relative-view '(1 0))))
        (is (not (null relative-pos))
          "Relative element position should be calculated")
        (when relative-pos
          (is (>= (getf relative-pos :x) 0)
            "Relative x position should be non-negative")
          (is (>= (getf relative-pos :y) 0)
            "Relative y position should be non-negative"))))))

;; Test for view geometry calculations
(test view-geometry-basic
  "Test view geometry calculations"
  ;; Test flex geometry if function exists
  (when (fboundp 'elmtui.view.dsl:calculate-geometry)
    (let ((flex-view '(:container
                        :direction :horizontal
                        :width 80
                        (:item :flex 1 :text "Item 1")
                        (:item :flex 2 :text "Item 2")
                        (:item :width 10 :text "Fixed"))))
      (let ((geometry (elmtui.view.dsl:calculate-geometry flex-view)))
        (is (not (null geometry))
          "Flex geometry should be calculated")
        (when geometry
          ;; Check that flex items are distributed properly
          (when (fboundp 'elmtui.view.dsl:get-item-geometry)
            (let ((item1-pos (elmtui.view.dsl:get-item-geometry geometry '(0 1))))
              (is (not (null item1-pos))
                "Item 1 geometry should be found")
              (when item1-pos
                (is (> (getf item1-pos :width) 0)
                  "Item 1 should have positive width")))

            (let ((item2-pos (elmtui.view.dsl:get-item-geometry geometry '(0 2))))
              (is (not (null item2-pos))
                "Item 2 geometry should be found")
              (when item2-pos
                (is (> (getf item2-pos :width) (getf item1-pos :width))
                  "Item 2 should be wider than item 1"))))))))

  ;; Test grid geometry if function exists
  (when (fboundp 'elmtui.view.dsl:calculate-geometry)
    (let ((grid-view '(:grid
                        :columns 3
                        :rows 2
                        :width 60
                        :height 10
                        (:cell :col 0 :row 0 :text "Cell 1")
                        (:cell :col 1 :row 0 :text "Cell 2")
                        (:cell :col 0 :row 1 :text "Cell 3"))))
      (let ((geometry (elmtui.view.dsl:calculate-geometry grid-view)))
        (is (not (null geometry))
          "Grid geometry should be calculated")
        (when geometry
          ;; Check cell dimensions if function exists
          (when (fboundp 'elmtui.view.dsl:get-cell-size)
            (let ((cell-size (elmtui.view.dsl:get-cell-size geometry)))
              (is (not (null cell-size))
                "Cell size should be available")
              (when cell-size
                (is (= (getf cell-size :width) 20)
                  "Cell width should be 60/3=20")
                (is (= (getf cell-size :height) 5)
                  "Cell height should be 10/2=5")))))))))

;; Test for view styling
(test view-styling-basic
  "Test view styling functionality"
  (let ((styled-view '(:button :text "Click me" :class ("primary" "large")
                        :style {:color :red :background :blue})))

    ;; Test extracting style information if function exists
    (when (fboundp 'elmtui.view.dsl:get-element-classes)
      (let ((classes (elmtui.view.dsl:get-element-classes styled-view)))
        (is (member "primary" classes :test #'string=)
          "Primary class should be extracted")
        (is (member "large" classes :test #'string=)
          "Large class should be extracted")))

    ;; Test inline styles if function exists
    (when (fboundp 'elmtui.view.dsl:get-inline-styles)
      (let ((inline-styles (elmtui.view.dsl:get-inline-styles styled-view)))
        (is (eq (getf inline-styles :color) :red)
          "Inline color style should be extracted")
        (is (eq (getf inline-styles :background) :blue)
          "Inline background style should be extracted")))

    ;; Test computed styles if function exists
    (when (and (fboundp 'elmtui.view.dsl:make-style-sheet)
            (fboundp 'elmtui.view.dsl:add-style-rule)
            (fboundp 'elmtui.view.dsl:compute-computed-styles))
      (let ((style-sheet (elmtui.view.dsl:make-style-sheet)))
        (elmtui.view.dsl:add-style-rule style-sheet ".primary" :color :white)
        (elmtui.view.dsl:add-style-rule style-sheet ".large" :font-size "18px")

        (let ((computed-styles (elmtui.view.dsl:compute-computed-styles
                                 styled-view style-sheet)))
          (is (eq (getf computed-styles :color) :red)
            "Inline style should override class style")
          (is (eq (getf computed-styles :background) :blue)
            "Inline background should be preserved")
          (is (eq (getf computed-styles :font-size) "18px")
            "Class style should be applied"))))))

;; Test for view transforms
(test view-transforms-basic
  "Test view transform functionality"
  (when (fboundp 'elmtui.view.dsl:apply-transform)
    (let ((base-view '(:text "Hello World" :x 10 :y 5)))

      ;; Test translation transform
      (let ((translated (elmtui.view.dsl:apply-transform base-view
                          :translate :dx 5 :dy 3)))
        (is (not (null translated))
          "Translated view should be created")
        (when translated
          (is (= (getf translated :x) 15)
            "X position should be translated")
          (is (= (getf translated :y) 8)
            "Y position should be translated"))))

    ;; Test scale transform
    (let ((scaled (elmtui.view.dsl:apply-transform base-view
                    :scale :sx 2 :sy 1.5)))
      (is (not (null scaled))
        "Scaled view should be created")
      (when scaled
        ;; The exact scaling behavior depends on implementation
        (is (>= (getf scaled :x) 10)
          "Scaled X should be at least original value"))))

  ;; Test chaining transforms if function exists
  (when (fboundp 'elmtui.view.dsl:apply-transforms)
    (let ((complex-view '(:container :width 40 :height 10
                           (:text "Content"))))
      (let ((transformed (elmtui.view.dsl:apply-transforms
                           complex-view
                           '(:translate :dx 5 :dy 5)
                           '(:scale :sx 1.5 :sy 2))))
        (is (not (null transformed))
          "Complex transformed view should be created")))))

;; Test for named area finder
(test named-area-finder-basic
  "Test named area finding functionality"
  (let ((named-view '(:layout
                       :areas '(:header :content :footer)
                       (:header :name "header-area"
                         (:text "Title"))
                       (:content :name "content-area"
                         (:text "Main content")
                         (:button :name "submit-btn" "Submit"))
                       (:footer :name "footer-area"
                         (:text "Status info")))))

    ;; Test finding named areas if function exists
    (when (fboundp 'elmtui.view.dsl:find-named-area)
      (let ((header-area (elmtui.view.dsl:find-named-area named-view "header-area")))
        (is (not (null header-area))
          "Header area should be found")
        (when header-area
          (is (string= (getf header-area :name) "header-area")
            "Area name should match"))))

    ;; Test finding nested named elements
    (let ((submit-btn (elmtui.view.dsl:find-named-area named-view "submit-btn")))
      (is (not (null submit-btn))
        "Submit button should be found")
      (when submit-btn
        (is (string= (getf submit-btn :name) "submit-btn")
          "Button name should match"))))

  ;; Test getting all named areas if function exists
  (when (fboundp 'elmtui.view.dsl:get-all-named-areas)
    (let ((all-areas (elmtui.view.dsl:get-all-named-areas named-view)))
      (is (= (length all-areas) 4)
        "Should find all 4 named areas")
      (is (some (lambda (area)
                  (string= (getf area :name) "content-area"))
            all-areas)
        "Content area should be in list"))))

;; Test for view tree transforms
(test view-tree-transforms-basic
  "Test view tree transformation functionality"
  (let ((tree '(:root
                 (:node1 (:child "A") (:child "B"))
                 (:node2 (:child "C") (:child "D")))))

    ;; Test simple transform if function exists
    (when (fboundp 'elmtui.view.dsl:transform-tree)
      (let ((transformed (elmtui.view.dsl:transform-tree tree
                           (lambda (node)
                             (when (eq (first node) :node1)
                               '(:node1-updated
                                  (:child "X") (:child "Y"))))))))
      (is (not (null transformed))
        "Transformed tree should be created")
      (is (eq (first (second transformed)) :node1-updated)
        "Node should be transformed")
      (is (eq (first (third transformed)) :node2)
        "Other node should remain unchanged")))

  ;; Test conditional transform if function exists
  (when (fboundp 'elmtui.view.dsl:filter-tree)
    (let ((filtered (elmtui.view.dsl:filter-tree tree
                      (lambda (node)
                        (not (eq (first node) :node1))))))
      (is (not (null filtered))
        "Filtered tree should be created")
      (is (eq (first filtered) :root)
        "Root should remain")
      (is (= (length (rest filtered)) 1)
        "Only one child should remain")
      (is (eq (first (second filtered)) :node2)
        "Node2 should remain")))

  ;; Test map transform if function exists
  (when (fboundp 'elmtui.view.dsl:map-tree)
    (let ((mapped (elmtui.view.dsl:map-tree tree
                    (lambda (node)
                      (case (first node)
                        (:child (list :child-updated (second node)))
                        (otherwise node))))))
      (is (not (null mapped))
        "Mapped tree should be created")
      ;; Check that all children have been transformed
      (when (fboundp 'elmtui.view.dsl:find-all-nodes)
        (let ((all-children (elmtui.view.dsl:find-all-nodes mapped :child-updated)))
          (is (= (length all-children) 4)
            "All 4 children should be updated"))))))

(defun run-view-extended-tests ()
  "Run all extended view module tests"
  (run! 'view-extended-test-suite))
