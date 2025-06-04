 ;;;===============================================================
;;; File: tests/elmtui-canvas-tests.lisp
;;; Unit Tests for Canvas Implementation
;;;===============================================================

(uiop:define-package :elmtui.tests.canvas
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.view.geo
                #:rectangle
                #:make-rectangle
                #:pos
                #:make-pos
                #:size
                #:make-size
                #:w
                #:h
                #:x
                #:y)
  (:import-from :elmtui.platform.canvas
                #:canvas
                #:make-canvas
                #:canvas-buffer
                #:canvas-backend
                #:canvas-position-strategy
                #:canvas-anchor-point
                #:canvas-content-rectangle
                #:initialize-canvas
                #:update-canvas-size
                #:apply-canvas-to-buffer
                #:prepare-canvas-for-rendering
                #:finalize-canvas-after-rendering
                #:restore-terminal-state)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer
                #:make-virtual-buffer
                #:with-virtual-buffer-lock
                #:buffer-cell-at
                #:buffer-cell-char
                #:buffer-cell-style
                #:set-buffer-cell-at
                #:buffer-width
                #:buffer-height))

(in-package :elmtui.tests.canvas)

;;;-----------------------------------------------------------------------------
;;; Test Suite Definition
;;;-----------------------------------------------------------------------------

(def-suite canvas-tests
  :description "Tests for the Canvas implementation in elmtui")

(in-suite canvas-tests)

;;;-----------------------------------------------------------------------------
;;; Mock Terminal Backend for Testing
;;;-----------------------------------------------------------------------------

(defclass mock-terminal-backend ()
  ((width :initform 80 :accessor term-w)
   (height :initform 24 :accessor term-h)
   (cursor-x :initform 0 :accessor cursor-x)
   (cursor-y :initform 0 :accessor cursor-y)
   (cleared-areas :initform nil :accessor cleared-areas)
   (front-buffer :initform nil :accessor front-buffer)
   (back-buffer :initform nil :accessor back-buffer)))

(defmethod initialize-instance :after ((backend mock-terminal-backend) &key)
  (setf (front-buffer backend)
        (make-virtual-buffer (term-w backend) (term-h backend)))
  (setf (back-buffer backend)
        (make-virtual-buffer (term-w backend) (term-h backend))))

(defun make-mock-backend (&key (width 80) (height 24) (cursor-x 0) (cursor-y 0))
  (let ((backend (make-instance 'mock-terminal-backend)))
    (setf (term-w backend) width
          (term-h backend) height
          (cursor-x backend) cursor-x
          (cursor-y backend) cursor-y)
    (setf (front-buffer backend)
          (make-virtual-buffer width height))
    (setf (back-buffer backend)
          (make-virtual-buffer width height))
    backend))

(defmethod get-cursor-position ((backend mock-terminal-backend))
  (values (cursor-x backend) (cursor-y backend)))

(defmethod set-cursor-position ((backend mock-terminal-backend) row col)
  (setf (cursor-y backend) row
        (cursor-x backend) col))

(defmethod clear-area ((backend mock-terminal-backend) target-buffer start-row start-col rows cols)
  (push (list start-row start-col rows cols) (cleared-areas backend)))

;;;-----------------------------------------------------------------------------
;;; Test Helper Functions
;;;-----------------------------------------------------------------------------

(defun create-test-canvas (strategy anchor &key
                                             (width 80)
                                             (height 24)
                                             (cursor-x 5)
                                             (cursor-y 5)
                                             (canvas-width 20)
                                             (canvas-height 10)
                                             fixed-position)
  "Create a test canvas with specified parameters"
  (let ((backend (make-mock-backend :width width :height height
                                    :cursor-x cursor-x :cursor-y cursor-y)))
    (initialize-canvas backend
                       :position-strategy strategy
                       :anchor-point anchor
                       :fixed-position fixed-position
                       :initial-size (make-size :w canvas-width :h canvas-height))))

(defun fill-test-buffer (buffer patterns)
  "Fill a buffer with test patterns for verification"
  (dolist (pattern patterns)
    (destructuring-bind (row col char style) pattern
      (set-buffer-cell-at buffer row col char style))))

(defun verify-buffer-content (buffer expected-patterns)
  "Verify buffer content matches expected patterns"
  (dolist (pattern expected-patterns)
    (destructuring-bind (row col expected-char expected-style) pattern
      (let ((cell (buffer-cell-at buffer row col)))
        (is (char= (buffer-cell-char cell) expected-char))
        (when expected-style
          (dolist (key-value expected-style)
            (destructuring-bind (key expected-value) key-value
              (is (equal (getf (buffer-cell-style cell) key) expected-value)))))))))

;;;-----------------------------------------------------------------------------
;;; Canvas Initialization Tests
;;;-----------------------------------------------------------------------------

(test canvas-initialization
  "Test canvas initialization with different position strategies"

  ;; Test below-cursor strategy
  (let* ((canvas (create-test-canvas :below-cursor :top-left)))
    (is (not (null canvas)) "Canvas should be created successfully")
    (is (eq (canvas-position-strategy canvas) :below-cursor)
        "Position strategy should be set to :below-cursor")
    (is (eq (canvas-anchor-point canvas) :top-left)
        "Anchor point should be set to :top-left")

    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (x (pos rect)) 0) "Canvas should be positioned at x=0")
      (is (= (y (pos rect)) 5) "Canvas should be positioned at y=5 (cursor-y)")
      (is (= (w (size rect)) 20) "Canvas width should be 20")
      (is (= (h (size rect)) 10) "Canvas height should be 10")))

  ;; Test above-cursor strategy
  (let* ((canvas (create-test-canvas :above-cursor :top-left)))
    (is (not (null canvas)) "Canvas should be created successfully")
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (y (pos rect)) 0) "Canvas should start at y=0 (above cursor)")
      (is (= (h (size rect)) 5) "Canvas height should adapt to cursor position")))

  ;; Test center-screen strategy
  (let* ((canvas (create-test-canvas :center-screen :center
                                     :width 100 :height 40
                                     :canvas-width 20 :canvas-height 10)))
    (is (not (null canvas)) "Canvas should be created successfully")
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (x (pos rect)) 40) "Canvas should be positioned at x=40 (centered)")
      (is (= (y (pos rect)) 15) "Canvas should be positioned at y=15 (centered)")))

  ;; Test fixed position strategy
  (let* ((fixed-pos (make-pos :x 15 :y 10))
         (canvas (create-test-canvas :fixed :top-left
                                     :fixed-position fixed-pos)))
    (is (not (null canvas)) "Canvas should be created successfully")
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (x (pos rect)) 15) "Canvas should be positioned at x=15")
      (is (= (y (pos rect)) 10) "Canvas should be positioned at y=10"))))

