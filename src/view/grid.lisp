;;;===============================================================
;;; File: src/view/grid.lisp
;;; CSS Grid Layout Implementation
;;;===============================================================
(uiop:define-package :elmtui.view.layout.grid
  (:use :cl)
  (:nicknames :et.grid)
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:make-rectangle #:make-pos #:make-size
                #:rectangle-pos #:rectangle-size
                #:dx! #:dy! #:valid-p)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value)
  (:import-from :elmtui.view.layout.flex
                #:get-item-margin #:get-item-padding #:get-item-space)
  (:export
   ;; Grid Container
   #:grid-container #:grid-item #:layout-grid-container
   ;; Grid Properties
   #:grid-template-areas #:grid-template-columns #:grid-template-rows
   #:grid-auto-columns #:grid-auto-rows #:grid-auto-flow
   #:grid-column-gap #:grid-row-gap #:grid-gap
   ;; Item Properties
   #:grid-column-start #:grid-column-end #:grid-row-start #:grid-row-end
   #:grid-column #:grid-row #:grid-area
   ;; Track Sizing
   #:fr #:minmax #:auto
   ;; Layout Functions
   #:layout-grid #:create-grid-template))

(in-package :elmtui.view.layout.grid)

;;;-----------------------------------------------------------------------------
;;; Grid Track Size Types
;;;-----------------------------------------------------------------------------

(deftype track-size ()
  '(or number ; Fixed size in units
       (member :auto :min-content :max-content) ; Keywords
       cons)) ; Complex values like (fr 1) or (minmax 100 :auto)

(defun fr (n)
  "Create a fractional track size."
  (cons :fr n))

(defun minmax (min max)
  "Create a minmax track size."
  (list :minmax min max))

(defun auto ()
  "Auto track size."
  :auto)

;;;-----------------------------------------------------------------------------
;;; Grid Container Properties
;;;-----------------------------------------------------------------------------

(defclass grid-container ()
  ((grid-template-areas
    :initarg :grid-template-areas
    :initform nil
    :accessor grid-template-areas)
   (grid-template-columns
    :initarg :grid-template-columns
    :initform '(:auto)
    :accessor grid-template-columns
    :type list)
   (grid-template-rows
    :initarg :grid-template-rows
    :initform '(:auto)
    :accessor grid-template-rows
    :type list)
   (grid-auto-columns
    :initarg :grid-auto-columns
    :initform :auto
    :accessor grid-auto-columns
    :type track-size)
   (grid-auto-rows
    :initarg :grid-auto-rows
    :initform :auto
    :accessor grid-auto-rows
    :type track-size)
   (grid-auto-flow
    :initarg :grid-auto-flow
    :initform :row
    :accessor grid-auto-flow
    :type (member :row :column :row-dense :column-dense))
   (grid-column-gap
    :initarg :grid-column-gap
    :initform 0
    :accessor grid-column-gap
    :type number)
   (grid-row-gap
    :initarg :grid-row-gap
    :initform 0
    :accessor grid-row-gap
    :type number)
   ;; Internal layout state
   (grid-tracks
    :initform nil
    :accessor grid-tracks)
   (grid-lines
    :initform nil
    :accessor grid-lines)))

;;;-----------------------------------------------------------------------------
;;; Grid Item Properties
;;;-----------------------------------------------------------------------------

(defclass grid-item ()
  ((grid-column-start
    :initarg :grid-column-start
    :initform :auto
    :accessor grid-column-start)
   (grid-column-end
    :initarg :grid-column-end
    :initform :auto
    :accessor grid-column-end)
   (grid-row-start
    :initarg :grid-row-start
    :initform :auto
    :accessor grid-row-start)
   (grid-row-end
    :initarg :grid-row-end
    :initform :auto
    :accessor grid-row-end)
   (grid-area
    :initarg :grid-area
    :initform nil
    :accessor grid-area)))

;;;-----------------------------------------------------------------------------
;;; Style Property Extraction
;;;-----------------------------------------------------------------------------

(defun parse-track-size (value)
  "Parse a track size specification from a style value."
  (cond
    ((numberp value) value)
    ((keywordp value) value)
    ((and (consp value) (eq (car value) :fr))
     (fr (cadr value)))
    ((and (consp value) (eq (car value) :minmax))
     (minmax (cadr value) (caddr value)))
    (t :auto)))

(defun extract-grid-template-areas (node)
  "Extract grid-template-areas from style."
  (when (typep node 'styled-ui-node)
    (style-value node :grid-template-areas nil)))

(defun extract-grid-template-columns (node)
  "Extract grid-template-columns from style."
  (when (typep node 'styled-ui-node)
    (mapcar #'parse-track-size
            (style-value node :grid-template-columns '(:auto)))))

(defun extract-grid-template-rows (node)
  "Extract grid-template-rows from style."
  (when (typep node 'styled-ui-node)
    (mapcar #'parse-track-size
            (style-value node :grid-template-rows '(:auto)))))

;;;-----------------------------------------------------------------------------
;;; Grid Layout Implementation
;;;-----------------------------------------------------------------------------

(defun calculate-track-sizes (tracks available-space)
  "Calculate actual sizes for grid tracks.
   - Fixed sizes are used as-is
   - Auto sizes are based on content
   - FR units share remaining space proportionally"
  (let* ((fixed-sizes (loop for track in tracks
                            when (numberp track)
                            sum track))
         (remaining-space (- available-space fixed-sizes))
         (fr-total (loop for track in tracks
                         when (and (consp track) (eq (car track) :fr))
                         sum (cdr track)))
         (calculated-sizes
          (loop for track in tracks
                collect
                  (cond
                    ((numberp track) track) ; Fixed size
                    ((and (consp track) (eq (car track) :fr))
                     (* remaining-space (/ (cdr track) fr-total))) ; FR size
                    (t 0))))) ; Default to 0 for unsupported types
    calculated-sizes))

(defun place-grid-items (container items)
  "Place items in the grid based on their grid-area/position properties.
   Returns a list of placed items with their final positions."
  (let ((grid-template-areas (grid-template-areas container))
        (column-gap (grid-column-gap container))
        (row-gap (grid-row-gap container)))
    (loop for item in items
          collect
            (let* ((column-start (or (grid-column-start item) 1))
                   (column-end (or (grid-column-end item) (+ column-start 1)))
                   (row-start (or (grid-row-start item) 1))
                   (row-end (or (grid-row-end item) (+ row-start 1)))
                   (width (- column-end column-start))
                   (height (- row-end row-start)))
              (make-instance 'grid-item
                             :grid-column-start column-start
                             :grid-column-end column-end
                             :grid-row-start row-start
                             :grid-row-end row-end
                             :width width
                             :height height)))))

(defun create-grid-template (container items template &key areas column-sizes row-sizes)
  "Create a grid layout using CSS Grid-like template syntax.
   - TEMPLATE is a list of lists defining the grid structure
   - AREAS maps area names to actual items
   - COLUMN-SIZES and ROW-SIZES define track sizes"
  (let* ((column-sizes (calculate-track-sizes column-sizes (w (rectangle container))))
         (row-sizes (calculate-track-sizes row-sizes (h (rectangle container))))
         (area-map (make-hash-table :test 'equal)))
    ;; Map area names to items
    (dolist (item items)
      (when-let ((area (grid-area item)))
        (setf (gethash area area-map) item)))
    ;; Assign positions based on template
    (loop for row across template
          for row-index from 0
          do (loop for area in row
                   for col-index from 0
                   do (when-let ((item (gethash area area-map)))
                        (setf (grid-row-start item) row-index
                              (grid-row-end item) (+ row-index 1)
                              (grid-column-start item) col-index
                              (grid-column-end item) (+ col-index 1)))))
    items))

(defun layout-grid (container items &key template areas column-sizes row-sizes)
  "Layout ITEMS in CONTAINER using grid layout.
   If TEMPLATE is provided, uses template-based layout, otherwise uses auto-placement."
  (if template
      (create-grid-template container items template
                           :areas areas
                           :column-sizes column-sizes
                           :row-sizes row-sizes)
      (layout-grid-auto container items)))

(defun layout-grid-auto (container items)
  "Layout items using grid auto-placement algorithm."
  (let ((column-gap (grid-column-gap container))
        (row-gap (grid-row-gap container))
        (columns (grid-template-columns container))
        (rows (grid-template-rows container))
        (current-column 0)
        (current-row 0))
    (loop for item in items
          do
            (when (>= current-column (length columns))
              (setf current-column 0
                    current-row (1+ current-row)))
            (setf (grid-column-start item) current-column
                  (grid-column-end item) (+ current-column 1)
                  (grid-row-start item) current-row
                  (grid-row-end item) (+ current-row 1))
            (incf current-column))
    items))

(defun layout-grid-container (container)
  "Top-level grid layout function. Returns laid out container."
  ;; TODO: Implement main grid layout function
  container)
