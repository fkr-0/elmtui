;;; ===============================================================
;;; File: tests/geo-tests.lisp
;;; Comprehensive Unit Tests for elmtui.view.geo
;;; ===============================================================
(uiop:define-package :elmtui.tests.geo
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo
    ;; Struct type symbols
    #:size #:pos #:rectangle
    ;; Struct constructors and accessors
    #:make-size #:make-pos #:make-rectangle
    #:size-p #:pos-p #:rectangle-p
    #:size-w #:size-h #:pos-x #:pos-y
    #:rectangle-size #:rectangle-pos
    ;; Generic functions
    #:=? #:area #:area< #:valid-p
    #:w #:h #:x #:y #:x2 #:y2
    #:dim #:dim-pos #:dim-length
    ;; Operations
    #:move! #:dx #:dy #:dx! #:dy!
    #:rectangle-union #:rectangle-union-list
    #:overlap #:contains-p
    #:normalize!
    #:resize-dimension! #:shrink-view! #:grow-view!
    #:corner #:line #:rect-diff
    #:border
    #:difference #:rectangle-between
    #:clamp)
  (:export #:geo-tests))

(in-package :elmtui.tests.geo)

(def-suite geo-tests
  :in elmtui.tests:elmtui-test
  :description "Comprehensive tests for geometric primitives (geo.lisp)")

(in-suite geo-tests)

;;;=============================================================================
;;; Struct Constructor and Predicate Tests
;;;=============================================================================

(test size-creation
  "Test size struct creation and predicates"
  ;; Default constructor
  (let ((s (make-size)))
    (is-true (size-p s))
    (is (= 0 (size-w s)))
    (is (= 0 (size-h s))))
  ;; With values
  (let ((s (make-size :w 10 :h 20)))
    (is-true (size-p s))
    (is (= 10 (size-w s)))
    (is (= 20 (size-h s)))))

(test pos-creation
  "Test pos struct creation and predicates"
  ;; Default constructor
  (let ((p (make-pos)))
    (is-true (pos-p p))
    (is (= 0 (pos-x p)))
    (is (= 0 (pos-y p))))
  ;; With values
  (let ((p (make-pos :x 5 :y 10)))
    (is-true (pos-p p))
    (is (= 5 (pos-x p)))
    (is (= 10 (pos-y p)))))

(test rectangle-creation
  "Test rectangle struct creation and predicates"
  ;; Default constructor
  (let ((r (make-rectangle)))
    (is-true (rectangle-p r))
    (is (= 0 (x r)))
    (is (= 0 (y r)))
    (is (= 0 (w r)))
    (is (= 0 (h r))))
  ;; With pos and size
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10)
             :size (make-size :w 20 :h 30))))
    (is-true (rectangle-p r))
    (is (= 5 (x r)))
    (is (= 10 (y r)))
    (is (= 20 (w r)))
    (is (= 30 (h r)))))

;;;=============================================================================
;;; Equality (=?) Tests
;;;=============================================================================

(test equality-default
  "Test default equality behavior"
  (is-true (=? t t))
  (is-false (=? t nil))
  (is-true (=? "hello" "hello"))
  (is-false (=? "hello" "world"))
  (is-true (=? 42 42))
  (is-false (=? 42 43)))

(test equality-symbols
  "Test symbol equality"
  (is-true (=? 'foo 'foo))
  (is-false (=? 'foo 'bar))
  (is-true (=? :x :x))
  (is-false (=? :x :y)))

(test equality-lists
  "Test list equality with =?"
  (is-true (=? '(1 2 3) '(1 2 3)))
  (is-false (=? '(1 2 3) '(1 2 4)))
  (is-false (=? '(1 2) '(1 2 3)))  ; Different lengths
  ;; Nested lists
  (is-true (=? '((1 2) (3 4)) '((1 2) (3 4))))
  (is-false (=? '((1 2) (3 4)) '((1 2) (3 5)))))

(test equality-pos
  "Test pos equality"
  (let ((p1 (make-pos :x 5 :y 10))
         (p2 (make-pos :x 5 :y 10))
         (p3 (make-pos :x 5 :y 11)))
    (is-true (=? p1 p2))
    (is-false (=? p1 p3))))

