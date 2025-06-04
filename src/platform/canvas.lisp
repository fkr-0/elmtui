;;;===============================================================
;;; File: src/platform/canvas.lisp
;;; Terminal Canvas Abstraction Layer
;;;
;;; This module provides an abstraction layer between the layout
;; Apply max size constraints if provided
;;; of UI elements and minimal screen impact.
;;;===============================================================

(uiop:define-package :elmtui.platform.canvas
  (:use :cl :log4cl)
  (:import-from :elmtui.platform.api
                #:term-w
                #:term-h
                #:get-cursor-position
                #:set-cursor-position
                #:clear-area)
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
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:virtual-terminal-buffer
                #:make-virtual-terminal-buffer
                #:with-virtual-buffer-lock
                #:virtual-buffer
                #:make-virtual-buffer
                #:buffer-width
                #:buffer-width #:buffer-height #:buffer-cell-at
                #:buffer-cell-char #:buffer-cell-style
                #:buffer-height
                #:buffer-cell-at
                #:set-buffer-cell-at)
  (:export
   ;; Canvas structure and accessors
   #:canvas
   #:make-canvas
   #:canvas-buffer
   #:canvas-backend
   #:canvas-position-strategy
   #:canvas-anchor-point
   #:canvas-initial-cursor-position
   #:canvas-current-cursor-position
   #:canvas-view-rectangle
   #:canvas-content-rectangle
   #:canvas-max-size
   #:canvas-visible-p
   #:apply-canvas-to-buffer
   #:get-canvas-viewport
   #:content-w
   #:content-h
   #:view-w
   #:view-h

   ;; Canvas management
   #:initialize-canvas
   #:update-canvas-size
   #:clear-canvas
   #:prepare-canvas-for-rendering
   #:finalize-canvas-after-rendering
   #:restore-terminal-state

   ;; Position strategies
   #:+position-strategy-below-cursor+
   #:+position-strategy-above-cursor+
   #:+position-strategy-center-screen+
   #:+position-strategy-fixed+

   ;; Anchor points
   #:+anchor-top+
   #:+anchor-bottom+
   #:+anchor-left+
   #:+anchor-right+
   #:+anchor-center+
   #:+anchor-top-left+
   #:+anchor-top-right+
   #:+anchor-bottom-left+
   #:+anchor-bottom-right+))

(in-package :elmtui.platform.canvas)

;;;-----------------------------------------------------------------------------
;;; Canvas Position Strategies
;;;-----------------------------------------------------------------------------

(defconstant +position-strategy-below-cursor+ :below-cursor
  "Place the canvas below the initial cursor position.")

(defconstant +position-strategy-above-cursor+ :above-cursor
  "Place the canvas above the initial cursor position.")

(defconstant +position-strategy-center-screen+ :center-screen
  "Center the canvas on the screen.")

(defconstant +position-strategy-fixed+ :fixed
  "Place the canvas at a fixed position specified by coordinates.")

;;;-----------------------------------------------------------------------------
;;; Canvas Anchor Points
;;;-----------------------------------------------------------------------------

(defconstant +anchor-top+ :top
  "Anchor the canvas at the top.")

(defconstant +anchor-bottom+ :bottom
  "Anchor the canvas at the bottom.")

(defconstant +anchor-left+ :left
  "Anchor the canvas at the left.")

(defconstant +anchor-right+ :right
  "Anchor the canvas at the right.")

(defconstant +anchor-center+ :center
  "Anchor the canvas at the center.")

(defconstant +anchor-top-left+ :top-left
  "Anchor the canvas at the top-left corner.")

(defconstant +anchor-top-right+ :top-right
  "Anchor the canvas at the top-right corner.")

(defconstant +anchor-bottom-left+ :bottom-left
  "Anchor the canvas at the bottom-left corner.")

(defconstant +anchor-bottom-right+ :bottom-right
  "Anchor the canvas at the bottom-right corner.")

;;;-----------------------------------------------------------------------------
;;; Canvas Structure
;;;-----------------------------------------------------------------------------

(defstruct canvas
  "Canvas abstraction that sits between layout trees and the terminal backend. Core of the
implementation are content vs view rectangle:

view-rectangle: The rectangle that represents the entire terminal view area.
content-rectangle: The rectangle that represents the area where the canvas content is rendered.

therefore the content is always a subset of the view rectangle, defining the area where
the canvas content is rendered "
  (backend nil :type (or null t) :read-only t)
  (position-strategy +position-strategy-fixed+ :type keyword) ; Default to fixed
  (anchor-point +anchor-top-left+ :type keyword)
  (fixed-position (make-pos :x 0 :y 0) :type (or null pos)) ; Default to 0,0
  (initial-cursor-position nil :type (or null pos))
  (current-cursor-position nil :type (or null pos))
  (lines-added 0 :type integer)
  (view-rectangle nil :type (or null rectangle))
  (content-rectangle nil :type (or null rectangle))
  (max-size nil :type (or null size))
  (visible-p t :type boolean)
  (initial-terminal-content nil :type (or null string))
  (buffer nil :type (or null virtual-terminal-buffer))) ;:read-only t)) TODO

;;;-----------------------------------------------------------------------------
;;; Canvas Management
;;;-----------------------------------------------------------------------------
(defun content-w (canvas)
  "Get the width of the canvas content rectangle."
  (when (canvas-content-rectangle canvas)
    (w (canvas-content-rectangle canvas))))
(defun content-h (canvas)
  "Get the height of the canvas content rectangle."
  (when (canvas-content-rectangle canvas)
    (h (canvas-content-rectangle canvas))))
(defun view-w (canvas)
  "Get the width of the canvas view rectangle."
  (when (canvas-view-rectangle canvas)
    (w (canvas-view-rectangle canvas))))
(defun view-h (canvas)
  "Get the height of the canvas view rectangle."
  (when (canvas-view-rectangle canvas)
    (h (canvas-view-rectangle canvas))))
(defmethod w ((canvas canvas))
  "Get the width of the canvas content rectangle."
  (when (canvas-content-rectangle canvas)
    (w (canvas-content-rectangle canvas))))
(defmethod h ((canvas canvas))
  "Get the height of the canvas content rectangle."
  (when (canvas-content-rectangle canvas)
    (h (canvas-content-rectangle canvas))))
(defun initialize-canvas (backend &key
                                    (position-strategy +position-strategy-fixed+) ; Updated default
                                    (anchor-point +anchor-top-left+)
                                    (fixed-position (make-pos :x 0 :y 0)) ; Updated default
                                    (initial-size nil) ; Will default to full screen if nil
                                    (max-size nil))
  "Initialize a new canvas for the given backend with specified positioning strategy.
   Returns a canvas structure.

   POSITION-STRATEGY: How to position the canvas (:below-cursor, :above-cursor, etc.)
   ANCHOR-POINT: The anchor point for canvas positioning and resizing
   FIXED-POSITION: For fixed position canvases, the absolute position
   INITIAL-SIZE: The initial size of the canvas content area. Defaults to full terminal if NIL.
   MAX-SIZE: The maximum size the canvas can grow to"
  (check-type backend t)
  (check-type position-strategy keyword)
  (check-type anchor-point keyword)

  (multiple-value-bind (cursor-col cursor-row)
      (get-cursor-position backend)
    (let* ((initial-cursor-pos (make-pos :x cursor-col :y cursor-row))
           (term-width (term-w backend))
           (term-height (term-h backend))
           ;; If initial-size is not provided, default to full terminal size.
           (effective-initial-size (or initial-size (make-size :w term-width :h term-height)))
           (canvas-width (w effective-initial-size))
           (canvas-height (h effective-initial-size))
           (view-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                      :size (make-size :w term-width :h term-height)))
           (content-rect nil)
           (effective-fixed-position (if (eq position-strategy +position-strategy-fixed+)
                                         (or fixed-position (make-pos :x 0 :y 0))
                                         fixed-position)))

      ;; Calculate the content rectangle based on positioning strategy
      (setf content-rect
            (case position-strategy
              (:below-cursor
               (make-rectangle :pos (make-pos :x 0 :y cursor-row)
                               :size (make-size :w canvas-width :h canvas-height)))

              (:above-cursor
               (let ((start-y (max 0 (- cursor-row canvas-height))))
                 (make-rectangle :pos (make-pos :x 0 :y start-y)
                                 :size (make-size :w canvas-width :h (- cursor-row start-y)))))

              (:center-screen
               (let ((start-x (max 0 (floor (- term-width canvas-width) 2)))
                     (start-y (max 0 (floor (- term-height canvas-height) 2))))
                 (make-rectangle :pos (make-pos :x start-x :y start-y)
                                 :size (make-size :w canvas-width :h canvas-height))))

              (:fixed
               (if effective-fixed-position
                   (make-rectangle :pos effective-fixed-position
                                   :size (make-size :w canvas-width :h canvas-height))
                   (error "Position strategy is :fixed but fixed-position is NIL and no default was applied.")))

              (t (error "Unknown position strategy: ~A" position-strategy))))

      ;; Apply max size constraints to the content rectangle's size
      (when max-size
        (setf (w (elmtui.view.geo:size content-rect)) (min (w (elmtui.view.geo:size content-rect)) (w max-size)))
        (setf (h (elmtui.view.geo:size content-rect)) (min (h (elmtui.view.geo:size content-rect)) (h max-size))))

      ;; Create and return the canvas structure with its own virtual buffer
      (let ((buf (make-virtual-buffer
                  (w content-rect)
                  (h content-rect))))
        (make-canvas :backend backend
                     :max-size max-size
                     :position-strategy position-strategy
                     :anchor-point anchor-point
                     :fixed-position effective-fixed-position
                     :initial-cursor-position initial-cursor-pos
                     :current-cursor-position initial-cursor-pos
                     :view-rectangle view-rect
                     :content-rectangle content-rect
                     :buffer buf)))))
