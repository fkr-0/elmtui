;;;===============================================================
;;; File: src/view/layout.lisp
;;; Top-Level Layout Pass & Flexbox/Block Layout
;;;===============================================================
(uiop:define-package :elmtui.view.layout
  (:use :cl :elmtui.view.core) ; Keep core for ui-node structure access
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
                #:copy-styled-node)
  ;; Grid layout function will be called via generic dispatch
  ;; (:import-from :elmtui.view.layout.grid #:layout-grid-container) ; Removed import
  (:export :layout-tree ; New top-level function
           :dispatch-layout ; Export the generic function
   ;; Keep old exports for now, maybe deprecate later
   :layout-vbox
           :layout-hbox
   :layout-grid))
(in-package :elmtui.view.layout)

;;;-----------------------------------------------------------------------------
;;; Helper: Styled Node -> Flex Item Conversion
;;;-----------------------------------------------------------------------------

(defun styled-node->flex-item (styled-node)
  "Convert a styled-ui-node into a flex-item instance.
   Extracts layout properties EXCLUSIVELY from computed styles."
  (let* ((initial-w (style-value styled-node :width 0)) ; TODO: Handle :auto, %, etc.
         (initial-h (style-value styled-node :height 0))
         (initial-rect (make-rectangle :pos (make-pos :x 0 :y 0)
                                       :size (make-size :w initial-w :h initial-h)))
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
         (max-h (style-value styled-node :max-height most-positive-fixnum)))

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
                   ;; :child-container is NOT set here. Nested layout is handled by layout-tree recursion.
                   )))

;;;-----------------------------------------------------------------------------
;;; Flexbox Layout for Children
;;;-----------------------------------------------------------------------------