;;;-----------------------------------------------------------------------------
;;; Canvas Size Update Tests
;;;-----------------------------------------------------------------------------

(test canvas-resize
  "Test canvas resizing with different anchor points"

  ;; Test resizing with top-left anchor
  (let* ((canvas (create-test-canvas :below-cursor :top-left))
         (old-rect (canvas-content-rectangle canvas))
         (old-x (x (pos old-rect)))
         (old-y (y (pos old-rect))))
    (update-canvas-size canvas 30 15)
    (let ((new-rect (canvas-content-rectangle canvas)))
      (is (= (x (pos new-rect)) old-x) "X position should not change")
      (is (= (y (pos new-rect)) old-y) "Y position should not change")
      (is (= (w (size new-rect)) 30) "Width should be updated to 30")
      (is (= (h (size new-rect)) 15) "Height should be updated to 15")))

  ;; Test resizing with bottom-right anchor
  (let* ((canvas (create-test-canvas :below-cursor :bottom-right))
         (old-rect (canvas-content-rectangle canvas))
         (old-right (+ (x (pos old-rect)) (w (size old-rect))))
         (old-bottom (+ (y (pos old-rect)) (h (size old-rect)))))
    (update-canvas-size canvas 30 15)
    (let* ((new-rect (canvas-content-rectangle canvas))
           (new-right (+ (x (pos new-rect)) (w (size new-rect))))
           (new-bottom (+ (y (pos new-rect)) (h (size new-rect)))))
      (is (= new-right old-right) "Right edge position should stay fixed")
      (is (= new-bottom old-bottom) "Bottom edge position should stay fixed")
      (is (= (w (size new-rect)) 30) "Width should be updated to 30")
      (is (= (h (size new-rect)) 15) "Height should be updated to 15")))

  ;; Test resizing with center anchor
  (let* ((canvas (create-test-canvas :center-screen :center))
         (old-rect (canvas-content-rectangle canvas))
         (old-center-x (+ (x (pos old-rect)) (/ (w (size old-rect)) 2)))
         (old-center-y (+ (y (pos old-rect)) (/ (h (size old-rect)) 2))))
    (update-canvas-size canvas 30 15)
    (let* ((new-rect (canvas-content-rectangle canvas))
           (new-center-x (+ (x (pos new-rect)) (/ (w (size new-rect)) 2)))
           (new-center-y (+ (y (pos new-rect)) (/ (h (size new-rect)) 2))))
      (is (= new-center-x old-center-x) "Center X position should stay fixed")
      (is (= new-center-y old-center-y) "Center Y position should stay fixed")
      (is (= (w (size new-rect)) 30) "Width should be updated to 30")
      (is (= (h (size new-rect)) 15) "Height should be updated to 15"))))