(defun update-canvas-size (canvas new-width new-height)
  "Update the size of the canvas content rectangle based on the anchor point.
   This ensures the canvas grows/shrinks in the desired direction.
   Also resizes the canvas's internal buffer."
  (check-type canvas canvas)
  (check-type new-width (integer 0)) ; Ensure non-negative
  (check-type new-height (integer 0)) ; Ensure non-negative

  (let* ((current-rect (canvas-content-rectangle canvas))
         (current-pos (rectangle-pos current-rect))
         (current-size (rectangle-size current-rect))
         (anchor (canvas-anchor-point canvas))
         (new-pos (copy-structure current-pos))) ; Make a copy to modify

    ;; Calculate the new position based on anchor point
    (case anchor
      (:bottom
       (setf (y new-pos) (- (+ (y current-pos) (h current-size)) new-height)))
      (:right
       (setf (x new-pos) (- (+ (x current-pos) (w current-size)) new-width)))
      (:center
       (setf (x new-pos) (+ (x current-pos)
                            (floor (- (w current-size) new-width) 2))
             (y new-pos) (+ (y current-pos)
                            (floor (- (h current-size) new-height) 2))))
      (:top-right
       (setf (x new-pos) (- (+ (x current-pos) (w current-size)) new-width)))
      (:bottom-left
       (setf (y new-pos) (- (+ (y current-pos) (h current-size)) new-height)))
      (:bottom-right
       (setf (x new-pos) (- (+ (x current-pos) (w current-size)) new-width)
             (y new-pos) (- (+ (y current-pos) (h current-size)) new-height)))
      ;; :top, :left, :top-left and any others keep the same position by default
      ((:top :left :top-left) nil)
      (otherwise (log-warn "Unhandled anchor point ~S in update-canvas-size" anchor)))


    ;; Apply max size constraints if provided
    (let* ((max-size (canvas-max-size canvas))
           (constrained-width (if (and max-size (< (w max-size) new-width))
                                  (w max-size)
                                  new-width))
           (constrained-height (if (and max-size (< (h max-size) new-height))
                                   (h max-size)
                                   new-height)))
      
      (setq constrained-width (max 0 constrained-width))
      (setq constrained-height (max 0 constrained-height))


      ;; Create a new rectangle and update the canvas
      (let ((new-rect (make-rectangle :pos new-pos
                                      :size (make-size :w constrained-width :h constrained-height))))
        (setf (canvas-content-rectangle canvas) new-rect)

        ;; Resize the canvas's internal buffer
        (let ((current-buffer (canvas-buffer canvas)))
          (when (and current-buffer
                     (or (/= (buffer-width current-buffer) constrained-width)
                         (/= (buffer-height current-buffer) constrained-height)))
            (log-info "Resizing canvas buffer from ~Dx~D to ~Dx~D"
                      (buffer-width current-buffer) (buffer-height current-buffer)
                      constrained-width constrained-height)
            ;; Assuming make-virtual-buffer creates a new buffer.
            ;; If there's a resize method for virtual-terminal-buffer, use that.
            ;; For now, creating a new one. Data is lost, which is typical for resize.
            (setf (canvas-buffer canvas)
                  (make-virtual-buffer constrained-width constrained-height))))))
    canvas))