(defun layout-flex-children (container-styled-node available-rect)
  "Layout the children of CONTAINER-STYLED-NODE using flexbox within AVAILABLE-RECT.
   Returns a list of *new* laid-out child nodes."
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
         (flex-items (mapcar #'styled-node->flex-item styled-children)))

    (let ((container (make-instance 'flex-container
                                    :rectangle (copy-rectangle available-rect)
                                    :children flex-items
                                    :main-axis main-axis
                                    :justify-content justify-content
                                    :align-items align-items
                                    :align-content align-content
                                    :flex-wrap flex-wrap)))
      (layout-flex-container container)

      ;; Create new styled nodes with updated layout rects
      (loop for flex-item in flex-items
            for original-child in styled-children
            collect (let* ((final-rect (rectangle flex-item))
                           (new-child (copy-styled-node original-child))) ; Create copy
                      ;; Store final layout rect in props
                      (setf (getf (ui-node-props new-child) :layout-rect) final-rect)
                      ;; Update individual props for convenience? (Optional)
                      (setf (getf (ui-node-props new-child) :x) (x final-rect))
                      (setf (getf (ui-node-props new-child) :y) (y final-rect))
                      (setf (getf (ui-node-props new-child) :width) (w final-rect))
                      (setf (getf (ui-node-props new-child) :height) (h final-rect))
                      new-child)))))

;;;-----------------------------------------------------------------------------
;;; Helper: Calculate Content Rect (Inner area after padding/border)
;;;-----------------------------------------------------------------------------

(defun calculate-content-rect (styled-node parent-content-rect)
  "Calculates the inner rectangle available for children,
   after accounting for the node's own padding and border."
  (let* ((pad-top (style-value styled-node :padding-top 0))
         (pad-bottom (style-value styled-node :padding-bottom 0))
         (pad-left (style-value styled-node :padding-left 0))
         (pad-right (style-value styled-node :padding-right 0))
         ;; Simple border assumption: 1 if :box is set, 0 otherwise
         ;; TODO: Use specific border-width styles when available
         (border-style (style-value styled-node :box :none))
         (border-width (if (eq border-style :none) 0 1))
         (border-top border-width)
         (border-bottom border-width)
         (border-left border-width)
         (border-right border-width)

         (content-x (+ (x parent-content-rect) pad-left border-left))
         (content-y (+ (y parent-content-rect) pad-top border-top))
         (content-w (max 0 (- (w parent-content-rect)
                              pad-left border-left pad-right border-right)))
         (content-h (max 0 (- (h parent-content-rect)
                              pad-top border-top pad-bottom border-bottom))))
    (make-rectangle :pos (make-pos :x content-x :y content-y)
                    :size (make-size :w content-w :h content-h))))

;;;-----------------------------------------------------------------------------
;;; Block Layout for Children
;;;-----------------------------------------------------------------------------

(defun layout-block-children (container-styled-node available-content-rect)
  "Layout children vertically within the available content rectangle.
   Returns a list of new laid-out child nodes and the total height used."
  (let ((laid-out-children '())
        (current-y (y available-content-rect))
        (max-child-width 0))
    (loop for child-node in (ui-node-children container-styled-node)
          do (when (typep child-node 'styled-ui-node)
               ;; Determine available space for this child
               (let* ((child-available-width (w available-content-rect)) ; Block takes full width
                      (child-available-height (max 0 (- (+ (y available-content-rect) (h available-content-rect))
                                                        current-y)))
                      (child-available-rect (make-rectangle
                                             :pos (make-pos :x (x available-content-rect) :y current-y)
                                             :size (make-size :w child-available-width :h child-available-height)))
                      ;; Recursively layout the child
                      (laid-out-child (layout-node child-node child-available-rect))
                      (child-layout-rect (getf (ui-node-props laid-out-child) :layout-rect)))

                 (when laid-out-child
                   ;; Update child's position based on block flow
                   (setf (x (rectangle-pos child-layout-rect)) (x available-content-rect))
                   (setf (y (rectangle-pos child-layout-rect)) current-y)

                   (push laid-out-child laid-out-children)
                   (incf current-y (h child-layout-rect)) ; Stack vertically
                   (setf max-child-width (max max-child-width (w child-layout-rect)))))))

    (values (nreverse laid-out-children)
            (- current-y (y available-content-rect)) ; Total height consumed by children
            max-child-width))) ; Max width used by children

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
    (warn "layout-node called on non-styled-node: ~A" node)
    (return-from layout-node nil)) ; Or handle appropriately
  (unless (typep available-rect 'rectangle)
     (error "layout-node requires a valid available-rect."))

  (let* ((display (style-value node :display :block))
         ;; Calculate rect available *for this node* (initially same as available-rect)
         ;; Position will be adjusted by parent's layout logic later.
         (node-rect (copy-rectangle available-rect))
         ;; Calculate inner content area based on *this node's* padding/border
         (content-rect (calculate-content-rect node node-rect))
         (laid-out-children nil)
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
           (border-width (if (eq (style-value node :box :none) :none) 0 1)) ; Simple border
           (horizontal-padding (+ pad-left pad-right (* 2 border-width)))
           (vertical-padding (+ pad-top pad-bottom (* 2 border-width)))

           ;; Calculate final width
           (final-w (cond ((integerp styled-w) styled-w)
                          ((eq styled-w :auto)
                           (case display
                             (:block (w available-rect)) ; Block usually takes available width
                             ;; For flex/grid, width is often determined by the container/available space
                             ;; unless items dictate otherwise (which isn't fully handled here yet).
                             ;; Use children-width as a fallback guess.
                             (:flex children-width)
                             (:grid children-width)
                             (t (max children-width horizontal-padding)))) ; Basic shrink-to-fit guess
                          (t (w available-rect)))) ; Default fallback

           ;; Calculate final height
           (final-h (cond ((integerp styled-h) styled-h)
                          ((eq styled-h :auto)
                           (+ children-height vertical-padding)) ; Height based on children + padding/border
                          (t (h available-rect))))) ; Default fallback

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
            new-node))))))

;; --- Default layout method (handles unknown display types like block) ---
(defmethod dispatch-layout (display node available-rect)
  (declare (ignore display)) ; Treat unknown as block
  (layout-block-children node available-rect))

;; --- Flex layout method ---
(defmethod dispatch-layout ((display (eql :flex)) node available-rect)
  (values (layout-flex-children node available-rect)
          (h available-rect) ; Flex height determined by container for now
          (w available-rect))) ; Flex width determined by container for now

;; --- Block layout method ---
(defmethod dispatch-layout ((display (eql :block)) node available-rect)
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

;; --- Grid layout method will be defined in grid.lisp ---


;;;-----------------------------------------------------------------------------
;;; Top-Level Entry Point
;;;-----------------------------------------------------------------------------

(defun layout-tree (styled-root-node screen-rect)
  "Top-level entry point for layout. Takes the root of the styled node tree
   and the total available screen rectangle."
  (unless (typep styled-root-node 'styled-ui-node)
    (error "layout-tree requires a styled-ui-node tree root."))
  (unless (typep screen-rect 'rectangle)
    (error "layout-tree requires a valid screen-rect."))
  ;; Layout the root node within the screen rectangle
  (layout-node styled-root-node screen-rect))

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