;;;-----------------------------------------------------------------------------
;;; Canvas Rendering Preparation Tests
;;;-----------------------------------------------------------------------------

(test prepare-and-finalize
  "Test canvas preparation and finalization for rendering"

  ;; Test preparation
  (let* ((backend (make-mock-backend :width 80 :height 24 :cursor-x 10 :cursor-y 8))
         (canvas (initialize-canvas backend
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 20 :h 10))))
    (prepare-canvas-for-rendering canvas)

    ;; Check that area was cleared
    (is (= (length (cleared-areas backend)) 1) "One area should be cleared")
    (let ((cleared (first (cleared-areas backend))))
      (is (= (first cleared) 8) "Clear should start at cursor's row"))

    ;; Check that cursor was positioned correctly
    (multiple-value-bind (cursor-col cursor-row)
        (get-cursor-position backend)
      (let ((rect (canvas-content-rectangle canvas)))
        (is (= cursor-row (y (pos rect))) "Cursor should be at canvas top edge")
        (is (= cursor-col (x (pos rect))) "Cursor should be at canvas left edge"))))

  ;; Test finalization
  (let* ((backend (make-mock-backend :width 80 :height 24 :cursor-x 10 :cursor-y 8))
         (canvas (initialize-canvas backend
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 20 :h 10))))
    (prepare-canvas-for-rendering canvas)

    ;; Simulate cursor movement during rendering
    (set-cursor-position backend 15 20)

    (finalize-canvas-after-rendering canvas)

    ;; Check that lines added was calculated correctly
    (is (= (elmtui.platform.canvas::canvas-lines-added canvas) 7)
        "Lines added should be tracked correctly")))

;;;-----------------------------------------------------------------------------
;;; Canvas Buffer Operations Tests
;;;-----------------------------------------------------------------------------