(test equality-size
  "Test size equality"
  (let ((s1 (make-size :w 10 :h 20))
         (s2 (make-size :w 10 :h 20))
         (s3 (make-size :w 11 :h 20)))
    (is-true (=? s1 s2))
    (is-false (=? s1 s3))))

(test equality-rectangle
  "Test rectangle equality"
  (let ((r1 (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30)))
         (r3 (make-rectangle :pos (make-pos :x 6 :y 10) :size (make-size :w 20 :h 30))))
    (is-true (=? r1 r2))
    (is-false (=? r1 r3))))

;;;=============================================================================
;;; Accessor Tests (w, h, x, y)
;;;=============================================================================

(test accessor-size
  "Test size accessor generic"
  (let ((s (make-size :w 10 :h 20)))
    (is (= 10 (w s)))
    (is (= 20 (h s)))))

(test accessor-pos
  "Test pos accessor generic"
  (let ((p (make-pos :x 5 :y 10)))
    (is (= 5 (x p)))
    (is (= 10 (y p)))))

(test accessor-rectangle
  "Test rectangle accessor generics"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    ;; Direct accessors
    (is (= 5 (x r)))
    (is (= 10 (y r)))
    (is (= 20 (w r)))
    (is (= 30 (h r)))
    ;; Via pos/size
    (is-true (pos-p (pos r)))
    (is-true (size-p (size r)))
    (is (= 5 (x (pos r))))
    (is (= 10 (y (pos r))))
    (is (= 20 (w (size r))))
    (is (= 30 (h (size r))))))

