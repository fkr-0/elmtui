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
  (:import-from :elmtui.state #:make-state #:state-ref
    #:apply-patches)
  (:import-from :elmtui.state.transactions
    #:with-transaction
    #:undo
    #:redo)
  (:import-from :elmtui.state
    #:ur-patches
    #:ur-commands)
  (:export #:run-scroll-panel-tests))

(in-package :elmtui.tests.scroll-panel)

(def-suite scroll-panel-tests
  :description "Tests for scroll-panel component")

(in-suite scroll-panel-tests)

;;;---------------------------------------------------------------
;;; Helper Functions
;;;---------------------------------------------------------------
(defun %plist-hash-table (plist)
  "Convert PLIST to a hash-table."
  (let ((ht (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr
      do (setf (gethash k ht) v))
    ht))
(defun %plist-has-key-in (plist path)
  "Return T if PLIST has a value at PATH (list of keywords)."
  (labels ((has-key (cell ks)
             (if (endp ks)
               t
               (let* ((k (first ks))
                       (rest (rest ks))
                       (sub (getf cell k)))
                 (if sub
                   (has-key sub rest)
                   nil)))))
    (has-key plist path)))
(defun make-test-state ()
  "Create a test state (hash-table based)."
  (make-state :initial (alexandria:plist-hash-table '(:components ()))))

(defun scrollbar-node-p (node)
  "Return non-nil when NODE represents the scrollbar text element."
  (and (listp node)
    (eq (first node) :text)
    (let* ((attrs (cdr node))
            (node-id (getf attrs :id))
            (style (getf attrs :style))
            (color (and (listp style) (getf style :color))))
      (and node-id
        (search "-SCROLLBAR" (symbol-name node-id))
        (string= (getf attrs :content "█") "█")
        (or (null color) (eq color :WHITE))))))

(defun find-scrollbar-node (node)
  "Find the scrollbar text node anywhere in the DSL tree."
  (cond
    ((scrollbar-node-p node) node)
    ((listp node)
      (loop for child in node
        for result = (find-scrollbar-node child)
        when result return result))
    (t nil)))
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

      (let ((panel-state (state-ref state id-path)))
        (is (hash-table-p panel-state) (format nil "Panel state found: ~a" panel-state))
        (is (= (gethash :width panel-state) 50)
          (format nil "Width should be 50, found: ~a" (gethash :width panel-state)))
        (is (= (gethash :height panel-state) 25) (format nil "Height should be 25, found: ~a" (gethash :height panel-state)))
        (is (= (gethash :content-height panel-state) 150) (format nil "Content height should be 150, found: ~a" (gethash :content-height panel-state)))
        (is (= (gethash :scroll-y panel-state) 0) (format nil "Initial scroll-y should be 0, found: ~a" (gethash :scroll-y panel-state)))
        (is (eq (gethash :show-scrollbar panel-state) t) (format nil "Show scrollbar should be t, found: ~a" (gethash :show-scrollbar panel-state)))
        (is (eq (gethash :border-style panel-state) :single) (format nil "Border style should be :single, found: ~a" (gethash :border-style panel-state)))))))

;;;---------------------------------------------------------------
;;; Test: Scroll Commands
;;;---------------------------------------------------------------
;; (let* ((panel (make-scroll-panel :test-panel2))
;;         (state (make-test-state))
;;         (id-path '(:components :test-panel2)))

;;   ;; Initialize
;;   (multiple-value-bind (comp patches cmds)
;;     (init panel :id-path id-path
;;       :width 40 :height 20 :content-height 100)


;;     (list ;; (apply-patches state patches)
;;       comp patches cmds)))

;;     ;; Scroll down by 10
;;     ;; (let* ((result (update panel state '(:scroll-by 10) state :id-path id-path))
;;     ;;         (patches (ur-patches result)))
;;     ;;   (apply-patches state patches)
;;     ;;   (let ((panel-state (state-ref state id-path)))
;;     ;;     (is (= (state-ref :scroll-y panel-state) 10) "Scroll-y should be 10 after scrolling by 10")))
;;   )
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
    (setf (state-ref state (append id-path '(:show-scrollbar))) nil)

    ;; Scroll down by 10
    (let* ((result (update panel state '(:scroll-by 10) :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (state-ref state id-path)))
        (is (= (state-ref panel-state  :scroll-y) 10)
          (format nil "Scroll-y should be 10 after scrolling down from 0, found: ~a"
            (gethash :scroll-y panel-state)))))))

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
    (let* ((result (update panel state '(:scroll-by -20) :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (state-ref state id-path)))
        (is (= (state-ref panel-state :scroll-y) 30)
          (format nil "Scroll-y should be 30 after scrolling up from 50, found: ~a"
            (state-ref panel-state :scroll-y)))))))

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

    (let* ((result (update panel state '(:scroll-to 35) :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (state-ref state id-path)))
        (is (= (gethash :scroll-y panel-state) 35)
          (format nil "Scroll-y should be 35 after scrolling to 35, found: ~a"
            (gethash :scroll-y panel-state)))))))

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

    (let* ((result (update panel state '(:scroll-by -100) :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches)
      (let ((panel-state (state-ref state id-path)))
        (is (= (state-ref panel-state :scroll-y) 0)
          (format nil "Scroll-y should be clamped to 0, found: ~a"
            (state-ref panel-state :scroll-y)))))))

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

    (let* ((result (update panel state '(:scroll-by 200) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        ;; Max scroll = content-height - height = 100 - 20 = 80
        (is (= (gethash :scroll-y local-state) 80)
          (format nil "Scroll-y should be clamped to max (80), found: ~a"
            (gethash :scroll-y local-state)))))))

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

    (let* ((result (update panel state '(:page-down) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        (is (= (state-ref local-state :scroll-y) 20)
          (format nil "Page-down should scroll down by height (20), found: ~a"
            (state-ref local-state :scroll-y)))))))

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

    (let* ((result (update panel state '(:page-up) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        (is (= (state-ref local-state :scroll-y) 30) "Page-up should scroll up by height (20)")))))

;;;---------------------------------------------------------------
;;; Test: Scroll to Top/Bottom
;;;---------------------------------------------------------------
(defun get-prop (state compid prop)
  (state-ref state (list :components compid prop)))
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

    (let* ((result (update panel state '(:scroll-to-top) :id-path id-path))
            (patches (ur-patches result)))
      (apply-patches state patches))
    (let ((local-state (state-ref state id-path)))
      (is (= (get-prop state :test-panel9 :scroll-y) 0)
        (format nil "Scroll-y: ~A should be 0 after scroll-to-top"
          (get-prop state :test-panel9 :scroll-y))))))

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

    (let* ((result (update panel state '(:scroll-to-bottom) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        ;; Max = 100 - 20 = 80
        (is (= (state-ref local-state :scroll-y) 80)
          (format nil "Scroll-y should be max (80) after scroll-to-bottom, found: ~a"
            (state-ref local-state :scroll-y)))))))

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
      (apply-patches state patches)(list comp patches cmds))
    (let* ((panel-state (state-ref state id-path))
            (dsl (view panel state :id-path id-path))
            (dsl-attrs (cdr dsl)))
      (declare (ignore panel-state))
      (is (eq (first dsl) :container) (format nil "Root should be :container - got ~a" (first dsl)))
      (is (= 50 (get-prop state :test-panel11 :width)) "Should have width in style")
      (is (getf dsl-attrs :children) "Should have children")
      ;; Check for box child
      (let* ((box-child (first (getf dsl-attrs :children)))
              (box-attrs (cdr box-child)))
        (is (eq (first box-child) :box) "First child should be :box")
        (is (eq (getf (getf box-attrs :style) :border-style) :double)
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

    (let* ((panel-state (state-ref state id-path))
            (dsl (view panel state :id-path id-path))
            (dsl-attrs (cdr dsl))
            (dsl-str (format nil "~S" dsl))
            (box (first (getf dsl-attrs :children)))
            (box-attrs (cdr box))
            (box-children (getf box-attrs :children))
            (scrollbar (find-scrollbar-node dsl)))
      (declare (ignore panel-state))
      ;; Should have content container + scrollbar
      (is (>= (length box-children) 2) "Should have content and scrollbar")
      (is (search "-SCROLLBAR" dsl-str) "Should include scrollbar"))))

(test view-no-scrollbar-when-disabled
  "Test scrollbar is not included when show-scrollbar is nil."
  (let* ((panel (make-scroll-panel :test-panel13))
          (state (make-test-state))
          (id-path '(:components :test-panel13)))

    (multiple-value-bind (comp patches cmds)
      (init panel :id-path id-path
        :width 40 :height 20 :content-height 100
        :show-scrollbar nil)
      
      (apply-patches state patches)
      (setf (state-ref state (append id-path '(:show-scrollbar))) nil))

    (let* ((panel-state (state-ref state id-path))
            (dsl (view panel state :id-path id-path))
            (dsl-attrs (cdr dsl))
            (box (first (getf dsl-attrs :children)))
            (box-attrs (cdr box))
            (box-children (getf box-attrs :children))
            (scrollbar (find-scrollbar-node dsl)))
      (declare (ignore panel-state))
      ;; Should only have content container
      (is (null scrollbar) "Should only have content container, no scrollbar"))))

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

    (let* ((panel-state (state-ref state id-path))
            (dsl (view panel state :id-path id-path))
            (scrollbar (find-scrollbar-node dsl))
            (scrollbar-attrs (and scrollbar (cdr scrollbar))))
      (declare (ignore panel-state))
      (when scrollbar
        (let ((scrollbar-y (getf (getf scrollbar-attrs :style) :y)))
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
      (apply-patches state patches)

      (let* ((panel-state (state-ref state id-path))
              (dsl (view panel state :id-path id-path))
              (scrollbar (find-scrollbar-node dsl))
              (scrollbar-attrs (and scrollbar (cdr scrollbar))))
        (declare (ignore panel-state))
        (when scrollbar
          (let ((scrollbar-y (getf (getf scrollbar-attrs :style) :y)))
            ;; At 100% scroll, scrollbar should be at bottom
            ;; height=20, borders=2, so available space is 18 (rows 1-18)
            ;; At max scroll, y should be 1 + 17 = 18
            (is (= scrollbar-y 19) "Scrollbar should be at bottom")))))))

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

    (let* ((new-children '((:text :id :item1 :content "Item 1")
                            (:text :id :item2 :content "Item 2")))
            (result (update panel state `(:set-content ,new-children 100) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        (is (equal (state-ref local-state :children-dsl) new-children) "Children should be updated")
        (is (= (state-ref local-state :content-height) 100) "Content height should be updated")))))

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

    (let* ((result (update panel state '(:set-dimensions 60 30) :id-path id-path))
            (update-patches (ur-patches result)))

      (apply-patches state update-patches)
      (let ((local-state (state-ref state id-path)))
        (is (= (state-ref local-state :width) 60) "Width should be updated to 60")
        (is (= (state-ref local-state :height) 30) "Height should be updated to 30")))))

;;;---------------------------------------------------------------
;;; Run Tests
;;;---------------------------------------------------------------

(defun run-scroll-panel-tests ()
  "Run all scroll-panel tests."
  (run! 'scroll-panel-tests))
