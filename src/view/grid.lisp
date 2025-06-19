;;;===============================================================
;;; File: src/view/grid.lisp
;;; CSS Grid Layout Implementation
;;;===============================================================
(uiop:define-package :elmtui.view.layout.grid
  (:use :cl)
  (:nicknames :et.grid)
  (:import-from :elmtui.view.core #:ui-node-children #:ui-node-props #:ui-node)
  (:import-from :elmtui.style-lib.style-set #:set-style #:style-set) ; Function to add styles to a set
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:make-rectangle #:make-pos #:make-size
                #:rectangle-pos #:rectangle-size #:copy-rectangle
                #:dx! #:dy! #:valid-p)
  (:import-from :elmtui.style-lib.api #:stylesheet #:style-rule #:make-style-set)
  (:import-from :elmtui.style-lib.style-set #:set-style) ; Function to add styles to a set
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value #:copy-styled-node #:styles)
  (:import-from :elmtui.view.layout  #:layout-grid-container-impl #:layout-node #:dispatch-layout #:layout-grid-container-impl #:measure-node-intrinsic-size)
  (:import-from :elmtui.utils #:ensure-list)

  (:export
   #:layout-grid-container-impl
   ;; Track Sizing Keywords (already in style-lib/properties but good to note here)
   #:fr #:minmax #:auto))

(in-package :elmtui.view.layout.grid)

;;;-----------------------------------------------------------------------------
;;; Data Structures for Grid Layout (Assuming these are defined elsewhere or implicitly by make-grid-item etc.)
;;; e.g., grid-item struct with slots like: node, id, raw-col-start, raw-col-end, raw-row-start, raw-row-end,
;;; col-start, col-end, row-start, row-end, col-span, row-span, placed-p,
;;; min-content-width, max-content-width, min-content-height, max-content-height,
;;; align-self, justify-self.
;;;
;;; e.g., grid-track struct with slots like: index, type, definition, base-size, fr-units, growth-limit,
;;; is-flexible, items, min-contribution, max-contribution, final-size.
;;; For now, these are assumed to exist and work with make-grid-item, grid-item-*, make-grid-track, grid-track-*.
;;;-----------------------------------------------------------------------------
(defstruct grid-track
  index
  type  ;:fixed, :fr, :minmax, :content, :auto
  definition
  base-size
  fr-units
  growth-limit
  is-flexible
  items ; List of grid items in this track
  min-contribution ; Minimum content contribution for this track
  max-contribution ; Maximum content contribution for this track
  final-size) ; Final computed size after all iterations(

(defstruct grid-item
  node ; The UI node this item represents
  id ; Unique identifier for the grid item
  raw-col-start ; Raw start column (from style)
  raw-col-end ; Raw end column (from style)
  raw-row-start ; Raw start row (from style)
  raw-row-end ; Raw end row (from style)
  col-start ; Resolved start column index
  col-end ; Resolved end column index
  row-start ; Resolved start row index
  row-end ; Resolved end row index
  col-span ; Number of columns spanned by this item
  row-span ; Number of rows spanned by this item
  placed-p ; Whether the item has been placed in the grid
  min-content-width ; Minimum content width contribution
  max-content-width ; Maximum content width contribution
  min-content-height ; Minimum content height contribution
  max-content-height ; Maximum content height contribution
  align-self ; Alignment along the cross axis (e.g., :start, :end, :center, :stretch)
  justify-self) ; Justification along the main axis (e.g., :start, :end, :center, :stretch)




;;;-----------------------------------------------------------------------------
;;; Helper: Parse grid-template-areas
;;;-----------------------------------------------------------------------------

(defun parse-grid-template-areas (areas-string-list)
  "Parses a list of strings (from grid-template-areas style) into a map of
   area-name -> {row-start, col-start, row-end, col-end}."
  (let ((area-map (make-hash-table))
        (row-idx 0))
    (dolist (row-str areas-string-list)
      (let ((col-idx 0)
            (tokens (uiop:split-string row-str :separator " ")))
        (dolist (token tokens)
          (unless (string= token ".") ; Ignore null cell markers
            (let ((existing (gethash token area-map)))
              (if existing
                  ;; Extend existing area
                  (progn
                    (setf (getf existing :row-end) (max (getf existing :row-end) (1+ row-idx)))
                    (setf (getf existing :col-end) (max (getf existing :col-end) (1+ col-idx))))
                  ;; New area
                  (setf (gethash token area-map)
                        (list :name token
                              :row-start row-idx :col-start col-idx
                              :row-end (1+ row-idx) :col-end (1+ col-idx)))))))))
    area-map))

;;;-----------------------------------------------------------------------------
;;; Helper: Resolve Grid Line (Enhanced)
;;;-----------------------------------------------------------------------------

(defun resolve-grid-line-spec (line-spec line-count named-lines is-end-line default-span)
  "Resolves a grid line spec (integer, name, :auto, (:span n), (:span name)) to an integer index or a span list.
   LINE-COUNT is the total number of EXPLICIT lines (before implicit ones).
   NAMED-LINES is an alist of (name . index) or a hash table from parse-grid-template-areas.
   IS-END-LINE is a boolean indicating if this is for a -end property.
   DEFAULT-SPAN is the span to use if the spec is just :auto or a name for an end line."
  (cond
    ((integerp line-spec) ; 1-based explicit line number
     (let ((val (if (< line-spec 0)
                    (+ line-count line-spec 1) ; Negative index from end (CSS lines are 1-based)
                    line-spec)))
       ;; Convert to 0-based index for internal use, clamped.
       ;; CSS lines: 1 to N. Internal array indices: 0 to N-1.
       ;; A line number `l` refers to the boundary before cell `l`.
       ;; Grid has N tracks, N+1 lines. line-count is number of tracks.
       (max 0 (min (1- val) line-count))))
    ((stringp line-spec) ; Named line or area name
     (let ((val nil))
       (if (hash-table-p named-lines)
           (let ((area-props (gethash line-spec named-lines)))
             (if (and area-props (listp area-props)) ; Ensure it's a plist from area parsing
                 ;; Assuming column context for now, as per original code. This is a known limitation.
                 ;; This function needs axis context if it's to resolve area names correctly for rows/cols.
                 (setf val (if is-end-line (getf area-props :col-end) (getf area-props :col-start)))
                 ;; If not found or not a plist, treat as :auto for now
                 (setf val :auto)))
           ;; named-lines is an alist '("name" . index)
           (let ((assoc-entry (assoc line-spec named-lines :test #'string=)))
             (if assoc-entry
                 (setf val (cdr assoc-entry))
                 (setf val :auto))))
       val)) ; val will be an index or :auto
    ((eq line-spec :auto)
     (if (and is-end-line default-span (numberp default-span)) ; Ensure default-span is a number
         (list :span default-span)
         :auto))
    ((and (consp line-spec) (eq (car line-spec) :span) (cadr line-spec)) ; Ensure span has a value
     line-spec) ; Already a span, e.g. (:span 2) or (:span "name")
    (t :auto))) ; Default for unknown

;;;-----------------------------------------------------------------------------
;;; Intrinsic Size Determination (Enhanced)
;;;-----------------------------------------------------------------------------
;; (defun measure-node-intrinsic-size (node container-available-width container-available-height)
;;   "Measures the intrinsic min/max content contributions of a node.
;;    This is a placeholder for actual measurement logic, which would depend on the node type."
;;   ;; Placeholder logic: In a real implementation, this would measure the node's content.
;;   ;; For now, we return dummy values.
;;   (values 50.0 100.0 20.0 80.0)) ; Example min-w, max-w, min-h, max-h

(defun update-item-intrinsic-dimensions (grid-item container-available-width container-available-height)
  "Updates the intrinsic min/max content contributions for a grid item.
   This now calls a (hypothetical) measure-node-intrinsic-size function."
  (multiple-value-bind (min-w max-w min-h max-h)
      (measure-node-intrinsic-size
       (grid-item-node grid-item)
       container-available-width container-available-height)
    (setf (grid-item-min-content-width grid-item) min-w
          (grid-item-max-content-width grid-item) max-w
          (grid-item-min-content-height grid-item) min-h
          (grid-item-max-content-height grid-item) max-h))
  grid-item)

;;;-----------------------------------------------------------------------------
;;; Track Sizing Algorithm (Refined - Iterative Approach Sketch)
;;;-----------------------------------------------------------------------------
(defconstant +max-grid-sizing-iterations+ 10)

(defun initialize-grid-tracks (track-defs default-auto-size track-type-keyword)
  (declare (ignorable default-auto-size track-type-keyword)) ; Mark unused parameters
  (loop for i from 0
        for def in track-defs
        collect
        (let ((type (cond ((numberp def) :fixed)
                          ((and (consp def) (eq (car def) :fr) (numberp (cadr def)) (> (cadr def) 0)) :fr) ; Valid fr
                          ((and (consp def) (eq (car def) :minmax)) :minmax)
                          ((member def '(:auto :min-content :max-content) :test #'eq) :content)
                          (t :auto)))) ; Default to :auto for unknown/invalid definitions
          (make-grid-track :index i :type type :definition def
                           :base-size (if (eq type :fixed) (max 0.0 (float def)) 0.0) ; Fixed size must be non-negative
                           :fr-units (if (eq type :fr) (cadr def) 0.0)
                           :growth-limit (if (and (eq type :minmax) (caddr def) (numberp (caddr def)))
                                             (caddr def)
                                             most-positive-double-float)
                           :is-flexible (not (eq type :fixed))))))

;; (defun grid-track-definition
;;     (track)
;;   "Returns the definition of a grid track, which can be a fixed size, fr unit, minmax, or content type."
;;   (let ((def track))
;;     (cond
;;       ((numberp def) def) ; Fixed size
;;       ((and (consp def) (eq (car def) :fr)) (cadr def)) ; fr unit
;;       ((and (consp def) (eq (car def) :minmax)) def) ; minmax definition
;;       ((member def '(:auto :min-content :max-content) :test #'eq) def) ; content type
;;       (t nil))))

(defun resolve-content-based-track-sizes (tracks items dimension)
  (declare (ignorable items)) ; Mark items as ignorable
  "Resolve sizes for :auto, :min-content, :max-content tracks based on items spanning them."
  (dolist (track tracks)
    (when (eq (grid-track-type track) :content)
      (let ((min-c 0.0) (max-c 0.0))
        (dolist (item (grid-track-items track)) ; Assumes grid-track-items is populated
          (let* ((item-span (if (eq dimension :width) (grid-item-col-span item) (grid-item-row-span item)))
                 (item-min (if (eq dimension :width) (grid-item-min-content-width item) (grid-item-min-content-height item)))
                 (item-max (if (eq dimension :width) (grid-item-max-content-width item) (grid-item-max-content-height item))))
            (when (and item-span (> item-span 0)) ; Ensure span is valid
              (let ((contrib-min (/ item-min item-span))
                    (contrib-max (/ item-max item-span)))
                (setf min-c (max min-c contrib-min))
                (setf max-c (max max-c contrib-max))))))
        (setf (grid-track-base-size track)
              (case (grid-track-definition track)
                (:min-content min-c)
                (:max-content max-c)
                (:auto min-c) ; Default :auto to min-content behavior
                (otherwise min-c)))
        (setf (grid-track-growth-limit track) (max (grid-track-base-size track) max-c))
        (setf (grid-track-is-flexible track) nil)))) ; Considered resolved for this sizing step
  tracks)

(defun resolve-minmax-track-sizes (tracks items dimension available-space total-gap)
  (declare (ignore items dimension available-space total-gap)) ; More complex logic needed here
  (dolist (track tracks)
    (when (eq (grid-track-type track) :minmax)
      (let* ((minmax-def (grid-track-definition track))
             (min-bound (cadr minmax-def))
             (max-bound (caddr minmax-def)))
        ;; Resolve min-bound (can be fixed, auto, min-content, max-content)
        (setf min-bound (cond ((numberp min-bound) min-bound)
                              ((eq min-bound :auto) (grid-track-min-contribution track)) ;; Needs item contributions
                              ;; TODO: Handle :min-content, :max-content for min-bound if needed
                              (t 0.0))) ;; Default for unhandled min-bound

        ;; Resolve max-bound (can be fixed, auto, min-content, max-content, fr)
        (setf max-bound (cond ((numberp max-bound) max-bound)
                              ((eq max-bound :auto) (grid-track-max-contribution track)) ;; Needs item contributions
                              ((eq max-bound :fr) most-positive-double-float) ;; fr in max behaves like auto for growth limit
                              ;; TODO: Handle :min-content, :max-content for max-bound
                              (t most-positive-double-float))) ;; Default for unhandled max-bound

        (setf (grid-track-base-size track) (max min-bound (grid-track-base-size track) (grid-track-min-contribution track)))
        (setf (grid-track-growth-limit track) (min max-bound (grid-track-max-contribution track)))

        (when (numberp max-bound)
          (setf (grid-track-base-size track) (min (grid-track-base-size track) max-bound))
          (when (>= (grid-track-base-size track) max-bound)
            (setf (grid-track-is-flexible track) nil))))))
  tracks)

(defun distribute-flexible-space (tracks available-space total-gap-size)
  "Distributes remaining space to FR units and other flexible tracks."
  (let* ((num-flexible-auto
           (loop for track in tracks count
                                     (and (grid-track-is-flexible track)
                                          (eq (grid-track-type track) :content) ; Assuming :auto tracks are :content type
                                          (eq (grid-track-definition track) :auto))))
         (total-fr-units (loop for track in tracks when (and (grid-track-is-flexible track) (> (grid-track-fr-units track) 0)) sum (grid-track-fr-units track)))
         (fixed-and-resolved-size (loop for track in tracks unless (grid-track-is-flexible track) sum (grid-track-base-size track)))
         (space-for-flexible (max 0.0 (- available-space fixed-and-resolved-size total-gap-size))))

    (when (> space-for-flexible 0)
      (cond
        ((> total-fr-units 0)
         (let ((size-per-fr (/ space-for-flexible total-fr-units)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track) (> (grid-track-fr-units track) 0))
               (let ((growth (max 0 (* (grid-track-fr-units track) size-per-fr))))
                 (incf (grid-track-base-size track) growth)
                 ;; Clamp by growth limit if defined by minmax(X, Y) where Y is fixed
                 (setf (grid-track-base-size track) (min (grid-track-base-size track) (grid-track-growth-limit track)))
                 (setf (grid-track-is-flexible track) nil)))))) ; Mark FR tracks as resolved
        ((> num-flexible-auto 0) ; Distribute remaining space equally among :auto tracks that are still flexible
         (let ((size-per-auto (/ space-for-flexible num-flexible-auto)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track) (eq (grid-track-type track) :content) (eq (grid-track-definition track) :auto))
               (incf (grid-track-base-size track) size-per-auto)
               (setf (grid-track-base-size track) (min (grid-track-base-size track) (grid-track-growth-limit track)))
               (setf (grid-track-is-flexible track) nil))))))
      ;; If no fr and no auto, but still flexible space and flexible tracks (e.g. minmax(:auto, :auto) not fully resolved),
      ;; this might need further logic or indicate an earlier step should have handled it.
      ))
  tracks)

(defun calculate-final-track-sizes (tracks)
  (dolist (track tracks)
    (setf (grid-track-final-size track)
          (max 0.0 (grid-track-base-size track))))) ; Ensure final size is non-negative

(defun perform-track-sizing-iteration (col-tracks row-tracks grid-items available-width available-height col-gap row-gap)
  ;; 1. Update item intrinsic contributions to tracks (min/max)
  (dolist (track col-tracks) (setf (grid-track-min-contribution track) 0.0 (grid-track-max-contribution track) 0.0 (grid-track-items track) nil))
  (dolist (track row-tracks) (setf (grid-track-min-contribution track) 0.0 (grid-track-max-contribution track) 0.0 (grid-track-items track) nil))

  (dolist (item grid-items)
    (loop for i from (grid-item-col-start item) to (1- (grid-item-col-end item)) do
      (when (< i (length col-tracks))
        (let ((track (nth i col-tracks)))
          (push item (grid-track-items track))
          (setf (grid-track-min-contribution track) (max (grid-track-min-contribution track) (/ (grid-item-min-content-width item) (grid-item-col-span item))))
          (setf (grid-track-max-contribution track) (max (grid-track-max-contribution track) (/ (grid-item-max-content-width item) (grid-item-col-span item)))))))
    (loop for i from (grid-item-row-start item) to (1- (grid-item-row-end item)) do
      (when (< i (length row-tracks))
        (let ((track (nth i row-tracks)))
          (push item (grid-track-items track))
          (setf (grid-track-min-contribution track) (max (grid-track-min-contribution track) (/ (grid-item-min-content-height item) (grid-item-row-span item))))
          (setf (grid-track-max-contribution track) (max (grid-track-max-contribution track) (/ (grid-item-max-content-height item) (grid-item-row-span item))))))))

  ;; 2. Resolve content-based tracks (min-content, max-content, auto)
  (resolve-content-based-track-sizes col-tracks grid-items :width)
  (resolve-content-based-track-sizes row-tracks grid-items :height)

  ;; 3. Resolve minmax constraints
  (resolve-minmax-track-sizes col-tracks grid-items :width available-width (* (max 0 (1- (length col-tracks))) col-gap))
  (resolve-minmax-track-sizes row-tracks grid-items :height available-height (* (max 0 (1- (length row-tracks))) row-gap))

  ;; 4. Distribute space to flexible (FR) tracks (and then other flexible like auto)
  (distribute-flexible-space col-tracks available-width (* (max 0 (1- (length col-tracks))) col-gap))
  (distribute-flexible-space row-tracks available-height (* (max 0 (1- (length row-tracks))) row-gap))

  ;; Check if all tracks are resolved (is-flexible is nil)
  (and (every (lambda (tr) (not (grid-track-is-flexible tr))) col-tracks)
       (every (lambda (tr) (not (grid-track-is-flexible tr))) row-tracks)))

;; Uncommented and designated as the main iterative track sizing function
(defun iterative-track-sizing (col-track-defs row-track-defs grid-items
                               available-width available-height col-gap row-gap
                               container-available-width container-available-height)
  "Main iterative track sizing function."
  ;; Initialize grid items with intrinsic sizes (called once before iterations)
  (dolist (item grid-items)
    (update-item-intrinsic-dimensions item container-available-width container-available-height))

  (let ((col-tracks (initialize-grid-tracks col-track-defs (style-value nil :grid-auto-columns :auto) :column))
        (row-tracks (initialize-grid-tracks row-track-defs (style-value nil :grid-auto-rows :auto) :row)))

    ;; Assign items to tracks initially (will be updated in perform-track-sizing-iteration)
    ;; This initial assignment might be redundant if perform-track-sizing-iteration clears and re-assigns.
    ;; (dolist (item grid-items)
    ;;   (loop for i from (grid-item-col-start item) to (1- (grid-item-col-end item))
    ;;         do (when (< i (length col-tracks)) (push item (grid-track-items (nth i col-tracks)))))
    ;;   (loop for i from (grid-item-row-start item) to (1- (grid-item-row-end item))
    ;;         do (when (< i (length row-tracks)) (push item (grid-track-items (nth i row-tracks))))))

    (loop for iteration from 1 to +max-grid-sizing-iterations+
          for all-resolved = (perform-track-sizing-iteration col-tracks row-tracks grid-items
                                                             available-width available-height col-gap row-gap)
          when all-resolved do (loop-finish))

    (calculate-final-track-sizes col-tracks)
    (calculate-final-track-sizes row-tracks)
    (values (mapcar #'grid-track-final-size col-tracks)
            (mapcar #'grid-track-final-size row-tracks))))

;;;-----------------------------------------------------------------------------
;;; Item Placement Logic
;;;-----------------------------------------------------------------------------

(defun process-item-placement-properties (item-node named-area-map explicit-col-count explicit-row-count)
  (let* ((item-styles (styles item-node))
         (grid-area (style-value item-styles :grid-area))
         (gcs (style-value item-styles :grid-column-start :auto))
         (gce (style-value item-styles :grid-column-end :auto))
         (grs (style-value item-styles :grid-row-start :auto))
         (gre (style-value item-styles :grid-row-end :auto))
         (col-start gcs) (col-end gce) (row-start grs) (row-end gre))

    ;; If grid-area is specified and is a name, it overrides others
    (when (and (stringp grid-area) named-area-map (gethash grid-area named-area-map))
      (let ((area-def (gethash grid-area named-area-map)))
        ;; Assuming area-def is a plist like (:col-start cs :col-end ce :row-start rs :row-end re)
        (setf col-start (getf area-def :col-start col-start)) ; Keep original if not in area_def
        (setf col-end (getf area-def :col-end col-end))
        (setf row-start (getf area-def :row-start row-start))
        (setf row-end (getf area-def :row-end row-end))))
    ;; TODO: Handle grid-area shorthand like row-start / col-start / row-end / col-end numerical syntax

    ;; Resolve line numbers and spans
    ;; For end lines, default span is 1 if start is auto, otherwise no default span (nil)
    (setf col-start (resolve-grid-line-spec col-start explicit-col-count named-area-map nil 1))
    (setf row-start (resolve-grid-line-spec row-start explicit-row-count named-area-map nil 1))

    (setf col-end (resolve-grid-line-spec col-end explicit-col-count named-area-map t (if (eq col-start :auto) 1 nil)))
    (setf row-end (resolve-grid-line-spec row-end explicit-row-count named-area-map t (if (eq row-start :auto) 1 nil)))

    (list :node item-node :id (getf (ui-node-props item-node) :id)
          :raw-col-start col-start :raw-col-end col-end
          :raw-row-start row-start :raw-row-end row-end)))

(defun resolve-item-final-placement (item-placement-info current-auto-col current-auto-row
                                     max-cols max-rows grid-auto-flow)
  (let ((cs (getf item-placement-info :raw-col-start))
        (ce (getf item-placement-info :raw-col-end))
        (rs (getf item-placement-info :raw-row-start))
        (re (getf item-placement-info :raw-row-end)))

    ;; Handle :auto and spans for start lines
    (multiple-value-bind (resolved-cs resolved-rs next-auto-col next-auto-row)
        (cond
          ((and (eq cs :auto) (eq rs :auto))
           ;; Full auto-placement
           (values current-auto-col current-auto-row
                   (if (eq grid-auto-flow :column) (1+ current-auto-col) current-auto-col)
                   (if (eq grid-auto-flow :row) (1+ current-auto-row) current-auto-row)))
          ((eq cs :auto)
           (values current-auto-col rs
                   (if (eq grid-auto-flow :column) (1+ current-auto-col) current-auto-col)
                   current-auto-row))
          ((eq rs :auto)
           (values cs current-auto-row
                   current-auto-col
                   (if (eq grid-auto-flow :row) (1+ current-auto-row) current-auto-row)))
          (t (values cs rs current-auto-col current-auto-row)))

      (setf cs resolved-cs)
      (setf rs resolved-rs)

      ;; Handle :auto and spans for end lines
      (setf ce (cond ((eq ce :auto) (1+ cs))
                     ((listp ce) (min max-cols (+ cs (cadr ce)))) ; span N
                     (t ce)))
      (setf re (cond ((eq re :auto) (1+ rs))
                     ((listp re) (min max-rows (+ rs (cadr re)))) ; span N
                     (t re)))

      ;; Ensure end is at least start + 1 and within bounds
      (setf ce (min max-cols (max ce (1+ cs))))
      (setf re (min max-rows (max re (1+ rs))))

      (values
       (make-grid-item :node (getf item-placement-info :node)
                       :id (getf item-placement-info :id)
                       :col-start cs :col-end ce :row-start rs :row-end re
                       :col-span (- ce cs) :row-span (- re rs)
                       :placed-p t)
       next-auto-col next-auto-row))))

;;;-----------------------------------------------------------------------------
;;; Item Alignment within Grid Area
;;;-----------------------------------------------------------------------------
(defun align-item-in-area (item-node item-layout-rect grid-area-rect align-self justify-self)
  "Aligns an item within its allocated grid area based on align-self and justify-self."
  (declare (ignore item-node))
  (let ((final-rect (copy-rectangle item-layout-rect)) ; Start with the item's measured/laid-out size
        (item-w (w item-layout-rect))
        (item-h (h item-layout-rect))
        (area-w (w grid-area-rect))
        (area-h (h grid-area-rect)))

    ;; Justify-self (horizontal alignment in the area)
    (case justify-self
      (:start (setf (x final-rect) (x grid-area-rect)))
      (:end (setf (x final-rect) (+ (x grid-area-rect) (- area-w item-w))))
      (:center (setf (x final-rect) (+ (x grid-area-rect) (round (/ (- area-w item-w) 2)))))
      (:stretch
       (setf (x final-rect) (x grid-area-rect))
       (setf (w final-rect) area-w))
      (otherwise (setf (x final-rect) (x grid-area-rect)))) ; Default to start

    ;; Align-self (vertical alignment in the area)
    (case align-self
      (:start (setf (y final-rect) (y grid-area-rect)))
      (:end (setf (y final-rect) (+ (y grid-area-rect) (- area-h item-h))))
      (:center (setf (y final-rect) (+ (y grid-area-rect) (round (/ (- area-h item-h) 2)))))
      (:stretch
       (setf (y final-rect) (y grid-area-rect))
       (setf (h final-rect) area-h))
      ;; TODO: :baseline - needs baseline info from item and area
      (otherwise (setf (y final-rect) (y grid-area-rect)))) ; Default to start

    ;; If stretch was applied, the item might need re-layout with new dimensions
    ;; For now, we assume layout-node handled the item's size correctly initially,
    ;; and stretch here just expands its containing box for drawing, or the item
    ;; itself is responsible for filling the stretched rect if its own width/height are auto.
    ;; A more correct model would re-layout the item if its size changed due to stretch.
    final-rect))

;;;-----------------------------------------------------------------------------
;;; Main Grid Layout Function
;;;-----------------------------------------------------------------------------
(defmethod layout-grid-container-impl (grid-container-node available-rect)
  (unless (and grid-container-node (typep grid-container-node 'styled-ui-node))
    (error "layout-grid-container requires a styled-ui-node for the container."))
  (unless (and available-rect (typep available-rect 'rectangle))
    (error "layout-grid-container requires a valid available-rect."))

  (let* ((container-styles (styles grid-container-node))
         (children (ui-node-children grid-container-node))
         (parent-absolute-content-rect available-rect)

         (template-areas-str (style-value container-styles :grid-template-areas))
         (named-area-map (if template-areas-str (parse-grid-template-areas (ensure-list template-areas-str)) nil))

         (col-defs (ensure-list (style-value container-styles :grid-template-columns '(:auto))))
         (row-defs (ensure-list (style-value container-styles :grid-template-rows '(:auto)))))
    (let* ((auto-flow (style-value container-styles :grid-auto-flow :row))
           (grid-auto-cols (style-value container-styles :grid-auto-columns :auto))
           (grid-auto-rows (style-value container-styles :grid-auto-rows :auto))
           (explicit-col-count (length col-defs))
           (explicit-row-count (length row-defs))
           ;; (explicit-row-defs (style-value container-styles :grid-template-rows '(:auto))) ; Redundant, use row-defs
           (col-gap (style-value container-styles :grid-column-gap 0))
           (row-gap (style-value container-styles :grid-row-gap 0))
           (container-offset-x (x parent-absolute-content-rect))
           (container-offset-y (y parent-absolute-content-rect))
           (all-raw-item-infos '()) ; Store raw placement info first
           (all-grid-items '()) ; Will store final grid-item structs
           (laid-out-children '()))

      ;; 1. Create list of raw placement property plists for each item
      (setf all-raw-item-infos
            (loop for child-node in children
                  when (typep child-node 'styled-ui-node)
                    collect (process-item-placement-properties child-node named-area-map explicit-col-count explicit-row-count)))

      ;; 2. Auto-placement pass: resolve raw placements into grid-item structs
      (let ((current-auto-col 0)
            (current-auto-row 0)
            (max-cols-needed explicit-col-count)
            (max-rows-needed explicit-row-count) ; Use explicit-row-count
            (resolved-items-temp '()))
        (dolist (raw-item-info all-raw-item-infos)
          ;; resolve-item-final-placement returns (values resolved-grid-item next-auto-col next-auto-row)
          ;; The attachment declares next-c and next-r ignorable, implying they are not used for advancing current-auto-col/row.
          ;; The main loop's logic (lines 507-517 in attachment) advances current-auto-col/row.
          (multiple-value-bind (resolved-item next-c next-r)
              (resolve-item-final-placement raw-item-info current-auto-col current-auto-row
                                            max-cols-needed max-rows-needed auto-flow)
            (declare (ignorable next-c next-r)) ; Keep ignorable as per user's version if main loop advances cursor
            (push resolved-item resolved-items-temp)

            (setf max-cols-needed (max max-cols-needed (grid-item-col-end resolved-item)))
            (setf max-rows-needed (max max-rows-needed (grid-item-row-end resolved-item)))

            ;; Advance current-auto-col/row based on the end of the placed item and auto-flow direction
            (if (eq auto-flow :row)
                (progn
                  (setf current-auto-col (grid-item-col-end resolved-item))
                  (when (and (>= current-auto-col max-cols-needed) (> max-cols-needed 0)) ; Check against current max_cols_needed
                    (setf current-auto-col 0)
                    (incf current-auto-row)))
                (progn ; :column flow
                  (setf current-auto-row (grid-item-row-end resolved-item))
                  (when (and (>= current-auto-row max-rows-needed) (> max-rows-needed 0)) ; Check against current max_rows_needed
                    (setf current-auto-row 0)
                    (incf current-auto-col))))
            ))
        (setf all-grid-items (nreverse resolved-items-temp))

        ;; Update col-defs and row-defs if auto-placement expanded the grid
        (when (> max-cols-needed (length col-defs))
          (setf col-defs (append col-defs (make-list (- max-cols-needed (length col-defs)) :initial-element grid-auto-cols))))
        (when (> max-rows-needed (length row-defs))
          (setf row-defs (append row-defs (make-list (- max-rows-needed (length row-defs)) :initial-element grid-auto-rows))))
        )


      ;; Calculate available track space based on final number of tracks
      (let ((available-track-w (max 0 (- (w parent-absolute-content-rect) (* (max 0 (1- (length col-defs))) col-gap))))
            (available-track-h (max 0 (- (h parent-absolute-content-rect) (* (max 0 (1- (length row-defs))) row-gap)))))

        ;; 3. Iterative Track Sizing
        (multiple-value-bind (final-col-sizes final-row-sizes)
            (iterative-track-sizing col-defs row-defs all-grid-items
                                    available-track-w available-track-h col-gap row-gap
                                    (w parent-absolute-content-rect) (h parent-absolute-content-rect))

          ;; 4. Position items, align them, and recursively layout children
          (dolist (grid-item all-grid-items)
            (let* ((cs (grid-item-col-start grid-item)) (ce (grid-item-col-end grid-item))
                   (rs (grid-item-row-start grid-item)) (re (grid-item-row-end grid-item))
                   (item-node (grid-item-node grid-item))
                   (item-styles (styles item-node)) ; Get styles for align/justify

                   ;; Calculate grid area for this item
                   (area-x (+ container-offset-x (loop for i from 0 below cs sum (or (nth i final-col-sizes) 0)) (* cs col-gap)))
                   (area-y (+ container-offset-y (loop for i from 0 below rs sum (or (nth i final-row-sizes) 0)) (* rs row-gap)))
                   (area-w (max 0 (+ (loop for i from cs below ce sum (or (nth i final-col-sizes) 0))
                                     (if (> (- ce cs) 0) (* (max 0 (1- (- ce cs))) col-gap) 0))))
                   (area-h (max 0 (+ (loop for i from rs below re sum (or (nth i final-row-sizes) 0))
                                     (if (> (- re rs) 0) (* (max 0 (1- (- re rs))) row-gap) 0))))
                   (grid-area-rect (make-rectangle
                                    :pos (make-pos :x area-x :y area-y)
                                    :size (make-size :w area-w :h area-h)))

                   ;; Layout child within its determined grid area (this gives its natural size or stretched size)
                   (laid-out-child-node (layout-node item-node grid-area-rect container-styles)) ; Pass container styles for context if needed
                   (item-actual-layout-rect (getf (ui-node-props laid-out-child-node) :layout-rect)))

              (when laid-out-child-node
                (let* ((align (style-value item-styles :align-self (style-value container-styles :align-items :stretch)))
                       (justify (style-value item-styles :justify-self (style-value container-styles :justify-items :stretch)))
                       (final-item-rect (align-item-in-area laid-out-child-node item-actual-layout-rect grid-area-rect align justify)))
                  (setf (getf (ui-node-props laid-out-child-node) :layout-rect) final-item-rect)
                  (push laid-out-child-node laid-out-children)))))

          ;; 5. Create a new container node with updated children and its own layout rect
          (let ((new-container-node (copy-styled-node grid-container-node)))
            (setf (ui-node-children new-container-node) (nreverse laid-out-children))
            ;; Determine container's own size based on its content or explicit styles
            (let* ((container-w-style (style-value container-styles :width))
                   (container-h-style (style-value container-styles :height))
                   (total-cols-width
                     (+ (loop for size in final-col-sizes sum size)
                        (if (> (length col-defs) 0)
                            (* (max 0 (1- (length col-defs))) col-gap) 0)))
                   (total-rows-height
                     (+ (loop for size in final-row-sizes sum size)
                        (if (> (length row-defs) 0)
                            (* (max 0 (1- (length row-defs))) row-gap) 0)))
                   (container-final-w (if (eq container-w-style :auto)
                                          total-cols-width
                                          (w parent-absolute-content-rect))) ; Or resolve percentage/fixed
                   (container-final-h (if (eq container-h-style :auto)
                                          total-rows-height
                                          (h parent-absolute-content-rect)))) ; Or resolve percentage/fixed
              (setf (getf (ui-node-props new-container-node) :layout-rect)
                    (make-rectangle :pos (make-pos :x container-offset-x :y container-offset-y)
                                    :size (make-size :w container-final-w :h container-final-h))))
            new-container-node))))))

;; --- Grid layout method (dispatch) ---
(defmethod dispatch-layout ((display (eql :grid)) node available-rect)
  (let* ((laid-out-container (layout-grid-container-impl node available-rect)))
    (if laid-out-container
        (let ((children (ui-node-children laid-out-container))
              (container-layout-rect (getf (ui-node-props laid-out-container) :layout-rect)))
          (values children (h container-layout-rect) (w container-layout-rect)))
        (values (ui-node-children node) 0 0)))) ; Fallback if layout fails

;; Comment out the old recursive/problematic track sizing helpers
#|
(defun resolve-track-sizes (col-track-defs row-track-defs grid-items
available-width available-height col-gap row-gap
container-available-width container-available-height)
"Resolve the sizes of grid tracks based on definitions and items.
COL-TRACK-DEFS, ROW-TRACK-DEFS: Lists of track size definitions.
GRID-ITEMS: List of grid items to be sized.
AVAILABLE-WIDTH, AVAILABLE-HEIGHT: Total space available for the grid.
COL-GAP, ROW-GAP: Gaps between columns and rows.
CONTAINER-AVAILABLE-WIDTH, CONTAINER-AVAILABLE-HEIGHT: Space available in the container."
(iterative-track-sizing col-track-defs row-track-defs grid-items
available-width available-height col-gap row-gap
container-available-width container-available-height))

(defun iterative-track-sizing (col-track-defs row-track-defs grid-items
available-width available-height col-gap row-gap
container-available-width container-available-height)
"Performs the iterative track sizing algorithm for CSS Grid.
This function is a simplified placeholder and needs to be fully implemented
according to the CSS Grid specification (Section 11.5 & 11.6).
Currently, it initializes tracks but doesn't perform the full iterative sizing logic."
;; Initialize grid items with intrinsic sizes
(dolist (item grid-items)
(update-item-intrinsic-dimensions item container-available-width container-available-height))

(let* ((col-tracks (initialize-grid-tracks col-track-defs (style-value nil :grid-auto-columns :auto) :column))
(row-tracks (initialize-grid-tracks row-track-defs (style-value nil :grid-auto-rows   :auto) :row))
;; The following are placeholders or simplified versions of what's needed.
;; A full implementation requires multiple passes and complex logic for fr units, min/max, etc.
(sized-col-tracks (resolve-track-sizes col-tracks available-width col-gap grid-items :column)) ; This was recursive
(sized-row-tracks (resolve-track-sizes row-tracks available-height row-gap grid-items :row)))  ; This was recursive

;; TODO: This is where the iterative sizing loop would go, handling intrinsic contributions,
;; content-based sizing, fr unit distribution, and min/max constraints.
;; For now, we just return the initially resolved sizes.
;; The actual algorithm involves multiple steps:
;; 1. Initialize track sizes (done by initialize-grid-tracks and resolve-track-sizes for non-flexible tracks)
;; 2. Resolve intrinsic track sizes (partially done by update-item-intrinsic-dimensions and resolve-track-sizes)
;; 3. Maximize tracks (for items spanning multiple tracks)
;; 4. Expand flexible tracks (distribute space for `fr` units)
;; 5. Stretch auto tracks (if align-content/justify-content is stretch)

;; The current `resolve-track-sizes` is a simplification. A full implementation
;; would need to handle these steps iteratively.
(values sized-col-tracks sized-row-tracks)))
|#