(test accessor-list
  "Test list accessor methods for 2-element and 4-element lists"
  ;; 2-element list as position (x y)
  (is (= 3 (x '(3 4))))
  (is (= 4 (y '(3 4))))
  ;; 4-element list as rectangle (x y w h)
  (is (= 5 (x '(5 10 15 20))))
  (is (= 10 (y '(5 10 15 20))))
  (is (= 15 (w '(5 10 15 20))))
  (is (= 20 (h '(5 10 15 20))))
  ;; Invalid lists should signal errors
  (signals error (x '(1)))      ; Too short
  (signals error (x '(1 2 3))) ; Wrong length for x/y
  (signals error (w '(1 2 3)))) ; Wrong length for w/h

(test accessor-calculated
  "Test calculated accessors x2 and y2"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (is (= 25 (x2 r)))  ; 5 + 20
    (is (= 40 (y2 r))))) ; 10 + 30

;;;=============================================================================
;;; Area Tests
;;;=============================================================================

(test area-size
  "Test area calculation for size"
  (is (= 0 (area (make-size :w 0 :h 0))))
  (is (= 6 (area (make-size :w 2 :h 3))))
  (is (= 100 (area (make-size :w 10 :h 10)))))

(test area-rectangle
  "Test area calculation for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 3 :h 4))))
    (is (= 12 (area r)))))  ; 3 * 4

(test area-comparison
  "Test area< generic function"
  (let ((s1 (make-size :w 2 :h 3))
         (s2 (make-size :w 3 :h 4))
         (r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 5 :h 5)))
         (r2 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10))))
    (is-true (area< s1 s2))   ; 6 < 12
    (is-false (area< s2 s1))
    (is-true (area< r1 r2))  ; 25 < 100
    (is-false (area< r2 r1))))

;;;=============================================================================
;;; Valid-p Tests
;;;=============================================================================

(test valid-p-size
  "Test validity check for size"
  (is-true (valid-p (make-size :w 0 :h 0)))
  (is-true (valid-p (make-size :w 10 :h 20))))

(test valid-p-rectangle
  "Test validity check for rectangle"
  (is-true (valid-p (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))))

;;;=============================================================================
;;; Dim Accessor Tests
;;;=============================================================================

(test dim-pos
  "Test dim accessor for pos"
  (let ((p (make-pos :x 5 :y 10)))
    (is (= 5 (dim p :x)))
    (is (= 10 (dim p :y)))
    (is (= 5 (dim p 0)))   ; 0 as x
    (is (= 10 (dim p 1)))  ; 1 as y
    (signals error (dim p :w))
    (signals error (dim p 2))))

(test dim-size
  "Test dim accessor for size"
  (let ((s (make-size :w 15 :h 25)))
    (is (= 15 (dim s :w)))
    (is (= 25 (dim s :h)))
    ;; Aliases work
    (is (= 15 (dim s :x)))  ; :x is alias for :w on size
    (is (= 25 (dim s :y)))  ; :y is alias for :h on size
    (is (= 15 (dim s 0)))
    (is (= 25 (dim s 1)))))

(test dim-rectangle
  "Test dim accessor for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (is (= 5 (dim r :x)))
    (is (= 10 (dim r :y)))
    (is (= 20 (dim r :w)))
    (is (= 30 (dim r :h)))
    (is (= 5 (dim r 0)))
    (is (= 10 (dim r 1)))))

(test dim-pos-rectangle
  "Test dim-pos for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (is (= 5 (dim-pos r :x)))
    (is (= 10 (dim-pos r :y)))))

(test dim-length-rectangle
  "Test dim-length for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (is (= 20 (dim-length r :w)))
    (is (= 30 (dim-length r :h)))))

;;;=============================================================================
;;; Setf Accessor Tests
;;;=============================================================================

(test setf-dim-pos
  "Test setf dim for pos"
  (let ((p (make-pos :x 5 :y 10)))
    (setf (dim p :x) 15)
    (is (= 15 (pos-x p)))
    (setf (dim p :y) 20)
    (is (= 20 (pos-y p)))
    (setf (dim p 0) 25)
    (is (= 25 (pos-x p)))
    (setf (dim p 1) 30)
    (is (= 30 (pos-y p)))))

(test setf-dim-size
  "Test setf dim for size"
  (let ((s (make-size :w 10 :h 20)))
    (setf (dim s :w) 15)
    (is (= 15 (size-w s)))
    (setf (dim s :h) 25)
    (is (= 25 (size-h s)))))

(test setf-dim-rectangle
  "Test setf dim for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (setf (dim r :x) 100)
    (is (= 100 (x r)))
    (setf (dim r :y) 200)
    (is (= 200 (y r)))
    (setf (dim r :w) 50)
    (is (= 50 (w r)))
    (setf (dim r :h) 60)
    (is (= 60 (h r)))))

(test setf-accessors
  "Test setf accessors w, h, x, y"
  (let ((p (make-pos :x 5 :y 10))
         (s (make-size :w 20 :h 30))
         (r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    ;; Pos
    (setf (x p) 15)
    (setf (y p) 25)
    (is (= 15 (pos-x p)))
    (is (= 25 (pos-y p)))
    ;; Size
    (setf (w s) 35)
    (setf (h s) 45)
    (is (= 35 (size-w s)))
    (is (= 45 (size-h s)))
    ;; Rectangle
    (setf (x r) 10)
    (setf (y r) 20)
    (setf (w r) 30)
    (setf (h r) 40)
    (is (= 10 (x r)))
    (is (= 20 (y r)))
    (is (= 30 (w r)))
    (is (= 40 (h r)))))

;;;=============================================================================
;;; Delta Operation Tests (Non-mutating)
;;;=============================================================================

(test dx-pos
  "Test horizontal delta on pos (non-mutating)"
  (let ((p (make-pos :x 5 :y 10)))
    (let ((result (dx p 3)))
      (is-true (pos-p result))
      (is (= 8 (x result)))   ; 5 + 3
      (is (= 10 (y result)))  ; y unchanged
      (is (= 5 (x p)))        ; original unchanged
      (is (= 10 (y p))))))

(test dy-pos
  "Test vertical delta on pos (non-mutating)"
  (let ((p (make-pos :x 5 :y 10)))
    (let ((result (dy p 3)))
      (is-true (pos-p result))
      (is (= 5 (x result)))   ; x unchanged
      (is (= 13 (y result)))  ; 10 + 3
      (is (= 5 (x p)))        ; original unchanged
      (is (= 10 (y p))))))

(test dx-rectangle
  "Test horizontal delta on rectangle (non-mutating)"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (dx r 3)))
      (is-true (rectangle-p result))
      (is (= 8 (x result)))   ; 5 + 3
      (is (= 10 (y result)))
      (is (= 20 (w result)))
      (is (= 30 (h result)))
      (is (= 5 (x r)))        ; original unchanged
      (is (= 10 (y r))))))

(test dy-rectangle
  "Test vertical delta on rectangle (non-mutating)"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (dy r 3)))
      (is-true (rectangle-p result))
      (is (= 5 (x result)))
      (is (= 13 (y result)))  ; 10 + 3
      (is (= 20 (w result)))
      (is (= 30 (h result))))))

(test negative-deltas
  "Test negative delta values"
  (let ((p (make-pos :x 10 :y 10)))
    (let ((result (dx p -3)))
      (is (= 7 (x result))))
    (let ((result (dy p -3)))
      (is (= 7 (y result))))))

;;;=============================================================================
;;; Delta Operation Tests (Mutating)
;;;=============================================================================

(test dx!-pos
  "Test horizontal delta on pos (mutating)"
  (let ((p (make-pos :x 5 :y 10)))
    (let ((result (dx! p 3)))
      (is (= 8 (pos-x p)))    ; mutated
      (is (= 10 (pos-y p)))
      (is (eq p result)))))   ; returns same object

(test dy!-pos
  "Test vertical delta on pos (mutating)"
  (let ((p (make-pos :x 5 :y 10)))
    (let ((result (dy! p 3)))
      (is (= 5 (pos-x p)))
      (is (= 13 (pos-y p)))   ; mutated
      (is (eq p result)))))

(test dx!-dy!-rectangle
  "Test delta operations on rectangle (mutating)"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (dx! r 3)
    (is (= 8 (x r)))
    (dy! r 5)
    (is (= 15 (y r)))
    (is (= 20 (w r)))
    (is (= 30 (h r)))))

;;;=============================================================================
;;; Move! Tests
;;;=============================================================================

(test move!-pos-absolute
  "Test move! with absolute positioning"
  (let ((p (make-pos :x 5 :y 10)))
    (move! p :x 20 :y 30)
    (is (= 20 (pos-x p)))
    (is (= 30 (pos-y p)))))

(test move!-pos-relative
  "Test move! with relative positioning"
  (let ((p (make-pos :x 5 :y 10)))
    (move! p :dx 3 :dy 7)
    (is (= 8 (pos-x p)))   ; 5 + 3
    (is (= 17 (pos-y p))))) ; 10 + 7

(test move!-pos-combined
  "Test move! with both absolute and relative positioning"
  (let ((p (make-pos :x 5 :y 10)))
    (move! p :x 20 :dy 5)
    (is (= 20 (pos-x p)))   ; absolute
    (is (= 15 (pos-y p))))) ; 10 + 5

(test move!-rectangle
  "Test move! on rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (move! r :x 100 :y 200)
    (is (= 100 (x r)))
    (is (= 200 (y r)))
    (is (= 20 (w r)))      ; size unchanged
    (is (= 30 (h r))))
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (move! r :dx 10 :dy 15)
    (is (= 15 (x r)))      ; 5 + 10
    (is (= 25 (y r)))      ; 10 + 15
    (is (= 20 (w r)))      ; size unchanged
    (is (= 30 (h r)))))

;;;=============================================================================
;;; Difference Tests
;;;=============================================================================

(test difference-pos
  "Test difference between two positions"
  (let ((p1 (make-pos :x 10 :y 20))
         (p2 (make-pos :x 3 :y 5)))
    (let ((result (difference p1 p2)))
      (is-true (pos-p result))
      (is (= 7 (x result)))   ; 10 - 3
      (is (= 15 (y result)))))) ; 20 - 5

;;;=============================================================================
;;; Rectangle Between Tests
;;;=============================================================================

(test rectangle-between
  "Test rectangle created between two positions"
  (let ((p1 (make-pos :x 10 :y 20))
         (p2 (make-pos :x 30 :y 50)))
    (let ((result (rectangle-between p1 p2)))
      (is-true (rectangle-p result))
      (is (= 10 (x result)))   ; min x
      (is (= 20 (y result)))   ; min y
      (is (= 20 (w result)))   ; 30 - 10
      (is (= 30 (h result)))))) ; 50 - 20

(test rectangle-between-reversed
  "Test rectangle between with reversed points"
  (let ((p1 (make-pos :x 30 :y 50))
         (p2 (make-pos :x 10 :y 20)))
    (let ((result (rectangle-between p1 p2)))
      (is-true (rectangle-p result))
      (is (= 10 (x result)))   ; min x
      (is (= 20 (y result)))   ; min y
      (is (= 20 (w result)))   ; 30 - 10
      (is (= 30 (h result)))))) ; 50 - 20

;;;=============================================================================
;;; Rectangle Union Tests
;;;=============================================================================

(test rectangle-union-overlapping
  "Test union of overlapping rectangles"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10))))
    (let ((result (rectangle-union r1 r2)))
      (is-true (rectangle-p result))
      (is (= 0 (x result)))    ; min x
      (is (= 0 (y result)))    ; min y
      (is (= 15 (w result)))   ; 15 = max(10, 15) - 0
      (is (= 15 (h result)))))) ; 15 = max(10, 15) - 0

(test rectangle-union-disjoint
  "Test union of disjoint rectangles"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 5 :h 5)))
         (r2 (make-rectangle :pos (make-pos :x 20 :y 20) :size (make-size :w 5 :h 5))))
    (let ((result (rectangle-union r1 r2)))
      (is-true (rectangle-p result))
      (is (= 0 (x result)))
      (is (= 0 (y result)))
      (is (= 25 (w result)))   ; 25 - 0
      (is (= 25 (h result)))))) ; 25 - 0

