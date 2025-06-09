;;;===============================================================
;;; File: tests/elmtui-grid-layout-tests.lisp
;;; Tests for Grid Layout System
;;;===============================================================

(uiop:define-package :elmtui-grid-layout-tests
  (:use :cl :fiveam :alexandria) 
  ;; Import grid layout components
  (:import-from :elmtui.view.grid-layout
                #:make-grid
                #:make-grid-item
                #:grid-template
                #:grid-area
                #:grid-auto-flow
                #:grid-responsive
                #:compute-grid-layout
                #:define-grid-template
                #:get-grid-area-coordinates
                #:render-grid-template
                #:build-grid-from-template))
(in-package :elmtui-grid-layout-tests)

(def-suite grid-layout-tests
  :description "Tests for the grid layout system implementation")

(in-suite grid-layout-tests)

;;;-----------------------------------------------------------------------------
;;; Basic Grid Tests
;;;-----------------------------------------------------------------------------

(test grid-template-parsing
  "Test parsing grid template strings"
  (let* ((template-str "header header . | sidebar main main | footer footer footer")
         (parsed (elmtui.view.grid-layout::parse-grid-template template-str)))
    (is (= (length parsed) 3) "Should have 3 rows")
    (is (equal (first parsed) '("header" "header" ".")) "First row should have header header .")
    (is (equal (second parsed) '("sidebar" "main" "main")) "Second row should have sidebar main main")
    (is (equal (third parsed) '("footer" "footer" "footer")) "Third row should have footer footer footer")))

(test grid-template-creation
  "Test creating grid templates"
  (let* ((rows '("auto" "1fr" "30px"))
         (columns '("1fr" "2fr" "1fr"))
         (areas "header header . | sidebar main main | footer footer footer")
         (template (grid-template rows columns :areas areas)))
    
    (is (equal (getf template :grid-template-rows) rows) "Rows should match")
    (is (equal (getf template :grid-template-columns) columns) "Columns should match")
    (is (listp (getf template :grid-template-areas)) "Areas should be parsed into a list")
    (is (= (length (getf template :grid-template-areas)) 3) "Areas should have 3 rows")))

;;;-----------------------------------------------------------------------------
;;; Named Areas Tests
;;;-----------------------------------------------------------------------------

(test grid-named-areas-definition
  "Test defining a grid template with named areas"
  (let* ((rows '("auto" "1fr" "30px"))
         (columns '("1fr" "2fr" "1fr"))
         (areas "header header header | sidebar main main | footer footer footer")
         (template (define-grid-template :dashboard rows columns areas)))
    
    (is (eq (elmtui.view.grid-layout::grid-template-definition-name template) :dashboard)
        "Template name should be :dashboard")
    
    ;; Check area coordinates mapping
    (let ((header-coords (get-grid-area-coordinates template "header"))
          (sidebar-coords (get-grid-area-coordinates template "sidebar"))
          (main-coords (get-grid-area-coordinates template "main"))
          (footer-coords (get-grid-area-coordinates template "footer")))
      
      (is (= (getf header-coords :row-start) 1) "Header should start at row 1")
      (is (= (getf header-coords :col-start) 1) "Header should start at column 1")
      (is (= (getf header-coords :col-end) 4) "Header should span 3 columns")
      
      (is (= (getf sidebar-coords :row-start) 2) "Sidebar should start at row 2")
      (is (= (getf sidebar-coords :col-start) 1) "Sidebar should start at column 1")
      
      (is (= (getf main-coords :row-start) 2) "Main should start at row 2")
      (is (= (getf main-coords :col-start) 2) "Main should start at column 2")
      (is (= (getf main-coords :col-end) 4) "Main should span 2 columns")
      
      (is (= (getf footer-coords :row-start) 3) "Footer should start at row 3")
      (is (= (getf footer-coords :row-end) 4) "Footer should end at row 4")
      (is (= (getf footer-coords :col-end) 4) "Footer should span 3 columns"))))

(test build-grid-from-template
  "Test building a complete grid from a template"
  (let* ((rows '("auto" "1fr" "30px"))
         (columns '("1fr" "2fr" "1fr"))
         (areas "header header header | sidebar main main | footer footer footer")
         (template (define-grid-template :dashboard rows columns areas))
         
         ;; Create some dummy child elements for each area
         (header (list :type :header :props '(:text "Dashboard Header")))
         (sidebar (list :type :div :props '(:text "Navigation")))
         (main (list :type :div :props '(:text "Main Content")))
         (footer (list :type :footer :props '(:text "Footer")))
         
         ;; Map children to areas
         (children `(("header" . ,header)
                     ("sidebar" . ,sidebar)
                     ("main" . ,main)
                     ("footer" . ,footer)))
         
         ;; Build the grid
         (grid (build-grid-from-template template children :gap 10)))
    
    (is (eq (getf grid :type) :div) "Grid should be a div element")
    (is (getf (getf grid :props) :display) :grid) "Grid should have display:grid"
    (is (= (length (getf grid :children)) 4) "Grid should have 4 children")
    
    ;; Check that grid area properties were added to children
    (let ((header-child (find :header (getf grid :children) :key (lambda (c) (getf c :type))))
          (main-child (find-if (lambda (c) 
                                 (equal (getf (getf c :props) :text) "Main Content"))
                               (getf grid :children))))
      
      (is (not (null header-child)) "Header child should exist")
      (is (not (null main-child)) "Main child should exist")
      
      (is (= (getf (getf header-child :props) :row-start) 1) 
          "Header should have row-start 1")
      (is (= (getf (getf main-child :props) :col-start) 2)
          "Main should have col-start 2")
      (is (= (getf (getf main-child :props) :col-end) 4)
          "Main should have col-end 4"))))

;;;-----------------------------------------------------------------------------
;;; Layout Computation Tests
;;;-----------------------------------------------------------------------------

(test compute-grid-layout-basic
  "Test basic grid layout computation"
  (let* ((container-width 600)
         (container-height 400)
         (grid-props (list :grid-template-rows '("auto" "1fr" "50px")
                           :grid-template-columns '("1fr" "2fr" "1fr")
                           :gap 10))
         (children (list (list :props (list :grid-row-start 1 :grid-column-start 1))
                         (list :props (list :grid-row-start 1 :grid-column-start 2
                                            :grid-column-end 4))
                         (list :props (list :grid-row-start 2 :grid-row-end 4
                                            :grid-column-start 1))))
         
         ;; Compute layout
         (layout (compute-grid-layout container-width container-height grid-props children)))
    
    (is (= (getf layout :container-width) container-width) "Container width should match")
    (is (= (getf layout :container-height) container-height) "Container height should match")
    (is (= (getf layout :num-rows) 3) "Should have 3 rows")
    (is (= (getf layout :num-columns) 3) "Should have 3 columns")
    
    ;; Check the computed layouts
    (let ((child-layouts (getf layout :child-layouts)))
      (is (= (length child-layouts) 3) "Should have 3 child layouts")
      
      ;; First child at row 1, col 1
      (let ((first-child (first child-layouts)))
        (is (= (getf first-child :row-start) 1) "First child should start at row 1")
        (is (= (getf first-child :col-start) 1) "First child should start at col 1"))
      
      ;; Second child spanning cols 2-4 in row 1
      (let ((second-child (second child-layouts)))
        (is (= (getf second-child :row-start) 1) "Second child should start at row 1")
        (is (= (getf second-child :col-start) 2) "Second child should start at col 2")
        (is (= (getf second-child :col-end) 4) "Second child should end at col 4")))))

(test compute-grid-layout-with-named-areas
  "Test grid layout computation with named areas"
  (let* ((container-width 600)
         (container-height 400)
         (areas '(("header" "header" "header")
                  ("sidebar" "main" "main")
                  ("footer" "footer" "footer")))
         (grid-props (list :grid-template-rows '("auto" "1fr" "50px")
                           :grid-template-columns '("1fr" "2fr" "1fr")
                           :grid-template-areas areas
                           :gap 10))
         (children (list (list :props (list :grid-area "header"))
                         (list :props (list :grid-area "sidebar"))
                         (list :props (list :grid-area "main"))
                         (list :props (list :grid-area "footer"))))
         
         ;; Compute layout
         (layout (compute-grid-layout container-width container-height grid-props children)))
    
    ;; Check the computed layouts for named areas
    (let ((child-layouts (getf layout :child-layouts)))
      (is (= (length child-layouts) 4) "Should have 4 child layouts")
      
      ;; Find layouts by area
      (let ((header-layout (find 1 child-layouts :key (lambda (c) (getf c :row-start))))
            (sidebar-layout (find-if (lambda (c) 
                                       (and (= (getf c :row-start) 2)
                                            (= (getf c :col-start) 1)))
                                     child-layouts))
            (main-layout (find-if (lambda (c)
                                    (and (= (getf c :row-start) 2)
                                         (= (getf c :col-start) 2)))
                                  child-layouts))
            (footer-layout (find 3 child-layouts :key (lambda (c) (getf c :row-start)))))
        
        (is (not (null header-layout)) "Header layout should exist")
        (is (not (null sidebar-layout)) "Sidebar layout should exist")
        (is (not (null main-layout)) "Main layout should exist")
        (is (not (null footer-layout)) "Footer layout should exist")
        
        ;; Check header spans full width
        (is (= (getf header-layout :col-start) 1) "Header should start at column 1")
        (is (= (getf header-layout :col-end) 4) "Header should end at column 4")
        
        ;; Check sidebar is in first column of second row
        (is (= (getf sidebar-layout :col-start) 1) "Sidebar should start at column 1")
        (is (= (getf sidebar-layout :col-end) 2) "Sidebar should end at column 2")
        
        ;; Check main spans two columns
        (is (= (getf main-layout :col-start) 2) "Main should start at column 2")
        (is (= (getf main-layout :col-end) 4) "Main should end at column 4")
        
        ;; Check footer spans full width in last row
        (is (= (getf footer-layout :col-start) 1) "Footer should start at column 1")
        (is (= (getf footer-layout :col-end) 4) "Footer should end at column 4")))))

;;;-----------------------------------------------------------------------------
;;; Run Tests
;;;-----------------------------------------------------------------------------

;; (def-test-run :grid-layout-tests
;;     (run! 'grid-layout-tests))
