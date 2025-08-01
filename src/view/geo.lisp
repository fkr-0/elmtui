;;; ===============================================================
;;; File: src/view/geo.lisp
;;; Geometric Primitives (Ported/Refactored from uncharming-tui.geo)
;;; ===============================================================
(uiop:define-package :elmtui.view.geo
  (:use :cl :log4cl)
  (:nicknames :et.geo)
  ;; Removed :ut.config import, defining =? locally
  (:import-from :cl :make-instance)
  (:import-from :sb-pcl
                #:make-instance)
  (:export #:=? #:area #:area< #:contains-p #:normalize!
           #:rectangle-union #:border #:bounding-box #:circle
           #:corner #:dim #:dim-length #:dim-pos #:flip #:grow-view!
           #:h #:line #:make-pos #:make-rectangle #:make-size
           #:move! #:overlap #:polygon #:pos #:rect-diff #:rectangle
           #:make-instance
           #:pos-x #:pos-y #:rectangle-size #:rectangle-pos
           #:clamp ; Added clamp
           #:rectangle-pos #:rectangle-union-list
           #:resize-dimension! #:rotate #:scale #:shrink-view!
           #:size #:translate #:triangle #:valid-p #:w #:x #:x2 #:y
           #:y2))
(in-package :elmtui.view.geo)

;;;-----------------------------------------------------------------------------
;;; Local =? Definition (Placeholder/Adaptation)
;;;-----------------------------------------------------------------------------

(defgeneric =? (a b)
  (:documentation "Generic equality check. Adapts behavior based on type."))

(defmethod =? ((a t) (b t))
  "Default equality check using EQUALP."
  (equalp a b))

(defmethod =? ((a symbol) (b symbol))
  "Check if two symbols are equal using EQL."
  (eql a b))

(defmethod =? ((a list) (b list))
  "Check if two lists are equal by comparing lengths and elements recursively using =?."
  (and (= (length a) (length b))
       (every #'=? a b)))
;; (let ((l '(:column :id :main-column
;;               :children
;;               ((:test-component :id :comp1 :initial-state "comp1 state")
;;                (:test-parent-component :id :parent1 :child-initial-state "child state")))))
;;   (=? l l))
;;;-----------------------------------------------------------------------------
;;; Struct Definitions
;;;-----------------------------------------------------------------------------

(defstruct (size (:conc-name size-))
  (w 0 :type (integer 0 *))
  (h 0 :type (integer 0 *)))

(defstruct (pos (:conc-name pos-))
  (x 0 :type (integer 0 *))
  (y 0 :type (integer 0 *)))

(defstruct (rectangle (:conc-name rectangle-))
  (size (make-size) :type size)
  (pos (make-pos) :type pos))

;; Add =? methods for structs after they are defined
(defmethod =? ((a pos) (b pos))
  "Check if two pos structs are equal."
  (and (= (pos-x a) (pos-x b))
       (= (pos-y a) (pos-y b))))

(defmethod =? ((a size) (b size))
  "Check if two size structs are equal."
  (and (= (size-w a) (size-w b))
       (= (size-h a) (size-h b))))

(defmethod =? ((a rectangle) (b rectangle))
  "Check if two rectangle structs are equal."
  (and (=? (rectangle-pos a) (rectangle-pos b))
       (=? (rectangle-size a) (rectangle-size b))))



;;;-----------------------------------------------------------------------------
;;; Generic Accessors/Methods
;;;-----------------------------------------------------------------------------

(defgeneric area (obj)
  (:documentation "Calculate the area of the object (size or rectangle)."))

(defgeneric size (obj)
  (:documentation "Get the size struct of the object (rectangle)."))

(defgeneric pos (obj)
  (:documentation "Get the pos struct of the object (rectangle)."))

(defgeneric w (obj)
  (:documentation "Get the width of the object (size or rectangle)."))

(defgeneric h (obj)
  (:documentation "Get the height of the object (size or rectangle)."))

(defgeneric x (obj)
  (:documentation "Get the x-coordinate of the object (pos or rectangle)."))

(defgeneric y (obj)
  (:documentation "Get the y-coordinate of the object (pos or rectangle)."))

(defgeneric (setf w) (new-value obj)
  (:documentation "Set the width of the object (size or rectangle)."))

(defgeneric (setf h) (new-value obj)
  (:documentation "Set the height of the object (size or rectangle)."))

(defgeneric (setf x) (new-value obj)
  (:documentation "Set the x-coordinate of the object (pos or rectangle)."))

(defgeneric (setf y) (new-value obj)
  (:documentation "Set the y-coordinate of the object (pos or rectangle)."))

(defgeneric x2 (rectangle)
  (:documentation "Get the x2 coordinate (x + width) of the rectangle."))

(defgeneric y2 (rectangle)
  (:documentation "Get the y2 coordinate (y + height) of the rectangle."))

(defgeneric dim (obj dimension)
  (:documentation "Get the value of a specific dimension (:x, :y, :w, :h, 0, 1) for pos, size, or rectangle."))

(defgeneric (setf dim) (new-value obj dimension)
  (:documentation "Set the value of a specific dimension for pos, size, or rectangle."))

(defgeneric dim-pos (rectangle dimension)
  (:documentation "Get the position component (:x or :y) of a rectangle's dimension."))

(defgeneric (setf dim-pos) (new-value rectangle dimension)
  (:documentation "Set the position component (:x or :y) of a rectangle's dimension."))

(defgeneric dim-length (rectangle dimension)
  (:documentation "Get the length component (:w or :h) of a rectangle's dimension."))

(defgeneric (setf dim-length) (new-value rectangle dimension)
  (:documentation "Set the length component (:w or :h) of a rectangle's dimension."))

;;;-----------------------------------------------------------------------------
;;; MAKE-INSTANCE Methods
;;;-----------------------------------------------------------------------------

(defmethod make-instance ((class (eql 'pos)) &rest initargs)
  (let ((p (make-pos)))
    (loop for (key value) on initargs by #'cddr
          do (case key
               (:x (setf (pos-x p) value))
               (:y (setf (pos-y p) value))
               (otherwise (error "Invalid initarg for pos: ~A" key))))
    p))

(defmethod make-instance ((class (eql 'size)) &rest initargs)
  (let ((s (make-size)))
    (loop for (key value) on initargs by #'cddr
          do (case key
               (:w (setf (size-w s) value))
               (:h (setf (size-h s) value))
               (:width (setf (size-w s) value)) ; Alias
               (:height (setf (size-h s) value)) ; Alias
               (otherwise (error "Invalid initarg for size: ~A" key))))
    s))

(defmethod make-instance ((class (eql 'rectangle)) &rest initargs)
  (let ((r (make-rectangle)))
    (loop for (key value) on initargs by #'cddr
          do (case key
               (:pos (setf (rectangle-pos r) value))
               (:size (setf (rectangle-size r) value))
               (:x (setf (pos-x (rectangle-pos r)) value))
               (:y (setf (pos-y (rectangle-pos r)) value))
               (:w (setf (size-w (rectangle-size r)) value))
               (:h (setf (size-h (rectangle-size r)) value))
               (:width (setf (size-w (rectangle-size r)) value)) ; Alias
               (:height (setf (size-h (rectangle-size r)) value)) ; Alias
               (otherwise (error "Invalid initarg for rectangle: ~A" key))))
    ;; Normalize after setting potentially negative dimensions via x/y/w/h
    (normalize! r)
    r))

;;;-----------------------------------------------------------------------------
;;; Method Implementations
;;;-----------------------------------------------------------------------------

;; Area
(defmethod area ((s size)) (* (size-w s) (size-h s)))
(defmethod area ((r rectangle)) (area (rectangle-size r)))

;; Area Comparison
(defgeneric area< (obj1 obj2)
  (:documentation "Check if the area of obj1 is less than the area of obj2."))
(defmethod area< ((s1 size) (s2 size)) (< (area s1) (area s2)))
(defmethod area< ((r1 rectangle) (r2 rectangle)) (< (area r1) (area r2)))

;; Validity
(defgeneric valid-p (obj)
  (:documentation "Check if the object (size or rectangle) is valid (non-negative dimensions)."))
(defmethod valid-p ((s size)) (and (>= (size-w s) 0) (>= (size-h s) 0)))
(defmethod valid-p ((r rectangle)) (valid-p (rectangle-size r)))

(defmethod x ((p list))
  "if len of elements == 2, take first, if length = 4, take first, otherwise error."
  (if (and (listp p) (or (= (length p) 2) (= (length p) 4)))
      (first p)
      (error "Invalid position list: ~A" p)))
(defmethod y ((p list))
  "if len of elements == 2, take second, if length = 4, take second, otherwise error."
  (if (and (listp p) (or (= (length p) 2) (= (length p) 4)))
      (second p)
      (error "Invalid position list: ~A" p)))
(defmethod w ((s list))
  "if len of elements == 2, take first, if length = 4, take third, otherwise error."
  (if (and (listp s) (or (= (length s) 2) (= (length s) 4)))
      (if (= (length s) 2) (first s) (third s))
      (error "Invalid size list: ~A" s)))
(defmethod h ((s list))
  "if len of elements == 2, take second, if length = 4, take fourth, otherwise error."
  (if (and (listp s) (or (= (length s) 2) (= (length s) 4)))
      (if (= (length s) 2) (second s) (fourth s))
      (error "Invalid size list: ~A" s)))
;; Accessors (Pos)
(defmethod x ((p pos)) (pos-x p))
(defmethod y ((p pos)) (pos-y p))
(defmethod (setf x) (new-value (p pos)) (setf (pos-x p) new-value))
(defmethod (setf y) (new-value (p pos)) (setf (pos-y p) new-value))

;; Accessors (Size)
(defmethod w ((s size)) (size-w s))
(defmethod h ((s size)) (size-h s))
(defmethod (setf w) (new-value (s size)) (setf (size-w s) new-value))

;; Accessors (Rectangle)
(defmethod pos ((r rectangle)) (rectangle-pos r))
(defmethod size ((r rectangle)) (rectangle-size r))
(defmethod x ((r rectangle)) (pos-x (rectangle-pos r)))
(defmethod y ((r rectangle)) (pos-y (rectangle-pos r)))
(defmethod w ((r rectangle)) (size-w (rectangle-size r)))
(defmethod h ((r rectangle)) (size-h (rectangle-size r)))
(defmethod (setf x) (new-value (r rectangle)) (setf (pos-x (rectangle-pos r)) new-value))
(defmethod (setf y) (new-value (r rectangle)) (setf (pos-y (rectangle-pos r)) new-value))
(defmethod (setf w) (new-value (r rectangle)) (setf (size-w (rectangle-size r)) new-value))
(defmethod (setf h) (new-value (r rectangle)) (setf (size-h (rectangle-size r)) new-value))

;; Calculated Accessors (Rectangle)
(defmethod x2 ((r rectangle)) (+ (x r) (w r)))
(defmethod y2 ((r rectangle)) (+ (y r) (h r)))

;; Dimension Accessors (Dim)
(defmethod dim ((p pos) dimension)
  (case dimension
    ((0 :x) (pos-x p))
    ((1 :y) (pos-y p))
    (otherwise (error "Invalid dimension for pos: ~A" dimension))))

(defmethod dim ((s size) dimension)
  (case dimension
    ((0 :w :x) (size-w s)) ; Treat :x as width for size
    ((1 :h :y) (size-h s)) ; Treat :y as height for size
    (otherwise (error "Invalid dimension for size: ~A" dimension))))

(defmethod dim ((r rectangle) dimension)
  (case dimension
    (:x (x r))
    (:y (y r))
    (:w (w r))
    (:h (h r))
    (0 (x r)) ; Treat 0 as x for rectangle
    (1 (y r)) ; Treat 1 as y for rectangle
    (otherwise (error "Invalid dimension for rectangle: ~A" dimension))))

;; Dimension Setters (Setf Dim)
(defmethod (setf dim) (new-value (p pos) dimension)
  (case dimension
    ((0 :x) (setf (pos-x p) new-value))
    ((1 :y) (setf (pos-y p) new-value))
    (otherwise (error "Invalid dimension for pos: ~A" dimension))))

(defmethod (setf dim) (new-value (s size) dimension)
  (case dimension
    ((0 :w :x) (setf (size-w s) new-value))
    ((1 :h :y) (setf (size-h s) new-value))
    (otherwise (error "Invalid dimension for size: ~A" dimension))))

(defmethod (setf dim) (new-value (r rectangle) dimension)
  (case dimension
    (:x (setf (x r) new-value))
    (:y (setf (y r) new-value))
    (:w (setf (w r) new-value))
    (:h (setf (h r) new-value))
    (0 (setf (x r) new-value))
    (1 (setf (y r) new-value))
    (otherwise (error "Invalid dimension for rectangle: ~A" dimension))))

;; Rectangle Dimension Helpers
(defmethod dim-pos ((r rectangle) dimension)
  (dim (rectangle-pos r) dimension))

(defmethod (setf dim-pos) (new-value (r rectangle) dimension)
  (setf (dim (rectangle-pos r) dimension) new-value))

(defmethod dim-length ((r rectangle) dimension)
  (dim (rectangle-size r) dimension))

(defmethod (setf dim-length) (new-value (r rectangle) dimension)
  (setf (dim (rectangle-size r) dimension) new-value))

;;;-----------------------------------------------------------------------------
;;; Geometric Operations
;;;-----------------------------------------------------------------------------

;; Difference
(defgeneric difference (obj1 obj2)
  (:documentation "Calculate the difference between two objects (e.g., positions)."))
(defmethod difference ((p1 pos) (p2 pos))
  (make-instance 'pos :x (- (x p1) (x p2)) :y (- (y p1) (y p2))))

;; Rectangle Between Points
(defgeneric rectangle-between (p1 p2)
  (:documentation "Calculate the bounding rectangle between two positions."))
(defmethod rectangle-between ((p1 pos) (p2 pos))
  (let ((x (min (x p1) (x p2)))
        (y (min (y p1) (y p2)))
        (x2 (max (x p1) (x p2)))
        (y2 (max (y p1) (y p2))))
    (make-instance 'rectangle :x x :y y :w (- x2 x) :h (- y2 y))))

;; Delta Operations (Non-mutating)
(defgeneric dx (obj delta)
  (:documentation "Return a new object shifted horizontally by delta."))
(defgeneric dy (obj delta)
  (:documentation "Return a new object shifted vertically by delta."))

(defmethod dx ((p pos) delta) (make-instance 'pos :x (+ (x p) delta) :y (y p)))
(defmethod dy ((p pos) delta) (make-instance 'pos :x (x p) :y (+ (y p) delta)))
(defmethod dx ((r rectangle) delta) (make-instance 'rectangle :pos (dx (pos r) delta) :size (size r)))
(defmethod dy ((r rectangle) delta) (make-instance 'rectangle :pos (dy (pos r) delta) :size (size r)))

;; Delta Operations (Mutating)
(defgeneric dx! (obj delta)
  (:documentation "Shift the object horizontally by delta (mutating)."))
(defgeneric dy! (obj delta)
  (:documentation "Shift the object vertically by delta (mutating)."))

(defmethod dx! ((p pos) delta)
  (setf (pos-x p) (+ (pos-x p) delta)) p)
(defmethod dy! ((p pos) delta)
  (setf (pos-y p) (+ (pos-y p) delta)) p)
(defmethod dx! ((r rectangle) delta) (dx! (pos r) delta) r)
(defmethod dy! ((r rectangle) delta) (dy! (pos r) delta) r)

;; Move (Mutating)
(defgeneric move! (obj &key x y dx dy)
  (:documentation "Move the object to absolute (x, y) then by relative (dx, dy) (mutating)."))

(defmethod move! ((p pos) &key (x nil x-p) (y nil y-p) (dx 0) (dy 0))
  (when x-p (setf (pos-x p) x))
  (when y-p (setf (pos-y p) y))
  (incf (pos-x p) dx)
  (incf (pos-y p) dy)
  p)

(defmethod move! ((r rectangle) &key (x nil x-p) (y nil y-p) (dx 0) (dy 0))
  (apply #'move! (pos r) :dx dx :dy dy (append (when x-p `(:x ,x)) (when y-p `(:y ,y))))
  r)

;; Union
(defmethod rectangle-union ((r1 rectangle) (r2 rectangle))
  "Calculate the bounding box containing both rectangles."
  (let ((x (min (x r1) (x r2)))
        (y (min (y r1) (y r2)))
        (x2 (max (x2 r1) (x2 r2)))
        (y2 (max (y2 r1) (y2 r2))))
    (make-instance 'rectangle :x x :y y :w (- x2 x) :h (- y2 y))))

(defgeneric rectangle-union-list (rectangles)
  (:documentation "Calculate the union of a list of rectangles."))
(defmethod rectangle-union-list ((r rectangle)) r) ; Base case: single rectangle
(defmethod rectangle-union-list ((rectangles list))
  (when rectangles
    (reduce #'rectangle-union rectangles)))

;; Overlap
(defmethod overlap ((r1 rectangle) (r2 rectangle))
  "Calculate the intersection rectangle of two rectangles, or NIL if no overlap."
  (let* ((x (max (x r1) (x r2)))
         (y (max (y r1) (y r2)))
         (x2 (min (x2 r1) (x2 r2)))
         (y2 (min (y2 r1) (y2 r2))))
    (when (and (< x x2) (< y y2)) ; Check for positive width and height
      (make-instance 'rectangle :x x :y y :w (- x2 x) :h (- y2 y)))))

;; Contains Point
(defmethod contains-p ((r rectangle) (p pos))
  "Check if the rectangle contains the position.
"
  (and (<= (x r) (x p)) (< (x p) (x2 r)) ; Use < for x2/y2 for exclusive upper bound
       (<= (y r) (y p)) (< (y p) (y2 r))))

(defmethod contains-p ((r rectangle) (p list))
  "Check if the rectangle contains the point specified as (x y) list."
  (and (= (length p) 2)
       (every #'numberp p)
       (contains-p r (make-instance 'pos :x (first p) :y (second p)))))

;; Contains Rectangle
(defmethod contains-p ((r1 rectangle) (r2 rectangle))
  "Check if rectangle r1 completely contains rectangle r2."
  (and (<= (x r1) (x r2))
       (<= (y r1) (y r2))
       (>= (x2 r1) (x2 r2))
       (>= (y2 r1) (y2 r2))))

;; Normalize (Ensure non-negative width/height)
(defmethod normalize! ((r rectangle))
  "Ensure the rectangle has non-negative width and height by adjusting pos if necessary."
  (when (< (w r) 0)
    (incf (x r) (w r))
    (setf (w r) (- (w r))))
  (when (< (h r) 0)
    (incf (y r) (h r))
    (setf (h r) (- (h r))))
  r)

;; Initialize Instance :after for Normalization
(defmethod initialize-instance :after ((r rectangle) &key)
  (normalize! r))

;; Shrink/Grow (Mutating) - Simplified using resize-dimension!
(defun neg-err (val &optional (var-name "Value"))
  "Helper to signal error if value becomes negative."
  (unless (>= val 0)
    (error "~A cannot become negative." var-name))
  val)

(defmethod resize-dimension! ((r rectangle) &key (side :right) (amount 1))
  "Resize the rectangle by adjusting one side (mutating)."
  (case side
    (:left   (let ((delta amount)) (setf (w r) (neg-err (- (w r) delta) :w)) (incf (x r) delta)))
    (:right  (let ((delta amount)) (setf (w r) (neg-err (+ (w r) delta) :w))))
    (:top    (let ((delta amount)) (setf (h r) (neg-err (- (h r) delta) :h)) (incf (y r) delta)))
    (:bottom (let ((delta amount)) (setf (h r) (neg-err (+ (h r) delta) :h))))
    (otherwise (error "Invalid side for resize-dimension!: ~A" side)))
  r)

(defmethod shrink-view! ((r rectangle) &key (side :right) (amount 1))
  "Shrink the rectangle from a specified side (mutating)."
  (resize-dimension! r :side side :amount (- amount)))

(defmethod grow-view! ((r rectangle) &key (side :right) (amount 1))
  "Grow the rectangle from a specified side (mutating)."
  (resize-dimension! r :side side :amount amount))

;; Corner
(defmethod corner ((r rectangle) corner-keyword)
  "Get the position of a specified corner (:top-left, :top-right, :bottom-left, :bottom-right)."
  (case corner-keyword
    (:top-left     (make-instance 'pos :x (x r) :y (y r)))
    (:top-right    (make-instance 'pos :x (x2 r) :y (y r)))
    (:bottom-left  (make-instance 'pos :x (x r) :y (y2 r)))
    (:bottom-right (make-instance 'pos :x (x2 r) :y (y2 r)))
    (otherwise (error "Invalid corner keyword: ~A" corner-keyword))))

;; Line (Axis-aligned)
(defmethod line ((p1 pos) (p2 pos))
  "Create a 1-unit thick rectangle representing an axis-aligned line between two points."
  (let ((dx (- (x p2) (x p1)))
        (dy (- (y p2) (y p1))))
    (unless (or (zerop dx) (zerop dy))
      (error "Cannot create diagonal line with this method."))
    (let ((x (min (x p1) (x p2)))
          (y (min (y p1) (y p2)))
          (w (if (zerop dx) 1 (1+ (abs dx)))) ; Width is 1 if vertical, else dx+1
          (h (if (zerop dy) 1 (1+ (abs dy))))) ; Height is 1 if horizontal, else dy+1
      (make-instance 'rectangle :x x :y y :w w :h h))))

;; Rectangle Difference (Subtract r2 from r1)
(defmethod rect-diff ((r1 rectangle) (r2 rectangle))
  "Calculate the list of rectangles representing r1 minus the overlapping area with r2."
  (let ((overlap-rect (overlap r1 r2)))
    (unless overlap-rect
      (return-from rect-diff (list r1))) ; No overlap, return r1

    (let ((rects '())
          (ox (x overlap-rect))
          (oy (y overlap-rect))
          (ox2 (x2 overlap-rect))
          (oy2 (y2 overlap-rect))
          (x (x r1)) (y (y r1))
          (x2 (x2 r1)) (y2 (y2 r1)))

      ;; Top part
      (when (> oy y)
        (push (make-instance 'rectangle :x x :y y :w (w r1) :h (- oy y)) rects))
      ;; Bottom part
      (when (< oy2 y2)
        (push (make-instance 'rectangle :x x :y oy2 :w (w r1) :h (- y2 oy2)) rects))
      ;; Left part (within the vertical bounds of the overlap)
      (when (> ox x)
        (push (make-instance 'rectangle :x x :y oy :w (- ox x) :h (h overlap-rect)) rects))
      ;; Right part (within the vertical bounds of the overlap)
      (when (< ox2 x2)
        (push (make-instance 'rectangle :x ox2 :y oy :w (- x2 ox2) :h (h overlap-rect)) rects))

      (nreverse rects))))


                                        ; Example usage
;; Border
(defmethod border ((r rectangle) &key (side :all) (width 1))
  "Get the border(s) of the rectangle as a list of rectangles."
  (let ((x (x r)) (y (y r)) (w (w r)) (h (h r)))
    (flet ((make-border (bx by bw bh)
             (overlap r (make-instance 'rectangle :x bx :y by :w bw :h bh)))) ; Ensure border is within original rect bounds
      (case side
        (:all (remove nil (list (make-border x y w width)          ; Top
                                (make-border x (- (+ y h) width) w width) ; Bottom
                                (make-border x y width h)          ; Left
                                (make-border (- (+ x w) width) y width h)))) ; Right
        (:top (make-border x y w width))
        (:bottom (make-border x (- (+ y h) width) w width))
        (:left (make-border x y width h))
        (:right (make-border (- (+ x w) width) y width h))
        (otherwise (error "Invalid border side: ~A" side))))))

;;;-----------------------------------------------------------------------------
;;; Clamp Function
;;;-----------------------------------------------------------------------------
(defun clamp (value min max)
  "Clamps VALUE to be within the range [MIN, MAX]."
  (cond
    ((> min max) (error "Clamp: min (~A) cannot be greater than max (~A)." min max))
    ((< value min) min)
    ((> value max) max)
    (t value)))

;;;-----------------------------------------------------------------------------
;;; Printing
;;;-----------------------------------------------------------------------------

(defmethod print-object ((p pos) stream)
  (print-unreadable-object (p stream :type t)
    (format stream "X:~A Y:~A" (pos-x p) (pos-y p))))

(defmethod print-object ((s size) stream)
  (print-unreadable-object (s stream :type t)
    (format stream "W:~A H:~A" (size-w s) (size-h s))))

(defmethod print-object ((r rectangle) stream)
  (print-unreadable-object (r stream :type t)
    (format stream "Pos:~A Size:~A" (rectangle-pos r) (rectangle-size r))))

;;;-----------------------------------------------------------------------------
;;; Deprecated/Commented Out Methods (from original) - Review if needed
;;;-----------------------------------------------------------------------------
;; (defmethod set-width ((rectangle rectangle) width) ...) ; Use (setf w)
;; (defmethod set-height ((rectangle rectangle) height) ...) ; Use (setf h)
;; (defmethod move-to! ...) ; Use move! with :x, :y
;; (defmethod move-diff! ...) ; Use move! with :dx, :dy
;; (defmethod rect-size ...) ; Use size accessor
;; (defmethod pos ...) ; Use pos accessor
;; (defmethod xor-intersect ...) ; Complex, maybe rect-diff is sufficient?
;; (defmethod fill-rect ...) ; Belongs in rendering/platform layer
;; Style/Layout/Scene classes/macros ; Belongs in higher-level view/ui/style layers
;; DSL macros (defscene, with-scene, defrect, etc.) ; Belongs in higher-level view/ui layers
