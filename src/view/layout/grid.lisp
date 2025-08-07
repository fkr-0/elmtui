;;;===============================================================
;;; File: src/view/grid-complete.lisp
;;; Unified CSS Grid Layout Implementation for ELMTUI
;;;===============================================================

;; This module consolidates the functionality from two previously
;; separate grid layout implementations (grid.lisp and grid-layout.lisp)
;; into a single, production‑ready module.  It provides both the low
;; level layout engine used by the ELMTUI renderer and the high level
;; declarative API for constructing grid containers, defining
;; templates, and computing layouts.  Developers can use the
;; exported API to define grid templates, build responsive grids,
;; render ASCII previews of grid templates, and perform precise
;; measurements and placement of UI nodes via CSS Grid semantics.

(uiop:define-package :elmtui.view.layout.grid
  (:use :cl)
  (:nicknames :et.grid)
  (:import-from :elmtui.view.core
                #:ui-node #:ui-node-children #:ui-node-props)

  (:import-from :elmtui.view.layout
                #:layout-grid-container-impl)
  (:import-from :elmtui.style-lib.style-set
                #:set-style #:style-set)
  (:import-from :elmtui.view.api
                #:ui-node-p)
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:make-rectangle #:make-pos #:make-size
                #:rectangle-pos #:rectangle-size #:copy-rectangle
                #:dx! #:dy! #:valid-p)
  (:import-from :elmtui.style-lib.api
                #:stylesheet #:style-rule #:make-style-set)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value #:copy-styled-node #:styles #:make-styled-node)
  (:import-from :elmtui.view.layout
                #:layout-node #:dispatch-layout #:measure-node-intrinsic-size)
  (:import-from :elmtui.utils #:ensure-list)
  ;; Import string utilities for the high level API
  (:import-from :str
                #:split #:trim)
  (:export
   ;; Main grid layout entry point (used by the renderer)
   #:dispatch-layout
   ;; Low level track sizing primitives and helpers
   #:grid-track #:grid-item #:iterative-track-sizing
   ;; High level API for grid templates and area definition
   #:parse-grid-template #:grid-template #:grid-area #:grid-auto-flow
   #:grid-responsive #:make-grid-item
   #:grid-template-definition #:define-grid-template
   #:get-grid-area-coordinates #:render-grid-template
   #:build-grid-from-template #:grid-position-to-coordinates
   #:make-grid #:compute-grid-layout))

(in-package :elmtui.view.layout.grid)

;;;====================================================================
;;; Low Level Grid Layout Engine
;;;====================================================================

;; The following section implements the core CSS grid layout algorithm
;; used by the ELMTUI layout engine.  Tracks are sized iteratively
;; based on the intrinsic sizes of child items, fractional units (fr),
;; min/max constraints, and flexible distribution of leftover space.

;;;---------------------------------------------------------------------
;;; Data Structures for Grid Layout
;;;---------------------------------------------------------------------

(defstruct grid-track
  "A track represents a single column or row in a grid.  Tracks can
have fixed size, fractional (fr) units, minmax definitions, or
content based sizing (:auto, :min-content, :max-content)."
  index
  type           ;:fixed, :fr, :minmax, :content, :auto
  definition
  base-size
  fr-units
  growth-limit
  is-flexible
  items
  min-contribution
  max-contribution
  final-size)

(defstruct (grid-item (:constructor %make-grid-item))
  "Represents a single item placed into the grid.  Holds resolved
column/row positions and spans along with the intrinsic size
contributions for track sizing."
  node
  id
  raw-col-start
  raw-col-end
  raw-row-start
  raw-row-end
  col-start
  col-end
  row-start
  row-end
  col-span
  row-span
  placed-p
  min-content-width
  max-content-width
  min-content-height
  max-content-height
  align-self
  justify-self)

;;;---------------------------------------------------------------------
;;; Parsing Grid Template Areas (High Level)
;;;---------------------------------------------------------------------

;; CSS allows template areas to be specified as a list of strings where
;; each non‑dot token names an area.  This helper produces a mapping
;; from area name to its bounds.  It is used by both the low level
;; placement engine and the high level template API.

(defun parse-grid-template-areas (areas-string-list)
  "Parses a list of strings (from grid-template-areas style) into a
   hash table mapping each area name to a plist with :row-start,
   :col-start, :row-end, and :col-end entries.  Dots (\".\") are
   ignored.  Rows and columns are zero‑based internally."
  (let ((area-map (make-hash-table :test 'equal))
        (row-idx 0))
    (dolist (row-str areas-string-list)
      (let ((col-idx 0)
            (tokens (uiop:split-string row-str :separator " ")))
        (dolist (token tokens)
          (unless (string= token ".")
            (let ((existing (gethash token area-map)))
              (if existing
                  ;; Extend existing area if necessary
                  (progn
                    (setf (getf existing :row-end)
                          (max (getf existing :row-end) (1+ row-idx)))
                    (setf (getf existing :col-end)
                          (max (getf existing :col-end) (1+ col-idx))))
                  ;; New area definition
                  (setf (gethash token area-map)
                        (list :name token
                              :row-start row-idx :col-start col-idx
                              :row-end (1+ row-idx) :col-end (1+ col-idx))))))
          (incf col-idx))
        (incf row-idx)))
    area-map))

;;;---------------------------------------------------------------------
;;; Resolving Grid Line Specifications
;;;---------------------------------------------------------------------

(defun resolve-grid-line-spec (line-spec line-count named-lines is-end-line default-span)
  "Resolves a grid line specification to either a zero‑based index or a
   span specification.  Supports integer indices, named lines (strings),
   :auto, (:span n), and (:span \"name\").  For end lines, a default
   span may be applied if the specification is :auto."
  (cond
    ((integerp line-spec)
     ;; Negative numbers count backwards from the end of explicit lines.
     (let ((val (if (< line-spec 0)
                    (+ line-count line-spec 1)
                    line-spec)))
       (max 0 (min (1- val) line-count))))
    ((stringp line-spec)
     ;; Named lines or areas: try the area map first, then fall back to
     ;; explicit named lines list.
     (let ((val nil))
       (cond
         ((hash-table-p named-lines)
          (let ((area-props (gethash line-spec named-lines)))
            (if (and area-props (listp area-props))
                (setf val (if is-end-line
                              (getf area-props :col-end)
                              (getf area-props :col-start)))
                (setf val :auto))))
         ((listp named-lines)
          (let ((assoc-entry (assoc line-spec named-lines :test #'string=)))
            (if assoc-entry
                (setf val (cdr assoc-entry))
                (setf val :auto)))))
       val))
    ((eq line-spec :auto)
     (if (and is-end-line (numberp default-span))
         (list :span default-span)
         :auto))
    ((and (consp line-spec) (eq (car line-spec) :span) (cadr line-spec))
     ;; Span specification is preserved
     line-spec)
    (t :auto)))

;;;---------------------------------------------------------------------
;;; Intrinsic Size Determination
;;;---------------------------------------------------------------------

;; update-item-intrinsic-dimensions wraps the measurement function to
;; populate the grid item with intrinsic width and height contributions.

(defun update-item-intrinsic-dimensions (grid-item container-available-width container-available-height)
  "Updates a grid item's min/max content contributions by measuring its
   intrinsic sizes via `measure-node-intrinsic-size'.  This must be
   invoked before performing track sizing."
  (multiple-value-bind (min-w max-w min-h max-h)
      (measure-node-intrinsic-size (grid-item-node grid-item)
                                   container-available-width
                                   container-available-height)
    (setf (grid-item-min-content-width grid-item) min-w
          (grid-item-max-content-width grid-item) max-w
          (grid-item-min-content-height grid-item) min-h
          (grid-item-max-content-height grid-item) max-h))
  grid-item)

;;;---------------------------------------------------------------------
;;; Track Sizing Helpers
;;;---------------------------------------------------------------------

(defconstant +max-grid-sizing-iterations+ 10
  "Maximum number of iterations allowed when resolving track sizes.")

(defun initialize-grid-tracks (track-defs default-auto-size track-type-keyword)
  "Create a list of grid-track structures from a list of track definitions.
   Each definition may be a number (fixed size), (:fr n) for fractional
   units, (:minmax min max) for minmax definitions, or content based
   values such as :auto, :min-content, :max-content."
  (declare (ignorable default-auto-size track-type-keyword))
  (loop for i from 0
        for def in track-defs
        collect
        (let ((type (cond
                      ((numberp def) :fixed)
                      ((and (consp def) (eq (car def) :fr) (numberp (cadr def)) (> (cadr def) 0)) :fr)
                      ((and (consp def) (eq (car def) :minmax)) :minmax)
                      ((member def '(:auto :min-content :max-content) :test #'eq) :content)
                      (t :auto))))
          (make-grid-track :index i
                           :type type
                           :definition def
                           :base-size (if (eq type :fixed)
                                          (max 0.0 (float def))
                                          0.0)
                           :fr-units (if (eq type :fr)
                                         (cadr def)
                                         0.0)
                           :growth-limit (if (and (eq type :minmax) (caddr def)
                                                  (numberp (caddr def)))
                                             (caddr def)
                                             most-positive-double-float)
                           :is-flexible (not (eq type :fixed))))))

(defun resolve-content-based-track-sizes (tracks items dimension)
  "Resolve base and growth sizes for tracks whose definition is
   content based (:auto, :min-content, :max-content).  Contributions
   from items spanning these tracks are used to compute min and max
   sizing contributions."
  (declare (ignorable items))
  (dolist (track tracks)
    (when (eq (grid-track-type track) :content)
      (let ((min-c 0.0) (max-c 0.0))
        (dolist (item (grid-track-items track))
          (let* ((item-span (if (eq dimension :width)
                                (grid-item-col-span item)
                                (grid-item-row-span item)))
                 (item-min (if (eq dimension :width)
                               (grid-item-min-content-width item)
                               (grid-item-min-content-height item)))
                 (item-max (if (eq dimension :width)
                               (grid-item-max-content-width item)
                               (grid-item-max-content-height item))))
            (when (and item-span (> item-span 0))
              (let ((contrib-min (/ item-min item-span))
                    (contrib-max (/ item-max item-span)))
                (setf min-c (max min-c contrib-min))
                (setf max-c (max max-c contrib-max))))))
        (setf (grid-track-base-size track)
              (case (grid-track-definition track)
                (:min-content min-c)
                (:max-content max-c)
                (:auto min-c)
                ;; (otherwise min-c)
                ))
        (setf (grid-track-growth-limit track) (max (grid-track-base-size track) max-c))
        (setf (grid-track-is-flexible track) nil))))
  tracks)

(defun resolve-minmax-track-sizes (tracks items dimension available-space total-gap)
  "Resolve track sizes for tracks defined with minmax().  The minimum
   and maximum bounds of a track may be numbers, :auto, or content
   keywords (:min-content, :max-content).  These are resolved
   considering the contributions from spanning items."
  (declare (ignore items dimension available-space total-gap))
  (dolist (track tracks)
    (when (eq (grid-track-type track) :minmax)
      (let* ((minmax-def (grid-track-definition track))
             (min-bound (cadr minmax-def))
             (max-bound (caddr minmax-def)))
        ;; Resolve minimum bound
        (setf min-bound
              (cond
                ((numberp min-bound) min-bound)
                ((eq min-bound :auto) (grid-track-min-contribution track))
                ;; These keywords fall back to contributions if unhandled
                ((eq min-bound :min-content) (grid-track-min-contribution track))
                ((eq min-bound :max-content) (grid-track-max-contribution track))
                (t 0.0)))
        ;; Resolve maximum bound
        (setf max-bound
              (cond
                ((numberp max-bound) max-bound)
                ((eq max-bound :auto) (grid-track-max-contribution track))
                ((eq max-bound :fr) most-positive-double-float)
                ((eq max-bound :min-content) (grid-track-min-contribution track))
                ((eq max-bound :max-content) (grid-track-max-contribution track))
                (t most-positive-double-float)))
        (setf (grid-track-base-size track)
              (max min-bound (grid-track-base-size track) (grid-track-min-contribution track)))
        (setf (grid-track-growth-limit track)
              (min max-bound (grid-track-max-contribution track)))
        (when (numberp max-bound)
          (setf (grid-track-base-size track) (min (grid-track-base-size track) max-bound))
          (when (>= (grid-track-base-size track) max-bound)
            (setf (grid-track-is-flexible track) nil))))))
  tracks)

(defun distribute-flexible-space (tracks available-space total-gap-size)
  "Distribute remaining space among tracks with fractional units (fr)
   or content based tracks that are still flexible.  Tracks marked
   non‑flexible are skipped.  This function mutates the base sizes of
   tracks in place."
  (let* ((num-flexible-auto
           (loop for track in tracks count
                                     (and (grid-track-is-flexible track)
                                          (eq (grid-track-type track) :content)
                                          (eq (grid-track-definition track) :auto))))
         (total-fr-units
           (loop for track in tracks when (and (grid-track-is-flexible track)
                                               (> (grid-track-fr-units track) 0))
                 sum (grid-track-fr-units track)))
         (fixed-and-resolved-size
           (loop for track in tracks unless (grid-track-is-flexible track)
                 sum (grid-track-base-size track)))
         (space-for-flexible (max 0.0 (- available-space fixed-and-resolved-size total-gap-size))))
    (when (> space-for-flexible 0)
      (cond
        ((> total-fr-units 0)
         (let ((size-per-fr (/ space-for-flexible total-fr-units)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track)
                        (> (grid-track-fr-units track) 0))
               (let ((growth (max 0 (* (grid-track-fr-units track) size-per-fr))))
                 (incf (grid-track-base-size track) growth)
                 (setf (grid-track-base-size track)
                       (min (grid-track-base-size track) (grid-track-growth-limit track)))
                 (setf (grid-track-is-flexible track) nil))))))
        ((> num-flexible-auto 0)
         ;; Distribute equally among remaining :auto tracks
         (let ((size-per-auto (/ space-for-flexible num-flexible-auto)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track)
                        (eq (grid-track-type track) :content)
                        (eq (grid-track-definition track) :auto))
               (incf (grid-track-base-size track) size-per-auto)
               (setf (grid-track-base-size track)
                     (min (grid-track-base-size track) (grid-track-growth-limit track)))
               (setf (grid-track-is-flexible track) nil)))))))
    tracks))

(defun calculate-final-track-sizes (tracks)
  "After the sizing iterations are complete, finalize each track's
   size by clamping it to zero if necessary."
  (dolist (track tracks)
    (setf (grid-track-final-size track)
          (max 0.0 (grid-track-base-size track))))
  tracks)

(defun perform-track-sizing-iteration (col-tracks row-tracks grid-items
                                       available-width available-height
                                       col-gap row-gap)
  "Perform a single iteration of the track sizing algorithm.  This
   function updates intrinsic contributions, resolves content and
   minmax tracks, distributes flexible space, and returns T if all
   tracks have been resolved (i.e. no longer flexible)."
  ;; Reset contributions and item lists for each track.
  (dolist (track col-tracks)
    (setf (grid-track-min-contribution track) 0.0
          (grid-track-max-contribution track) 0.0
          (grid-track-items track) nil))
  (dolist (track row-tracks)
    (setf (grid-track-min-contribution track) 0.0
          (grid-track-max-contribution track) 0.0
          (grid-track-items track) nil))
  ;; Accumulate contributions for each track from each item.
  (dolist (item grid-items)
    (loop for i from (grid-item-col-start item) to (1- (grid-item-col-end item))
          do (when (< i (length col-tracks))
               (let ((track (nth i col-tracks)))
                 (push item (grid-track-items track))
                 (setf (grid-track-min-contribution track)
                       (max (grid-track-min-contribution track)
                            (/ (grid-item-min-content-width item)
                               (grid-item-col-span item))))
                 (setf (grid-track-max-contribution track)
                       (max (grid-track-max-contribution track)
                            (/ (grid-item-max-content-width item)
                               (grid-item-col-span item)))))))
    (loop for i from (grid-item-row-start item) to (1- (grid-item-row-end item))
          do (when (< i (length row-tracks))
               (let ((track (nth i row-tracks)))
                 (push item (grid-track-items track))
                 (setf (grid-track-min-contribution track)
                       (max (grid-track-min-contribution track)
                            (/ (grid-item-min-content-height item)
                               (grid-item-row-span item))))
                 (setf (grid-track-max-contribution track)
                       (max (grid-track-max-contribution track)
                            (/ (grid-item-max-content-height item)
                               (grid-item-row-span item))))))))
  ;; Resolve content based track sizes.
  (resolve-content-based-track-sizes col-tracks grid-items :width)
  (resolve-content-based-track-sizes row-tracks grid-items :height)
  ;; Resolve minmax definitions.
  (resolve-minmax-track-sizes col-tracks grid-items :width
                              available-width (* (max 0 (1- (length col-tracks))) col-gap))
  (resolve-minmax-track-sizes row-tracks grid-items :height
                              available-height (* (max 0 (1- (length row-tracks))) row-gap))
  ;; Distribute flexible space for fr and auto tracks.
  (distribute-flexible-space col-tracks available-width
                             (* (max 0 (1- (length col-tracks))) col-gap))
  (distribute-flexible-space row-tracks available-height
                             (* (max 0 (1- (length row-tracks))) row-gap))
  ;; Determine whether all tracks have been resolved (i.e. no flexible left).
  (and (every (lambda (tr) (not (grid-track-is-flexible tr))) col-tracks)
       (every (lambda (tr) (not (grid-track-is-flexible tr))) row-tracks)))

(defun iterative-track-sizing (col-track-defs row-track-defs grid-items
                               available-width available-height
                               col-gap row-gap
                               container-available-width container-available-height)
  "Perform the full iterative track sizing algorithm for columns and rows.
   Intrinsic contributions are measured once at the start, then up to
   +max-grid-sizing-iterations+ iterations of sizing are performed
   until all tracks are resolved.  Returns two lists of final sizes.
   The additional container dimensions are provided for measurement of
   intrinsic sizes."
  ;; First measure intrinsic sizes for all items.
  (dolist (item grid-items)
    (update-item-intrinsic-dimensions item
                                      container-available-width
                                      container-available-height))
  ;; Initialize track structures.
  (let ((col-tracks (initialize-grid-tracks col-track-defs
                                            (style-value nil :grid-auto-columns :auto)
                                            :column))
        (row-tracks (initialize-grid-tracks row-track-defs
                                            (style-value nil :grid-auto-rows :auto)
                                            :row)))
    ;; Iteratively resolve tracks.
    (loop for iteration from 1 to +max-grid-sizing-iterations+
          for resolved-p = (perform-track-sizing-iteration col-tracks row-tracks grid-items
                                                           available-width available-height
                                                           col-gap row-gap)
          when resolved-p do (loop-finish))
    ;; Finalize sizes and return lists.
    (calculate-final-track-sizes col-tracks)
    (calculate-final-track-sizes row-tracks)
    (values (mapcar #'grid-track-final-size col-tracks)
            (mapcar #'grid-track-final-size row-tracks))))

;;;---------------------------------------------------------------------
;;; Item Placement and Alignment
;;;---------------------------------------------------------------------

(defun process-item-placement-properties (item-node named-area-map explicit-col-count explicit-row-count)
  "Extract placement properties from a child node.  This function reads
   :grid-area and related grid placement properties from the node's
   styles, resolves area names against named-area-map, and returns a
   plist describing the raw placement requests."
  (let* ((item-styles (styles item-node))
         (grid-area (style-value item-styles :grid-area))
         (gcs (style-value item-styles :grid-column-start :auto))
         (gce (style-value item-styles :grid-column-end :auto))
         (grs (style-value item-styles :grid-row-start :auto))
         (gre (style-value item-styles :grid-row-end :auto))
         (col-start gcs) (col-end gce) (row-start grs) (row-end gre))
    ;; Override individual placement properties with grid-area if it's a name
    (when (and (stringp grid-area) named-area-map (gethash grid-area named-area-map))
      (let ((area-def (gethash grid-area named-area-map)))
        (setf col-start (getf area-def :col-start col-start))
        (setf col-end   (getf area-def :col-end   col-end))
        (setf row-start (getf area-def :row-start row-start))
        (setf row-end   (getf area-def :row-end   row-end))))
    ;; Resolve start and end specifications to indices or spans.
    (setf col-start (resolve-grid-line-spec col-start explicit-col-count named-area-map nil 1))
    (setf row-start (resolve-grid-line-spec row-start explicit-row-count named-area-map nil 1))
    (setf col-end (resolve-grid-line-spec col-end explicit-col-count named-area-map t
                                          (if (eq col-start :auto) 1 nil)))
    (setf row-end (resolve-grid-line-spec row-end explicit-row-count named-area-map t
                                          (if (eq row-start :auto) 1 nil)))
    (list :node item-node
          :id (getf (ui-node-props item-node) :id)
          :raw-col-start col-start :raw-col-end col-end
          :raw-row-start row-start :raw-row-end row-end)))

(defun resolve-item-final-placement (item-placement-info current-auto-col current-auto-row
                                     max-cols max-rows grid-auto-flow)
  "Resolve a grid item's final column/row positions from its raw
   placement info.  Handles auto-placement, spans, and updating the
   current auto placement cursor.  Returns multiple values: a
   grid-item structure and the next auto column and row positions."
  (let ((cs (getf item-placement-info :raw-col-start))
        (ce (getf item-placement-info :raw-col-end))
        (rs (getf item-placement-info :raw-row-start))
        (re (getf item-placement-info :raw-row-end)))
    ;; Determine starting positions based on auto placements
    (multiple-value-bind (resolved-cs resolved-rs next-auto-col next-auto-row)
        (cond
          ((and (eq cs :auto) (eq rs :auto))
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
          (t
           (values cs rs current-auto-col current-auto-row)))
      (setf cs resolved-cs)
      (setf rs resolved-rs)
      ;; Resolve end lines and spans
      (setf ce (cond
                 ((eq ce :auto) (1+ cs))
                 ((listp ce) (min max-cols (+ cs (cadr ce))))
                 (t ce)))
      (setf re (cond
                 ((eq re :auto) (1+ rs))
                 ((listp re) (min max-rows (+ rs (cadr re))))
                 (t re)))
      ;; Ensure end lines are at least one beyond start and within bounds
      (setf ce (min max-cols (max ce (1+ cs))))
      (setf re (min max-rows (max re (1+ rs))))
      (values
       (make-grid-item :node (getf item-placement-info :node)
                       :id (getf item-placement-info :id)
                       :col-start cs :col-end ce
                       :row-start rs :row-end re
                       :col-span (- ce cs) :row-span (- re rs)
                       :placed-p t)
       next-auto-col next-auto-row))))

(defun align-item-in-area (item-node item-layout-rect grid-area-rect align-self justify-self)
  "Align a child within its allocated grid area based on align-self
   (vertical alignment) and justify-self (horizontal alignment).
   Returns a new rectangle representing the final position and size of
   the item.  Stretch alignment expands the item to fill the area."
  (declare (ignore item-node))
  (let ((final-rect (copy-rectangle item-layout-rect))
        (item-w (w item-layout-rect))
        (item-h (h item-layout-rect))
        (area-w (w grid-area-rect))
        (area-h (h grid-area-rect)))
    ;; Horizontal alignment via justify-self
    (case justify-self
      (:start (setf (x final-rect) (x grid-area-rect)))
      (:end   (setf (x final-rect) (+ (x grid-area-rect) (- area-w item-w))))
      (:center (setf (x final-rect) (+ (x grid-area-rect)
                                       (round (/ (- area-w item-w) 2)))))
      (:stretch
       (setf (x final-rect) (x grid-area-rect))
       (setf (w final-rect) area-w))
      (otherwise (setf (x final-rect) (x grid-area-rect))))
    ;; Vertical alignment via align-self
    (case align-self
      (:start (setf (y final-rect) (y grid-area-rect)))
      (:end   (setf (y final-rect) (+ (y grid-area-rect) (- area-h item-h))))
      (:center (setf (y final-rect) (+ (y grid-area-rect)
                                       (round (/ (- area-h item-h) 2)))))
      (:stretch
       (setf (y final-rect) (y grid-area-rect))
       (setf (h final-rect) area-h))
      (otherwise (setf (y final-rect) (y grid-area-rect))))
    final-rect))

;;;---------------------------------------------------------------------
;;; Grid Layout Container Implementation
;;;---------------------------------------------------------------------

(defmethod layout-grid-container-impl (grid-container-node available-rect)
  "Layout a grid container node within the given available rectangle.
   This method is dispatched by the general layout system when a node
   has :display set to :grid.  It performs auto placement, track sizing,
   alignment of items, and recursively lays out children."
  (unless (and grid-container-node (typep grid-container-node 'styled-ui-node))
    (error "layout-grid-container requires a styled-ui-node for the container."))
  (unless (and available-rect (typep available-rect 'rectangle))
    (error "layout-grid-container requires a valid available-rect."))
  (let* ((container-styles (styles grid-container-node))
         (children (ui-node-children grid-container-node))
         (parent-absolute-content-rect available-rect)
         (template-areas-str (style-value container-styles :grid-template-areas))
         (named-area-map (if template-areas-str
                             (parse-grid-template-areas (ensure-list template-areas-str))
                             nil))
         (col-defs (ensure-list (style-value container-styles :grid-template-columns '(:auto))))
         (row-defs (ensure-list (style-value container-styles :grid-template-rows '(:auto)))))
    (let* ((auto-flow (style-value container-styles :grid-auto-flow :row))
           (grid-auto-cols (style-value container-styles :grid-auto-columns :auto))
           (grid-auto-rows (style-value container-styles :grid-auto-rows :auto))
           (explicit-col-count (length col-defs))
           (explicit-row-count (length row-defs))
           (col-gap (style-value container-styles :grid-column-gap 0))
           (row-gap (style-value container-styles :grid-row-gap 0))
           (container-offset-x (x parent-absolute-content-rect))
           (container-offset-y (y parent-absolute-content-rect))
           (all-raw-item-infos '())
           (all-grid-items '())
           (laid-out-children '()))
      ;; Step 1: collect raw placement info for each child node.
      (setf all-raw-item-infos
            (loop for child-node in children
                  when (typep child-node 'styled-ui-node)
                    collect (process-item-placement-properties child-node
                                                               named-area-map
                                                               explicit-col-count
                                                               explicit-row-count)))
      ;; Step 2: auto placement pass.  Resolve raw specs into grid items.
      (let ((current-auto-col 0)
            (current-auto-row 0)
            (max-cols-needed explicit-col-count)
            (max-rows-needed explicit-row-count)
            (resolved-items-temp '()))
        (dolist (raw-item-info all-raw-item-infos)
          (multiple-value-bind (resolved-item next-c next-r)
              (resolve-item-final-placement raw-item-info current-auto-col current-auto-row
                                            max-cols-needed max-rows-needed auto-flow)
            (declare (ignorable next-c next-r))
            (push resolved-item resolved-items-temp)
            (setf max-cols-needed (max max-cols-needed (grid-item-col-end resolved-item)))
            (setf max-rows-needed (max max-rows-needed (grid-item-row-end resolved-item)))
            ;; Advance auto cursor based on flow direction
            (if (eq auto-flow :row)
                (progn
                  (setf current-auto-col (grid-item-col-end resolved-item))
                  (when (and (>= current-auto-col max-cols-needed) (> max-cols-needed 0))
                    (setf current-auto-col 0)
                    (incf current-auto-row)))
                (progn
                  (setf current-auto-row (grid-item-row-end resolved-item))
                  (when (and (>= current-auto-row max-rows-needed) (> max-rows-needed 0))
                    (setf current-auto-row 0)
                    (incf current-auto-col))))))
        (setf all-grid-items (nreverse resolved-items-temp))
        ;; If auto placement extended beyond explicit tracks, append auto tracks
        (when (> max-cols-needed (length col-defs))
          (setf col-defs (append col-defs
                                 (make-list (- max-cols-needed (length col-defs))
                                            :initial-element grid-auto-cols))))
        (when (> max-rows-needed (length row-defs))
          (setf row-defs (append row-defs
                                 (make-list (- max-rows-needed (length row-defs))
                                            :initial-element grid-auto-rows)))))
      ;; Calculate available track space (account for gaps)
      (let ((available-track-w
              (max 0 (- (w parent-absolute-content-rect)
                        (* (max 0 (1- (length col-defs))) col-gap))))
            (available-track-h
              (max 0 (- (h parent-absolute-content-rect)
                        (* (max 0 (1- (length row-defs))) row-gap)))))
        ;; Step 3: iterative track sizing
        (multiple-value-bind (final-col-sizes final-row-sizes)
            (iterative-track-sizing col-defs row-defs all-grid-items
                                    available-track-w available-track-h
                                    col-gap row-gap
                                    (w parent-absolute-content-rect)
                                    (h parent-absolute-content-rect))
          ;; Step 4: layout each item and align within its area
          (dolist (grid-item all-grid-items)
            (let* ((cs (grid-item-col-start grid-item))
                   (ce (grid-item-col-end grid-item))
                   (rs (grid-item-row-start grid-item))
                   (re (grid-item-row-end grid-item))
                   (item-node (grid-item-node grid-item))
                   (item-styles (styles item-node))
                   ;; Determine area rectangle for this item
                   (area-x (+ container-offset-x
                              (loop for i from 0 below cs
                                    sum (or (nth i final-col-sizes) 0))
                              (* cs col-gap)))
                   (area-y (+ container-offset-y
                              (loop for i from 0 below rs
                                    sum (or (nth i final-row-sizes) 0))
                              (* rs row-gap)))
                   (area-w (max 0 (+ (loop for i from cs below ce
                                           sum (or (nth i final-col-sizes) 0))
                                     (if (> (- ce cs) 0)
                                         (* (max 0 (1- (- ce cs))) col-gap)
                                         0))))
                   (area-h (max 0 (+ (loop for i from rs below re
                                           sum (or (nth i final-row-sizes) 0))
                                     (if (> (- re rs) 0)
                                         (* (max 0 (1- (- re rs))) row-gap)
                                         0))))
                   (grid-area-rect (make-rectangle
                                    :pos (make-pos :x area-x :y area-y)
                                    :size (make-size :w area-w :h area-h)))
                   ;; Recursively lay out the child inside its area
                   (laid-out-child (layout-node item-node grid-area-rect container-styles))
                   (child-layout-rect (getf (ui-node-props laid-out-child) :layout-rect)))
              (when laid-out-child
                (let* ((align (style-value item-styles :align-self
                                           (style-value container-styles :align-items :stretch)))
                       (justify (style-value item-styles :justify-self
                                             (style-value container-styles :justify-items :stretch)))
                       (final-item-rect (align-item-in-area laid-out-child
                                                            child-layout-rect
                                                            grid-area-rect
                                                            align justify)))
                  (setf (getf (ui-node-props laid-out-child) :layout-rect)
                        final-item-rect)
                  (push laid-out-child laid-out-children)))))
          ;; Step 5: update container node and return
          (let ((new-container (copy-styled-node grid-container-node)))
            (setf (ui-node-children new-container) (nreverse laid-out-children))
            ;; Compute container final size based on explicit styles or content
            (let* ((container-w-style (style-value container-styles :width))
                   (container-h-style (style-value container-styles :height))
                   (total-cols-width (+ (loop for size in final-col-sizes sum size)
                                        (if (> (length col-defs) 0)
                                            (* (max 0 (1- (length col-defs))) col-gap)
                                            0)))
                   (total-rows-height (+ (loop for size in final-row-sizes sum size)
                                         (if (> (length row-defs) 0)
                                             (* (max 0 (1- (length row-defs))) row-gap)
                                             0)))
                   (container-final-w (if (eq container-w-style :auto)
                                          total-cols-width
                                          (w parent-absolute-content-rect)))
                   (container-final-h (if (eq container-h-style :auto)
                                          total-rows-height
                                          (h parent-absolute-content-rect))))
              (setf (getf (ui-node-props new-container) :layout-rect)
                    (make-rectangle :pos (make-pos :x container-offset-x :y container-offset-y)
                                    :size (make-size :w container-final-w :h container-final-h))))
            new-container))))))

;;;---------------------------------------------------------------------
;;; Dispatch Method Override
;;;---------------------------------------------------------------------

;; When a styled node has :display set to :grid, this dispatch
;; overrides the default layout engine and calls layout-grid-container-impl.

(defmethod dispatch-layout ((display (eql :grid)) node available-rect)
  (let ((result (layout-grid-container-impl node available-rect)))
    (if result
        (let ((children (ui-node-children result))
              (container-layout (getf (ui-node-props result) :layout-rect)))
          (values children (h container-layout) (w container-layout)))
        (values (ui-node-children node) 0 0))))

;;;====================================================================
;;; High Level Grid Template API
;;;====================================================================

;; This section implements user facing helpers for declaring grid
;; templates, areas, responsive configurations, and building grids
;; programmatically.  These helpers use simple lists and strings to
;; describe grid structures and rely on the low level engine for
;; actual layout.

;;;---------------------------------------------------------------------
;;; Template Parsing
;;;---------------------------------------------------------------------

(defun parse-grid-template (template)
  "Parse a grid template string into a structured representation.
   Templates are delimited by \" | \" for rows and space for columns.
   Dots (\".\") denote empty cells.  Returns a list of rows where
   each row is a list of area names or NIL for empty cells."
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
  "Create a grid template configuration.  ROWS and COLUMNS are lists
    of strings describing track sizes (e.g. '(\"auto\" \"1fr\" \"30\")).
    AREAS may be a template string or a parsed representation.  Returns
    a plist with :grid-template-rows, :grid-template-columns, and
    :grid-template-areas."
  (let ((parsed-areas (if (stringp areas)
                          (parse-grid-template areas)
                          areas)))
    (list :grid-template-rows rows
          :grid-template-columns columns
          :grid-template-areas parsed-areas)))

(defun grid-area (name &key row-start row-end col-start col-end)
  "Create a grid area placement specification for a single item.
    NAME refers to a named area in the template.  ROW-START/END and
    COL-START/END specify line numbers.  Returns a plist of
    placement properties."
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
  "Return a string representing the CSS grid-auto-flow property.  DIRECTION
    is one of :row or :column; if DENSE is true, " dense" is appended."
  (if dense
      (format nil "~A dense" (string-downcase direction))
      (string-downcase direction)))

(defun grid-responsive (base-config breakpoints)
  "Create a responsive grid configuration.  BASE-CONFIG is the
   default grid configuration (as a plist) for all viewport sizes.
   BREAKPOINTS is an alist mapping viewport widths to grid
   configurations (plists).  Returns a plist with responsive info."
  (list :grid-base-config base-config
        :grid-breakpoints breakpoints))

(defun make-grid-item-plist (&key area row-start row-end col-start col-end align-self justify-self
                               node id placed-p col-span row-span)
  "Construct a grid item plist for high level grid creation.  AREA
   names a template area.  ROW-START/END and COL-START/END specify
   placement lines.  ALIGN-SELF and JUSTIFY-SELF specify alignment
   values."
  (let ((props (grid-area area
                          :row-start row-start
                          :row-end row-end
                          :col-start col-start
                          :col-end col-end)))
    (when align-self
      (setf props (list* :align-self (string-downcase align-self) props)))
    (when justify-self
      (setf props (list* :justify-self (string-downcase justify-self) props)))
    (when node
      (setf props (list* :node node props)))
    (when id
      (setf props (list* :id id props)))
    (when placed-p
      (setf props (list* :placed-p placed-p props)))
    (when col-span
      (setf props (list* :col-span col-span props)))
    (when row-span
      (setf props (list* :row-span row-span props)))
    (when (and col-start col-end)
      (setf props (list* :raw-col-start col-start
                         :raw-col-end col-end props)))

    (when (and row-start row-end)
      (setf props (list* :raw-row-start row-start
                         :raw-row-end row-end props)))

    (setf (getf props :grid-item) t)
    (setf (getf props :grid-item-id) id)
    (setf (getf props :grid-item-placed) placed-p)
    (setf (getf props :grid-item-col-span) col-span)
    (setf (getf props :grid-item-row-span) row-span)
    props))

(defun make-grid-item (&key row-start row-end col-start col-end align-self justify-self
                         node id placed-p col-span row-span)
  "Construct a grid item plist for high level grid creation.  AREA
   names a template area.  ROW-START/END and COL-START/END specify
   placement lines.  ALIGN-SELF and JUSTIFY-SELF specify alignment
   values."
  (%make-grid-item :node node
                   :id id
                   :placed-p placed-p
                   :col-span col-span
                   :row-span row-span
                   :align-self (and align-self (string-downcase align-self))
                   :justify-self (and justify-self (string-downcase justify-self))
                   :raw-col-start (or col-start :auto)
                   :raw-col-end (or col-end :auto)
                   :raw-row-start (or row-start :auto)
                   :raw-row-end (or row-end :auto)))
;;;---------------------------------------------------------------------
;;; Named Grid Template Definitions
;;;---------------------------------------------------------------------

(defstruct (grid-template-definition (:constructor %make-grid-template-definition))
  "Structure encapsulating a complete grid template with rows, columns,
   parsed areas, and a map of area names to their coordinates."
  (name nil :type symbol :read-only t)
  (rows nil :type list :read-only t)
  (columns nil :type list :read-only t)
  (areas nil :type list :read-only t)
  (area-map (make-hash-table :test 'equal) :type hash-table))

(defun define-grid-template (name rows columns areas)
  "Create and register a named grid template.  NAME is a symbol used
   to identify the template.  ROWS and COLUMNS are lists of size
   definitions.  AREAS may be a template string or a parsed template
   representation.  Returns a grid-template-definition."
  (let* ((parsed-areas (if (stringp areas) (parse-grid-template areas) areas))
         (template (%make-grid-template-definition :name name
                                                   :rows rows
                                                   :columns columns
                                                   :areas parsed-areas))
         (area-map (grid-template-definition-area-map template)))
    ;; Populate area map with coordinates
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
  "Compute the bounding rectangle of a contiguous named area in the
   parsed template AREAS.  Returns four values: start-row, start-col,
   end-row, and end-col (zero based)."
  (let ((start-row row)
        (start-col col)
        (end-row row)
        (end-col col)
        (num-rows (length areas))
        (num-cols (length (first areas))))
    ;; Expand to the right
    (loop for c from col below num-cols
          while (and (< c (length (nth row areas)))
                     (string= (nth c (nth row areas)) area-name))
          do (setf end-col c))
    ;; Expand downward
    (loop for r from row below num-rows
          while (and (< r num-rows)
                     (< col (length (nth r areas)))
                     (string= (nth col (nth r areas)) area-name))
          do (setf end-row r))
    (values start-row start-col end-row end-col)))

(defun get-grid-area-coordinates (template area-name)
  "Return the coordinate plist for AREA-NAME in TEMPLATE.  TEMPLATE is
   a grid-template-definition.  The returned plist contains
   :row-start, :col-start, :row-end, and :col-end (1‑based).
   Returns NIL if the area is not found."
  (gethash area-name (grid-template-definition-area-map template)))

(defun render-grid-template (template)
  "Render a visual representation of TEMPLATE as an ASCII grid.  Each
   cell displays the first character of the area name or a space for
   empty cells.  Returns a list of strings (rows)."
  (let* ((areas (grid-template-definition-areas template))
         (num-rows (length areas))
         (num-cols (apply #'max (mapcar #'length areas)))
         (result-lines nil))
    ;; Header
    (push (format nil "   ~{~2d~}" (loop for i from 1 to num-cols collect i)) result-lines)
    (push (format nil "  ~v@{~A~:*~}" (+ (* 2 num-cols) 1) "-") result-lines)
    ;; Each row with row number and area letters
    (loop for row-index from 0 below num-rows
          for row in areas
          do (push (format nil "~2d|~{~2a~}"
                           (1+ row-index)
                           (loop for col-index from 0 below num-cols
                                 collect (if (and (< col-index (length row))
                                                  (nth col-index row)
                                                  (not (string= (nth col-index row) ".")))
                                             (string (char (nth col-index row) 0))
                                             " ")))
                   result-lines))
    (reverse result-lines)))

(defun build-grid-from-template (template children
                                 &key gap row-gap column-gap
                                   justify-items align-items)
  "Build a grid container using a named TEMPLATE definition and a
   collection of children.  CHILDREN may be an alist mapping area
   names to elements or a list of elements with placement props.
   Returns a styled node representing the grid."
  (let* ((rows (grid-template-definition-rows template))
         (columns (grid-template-definition-columns template))
         (areas (grid-template-definition-areas template))
         (child-elements
           (if (and (consp (car children)) (consp (caar children)))
               ;; Convert alist to children with placement props
               (loop for (area-name . element) in children
                     for coords = (get-grid-area-coordinates template area-name)
                     when coords
                       collect (let ((props (append coords (getf element :props))))
                                 (setf (getf element :props) props)
                                 element))
               ;; Already annotated children
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
  "Convert a linear index POSITION (0‑based) into row and column
   coordinates given the number of columns in the grid.  Returns two
   values: row and column (both 0‑based)."
  (values (floor position grid-width) (mod position grid-width)))

;;;---------------------------------------------------------------------
;;; Grid Creation Helper
;;;---------------------------------------------------------------------

(defun make-grid (&key template-rows template-columns template-areas
                    auto-flow gap row-gap column-gap
                    justify-content align-content
                    justify-items align-items
                    children)
  "Create a styled grid node with the given properties.  The
   properties correspond to CSS grid properties.  CHILDREN is a
   sequence of styled nodes or other UI nodes.  Returns a new
   styled-node representing the grid container."
  (let ((grid-props (list :display :grid)))
    ;; Add template definitions
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
    ;; Flow and gaps
    (when auto-flow
      (setf grid-props (list* :grid-auto-flow auto-flow grid-props)))
    (when gap
      (setf grid-props (list* :gap gap grid-props)))
    (when row-gap
      (setf grid-props (list* :row-gap row-gap grid-props)))
    (when column-gap
      (setf grid-props (list* :column-gap column-gap grid-props)))
    ;; Alignment properties
    (when justify-content
      (setf grid-props (list* :justify-content justify-content grid-props)))
    (when align-content
      (setf grid-props (list* :align-content align-content grid-props)))
    (when justify-items
      (setf grid-props (list* :justify-items justify-items grid-props)))
    (when align-items
      (setf grid-props (list* :align-items align-items grid-props)))
    ;; Construct the node
    (make-styled-node
     :type :div
     :props grid-props
     :children children)))

;;;---------------------------------------------------------------------
;;; Simplified Grid Layout Computation (for non‑UI use)
;;;---------------------------------------------------------------------

(defun find-named-area-coordinates (template-areas area-name)
  "Find the coordinates of AREA-NAME within TEMPLATE-AREAS, which is
   a parsed representation (list of lists).  Returns a plist with
   :row-start, :col-start, :row-end, and :col-end (1‑based) and a
   boolean indicating success."
  (loop for r from 0 below (length template-areas)
        for row = (nth r template-areas)
        do (loop for c from 0 below (length row)
                 for current = (nth c row)
                 when (and current (string= current area-name))
                   do (multiple-value-bind (sr sc er ec)
                          (compute-area-bounds template-areas r c area-name)
                        (return-from find-named-area-coordinates
                          (values (list :row-start (1+ sr)
                                        :col-start (1+ sc)
                                        :row-end (1+ er)
                                        :col-end (1+ ec))
                                  t)))))
  (values nil nil))

(defun compute-grid-layout (container-width container-height grid-props children)
  "Compute layout for a grid container given numeric dimensions.  This
   simplified layout function distributes space evenly among tracks
   rather than using the full iterative algorithm.  It is provided
   primarily for testing and non‑UI purposes.  Returns a plist with
   layout information for the container and its children."
  (let* ((template-rows (getf grid-props :grid-template-rows '("auto")))
         (template-columns (getf grid-props :grid-template-columns '("1fr")))
         (template-areas (getf grid-props :grid-template-areas nil))
         (auto-flow (getf grid-props :grid-auto-flow "row"))
         (dense-packing (search "dense" auto-flow))
         (flow-direction (if (search "column" auto-flow) :column :row))
         (gap (getf grid-props :gap 0))
         (row-gap (getf grid-props :row-gap gap))
         (column-gap (getf grid-props :column-gap gap))
         (num-columns (length template-columns))
         (num-rows (length template-rows))
         (row-sizes nil) (column-sizes nil) (child-layouts nil))
    ;; Distribute widths and heights evenly
    (setf column-sizes
          (if (= num-columns 1)
              (list container-width)
              (let ((space (- container-width (* column-gap (1- num-columns)))))
                (loop repeat num-columns collect (/ space num-columns)))))
    (setf row-sizes
          (if (= num-rows 1)
              (list container-height)
              (let ((space (- container-height (* row-gap (1- num-rows)))))
                (loop repeat num-rows collect (/ space num-rows)))))
    ;; Compute each child's layout based on grid-area or explicit lines
    (loop for child in children
          for props = (if (ui-node-p child)
                          (ui-node-props child)
                          (when (typep child 'hash-table)
                            (gethash :props child)))
          for area-name = (getf props :grid-area)
          for row-start = (getf props :grid-row-start)
          for row-end = (getf props :grid-row-end)
          for col-start = (getf props :grid-column-start)
          for col-end = (getf props :grid-column-end)
          do (multiple-value-bind (coords found)
                 (if (and area-name template-areas)
                     (find-named-area-coordinates template-areas area-name)
                     (values nil nil))
               (declare (ignore found))
               (let* ((r-start (or (getf coords :row-start) row-start 1))
                      (r-end   (or (getf coords :row-end)   row-end   (1+ (or r-start 1))))
                      (c-start (or (getf coords :col-start) col-start 1))
                      (c-end   (or (getf coords :col-end)
                                   col-end
                                   (1+ (or c-start 1))))
                      (x 0) (y 0) (width 0) (height 0))
                 ;; Compute x,y,width,height
                 (setf x (if (> c-start 0)
                             (+ (reduce #'+ (subseq column-sizes 0 (1- c-start)))
                                (* column-gap (1- c-start)))
                             0))
                 (setf y (if (> r-start 0)
                             (+ (reduce #'+ (subseq row-sizes 0 (1- r-start)))
                                (* row-gap (1- r-start)))
                             0))
                 (setf width (- (+ (reduce #'+ (subseq column-sizes (1- c-start) (1- c-end)))
                                   (* column-gap (- c-end c-start))) column-gap))
                 (setf height (- (+ (reduce #'+ (subseq row-sizes (1- r-start) (1- r-end)))
                                    (* row-gap (- r-end r-start))) row-gap))
                 (push (list :x x :y y :width width :height height
                             :row-start r-start :row-end r-end
                             :col-start c-start :col-end c-end)
                       child-layouts))))
    ;; Return summary
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
          :child-layouts (nreverse child-layouts))))