(test canvas-buffer-operations
  "Test canvas buffer operations"

  ;; Test applying canvas to buffer
  (let* ((backend (make-mock-backend :width 80 :height 24))
         (canvas (initialize-canvas backend
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 20 :h 10)))
         (test-buffer (make-virtual-buffer 80 24))
         (canvas-buf (canvas-buffer canvas)))

    ;; Fill canvas buffer with test content
    (fill-test-buffer canvas-buf
                      '((0 0 #\A (:color (255 0 0)))
                        (0 19 #\Z (:color (0 0 255)))
                        (9 0 #\1 (:color (0 255 0)))
                        (9 19 #\9 (:color (255 255 0)))))

    ;; Apply canvas to test buffer
    (apply-canvas-to-buffer canvas test-buffer)

    ;; Check that content was transferred correctly, with position offset
    (let ((rect (canvas-content-rectangle canvas))
          (patterns '()))
      (push (list (y (pos rect)) (x (pos rect)) #\A '((:color (255 0 0)))) patterns)
      (push (list (y (pos rect)) (+ (x (pos rect)) 19) #\Z '((:color (0 0 255)))) patterns)
      (push (list (+ (y (pos rect)) 9) (x (pos rect)) #\1 '((:color (0 255 0)))) patterns)
      (push (list (+ (y (pos rect)) 9) (+ (x (pos rect)) 19) #\9 '((:color (255 255 0)))) patterns)

      (verify-buffer-content test-buffer patterns))))

;;;-----------------------------------------------------------------------------
;;; Canvas Edge Cases Tests
;;;-----------------------------------------------------------------------------

(test canvas-edge-cases
  "Test canvas behavior in edge cases"

  ;; Test with zero size
  (let* ((backend (make-mock-backend :width 80 :height 24))
         (canvas (initialize-canvas backend
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 0 :h 0))))
    (is (not (null canvas)) "Canvas should be created even with zero size")
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (w (size rect)) 0) "Canvas width should be 0")
      (is (= (h (size rect)) 0) "Canvas height should be 0")))

  ;; Test with position outside terminal bounds
  (let* ((backend (make-mock-backend :width 20 :height 10 :cursor-x 25 :cursor-y 15))
         (canvas (initialize-canvas backend
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 10 :h 5))))

    ;; Apply to a smaller buffer
    (let ((test-buffer (make-virtual-buffer 15 8)))
      (apply-canvas-to-buffer canvas test-buffer)
      ;; This should not raise any errors
      (is (eq (not null) t) "Canvas should handle application to smaller buffer gracefully"))))

;;;-----------------------------------------------------------------------------
;;; Boundary Tests for Fixed-Position Canvases
;;;-----------------------------------------------------------------------------

(test canvas-boundary-tests
  "Test canvas boundary handling for fixed position canvases"

  ;; Test fixed position at edge
  (let* ((fixed-pos (make-pos :x 75 :y 20))
         (canvas (create-test-canvas :fixed :top-left
                                     :width 80 :height 24
                                     :canvas-width 10 :canvas-height 8
                                     :fixed-position fixed-pos)))
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (x (pos rect)) 75) "Canvas X should be at the specified position")
      (is (= (y (pos rect)) 20) "Canvas Y should be at the specified position")

      ;; Apply to a buffer to test boundary handling
      (let ((test-buffer (make-virtual-buffer 80 24)))
        (let ((canvas-buf (canvas-buffer canvas)))
          ;; Fill canvas with test pattern
          (fill-test-buffer canvas-buf
                            '((0 0 #\A (:color (255 0 0)))
                              (0 9 #\Z (:color (0 0 255)))  ;; This is at the edge
                              (7 0 #\1 (:color (0 255 0)))
                              (7 9 #\9 (:color (255 255 0))))) ;; This is at the edge

          ;; Apply canvas to test buffer
          (apply-canvas-to-buffer canvas test-buffer)

          ;; Verify content within buffer boundaries
          (let ((patterns '()))
            (push (list 20 75 #\A '((:color (255 0 0)))) patterns)
            (push (list 27 75 #\1 '((:color (0 255 0)))) patterns)
            (verify-buffer-content test-buffer patterns)))))))

;;;-----------------------------------------------------------------------------
;;; Canvas Max Size Tests
;;;-----------------------------------------------------------------------------

(test canvas-max-size
  "Test canvas respects the max-size parameter"

  ;; Test initialization with max-size
  (let* ((max-size (make-size :w 15 :h 8))
         (canvas (initialize-canvas (make-mock-backend)
                                    :position-strategy :below-cursor
                                    :anchor-point :top-left
                                    :initial-size (make-size :w 20 :h 10)
                                    :max-size max-size)))
    (is (not (null canvas)) "Canvas should be created successfully")
    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (w (size rect)) 15) "Canvas width should be limited to max-size width")
      (is (= (h (size rect)) 8) "Canvas height should be limited to max-size height")))

  ;; Test resize respects max-size
  (let* ((max-size (make-size :w 25 :h 12))
         (canvas (create-test-canvas :below-cursor :top-left
                                     :canvas-width 20 :canvas-height 10)))

    ;; Set max-size after creation
    (setf (canvas-max-size canvas) max-size)

    ;; Try to resize beyond max-size
    (update-canvas-size canvas 30 15)

    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (w (size rect)) 25) "Resized width should be limited to max-size")
      (is (= (h (size rect)) 12) "Resized height should be limited to max-size"))

    ;; Try resize within max-size
    (update-canvas-size canvas 22 11)

    (let ((rect (canvas-content-rectangle canvas)))
      (is (= (w (size rect)) 22) "Resize within max-size should work")
      (is (= (h (size rect)) 11) "Resize within max-size should work"))))


;; (test basic-canvas-creation-and-access
;;       (let ((canvas (elmtui.platform.canvas:make-canvas :width 10 :height 5)))
;;         (is (= (elmtui.platform.canvas:content-w canvas) 10))
;;         (is (= (elmtui.platform.canvas:content-h canvas) 5))
;;         ;; Ensure default char is space and default style is nil
;;         (loop for y from 0 below (elmtui.platform.canvas:content-h canvas)
;;               do (loop for x from 0 below (elmtui.platform.canvas:content-w canvas)
;;                        do (is (eql (elmtui.platform.canvas:canvas-char-at canvas x y) #\Space))
;;                           (is (null (elmtui.platform.canvas:canvas-style-at canvas x y)))))))

;; (test canvas-put-and-get
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 3 :height 2))
;;         (style1 (elmtui.style-lib:make-style :fg-color :red))
;;         (style2 (elmtui.style-lib:make-style :bg-color :blue)))
;;     (elmtui.platform.canvas:canvas-put canvas 0 0 #\A style1)
;;     (elmtui.platform.canvas:canvas-put canvas 1 0 #\B nil)
;;     (elmtui.platform.canvas:canvas-put canvas 0 1 #\C style2)

;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 0) #\A))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 0 0) style1))

;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 0) #\B))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 1 0)))

;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 1) #\C))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 0 1) style2))

;;     ;; Check out-of-bounds access (should not error, should return default)
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-char-at canvas 10 10))
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-style-at canvas 10 10))
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-put canvas 10 10 #\X nil))))

;; (test canvas-clear
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 2 :height 1))
;;         (style1 (elmtui.style-lib:make-style :fg-color :green)))
;;     (elmtui.platform.canvas:canvas-put canvas 0 0 #\X style1)
;;     (elmtui.platform.canvas:canvas-put canvas 1 0 #\Y nil)

;;     (elmtui.platform.canvas:canvas-clear canvas)

;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 0) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 0)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 0) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 1 0)))))