(defun clear-canvas (canvas)
  "Clear the area occupied by the canvas content."
  (check-type canvas canvas)

  (when (canvas-visible-p canvas)
    (let* ((backend (canvas-backend canvas))
           (rect (canvas-content-rectangle canvas))
           (pos (rectangle-pos rect))
           (size (rectangle-size rect)))

      (clear-area backend (canvas-buffer canvas) (y pos) (x pos) (h size) (w size))

      ;; Track that we've cleared this area
      (setf (canvas-lines-added canvas) (max (canvas-lines-added canvas) (h size)))))
  t)

(defun prepare-canvas-for-rendering (canvas)
  "Prepare the terminal for rendering to the canvas.
   This clears the canvas area and positions the cursor appropriately."
  (check-type canvas canvas)

  (let* ((backend (canvas-backend canvas))
         (rect (canvas-content-rectangle canvas))
         (pos (rectangle-pos rect)))

    ;; Clear the canvas area
    (clear-canvas canvas)

    ;; Position the cursor at the top-left of the canvas content area
    (set-cursor-position backend (y pos) (x pos))

    ;; Update the current cursor position
    (setf (canvas-current-cursor-position canvas)
          (make-pos :x (x pos) :y (y pos))))

  t)

(defun finalize-canvas-after-rendering (canvas)
  "Finalize the canvas after rendering.
   This updates the current cursor position and other state tracking."
  (check-type canvas canvas)

  (let ((backend (canvas-backend canvas)))
    ;; Get current cursor position after rendering
    (multiple-value-bind (cursor-col cursor-row)
        (get-cursor-position backend)

      ;; Update tracked cursor position
      (setf (canvas-current-cursor-position canvas)
            (make-pos :x cursor-col :y cursor-row))

      ;; Update lines added tracking
      (let* ((initial-row (y (canvas-initial-cursor-position canvas)))
             (current-row cursor-row)
             (lines-delta (- current-row initial-row)))
        (setf (canvas-lines-added canvas)
              (max (canvas-lines-added canvas) lines-delta)))))

  t)

