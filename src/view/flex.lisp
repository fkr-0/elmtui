;;; ===============================================================
;;; File: src/view/flex.lisp
;;; Flexbox Layout Engine (Ported/Refactored from uncharming-tui.flex)
;;; ===============================================================
(uiop:define-package :elmtui.view.layout.flex
  (:use :cl)
  (:nicknames :et.flex)
  ;; Import from the refactored geo package
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y #:make-rectangle #:make-pos #:make-size
                #:pos-x #:pos-y #:size-w #:size-h #:rectangle-pos #:rectangle-size
                #:dx! #:dy! #:valid-p)
  ;; Import styling support
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value
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

;;; ----------------------------------------------------------------------------
;;; HELPERS & UTILITIES
;;; ----------------------------------------------------------------------------
(defun clamp (value min max)
  "Clamp VALUE between MIN and MAX."
  (max min (min value max)))

;;; Generic definitions for properties with defaults.
(defgeneric child-container (object)
  (:documentation "Return the child flex-container of OBJECT, if any."))
(defmethod child-container ((object t)) nil)

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

(defmethod main-axis ((container flex-container))
  (if (typep container 'styled-ui-node) ; Should not happen, flex-container is not a styled-ui-node
      (extract-style-value container :flex-direction (%main-axis container))
      (%main-axis container)))

(defmethod flex-wrap ((container flex-container))
  (if (typep container 'styled-ui-node)
      (extract-style-value container :flex-wrap (%flex-wrap container))
      (%flex-wrap container)))

(defmethod justify-content ((container flex-container))
  (if (typep container 'styled-ui-node)
      (extract-style-value container :justify-content (%justify-content container))
      (%justify-content container)))

(defmethod align-items ((container flex-container))
  (if (typep container 'styled-ui-node)
      (extract-style-value container :align-items (%align-items container))
      (%align-items container)))

(defmethod align-content ((container flex-container))
  (if (typep container 'styled-ui-node)
      (extract-style-value container :align-content (%align-content container))
      (%align-content container)))

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
(defun layout-flex-container (container)
  "Layout the flex CONTAINER and its children. Returns the container."
  (let* ((main-axis (main-axis container))
         (available-main-size (derive-available-main-size container))
         (available-cross-size (derive-available-cross-size container))
         (items (flex-item-children container)))

    (unless (and (rectangle container) (valid-p (rectangle container)))
      (error "Flex container requires a valid rectangle for layout: ~A" container))

    (resolve-flexible-lengths items available-main-size main-axis)

    (let ((lines (collect-flex-lines container available-main-size main-axis)))
      (dolist (line lines)
        (justify-content-alignment line container available-main-size main-axis))
      (align-cross-axis lines container available-cross-size main-axis)
      (layout-nested-containers container)
      (when (and (member (flex-wrap container) '(:wrap :wrap-reverse)) lines)
        (let ((total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)))
          (declare (ignore total-lines-cross-size))
          ))
      (let ((offset-x (x container))
            (offset-y (y container)))
        (dolist (item items)
          (dx! (rectangle item) offset-x)
          (dy! (rectangle item) offset-y)))
      container)))

(uiop:define-package :elmtui.view.layout.flex-layout
  (:use :cl)
  (:nicknames :et.flex-layout)
  ;; Import from the refactored geo package
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
  (:import-from :elmtui.view.layout.flex
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

(in-package :elmtui.view.layout.flex-layout)
(defun compute-flex-layout (flex-container-node parent-absolute-content-rect parent-style-set)
  "Computes the layout for a flex container and its children using a simplified Flexbox model.
   Handles a single flex line (no wrapping).
   Supports flex-direction, justify-content, align-items, align-self,
   flex-grow, flex-shrink, flex-basis, and min/max sizes.

   LIMITATIONS & TODOs:
   - Flex Wrapping (`flex-wrap`): Currently only processes items as a single flex line.
     TODO: Implement line breaking logic. This involves:
       - Iteratively adding items to a line until available main space is exceeded.
       - If `flex-wrap` is `wrap` or `wrap-reverse`, start a new line.
       - Each line will then independently undergo main axis distribution and cross axis alignment.
       - The container's cross size might need to adjust based on the sum of line cross sizes.
   - `align-content`: This property (for distributing space between/around lines) is not used.
     TODO: Implement `align-content` after multi-line support is added.
   - `order` Property: Items are laid out in their source order.
     TODO: Implement sorting of flex items based on the `order` style property before layout.
   - `flex-basis` Keywords: Only numeric values and `:auto` are meaningfully handled.
     TODO: Implement support for `flex-basis: :content`, which requires pre-calculating
           the content-based size of an item. This might involve a preliminary layout pass
           for such items or a callback to the item to report its content size.
     TODO: Consider support for percentage-based `flex-basis` (relative to flex container main size).
   - Baseline Alignment (`align-items: :baseline`, `align-self: :baseline`):
     TODO: Implement baseline alignment. This requires items to report their baseline position.
           For text-based elements, this is the baseline of the first line of text.
           This can be complex in a TUI context if not all elements have clear text baselines.
   - Intrinsic Aspect Ratios: Not considered.
   - Margin/Padding/Border on Flex Items: The current algorithm calculates positions and sizes
     that are assumed to be for the border-box of the flex items. The `layout-view` function
     (which calls this) is responsible for calculating the container's content-box (passed as
     `parent-absolute-content-rect`) and for interpreting the item's own margin, border, and padding
     to adjust the final `layout-rect` or the space used by the item.
     This function focuses on distributing the container's content space among items.
     CONFIRMATION: This is more of a note on responsibility. The main `layout-view` should handle this.
   - Floating Point Precision: Calculations use floating point numbers. Final rects are rounded.
     NOTE: This is generally acceptable but be aware of potential minor rounding differences.
   - Performance for Very Large Number of Items: The current implementation involves multiple loops.
     NOTE: For typical TUI use cases, this should be acceptable. If performance issues arise with
           extremely large flex containers, profiling and optimization might be needed.
  "

  (declare (ignore parent-style-set)) ; Placeholder

  (log:debug "FLEX-LAYOUT: Computing layout for ~S in available rect ~S"
             (getf (ui-node-props flex-container-node) :id "N/A")
             parent-absolute-content-rect)

  ;; 1. Extract Flex Container Properties & Determine Axes
  (let* ((container-styles (styles flex-container-node))
         (flex-direction (style-value container-styles :flex-direction :row))
         (justify-content (style-value container-styles :justify-content :flex-start))
         (align-items (style-value container-styles :align-items :stretch))
         ;; Container's explicit size from styles
         (styled-container-width (style-value container-styles :width))
         (styled-container-height (style-value container-styles :height))

         ;; Available space for the flex container's content box
         (container-content-x (x parent-absolute-content-rect))
         (container-content-y (y parent-absolute-content-rect))
         (available-width (if (numberp styled-container-width) styled-container-width (w parent-absolute-content-rect)))
         (available-height (if (numberp styled-container-height) styled-container-height (h parent-absolute-content-rect)))

         (is-row (member flex-direction '(:row :row-reverse)))
         (is-column (member flex-direction '(:column :column-reverse)))
         (is-main-axis-reverse (member flex-direction '(:row-reverse :column-reverse)))

         (main-axis-size (if is-row available-width available-height))
         (cross-axis-size (if is-row available-height available-width))

         (children (ui-node-children flex-container-node))
         (flex-items-data '()))

    (log:trace "FLEX-LAYOUT: Dir: ~A, Container Avail W: ~A, H: ~A, MainSize: ~A, CrossSize: ~A"
               flex-direction available-width available-height main-axis-size cross-axis-size)

    ;; 2. Collect Flex Items and their Initial (Hypothetical) Main Sizes
    (loop for child in children do
      (when (typep child 'styled-ui-node)
        (let* ((child-styles (styles child))
               (child-props (ui-node-props child))
               (flex-basis (style-value child-styles :flex-basis :auto))
               (flex-grow (style-value child-styles :flex-grow 0))
               (flex-shrink (style-value child-styles :flex-shrink 1))
               (align-self (style-value child-styles :align-self :auto))

               (styled-main-dim (if is-row (style-value child-styles :width) (style-value child-styles :height)))
               (styled-cross-dim (if is-row (style-value child-styles :height) (style-value child-styles :width)))

               (min-main-dim (if is-row (style-value child-styles :min-width 0) (style-value child-styles :min-height 0)))
               (max-main-dim (if is-row (style-value child-styles :max-width most-positive-fixnum) (style-value child-styles :max-height most-positive-fixnum)))
               (min-cross-dim (if is-row (style-value child-styles :min-height 0) (style-value child-styles :min-width 0)))
               (max-cross-dim (if is-row (style-value child-styles :max-height most-positive-fixnum) (style-value child-styles :max-width most-positive-fixnum)))

               (hypothetical-main-size 0))

          ;; Determine hypothetical main size based on flex-basis, then styled main dimension
          (cond
            ((numberp flex-basis) (setf hypothetical-main-size flex-basis))
            ((eq flex-basis :auto)
             (if (numberp styled-main-dim)
                 (setf hypothetical-main-size styled-main-dim)
                 (setf hypothetical-main-size (if is-row 5 3)))) ; Default if auto and no styled dim
            ;; TODO: Handle :content, other flex-basis keywords
            (t (setf hypothetical-main-size (if is-row 5 3)))) ; Default for unhandled basis

          ;; Clamp by min/max
          (setf hypothetical-main-size (max min-main-dim (min hypothetical-main-size max-main-dim)))

          (push (list :node child :props child-props :styles child-styles
                      :hypothetical-main-size hypothetical-main-size
                      :final-main-size hypothetical-main-size ; Initialize final with hypothetical
                      :flex-grow flex-grow :flex-shrink flex-shrink
                      :align-self align-self
                      :styled-cross-dim styled-cross-dim
                      :min-main min-main-dim :max-main max-main-dim
                      :min-cross min-cross-dim :max-cross max-cross-dim)
                flex-items-data))))
    (setf flex-items-data (nreverse flex-items-data)) ; Preserve original child order

    ;; 3. Resolve Flexible Lengths (Main Axis)
    (let* ((total-hypothetical-main-size (loop for item in flex-items-data sum (getf item :hypothetical-main-size)))
           (remaining-space (- main-axis-size total-hypothetical-main-size))
           (total-flex-grow (loop for item in flex-items-data when (> (getf item :flex-grow 0) 0) sum (getf item :flex-grow)))
           (total-flex-shrink-weighted (loop for item in flex-items-data when (> (getf item :flex-shrink 0) 0) sum (* (getf item :flex-shrink) (getf item :hypothetical-main-size)))))

      (cond
        ;; Distribute positive remaining space (Growing)
        ((and (> remaining-space 0) (> total-flex-grow 0))
         (loop for item in flex-items-data
               when (> (getf item :flex-grow 0) 0) do
                 (let* ((grow-share (/ (getf item :flex-grow) total-flex-grow))
                        (space-to-add (* remaining-space grow-share))
                        (new-size (+ (getf item :final-main-size) space-to-add)))
                   (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main)))))))
        ;; Distribute negative remaining space (Shrinking)
        ((and (< remaining-space 0) (> total-flex-shrink-weighted 0))
         (let ((space-to-remove (abs remaining-space)))
           (loop for item in flex-items-data
                 when (> (getf item :flex-shrink 0) 0) do
                   (let* ((shrink-share (/ (* (getf item :flex-shrink) (getf item :hypothetical-main-size)) total-flex-shrink-weighted))
                          (reduction (* space-to-remove shrink-share))
                          (new-size (- (getf item :final-main-size) reduction)))
                     (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main)))))))))
      ;; Re-calculate total final main size after grow/shrink for justify-content
      (let ((total-final-main-size (loop for item in flex-items-data sum (getf item :final-main-size))))
        (setf remaining-space (- main-axis-size total-final-main-size))))


    ;; 4. Main Axis Alignment (justify-content)
    (let* ((num-items (length flex-items-data))
           (total-final-main-size (loop for item in flex-items-data sum (getf item :final-main-size)))
           (current-remaining-space (- main-axis-size total-final-main-size))
           (main-offset 0.0))

      (cond
        ((eq justify-content :flex-end) (setf main-offset current-remaining-space))
        ((eq justify-content :center) (setf main-offset (/ current-remaining-space 2)))
        ((eq justify-content :space-between)
         (when (> num-items 1) (setf main-offset 0))) ; First item at start
        ((eq justify-content :space-around)
         (if (> num-items 0) (setf main-offset (/ current-remaining-space (* 2 num-items)))))
        ((eq justify-content :space-evenly)
         (if (> num-items 0) (setf main-offset (/ current-remaining-space (+ 1 num-items)))))
        (t (setf main-offset 0))) ; :flex-start or default

      (when is-main-axis-reverse (setf flex-items-data (reverse flex-items-data)))

      (loop for item in flex-items-data do
        (setf (getf item :main-pos) main-offset)
        (incf main-offset (getf item :final-main-size))
        (cond
          ((and (eq justify-content :space-between) (> num-items 1))
           (when (< (position item flex-items-data :test #'eq) (1- num-items)) ; Not the last item
             (incf main-offset (/ current-remaining-space (1- num-items)))))
          ((eq justify-content :space-around)
           (incf main-offset (/ current-remaining-space num-items))) ; Space after item
          ((eq justify-content :space-evenly)
           (incf main-offset (/ current-remaining-space (+ 1 num-items))))))) ; Space after item

    ;; 5. Cross Axis Sizing and Alignment
    (loop for item in flex-items-data do
      (let* ((item-styles (getf item :styles))
             (item-align-self (getf item :align-self))
             (effective-align (if (eq item-align-self :auto) align-items item-align-self))
             (styled-cross-dim (getf item :styled-cross-dim))
             (final-cross-size 0)
             (cross-pos 0))

        ;; Determine final cross size
        (cond
          ((and (eq effective-align :stretch) (eq styled-cross-dim :auto)) ; Stretch if auto
           (setf final-cross-size cross-axis-size))
          ((numberp styled-cross-dim)
           (setf final-cross-size styled-cross-dim))
          (t (setf final-cross-size (if is-row 3 5)))) ; Default cross size

        (setf final-cross-size (max (getf item :min-cross) (min final-cross-size (getf item :max-cross))))
        (setf (getf item :final-cross-size) final-cross-size)

        ;; Determine cross position
        (cond
          ((eq effective-align :flex-end) (setf cross-pos (- cross-axis-size final-cross-size)))
          ((eq effective-align :center) (setf cross-pos (/ (- cross-axis-size final-cross-size) 2)))
          ;; :flex-start, :stretch (position at start for stretch)
          (t (setf cross-pos 0)))
        (setf (getf item :cross-pos) cross-pos)))

    ;; 6. Set Layout Rects for Children
    (let ((actual-content-main-end 0)
          (actual-content-cross-end 0))
      (loop for item in flex-items-data do
        (let* ((child-node (getf item :node))
               (main-pos (getf item :main-pos))
               (cross-pos (getf item :cross-pos))
               (final-main (getf item :final-main-size))
               (final-cross (getf item :final-cross-size))
               (child-x 0) (child-y 0) (child-w 0) (child-h 0))

          (if is-row
              (setf child-x (+ container-content-x
                               (if is-main-axis-reverse
                                   main-pos
                                   (- main-axis-size main-pos final-main)))
                    child-y (+ container-content-y cross-pos)
                    child-w final-main
                    child-h final-cross)
              (setf child-x (+ container-content-x cross-pos)
                    child-y (+ container-content-y
                               (if is-main-axis-reverse (- main-axis-size main-pos final-main) main-pos))
                    child-w final-cross
                    child-h final-main))

          (let ((child-rect (make-rectangle :pos (make-pos
                                                  :x (round child-x)
                                                  :y (round child-y))
                                            :size (make-size
                                                   :w (round child-w)
                                                   :h (round child-h)))))
            (setf (getf (ui-node-props child-node) :layout-rect) child-rect)
            (log:debug "FLEX-LAYOUT: Child ~S (main:~A crs:~A) at rect ~S"
                       (getf (ui-node-props child-node) :id "N/A") final-main final-cross child-rect)
            (setf actual-content-main-end (max actual-content-main-end (+ main-pos final-main)))
            (setf actual-content-cross-end (max actual-content-cross-end (+ cross-pos final-cross))))))

      ;; 7. Determine Final Container Rectangle
      (let ((final-container-w available-width)
            (final-container-h available-height))
        (if is-row
            (progn
              (when (eq styled-container-width :auto) (setf final-container-w actual-content-main-end))
              (when (eq styled-container-height :auto) (setf final-container-h actual-content-cross-end)))
            (progn
              (when (eq styled-container-width :auto) (setf final-container-w actual-content-cross-end))
              (when (eq styled-container-height :auto) (setf final-container-h actual-content-main-end))))

        ;; Ensure container respects its own min/max if styled-size was auto
        (when (eq styled-container-width :auto)
          (setf final-container-w (max (style-value container-styles :min-width 0)
                                       (min final-container-w (style-value container-styles :max-width most-positive-fixnum)))))
        (when (eq styled-container-height :auto)
          (setf final-container-h (max (style-value container-styles :min-height 0)
                                       (min final-container-h (style-value container-styles :max-height most-positive-fixnum)))))

        (make-rectangle :pos (make-pos :x container-content-x
                                       :y container-content-y)
                        :size (make-size
                               :w (round final-container-w)
                               :h (round final-container-h)))))))