(test rectangle-union-list
  "Test union of list of rectangles"
  (let ((rects (list (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10))
                 (make-rectangle :pos (make-pos :x 20 :y 0) :size (make-size :w 10 :h 10))
                 (make-rectangle :pos (make-pos :x 10 :y 0) :size (make-size :w 10 :h 10)))))
    (let ((result (rectangle-union-list rects)))
      (is-true (rectangle-p result))
      (is (= 0 (x result)))
      (is (= 0 (y result)))
      (is (= 30 (w result)))   ; 30 - 0
      (is (= 10 (h result)))))
  ;; Single rectangle returns itself
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10))))
    (is (eq r (rectangle-union-list r)))))

;;;=============================================================================
;;; Overlap Tests
;;;=============================================================================

(test overlap-overlapping
  "Test overlap of overlapping rectangles"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10))))
    (let ((result (overlap r1 r2)))
      (is-true (rectangle-p result))
      (is (= 5 (x result)))    ; max(0, 5)
      (is (= 5 (y result)))    ; max(0, 5)
      (is (= 5 (w result)))    ; min(10, 15) - 5
      (is (= 5 (h result)))))) ; min(10, 15) - 5

(test overlap-adjacent
  "Test overlap of adjacent rectangles (should be nil)"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))
         (r2 (make-rectangle :pos (make-pos :x 10 :y 0) :size (make-size :w 10 :h 10))))
    (is-false (overlap r1 r2)))  ; Touching but not overlapping
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))
         (r2 (make-rectangle :pos (make-pos :x 0 :y 10) :size (make-size :w 10 :h 10))))
    (is-false (overlap r1 r2)))) ; Touching but not overlapping

