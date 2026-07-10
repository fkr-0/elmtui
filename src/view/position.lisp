;;;===============================================================
;;; File: src/view/position.lisp
;;; UI Element Position Tracking System
;;;
;;; This module provides structures and utilities for tracking
;;; the positions of UI elements in both absolute coordinates
;;; and grid-based layouts. It's used by the focus management
;;; system and can be used by other systems that need to know
;;; where elements are positioned.
;;;===============================================================

(uiop:define-package :elmtui.view.position
  (:use :cl :log4cl)
  (:export
   ;; Position structures and accessors
   #:element-position
   #:make-element-position
   #:element-position-x
   #:element-position-y
   #:element-position-width
   #:element-position-height
   #:element-position-right
   #:element-position-bottom
   #:element-position-center-x
   #:element-position-center-y
   #:copy-element-position

   ;; Grid coordinate structures and accessors
   #:element-grid-coordinates
   #:make-element-grid-coordinates
   #:element-grid-coordinates-row
   #:element-grid-coordinates-col
   #:element-grid-coordinates-row-span
   #:element-grid-coordinates-col-span
   #:copy-element-grid-coordinates

   ;; Position operations
   #:position-contains-p
   #:positions-overlap-p
   #:position-distance
   #:direction-to-position
   #:find-nearest-in-direction))

(in-package :elmtui.view.position)

;;;-----------------------------------------------------------------------------
;;; Element Position Structure
;;;-----------------------------------------------------------------------------

(defstruct (element-position (:constructor make-element-position)
                             (:conc-name element-position-)
                             (:copier copy-element-position))
  "Represents the absolute position and dimensions of a UI element."
  (x 0 :type integer)
  (y 0 :type integer)
  (width 0 :type integer)
  (height 0 :type integer))

;; Derived accessors for convenience
(defun element-position-right (pos)
  "Get the right edge x-coordinate of the element position."
  (+ (element-position-x pos) (element-position-width pos)))

(defun element-position-bottom (pos)
  "Get the bottom edge y-coordinate of the element position."
  (+ (element-position-y pos) (element-position-height pos)))

(defun element-position-center-x (pos)
  "Get the horizontal center coordinate of the element position."
  (+ (element-position-x pos) (floor (element-position-width pos) 2)))

(defun element-position-center-y (pos)
  "Get the vertical center coordinate of the element position."
  (+ (element-position-y pos) (floor (element-position-height pos) 2)))

;;;-----------------------------------------------------------------------------
;;; Element Grid Coordinates Structure
;;;-----------------------------------------------------------------------------

(defstruct (element-grid-coordinates (:constructor make-element-grid-coordinates)
                                     (:conc-name element-grid-coordinates-)
                                     (:copier copy-element-grid-coordinates))
  "Represents the grid-based position and span of a UI element."
  (row 0 :type integer)
  (col 0 :type integer)
  (row-span 1 :type integer)
  (col-span 1 :type integer))

;;;-----------------------------------------------------------------------------
;;; Position Operations
;;;-----------------------------------------------------------------------------

(defun position-contains-p (container-pos element-pos)
  "Returns true if container-pos fully contains element-pos."
  (and container-pos
       element-pos
       (<= (element-position-x container-pos)
           (element-position-x element-pos))
       (<= (element-position-y container-pos)
           (element-position-y element-pos))
       (>= (element-position-right container-pos)
           (element-position-right element-pos))
       (>= (element-position-bottom container-pos)
           (element-position-bottom element-pos))))

(defun positions-overlap-p (pos1 pos2)
  "Returns true if the two positions overlap."
  (and pos1
       pos2
       (< (element-position-x pos1) (element-position-right pos2))
       (> (element-position-right pos1) (element-position-x pos2))
       (< (element-position-y pos1) (element-position-bottom pos2))
       (> (element-position-bottom pos1) (element-position-y pos2))))

(defun position-distance (pos1 pos2)
  "Calculates the Euclidean distance between the centers of two positions."
  (when (and pos1 pos2)
    (let ((dx (- (element-position-center-x pos2) (element-position-center-x pos1)))
          (dy (- (element-position-center-y pos2) (element-position-center-y pos1))))
      (sqrt (+ (* dx dx) (* dy dy))))))

;;;-----------------------------------------------------------------------------
;;; Element Position Access Functions
;;;-----------------------------------------------------------------------------

(defgeneric element-position (element)
  (:documentation "Get the position data for a UI element.
Returns an element-position struct or nil if position is not available."))

(defmethod element-position ((element null))
  nil)

(defun %element-props (element)
  "Return plist properties from either a plist node or Hiccup-style element node."
  (cond
    ((and (listp element) (keywordp (first element))
          (listp (second element)) (keywordp (first (second element))))
     (second element))
    ((and (listp element) (keywordp (first element)))
     element)
    (t nil)))

(defmethod element-position ((element t))
  "Default implementation for getting element position from properties.
Override this for specific element types as needed."
  (let ((props (%element-props element)))
    (when (and (listp props)
               (getf props :x)
               (getf props :y)
               (getf props :width)
               (getf props :height))
      (make-element-position
       :x (getf props :x)
       :y (getf props :y)
       :width (getf props :width)
       :height (getf props :height)))))

;;;-----------------------------------------------------------------------------
;;; Element Grid Coordinates Access Functions
;;;-----------------------------------------------------------------------------

(defgeneric element-grid-coordinates (element)
  (:documentation "Get the grid coordinates for a UI element.
Returns an element-grid-coordinates struct or nil if grid position is not available."))

(defmethod element-grid-coordinates ((element null))
  nil)

(defmethod element-grid-coordinates ((element t))
  "Default implementation for getting element grid coordinates from properties.
Override this for specific element types as needed."
  (let ((props (%element-props element)))
    (when (and (listp props)
               (or (getf props :grid-row)
                   (getf props :grid-col)
                   (getf props :grid-x)
                   (getf props :grid-y)))
      (make-element-grid-coordinates
       :row (or (getf props :grid-row) (getf props :grid-y) 0)
       :col (or (getf props :grid-col) (getf props :grid-x) 0)
       :row-span (or (getf props :grid-row-span) 1)
       :col-span (or (getf props :grid-col-span) 1)))))

;;;-----------------------------------------------------------------------------
;;; Direction-Based Navigation Helpers
;;;-----------------------------------------------------------------------------

(defun direction-to-position (from-pos to-pos)
  "Determines the primary direction from one position to another.
Returns one of :up, :down, :left, :right, or nil if positions are identical."
  (when (and from-pos to-pos)
    (let* ((from-cx (element-position-center-x from-pos))
           (from-cy (element-position-center-y from-pos))
           (to-cx (element-position-center-x to-pos))
           (to-cy (element-position-center-y to-pos))
           (dx (- to-cx from-cx))
           (dy (- to-cy from-cy))
           (abs-dx (abs dx))
           (abs-dy (abs dy)))
      (cond
        ((and (= dx 0) (= dy 0)) nil) ; Same position
        ((> abs-dx abs-dy) (if (> dx 0) :right :left)) ; Horizontal distance dominates
        (t (if (> dy 0) :down :up)))))) ; Vertical distance dominates

(defun find-nearest-in-direction (elements from-element direction)
  "Finds the nearest element in the given direction from the from-element.
elements: List of UI elements with position information
from-element: The reference element
direction: One of :up, :down, :left, :right
Returns: The nearest element in that direction or nil if none found"
  (let ((from-pos (element-position from-element)))
    (unless from-pos (return-from find-nearest-in-direction nil))

    (let ((candidates nil))
      ;; Filter elements that are in the specified direction
      (dolist (el elements)
        (unless (eq el from-element)
          (let ((el-pos (element-position el)))
            (when el-pos
              (let ((actual-dir (direction-to-position from-pos el-pos)))
                (when (eq actual-dir direction)
                  (let ((dist (position-distance from-pos el-pos)))
                    (push (cons el dist) candidates))))))))

      ;; Return the closest one
      (when candidates
        (caar (sort candidates #'< :key #'cdr))))))
