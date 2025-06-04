;;;===============================================================
;;; File: src/platform/output.lisp
;;; UI Tree Rendering to Backend Buffers
;;;===============================================================
(uiop:define-package :elmtui.platform.output
  (:use :cl :alexandria) ; Added alexandria if you use its functions like 'if-let' or 'when-let'
  (:import-from :log4cl #:log-debug #:log-info #:log-error #:log-warn)
  (:import-from :elmtui.core.globals #:*debug-layout-outlines*)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h #:make-size #:make-pos #:make-rectangle)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value #:apply-stylesheet-to-tree)
  (:import-from :elmtui.style-lib.api #:styles #:style-set) ; Ensure this is correct for your style system
  (:import-from :elmtui.platform.api
                #:draw-text-at #:fill-rectangle #:draw-styled-box
                ;; Add other API drawing functions if used by render-node-recursive
                #:draw-char-at) ; Example if you add more detailed drawing
  (:export :render-frame))
(in-package :elmtui.platform.output)

(defun translate-styles-for-backend (node)
  "Extracts relevant style properties from a styled-ui-node and translates
   them into a plist suitable for the backend's drawing functions.
   Returns NIL if node is not styled or has no relevant styles."
  (when (typep node 'styled-ui-node)
    (let* ((node-id (getf (ui-node-props node) :id "N/A"))
           (style-set-obj (elmtui.style-lib.api:styles node)))
      (unless (typep style-set-obj 'elmtui.style-lib.api:style-set)
        (log:warn "TRANSLATE-STYLES: Node ID: ~S - (styles node) did not return a style-set. Type: ~A. Using no styles."
                  node-id (type-of style-set-obj))
        (return-from translate-styles-for-backend nil))

      (let* ((fg-val (style-value node :color nil))
             (bg-val (style-value node :background-color nil))
             (attrs-val (style-value node :attributes nil))
             (result nil))
        (when fg-val (push fg-val result) (push :fg result))
        (when bg-val (push bg-val result) (push :bg result))
        (when attrs-val (push attrs-val result) (push :attrs result))
        (nreverse result)))))

(defun render-node-recursive (node backend-instance target-buffer)
  "Recursively renders a single laid-out UI node and its children."
  (when (and node (typep node 'ui-node))
    (let ((layout-rect (getf (ui-node-props node) :layout-rect)))
      (log:debug "OUTPUT: render-node - Type: ~S, ID: ~S, LayoutRect: ~S"
                 (ui-node-type node) (getf (ui-node-props node) :id "N/A") layout-rect)

      (unless (and layout-rect (typep layout-rect 'rectangle))
        (log:warn "OUTPUT: Skipping node ID ~S, Type ~S due to missing or invalid layout-rect."
                  (getf (ui-node-props node) :id "N/A") (ui-node-type node))
        (return-from render-node-recursive))

      (let* ((node-type (ui-node-type node))
             (props (ui-node-props node))
             (style-plist (translate-styles-for-backend node))
             (pos-x (x layout-rect))
             (pos-y (y layout-rect))
             (width (w layout-rect))
             (height (h layout-rect)))

        (when (and (> width 0) (> height 0)
                   (not (eq (style-value node :visibility :visible) :hidden))
                   (not (eq (style-value node :display :block) :none)))

          (let ((bg-color (getf style-plist :bg)))
            (when bg-color
              (fill-rectangle backend-instance target-buffer pos-y pos-x height width :char #\Space :style (list :bg bg-color))))

          (let* ((border-s (style-value node :border-style :none))
                 (border-color-val (style-value node :border-color nil))
                 (effective-border-color (or border-color-val (getf style-plist :fg))))
            (when (and (not (eq border-s :none)))
              (draw-styled-box backend-instance target-buffer pos-y pos-x height width
                               :border-style border-s
                               :border-color effective-border-color
                               :style style-plist)))

          (let* ((pad-top (style-value node :padding-top 0))
                 (pad-right (style-value node :padding-right 0))
                 (pad-bottom (style-value node :padding-bottom 0))
                 (pad-left (style-value node :padding-left 0))
                 (border-s (style-value node :border-style :none))
                 (bt-w (if (eq border-s :none) 0 (or (style-value node :border-top-width) (style-value node :border-width 1))))
                 (br-w (if (eq border-s :none) 0 (or (style-value node :border-right-width) (style-value node :border-width 1))))
                 (bb-w (if (eq border-s :none) 0 (or (style-value node :border-bottom-width) (style-value node :border-width 1))))
                 (bl-w (if (eq border-s :none) 0 (or (style-value node :border-left-width) (style-value node :border-width 1))))
                 (content-x (+ pos-x bl-w pad-left))
                 (content-y (+ pos-y bt-w pad-top))
                 (content-w (max 0 (- width bl-w br-w pad-left pad-right)))
                 (content-h (max 0 (- height bt-w bb-w pad-top pad-bottom))))

            (when (and (member node-type '(:text :text-input :list-item :p :h1 :h2 :h3 :button :label))
                       (> content-w 0) (> content-h 0))
              (let ((text (getf props :value "")))
                (when (plusp (length text))
                  (let ((clipped-text (if (> (length text) content-w)
                                          (subseq text 0 content-w)
                                          text))
                        (text-style (list :fg (getf style-plist :fg)
                                          :attrs (getf style-plist :attrs))))
                    (draw-text-at backend-instance target-buffer content-y content-x clipped-text :style text-style))))))

          (dolist (child (ui-node-children node))
            (render-node-recursive child backend-instance target-buffer))

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
                   (bt-w (if (eq border-s :none) 0 (or (style-value node :border-top-width) (style-value node :border-width 1))))
                   (br-w (if (eq border-s :none) 0 (or (style-value node :border-right-width) (style-value node :border-width 1))))
                   (bb-w (if (eq border-s :none) 0 (or (style-value node :border-bottom-width) (style-value node :border-width 1))))
                   (bl-w (if (eq border-s :none) 0 (or (style-value node :border-left-width) (style-value node :border-width 1))))

                   (border-box layout-rect)
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

              (ignore-errors
               (draw-styled-box backend-instance target-buffer (y margin-box) (x margin-box) (h margin-box) (w margin-box)
                                :border-style :single :border-color :red)
               (draw-styled-box backend-instance target-buffer (y padding-box) (x padding-box) (h padding-box) (w padding-box)
                                :border-style :single :border-color :green)
               (draw-styled-box backend-instance target-buffer (y content-box) (x content-box) (h content-box) (w content-box)
                                :border-style :single :border-color :blue)))))))))

 (defun render-frame (laid-out-root-node backend-instance target-buffer &optional stylesheet)
  "Renders the complete, laid-out UI tree to the backend.
   LAID-OUT-ROOT-NODE: The root node returned by layout-tree.
   BACKEND-INSTANCE: The initialized platform backend.
   TARGET-BUFFER: Conceptually represents the backend's drawing target;
                  the backend's drawing primitives will use this implicitly or explicitly."
  (log:info "OUTPUT: render-frame initiated for root node ID: ~S"
            (if laid-out-root-node (getf (ui-node-props laid-out-root-node) :id "NIL_ROOT") "NIL_ROOT"))
  (when backend-instance
    (handler-case
        (let ((tree (if stylesheet
                        (apply-stylesheet-to-tree laid-out-root-node stylesheet)
                        laid-out-root-node)))
          (log:debug "OUTPUT: Rendering styled node tree.")
          (render-node-recursive tree backend-instance target-buffer)
          (log:info "OUTPUT: render-frame drawing calls completed."))
      (error (e)
        (log:error "OUTPUT: Error during render-frame's drawing calls: ~A~%Backtrace: ~A" e
                   #+sbcl (with-output-to-string (s) (sb-debug:print-backtrace :stream s :count 15 :print-frame-source t))
                   #-sbcl "Backtrace not available.")
        (ignore-errors ; Minimal error display on terminal if possible
         ;; Consider if clear-screen and flush-output are appropriate here,
         ;; or if the backend should handle error display.
         (elmtui.platform.api:clear-screen backend-instance) ; Assuming clear-screen is in API
         (elmtui.platform.api:draw-text-at backend-instance target-buffer 0 0 (format nil "Render Error: ~A" e) :style '(:fg "red" :bg "black"))
         (elmtui.platform.api:flush-output backend-instance)))))) ; Assuming flush-output is in API
