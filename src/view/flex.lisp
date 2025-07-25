;;; ===============================================================
;;; File: src/view/flex.lisp
;;; Flexbox Layout Engine (Ported/Refactored from uncharming-tui.flex)
;;; ===============================================================
(uiop:define-package :elmtui.view.layout.flex
  (:use :cl #:log4cl)
  (:nicknames :et.flex)
  ;; Import from the refactored geo package
  (:import-from :elmtui.style-lib.api #:stylesheet #:style-rule #:make-style-set)
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y #:make-rectangle #:make-pos #:make-size
                #:pos-x #:pos-y #:size-w #:size-h #:rectangle-pos #:rectangle-size
                #:dx! #:dy! #:valid-p)
  ;; Import styling support
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value
                #:ui-node #:styles
                #:ui-node-props
                #:ui-node-children)
  (:export
   #:main-axis
   #:flex-container
   #:compute-flex-layout
   #:flex-item
   #:layout-flex-container
   #:flex-item-children
   #:flex-direction
   #:min-width
   #:max-width
   #:min-height
   #:max-height
   #:order
   #:child-container
   #:clamp
   #:flex-grow
   #:flex-shrink
   #:flex-basis
   #:align-self
   #:align-items
   #:align-content
   #:flex-wrap
   #:justify-content
   #:flex-line
   #:items
   #:main-size  ; Represents border-box size for flex-item, margin-box sum for flex-line
   #:cross-size ; Represents border-box size for flex-item, max margin-box for flex-line
   #:collect-flex-lines
   #:get-flex-item-margin-box-main-size
   #:get-flex-item-margin-box-cross-size
   #:get-flex-item-border-box-main-size
   #:get-flex-item-border-box-cross-size
   #:set-flex-item-main-position
   #:set-flex-item-cross-position
   #:set-flex-item-main-size    ; Sets border-box size
   #:set-flex-item-cross-size   ; Sets border-box size
   #:derive-available-main-size
   #:axis->direction))
(in-package :elmtui.view.layout.flex)

(defun propagate-offset! (item dx dy)
  "Shift ITEM’s rectangle by DX/DY **and** do the same for the whole subtree."
  (dx! (rectangle item) dx)
  (dy! (rectangle item) dy)
  (when (typep item 'flex-container)
    (dolist (child (flex-item-children item))
      (propagate-offset! child dx dy))))
;;; ----------------------------------------------------------------------------
;;; HELPERS & UTILITIES
;;; ----------------------------------------------------------------------------
(defun clamp (value min max)
  "Clamp VALUE between MIN and MAX.

Arguments:
  VALUE -- The value to clamp (number).
  MIN   -- The minimum allowed value (number).
  MAX   -- The maximum allowed value (number).

Returns:
  (number) -- VALUE, but not less than MIN and not greater than MAX.

Example:
  (clamp 5 1 10) ; => 5
  (clamp -2 0 8) ; => 0

Type:
  (number, number, number) => number

Purity:
  Pure (no side effects).
  "
  ;; Clamp VALUE to the [MIN, MAX] range.
  (max min (min value max)))

;;; Generic definitions for properties with defaults.
(defgeneric child-container (object)
  (:documentation
   "Return the child flex-container of OBJECT, if any.

Arguments:
  OBJECT -- The object to query (any type).

Returns:
  (flex-container or nil) -- The child flex-container if present, else NIL.

Type:
  (t) => flex-container | nil

Purity:
  Pure (no side effects).
  "))

(defmethod child-container ((object t))
  "Default method for child-container. Returns NIL for objects with no child flex-container.

Arguments:
  OBJECT -- Any object.

Returns:
  NIL -- Always returns NIL.

Type:
  (t) => nil

Purity:
  Pure (no side effects).
  "
  nil)

;;; Style value access
(defgeneric extract-style-value (object property &optional default)
  (:documentation "Extract a style value from an object, falling back to default."))

(defmethod extract-style-value ((object t) property &optional default)
  "Default method returns default value."
  (declare (ignore property))
  default)

(defmethod extract-style-value ((object styled-ui-node) property &optional default)
  "Extract styled properties from styled-ui-node."
  (style-value object property default))

(defgeneric flex-grow (object)
  (:documentation "Return how much OBJECT can grow. Defaults to 0 if not set."))
(defmethod flex-grow ((object t)) 0)
(defmethod flex-grow ((object styled-ui-node))
  (extract-style-value object :flex-grow 0))

(defgeneric flex-shrink (object)
  (:documentation "Return how much OBJECT can shrink. Defaults to 1 for flex-items, 0 otherwise."))
(defmethod flex-shrink ((object t)) 0)
(defmethod flex-shrink ((object styled-ui-node))
  (extract-style-value object :flex-shrink 1))

(defgeneric flex-basis (object)
  (:documentation "Return the flex-basis value. Nil means 'auto'."))
(defmethod flex-basis ((object t)) nil)
(defmethod flex-basis ((object styled-ui-node))
  (extract-style-value object :flex-basis nil))

(defgeneric align-self (object)
  (:documentation "Return the alignment for OBJECT on the cross axis. Defaults to nil (auto)."))
(defmethod align-self ((object t)) nil)
(defmethod align-self ((object styled-ui-node))
  (extract-style-value object :align-self nil))

(defgeneric min-width (object)
  (:documentation "Return minimum width constraint."))
(defmethod min-width ((object t)) 0)
(defmethod min-width ((object styled-ui-node))
  (extract-style-value object :min-width 0))

(defgeneric max-width (object)
  (:documentation "Return maximum width constraint."))
(defmethod max-width ((object t)) most-positive-fixnum)
(defmethod max-width ((object styled-ui-node))
  (extract-style-value object :max-width most-positive-fixnum))

(defgeneric min-height (object)
  (:documentation "Return minimum height constraint."))
(defmethod min-height ((object t)) 0)
(defmethod min-height ((object styled-ui-node))
  (extract-style-value object :min-height 0))

(defgeneric max-height (object)
  (:documentation "Return maximum height constraint."))
(defmethod max-height ((object t)) most-positive-fixnum)
(defmethod max-height ((object styled-ui-node))
  (extract-style-value object :max-height most-positive-fixnum))

(defgeneric order (object)
  (:documentation "Return layout order. Lower values come first."))
(defmethod order ((object t)) 0)
(defmethod order ((object styled-ui-node))
  (extract-style-value object :order 0))

;;; ----------------------------------------------------------------------------
;;; FLEX ITEM CLASS
;;; ----------------------------------------------------------------------------
(defclass flex-item ()
  ((rectangle
    :initarg :rectangle
    :initform (make-rectangle :pos (make-pos :x 0 :y 0)
                              :size (make-size :w 0 :h 0))
    :accessor rectangle)
   (flex-basis
    :initarg :flex-basis
    :initform nil ; Use nil to indicate 'auto' or default sizing
    :accessor flex-basis)
   (min-width
    :initarg :min-width
    :initform 0
    :accessor min-width)
   (max-width
    :initarg :max-width
    :initform most-positive-fixnum
    :accessor max-width)
   (min-height
    :initarg :min-height
    :initform 0
    :accessor min-height)
   (max-height
    :initarg :max-height
    :initform most-positive-fixnum
    :accessor max-height)
   (order
    :initarg :order
    :initform 0
    :accessor order)
   (flex-grow
    :initarg :flex-grow
    :initform 0
    :type (real 0 *) ; Ensure non-negative
    :accessor flex-grow)
   (flex-shrink
    :initarg :flex-shrink
    :initform 1 ; Default shrink factor is 1
    :type (real 0 *) ; Ensure non-negative
    :accessor flex-shrink)
   ;; Internal layout state: these store BORDER-BOX dimensions
   (main-size
    :initform 0
    :accessor main-size)
   (cross-size
    :initform 0
    :accessor cross-size)
   ;; Nested container support
   (child-container
    :initarg :child-container
    :initform nil
    :accessor child-container)
   ;; Alignment override
   (align-self
    :initarg :align-self
    :initform nil ; Inherits from container by default (nil means auto)
    :type (member nil :auto :flex-start :flex-end :center :baseline :stretch)
    :accessor align-self)
   ;; Margins
   (margin-top
    :initarg :margin-top
    :initform 0
    :accessor margin-top)
   (margin-right
    :initarg :margin-right
    :initform 0
    :accessor margin-right)
   (margin-bottom
    :initarg :margin-bottom
    :initform 0
    :accessor margin-bottom)
   (margin-left
    :initarg :margin-left
    :initform 0
    :accessor margin-left)))
;; (defmethod children ((item flex-item))
;;   "Return the children of the flex-item, if any."
;;   (flex-item-children item))
(defmethod elmtui.view.geo:rectangle ((item flex-item))
  "Return the rectangle representing the flex-item's border-box."
  (slot-value item 'rectangle))

(defmethod (setf elmtui.view.geo:rectangle) (new-value (item flex-item))
  "Set the rectangle representing the flex-item's border-box."
  (setf (slot-value item 'rectangle) new-value))

;; (defmethod elmtui.view.geo:rectangle ((n styled-ui-node))
;;   "Return the rectangle representing the styled-ui-node's border-box."

;; Geometric accessors for flex-item, delegating to its rectangle slot
(defmethod elmtui.view.geo:x ((item flex-item))
  (elmtui.view.geo:x (rectangle item)))

(defmethod elmtui.view.geo:y ((item flex-item))
  (elmtui.view.geo:y (rectangle item)))

(defmethod elmtui.view.geo:w ((item flex-item))
  (elmtui.view.geo:w (rectangle item)))

(defmethod elmtui.view.geo:h ((item flex-item))
  (elmtui.view.geo:h (rectangle item)))

(defmethod (setf elmtui.view.geo:x) (new-value (item flex-item))
  (setf (elmtui.view.geo:x (rectangle item)) new-value))

(defmethod (setf elmtui.view.geo:y) (new-value (item flex-item))
  (setf (elmtui.view.geo:y (rectangle item)) new-value))

(defmethod (setf elmtui.view.geo:w) (new-value (item flex-item))
  (setf (elmtui.view.geo:w (rectangle item)) new-value))

(defmethod (setf elmtui.view.geo:h) (new-value (item flex-item))
  (setf (elmtui.view.geo:h (rectangle item)) new-value))

;; We also define the generic for a flex-item to return its child container.
(defmethod child-container ((item flex-item))
  (slot-value item 'child-container))

;;; ----------------------------------------------------------------------------
;;; FLEX CONTAINER CLASS
;;; ----------------------------------------------------------------------------
(defgeneric main-axis (object)
  (:documentation "Get the flex direction/main axis."))
(defmethod main-axis ((object t)) :row)
(defmethod main-axis ((object styled-ui-node))
  (extract-style-value object :flex-direction :row))

(defgeneric flex-wrap (object)
  (:documentation "Get flex-wrap setting."))
(defmethod flex-wrap ((object t)) :nowrap)
(defmethod flex-wrap ((object styled-ui-node))
  (extract-style-value object :flex-wrap :nowrap))

(defgeneric justify-content (object)
  (:documentation "Get justify-content setting."))
(defmethod justify-content ((object t)) :flex-start)
(defmethod justify-content ((object styled-ui-node))
  (extract-style-value object :justify-content :flex-start))

(defgeneric align-items (object)
  (:documentation "Get align-items setting."))
(defmethod align-items ((object t)) :stretch)
(defmethod align-items ((object styled-ui-node))
  (extract-style-value object :align-items :stretch))

(defgeneric align-content (object)
  (:documentation "Get align-content setting."))
(defmethod align-content ((object t)) :stretch)
(defmethod align-content ((object styled-ui-node))
  (extract-style-value object :align-content :stretch))

(defclass flex-container (flex-item)
  ((children
    :initarg :children
    :initform nil
    :accessor flex-item-children)
   (main-axis
    :initarg :main-axis
    :initform :row
    :type (member :row :row-reverse :column :column-reverse)
    :accessor %main-axis)
   (flex-wrap
    :initarg :flex-wrap
    :initform :nowrap
    :type (member :nowrap :wrap :wrap-reverse)
    :accessor %flex-wrap)
   (justify-content
    :initarg :justify-content
    :initform :flex-start
    :type (member :flex-start :flex-end :center :space-between :space-around :space-evenly)
    :accessor %justify-content)
   (align-items
    :initarg :align-items
    :initform :stretch
    :type (member :stretch :flex-start :flex-end :center :baseline :auto)
    :accessor %align-items)
   (align-content
    :initarg :align-content
    :initform :stretch
    :type (member :stretch :flex-start :flex-end :center :space-between :space-around)
    :accessor %align-content)))

(defmethod flex-item-children ((flex-item flex-item))
  "Return the children of a flex-item, which may be a flex-container."
  nil)

(defmethod main-axis ((container flex-container))
  "Return the main axis of the flex container, which is determined by its flex-direction."
  (let ((direction (%main-axis container)))
    (case direction
      (:row :row)
      (:row-reverse :row-reverse)
      (:column :column)
      (:column-reverse :column-reverse)
      (otherwise (error "Unsupported flex direction: ~a" direction)))))
(defmethod main-axis ((container styled-ui-node))
  (extract-style-value container :flex-direction (%main-axis container)))
(defmethod flex-wrap ((container flex-container))
  (%flex-wrap container))
(defmethod flex-wrap ((container styled-ui-node))
  (extract-style-value container :flex-wrap (%flex-wrap container)))

(defmethod justify-content ((container flex-container))
  (%justify-content container))
(defmethod justify-content ((container styled-ui-node))
  (extract-style-value container :justify-content (%justify-content container)))

(defmethod align-items ((container flex-container))
  (%align-items container))

(defmethod align-items ((container styled-ui-node))
  (extract-style-value container :align-items (%align-items container)))

(defmethod align-content ((container flex-container))
  (%align-content container))

(defmethod align-content ((container styled-ui-node))
  (extract-style-value container :align-content (%align-content container)))

;;; ----------------------------------------------------------------------------
;;; FLEX LINE CLASS (Internal Helper for Layout)
;;; ----------------------------------------------------------------------------
(defclass flex-line ()
  ((items
    :initarg :items
    :initform nil
    :accessor items)
   (main-size ; Sum of MARGIN-BOX main sizes of items in the line
    :initarg :main-size
    :initform 0
    :accessor main-size)
   (cross-size ; Max MARGIN-BOX cross size of items in the line
    :initarg :cross-size
    :initform 0
    :accessor cross-size)))

;;; ----------------------------------------------------------------------------
;;; SIZE & POSITION HELPERS
;;; (These now operate on flex-item instances, which have margin slots)
;;; ----------------------------------------------------------------------------

(defun get-flex-item-border-box-main-size (item axis)
  "Return the main size of ITEM's border-box based on AXIS (:row or :column)."
  (let ((rect (rectangle item)))
    (case axis
      (:row (w rect))
      (:column (h rect))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun get-flex-item-border-box-cross-size (item axis)
  "Return the cross size of ITEM's border-box based on AXIS (:row or :column)."
  (let ((rect (rectangle item)))
    (case axis
      (:row (h rect))    ; Main axis row -> Cross axis H
      (:column (w rect)) ; Main axis column -> Cross axis W
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun get-flex-item-margin-box-main-size (item axis)
  "Return the main size of ITEM's margin-box (border-box + main-axis margins)."
  (let ((border-box-main-size (get-flex-item-border-box-main-size item axis))
        (margin-start (case axis
                        (:row (margin-left item))
                        (:column (margin-top item))))
        (margin-end (case axis
                      (:row (margin-right item))
                      (:column (margin-bottom item)))))
    (+ margin-start border-box-main-size margin-end)))

(defun get-flex-item-margin-box-cross-size (item axis)
  "Return the cross size of ITEM's margin-box (border-box + cross-axis margins)."
  (let ((border-box-cross-size (get-flex-item-border-box-cross-size item axis))
        (margin-start (case axis
                        (:row (margin-top item))    ; Cross-axis margin for row is top
                        (:column (margin-left item)))) ; Cross-axis margin for column is left
        (margin-end (case axis
                      (:row (margin-bottom item)) ; Cross-axis margin for row is bottom
                      (:column (margin-right item))))) ; Cross-axis margin for column is right
    (+ margin-start border-box-cross-size margin-end)))

(defmethod flex-direction ((container flex-container))
  "Return the flex-direction keyword based on the container's main-axis."
  (main-axis container)) ; Direct mapping

(defun set-flex-item-main-position (item pos axis)
  "Set the main-axis position for ITEM's BORDER-BOX to POS (rounded),
   accounting for its start margin."
  (let* ((int-pos (round pos))
         (rect (rectangle item))
         (item-margin-start (case axis
                              (:row (margin-left item))
                              (:column (margin-top item)))))
    (case axis
      (:row (setf (x rect) (+ int-pos item-margin-start)))
      (:column (setf (y rect) (+ int-pos item-margin-start)))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-cross-position (item pos axis)
  "Set the cross-axis position for ITEM's BORDER-BOX to POS (rounded),
   accounting for its start margin."
  (let* ((int-pos (round pos))
         (rect (rectangle item))
         (item-margin-start (case axis
                              (:row (margin-top item))    ; Cross-axis margin for row is top
                              (:column (margin-left item))))) ; Cross-axis margin for column is left
    (case axis
      (:row (setf (y rect) (+ int-pos item-margin-start)))
      (:column (setf (x rect) (+ int-pos item-margin-start)))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-main-size (item target-margin-box-size axis)
  "Set the main size of ITEM's BORDER-BOX (clamped) along AXIS.
   TARGET-MARGIN-BOX-SIZE is the total space allocated including margins."
  (let* ((rect (rectangle item))
         (margin-start (case axis
                         (:row (margin-left item))
                         (:column (margin-top item))))
         (margin-end (case axis
                       (:row (margin-right item))
                       (:column (margin-bottom item))))
         (target-border-box-size (max 0 (- (round target-margin-box-size) margin-start margin-end)))
         (clamped-border-box-size (case axis
                                    (:row (clamp target-border-box-size (min-width item) (max-width item)))
                                    (:column (clamp target-border-box-size (min-height item) (max-height item))))))
    (case axis
      (:row (setf (w rect) (floor clamped-border-box-size)))
      (:column (setf (h rect) (floor clamped-border-box-size)))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-cross-size (item target-margin-box-size axis)
  "Set the cross size of ITEM's BORDER-BOX (clamped) along AXIS.
   TARGET-MARGIN-BOX-SIZE is the total space allocated including margins."
  (let* ((rect (rectangle item))
         (margin-start (case axis
                         (:row (margin-top item))
                         (:column (margin-left item))))
         (margin-end (case axis
                       (:row (margin-bottom item))
                       (:column (margin-right item))))
         (target-border-box-size (max 0 (- (round target-margin-box-size) margin-start margin-end)))
         (clamped-border-box-size (case axis
                                    (:row (clamp target-border-box-size (min-height item) (max-height item)))
                                    (:column (clamp target-border-box-size (min-width item) (max-width item))))))
    (case axis
      (:row (setf (h rect) (floor clamped-border-box-size)))
      (:column (setf (w rect) (floor clamped-border-box-size)))
      (otherwise (error "Unsupported axis: ~a" axis)))))

;; Generic size accessors based on axis (useful internally for flex-line)
;; For flex-item, these refer to the BORDER-BOX dimensions stored in main-size/cross-size slots.
;; For flex-line, these refer to the SUM/MAX of MARGIN-BOX dimensions of items.
(defun get-main-size (entity main-axis)
  "Return the main-size slot value of ENTITY (flex-item's border-box or flex-line's margin-box sum)."
  (declare (ignore main-axis))
  (main-size entity))

(defun set-main-size (entity size main-axis)
  "Set ENTITY's main-size slot."
  (declare (ignore main-axis))
  (setf (main-size entity) (round size)))

(defun get-cross-size (entity main-axis)
  "Return the cross-size slot value of ENTITY (flex-item's border-box or flex-line's max margin-box)."
  (declare (ignore main-axis))
  (cross-size entity))

(defun set-cross-size (entity size main-axis)
  "Set ENTITY's cross-size slot."
  (declare (ignore main-axis))
  (setf (cross-size entity) (round size)))

(defun derive-available-main-size (container)
  "Return the container's available size along its main-axis from its rectangle (border-box)."
  (let ((axis (main-axis container))
        (rect (rectangle container)))
    (case axis
      ((:row :row-reverse) (w rect))
      ((:column :column-reverse) (h rect))
      (otherwise 0))))

(defun derive-available-cross-size (container)
  "Return the container's available size along its cross-axis from its rectangle (border-box)."
  (let ((axis (main-axis container))
        (rect (rectangle container)))
    (case axis
      ((:row :row-reverse) (h rect))
      ((:column :column-reverse) (w rect))
      (otherwise 0))))

(defun axis->direction (axis)
  "Map :x to :row and :y to :column, or return valid flex direction."
  (case axis
    (:x :row)
    (:y :column)
    ((:row :row-reverse :column :column-reverse) axis)
    (t (error "Unsupported axis: ~a" axis))))

;;; ----------------------------------------------------------------------------
;;; 1. RESOLVE FLEXIBLE LENGTHS (Determine Item Main Sizes)
;;; ----------------------------------------------------------------------------
(defun resolve-flexible-lengths (items available-main-size main-axis)
  "Determine the main size of each item's border-box based on flex-basis, flex-grow, and flex-shrink.
   The 'main-size' slot on flex-item stores the resolved border-box main size."
  ;; 1. Initialize item's main-size (border-box) to its flex-basis or its intrinsic border-box main size.
  (dolist (item items)
    (setf (main-size item) ; This is border-box main size
          (or (flex-basis item) ; flex-basis refers to border-box
              (get-flex-item-border-box-main-size item main-axis))))

  ;; Calculate total main-axis margins for all items
  (let* ((total-main-axis-margins (reduce #'+ items
                                          :key (lambda (it)
                                                 (case main-axis
                                                   (:row (+ (margin-left it) (margin-right it)))
                                                   (:column (+ (margin-top it) (margin-bottom it)))))
                                          :initial-value 0))
         ;; available-main-size is the content area of the container.
         ;; available-main-size-for-border-boxes is this area minus all margins.
         (available-space-for-border-boxes (max 0.0 (- available-main-size total-main-axis-margins)))
         (initial-used-border-box-space (reduce #'+ items :key #'main-size :initial-value 0))
         (remaining-space-for-border-boxes (- available-space-for-border-boxes initial-used-border-box-space)))

    (if (>= remaining-space-for-border-boxes 0)
        ;; 2a. Distribute positive remaining space (Flex Grow)
        (let ((total-flex-grow (reduce #'+ items :key #'flex-grow :initial-value 0)))
          (when (> total-flex-grow 0)
            (dolist (item items)
              (when (> (flex-grow item) 0)
                (let* ((grow-ratio (/ (flex-grow item) total-flex-grow))
                       (grow-amount (* remaining-space-for-border-boxes grow-ratio)))
                  (incf (main-size item) grow-amount)))))) ; Grow the border-box size
        ;; 2b. Distribute negative remaining space (Flex Shrink)
        (let ((total-weighted-shrink (reduce #'+ items
                                             :key (lambda (it) (* (flex-shrink it) (main-size it))) ; Shrink based on current border-box size
                                             :initial-value 0)))
          (when (> total-weighted-shrink 0)
            (dolist (item items)
              (when (> (flex-shrink item) 0)
                (let* ((weighted-shrink (* (flex-shrink item) (main-size item)))
                       (shrink-ratio (/ weighted-shrink total-weighted-shrink))
                       (shrink-amount (* (- remaining-space-for-border-boxes) shrink-ratio))) ; remaining-space is negative
                  (decf (main-size item) shrink-amount))))))) ; Shrink the border-box size

    ;; 3. Apply resolved border-box main size to the item's rectangle (w/h),
    ;;    and set its border-box cross-size slot.
    (dolist (item items)
      (let* ((target-border-box-main (main-size item)) ; This is the resolved border-box size
             (clamped-border-box-main
               (case main-axis
                 (:row (clamp target-border-box-main (min-width item) (max-width item)))
                 (:column (clamp target-border-box-main (min-height item) (max-height item))))))
        (setf (main-size item) (floor clamped-border-box-main)) ; Ensure main-size slot is also integer
        (case main-axis ; Update rectangle dimension
          (:row (setf (w (rectangle item)) (floor clamped-border-box-main)))
          (:column (setf (h (rectangle item)) (floor clamped-border-box-main))))

        ;; Initialize item's cross-size slot (border-box) based on its rectangle's current cross dimension
        ;; get-flex-item-border-box-cross-size reads w/h which are now integers.
        (setf (cross-size item) (floor (get-flex-item-border-box-cross-size item main-axis)))))
    items))

;;; ----------------------------------------------------------------------------
;;; 2. COLLECTING FLEX LINES (Wrap / No-Wrap)
;;; ----------------------------------------------------------------------------
(defun collect-flex-lines (container available-main-size main-axis)
  "Collect flex lines for CONTAINER along main-axis, respecting flex-wrap.
   Assumes item main sizes (border-box) have been resolved.
   Line main-size and cross-size will be based on MARGIN-BOXES of items."
  (let* ((wrap-type (flex-wrap container))
         (sorted-items (sort (copy-list (flex-item-children container)) #'< :key #'order)))
    (if (eq wrap-type :nowrap)
        ;; Single line containing all items
        (list (make-instance 'flex-line
                             :items sorted-items
                             :main-size (reduce #'+ sorted-items :key (lambda (it) (get-flex-item-margin-box-main-size it main-axis)) :initial-value 0)
                             :cross-size (if sorted-items
                                             (reduce #'max sorted-items :key (lambda (it) (get-flex-item-margin-box-cross-size it main-axis)))
                                             0)))
        ;; Handle wrapping (:wrap or :wrap-reverse - reverse handled later)
        (loop with lines = '()
              with current-line-items = '()
              with current-line-main-size = 0
              for item in sorted-items
              do
                 (let ((item-margin-box-main (get-flex-item-margin-box-main-size item main-axis)))
                   (if (and current-line-items (> (+ current-line-main-size item-margin-box-main) available-main-size))
                       ;; Start a new line
                       (progn
                         (push (make-instance 'flex-line
                                              :items (reverse current-line-items)
                                              :main-size current-line-main-size
                                              :cross-size (if current-line-items
                                                              (reduce #'max current-line-items :key (lambda (it) (get-flex-item-margin-box-cross-size it main-axis)))
                                                              0))
                               lines)
                         (setf current-line-items (list item))
                         (setf current-line-main-size item-margin-box-main))
                       ;; Add to current line
                       (progn
                         (push item current-line-items)
                         (incf current-line-main-size item-margin-box-main))))
              finally
                 (when current-line-items
                   (push (make-instance 'flex-line
                                        :items (reverse current-line-items)
                                        :main-size current-line-main-size
                                        :cross-size (if current-line-items
                                                        (reduce #'max current-line-items :key (lambda (it) (get-flex-item-margin-box-cross-size it main-axis)))
                                                        0))
                         lines))
                 (return (reverse lines)))))) ; Return lines in logical order

;;; ----------------------------------------------------------------------------
;;; 3. MAIN AXIS ALIGNMENT (Justify Content)
;;; ----------------------------------------------------------------------------
(defun justify-content-alignment (line container available-main-size main-axis)
  "Calculate and set main-axis positions for items within a single line based on justify-content.
   Positions the MARGIN-BOX of each item."
  (let* ((items (items line))
         (num-items (length items))
         (jc (justify-content container))
         (line-main-size (main-size line)) ; This is sum of margin-box main sizes
         (remaining-space (- available-main-size line-main-size))
         (current-pos 0.0))

    (when (<= num-items 0) (return-from justify-content-alignment)) ; Empty line

    (when (member (main-axis container) '(:row-reverse :column-reverse))
      (setf items (reverse items)))

    (case jc
      (:flex-start
       (setf current-pos 0.0))
      (:flex-end
       (setf current-pos remaining-space))
      (:center
       (setf current-pos (/ remaining-space 2.0)))
      (:space-between
       (let ((gap (if (> num-items 1) (/ remaining-space (1- num-items)) 0.0)))
         (setf current-pos 0.0)
         (loop for item in items
               for i from 0
               do
                  (set-flex-item-main-position item current-pos main-axis) ; Positions border-box considering start margin
                  (incf current-pos (get-flex-item-margin-box-main-size item main-axis)) ; Advance by full margin-box
                  (unless (= i (1- num-items))
                    (incf current-pos gap)))
         (return-from justify-content-alignment)))
      (:space-around
       (let ((gap (if (> num-items 0) (/ remaining-space num-items) 0.0)))
         (setf current-pos (/ gap 2.0))
         (loop for item in items
               do
                  (set-flex-item-main-position item current-pos main-axis)
                  (incf current-pos (+ (get-flex-item-margin-box-main-size item main-axis) gap)))
         (return-from justify-content-alignment)))
      (:space-evenly
       (let ((gap (if (> num-items 0) (/ remaining-space (1+ num-items)) 0.0)))
         (setf current-pos gap)
         (loop for item in items
               do
                  (set-flex-item-main-position item current-pos main-axis)
                  (incf current-pos (+ (get-flex-item-margin-box-main-size item main-axis) gap)))
         (return-from justify-content-alignment)))
      (otherwise ; Default to flex-start
       (setf current-pos 0.0)))

    ;; Common loop for :flex-start, :flex-end, :center
    (loop for item in items
          do
             (set-flex-item-main-position item current-pos main-axis)
             (incf current-pos (get-flex-item-margin-box-main-size item main-axis)))))

;;; ----------------------------------------------------------------------------
;;; 4. CROSS AXIS ALIGNMENT (Align Items / Align Self / Align Content)
;;; ----------------------------------------------------------------------------

(defun determine-line-cross-sizes (lines container available-cross-size main-axis)
  "Determine the cross size of each flex line (margin-box) based on align-content."
  (declare (ignore main-axis))
  (let* ((num-lines (length lines))
         (ac (align-content container))
         (total-lines-margin-box-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)) ; cross-size of line is max margin-box
         (remaining-cross-space (- available-cross-size total-lines-margin-box-cross-size)))

    (when (<= num-lines 0) (return-from determine-line-cross-sizes))

    (case ac
      (:stretch
       (when (> remaining-cross-space 0)
         (let ((stretch-amount (/ remaining-cross-space num-lines)))
           (dolist (line lines)
             (incf (cross-size line) stretch-amount))))) ; Stretch the line's margin-box height
      (:flex-start)
      (:flex-end)
      (:center)
      (:space-between)
      (:space-around)
      (otherwise (warn "Unsupported align-content value: ~A. Treating as :flex-start." ac)))

    (dolist (line lines)
      (setf (cross-size line) (max 0.0 (cross-size line))))))

(defun align-items-in-line (line line-cross-pos line-margin-box-cross-size container main-axis)
  "Align items within a single flex line on the cross axis.
   LINE-CROSS-POS is the start of the line's margin-box.
   LINE-MARGIN-BOX-CROSS-SIZE is the total height/width allocated to the line's margin-box."
  (let ((items (items line))
        (container-align-items (align-items container)))
    (dolist (item items)
      (let* ((item-margin-box-cross (get-flex-item-margin-box-cross-size item main-axis))
             (item-align-self (or (align-self item) container-align-items))
             (effective-align (case item-align-self
                                (:auto :stretch)
                                (:baseline :flex-start) ; Simplification
                                (t item-align-self)))
             (available-space-in-line (- line-margin-box-cross-size item-margin-box-cross))
             (item-final-cross-pos line-cross-pos))

        (case effective-align
          (:stretch
           ;; Set item's MARGIN-BOX cross size to the line's MARGIN-BOX cross size
           (set-flex-item-cross-size item line-margin-box-cross-size main-axis)
           (setf item-final-cross-pos line-cross-pos))
          (:flex-start
           (setf item-final-cross-pos line-cross-pos))
          (:flex-end
           (setf item-final-cross-pos (+ line-cross-pos available-space-in-line)))
          (:center
           (setf item-final-cross-pos (+ line-cross-pos (/ available-space-in-line 2.0))))
          (otherwise (warn "Unsupported align-items/align-self: ~A" effective-align)))

        (set-flex-item-cross-position item item-final-cross-pos main-axis)))))

(defun align-cross-axis (lines container available-cross-size main-axis)
  "Position flex lines and align items within them along the cross axis."
  (determine-line-cross-sizes lines container available-cross-size main-axis)

  (let* ((num-lines (length lines))
         (ac (align-content container))
         (total-lines-margin-box-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0))
         (remaining-cross-space (max 0.0 (- available-cross-size total-lines-margin-box-cross-size)))
         (current-cross-pos 0.0))

    (when (<= num-lines 0) (return-from align-cross-axis))

    (when (eq (flex-wrap container) :wrap-reverse)
      (setf lines (reverse lines)))

    (case ac
      (:flex-start (setf current-cross-pos 0.0))
      (:flex-end   (setf current-cross-pos remaining-cross-space))
      (:center     (setf current-cross-pos (/ remaining-cross-space 2.0)))
      (:space-between
       (let ((gap (if (> num-lines 1) (/ remaining-cross-space (1- num-lines)) 0.0)))
         (setf current-cross-pos 0.0)
         (loop for line in lines
               for i from 0
               do
                  (align-items-in-line line current-cross-pos (cross-size line) container main-axis)
                  (incf current-cross-pos (cross-size line))
                  (unless (= i (1- num-lines))
                    (incf current-cross-pos gap)))
         (return-from align-cross-axis)))
      (:space-around
       (let ((gap (if (> num-lines 0) (/ remaining-cross-space num-lines) 0.0)))
         (setf current-cross-pos (/ gap 2.0))
         (loop for line in lines
               do
                  (align-items-in-line line current-cross-pos (cross-size line) container main-axis)
                  (incf current-cross-pos (+ (cross-size line) gap)))
         (return-from align-cross-axis)))
      (:stretch
       (setf current-cross-pos 0.0))
      (otherwise
       (setf current-cross-pos 0.0)))

    (loop for line in lines
          do
             (align-items-in-line line current-cross-pos (cross-size line) container main-axis)
             (incf current-cross-pos (cross-size line)))))

;;; ----------------------------------------------------------------------------
;;; 5. RECURSIVE LAYOUT FOR NESTED CONTAINERS
;;; ----------------------------------------------------------------------------
(defun layout-nested-containers (container)
  "Recursively call layout-flex-container on any child items that are themselves flex containers."
  (dolist (item (flex-item-children container))
    (when (typep item 'flex-container)
      (layout-flex-container item))))

;;; ----------------------------------------------------------------------------
;;; HIGH-LEVEL LAYOUT FUNCTION
;;; ----------------------------------------------------------------------------
;; (defun layout-flex-container (maybe-node-container &optional self-content-rect parent-style-set)
;;   "Layout the flex CONTAINER and its children. Returns the container."

;;   (let* ((container (if (typep maybe-node-container 'styled-ui-node)
;;                         (node->flex-item maybe-node-container)
;;                         maybe-node-container))
;;          (main-axis (main-axis container))
;;          (available-main-size (derive-available-main-size container))
;;          (available-cross-size (derive-available-cross-size container))
;;          (items (flex-item-children container)))

;;     (unless (and (rectangle container) (valid-p (rectangle container)))
;;       (error "Flex container requires a valid rectangle for layout: ~A" container))

;;     (resolve-flexible-lengths items available-main-size main-axis)

;;     (let ((lines (collect-flex-lines container available-main-size main-axis)))
;;       (dolist (line lines)
;;         (justify-content-alignment line container available-main-size main-axis))
;;       (align-cross-axis lines container available-cross-size main-axis)
;;       (layout-nested-containers container)
;;       (when (and (member (flex-wrap container) '(:wrap :wrap-reverse)) lines)
;;         (let ((total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)))
;;           (declare (ignore total-lines-cross-size))
;;           ))
;;       (let ((offset-x (x container))
;;             (offset-y (y container)))
;;         (dolist (item items)
;;           (dx! (rectangle item) offset-x)
;;           (dy! (rectangle item) offset-y)))
;;       container)))
;;; Patch #1 – shift children BEFORE recursing  ────────────────────────────────
;; ➊ the algorithm that resolves lengths, lines, justify‑content, align‑items
(defun layout-flex-container (maybe-node-container
                              &optional self-content-rect parent-style-set)
  "Lay out a flex container and all its descendants and return the container
   (with every item's rectangle in ABSOLUTE coordinates)."

  ;; ────────────────── wrap the old body in a LET* so we can re‑order things
  (let* ((container (if (typep maybe-node-container 'styled-ui-node)
                        (node->flex-item maybe-node-container self-content-rect)
                        maybe-node-container))
         (main-axis           (main-axis container))
         (available-main-size  (derive-available-main-size  container))
         (available-cross-size (derive-available-cross-size container))
         (items               (flex-item-children container)))

    (unless (and (rectangle container) (valid-p (rectangle container)))
      (error "Flex container requires a valid rectangle for layout: ~A" container))

    (resolve-flexible-lengths items available-main-size main-axis)
    (let ((lines (collect-flex-lines container available-main-size main-axis)))
      (dolist (line lines)
        (justify-content-alignment line container available-main-size main-axis))
      (align-cross-axis lines container available-cross-size main-axis)

      ;; ➋ recurse into nested flex containers **before** we add any offset
      (layout-nested-containers container)

      ;; ➌ now shift the *entire* subtree exactly once
      (propagate-offset! container (x container) (y container))
      ;; 1. Resolve flexible lengths & collect lines (unchanged)
      ;; (resolve-flexible-lengths items available-main-size main-axis)
      ;; (let ((lines (collect-flex-lines container available-main-size main-axis)))
      ;;   (dolist (line lines)
      ;;     (justify-content-alignment line container available-main-size main-axis))
      ;;   (align-cross-axis lines container available-cross-size main-axis)

      ;;   ;; 2. *** NEW ORDER: apply the container’s offset to EVERY direct child
      ;;   ;;    BEFORE we recurse so grandchildren inherit it naturally. ***
      ;;   (let ((dx (x container))
      ;;         (dy (y container)))
      ;;     (dolist (item items)
      ;;       (dx! (rectangle item) dx)
      ;;       (dy! (rectangle item) dy)))

      ;;   ;; 3. Now descend into nested flex containers (they now start at abs coords)
      ;;   (layout-nested-containers container)

      ;;   ;; 4. (Optional bookkeeping for wrap height – unchanged)
      ;;   (when (and (member (flex-wrap container) '(:wrap :wrap-reverse)) lines)
      ;;     (let ((total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)))
      ;;       (declare (ignore total-lines-cross-size))))

      container)))

;;; Patch #1b – keep the old public name alive for callers
(defun compute-flex-layout (container &rest args)
  "Compatibility shim – just forwards to LAYOUT-FLEX-CONTAINER."
  (apply #'layout-flex-container container args))
(defun node->flex-item (node &optional (rect nil))
  "Convert a styled-ui-node to a flex-item or flex-container instance."
  (let* ((is-flex-container (eq (style-value node :display) :flex))
         (final-rect (or rect
                         (getf (ui-node-props node) :layout-rect)
                         (make-rectangle
                          :pos (make-pos :x 0 :y 0) :size (make-size :w 0 :h 0))))
         (common-args (list :rectangle final-rect
                            :flex-basis (style-value node :flex-basis nil)
                            :min-width (style-value node :min-width 0)
                            :max-width (style-value node :max-width most-positive-fixnum)
                            :min-height (style-value node :min-height 0)
                            :max-height (style-value node :max-height most-positive-fixnum)
                            :order (style-value node :order 0)
                            :flex-grow (style-value node :flex-grow 0)
                            :flex-shrink (style-value node :flex-shrink 1)
                            :align-self (style-value node :align-self nil)))
         (container-args (when is-flex-container
                           (list :main-axis (style-value node :flex-direction :row)
                                 :flex-wrap (style-value node :flex-wrap :nowrap)
                                 :justify-content (style-value node :justify-content :flex-start)
                                 :align-items (style-value node :align-items :stretch)
                                 :align-content (style-value node :align-content :stretch)
                                 :children
                                 (mapcar #'node->flex-item
                                         (ui-node-children node))))))
    (apply #'make-instance (if is-flex-container 'flex-container 'flex-item)
           (append common-args container-args))))

;; (defun compute-flex-layout (container-node &optional self-content-rect parent-style-set)
;;   "Layout the flex CONTAINER-NODE and its children. Returns the container.

;;    SELF-CONTENT-RECT is the rectangle for self-content, if provided.
;;    PARENT-STYLE-SET is ignored in this context.
;;    This function assumes the container-node is a flex container with children that may also be flex containers.

;;    It computes the layout based on flexbox rules, including resolving flexible lengths,
;;    collecting flex lines, justifying content, and aligning items in the cross axis.

;;    The function modifies the rectangles of flex items in place, setting their positions and sizes.
;;    For nested flex containers, it recursively calls compute-flex-layout on each child flex container.
;; "
;;   (declare (ignore parent-style-set))
;;   (let* ((container (node->flex-item container-node self-content-rect))
;;          (main-axis (main-axis container))
;;          (available-main-size (derive-available-main-size container))
;;          (available-cross-size (derive-available-cross-size container))
;;          (items (flex-item-children container)))

;;     (unless (and (rectangle container) (valid-p (rectangle container)))
;;       (error "Flex container requires a valid rectangle for layout: ~A" container))

;;     (resolve-flexible-lengths items available-main-size main-axis)

;;     (let ((lines (collect-flex-lines container available-main-size main-axis)))
;;       (dolist (line lines)
;;         (justify-content-alignment line container available-main-size main-axis))
;;       (align-cross-axis lines container available-cross-size main-axis)
;;       (dolist (item items)
;;         (when (typep item 'flex-container)
;;           (compute-flex-layout item nil nil)))
;;       (when (and (member (flex-wrap container) '(:wrap :wrap-reverse)) lines)
;;         (let ((total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)))
;;           (declare (ignore total-lines-cross-size))
;;           ))
;;       (let ((offset-x (x container))
;;             (offset-y (y container)))
;;         (dolist (item items)
;;           (let* ((rect (rectangle item))
;;                  (s (format nil "~A->" rect)))
;;             (setf (x rect) (+ (x rect) offset-x))
;;             (setf (y rect) (+ (y rect) offset-y))
;;             (log-info "Item ~A positioned: ~A~A" item s (rectangle item)))))
;;       container)))