(test overlap-disjoint
  "Test overlap of disjoint rectangles"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 5 :h 5)))
         (r2 (make-rectangle :pos (make-pos :x 20 :y 20) :size (make-size :w 5 :h 5))))
    (is-false (overlap r1 r2))))

(test overlap-containing
  "Test overlap when one rectangle contains another"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 20 :h 20)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10))))
    (let ((result (overlap r1 r2)))
      (is-true (rectangle-p result))
      ;; The overlap should be r2
      (is (= 5 (x result)))
      (is (= 5 (y result)))
      (is (= 10 (w result)))
      (is (= 10 (h result))))))

;;;=============================================================================
;;; Contains-p Tests
;;;=============================================================================

(test contains-point
  "Test if rectangle contains a position"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    ;; Point inside
    (is-true (contains-p r (make-pos :x 15 :y 15)))
    ;; Point at top-left corner (inside)
    (is-true (contains-p r (make-pos :x 10 :y 10)))
    ;; Point at bottom-right corner (outside - exclusive upper bound)
    (is-false (contains-p r (make-pos :x 30 :y 30)))
    ;; Point outside
    (is-false (contains-p r (make-pos :x 5 :y 5)))
    (is-false (contains-p r (make-pos :x 35 :y 35)))))

(test contains-point-list
  "Test if rectangle contains a point as a list"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (is-true (contains-p r '(15 15)))
    (is-false (contains-p r '(35 35)))
    ;; Invalid lists return nil (graceful failure)
    (is-false (contains-p r '(1)))      ; Invalid list length
    (is-false (contains-p r '(1 2 3)))  ; Invalid list length
    (is-false (contains-p r '("a" "b"))))) ; Non-numeric values

(test contains-rectangle
  "Test if one rectangle contains another"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 20 :h 20)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10)))
         (r3 (make-rectangle :pos (make-pos :x 15 :y 15) :size (make-size :w 10 :h 10))))
    (is-true (contains-p r1 r2))   ; r1 contains r2
    (is-false (contains-p r1 r3))  ; r1 doesn't fully contain r3
    (is-false (contains-p r2 r1)))) ; r2 doesn't contain r1

;;;=============================================================================
;;; Normalize! Tests
;;;=============================================================================

(test normalize-positive
  "Test normalize! with positive dimensions (no change)"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (normalize! r)))
      (is (= 5 (x r)))
      (is (= 10 (y r)))
      (is (= 20 (w r)))
      (is (= 30 (h r)))
      (is (eq r result)))))

;; NOTE: Tests for negative dimensions are skipped because the struct definition
;; enforces (integer 0 *) type constraints. The normalize! function exists for
;; edge cases but cannot be tested with negative dimensions directly through
;; the standard constructor.

;;;=============================================================================
;;; Resize Dimension Tests
;;;=============================================================================

(test resize-dimension-right
  "Test resize-dimension! on right side"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (resize-dimension! r :side :right :amount 5)
    (is (= 5 (x r)))
    (is (= 25 (w r))))) ; 20 + 5

