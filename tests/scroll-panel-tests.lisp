;;;===============================================================
;;; File: tests/scroll-panel-tests.lisp
;;; Tests for Virtual Scroll Panel Component
;;;===============================================================

(uiop:define-package :elmtui.tests.scroll-panel
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.scroll-panel
    #:scroll-panel
    #:make-scroll-panel)
  (:import-from :elmtui.ui.api
    #:init #:update #:view)
  (:export #:run-scroll-panel-tests))

(in-package :elmtui.tests.scroll-panel)

(def-suite scroll-panel-tests
  :description "Tests for scroll-panel component")

(in-suite scroll-panel-tests)

;;;---------------------------------------------------------------
;;; Helper Functions
;;;---------------------------------------------------------------

(defun make-test-state ()
  "Create a test state (hash-table based)."
  (make-hash-table :test 'equal))

(defun apply-patches (state patches)
  "Apply patches to state."
  (dolist (patch patches state)
    (setf (gethash (first patch) state) (second patch))))

(defun get-state-value (state path &optional default)
  "Get value from state at path."
  (gethash path state default))

;;;---------------------------------------------------------------
;;; Test: Initialization
;;;---------------------------------------------------------------

(test scroll-panel-initialization
  "Test scroll-panel initializes with correct defaults."
  (let* ((panel (make-scroll-panel :test-panel
                  :width 50
                  :height 25
                  :content-height 150))
          (state (make-test-state))
          (id-path '(:components :test-panel)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 50
        :height 25
        :content-height 150)
      (declare (ignore comp cmds))

      (apply-patches state patches)

      (let ((panel-state (get-state-value state id-path)))
        (is (hash-table-p panel-state) "Panel state should be a hash table")
        (is (= (gethash :width panel-state) 50) "Width should be 50")
        (is (= (gethash :height panel-state) 25) "Height should be 25")
        (is (= (gethash :content-height panel-state) 150) "Content height should be 150")
        (is (= (gethash :scroll-y panel-state) 0) "Initial scroll should be 0")
        (is (eq (gethash :show-scrollbar panel-state) t) "Scrollbar should be shown by default")
        (is (eq (gethash :border-style panel-state) :single) "Border style should be :single")))))

;;;---------------------------------------------------------------
;;; Test: Scroll Commands
;;;---------------------------------------------------------------

(test scroll-by-positive
  "Test scrolling down by a positive delta."
  (let* ((panel (make-scroll-panel :test-panel2))
          (state (make-test-state))
          (id-path '(:components :test-panel2)))

    ;; Initialize
    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    ;; Scroll down by 10
    (let* ((result (update panel '(:scroll-by 10) state :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (get-state-value state id-path)))
        (is (= (gethash :scroll-y panel-state) 10) "Scroll-y should be 10 after scrolling by 10")))))

(test scroll-by-negative
  "Test scrolling up by a negative delta."
  (let* ((panel (make-scroll-panel :test-panel3))
          (state (make-test-state))
          (id-path '(:components :test-panel3)))

    ;; Initialize
    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100 :scroll-y 50)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    ;; Scroll up by 20
    (let* ((result (update panel '(:scroll-by -20) state :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (get-state-value state id-path)))
        (is (= (gethash :scroll-y panel-state) 30) "Scroll-y should be 30 after scrolling up from 50")))))

(test scroll-to-specific-position
  "Test scrolling to a specific position."
  (let* ((panel (make-scroll-panel :test-panel4))
          (state (make-test-state))
          (id-path '(:components :test-panel4)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((result (update panel '(:scroll-to 35) state :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (get-state-value state id-path)))
        (is (= (gethash :scroll-y panel-state) 35) "Scroll-y should be exactly 35")))))

(test scroll-clamping-top
  "Test scroll position is clamped to minimum (0)."
  (let* ((panel (make-scroll-panel :test-panel5))
          (state (make-test-state))
          (id-path '(:components :test-panel5)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100 :scroll-y 5)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((result (update panel '(:scroll-by -100) state :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (get-state-value state id-path)))
        (is (= (gethash :scroll-y panel-state) 0) "Scroll-y should be clamped to 0")))))

(test scroll-clamping-bottom
  "Test scroll position is clamped to maximum."
  (let* ((panel (make-scroll-panel :test-panel6))
          (state (make-test-state))
          (id-path '(:components :test-panel6)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let ((local-state (get-state-value state id-path)))
      ;; Max scroll = content-height - height = 100 - 20 = 80
      (multiple-value-bind (new-local-state commands)
        (update panel '(:scroll-by 200) state :id-path id-path)
        (declare (ignore commands))

        (is (= (getf new-local-state :scroll-y) 80) "Scroll-y should be clamped to max (80)")))))

;;;---------------------------------------------------------------
;;; Test: Page Scrolling
;;;---------------------------------------------------------------

(test page-down-scrolling
  "Test page-down scrolls by panel height."
  (let* ((panel (make-scroll-panel :test-panel7))
          (state (make-test-state))
          (id-path '(:components :test-panel7)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let ((local-state (get-state-value state id-path)))
      (multiple-value-bind (new-local-state commands)
        (update panel '(:page-down) state :id-path id-path)
        (declare (ignore commands))

        (is (= (getf new-local-state :scroll-y) 20) "Page-down should scroll by height (20)")))))

(test page-up-scrolling
  "Test page-up scrolls by panel height upwards."
  (let* ((panel (make-scroll-panel :test-panel8))
          (state (make-test-state))
          (id-path '(:components :test-panel8)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100 :scroll-y 50)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let ((local-state (get-state-value state id-path)))
      (multiple-value-bind (new-local-state commands)
        (update panel '(:page-up) state :id-path id-path)
        (declare (ignore commands))

        (is (= (getf new-local-state :scroll-y) 30) "Page-up should scroll up by height (20)")))))

;;;---------------------------------------------------------------
;;; Test: Scroll to Top/Bottom
;;;---------------------------------------------------------------

(test scroll-to-top
  "Test scroll-to-top command."
  (let* ((panel (make-scroll-panel :test-panel9))
          (state (make-test-state))
          (id-path '(:components :test-panel9)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100 :scroll-y 50)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let ((local-state (get-state-value state id-path)))
      (multiple-value-bind (new-local-state commands)
        (update panel '(:scroll-to-top) state :id-path id-path)
        (declare (ignore commands))

        (is (= (getf new-local-state :scroll-y) 0) "Scroll-y should be 0 after scroll-to-top")))))

(test scroll-to-bottom
  "Test scroll-to-bottom command."
  (let* ((panel (make-scroll-panel :test-panel10))
          (state (make-test-state))
          (id-path '(:components :test-panel10)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let ((local-state (get-state-value state id-path)))
      (multiple-value-bind (new-local-state commands)
        (update panel '(:scroll-to-bottom) state :id-path id-path)
        (declare (ignore commands))

        ;; Max = 100 - 20 = 80
        (is (= (getf new-local-state :scroll-y) 80) "Scroll-y should be at maximum")))))

;;;---------------------------------------------------------------
;;; Test: View Rendering
;;;---------------------------------------------------------------

(test view-renders-container-with-box
  "Test view method produces correct DSL structure."
  (let* ((panel (make-scroll-panel :test-panel11))
          (state (make-test-state))
          (id-path '(:components :test-panel11)))
    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 50 :height 25 :content-height 100
        :border-style :double :title "Test Panel")
      (declare (ignore comp cmds))
      (apply-patches state patches))
    (let* ((dsl (view panel state :id-path id-path)))
      (is (eq (first dsl) :container) "Root should be :container")
      (is (getf (getf dsl :style) :width) "Should have width in style")
      (is (getf dsl :children) "Should have children")
      ;; Check for box child
      (let ((box-child (first (getf dsl :children))))
        (is (eq (first box-child) :box) "First child should be :box")
        (is (eq (getf (getf box-child :style) :border-style) :double)
          "Border should be :double")))))

(test view-includes-scrollbar-when-needed
  "Test scrollbar is included when content exceeds height."
  (let* ((panel (make-scroll-panel :test-panel12))
          (state (make-test-state))
          (id-path '(:components :test-panel12)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100
        :show-scrollbar t)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((dsl (view panel state :id-path id-path))
            (box-children (getf (first (getf dsl :children)) :children)))
      ;; Should have content container + scrollbar
      (is (>= (length box-children) 2) "Should have content and scrollbar"))))

(test view-no-scrollbar-when-disabled
  "Test scrollbar is not included when show-scrollbar is nil."
  (let* ((panel (make-scroll-panel :test-panel13))
          (state (make-test-state))
          (id-path '(:components :test-panel13)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100
        :show-scrollbar nil)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((dsl (view panel state :id-path id-path))
            (box-children (getf (first (getf dsl :children)) :children)))
      ;; Should only have content container
      (is (= (length box-children) 1) "Should only have content container, no scrollbar"))))

;;;---------------------------------------------------------------
;;; Test: Scrollbar Position Calculation
;;;---------------------------------------------------------------

(test scrollbar-position-at-top
  "Test scrollbar is at top when scroll is 0."
  (let* ((panel (make-scroll-panel :test-panel14))
          (state (make-test-state))
          (id-path '(:components :test-panel14)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100
        :scroll-y 0)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((dsl (view panel state :id-path id-path))
            (box-children (getf (first (getf dsl :children)) :children))
            (scrollbar (find :text box-children :key #'first)))
      (when scrollbar
        (let ((scrollbar-y (getf (getf scrollbar :style) :y)))
          (is (= scrollbar-y 1) "Scrollbar should be at top (y=1, inside border)"))))))

(test scrollbar-position-at-bottom
  "Test scrollbar is at bottom when scrolled to max."
  (let* ((panel (make-scroll-panel :test-panel15))
          (state (make-test-state))
          (id-path '(:components :test-panel15)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100
        :scroll-y 80) ; max scroll
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((dsl (view panel state :id-path id-path))
            (box-children (getf (first (getf dsl :children)) :children))
            (scrollbar (find :text box-children :key #'first)))
      (when scrollbar
        (let ((scrollbar-y (getf (getf scrollbar :style) :y)))
          ;; At 100% scroll, scrollbar should be at bottom
          ;; height=20, borders=2, so available space is 18 (rows 1-18)
          ;; At max scroll, y should be 1 + 17 = 18
          (is (= scrollbar-y 18) "Scrollbar should be at bottom"))))))

;;;---------------------------------------------------------------
;;; Test: Content Update
;;;---------------------------------------------------------------

(test set-content-updates-children
  "Test :set-content message updates children."
  (let* ((panel (make-scroll-panel :test-panel16))
          (state (make-test-state))
          (id-path '(:components :test-panel16)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 50)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((local-state (get-state-value state id-path))
            (new-children '((:text :id :item1 :content "Item 1")
                             (:text :id :item2 :content "Item 2")))
            (r (update panel `(:set-content ,new-children 100) state :id-path id-path))
            (a (ur-patches r))
            (b (ur-commands r)))
      

      (is (equal (getf new-local-state :children-dsl) new-children) "Children should be updated")
      (is (= (getf new-local-state :content-height) 100) "Content height should be updated"))))

;;;---------------------------------------------------------------
;;; Test: Dimension Updates
;;;---------------------------------------------------------------

(test set-dimensions-updates-size
  "Test :set-dimensions message updates width and height."
  (let* ((panel (make-scroll-panel :test-panel17))
          (state (make-test-state))
          (id-path '(:components :test-panel17)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20)
      (declare (ignore comp cmds))
      (apply-patches state patches))

    (let* ((local-state (get-state-value state id-path))
            (r (update panel '(:set-dimensions 60 30) state :id-path id-path))
            (a (ur-patches r))
            (b (ur-commands r)))
      
      
      
      (declare (ignore commands))

      (is (= (getf new-local-state :width) 60) "Width should be updated to 60")
      (is (= (getf new-local-state :height) 30) "Height should be updated to 30"))))

;;;---------------------------------------------------------------
;;; Run Tests
;;;---------------------------------------------------------------

(defun run-scroll-panel-tests ()
  "Run all scroll-panel tests."
  (run! 'scroll-panel-tests))
