(uiop:define-package
    :elmtui.ui.widgets.root-viewport
  (:use :cl
   :elmtui.ui.api
        :elmtui.ui.widgets.viewport)
  (:import-from :elmtui.utils :ensure-list)
  (:import-from :elmtui.app.api
                #:get-component-instance)
  (:export #:root-viewport
           #:get-cleanup-info
           #:make-root-viewport
           #:anchor-type))

(in-package :elmtui.ui.widgets.root-viewport)

;;; ---------------------------------------------------------------------------
;;; Types
;;; ---------------------------------------------------------------------------

(deftype anchor-type ()
  "Legal positions for the root-viewport relative to the terminal or cursor."
  '(member :top-left  :top   :top-right
    :left      :center :right
    :bottom-left :bottom :bottom-right
    :below-cursor :above-cursor))

;;; ---------------------------------------------------------------------------
;;; Class
;;; ---------------------------------------------------------------------------

(defclass root-viewport (viewport)
  () ;; Removed slots: anchor, initial-cursor-row, initial-cursor-col
  (:documentation
   "Stateless root viewport component. All mutable attributes (size,
offsets, scroll-state, anchor, initial cursor position, etc.) are maintained
in the external application state as *patches* rather than CLOS slots."))

;;; ---------------------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------------------

(defun compute-anchor-offset (anchor viewport-width viewport-height term-cols term-rows cursor-row cursor-col)
  "Compute (offset-y, offset-x) for the root-viewport based on anchor, terminal size, viewport size, and cursor position."
  (ecase anchor
    (:top-left      (values 0 0))
    (:top           (values 0 (floor (- term-cols viewport-width) 2)))
    (:top-right     (values 0 (- term-cols viewport-width)))
    (:left          (values (floor (- term-rows viewport-height) 2) 0))
    (:center        (values (floor (- term-rows viewport-height) 2)
                            (floor (- term-cols viewport-width) 2)))
    (:right         (values (floor (- term-rows viewport-height) 2)
                            (- term-cols viewport-width)))
    (:bottom-left   (values (- term-rows viewport-height) 0))
    (:bottom        (values (- term-rows viewport-height)
                            (floor (- term-cols viewport-width) 2)))
    (:bottom-right  (values (- term-rows viewport-height)
                            (- term-cols viewport-width)))
    (:below-cursor  (values (min (1+ cursor-row) (- term-rows viewport-height))
                            (max 0 (min cursor-col (- term-cols viewport-width)))))
    (:above-cursor  (values (max 0 (- cursor-row viewport-height))
                            (max 0 (min cursor-col (- term-cols viewport-width)))))))

(defun compute-view-size (anchor term-cols term-rows cursor-row)
  "Return three values: width height offset-y."
  (ecase anchor
    (:below-cursor (values term-cols (- term-rows cursor-row 1) 0))
    (:above-cursor (values term-cols cursor-row                 0))
    ((:top-left :top :top-right
                :left :center :right
      :bottom-left :bottom :bottom-right)
     ;; Full screen; renderer handles offset mapping.
     (values term-cols term-rows 0))))

(defun child-instance (state id-path)
  "Return the live child component instance, or NIL when absent.
   Assumes the child's specification is stored at (append id-path '(:child))
   and the first element of this spec is the child's ID (a keyword)."
  (let ((child-spec (get-path state (append id-path '(:child)))))
    (when (and child-spec (consp child-spec)) ; Ensure spec is a non-nil list
      (let ((child-id (car child-spec)))
        ;; Ensure ID is a keyword, which is the convention for component IDs.
        (when (keywordp child-id)
          (let ((child-actual-id-path (append id-path (list child-id))))
            (get-component-instance child-actual-id-path state)))))))

;;; ---------------------------------------------------------------------------
;;; Instantiation
;;; ---------------------------------------------------------------------------

;; Removed initialize-instance :after method as it was setting slots that no longer exist.
;; The :anchor and :initial-cursor-pos initargs to make-instance in make-root-viewport
;; will be effectively ignored by root-viewport's own make-instance, which is fine,
;; as the elmtui.ui.api:init method is responsible for setting these values in the app state.

(defun make-root-viewport (id
                           &key (anchor :below-cursor)
                             (initial-cursor-pos '(0 . 0)))
  "Convenience factory. Creates a root-viewport instance with the given ID.
   Anchor and initial cursor position are configured via the 'init' method."
  (declare (ignore anchor initial-cursor-pos)) ; These are handled by the init method
  (make-instance 'root-viewport :id id))

;;; ---------------------------------------------------------------------------
;;; API – INIT
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:init ((component root-viewport)
                               &key id-path
                                 initial-child-spec
                                 (anchor :below-cursor)
                                 (initial-terminal-dimensions '(80 . 24))
                                 (initial-cursor-pos '(0 . 0)))
  "Return a *patch list* describing the component’s initial state."
  (multiple-value-bind (w h oy)
      (compute-view-size anchor
                         (car initial-terminal-dimensions)
                         (cdr initial-terminal-dimensions)
                         (car initial-cursor-pos))
    (declare (ignore oy)) ; oy from compute-view-size is not directly used for offset here
    (multiple-value-bind (offset-y offset-x)
        (compute-anchor-offset anchor w h
                               (car initial-terminal-dimensions)
                               (cdr initial-terminal-dimensions)
                               (car initial-cursor-pos)
                               (cdr initial-cursor-pos))
      `((,(append id-path '(:type))          ,(type-of component))
        (,(append id-path '(:id))            ,(id-from-path id-path))
        (,(append id-path '(:state))
         (:width ,w
          :height ,h
          :offset-x ,offset-x
          :offset-y ,offset-y
          :anchor ,anchor
          :initial-cursor-row ,(car initial-cursor-pos)
          :initial-cursor-col ,(cdr initial-cursor-pos)))
        ;; Add the child spec if provided.
        ,@(when initial-child-spec
            `((,(append id-path '(:child)) ,initial-child-spec)))))))

;;; ---------------------------------------------------------------------------
;;; API – UPDATE
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:update ((component root-viewport)
                                 state message
                                 &key id-path)
  "Handle :terminal-resized plus delegate all other messages downward."
  (flet ((patch (subkey value)
           `(,(append id-path subkey) ,value)))
    (case (ensure-list message)
      ;; ── Terminal resize ────────────────────────────────────────────────────
      ((:terminal-resized)
       (destructuring-bind (&key new-dimensions) (cdr message)
         (let* ((term-cols (car new-dimensions))
                (term-rows (cdr new-dimensions))
                (anchor    (get-path state (append id-path '(:state :anchor))))
                (cursor-row (get-path state (append id-path '(:state :initial-cursor-row))))
                (cursor-col (get-path state (append id-path '(:state :initial-cursor-col))))
                (new-width  term-cols) ; root-viewport width is usually term-cols
                (new-height (nth-value 1 (compute-view-size anchor
                                                            term-cols
                                                            term-rows
                                                            cursor-row)))
                (offsets (multiple-value-list
                          (compute-anchor-offset anchor new-width new-height
                                                 term-cols term-rows
                                                 cursor-row cursor-col))))
           (list (patch '(:state :width)  new-width)
                 (patch '(:state :height) new-height)
                 (patch '(:state :offset-y) (first offsets))
                 (patch '(:state :offset-x) (second offsets))))))
      ;; ── Pass-through: send to child, keep accumulated patches ─────────────
      (t
       (let ((child (child-instance state id-path)))
         (when child
           (elmtui.ui.api:update child state message
                                 :id-path (append id-path
                                                  (list (slot-value child 'id))))))))))

;;; ---------------------------------------------------------------------------
;;; API – VIEW
;;; ---------------------------------------------------------------------------

(defmethod elmtui.ui.api:view ((component root-viewport) state
                               &key id-path)
  (let* ((vp-state (get-path state (append id-path '(:state))))
         (child    (child-instance state id-path)))
    `(:root-viewport
      :id        ,(id-from-path id-path)
      :width     ,(getf vp-state :width)
      :height    ,(getf vp-state :height)
      :offset-x  ,(getf vp-state :offset-x)
      :offset-y  ,(getf vp-state :offset-y)
      :anchor    ,(getf vp-state :anchor)
      :child     ,(when child
                    (elmtui.ui.api:view child state
                                        :id-path (append id-path
                                                         (list (slot-value child 'id))))))))

;;; ---------------------------------------------------------------------------
;;; Cleanup helpers
;;; ---------------------------------------------------------------------------

(defmethod get-cleanup-info ((component root-viewport)
                             root-viewport-id-path
                             app-state)
  "Return a property list the platform driver may need on shutdown.

Args:
  component: The root-viewport component instance (often nil if called generically).
  root-viewport-id-path: The ID path to the root-viewport in the app-state.
  app-state: The current application state (model).

Returns:
  A property list with :initial-cursor-row and :anchor if the root-viewport's
  state is found, otherwise nil.
  Example: '(:initial-cursor-row 5 :anchor :below-cursor)"
  (let ((state (get-path app-state
                         (append root-viewport-id-path '(:state)))))
    (if state ; Check if state was found
        `(:initial-cursor-row ,(getf state :initial-cursor-row 0) ; Default to 0 if not present
          :anchor             ,(getf state :anchor :top-left))   ; Default to :top-left if not present
        (progn
          (log4cl:log-warn "get-cleanup-info: Root viewport state not found at ~S"
                           (append root-viewport-id-path '(:state)))
          nil)))) ; Return nil if state is not found

;;; ---------------------------------------------------------------------------
;;; EOF
;;; ---------------------------------------------------------------------------

;;; ---------------------------------------------------------------------------
;;; EOF
;;; ---------------------------------------------------------------------------
;; (defun canvas-terminal-origin (cv backend-instance)
;;   "Calculates and returns the absolute top-left (row, col) of the canvas
;;    on the terminal based on its strategy, arguments, and current terminal state.
;;    Returns (values absolute-row absolute-col)."
;;   (declare (ignorable backend-instance)) ; backend-instance needed for term-w/h, cursor-pos
;;   (let ((canvas-w (canvas-width cv))
;;         (canvas-h (canvas-height cv))
;;         (term-w (term-w backend-instance))
;;         (term-h (term-h backend-instance)))
;;     (multiple-value-bind (base-x base-y)
;;         (case (canvas-position-strategy cv)
;;           (#.+position-strategy-fixed+
;;            (values (getf (canvas-position-args cv) :x 0)
;;                    (getf (canvas-position-args cv) :y 0)))
;;           (#.+position-strategy-below-cursor+
;;            (multiple-value-bind (cursor-c cursor-r)
;;                (get-cursor-position backend-instance)
;;              (values cursor-c (1+ cursor-r))))
;;           (#.+position-strategy-above-cursor+
;;            (multiple-value-bind (cursor-c cursor-r)
;;                (get-cursor-position backend-instance)
;;              (values cursor-c (- cursor-r canvas-h)))) ;; Anchor point will adjust this further
;;           (#.+position-strategy-center-screen+
;;            (values (floor (- term-w canvas-w) 2)
;;                    (floor (- term-h canvas-h) 2)))
;;           (t (log-warn "CANVAS: Unknown position strategy: ~S. Defaulting to (0,0)."
;;                        (canvas-position-strategy cv))
;;            (values 0 0)))
;;       ;; Adjust base-x, base-y based on anchor-point
;;       ;; The base-x, base-y is the terminal coordinate where the anchor point of the canvas will be.
;;       (case (canvas-anchor-point cv)
;;         (#.+anchor-top-left+ (values base-y base-x)) ; y is row, x is col
;;         (#.+anchor-top+
;;          (values base-y (floor (- base-x (/ canvas-w 2)))))
;;         (#.+anchor-top-right+
;;          (values base-y (- base-x canvas-w -1)))
;;         (#.+anchor-left+
;;          (values (floor (- base-y (/ canvas-h 2))) base-x))
;;         (#.+anchor-center+
;;          (values (floor (- base-y (/ canvas-h 2))) (floor (- base-x (/ canvas-w 2)))))
;;         (#.+anchor-right+
;;          (values (floor (- base-y (/ canvas-h 2))) (- base-x canvas-w -1)))
;;         (#.+anchor-bottom-left+
;;          (values (- base-y canvas-h -1) base-x))
;;         (#.+anchor-bottom+
;;          (values (- base-y canvas-h -1) (floor (- base-x (/ canvas-w 2)))))
;;         (#.+anchor-bottom-right+
;;          (values (- base-y canvas-h -1) (- base-x canvas-w -1)))
;;         (t (log-warn "CANVAS: Unknown anchor point: ~S. Defaulting to top-left behavior."
;;                      (canvas-anchor-point cv))
;;          (values base-y base-x))))))