(test resize-dimension-left
  "Test resize-dimension! on left side"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (resize-dimension! r :side :left :amount 5)
    (is (= 10 (x r)))   ; 5 + 5
    (is (= 15 (w r)))))  ; 20 - 5

(test resize-dimension-bottom
  "Test resize-dimension! on bottom side"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (resize-dimension! r :side :bottom :amount 5)
    (is (= 10 (y r)))
    (is (= 35 (h r)))))  ; 30 + 5

(test resize-dimension-top
  "Test resize-dimension! on top side"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (resize-dimension! r :side :top :amount 5)
    (is (= 15 (y r)))   ; 10 + 5
    (is (= 25 (h r)))))  ; 30 - 5

(test resize-dimension-negative-amount
  "Test resize-dimension! with negative amount (should error)"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (signals error (resize-dimension! r :side :left :amount 25))   ; Would make w negative
    (signals error (resize-dimension! r :side :top :amount 35))))  ; Would make h negative

;;;=============================================================================
;;; Shrink/Grow View Tests
;;;=============================================================================

(test shrink-view
  "Test shrink-view! reduces rectangle size"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (shrink-view! r :side :right :amount 5)
    (is (= 5 (x r)))
    (is (= 15 (w r)))))  ; 20 - 5

(test grow-view
  "Test grow-view! increases rectangle size"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (grow-view! r :side :right :amount 5)
    (is (= 5 (x r)))
    (is (= 25 (w r)))))  ; 20 + 5