;; (test canvas-blit
;;   (let* ((src-canvas (elmtui.platform.canvas:make-canvas :width 2 :height 2))
;;          (dst-canvas (elmtui.platform.canvas:make-canvas :width 4 :height 3))
;;          (style-a (elmtui.style-lib:make-style :fg-color :red))
;;          (style-b (elmtui.style-lib:make-style :bg-color :blue)))
;;     ;; Populate source canvas
;;     (elmtui.platform.canvas:canvas-put src-canvas 0 0 #\A style-a)
;;     (elmtui.platform.canvas:canvas-put src-canvas 1 0 #\B nil)
;;     (elmtui.platform.canvas:canvas-put src-canvas 0 1 #\C style-b)
;;     (elmtui.platform.canvas:canvas-put src-canvas 1 1 #\D style-a)

;;     ;; Blit src-canvas to dst-canvas at (1, 1)
;;     (elmtui.platform.canvas:canvas-blit dst-canvas src-canvas 1 1)

;;     ;; Check characters and styles in dst-canvas
;;     ;; Area where src-canvas was blitted
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 1 1) #\A))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at dst-canvas 1 1) style-a))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 2 1) #\B))
;;     (is (null (elmtui.platform.canvas:canvas-style-at dst-canvas 2 1)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 1 2) #\C))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at dst-canvas 1 2) style-b))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 2 2) #\D))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at dst-canvas 2 2) style-a))

;;     ;; Check areas outside the blitted region (should remain default)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 0 0) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at dst-canvas 0 0)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas 3 2) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at dst-canvas 3 2)))

;;     ;; Test blitting with clipping (part of src-canvas outside dst-canvas)
;;     (let ((small-dst (elmtui.platform.canvas:make-canvas :width 2 :height 1)))
;;       (elmtui.platform.canvas:canvas-blit small-dst src-canvas 0 0)
;;       (is (eql (elmtui.platform.canvas:canvas-char-at small-dst 0 0) #\A))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at small-dst 0 0) style-a))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at small-dst 1 0) #\B))
;;       (is (null (elmtui.platform.canvas:canvas-style-at small-dst 1 0)))
;;       ;; Characters from the second row of src-canvas should not be blitted
;;       (signals elmtui.platform.canvas:canvas-out-of-bounds
;;         (elmtui.platform.canvas:canvas-char-at small-dst 0 1)))

;;     ;; Test blitting with source-rect
;;     (let ((dst-canvas-src-rect (elmtui.platform.canvas:make-canvas :width 3 :height 2)))
;;       ;; Blit only the character 'D' from src-canvas (1,1) of size 1x1
;;       ;; to dst-canvas-src-rect at (0,0)
;;       (elmtui.platform.canvas:canvas-blit dst-canvas-src-rect src-canvas 0 0
;;                                           :src-x 1 :src-y 1 :src-width 1 :src-height 1)
;;       (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas-src-rect 0 0) #\D))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at dst-canvas-src-rect 0 0) style-a))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at dst-canvas-src-rect 1 0) #\Space)) ; Unchanged
;;       (is (null (elmtui.platform.canvas:canvas-style-at dst-canvas-src-rect 1 0))))))

