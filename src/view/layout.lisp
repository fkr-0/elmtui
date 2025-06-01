;;;===============================================================
;;; File: src/view/layout.lisp
;;; Top-Level Layout Pass & Flexbox/Block Layout
;;;===============================================================
(uiop:define-package :elmtui.view.layout
  (:use :cl :elmtui.view.core) ; Keep core for ui-node structure access
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  ;; Import necessary symbols
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:make-rectangle #:make-pos #:make-size
                #:rectangle-pos #:rectangle-size #:copy-rectangle
                #:clamp) ; Import clamp if not already available
  (:import-from :elmtui.view.layout.flex
                #:flex-item #:flex-container #:layout-flex-container
                #:flex-item-children #:main-axis #:flex-wrap #:justify-content
                #:align-items #:align-content #:order #:flex-grow #:flex-shrink
                #:flex-basis #:align-self)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:style-value #:apply-stylesheet-to-tree
                #:copy-styled-node #:styles)
  ;; Grid layout function will be called via generic dispatch
  ;; (:import-from :elmtui.view.layout.grid #:layout-grid-container)
                                        ; Import grid layout
  (:export :layout-tree ; New top-level function
   :dispatch-layout ; Export the generic function
   ;; Keep old exports for now, maybe deprecate later
           :layout-vbox
   :layout-hbox
           :layout-grid-container-impl
   :layout-grid))
(in-package :elmtui.view.layout)

;;;-----------------------------------------------------------------------------
;;; Helper: Styled Node -> Flex Item Conversion
;;;-----------------------------------------------------------------------------
(defgeneric layout-grid-container-impl (grid-container-node available-rect))
(defun styled-node->flex-item (styled-node)
  "Convert a styled-ui-node into a flex-item instance.
   Extracts layout properties EXCLUSIVELY from computed styles."
  (let* ((raw-initial-w (style-value styled-node :width :auto))
         (raw-initial-h (style-value styled-node :height :auto))
         ;; Ensure initial-w and initial-h for make-size are numeric.
         ;; Keywords like :auto, :fill will be handled by flex-basis or layout algorithm.
         (numeric-initial-w (if (integerp raw-initial-w) raw-initial-w 0))
         (numeric-initial-h (if (integerp raw-initial-h) raw-initial-h 0))
         (initial-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                       :size (make-size :w numeric-initial-w :h numeric-initial-h)))
         ;; Extract flex properties from styles
         (order (style-value styled-node :order 0))
         (flex-grow (style-value styled-node :flex-grow 0))
         (flex-shrink (style-value styled-node :flex-shrink 1))
         (flex-basis (style-value styled-node :flex-basis nil)) ; nil means auto/use initial size
         (align-self (style-value styled-node :align-self nil)) ; nil means inherit/auto
         ;; Extract min/max constraints from styles
         (min-w (style-value styled-node :min-width 0))
         (max-w (style-value styled-node :max-width most-positive-fixnum))
         (min-h (style-value styled-node :min-height 0))
         (max-h (style-value styled-node :max-height most-positive-fixnum))
         ;; Extract margins from styles
         (margin-top (style-value styled-node :margin-top 0))
         (margin-right (style-value styled-node :margin-right 0))
         (margin-bottom (style-value styled-node :margin-bottom 0))
         (margin-left (style-value styled-node :margin-left 0)))

    (make-instance 'flex-item
                   :rectangle initial-rect
                   :order order
                   :flex-grow flex-grow
                   :flex-shrink flex-shrink
                   :flex-basis flex-basis
                   :align-self align-self
                   :min-width min-w
                   :max-width max-w
                   :min-height min-h
                   :max-height max-h
                   :margin-top margin-top
                   :margin-right margin-right
                   :margin-bottom margin-bottom
                   :margin-left margin-left
                   ;; :child-container is NOT set here. Nested layout is handled by layout-tree recursion.
                   )))

;;;-----------------------------------------------------------------------------
;;; Flexbox Layout for Children
;;;-----------------------------------------------------------------------------

(defun layout-flex-children (container-styled-node available-rect)
  "Layout the children of CONTAINER-STYLED-NODE using flexbox within AVAILABLE-RECT.
   Returns a list of *new* laid-out child nodes, and the collective
   width and height occupied by these children within available-rect."
  (unless (and available-rect (typep available-rect 'rectangle))
    (error "layout-flex-children requires a valid available-rect."))

  (let* ((children (ui-node-children container-styled-node))
         (styled-children (if (every #'(lambda (n) (typep n 'styled-ui-node)) children)
                              children
                              (progn (warn "Non-styled node found in flex container children.")
                                     children))) ; Should not happen in correct pipeline
         (main-axis (style-value container-styled-node :flex-direction :row))
         (justify-content (style-value container-styled-node :justify-content :flex-start))
         (align-items (style-value container-styled-node :align-items :stretch))
         (align-content (style-value container-styled-node :align-content :stretch))
         (flex-wrap (style-value container-styled-node :flex-wrap :nowrap))

         ;; Extract padding and border to calculate content rect properly
         (padding (or (style-value container-styled-node :padding)
                      (list :top (style-value container-styled-node :padding-top 0)
                            :right (style-value container-styled-node :padding-right 0)
                            :bottom (style-value container-styled-node :padding-bottom 0)
                            :left (style-value container-styled-node :padding-left 0))))
         (border-style (style-value container-styled-node :border-style :none))
         (border-width (if (eq border-style :none)
                           0
                           (or (style-value container-styled-node :border-width 1) ; Default to 1 if style but no width
                               (list :top (style-value container-styled-node :border-top-width 1)
                                     :right (style-value container-styled-node :border-right-width 1)
                                     :bottom (style-value container-styled-node :border-bottom-width 1)
                                     :left (style-value container-styled-node :border-left-width 1)))))

         ;; Calculate content rect to position children correctly
         (content-rect (calculate-content-rect available-rect padding border-width)) ; This is the flex container's bounds
         (flex-items (mapcar #'styled-node->flex-item children)))
    (declare (type rectangle content-rect) (ignorable styled-children))
    (log:debug "LAYOUT: layout-flex-children - Container ID: ~S, Content Rect: ~S"
               (getf (ui-node-props container-styled-node) :id) content-rect)

    (let ((container (make-instance 'flex-container
                                    :rectangle (copy-rectangle content-rect)
                                    :children flex-items
                                    :main-axis main-axis
                                    :justify-content justify-content
                                    :align-items align-items
                                    :align-content align-content
                                    :flex-wrap flex-wrap)))
      (layout-flex-container container) ; This updates flex-item rectangles relative to content-rect

      (let ((laid-out-children-list nil)
            (min-item-x most-positive-fixnum) (min-item-y most-positive-fixnum)
            (max-item-x most-negative-fixnum) (max-item-y most-negative-fixnum)
            (has-items nil))

        (loop for flex-item in flex-items
              for original-child in children ; Assuming children are already styled-ui-nodes
              do
                 (setf has-items t)
                 (let* ((item-relative-rect (rectangle flex-item))
                        ;; Make item-rect absolute for the child node
                        (abs-pos-x (+ (x content-rect) (x item-relative-rect)))
                        (abs-pos-y (+ (y content-rect) (y item-relative-rect)))
                        (item-abs-rect (make-rectangle
                                        :pos (make-pos :x abs-pos-x :y abs-pos-y)
                                        :size (size item-relative-rect)))
                        (new-child (copy-styled-node original-child)))

                   ;; Store final absolute layout rect in props
                   (setf (getf (ui-node-props new-child) :layout-rect) item-abs-rect)
                   (setf (getf (ui-node-props new-child) :x) (x item-abs-rect))
                   (setf (getf (ui-node-props new-child) :y) (y item-abs-rect))
                   (setf (getf (ui-node-props new-child) :width) (w item-abs-rect))
                   (setf (getf (ui-node-props new-child) :height) (h item-abs-rect))

                   ;; RECURSE: layout the child node's subtree using its determined absolute rect
                   (let ((recursed-child (layout-node new-child item-abs-rect)))
                     (push recursed-child laid-out-children-list)

                     ;; Update bounds based on the item's relative rect for content size calculation
                     (setf min-item-x (min min-item-x (x item-relative-rect)))
                     (setf min-item-y (min min-item-y (y item-relative-rect)))
                     (setf max-item-x (max max-item-x (+ (x item-relative-rect) (w item-relative-rect))))
                     (setf max-item-y (max max-item-y (+ (y item-relative-rect) (h item-relative-rect)))))))

        (let ((children-content-w (if has-items (max 0 (- max-item-x min-item-x)) 0))
              (children-content-h (if has-items (max 0 (- max-item-y min-item-y)) 0)))
          (log:debug "LAYOUT: layout-flex-children for ~S - Children Content WxH: ~Ax~A"
                     (getf (ui-node-props container-styled-node) :id)
                     children-content-w children-content-h)
          (values (nreverse laid-out-children-list)
                  children-content-w
                  children-content-h))))))

;;;-----------------------------------------------------------------------------
;;; Helper: Calculate Content Rect (Inner area after padding/border)
;;;-----------------------------------------------------------------------------

(defun calculate-content-rect (box-rect padding border-width)
  "Calculate the content rectangle given the box rectangle, padding, and border width.
   BOX-RECT: The border-box rectangle (outermost box including borders)
   PADDING: Padding value (integer or plist with :top, :right, :bottom, :left)
   BORDER-WIDTH: Border width (integer or plist with :top, :right, :bottom, :left)
   Returns a rectangle representing the content box."
  (let ((pad-top    (if (integerp padding) padding (getf padding :top 0)))
        (pad-right  (if (integerp padding) padding (getf padding :right 0)))
        (pad-bottom (if (integerp padding) padding (getf padding :bottom 0)))
        (pad-left   (if (integerp padding) padding (getf padding :left 0)))
        (bw-top     (if (integerp border-width) border-width (getf border-width :top 0)))
        (bw-right   (if (integerp border-width) border-width (getf border-width :right 0)))
        (bw-bottom  (if (integerp border-width) border-width (getf border-width :bottom 0)))
        (bw-left    (if (integerp border-width) border-width (getf border-width :left 0))))

    (make-rectangle
     :pos (make-pos :x (+ (x box-rect) pad-left bw-left)
                    :y (+ (y box-rect) pad-top bw-top))
     :size (make-size :w (- (w box-rect) pad-left pad-right bw-left bw-right)
                      :h (- (h box-rect) pad-top pad-bottom bw-top bw-bottom)))))

(defun position-child-in-parent (parent-content-rect child style)
  "Position a child node within its parent's content rectangle.
   PARENT-CONTENT-RECT: The parent's content rectangle
   CHILD: The child node to position
   STYLE: The child's style
   Returns the child's border-box rectangle."
  (let* ((margin (getf style :margin 0))
         ;; Handle margin extraction properly depending on whether it's an integer or plist
         (margin-top    (if (integerp margin) margin (getf margin :top 0)))
         (margin-right  (if (integerp margin) margin (getf margin :right 0)))
         (margin-bottom (if (integerp margin) margin (getf margin :bottom 0)))
         (margin-left   (if (integerp margin) margin (getf margin :left 0)))

         ;; Get available space within parent
         (available-width (max 0 (- (w parent-content-rect) margin-left margin-right)))
         (available-height (max 0 (- (h parent-content-rect) margin-top margin-bottom)))

         ;; Handle width/height from style, with fallbacks
         (child-width-value (getf style :width))
         (child-height-value (getf style :height))

         ;; Calculate final width and height
         (child-width (cond
                        ((integerp child-width-value) child-width-value)
                        ((eq child-width-value :fill) available-width)
                        ((eq child-width-value :auto)
                         (or (getf (ui-node-props child) :intrinsic-width) ; Use intrinsic if present
                             available-width)) ; Fall back to available space
                        (t available-width))) ; Default to available

         (child-height (cond
                         ((integerp child-height-value) child-height-value)
                         ((eq child-height-value :fill) available-height)
                         ((eq child-height-value :auto)
                          (or (getf (ui-node-props child) :intrinsic-height) ; Use intrinsic if present
                              available-height)) ; Fall back to available space
                         (t available-height))) ; Default to available

         ;; Apply min/max constraints
         (min-width (getf style :min-width 0))
         (max-width (getf style :max-width most-positive-fixnum))
         (min-height (getf style :min-height 0))
         (max-height (getf style :max-height most-positive-fixnum))
         (final-width (clamp child-width min-width max-width))
         (final-height (clamp child-height min-height max-height)))

    ;; Create and return the child's box rectangle positioned within the parent
    (make-rectangle
     :pos (make-pos :x (+ (x parent-content-rect) margin-left)
                    :y (+ (y parent-content-rect) margin-top))
     :size (make-size :w final-width
                      :h final-height))))

(defun layout-flex-children-row (parent-content-rect children)
  "Layout children in a row within the parent's content rectangle.
   PARENT-CONTENT-RECT: The parent's content rectangle
   CHILDREN: List of (child, style) pairs
   Returns a list of (child, layout-rect) pairs."
  (let ((current-x (x parent-content-rect))
        (results nil))

    (dolist (child-data children)
      (destructuring-bind (child style) child-data
        (let* ((margin (getf style :margin 0))
               ;; Fix margin extraction to use proper keys
               (margin-left   (if (integerp margin) margin (getf margin :left 0)))
               (margin-right  (if (integerp margin) margin (getf margin :right 0)))
               (margin-top    (if (integerp margin) margin (getf margin :top 0)))
               (child-width  (getf style :width 0))
               (child-height (getf style :height 0))
               (child-rect (make-rectangle
                            :pos (make-pos :x (+ current-x margin-left)
                                           :y (+ (y parent-content-rect) margin-top))
                            :size (make-size :w child-width
                                             :h child-height))))

          ;; Update for next child
          (setf current-x (+ (x child-rect) child-width margin-right))

          ;; Add to results
          (push (list child child-rect) results))))

    (nreverse results)))

;;;-----------------------------------------------------------------------------
;;; Block Layout for Children
;;;-----------------------------------------------------------------------------

(defun layout-block-children (container-styled-node available-content-rect)
  "Layout children vertically within the available content rectangle, accounting for margins.
   Returns a list of new laid-out child nodes and the total height used by them (including their margins)."
  (let ((laid-out-children '())
        (current-y (y available-content-rect)) ; Start at the top of the parent's content area
        (max-child-width 0)
        (previous-child-margin-bottom 0))
    (log:debug "LAYOUT: layout-block-children - Container ID: ~S, Available Content Rect: ~S"
               (getf (ui-node-props container-styled-node) :id) available-content-rect)

    ;; Extract padding and border to ensure correct content rect positioning
    (let* ((padding (or (style-value container-styled-node :padding)
                        (list :top (style-value container-styled-node :padding-top 0)
                              :right (style-value container-styled-node :padding-right 0)
                              :bottom (style-value container-styled-node :padding-bottom 0)
                              :left (style-value container-styled-node :padding-left 0))))
           (border-style (style-value container-styled-node :border-style :none))
           (border-width (if (eq border-style :none)
                             0
                             (or (style-value container-styled-node :border-width 1) ; Default to 1 if style but no width
                                 (list :top (style-value container-styled-node :border-top-width 1)
                                       :right (style-value container-styled-node :border-right-width 1)
                                       :bottom (style-value container-styled-node :border-bottom-width 1)
                                       :left (style-value container-styled-node :border-left-width 1))))))
      (declare (ignore padding border-width))
      (loop for child-node in (ui-node-children container-styled-node)
            do
               (log:debug "LAYOUT-BLOCK-CHILDREN: Processing child of ~S -> ID: ~S, Type: ~A"
                          (getf (ui-node-props container-styled-node) :id)
                          (if (typep child-node 'ui-node) (getf (ui-node-props child-node) :id) "N/A")
                          (type-of child-node))

               (unless (typep child-node 'styled-ui-node)
                 (log:warn "LAYOUT-BLOCK-CHILDREN: Skipping non-styled-ui-node child: ~S" child-node)
                 (continue))

               (when (typep child-node 'styled-ui-node)
                 (let* ((child-margin-top (style-value child-node :margin-top 0))
                        (child-margin-bottom (style-value child-node :margin-bottom 0))
                        (child-margin-left (style-value child-node :margin-left 0))
                        (child-margin-right (style-value child-node :margin-right 0))

                        ;; Effective Y start for this child's margin-box
                        ;; For block layout, collapse vertical margins (max of prev-bottom and current-top)
                        (effective-margin-spacing (max previous-child-margin-bottom child-margin-top))

                        ;; Child's border-box starting position
                        (child-start-y-corrected (if (null laid-out-children)
                                                     (+ current-y child-margin-top) ; First child
                                                     (+ current-y effective-margin-spacing))) ; Subsequent children with margin collapsing

                        ;; Available space for this child's border-box
                        (child-border-box-available-x (+ (x available-content-rect) child-margin-left))
                        (child-border-box-available-y child-start-y-corrected)
                        (child-border-box-available-width (max 0 (- (w available-content-rect) child-margin-left child-margin-right)))
                        (child-border-box-available-height (max 0 (- (+ (y available-content-rect) (h available-content-rect))
                                                                     child-border-box-available-y)))

                        (child-available-rect-for-layout (make-rectangle
                                                          :pos (make-pos :x child-border-box-available-x
                                                                         :y child-border-box-available-y)
                                                          :size (make-size :w child-border-box-available-width
                                                                           :h child-border-box-available-height)))

                        (laid-out-child (layout-node child-node child-available-rect-for-layout))
                        (child-layout-rect (when laid-out-child (getf (ui-node-props laid-out-child) :layout-rect))))

                   (when laid-out-child
                     (unless child-layout-rect (error "Laid-out child missing :layout-rect"))

                     (push laid-out-child laid-out-children)

                     ;; Advance current-y by the height of the child's border-box plus its bottom margin
                     (setf current-y (+ (y child-layout-rect) (h child-layout-rect) child-margin-bottom))
                     (setf previous-child-margin-bottom child-margin-bottom)

                     ;; Track the maximum width used by children (including their horizontal margins)
                     (setf max-child-width (max max-child-width (+ child-margin-left (w child-layout-rect) child-margin-right)))))))

      (values (nreverse laid-out-children)
              (- current-y (y available-content-rect))
              max-child-width)))) ; Max width including horizontal margins

;;;-----------------------------------------------------------------------------
;;; Top-Level Recursive Layout Function & Dispatch
;;;-----------------------------------------------------------------------------

(defgeneric dispatch-layout (display node available-rect)
  (:documentation "Dispatch layout calculation based on display type.
                   Returns a list of laid-out children and their collective width/height."))

(defun layout-node (node available-rect)
  "Calculate layout for a single styled node within available-rect.
   Handles layout of children by dispatching based on display type.
   Returns a new node with layout information."
  (unless (typep node 'styled-ui-node)
    (log:warn "LAYOUT: layout-node called on non-styled-node: ~A. Skipping." node)
    (return-from layout-node nil))
  (unless (typep available-rect 'rectangle)
    (error "LAYOUT: layout-node requires a valid available-rect. Got: ~S" available-rect))

  (log:debug "LAYOUT: layout-node - Node Type: ~S, ID: ~S, Display: ~S, Available Rect: ~S"
             (ui-node-type node) (getf (ui-node-props node) :id)
             (style-value node :display :block) available-rect)

  (let* ((display (style-value node :display :block))
         ;; Calculate rect available *for this node* (initially same as available-rect)
         ;; Position will be adjusted by parent's layout logic later.
         (node-rect (copy-rectangle available-rect))
         ;; Extract padding and border values from the node's style
         (padding (or (style-value node :padding)
                      (list :top (style-value node :padding-top 0)
                            :right (style-value node :padding-right 0)
                            :bottom (style-value node :padding-bottom 0)
                            :left (style-value node :padding-left 0))))
         (border-style (style-value node :border-style :none))
         (border-width (if (eq border-style :none)
                           0
                           (or (style-value node :border-width)
                               (list :top (style-value node :border-top-width 0)
                                     :right (style-value node :border-right-width 0)
                                     :bottom (style-value node :border-bottom-width 0)
                                     :left (style-value node :border-left-width 0)))))
         ;; Calculate inner content area based on *this node's* padding/border
         (content-rect (calculate-content-rect node-rect padding border-width)))
    (log:debug "LAYOUT: layout-node - Node ID: ~S, Computed Content-Rect: ~S"
               (getf (ui-node-props node) :id) content-rect)
    (let* ( (laid-out-children nil)
            (children-height 0)
            (children-width 0))

      ;; 1. Layout Children using generic dispatch
      (multiple-value-bind (result-children height width)
          (dispatch-layout display node content-rect)
        (setf laid-out-children result-children)
        (setf children-height height)
        (setf children-width width))

      ;; 2. Determine Self Size based on styles and children
      (let* ((styled-w (style-value node :width :auto))
             (styled-h (style-value node :height :auto))

             (pad-left (style-value node :padding-left 0))
             (pad-right (style-value node :padding-right 0))
             (pad-top (style-value node :padding-top 0))
             (pad-bottom (style-value node :padding-bottom 0))
             ;; Simplified border width calculation for self-sizing.
             ;; Assumes uniform border if :border-style is not :none.
             (border-s (style-value node :border-style :none))
             (bw (if (eq border-s :none) 0 (or (style-value node :border-width) 1))) ; Use :border-width or default to 1
             
             (horizontal-padding-and-border (+ pad-left pad-right (* 2 bw)))
             (vertical-padding-and-border (+ pad-top pad-bottom (* 2 bw)))

             ;; Calculate final width
             (final-w (cond ((integerp styled-w) styled-w)
                            ((eq styled-w :auto)
                             ;; children-width is the content width from dispatch-layout
                             (+ children-width horizontal-padding-and-border))
                            ;; Add :fill if you intend to support it explicitly
                            ;; ((eq styled-w :fill) (w available-rect))
                            (t (w available-rect)))) ; Default fallback (e.g. for block taking available width)

             ;; Calculate final height
             (final-h (cond ((integerp styled-h) styled-h)
                            ((eq styled-h :auto)
                             ;; children-height is the content height from dispatch-layout
                             (+ children-height vertical-padding-and-border))
                            ;; ((eq styled-h :fill) (h available-rect))
                            (t (h available-rect)))))
        (when (eq (ui-node-type node) :list-item)
          (log:debug "LAYOUT: :list-item styled-h=~S children-height=~S vertical-padding=~S props=~S styles=~S"
                     styled-h children-height vertical-padding-and-border (ui-node-props node)
                     (if (typep node 'styled-ui-node) (styles node) nil)))
        ;; Apply min/max constraints
        (setf final-w (clamp final-w (style-value node :min-width 0)
                             (style-value node :max-width most-positive-fixnum)))
        (setf final-h (clamp final-h (style-value node :min-height 0)
                             (style-value node :max-height most-positive-fixnum)))

        ;; 3. Determine Self Position (Relative to parent's content-rect)
        ;; The actual final position is set by the PARENT's layout logic.
        ;; We store the size here, position is initially (0,0) relative to available-rect.
        (let ((final-x (x available-rect))
              (final-y (y available-rect)))

          ;; 4. Create/Update Node with Layout Info
          (let ((new-node (copy-styled-node node)))
            (setf (ui-node-children new-node) laid-out-children)
            (let ((final-layout-rect (make-rectangle :pos (make-pos :x final-x :y final-y)
                                                     :size (make-size :w final-w :h final-h))))
              (setf (getf (ui-node-props new-node) :layout-rect) final-layout-rect)
              ;; Update individual props for convenience? (Optional)
              (setf (getf (ui-node-props new-node) :x) final-x)
              (setf (getf (ui-node-props new-node) :y) final-y)
              (setf (getf (ui-node-props new-node) :width) final-w)
              (setf (getf (ui-node-props new-node) :height) final-h)
              (log:debug "LAYOUT: layout-node result for ID ~S - Final Rect: ~S"
                         (getf (ui-node-props new-node) :id)
                         final-layout-rect)
              (log:debug "LAYOUT: layout-node PRE-RETURN for ID ~S - Final Rect: ~S, Props: ~S"
                         (getf (ui-node-props new-node) :id)
                         final-layout-rect
                         (ui-node-props new-node))
              new-node)))))))


;; --- Default layout method (handles unknown display types like block) ---
(defmethod dispatch-layout (display node available-rect)
  ;; (declare (ignore display))
  (log:debug "LAYOUT: dispatch-layout (default/block) for ~S, Display: ~S, Available: ~S"
             (getf (ui-node-props node) :id) display available-rect)
                                        ; Treat unknown as block
  (layout-block-children node available-rect))

;; --- Flex layout method ---
(defmethod dispatch-layout ((display (eql :flex)) node available-rect)
  (log:debug "LAYOUT: dispatch-layout (:flex) for ~S, Available: ~S"
             (getf (ui-node-props node) :id) available-rect)
  (multiple-value-bind (laid-children content-w content-h)
      (layout-flex-children node available-rect)
    (values laid-children content-w content-h)))

;; --- Block layout method ---
(defmethod dispatch-layout ((display (eql :block)) node available-rect)
  (log:debug "LAYOUT: dispatch-layout (:block) for ~S, Available: ~S"
             (getf (ui-node-props node) :id) available-rect)
  (layout-block-children node available-rect))

;; --- ListBox layout method (Treat as block for now) ---
;; Children (list items) are laid out like block elements vertically.
(defmethod dispatch-layout ((display (eql :list-box)) node available-rect)
  (log:debug "LAYOUT: dispatch-layout (:list-box treated as :block) for ~S, Available: ~S"
             (getf (ui-node-props node) :id) available-rect)
  (layout-block-children node available-rect))

;; --- ListItem layout method (Treat as block for now) ---
;; Children (usually just text) are laid out like block elements.
(defmethod dispatch-layout ((display (eql :list-item)) node available-rect)
  (log:debug "LAYOUT: dispatch-layout (:list-item treated as :block) for ~S, Available: ~S"
             (getf (ui-node-props node) :id) available-rect)
  (layout-block-children node available-rect))

;; --- Inline layout method (stub) ---
(defmethod dispatch-layout ((display (eql :inline)) node available-rect)
  (declare (ignore node available-rect))
  (warn ":inline layout not implemented")
  (values nil 0 0))

;; --- None layout method ---
(defmethod dispatch-layout ((display (eql :none)) node available-rect)
  (declare (ignore node available-rect))
  (values nil 0 0))

;; --- Grid layout method ---
;; (defmethod dispatch-layout ((display (eql :grid)) node available-rect)
;;   (log:debug "LAYOUT: dispatch-layout (:grid) for ~S, Available: ~S"
;;              (getf (ui-node-props node) :id) available-rect)
;;   ;; Calls the main grid layout function from the grid package
;;   (layout-grid-container-impl node available-rect))


;;;-----------------------------------------------------------------------------
;;; Top-Level Entry Point
;;;-----------------------------------------------------------------------------

(defun layout-tree (styled-root-node screen-rect)
  "Top-level entry point for layout. Takes the root of the styled node tree
   and the total available screen rectangle."
  (log:info "LAYOUT: Starting layout-tree for root node ID: ~S, Screen Rect: ~S"
            (getf (ui-node-props styled-root-node) :id) screen-rect)
  (unless (typep styled-root-node 'styled-ui-node)
    (error "layout-tree requires a styled-ui-node tree root."))
  (unless (typep screen-rect 'rectangle)
    (error "layout-tree requires a valid screen-rect."))
  ;; Layout the root node within the screen rectangle
  (let ((result (layout-node styled-root-node screen-rect)))
    (log:info "LAYOUT: Finished layout-tree for root node ID: ~S. Resulting layout-rect: ~S"
              (getf (ui-node-props styled-root-node) :id)
              (getf (ui-node-props result) :layout-rect))
    result))

;;;-----------------------------------------------------------------------------
;;; Deprecated Public Layout Functions (Adapt or Remove)
;;;-----------------------------------------------------------------------------

(defun layout-vbox (nodes container-rect &rest container-props &key &allow-other-keys)
  "DEPRECATED: Use stylesheets and :display :flex with :flex-direction :column."
  (declare (ignore nodes container-rect container-props))
  (warn "layout-vbox is deprecated. Use stylesheets and flex display properties.")
  nil)

(defun layout-hbox (nodes container-rect &rest container-props &key &allow-other-keys)
  "DEPRECATED: Use stylesheets and :display :flex with :flex-direction :row."
  (declare (ignore nodes container-rect container-props))
  (warn "layout-hbox is deprecated. Use stylesheets and flex display properties.")
  nil)

(defun layout-grid (nodes rows cols container-rect &key gap)
  "DEPRECATED: Use stylesheets and :display :grid."
  (declare (ignore nodes rows cols container-rect gap))
  (warn "layout-grid is deprecated. Use stylesheets and grid display properties.")
  nil)
