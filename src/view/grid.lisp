;;;===============================================================
;;; File: src/view/grid.lisp
;;; CSS Grid Layout Implementation
;;;===============================================================
(uiop:define-package :elmtui.view.layout.grid
  (:use :cl)
  (:nicknames :et.grid)
  (:import-from :elmtui.view.core #:ui-node-children #:ui-node-props)
  (:import-from :elmtui.view.geo
    #:rectangle #:pos #:size #:h #:w #:x #:y
    #:make-rectangle #:make-pos #:make-size
    #:rectangle-pos #:rectangle-size #:copy-rectangle
    #:dx! #:dy! #:valid-p)
  (:import-from :elmtui.view.styled
    #:styled-ui-node #:style-value #:copy-styled-node)
  ;; Import layout-node for recursion
  ;; Import layout-node for recursion and dispatch-layout for defining the method
  (:import-from :elmtui.view.layout #:layout-node #:dispatch-layout #:layout-grid-container-impl)

  (:export
    ;; Grid Container (no specific class, uses styled-ui-node)
    ;; #:layout-grid-container ; No longer exported directly, called via dispatch-layout
    ;; Grid Properties (accessed via style-value)
    ;; #:grid-template-areas #:grid-template-columns #:grid-template-rows
    ;; #:grid-auto-columns #:grid-auto-rows #:grid-auto-flow
    ;; #:grid-column-gap #:grid-row-gap #:grid-gap
    ;; Item Properties (accessed via style-value)
    ;; #:grid-column-start #:grid-column-end #:grid-row-start #:grid-row-end
    ;; #:grid-column #:grid-row #:grid-area
    ;; Track Sizing Keywords (used in style values)
    #:fr #:minmax #:auto))

(in-package :elmtui.view.layout.grid)

;;;-----------------------------------------------------------------------------
;;; Grid Track Size Types & Parsers (already defined in properties.lisp)
;;; We rely on style-value to return these parsed values.
;;;-----------------------------------------------------------------------------
;; (deftype track-size () ...)
;; (defun fr (n) ...)
;; (defun minmax (min max) ...)
;; (defun auto () ...)

;;;-----------------------------------------------------------------------------
;;; Helper: Resolve Grid Line
;;;-----------------------------------------------------------------------------
(defun resolve-grid-line (line-value line-count named-lines)
  "Resolves a grid line value (integer, name, :auto, :span n) to an integer index.
   LINE-COUNT is the total number of explicit + implicit lines.
   NAMED-LINES is an alist of (name . index)."
  (cond
    ((integerp line-value)
      (if (and (< 0 line-value) (<= line-value line-count))
        (1- line-value) ; 1-based to 0-based
        (if (> line-value 0)
          (1- line-count) ; Clamp to last line if positive and out of bounds
          0))) ; Clamp to first line if non-positive
    ((stringp line-value)
      (let ((found (assoc line-value named-lines :test #'string=)))
        (if found (cdr found) 0))) ; Default to first line if name not found
    ((eq line-value :auto) 0) ; Placeholder, auto-placement handles this
    ((and (consp line-value) (eq (car line-value) :span))
      ;; Span is relative, actual resolution depends on context (start/end)
      ;; For now, treat as auto for initial placement if used directly
      0)
    (t 0))) ; Default for unknown

;;;-----------------------------------------------------------------------------
;;; Grid Layout Implementation
;;;-----------------------------------------------------------------------------

(defun calculate-track-sizes (track-definitions available-space item-intrinsic-sizes gap-size)
  "Calculate actual sizes for grid tracks.
   TRACK-DEFINITIONS: List of track size specs (e.g., 100, :auto, '(:fr 1)).
   AVAILABLE-SPACE: Total space for this dimension.
   ITEM-INTRINSIC-SIZES: A list of lists, where each inner list contains
                         the intrinsic sizes of items spanning that track.
                         (Not fully used in this simplified version for :auto).
   GAP-SIZE: Total size consumed by gaps in this dimension."
  (declare (ignore item-intrinsic-sizes)) ; Simplified :auto handling for now
  (let* ((num-tracks (length track-definitions))
          (space-for-tracks (max 0 (- available-space gap-size)))
          (fixed-sized-tracks '())
          (fr-unit-tracks '())
          (auto-sized-tracks '())
          (total-fixed-size 0)
          (total-fr-units 0)
          (calculated-sizes (make-list num-tracks :initial-element 0)))

    ;; Pass 1: Identify track types and sum fixed sizes/fr units
    (loop for def in track-definitions
      for i from 0
      do (cond
           ((integerp def)
             (push i fixed-sized-tracks)
             (incf total-fixed-size def)
             (setf (nth i calculated-sizes) def))
           ((and (consp def) (eq (car def) :fr) (integerp (cadr def)))
             (push (cons i (cadr def)) fr-unit-tracks)
             (incf total-fr-units (cadr def)))
           ((member def '(:auto :min-content :max-content))
             (push i auto-sized-tracks)
             ;; Simplified: treat auto/content-based as 0 initially,
             ;; or a small minimum if we had better intrinsic sizing.
             (setf (nth i calculated-sizes) 1)) ; Small placeholder for auto
           ((and (listp def) (eq (car def) :minmax))
             ;; Simplified: use the min value of minmax for now
             (let ((min-val (cadr def)))
               (when (integerp min-val)
                 (push i fixed-sized-tracks)
                 (incf total-fixed-size min-val)
                 (setf (nth i calculated-sizes) min-val))))
           (t (warn "Unsupported track definition: ~A" def))))

    (setf fixed-sized-tracks (nreverse fixed-sized-tracks))
    (setf fr-unit-tracks (nreverse fr-unit-tracks))
    (setf auto-sized-tracks (nreverse auto-sized-tracks))

    ;; Calculate space available for fr units and auto tracks
    (let ((remaining-space-for-flexible (max 0 (- space-for-tracks total-fixed-size
                                                 (loop for i in auto-sized-tracks sum (nth i calculated-sizes))))))

      ;; Pass 2: Distribute space for FR units
      (when (and (> total-fr-units 0) (> remaining-space-for-flexible 0))
        (let ((size-per-fr-unit (/ remaining-space-for-flexible total-fr-units)))
          (dolist (fr-track-cons fr-unit-tracks)
            (let ((index (car fr-track-cons))
                   (units (cdr fr-track-cons)))
              (setf (nth index calculated-sizes) (floor (* units size-per-fr-unit)))))))
      ;; NOTE: A more complete implementation would handle :auto and content-based
      ;; sizing by measuring items, then distributing remaining space for FR.
      ;; This version is simplified. Minmax is also simplified.
      )
    calculated-sizes))

(defun get-item-grid-placement (item-node num-cols num-rows)
  "Extracts and resolves grid placement properties for an item.
   Returns a plist: (:col-start, :col-end, :row-start, :row-end)"
  (let* ((col-start-val (style-value item-node :grid-column-start :auto))
          (col-end-val (style-value item-node :grid-column-end :auto))
          (row-start-val (style-value item-node :grid-row-start :auto))
          (row-end-val (style-value item-node :grid-row-end :auto))
          (area-val (style-value item-node :grid-area nil)))

    ;; TODO: Handle :grid-area string (named areas) and complex shorthand
    (declare (ignore area-val))

    (let ((cs (resolve-grid-line col-start-val num-cols nil))
           (ce (resolve-grid-line col-end-val num-cols nil))
           (rs (resolve-grid-line row-start-val num-rows nil))
           (re (resolve-grid-line row-end-val num-rows nil)))

      ;; Basic span interpretation if end is less than start or auto
      (when (or (eq col-end-val :auto) (<= ce cs))
        (setf ce (min num-cols (+ cs (if (and (consp col-start-val) (eq (car col-start-val) :span))
                                       (cadr col-start-val)
                                       1)))))
      (when (or (eq row-end-val :auto) (<= re rs))
        (setf re (min num-rows (+ rs (if (and (consp row-start-val) (eq (car row-start-val) :span))
                                       (cadr row-start-val)
                                       1)))))
      ;; Ensure end is at least start + 1
      (when (<= ce cs) (setf ce (min num-cols (+ cs 1))))
      (when (<= re rs) (setf re (min num-rows (+ rs 1))))

      (list :col-start cs :col-end ce :row-start rs :row-end re))))


(defmethod layout-grid-container-impl (grid-container-node available-rect)
  "Implementation detail for grid layout. Called via dispatch-layout.
   Returns a new styled-ui-node for the container with laid-out children."
  (unless (and grid-container-node (typep grid-container-node 'styled-ui-node))
    (error "layout-grid-container requires a styled-ui-node for the container."))
  (unless (and available-rect (typep available-rect 'rectangle))
    (error "layout-grid-container requires a valid available-rect."))

  (let* ((children (ui-node-children grid-container-node))
          (col-defs (style-value grid-container-node :grid-template-columns '(:auto)))
          (row-defs (style-value grid-container-node :grid-template-rows '(:auto)))
          (num-cols (length col-defs))
          (num-rows (length row-defs))
          (col-gap (style-value grid-container-node :grid-column-gap 0))
          (row-gap (style-value grid-container-node :grid-row-gap 0))
          ;; TODO: Handle :grid-template-areas and named lines

          (total-col-gap (* (max 0 (1- num-cols)) col-gap))
          (total-row-gap (* (max 0 (1- num-rows)) row-gap))

          (col-sizes (calculate-track-sizes col-defs (w available-rect) nil total-col-gap))
          (row-sizes (calculate-track-sizes row-defs (h available-rect) nil total-row-gap))

          (laid-out-children '())
          (container-offset-x (x available-rect))
          (container-offset-y (y available-rect)))

    (loop for child-node in children
      unless (typep child-node 'styled-ui-node)
      do (warn "Non-styled node found in grid container children: ~A" child-node)
      when (typep child-node 'styled-ui-node)
      do
      (let* ((placement (get-item-grid-placement child-node num-cols num-rows))
              (col-start (getf placement :col-start))
              (col-end (getf placement :col-end))
              (row-start (getf placement :row-start))
              (row-end (getf placement :row-end))

              (item-x (+ container-offset-x
                        (loop for i from 0 below col-start sum (nth i col-sizes))
                        (* col-start col-gap)))
              (item-y (+ container-offset-y
                        (loop for i from 0 below row-start sum (nth i row-sizes))
                        (* row-start row-gap)))
              (item-w (max 0 (+ (loop for i from col-start below col-end sum (nth i col-sizes))
                               (if (> (- col-end col-start) 0)
                                 (* (max 0 (1- (- col-end col-start))) col-gap)
                                 0))))
              (item-h (max 0 (+ (loop for i from row-start below row-end sum (nth i row-sizes))
                               (if (> (- row-end row-start) 0)
                                 (* (max 0 (1- (- row-end row-start))) row-gap)
                                 0))))
              (item-available-rect (make-rectangle
                                     :pos (make-pos :x item-x :y item-y)
                                     :size (make-size :w item-w :h item-h)))
              ;; Recursively layout the child within its grid area
              (laid-out-child (layout-node child-node item-available-rect)))

        (when laid-out-child
          ;; The layout-node call already sets :layout-rect in child's props
          (push laid-out-child laid-out-children))))

    ;; Create a new container node with updated children
    (let ((new-container-node (copy-styled-node grid-container-node)))
      (setf (ui-node-children new-container-node) (nreverse laid-out-children))
      ;; The container's own :layout-rect is simply the available-rect it was given
      (setf (getf (ui-node-props new-container-node) :layout-rect) (copy-rectangle available-rect))
      new-container-node)))

;; --- Grid layout method ---
(defmethod dispatch-layout ((display (eql :grid)) node available-rect)
  "Dispatch method for grid layout."
  ;; layout-grid-container-impl returns the modified container node.
  ;; dispatch-layout should return (values laid-out-children height width)
  (let* ((laid-out-container (layout-grid-container-impl node available-rect))
          (children (ui-node-children laid-out-container))
          ;; Grid container takes the available space by default
          (height (h available-rect))
          (width (w available-rect)))
    (values children height width)))