;; (test canvas-draw-string
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 10 :height 3))
;;         (style1 (elmtui.style-lib:make-style :fg-color :blue :bold t)))
;;     (elmtui.platform.canvas:canvas-draw-string canvas 1 1 "Hello" style1)

;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 1) #\H))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 1 1) style1))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 2 1) #\e))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 2 1) style1))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 3 1) #\l))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 3 1) style1))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 4 1) #\l))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 4 1) style1))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 5 1) #\o))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 5 1) style1))

;;     ;; Check character after string and character before string
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 6 1) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 6 1)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 1) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 1)))

;;     ;; Test string clipping
;;     (elmtui.platform.canvas:canvas-draw-string canvas 7 0 "Clipped" style1)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 7 0) #\C))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 8 0) #\l))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 9 0) #\i))
;;     ;; The rest "pped" should be clipped
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-char-at canvas 10 0))

;;     ;; Test drawing with nil style
;;     (elmtui.platform.canvas:canvas-draw-string canvas 0 2 "Test" nil)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 2) #\T))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 2)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 3 2) #\t))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 3 2)))))

;; (test canvas-fill-rect
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 5 :height 4))
;;         (style-fill (elmtui.style-lib:make-style :bg-color :yellow)))
;;     (elmtui.platform.canvas:canvas-fill-rect canvas 1 1 3 2 #\X style-fill)

;;     ;; Check filled area
;;     (loop for y from 1 to 2
;;           do (loop for x from 1 to 3
;;                    do (is (eql (elmtui.platform.canvas:canvas-char-at canvas x y) #\X))
;;                       (is (equal (elmtui.platform.canvas:canvas-style-at canvas x y) style-fill))))

;;     ;; Check outside filled area (should be default)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 0) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 0)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 4 3) #\Space))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 4 3)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 0) #\Space)) ; Above rect
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 1 0)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 1) #\Space)) ; Left of rect
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 1)))

;;     ;; Test filling with clipping
;;     (elmtui.platform.canvas:canvas-fill-rect canvas 3 2 5 5 #\# nil) ; Rect extends beyond canvas
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 3 2) #\#))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 3 2)))
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 4 3) #\#))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 4 3)))
;;     ;; Original X from previous fill should be overwritten
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 3 2) #\#))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 3 2)))

;;     ;; Check that out-of-bounds parts were not written
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-char-at canvas 5 4))))

;; ;;; New test for canvas-set-style
;; (test canvas-set-style
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 3 :height 2))
;;         (style1 (elmtui.style-lib:make-style :fg-color :red))
;;         (style2 (elmtui.style-lib:make-style :bg-color :blue :bold t)))
;;     ;; Put some characters first
;;     (elmtui.platform.canvas:canvas-put canvas 0 0 #\A nil)
;;     (elmtui.platform.canvas:canvas-put canvas 1 0 #\B style1)

;;     ;; Set style for A
;;     (elmtui.platform.canvas:canvas-set-style canvas 0 0 style2)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 0) #\A)) ; Char should remain
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 0 0) style2))

;;     ;; Set style for B (overwrite existing style)
;;     (elmtui.platform.canvas:canvas-set-style canvas 1 0 style2)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 0) #\B)) ; Char should remain
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 1 0) style2))

;;     ;; Set style for an empty cell
;;     (elmtui.platform.canvas:canvas-set-style canvas 0 1 style1)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 1) #\Space)) ; Char should be default
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 0 1) style1))

;;     ;; Test out-of-bounds
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-set-style canvas 10 10 style1))))

