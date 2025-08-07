;;;===============================================================
;;; File: src/view/grid-tests.lisp
;;; FiveAM Test Suite for the Grid Layout Module
;;;===============================================================

;; This file defines a comprehensive set of unit tests for the unified
;; grid layout implementation found in grid-complete.lisp.  The tests
;; exercise both the high level API (template parsing, area definition,
;; responsive helpers) and the simplified layout computation
;; functions.  These tests rely on the FiveAM testing framework.

(uiop:define-package :elmtui.view.layout.grid-tests
  (:use :cl :fiveam)
  (:import-from :elmtui.view.layout.grid-complete
                #:parse-grid-template
                #:grid-template #:grid-area #:grid-auto-flow #:grid-responsive
                #:make-grid-item
                #:define-grid-template #:get-grid-area-coordinates
                #:render-grid-template #:build-grid-from-template
                #:grid-position-to-coordinates #:make-grid
                #:compute-grid-layout)
  (:import-from :elmtui.view.layout.grid-complete
                ;; Import internal functions with package prefix for specific tests
                ;; (not part of public API but useful for verification)
                #:parse-grid-template-areas)
  (:export #:run-grid-tests))

(in-package :elmtui.view.layout.grid-tests)

;;;---------------------------------------------------------------------
;;; Helpers
;;;---------------------------------------------------------------------

;; Some tests use hash tables to simulate UI node props.  The
;; simplified compute-grid-layout treats hash tables with a :props
;; entry as elements, pulling the placement information from that
;; table.  This helper builds such a mock element.

(defun make-mock-child (&key props)
  (let ((ht (make-hash-table :test 'equal)))
    (setf (gethash :props ht) props)
    ht))

;;;---------------------------------------------------------------------
;;; Test Suite Definition
;;;---------------------------------------------------------------------

(def-suite grid-layout-tests
  :description "Test the unified grid layout module")

;; Parse grid template string into rows/columns
(def-test parse-grid-template-test
  (let ((template "a a . | b b c"))
    (let ((result (parse-grid-template template)))
      ;; Expect two rows: row 1 contains "a", "a", NIL; row 2 contains "b","b","c"
      (is (= 2 (length result)))
      (is (equal (first result) '("a" "a" nil)))
      (is (equal (second result) '("b" "b" "c"))))))

;; Define a template and verify area coordinates
(def-test define-grid-template-test
  (let* ((tpl (define-grid-template 'my-tpl
                                     '("auto" "auto")
                                     '("1fr" "1fr" "1fr")
                                     "a a . | b b c"))
         (coords-a (get-grid-area-coordinates tpl "a"))
         (coords-b (get-grid-area-coordinates tpl "b"))
         (coords-c (get-grid-area-coordinates tpl "c")))
    ;; Area "a" occupies first row, first two columns
    (is (= (getf coords-a :row-start) 1))
    (is (= (getf coords-a :row-end)   1))
    (is (= (getf coords-a :col-start) 1))
    (is (= (getf coords-a :col-end)   2))
    ;; Area "b" occupies second row, first two columns
    (is (= (getf coords-b :row-start) 2))
    (is (= (getf coords-b :row-end)   2))
    (is (= (getf coords-b :col-start) 1))
    (is (= (getf coords-b :col-end)   2))
    ;; Area "c" occupies second row, third column
    (is (= (getf coords-c :row-start) 2))
    (is (= (getf coords-c :row-end)   2))
    (is (= (getf coords-c :col-start) 3))
    (is (= (getf coords-c :col-end)   3))))

;; Test grid-position-to-coordinates conversion
(def-test grid-position-to-coordinates-test
  (multiple-value-bind (row col)
      (grid-position-to-coordinates 5 3)
    ;; Position 5 in a width-3 grid is row 1, col 2 (zero-based)
    (is (= row 1))
    (is (= col 2))))

;; Test simplified compute-grid-layout with uniform tracks
(def-test compute-grid-layout-even-distribution-test
  (let* ((props (list :grid-template-rows '("1fr" "1fr")
                       :grid-template-columns '("1fr" "1fr")
                       :gap 10))
         (layout (compute-grid-layout 100 50 props nil))
         (col-sizes (getf layout :column-sizes))
         (row-sizes (getf layout :row-sizes)))
    ;; With a width of 100 and one gap of 10, each column should be 45
    (is (equal col-sizes '(45 45)))
    ;; With a height of 50 and one gap of 10, each row should be 20
    (is (equal row-sizes '(20 20)))))

;; Test compute-grid-layout with named areas and placement of children
(def-test compute-grid-layout-named-areas-test
  (let* ((props (list :grid-template-rows '("1fr" "1fr")
                       :grid-template-columns '("1fr" "1fr" "1fr")
                       :grid-template-areas (parse-grid-template "a a . | b b c")
                       :gap 0))
         ;; Create three mock children placed into named areas
         (children (list (make-mock-child :props (list :grid-area "a"))
                         (make-mock-child :props (list :grid-area "b"))
                         (make-mock-child :props (list :grid-area "c"))))
         (layout (compute-grid-layout 90 60 props children))
         (layouts (getf layout :child-layouts)))
    ;; Expect three layout entries
    (is (= 3 (length layouts)))
    ;; The first child ("a") spans two columns on the first row
    (let ((a-layout (first layouts)))
      (is (= (getf a-layout :row-start) 1))
      (is (= (getf a-layout :row-end)   1))
      (is (= (getf a-layout :col-start) 1))
      (is (= (getf a-layout :col-end)   2))
      ;; Width covers two of the three columns (60 width / 3 columns = 30 each)
      (is (= (getf a-layout :width) 60))
      ;; Height is half of container height (since two rows) => 30
      (is (= (getf a-layout :height) 30)))
    ;; The third child ("c") should occupy the second row, third column
    (let ((c-layout (third layouts)))
      (is (= (getf c-layout :row-start) 2))
      (is (= (getf c-layout :col-start) 3))
      (is (= (getf c-layout :width) 30))
      (is (= (getf c-layout :height) 30)))))

;; Test internal parse-grid-template-areas to ensure area map generation
(def-test parse-grid-template-areas-test
  (let* ((area-map (parse-grid-template-areas '("a a ." "b c c")))
         (a (gethash "a" area-map))
         (b (gethash "b" area-map))
         (c (gethash "c" area-map)))
    ;; Area "a" spans row 0, cols 0-1 (0-based indices), so end row = 1, end col = 2 in 1-based terms
    (is (= (getf a :row-start) 0))
    (is (= (getf a :col-start) 0))
    (is (= (getf a :row-end) 1))
    (is (= (getf a :col-end) 2))
    ;; Area "b" at second row, first column
    (is (= (getf b :row-start) 1))
    (is (= (getf b :col-start) 0))
    (is (= (getf b :row-end) 2))
    (is (= (getf b :col-end) 1))
    ;; Area "c" spans second row, columns 1-2
    (is (= (getf c :row-start) 1))
    (is (= (getf c :col-start) 1))
    (is (= (getf c :row-end) 2))
    (is (= (getf c :col-end) 3))))

;;;---------------------------------------------------------------------
;;; Runner Function
;;;---------------------------------------------------------------------

(defun run-grid-tests ()
  "Run all tests defined in this file and return the FiveAM results."
  (run! 'grid-layout-tests))
