(defpackage :elmtui.ui.widgets.table
  (:use :cl)
  (:export :table
           :make-table
           :deftable
           :define-column))

(in-package :elmtui.ui.widgets.table)

;; Import from internal modules
(defvar *view-fn* nil "Dynamic view rendering function")

;; Column definition
(defstruct column
  (id nil :type (or symbol string))
  (title "" :type string)
  (width nil)
  (min-width 1 :type integer)
  (max-width nil)
  (align :left :type (member :left :center :right))
  (formatter #'identity :type function)
  (sortable t :type boolean)
  (style nil))

;; Table props structure
(defstruct table-props
  (columns nil :type list)
  (data nil :type list)
  (selected-row nil)
  (sort-column nil)
  (sort-direction :asc :type (member :asc :desc))
  (header-style nil)
  (row-style nil)
  (zebra-striping nil :type boolean)
  (bordered nil :type boolean)
  (on-select nil :type (or null function))
  (on-sort nil :type (or null function))
  (pagination nil)
  (fixed-header nil :type boolean))

;; Table component - functional approach
(defun table (&key columns data (selected-row nil) (sort-column nil) (sort-direction :asc)
                   header-style row-style (zebra-striping t) (bordered t)
                   on-select on-sort pagination (fixed-header t))
  "Create a table component with the given properties.
   COLUMNS        - List of column definitions
   DATA           - List of rows (each row is a list or alist)
   SELECTED-ROW   - Index of the currently selected row
   SORT-COLUMN    - ID of the column to sort by
   SORT-DIRECTION - Direction to sort (:asc or :desc)
   HEADER-STYLE   - Style to apply to the header row
   ROW-STYLE      - Style or function to apply to data rows
   ZEBRA-STRIPING - Whether to apply alternating styles to rows
   BORDERED       - Whether to show cell borders
   ON-SELECT      - Function to call when a row is selected
   ON-SORT        - Function to call when a column is sorted
   PAGINATION     - Pagination configuration
   FIXED-HEADER   - Whether the header should remain visible when scrolling"
  (let ((props (make-table-props
                :columns columns
                :data data
                :selected-row selected-row
                :sort-column sort-column
                :sort-direction sort-direction
                :header-style header-style
                :row-style row-style
                :zebra-striping zebra-striping
                :bordered bordered
                :on-select on-select
                :on-sort on-sort
                :pagination pagination
                :fixed-header fixed-header)))
    (funcall *view-fn* :table props nil)))

;; Helper function to create a column
(defun define-column (id title &key width min-width max-width (align :left) formatter (sortable t) style)
  "Define a table column"
  (make-column :id id
               :title title
               :width width
               :min-width (or min-width 1)
               :max-width max-width
               :align align
               :formatter (or formatter #'identity)
               :sortable sortable
               :style style))

;; Define a reusable table component
(defmacro deftable (name args &body body)
  "Define a reusable table component"
  `(defun ,name ,args
     (table ,@body)))

;; Example usage:
#|
(deftable user-table (users &key (selected-user-id nil))
  :columns (list 
            (define-column :id "ID" :width 5)
            (define-column :name "Name" :min-width 15)
            (define-column :email "Email Address" :min-width 25)
            (define-column :role "Role" :width 10))
  :data users
  :selected-row (position selected-user-id users :key #'user-id)
  :on-select (lambda (row) (select-user (nth row users)))
  :zebra-striping t
  :bordered t)
|#