;;;=============================================================================
;;; Corner Tests
;;;=============================================================================

(test corner-top-left
  "Test getting top-left corner"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (corner r :top-left)))
      (is-true (pos-p result))
      (is (= 5 (x result)))
      (is (= 10 (y result))))))

(test corner-top-right
  "Test getting top-right corner"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (corner r :top-right)))
      (is-true (pos-p result))
      (is (= 25 (x result)))  ; 5 + 20
      (is (= 10 (y result))))))

(test corner-bottom-left
  "Test getting bottom-left corner"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (corner r :bottom-left)))
      (is-true (pos-p result))
      (is (= 5 (x result)))
      (is (= 40 (y result)))))) ; 10 + 30

(test corner-bottom-right
  "Test getting bottom-right corner"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((result (corner r :bottom-right)))
      (is-true (pos-p result))
      (is (= 25 (x result)))  ; 5 + 20
      (is (= 40 (y result)))))) ; 10 + 30

(test corner-invalid
  "Test corner with invalid keyword"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (signals error (corner r :invalid))))

;;;=============================================================================
;;; Line Tests
;;;=============================================================================

(test line-horizontal
  "Test creating horizontal line"
  (let ((p1 (make-pos :x 5 :y 10))
         (p2 (make-pos :x 15 :y 10)))
    (let ((result (line p1 p2)))
      (is-true (rectangle-p result))
      (is (= 5 (x result)))    ; min x
      (is (= 10 (y result)))
      (is (= 11 (w result)))   ; |15-5|+1 = 11
      (is (= 1 (h result)))))) ; Height 1 for horizontal

(test line-vertical
  "Test creating vertical line"
  (let ((p1 (make-pos :x 10 :y 5))
         (p2 (make-pos :x 10 :y 15)))
    (let ((result (line p1 p2)))
      (is-true (rectangle-p result))
      (is (= 10 (x result)))
      (is (= 5 (y result)))    ; min y
      (is (= 1 (w result)))    ; Width 1 for vertical
      (is (= 11 (h result)))))) ; |15-5|+1 = 11

(test line-diagonal-error
  "Test that diagonal line signals error"
  (let ((p1 (make-pos :x 0 :y 0))
         (p2 (make-pos :x 10 :y 10)))
    (signals error (line p1 p2))))

;;;=============================================================================
;;; Rect Diff Tests
;;;=============================================================================

(test rect-diff-no-overlap
  "Test rect-diff with no overlap"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10)))
         (r2 (make-rectangle :pos (make-pos :x 20 :y 20) :size (make-size :w 10 :h 10))))
    (let ((result (rect-diff r1 r2)))
      (is (= 1 (length result)))
      (is-true (rectangle-p (first result)))
      (is (= 0 (x (first result))))
      (is (= 0 (y (first result))))
      (is (= 10 (w (first result))))
      (is (= 10 (h (first result)))))))

(test rect-diff-full-overlap
  "Test rect-diff with full overlap (same rect)"
  (let ((r (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 10 :h 10))))
    (let ((result (rect-diff r r)))
      ;; No difference since r2 covers r1 completely
      (is (= 0 (length result))))))