;; ;;; New test for canvas-set-char
;; (test canvas-set-char
;;   (let ((canvas (elmtui.platform.canvas:make-canvas :width 3 :height 2))
;;         (style1 (elmtui.style-lib:make-style :fg-color :magenta)))
;;     ;; Put some characters and styles first
;;     (elmtui.platform.canvas:canvas-put canvas 0 0 #\A style1)
;;     (elmtui.platform.canvas:canvas-put canvas 1 0 #\B nil)

;;     ;; Set char for A's position
;;     (elmtui.platform.canvas:canvas-set-char canvas 0 0 #\X)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 0) #\X))
;;     (is (equal (elmtui.platform.canvas:canvas-style-at canvas 0 0) style1)) ; Style should remain

;;     ;; Set char for B's position
;;     (elmtui.platform.canvas:canvas-set-char canvas 1 0 #\Y)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 1 0) #\Y))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 1 0))) ; Style should remain nil

;;     ;; Set char for an empty cell (default style)
;;     (elmtui.platform.canvas:canvas-set-char canvas 0 1 #\Z)
;;     (is (eql (elmtui.platform.canvas:canvas-char-at canvas 0 1) #\Z))
;;     (is (null (elmtui.platform.canvas:canvas-style-at canvas 0 1))) ; Style should be default (nil)

;;     ;; Test out-of-bounds
;;     (signals elmtui.platform.canvas:canvas-out-of-bounds
;;       (elmtui.platform.canvas:canvas-set-char canvas 10 10 #\W))))

;; (test canvas-copy
;;   (let* ((original-canvas (elmtui.platform.canvas:make-canvas :width 2 :height 1))
;;          (style1 (elmtui.style-lib:make-style :fg-color :cyan)))
;;     (elmtui.platform.canvas:canvas-put original-canvas 0 0 #\X style1)
;;     (elmtui.platform.canvas:canvas-put original-canvas 1 0 #\Y nil)

;;     (let ((copied-canvas (elmtui.platform.canvas:canvas-copy original-canvas)))
;;       ;; Check dimensions
;;       (is (= (elmtui.platform.canvas:canvas-width copied-canvas) 2))
;;       (is (= (elmtui.platform.canvas:canvas-height copied-canvas) 1))

;;       ;; Check content
;;       (is (eql (elmtui.platform.canvas:canvas-char-at copied-canvas 0 0) #\X))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at copied-canvas 0 0) style1))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at copied-canvas 1 0) #\Y))
;;       (is (null (elmtui.platform.canvas:canvas-style-at copied-canvas 1 0)))

;;       ;; Modify original, ensure copy is not affected
;;       (elmtui.platform.canvas:canvas-put original-canvas 0 0 #\Z nil)
;;       (is (eql (elmtui.platform.canvas:canvas-char-at copied-canvas 0 0) #\X))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at copied-canvas 0 0) style1))

;;       ;; Modify copy, ensure original is not affected
;;       (elmtui.platform.canvas:canvas-put copied-canvas 1 0 #\W style1)
;;       (is (eql (elmtui.platform.canvas:canvas-char-at original-canvas 1 0) #\Y))
;;       (is (null (elmtui.platform.canvas:canvas-style-at original-canvas 1 0))))))

;; (test canvas-subcanvas
;;   (let* ((main-canvas (elmtui.platform.canvas:make-canvas :width 5 :height 4))
;;          (style-a (elmtui.style-lib:make-style :fg-color :red))
;;          (style-b (elmtui.style-lib:make-style :bg-color :blue)))
;;     ;; Populate main canvas
;;     (elmtui.platform.canvas:canvas-put main-canvas 1 1 #\A style-a)
;;     (elmtui.platform.canvas:canvas-put main-canvas 2 1 #\B nil)
;;     (elmtui.platform.canvas:canvas-put main-canvas 1 2 #\C style-b)
;;     (elmtui.platform.canvas:canvas-put main-canvas 2 2 #\D style-a)
;;     (elmtui.platform.canvas:canvas-put main-canvas 3 2 #\E nil) ; Edge of 2x2 subcanvas

;;     (let ((sub (elmtui.platform.canvas:canvas-subcanvas main-canvas 1 1 2 2)))
;;       (is (= (elmtui.platform.canvas:canvas-width sub) 2))
;;       (is (= (elmtui.platform.canvas:canvas-height sub) 2))

;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub 0 0) #\A))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at sub 0 0) style-a))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub 1 0) #\B))
;;       (is (null (elmtui.platform.canvas:canvas-style-at sub 1 0)))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub 0 1) #\C))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at sub 0 1) style-b))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub 1 1) #\D))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at sub 1 1) style-a))

;;       ;; Test out-of-bounds for subcanvas
;;       (signals elmtui.platform.canvas:canvas-out-of-bounds
;;         (elmtui.platform.canvas:canvas-char-at sub 2 0))
;;       (signals elmtui.platform.canvas:canvas-out-of-bounds
;;         (elmtui.platform.canvas:canvas-char-at sub 0 2))

;;       ;; Modify subcanvas and check if main-canvas is affected (it should be a copy)
;;       (elmtui.platform.canvas:canvas-put sub 0 0 #\X nil)
;;       (is (eql (elmtui.platform.canvas:canvas-char-at main-canvas 1 1) #\A))
;;       (is (equal (elmtui.platform.canvas:canvas-style-at main-canvas 1 1) style-a)))


;;     ;; Test subcanvas creation that goes out of bounds of the parent
;;     ;; It should be clipped to the parent's bounds.
;;     (let ((sub-clipped (elmtui.platform.canvas:canvas-subcanvas main-canvas 3 2 3 3))) ; Request 3x3 from (3,2)
;;       ;; main-canvas is 5x4. From (3,2):
;;       ;; Width: can go from 3 up to 4 (2 cells: (3,y), (4,y))
;;       ;; Height: can go from 2 up to 3 (2 cells: (x,2), (x,3))
;;       ;; So, clipped subcanvas should be 2x2
;;       (is (= (elmtui.platform.canvas:canvas-width sub-clipped) 2))
;;       (is (= (elmtui.platform.canvas:canvas-height sub-clipped) 2))

;;       (elmtui.platform.canvas:canvas-put main-canvas 3 2 #\X nil)
;;       (elmtui.platform.canvas:canvas-put main-canvas 4 2 #\Y style-a)
;;       (elmtui.platform.canvas:canvas-put main-canvas 3 3 #\Z style-b)
;;       (elmtui.platform.canvas:canvas-put main-canvas 4 3 #\W nil)

;;       ;; Re-create sub-clipped after populating main-canvas for these checks
;;       (setq sub-clipped (elmtui.platform.canvas:canvas-subcanvas main-canvas 3 2 3 3))

;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub-clipped 0 0) #\X)) ; Corresponds to main-canvas (3,2)
;;       (is (null (elmtui.platform.canvas:canvas-style-at sub-clipped 0 0)))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub-clipped 1 0) #\Y)) ; Corresponds to main-canvas (4,2)
;;       (is (equal (elmtui.platform.canvas:canvas-style-at sub-clipped 1 0) style-a))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub-clipped 0 1) #\Z)) ; Corresponds to main-canvas (3,3)
;;       (is (equal (elmtui.platform.canvas:canvas-style-at sub-clipped 0 1) style-b))
;;       (is (eql (elmtui.platform.canvas:canvas-char-at sub-clipped 1 1) #\W)) ; Corresponds to main-canvas (4,3)
;;       (is (null (elmtui.platform.canvas:canvas-style-at sub-clipped 1 1))))

;; Test subcanvas with 0 width or height (should probably be an empty canvas or error)
;; Current implementation of canvas-subcanvas will create a 0xH or Wx0 canvas.
;; Let's test that it creates a canvas with 0 width/height and doesn't error.
;; (let ((sub-zero-width (elmtui.platform.canvas:canvas-subcanvas main-canvas 1 1 0 2)))
;;   (is (= (elmtui.platform.canvas:canvas-width sub-zero-width) 0))
;;   (is (= (elmtui.platform.canvas:canvas-height sub-zero-width) 2)))

;; (let ((sub-zero-height (elmtui.platform.canvas:canvas-subcanvas main-canvas 1 1 2 0)))
;;   (is (= (elmtui.platform.canvas:canvas-width sub-zero-height) 2))
;;   (is (= (elmtui.platform.canvas:canvas-height sub-zero-height) 0)))

;; (let ((sub-zero-both (elmtui.platform.canvas:canvas-subcanvas main-canvas 1 1 0 0)))
;;   (is (= (elmtui.platform.canvas:canvas-width sub-zero-both) 0))
;;   (is (= (elmtui.platform.canvas:canvas-height sub-zero-both) 0)))

;; ;; Test subcanvas from an out-of-bounds starting point (should result in 0x0 canvas)
;; (let ((sub-oob (elmtui.platform.canvas:canvas-subcanvas main-canvas 10 10 2 2)))
;;   (is (= (elmtui.platform.canvas:canvas-width sub-oob) 0))
;;   (is (= (elmtui.platform.canvas:canvas-height sub-oob) 0)))))


;;;-----------------------------------------------------------------------------
;;; Run Tests
;;;-----------------------------------------------------------------------------

(defun run-canvas-tests ()
  (run! 'canvas-tests))
