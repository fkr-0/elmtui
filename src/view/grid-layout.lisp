;;;===============================================================
;;; File: src/view/grid-layout.lisp
;;; CSS Grid Layout Implementation for ELMTUI
;;;===============================================================
(uiop:define-package :elmtui.view.grid-layout
  (:use :cl :str)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:export
   #:make-grid
   #:make-grid-item
   #:grid-template
   #:grid-area
   #:grid-auto-flow
   #:grid-responsive
   #:compute-grid-layout
   ;; New exports for named areas
   #:define-grid-template
   #:get-grid-area-coordinates
   #:render-grid-template
   #:build-grid-from-template))
(in-package :elmtui.view.grid-layout)

;;;-----------------------------------------------------------------------------
;;; Grid Layout System
;;;-----------------------------------------------------------------------------

(defun parse-grid-template (template)
  "Parse a grid template string into a structured representation.
   Example: \"header header . | sidebar main main | footer footer footer\"
   Returns a list of rows, each containing column names."
  (let* ((rows (str:split "|" template))
         (parsed-rows
           (mapcar (lambda (row)
                     (remove ""
                             (mapcar (lambda (s)
                                       (if (string= s ".")
                                           nil
                                           (str:trim s)))
                                     (str:split " " row))
                             :test #'string=))
                   rows)))
    parsed-rows))

(defun grid-template (rows columns &key areas)
  "Create a grid template configuration.
   ROWS: List of row heights (e.g., '(\"auto\" \"1fr\" \"30\"))
   COLUMNS: List of column widths (e.g., '(\"1fr\" \"2fr\" \"1fr\"))
   AREAS: Grid template areas string or parsed representation.
   Returns a plist with grid template properties."
  (let ((parsed-areas (if (stringp areas)
                          (parse-grid-template areas)
                          areas)))
    (list :grid-template-rows rows
          :grid-template-columns columns
          :grid-template-areas parsed-areas)))

(defun grid-area (name &key row-start row-end col-start col-end)
  "Create a grid area configuration.
   NAME: Named grid area to place item in.
   ROW-START, ROW-END, COL-START, COL-END: Grid line numbers for placement.
   Returns a plist with grid area properties."
  (let ((props nil))
    (when name
      (setf props (list* :grid-area name props)))
    (when row-start
      (setf props (list* :grid-row-start row-start props)))
    (when row-end
      (setf props (list* :grid-row-end row-end props)))
    (when col-start
      (setf props (list* :grid-column-start col-start props)))
    (when col-end
      (setf props (list* :grid-column-end col-end props)))
    props))

(defun grid-auto-flow (direction &key dense)
  "Create a grid auto-flow configuration.
   DIRECTION: Flow direction (:row, :column, :row-dense, :column-dense).
   DENSE: Whether to use dense packing algorithm.
   Returns the grid-auto-flow property value."
  (if dense
      (format nil "~A dense" (string-downcase direction))
      (string-downcase direction)))

(defun grid-responsive (base-config breakpoints)
  "Create a responsive grid configuration.
   BASE-CONFIG: Default grid configuration for all viewport sizes.
   BREAKPOINTS: Alist mapping viewport width thresholds to grid configurations.
   Example: ((600 . (:grid-template-columns (\"1fr\")))
             (1200 . (:grid-template-columns (\"1fr\" \"1fr\" \"1fr\"))))
   Returns a plist with responsive grid properties."
  (list :grid-base-config base-config
        :grid-breakpoints breakpoints))

(defun make-grid-item (&key area row-start row-end col-start col-end align-self justify-self)
  "Create a grid item configuration.
   AREA: Named grid area to place item in.
   ROW-START, ROW-END, COL-START, COL-END: Grid line numbers for placement.
   ALIGN-SELF, JUSTIFY-SELF: Alignment within grid cell.
   Returns a plist with grid item properties."
  (let ((props (grid-area area
                          :row-start row-start
                          :row-end row-end
                          :col-start col-start
                          :col-end col-end)))
    (when align-self
      (setf props (list* :align-self (string-downcase align-self) props)))
    (when justify-self
      (setf props (list* :justify-self (string-downcase justify-self) props)))
    props))

;;;-----------------------------------------------------------------------------
;;; Enhanced Named Areas System
;;;-----------------------------------------------------------------------------

(defstruct (grid-template-definition (:constructor %make-grid-template-definition))
  "Structure for a complete grid template definition with named areas"
  (name nil :type symbol :read-only t)
  (rows nil :type list :read-only t)
  (columns nil :type list :read-only t)
  (areas nil :type list :read-only t)
  (area-map (make-hash-table :test 'equal) :type hash-table))

(defun define-grid-template (name rows columns areas)
  "Define a named grid template with area mappings.
   NAME: Symbol to identify this template
   ROWS: List of row heights (e.g., '(\"auto\" \"1fr\" \"30\"))
   COLUMNS: List of column widths (e.g., '(\"1fr\" \"2fr\" \"1fr\"))
   AREAS: Grid template areas string (will be parsed)
   Returns a grid-template-definition structure."
  (let* ((parsed-areas (if (stringp areas)
                           (parse-grid-template areas)
                           areas))
         (template (%make-grid-template-definition
                    :name name
                    :rows rows
                    :columns columns
                    :areas parsed-areas))
         (area-map (grid-template-definition-area-map template)))

    ;; Build map of area name -> coordinates
    (loop for row-index from 0 below (length parsed-areas)
          for row in parsed-areas
          do (loop for col-index from 0 below (length row)
                   for area = (nth col-index row)
                   when (and area (not (string= area ".")))
                     do (multiple-value-bind (start-row start-col end-row end-col)
                            (compute-area-bounds parsed-areas row-index col-index area)
                          (setf (gethash area area-map)
                                (list :row-start (1+ start-row)
                                      :col-start (1+ start-col)
                                      :row-end (1+ end-row)
                                      :col-end (1+ end-col))))))
    template))

(defun compute-area-bounds (areas row col area-name)
  "Compute the bounds of a named area in the grid template.
   Returns (values start-row start-col end-row end-col)"
  (let ((start-row row)
        (start-col col)
        (end-row row)
        (end-col col)
        (num-rows (length areas))
        (num-cols (length (first areas))))

    ;; Find the top-left corner (should be row,col)
    ;; Find bottom-right corner by scanning right and down

    ;; Scan right to find width
    (loop for c from col below num-cols
          while (and (< c (length (nth row areas)))
                     (string= (nth c (nth row areas)) area-name))
          do (setf end-col c))

    ;; Scan down to find height
    (loop for r from row below num-rows
          while (and (< r num-rows)
                     (< col (length (nth r areas)))
                     (string= (nth col (nth r areas)) area-name))
          do (setf end-row r))

    (values start-row start-col end-row end-col)))

(defun get-grid-area-coordinates (template area-name)
  "Get the grid coordinates for a named area in a template.
   TEMPLATE: A grid-template-definition structure
   AREA-NAME: String name of the area
   Returns a plist with :row-start, :col-start, :row-end, :col-end keys"
  (gethash area-name (grid-template-definition-area-map template)))

(defun render-grid-template (template)
  "Render a grid template as an ASCII representation for debugging/visualization.
   TEMPLATE: A grid-template-definition structure
   Returns a multi-line string visualization"
  (let* ((areas (grid-template-definition-areas template))
         (num-rows (length areas))
         (num-cols (apply #'max (mapcar #'length areas)))
         (result-lines nil))

    ;; Add header line with column numbers
    (push (format nil "   ~{~2d~}" (loop for i from 1 to num-cols collect i)) result-lines)
    (push (format nil "  ~v@{~A~:*~}" (+ (* 2 num-cols) 1) "-") result-lines)

    ;; Add rows with row numbers
    (loop for row-index from 0 below num-rows
          for row in areas
          do (push (format nil "~2d|~{~2a~}"
                           (1+ row-index)
                           (loop for col-index from 0 below num-cols
                                 collect (if (and (< col-index (length row))
                                                  (nth col-index row)
                                                  (not (string= (nth col-index row) ".")))
                                             (char (nth col-index row) 0)
                                             " ")))
                   result-lines))

    (reverse result-lines)))

(defun build-grid-from-template (template children &key gap row-gap column-gap justify-items align-items)
  "Build a complete grid layout using a template definition.
   TEMPLATE: A grid-template-definition structure
   CHILDREN: Alist mapping area names to child elements, or a list of child elements
             If a list, children must have :grid-area property in their props
   Returns a grid element"
  (let* ((rows (grid-template-definition-rows template))
         (columns (grid-template-definition-columns template))
         (areas (grid-template-definition-areas template))
         (child-elements
           ;; Convert from alist if provided as such
           (if (and (consp (car children))
                    (consp (caar children)))
               (loop for (area-name . element) in children
                     for coords = (get-grid-area-coordinates template area-name)
                     when coords
                       collect (let ((props (append coords (getf element :props))))
                                 (setf (getf element :props) props)
                                 element))
               ;; Otherwise, assume children already have grid-area properties
               children)))

    (make-grid :template-rows rows
               :template-columns columns
               :template-areas areas
               :gap gap
               :row-gap row-gap
               :column-gap column-gap
               :justify-items justify-items
               :align-items align-items
               :children child-elements)))

(defun grid-position-to-coordinates (position grid-width)
  "Convert a linear position to row/column coordinates in a grid.
   POSITION: Linear position (zero-based).
   GRID-WIDTH: Number of columns in the grid.
   Returns (values row col) coordinates."
  (values (floor position grid-width) (mod position grid-width)))

(defun make-grid (&key template-rows template-columns template-areas
                    auto-flow gap row-gap column-gap
                    justify-content align-content
                    justify-items align-items
                    children)
  "Create a grid container with the specified properties.
   TEMPLATE-ROWS: Grid template rows specification.
   TEMPLATE-COLUMNS: Grid template columns specification.
   TEMPLATE-AREAS: Grid template areas specification.
   AUTO-FLOW: Grid auto-flow property.
   GAP, ROW-GAP, COLUMN-GAP: Grid gap properties.
   JUSTIFY-CONTENT, ALIGN-CONTENT: Container alignment properties.
   JUSTIFY-ITEMS, ALIGN-ITEMS: Default item alignment properties.
   CHILDREN: Child elements to place in the grid.
   Returns a styled-node representing the grid."
  (let ((grid-props
          (list :display :grid)))

    ;; Add grid template properties
    (when template-rows
      (setf grid-props (list* :grid-template-rows template-rows grid-props)))

    (when template-columns
      (setf grid-props (list* :grid-template-columns template-columns grid-props)))

    (when template-areas
      (setf grid-props (list* :grid-template-areas
                              (if (stringp template-areas)
                                  (parse-grid-template template-areas)
                                  template-areas)
                              grid-props)))

    ;; Add grid flow and gap properties
    (when auto-flow
      (setf grid-props (list* :grid-auto-flow auto-flow grid-props)))

    (when gap
      (setf grid-props (list* :gap gap grid-props)))

    (when row-gap
      (setf grid-props (list* :row-gap row-gap grid-props)))

    (when column-gap
      (setf grid-props (list* :column-gap column-gap grid-props)))

    ;; Add alignment properties
    (when justify-content
      (setf grid-props (list* :justify-content justify-content grid-props)))

    (when align-content
      (setf grid-props (list* :align-content align-content grid-props)))

    (when justify-items
      (setf grid-props (list* :justify-items justify-items grid-props)))

    (when align-items
      (setf grid-props (list* :align-items align-items grid-props)))

    ;; Create the grid element
    (make-styled-node
     :type :div
     :props grid-props
     :children children)))

;;;-----------------------------------------------------------------------------
;;; Grid Layout Computation
;;;-----------------------------------------------------------------------------

(defun find-named-area-coordinates (template-areas area-name)
  "Finds the coordinates of a named area within a parsed template-areas structure.
   TEMPLATE-AREAS: A list of lists, where each inner list represents a row
                   and contains strings (area names) or NIL.
   AREA-NAME: The string name of the area to find.
   Returns (values coordinates found-p), where coordinates is a plist
   :row-start, :col-start, :row-end, :col-end (1-based)."
  (loop for r from 0 below (length template-areas)
        for row = (nth r template-areas)
        do (loop for c from 0 below (length row)
                 for current-cell-name = (nth c row)
                 when (and current-cell-name (string= current-cell-name area-name))
                   do (multiple-value-bind (start-row start-col end-row end-col)
                          (compute-area-bounds template-areas r c area-name)
                        (return-from find-named-area-coordinates
                          (values (list :row-start (1+ start-row)
                                        :col-start (1+ start-col)
                                        :row-end (1+ end-row)
                                        :col-end (1+ end-col))
                                  t)))))
  (values nil nil))

(defun compute-grid-layout (container-width container-height grid-props children)
  "Compute the layout for a grid container and its children.
   CONTAINER-WIDTH: Available width for the grid.
   CONTAINER-HEIGHT: Available height for the grid.
   GRID-PROPS: Property list containing grid configuration.
   CHILDREN: List of children to layout.
   Returns a plist with computed layout information for the grid and its children."

  ;; Parse grid templates
  (let* ((template-rows (getf grid-props :grid-template-rows '("auto")))
         (template-columns (getf grid-props :grid-template-columns '("1fr")))
         (template-areas (getf grid-props :grid-template-areas nil))
         (auto-flow (getf grid-props :grid-auto-flow "row"))
         (dense-packing (search "dense" auto-flow))
         (flow-direction (if (search "column" auto-flow) :column :row))

         ;; Parse gap values
         (gap (getf grid-props :gap 0))
         (row-gap (getf grid-props :row-gap gap))
         (column-gap (getf grid-props :column-gap gap))

         ;; Initialize layout calculations
         (num-columns (length template-columns))
         (num-rows (length template-rows))
         (explicit-placements 0)
         (auto-placements 0)
         (row-sizes nil)
         (column-sizes nil)
         (child-layouts nil))

    ;; First pass: Calculate track sizes based on template
    ;; In a real implementation, this would involve computing fractions, auto sizes, etc.
    ;; For simplicity, we just distribute available space evenly
    (setf column-sizes
          (if (= num-columns 1)
              (list container-width)
              (let ((available-space (- container-width (* column-gap (1- num-columns)))))
                (loop repeat num-columns collect (/ available-space num-columns)))))

    (setf row-sizes
          (if (= num-rows 1)
              (list container-height)
              (let ((available-space (- container-height (* row-gap (1- num-rows)))))
                (loop repeat num-rows collect (/ available-space num-rows)))))

    ;; Second pass: Place items according to their grid properties
    (loop for child in children
          for props = (if (elmtui.view.core:ui-node-p child)
                          (elmtui.view.api:ui-node-props child)
                          (when (typep child 'hash-table) ; Fallback for other possible formats
                            (gethash :props child)))
          for grid-area = (getf props :grid-area)
          for row-start = (getf props :grid-row-start)
          for row-end = (getf props :grid-row-end)
          for col-start = (getf props :grid-column-start)
          for col-end = (getf props :grid-column-end)

          ;; Track whether this item has explicit placement
          do (if (or grid-area row-start col-start)
                 (incf explicit-placements)
                 (incf auto-placements))

             ;; Calculate actual placement with support for named areas
          collect (let ((r-start nil)
                        (r-end nil)
                        (c-start nil)
                        (c-end nil)
                        (x 0)
                        (y 0)
                        (width 0)
                        (height 0))

                    ;; If we have a named area, look it up in the template-areas
                    (when (and grid-area template-areas)
                      (multiple-value-bind (area-coords found)
                          (find-named-area-coordinates template-areas grid-area)
                        (when found
                          (setf r-start (getf area-coords :row-start)
                                r-end (getf area-coords :row-end)
                                c-start (getf area-coords :col-start)
                                c-end (getf area-coords :col-end)))))

                    ;; If no area found or direct coordinates were provided, use those
                    (setf r-start (or r-start row-start 1)
                          r-end (or r-end row-end (1+ (or r-start 1)))
                          c-start (or c-start col-start 1)
                          c-end (or c-end col-end (1+ (or c-start 1))))

                    ;; Calculate position and size from grid lines
                    (setf x (if (> c-start 0)
                                (+ (reduce #'+ (subseq column-sizes 0 (1- c-start)))
                                   (* column-gap (1- c-start)))
                                0))

                    (setf y (if (> r-start 0)
                                (+ (reduce #'+ (subseq row-sizes 0 (1- r-start)))
                                   (* row-gap (1- r-start)))
                                0))

                    (setf width (- (+ (reduce #'+ (subseq column-sizes (1- c-start) (1- c-end)))
                                      (* column-gap (- c-end c-start)))
                                   column-gap))

                    (setf height (- (+ (reduce #'+ (subseq row-sizes (1- r-start) (1- r-end)))
                                       (* row-gap (- r-end r-start)))
                                    row-gap))

                    ;; Create layout entry
                    (list :x x
                          :y y
                          :width width
                          :height height
                          :row-start r-start
                          :row-end r-end
                          :col-start c-start
                          :col-end c-end))
            into layouts

          finally (setf child-layouts layouts))

    ;; Return the layout information
    (list :container-width container-width
          :container-height container-height
          :num-rows num-rows
          :num-columns num-columns
          :row-sizes row-sizes
          :column-sizes column-sizes
          :row-gap row-gap
          :column-gap column-gap
          :flow-direction flow-direction
          :dense-packing dense-packing
          :explicit-placements explicit-placements
          :auto-placements auto-placements
          :child-layouts child-layouts)))
