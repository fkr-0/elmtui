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
                #:styled-ui-node #:style-value)
  (:export
   #:main-axis
   #:flex-container
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
   #:main-size
   #:cross-size
   #:collect-flex-lines
   ;; #:calculate-initial-main-pos ; Seems unused externally, consider removing export later
   #:get-flex-item-main-size
   #:set-flex-item-main-position
   #:set-flex-item-main-size
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
   ;; Internal layout state
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
    :accessor align-self)))

;; We also define the generic for a flex-item to return its child container.
(defmethod child-container ((item flex-item))
  (slot-value item 'child-container))

;;; ----------------------------------------------------------------------------
;;; FLEX CONTAINER CLASS
;;; ----------------------------------------------------------------------------
;;;-----------------------------------------------------------------------------
;;; Container Style Properties
;;;-----------------------------------------------------------------------------

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
  ;; flex-container inherits from flex-item so that nested containers have
  ;; common properties like main-size, cross-size, and rectangle.
  ((children
    :initarg :children
    :initform nil
    :accessor flex-item-children)
   (main-axis ; Corresponds to flex-direction (cached from style)
    :initarg :main-axis
    :initform :row
    :type (member :row :row-reverse :column :column-reverse)
    :accessor %main-axis)
   (flex-wrap ; Cached from style
    :initarg :flex-wrap
    :initform :nowrap
    :type (member :nowrap :wrap :wrap-reverse)
    :accessor %flex-wrap)
   (justify-content ; Cached from style
    :initarg :justify-content
    :initform :flex-start
    :type (member :flex-start :flex-end :center :space-between :space-around :space-evenly)
    :accessor %justify-content)
   (align-items ; Cached from style
    :initarg :align-items
    :initform :stretch
    :type (member :stretch :flex-start :flex-end :center :baseline :auto)
    :accessor %align-items)
   (align-content ; Cached from style
    :initarg :align-content
    :initform :stretch
    :type (member :stretch :flex-start :flex-end :center :space-between :space-around)
    :accessor %align-content)))

;; Override flex-container's accessors to check styles first
(defmethod main-axis ((container flex-container))
  (if (typep container 'styled-ui-node)
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
   (main-size
    :initarg :main-size
    :initform 0
    :accessor main-size)
   (cross-size
    :initarg :cross-size
    :initform 0
    :accessor cross-size)))

;;; ----------------------------------------------------------------------------
;;; SPACING & POSITIONING
;;; ----------------------------------------------------------------------------

(defun get-item-margin (item axis side)
  "Get margin for ITEM's SIDE along AXIS. Consolidates margin-* properties."
  (when (typep item 'styled-ui-node)
    (case axis
      (:row (case side
              (:start (extract-style-value item :margin-left 0))
              (:end (extract-style-value item :margin-right 0))))
      (:column (case side
                 (:start (extract-style-value item :margin-top 0))
                 (:end (extract-style-value item :margin-bottom 0))))))
  0) ; Default to 0 for non-styled nodes or unknown axis/side

(defun get-item-padding (item axis side)
  "Get padding for ITEM's SIDE along AXIS. Consolidates padding-* properties."
  (when (typep item 'styled-ui-node)
    (case axis
      (:row (case side
              (:start (extract-style-value item :padding-left 0))
              (:end (extract-style-value item :padding-right 0))))
      (:column (case side
                 (:start (extract-style-value item :padding-top 0))
                 (:end (extract-style-value item :padding-bottom 0))))))
  0) ; Default to 0 for non-styled nodes or unknown axis/side

(defun get-item-space (item axis side)
  "Get total space (margin + padding) for ITEM's SIDE along AXIS."
  (+ (get-item-margin item axis side)
     (get-item-padding item axis side)))

;;; ----------------------------------------------------------------------------
;;; SIZE & POSITION HELPERS
;;; ----------------------------------------------------------------------------

(defun get-flex-item-main-size (item axis)
  "Return the main size of ITEM based on AXIS (:row or :column).
   Includes content size plus padding and margins."
  (let* ((rect (rectangle item))
         (content-size (case axis
                         (:row (w rect))
                         (:column (h rect))
                         (otherwise (error "Unsupported axis: ~a" axis))))
         (start-space (get-item-space item axis :start))
         (end-space (get-item-space item axis :end)))
    (+ content-size start-space end-space)))

(defun get-flex-item-cross-size (item axis)
  "Return the cross size of ITEM based on AXIS (:row or :column).
   Includes content size plus padding and margins."
  (let* ((rect (rectangle item))
         (content-size (case axis
                         (:row (h rect))
                         (:column (w rect))
                         (otherwise (error "Unsupported axis: ~a" axis))))
         (start-space (get-item-space item axis :start))
         (end-space (get-item-space item axis :end)))
    (+ content-size start-space end-space)))

(defmethod flex-direction ((container flex-container))
  "Return the flex-direction keyword based on the container's main-axis."
  (main-axis container)) ; Direct mapping

(defun set-flex-item-main-position (item pos axis)
  "Set the main-axis position for ITEM's rectangle to POS (rounded).
   Accounts for start margin and padding."
  (let* ((int-pos (round pos))
         (rect (rectangle item))
         (start-space (get-item-margin item axis :start)))
    (case axis
      (:row (setf (x rect) (+ int-pos start-space)))
      (:column (setf (y rect) (+ int-pos start-space)))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-cross-position (item pos axis)
  "Set the cross-axis position for ITEM's rectangle to POS (rounded).
   Accounts for start margin and padding."
  (let* ((int-pos (round pos))
         (rect (rectangle item))
         (start-space (get-item-margin item axis :start)))
    (case axis
      (:row (setf (y rect) (+ int-pos start-space)))    ; Main axis row -> Cross axis Y
      (:column (setf (x rect) (+ int-pos start-space))) ; Main axis column -> Cross axis X
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-main-size (item size axis)
  "Set the main size of ITEM's rectangle (clamped) along AXIS."
  (let ((int-size (round size))
        (rect (rectangle item)))
    (case axis
      (:row (setf (w rect) (clamp int-size (min-width item) (max-width item))))
      (:column (setf (h rect) (clamp int-size (min-height item) (max-height item))))
      (otherwise (error "Unsupported axis: ~a" axis)))))

(defun set-flex-item-cross-size (item size axis)
  "Set the cross size of ITEM's rectangle (clamped) along AXIS."
  (let ((int-size (round size))
        (rect (rectangle item)))
    (case axis
      (:row (setf (h rect) (clamp int-size (min-height item) (max-height item)))) ; Main axis row -> Cross axis H
      (:column (setf (w rect) (clamp int-size (min-width item) (max-width item)))) ; Main axis column -> Cross axis W
      (otherwise (error "Unsupported axis: ~a" axis)))))

;; Generic size accessors based on axis (useful internally)
(defun get-main-size (entity main-axis)
  "Return the main-size slot value of ENTITY (flex-item or flex-line)."
  (declare (ignore main-axis)) ; Main-size slot is independent of axis
  (main-size entity))

(defun set-main-size (entity size main-axis)
  "Set ENTITY's main-size slot."
  (declare (ignore main-axis))
  (setf (main-size entity) (round size)))

(defun get-cross-size (entity main-axis)
  "Return the cross-size slot value of ENTITY (flex-item or flex-line)."
  (declare (ignore main-axis)) ; Cross-size slot is independent of axis
  (cross-size entity))

(defun set-cross-size (entity size main-axis)
  "Set ENTITY's cross-size slot."
  (declare (ignore main-axis))
  (setf (cross-size entity) (round size)))

(defun derive-available-main-size (container)
  "Return the container's available size along its main-axis from its rectangle."
  (let ((axis (main-axis container))
        (rect (rectangle container)))
    (case axis
      ((:row :row-reverse) (w rect))
      ((:column :column-reverse) (h rect))
      (otherwise 0))))

(defun derive-available-cross-size (container)
  "Return the container's available size along its cross-axis from its rectangle."
  (let ((axis (main-axis container))
        (rect (rectangle container)))
    (case axis
      ((:row :row-reverse) (h rect)) ; Cross axis is height for row
      ((:column :column-reverse) (w rect)) ; Cross axis is width for column
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
  "Determine the main size of each item based on flex-basis, flex-grow, and flex-shrink."
  ;; 1. Determine used space by summing flex-basis (or content size if basis is nil).
  (dolist (item items)
    (setf (main-size item)
          (or (flex-basis item)
              (get-flex-item-main-size item main-axis))))

  (let* ((initial-used-space (reduce #'+ items :key (lambda (it) (main-size it)) :initial-value 0))
         (remaining-space (- available-main-size initial-used-space)))

    (if (>= remaining-space 0)
        ;; 2a. Distribute positive remaining space (Flex Grow)
        (let ((total-flex-grow (reduce #'+ items :key #'flex-grow :initial-value 0)))
          (when (> total-flex-grow 0)
            (dolist (item items)
              (when (> (flex-grow item) 0)
                (let* ((grow-ratio (/ (flex-grow item) total-flex-grow))
                       (grow-amount (* remaining-space grow-ratio)))
                  (incf (main-size item) grow-amount))))))
        ;; 2b. Distribute negative remaining space (Flex Shrink)
        (let ((total-weighted-shrink (reduce #'+ items
                                             :key (lambda (it) (* (flex-shrink it) (main-size it)))
                                             :initial-value 0)))
          (when (> total-weighted-shrink 0)
            (dolist (item items)
              (when (> (flex-shrink item) 0)
                (let* ((weighted-shrink (* (flex-shrink item) (main-size item)))
                       (shrink-ratio (/ weighted-shrink total-weighted-shrink))
                       ;; remaining-space is negative here
                       (shrink-amount (* (- remaining-space) shrink-ratio)))
                  (decf (main-size item) shrink-amount)))))))

    ;; 3. Clamp sizes to min/max constraints and update rectangle
    (dolist (item items)
      (set-flex-item-main-size item (main-size item) main-axis)
      ;; Also initialize cross-size based on rectangle for later alignment steps
      (setf (cross-size item) (get-flex-item-cross-size item main-axis)))
    items))

;;; ----------------------------------------------------------------------------
;;; 2. COLLECTING FLEX LINES (Wrap / No-Wrap)
;;; ----------------------------------------------------------------------------
(defun collect-flex-lines (container available-main-size main-axis)
  "Collect flex lines for CONTAINER along main-axis, respecting flex-wrap.
   Assumes item main sizes have been resolved."
  (let* ((wrap-type (flex-wrap container))
         (sorted-items (sort (copy-list (flex-item-children container)) #'< :key #'order)))
    (if (eq wrap-type :nowrap)
        ;; Single line containing all items
        (list (make-instance 'flex-line
                             :items sorted-items
                             :main-size (reduce #'+ sorted-items :key (lambda (it) (get-main-size it main-axis)) :initial-value 0)
                             :cross-size (if sorted-items
                                             (reduce #'max sorted-items :key (lambda (it) (get-cross-size it main-axis)))
                                             0)))
        ;; Handle wrapping (:wrap or :wrap-reverse - reverse handled later)
        (loop with lines = '()
              with current-line-items = '()
              with current-line-main-size = 0
              for item in sorted-items
              do
                 (let ((item-main-size (get-main-size item main-axis)))
                   (if (and current-line-items (> (+ current-line-main-size item-main-size) available-main-size))
                       ;; Start a new line
                       (progn
                         (push (make-instance 'flex-line
                                              :items (reverse current-line-items)
                                              :main-size current-line-main-size
                                              :cross-size (if current-line-items
                                                              (reduce #'max current-line-items :key (lambda (it) (get-cross-size it main-axis)))
                                                              0))
                               lines)
                         (setf current-line-items (list item))
                         (setf current-line-main-size item-main-size))
                       ;; Add to current line
                       (progn
                         (push item current-line-items)
                         (incf current-line-main-size item-main-size))))
              finally
                 (when current-line-items
                   (push (make-instance 'flex-line
                                        :items (reverse current-line-items)
                                        :main-size current-line-main-size
                                        :cross-size (if current-line-items
                                                        (reduce #'max current-line-items :key (lambda (it) (get-cross-size it main-axis)))
                                                        0))
                         lines))
                 (return (reverse lines)))))) ; Return lines in logical order

;;; ----------------------------------------------------------------------------
;;; 3. MAIN AXIS ALIGNMENT (Justify Content)
;;; ----------------------------------------------------------------------------
(defun justify-content-alignment (line container available-main-size main-axis)
  "Calculate and set main-axis positions for items within a single line based on justify-content."
  (let* ((items (items line))
         (num-items (length items))
         (jc (justify-content container))
         (line-main-size (main-size line)) ; Use calculated line size
         (remaining-space (- available-main-size line-main-size))
         (current-pos 0.0))

    (when (<= num-items 0) (return-from justify-content-alignment)) ; Empty line

    ;; Handle reverse directions by reversing items temporarily
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
                  (set-flex-item-main-position item current-pos main-axis)
                  (incf current-pos (get-main-size item main-axis))
                  (unless (= i (1- num-items)) ; Don't add gap after last item
                    (incf current-pos gap)))
         (return-from justify-content-alignment))) ; Skip common loop below
      (:space-around
       (let ((gap (if (> num-items 0) (/ remaining-space num-items) 0.0)))
         (setf current-pos (/ gap 2.0))
         (loop for item in items
               do
                  (set-flex-item-main-position item current-pos main-axis)
                  (incf current-pos (+ (get-main-size item main-axis) gap)))
         (return-from justify-content-alignment))) ; Skip common loop below
      (:space-evenly
       (let ((gap (if (> num-items 0) (/ remaining-space (1+ num-items)) 0.0)))
         (setf current-pos gap)
         (loop for item in items
               do
                  (set-flex-item-main-position item current-pos main-axis)
                  (incf current-pos (+ (get-main-size item main-axis) gap)))
         (return-from justify-content-alignment))) ; Skip common loop below
      (otherwise ; Default to flex-start
       (setf current-pos 0.0)))

    ;; Common loop for :flex-start, :flex-end, :center
    (loop for item in items
          do
             (set-flex-item-main-position item current-pos main-axis)
             (incf current-pos (get-main-size item main-axis)))))

;;; ----------------------------------------------------------------------------
;;; 4. CROSS AXIS ALIGNMENT (Align Items / Align Self / Align Content)
;;; ----------------------------------------------------------------------------

(defun determine-line-cross-sizes (lines container available-cross-size main-axis)
  "Determine the cross size of each flex line based on align-content."
  (declare (ignore main-axis)) ; Main axis is not used here
  (let* ((num-lines (length lines))
         (ac (align-content container))
         (total-lines-cross-size (reduce #'+ lines :key (lambda (ln) (cross-size ln)) :initial-value 0))
         (remaining-cross-space (- available-cross-size total-lines-cross-size)))

    (when (<= num-lines 0) (return-from determine-line-cross-sizes))

    (case ac
      (:stretch
       ;; Distribute remaining space evenly if positive
       (when (> remaining-cross-space 0)
         (let ((stretch-amount (/ remaining-cross-space num-lines)))
           (dolist (line lines)
             (incf (cross-size line) stretch-amount)))))
      ;; Other align-content values (:flex-start, :flex-end, :center, :space-between, etc.)
      ;; don't change the intrinsic cross-size of the lines themselves, only their positioning.
      ;; The cross-size calculated during collect-flex-lines (max item cross size) remains.
      (:flex-start)
      (:flex-end)
      (:center)
      (:space-between)
      (:space-around)
      (otherwise (warn "Unsupported align-content value: ~A. Treating as :flex-start." ac)))

    ;; Ensure cross sizes are non-negative after potential stretching
    (dolist (line lines)
      (setf (cross-size line) (max 0.0 (cross-size line))))))

(defun align-items-in-line (line line-cross-pos line-cross-size container main-axis)
  "Align items within a single flex line on the cross axis."
  (let ((items (items line))
        (container-align-items (align-items container)))
    (dolist (item items)
      (let* ((item-cross-size (get-cross-size item main-axis))
             (item-align-self (or (align-self item) container-align-items))
             ;; Resolve :auto and :baseline (treat baseline as flex-start for now)
             (effective-align (case item-align-self
                                (:auto :stretch) ; Default auto behavior is stretch
                                (:baseline :flex-start) ; Simplification
                                (t item-align-self)))
             (available-space (- line-cross-size item-cross-size))
             (item-cross-pos line-cross-pos))

        (case effective-align
          (:stretch
           ;; Set item's cross size to the line's cross size
           (set-flex-item-cross-size item line-cross-size main-axis)
           (setf item-cross-pos line-cross-pos)) ; Position at the start of the line space
          (:flex-start
           (setf item-cross-pos line-cross-pos))
          (:flex-end
           (setf item-cross-pos (+ line-cross-pos available-space)))
          (:center
           (setf item-cross-pos (+ line-cross-pos (/ available-space 2.0))))
          (otherwise (warn "Unsupported align-items/align-self: ~A" effective-align)))

        (set-flex-item-cross-position item item-cross-pos main-axis)))))

(defun align-cross-axis (lines container available-cross-size main-axis)
  "Position flex lines and align items within them along the cross axis."
  (determine-line-cross-sizes lines container available-cross-size main-axis)

  (let* ((num-lines (length lines))
         (ac (align-content container))
         (total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0))
         (remaining-cross-space (max 0.0 (- available-cross-size total-lines-cross-size))) ; Ensure non-negative
         (current-cross-pos 0.0))

    (when (<= num-lines 0) (return-from align-cross-axis))

    ;; Handle wrap-reverse by reversing lines temporarily
    (when (eq (flex-wrap container) :wrap-reverse)
      (setf lines (reverse lines)))

    ;; Calculate starting position based on align-content
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
         (return-from align-cross-axis))) ; Skip common loop
      (:space-around
       (let ((gap (if (> num-lines 0) (/ remaining-cross-space num-lines) 0.0)))
         (setf current-cross-pos (/ gap 2.0))
         (loop for line in lines
               do
                  (align-items-in-line line current-cross-pos (cross-size line) container main-axis)
                  (incf current-cross-pos (+ (cross-size line) gap)))
         (return-from align-cross-axis))) ; Skip common loop
      (:stretch ; Stretch already handled in determine-line-cross-sizes
       (setf current-cross-pos 0.0))
      (otherwise ; Default to flex-start
       (setf current-cross-pos 0.0)))

    ;; Common loop for positioning lines (:flex-start, :flex-end, :center, :stretch)
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
      ;; The item's rectangle (pos/size) should already be set by the parent's
      ;; resolve-flexible-lengths and alignment steps before this is called.
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

    ;; Ensure container itself has a valid rectangle
    (unless (and (rectangle container) (valid-p (rectangle container)))
      (error "Flex container requires a valid rectangle for layout: ~A" container))

    ;; 0. Handle absolute positioning? (Skipped in this basic flex implementation)

    ;; 1. Resolve flexible lengths (Determine main sizes)
    (resolve-flexible-lengths items available-main-size main-axis)

    ;; 2. Collect flex lines
    (let ((lines (collect-flex-lines container available-main-size main-axis)))

      ;; 3. Main Axis Alignment (Justify Content for each line)
      (dolist (line lines)
        (justify-content-alignment line container available-main-size main-axis))

      ;; 4. Cross Axis Alignment (Align Content for lines, Align Items within lines)
      (align-cross-axis lines container available-cross-size main-axis)

      ;; 5. Recursive Layout for Nested Containers
      ;; This needs to happen *after* parent layout determines the nested container's bounds.
      (layout-nested-containers container)

      ;; 6. Finalize container's own cross-size based on lines (if wrapping)
      ;; This might be redundant if the container's size is fixed, but useful if it's content-sized.
      (when (and (member (flex-wrap container) '(:wrap :wrap-reverse)) lines)
        (let ((total-lines-cross-size (reduce #'+ lines :key #'cross-size :initial-value 0)))
          (declare (ignore total-lines-cross-size))
          ;; Decide if we should update the container's rectangle height/width
          ;; For now, assume container size is fixed by parent layout or initial state.
          ;; (set-flex-item-cross-size container total-lines-cross-size main-axis)
          ))

      ;; 7. Add container's own position offset to all children
      (let ((offset-x (x container))
            (offset-y (y container)))
        (dolist (item items)
          (dx! (rectangle item) offset-x)
          (dy! (rectangle item) offset-y)))

      container))) ; Return the laid-out container