(defun restore-terminal-state (canvas)
  "Restore the terminal to its state before the canvas was created.
   This positions the cursor back to the original position plus any added lines."
  (check-type canvas canvas)

  (let* ((backend (canvas-backend canvas))
         (initial-pos (canvas-initial-cursor-position canvas))
         (lines-added (canvas-lines-added canvas))
         (target-row (+ (y initial-pos) lines-added)))

    ;; Position the cursor at the original column, but after any added lines
    (set-cursor-position backend target-row (x initial-pos)))

  t)

;;;-----------------------------------------------------------------------------
;;; Helper Functions
;;;-----------------------------------------------------------------------------

(defun rectangle-pos (rect)
  "Get the position of a rectangle."
  (elmtui.view.geo:pos rect))

(defun rectangle-size (rect)
  "Get the size of a rectangle."
  (elmtui.view.geo:size rect))

;; (defun apply-to-buffer (canvas buffer)
;;   "Apply the canvas to a buffer."
;;   (check-type canvas canvas)
;;   (check-type buffer t)

;;   ;; This function would typically apply the canvas to a specific buffer
;;   ;; in the terminal, but for now, we just return the canvas.
;;   (setf (canvas-initial-terminal-content canvas) buffer)
;;   canvas)
(defun get-canvas-viewport (canvas)
  "Returns a rectangle representing the current viewport of the canvas.
   This is the area where content should be rendered."
  (check-type canvas canvas)
  (canvas-content-rectangle canvas))

(defun apply-canvas-to-buffer (canvas back-buffer)
  "Overlay the canvas's virtual buffer into BACK-BUFFER at the canvas viewport."
  (check-type canvas canvas)
  (check-type back-buffer virtual-terminal-buffer)
  (let* ((buf (canvas-buffer canvas)))
    (unless buf
      (log-error "Cannot apply canvas to buffer: canvas buffer is NIL")
      (return-from apply-canvas-to-buffer back-buffer))

    (let* ((rect      (canvas-content-rectangle canvas))
           (pos       (rectangle-pos rect))
           (offset-y  (y pos))
           (offset-x  (x pos))
           (back-height (buffer-height back-buffer))
           (back-width (buffer-width back-buffer)))

      ;; Copy each cell from the canvas buffer into the back buffer with bounds checking
      (with-virtual-buffer-lock (buf)
        (with-virtual-buffer-lock (back-buffer)  ;; Add lock for back buffer too
          (loop for r from 0 below (buffer-height buf) do
            (loop for c from 0 below (buffer-width buf) do
              (let* ((target-y (+ offset-y r))
                     (target-x (+ offset-x c)))
                ;; Only copy if target coordinates are within back-buffer bounds
                (when (and (< target-y back-height)
                           (< target-x back-width))
                  (let* ((cell (buffer-cell-at buf r c))
                         (ch   (buffer-cell-char cell))
                         (st   (buffer-cell-style cell)))
                    ;; Style is always a terminal-style struct in the current rendering pipeline
                    (set-buffer-cell-at back-buffer target-y target-x ch st))))))))
      back-buffer)))
