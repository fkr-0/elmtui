;;;===============================================================
;;; File: src/platform/output.lisp
;;; Platform Output Adapter
(uiop:define-package :elmtui.platform.output
  (:use :cl :alexandria) ; Removed :log4cl, will add it back if not already via :cl
  (:import-from :log4cl #:log-debug #:log-info #:log-error)
  (:import-from :elmtui.core.globals :*debug-layout-outlines*)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children )
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h #:make-size #:make-pos #:make-rectangle)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.platform.api #:clear-screen #:flush-output #:draw-text-at #:fill-rectangle #:draw-styled-box) ; Import draw-styled-box
  (:export :render-frame))
(in-package :elmtui.platform.output)

(defun translate-styles-for-backend (node)
  "Extracts relevant style properties and translates them into a plist
   suitable for the backend's draw-text-at function."
  (if (not (typep node 'styled-ui-node))
      (progn
        (log:debug "TRANSLATE-STYLES: Node ID: ~S is not a styled-ui-node. Returning NIL style-plist." (getf (ui-node-props node) :id))
        nil) ; Not a styled node, so no styles to translate
      (let* ((node-id (getf (ui-node-props node) :id))
             ;; Use the correctly imported 'styles' function
             (actual-style-set (elmtui.style-lib.api:styles node))) ; Get the style-set object from the node
        (log:debug "TRANSLATE-STYLES: Node ID: ~S, Input Style-Set Object: ~S" node-id actual-style-set)
        (if (not (typep actual-style-set 'elmtui.style-lib.api:style-set))
            (progn
              (log:error "TRANSLATE-STYLES: Node ID: ~S, (styles node) is NOT a style-set! Type: ~A, Value: ~S. Returning NIL."
                         node-id (type-of actual-style-set) actual-style-set)
             nil)
            ;; Standardize on :color and :background-color from style system
           (let* ((fg-val (style-value node :color nil)) ; Query :color for foreground
                  (bg-val (style-value node :background-color nil)) ; Query :background-color for background
                  (attrs-val (style-value node :attributes nil))
                  ;; The backend expects :fg and :bg in the style-plist for drawing
                  (result (append (when fg-val `(:fg ,fg-val))
                                  (when bg-val `(:bg ,bg-val))
                                  (when attrs-val `(:attrs ,attrs-val)))))
             (log:debug "TRANSLATE-STYLES: Node ID: ~S, Extracted fg: ~S (from :color), bg: ~S (from :background-color), attrs: ~S. Result Plist: ~S"
                        node-id fg-val bg-val attrs-val result)
             result)))))

(defun render-node (node backend-instance)
  "Recursively renders a single laid-out UI node and its children."
  (when (and node (typep node 'ui-node))
    (let ((layout-rect (getf (ui-node-props node) :layout-rect)))
      (log:debug "OUTPUT: render-node - Type: ~S, ID: ~S, LayoutRect: ~S"
        (ui-node-type node) (getf (ui-node-props node) :id) layout-rect)
      (when (and layout-rect (typep layout-rect 'rectangle))
        (let* ((node-type (ui-node-type node))
                (props (ui-node-props node))
                (text (getf props :value ""))
                (style-plist (translate-styles-for-backend node))
                (pos-x (x layout-rect))
                (pos-y (y layout-rect))
                (width (w layout-rect))
                (height (h layout-rect)))

          ;; 1. Fill background for the entire layout-rect of the node
          (when (and (> width 0) (> height 0)) ; Only fill if node has dimensions
            (let ((bg-color (getf style-plist :bg)))
              (when bg-color ; Only fill if there's a background color specified
                (log:debug "OUTPUT: fill-rectangle (background) - Pos: (~A,~A), Size: (~A,~A), Style: ~S"
                  pos-y pos-x height width (list :bg bg-color))
                (fill-rectangle backend-instance pos-y pos-x height width :char #\Space :style (list :bg bg-color)))))

          ;; 2. Draw border (if any)
          (let ((border-s (style-value node :border-style :none))
                 (border-c (style-value node :border-color (getf style-plist :fg)))) ; Default border color to fg
            (when (and (not (eq border-s :none)) (> width 0) (> height 0))
              (log:debug "OUTPUT: draw-styled-box - Pos: (~A,~A), Size: (~A,~A), BorderStyle: ~S, BorderColor: ~S"
                pos-y pos-x height width border-s border-c)
              (draw-styled-box backend-instance pos-y pos-x height width
                :border-style border-s
                :border-color border-c
                ;; Pass general style-plist for other attributes like :bold for border if needed
                ;; but border-color in draw-styled-box takes precedence for line color.
                :style style-plist)))

          ;; 3. Render text content (if any)
          ;; Text is rendered within the content-box, so its position needs to be adjusted
          ;; if we consider padding/border for text. For now, text draws directly at layout-rect's origin.
          ;; This will be refined when padding affects content placement.
          (when (and (member node-type '(:text :text-input :list-item :p :h1 :h2 :h3 :button :label))
                  (> width 0) (> height 0)
                  (plusp (length text)))
            (let* ((pad-left (style-value node :padding-left 0))
                    (pad-top (style-value node :padding-top 0))
                    (border-width (if (eq (style-value node :border-style :none) :none) 0 1)) ; Simplified border width for now
                    (text-x (+ pos-x pad-left border-width))
                    (text-y (+ pos-y pad-top border-width))
                    (text-w (max 0 (- width (* 2 border-width) pad-left (style-value node :padding-right 0))))
                    (text-h (max 0 (- height (* 2 border-width) pad-top (style-value node :padding-bottom 0))))
                    (clipped-text (if (> (length text) text-w)
                                    (subseq text 0 (max 0 text-w)) ; Ensure non-negative length
                                    text)))
              (when (and (> text-w 0) (> text-h 0) (plusp (length clipped-text)))
                (log:debug "OUTPUT: draw-text-at - Pos: (~A,~A), Text: \"~A\", Style: ~S, ClipBox: (~A,~A,~A,~A)"
                  text-y text-x clipped-text style-plist text-x text-y text-w text-h)
                (draw-text-at backend-instance text-y text-x clipped-text :style style-plist)))))

        ;; 4. Recursively render children
        ;; Children are laid out within the content-box of this node.
        ;; Their layout-rects are relative to this node's layout-rect's origin.
        (dolist (child (ui-node-children node))
          (render-node child backend-instance))

        ;; 5. Draw debug outlines if enabled
        (when *debug-layout-outlines*
          (let* ((margin-top (style-value node :margin-top 0))
                  (margin-right (style-value node :margin-right 0))
                  (margin-bottom (style-value node :margin-bottom 0))
                  (margin-left (style-value node :margin-left 0))
                  (pad-top (style-value node :padding-top 0))
                  (pad-right (style-value node :padding-right 0))
                  (pad-bottom (style-value node :padding-bottom 0))
                  (pad-left (style-value node :padding-left 0))
                  (border-s (style-value node :border-style :none))
                  (bt-w (if (eq border-s :none) 0 (style-value node :border-top-width 0)))
                  (br-w (if (eq border-s :none) 0 (style-value node :border-right-width 0)))
                  (bb-w (if (eq border-s :none) 0 (style-value node :border-bottom-width 0)))
                  (bl-w (if (eq border-s :none) 0 (style-value node :border-left-width 0)))

                  (border-box layout-rect) ; layout-rect is the border-box
                  (margin-box (make-rectangle
                                :pos (make-pos :x (- (x border-box) margin-left)
                                       :y (- (y border-box) margin-top))
                                :size (make-size :w (+ (w border-box) margin-left margin-right)
                                        :h (+ (h border-box) margin-top margin-bottom))))
                  (padding-box (make-rectangle
                                 :pos (make-pos :x (+ (x border-box) bl-w)
                                        :y (+ (y border-box) bt-w))
                                 :size (make-size :w (max 0 (- (w border-box) bl-w br-w))
                                         :h (max 0 (- (h border-box) bt-w bb-w)))))
                  (content-box (make-rectangle
                                 :pos (make-pos :x (+ (x padding-box) pad-left)
                                        :y (+ (y padding-box) pad-top))
                                 :size (make-size :w (max 0 (- (w padding-box) pad-left pad-right))
                                         :h (max 0 (- (h padding-box) pad-top pad-bottom))))))

            ;; Draw Margin Box (e.g., red)
            (draw-styled-box backend-instance (y margin-box) (x margin-box) (h margin-box) (w margin-box)
              :border-style :single :border-color :red :style '(:fg :red))
            ;; Border box is already drawn by main border rendering, or use a different color if needed
            ;; (draw-styled-box backend-instance (y border-box) (x border-box) (h border-box) (w border-box)
            ;;                  :border-style :single :border-color :yellow :style '(:fg :yellow))
            ;; Draw Padding Box (e.g., green)
            (draw-styled-box backend-instance (y padding-box) (x padding-box) (h padding-box) (w padding-box)
              :border-style :single :border-color :green :style '(:fg :green))
            ;; Draw Content Box (e.g., blue)
            (draw-styled-box backend-instance (y content-box) (x content-box) (h content-box) (w content-box)
              :border-style :single :border-color :blue :style '(:fg :blue))))))))

(defun call-with-errors-log (fn &rest args)
  "Call FN with ARGS, logging any errors to errors.log."
  (handler-case (apply #'funcall (append (list fn) args))
    (error (c)
      (progn
        (log-info "Error in thread: ~a~%"
          (sb-thread:thread-name sb-thread:*current-thread*))
        (log-info "Args: ~a~%" args)
        (log-info "Fn: ~a~%" fn)
        (log-info "Backtrace: ~a~%"
          (sb-debug:print-backtrace :print-frame-source t )
          ;; (with-output-to-string (o)
          ;;   (sb-debug:print-backtrace :stream o :print-frame-source t))
          )
        (invoke-debugger c)))))

(defun render-frame (laid-out-root-node backend-instance)
  (call-with-errors-log #'render-frame-in laid-out-root-node backend-instance))

(defun render-frame-in (laid-out-root-node backend-instance)
  "Renders the complete, laid-out UI tree to the terminal using the backend.
   LAID-OUT-ROOT-NODE: The root node returned by layout-tree.
   BACKEND-INSTANCE: The initialized platform backend."
  (log:info "OUTPUT: render-frame initiated for root node ID: ~S"
    (if laid-out-root-node (getf (ui-node-props laid-out-root-node) :id) "NIL_ROOT"))
  (when backend-instance
    (handler-case
      (progn
        (log:debug "OUTPUT: Clearing screen.")
        (clear-screen backend-instance) ; Uncommented
        (log:debug "OUTPUT: Rendering node tree.")
        (render-node laid-out-root-node backend-instance)
        (log:debug "OUTPUT: Flushing output.")
        (flush-output backend-instance)
        (log:info "OUTPUT: render-frame completed."))
      (error (e)
        (log:error "OUTPUT: Error during render-frame: ~A" e)
        (ignore-errors
          (clear-screen backend-instance)
          (draw-text-at backend-instance 0 0 (format nil "Render Error: ~A" e) :style '(:fg "red"))
          (flush-output backend-instance))))))