(test rect-diff-partial-overlap
  "Test rect-diff with partial overlap"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 20 :h 20)))
         (r2 (make-rectangle :pos (make-pos :x 5 :y 5) :size (make-size :w 10 :h 10))))
    (let ((result (rect-diff r1 r2)))
      ;; Should return 4 rectangles (top, bottom, left, right of overlap)
      (is (= 4 (length result)))
      (is (every #'rectangle-p result)))))

(test rect-diff-center-hole
  "Test rect-diff creating a hole in center"
  (let ((r1 (make-rectangle :pos (make-pos :x 0 :y 0) :size (make-size :w 30 :h 30)))
         (r2 (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 10 :h 10))))
    (let ((result (rect-diff r1 r2)))
      (is (= 4 (length result)))
      ;; Check that each result is valid
      (is (every #'valid-p result)))))

;;;=============================================================================
;;; Border Tests
;;;=============================================================================

(test border-all
  "Test getting all borders"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (let ((result (border r :side :all :width 2)))
      (is (= 4 (length result)))
      (is (every #'rectangle-p result)))))

(test border-top
  "Test getting top border"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (let ((result (border r :side :top :width 2)))
      (is (= 1 (length result)))
      (is-true (rectangle-p (first result)))
      (is (= 10 (x (first result))))
      (is (= 10 (y (first result))))
      (is (= 20 (w (first result))))
      (is (= 2 (h (first result)))))))

(test border-bottom
  "Test getting bottom border"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (let ((result (border r :side :bottom :width 2)))
      (is (= 1 (length result)))
      (is-true (rectangle-p (first result)))
      ;; y should be 30 - 2 = 28 (y + h - width)
      (is (= 28 (y (first result))))
      (is (= 20 (w (first result))))
      (is (= 2 (h (first result)))))))

(test border-left
  "Test getting left border"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (let ((result (border r :side :left :width 2)))
      (is (= 1 (length result)))
      (is-true (rectangle-p (first result)))
      (is (= 10 (x (first result))))
      (is (= 10 (y (first result))))
      (is (= 2 (w (first result))))
      (is (= 20 (h (first result)))))))

(test border-right
  "Test getting right border"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (let ((result (border r :side :right :width 2)))
      (is (= 1 (length result)))
      (is-true (rectangle-p (first result)))
      ;; x should be 30 - 2 = 28 (x + w - width)
      (is (= 28 (x (first result))))
      (is (= 10 (y (first result))))
      (is (= 2 (w (first result))))
      (is (= 20 (h (first result)))))))

(test border-invalid-side
  "Test border with invalid side"
  (let ((r (make-rectangle :pos (make-pos :x 10 :y 10) :size (make-size :w 20 :h 20))))
    (signals error (border r :side :invalid))))

;;;=============================================================================
;;; Clamp Function Tests
;;;=============================================================================

(test clamp-within-range
  "Test clamp with value within range"
  (is (= 5 (clamp 5 0 10)))
  (is (= 0 (clamp 0 0 10)))
  (is (= 10 (clamp 10 0 10))))

(test clamp-below-range
  "Test clamp with value below range"
  (is (= 0 (clamp -5 0 10)))
  (is (= 10 (clamp 5 10 20))))

(test clamp-above-range
  "Test clamp with value above range"
  (is (= 10 (clamp 15 0 10)))
  (is (= 20 (clamp 25 10 20))))

(test clamp-invalid-range
  "Test clamp with min > max (should error)"
  (signals error (clamp 5 10 0)))

;;;=============================================================================
;;; Setf Dim-Pos and Dim-Length Tests
;;;=============================================================================

(test setf-dim-pos-rectangle
  "Test setf dim-pos for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (setf (dim-pos r :x) 100)
    (is (= 100 (x r)))
    (setf (dim-pos r :y) 200)
    (is (= 200 (y r)))))

(test setf-dim-length-rectangle
  "Test setf dim-length for rectangle"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (setf (dim-length r :w) 50)
    (is (= 50 (w r)))
    (setf (dim-length r :h) 60)
    (is (= 60 (h r)))))

;;;=============================================================================
;;; Print Object Tests
;;;=============================================================================

(test print-object-pos
  "Test printing a pos object"
  (let ((p (make-pos :x 5 :y 10)))
    (let ((output (write-to-string p)))
      (is-true (search "POS" output))
      (is-true (search "5" output))
      (is-true (search "10" output)))))

(test print-object-size
  "Test printing a size object"
  (let ((s (make-size :w 20 :h 30)))
    (let ((output (write-to-string s)))
      (is-true (search "SIZE" output))
      (is-true (search "20" output))
      (is-true (search "30" output)))))

(test print-object-rectangle
  "Test printing a rectangle object"
  (let ((r (make-rectangle :pos (make-pos :x 5 :y 10) :size (make-size :w 20 :h 30))))
    (let ((output (write-to-string r)))
      (is-true (search "RECTANGLE" output))
      (is-true (search "Pos" output))
      (is-true (search "Size" output)))))

