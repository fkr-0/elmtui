;;;===============================================================
;;; File: src/view/layout.lisp
;;; Top-Level Layout Pass & Dispatcher
;;;===============================================================
(uiop:define-package :elmtui.view.layout
  (:use :cl :elmtui.view.core)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.style-lib.style-set #:set-style #:style-set) ; Function to add styles to a set
  (:import-from :elmtui.style-lib.api #:styles)
  (:import-from :elmtui.view.api #:styled-ui-node-style-map
                #:ui-node-type #:ui-node-props #:ui-node-children
                )
  (:import-from :elmtui.view.core #:ui-node-p)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size
                #:rectangle #:make-rectangle #:copy-rectangle
                #:x #:y #:w #:h #:pos #:size)
  (:import-from :elmtui.view.styled
                #:styled-ui-node #:styles #:style-value #:copy-styled-node)
  ;; Import specific layout engines
  (:import-from :elmtui.view.layout.flex #:compute-flex-layout)

  (:export :layout-tree :layout-node #:dispatch-layout #:layout-grid-container-impl
           #:box-model #:content-box #:padding-box #:border-box
           #:dump-rect-tree))

(in-package :elmtui.view.layout)

;;;-----------------------------------------------------------------------------
;;; Box Model Definition
;;;-----------------------------------------------------------------------------
(defclass box-model ()
  ((border-box :initarg :border-box :accessor border-box
               :type rectangle
               :documentation "The outermost box, including margins, borders, and padding.")
   (padding-box :initarg :padding-box :accessor padding-box
                :type rectangle
                :documentation "The area inside the border, including padding but excluding borders.")
   (content-box :initarg :content-box :accessor content-box
                :type rectangle
                :documentation "The innermost box, containing the actual content."))
  (:documentation "Represents the CSS Box Model for a UI element."))

(defgeneric content-box (box-model)
  (:documentation "Returns the content-box rectangle of a box-model.")
  (:method ((bm box-model))
    (slot-value bm 'content-box)))

(defgeneric padding-box (box-model)
  (:documentation "Returns the padding-box rectangle of a box-model.")
  (:method ((bm box-model))
    (slot-value bm 'padding-box)))

(defgeneric border-box (box-model)
  (:documentation "Returns the border-box rectangle of a box-model.")
  (:method ((bm box-model))
    (slot-value bm 'border-box)))

(defgeneric layout-grid-container-impl (grid-container-node available-rect))

;;;-----------------------------------------------------------------------------
;;; Helper: Calculate Content Rect (Inner area after padding/border)
;;;-----------------------------------------------------------------------------
(defun calculate-content-rect (node-layout-rect styled-node)
  "Calculate the content rectangle within NODE-LAYOUT-RECT for STYLED-NODE,
   accounting for padding and border widths.
   Returns a new RECTANGLE for the content area."
  (let* ((padding-top (style-value styled-node :padding-top 0))
         (padding-right (style-value styled-node :padding-right 0))
         (padding-bottom (style-value styled-node :padding-bottom 0))
         (padding-left (style-value styled-node :padding-left 0))
         ;; Assuming border widths are 0 if border-style is :none, or 1 if not specified but style is not :none.
         ;; This logic should ideally be part of style computation or a helper.
         (border-style (style-value styled-node :border-style :none))
         (default-border-width (if (eq border-style :none) 0 1))
         (border-top-width (style-value styled-node :border-top-width default-border-width))
         (border-right-width (style-value styled-node :border-right-width default-border-width))
         (border-bottom-width (style-value styled-node :border-bottom-width default-border-width))
         (border-left-width (style-value styled-node :border-left-width default-border-width)))

    ;; Ensure border widths are 0 if border-style is :none, regardless of explicit width values
    (when (eq border-style :none)
      (setf border-top-width 0 border-right-width 0 border-bottom-width 0 border-left-width 0))

    (let* ((content-x (+ (x node-layout-rect) padding-left border-left-width))
           (content-y (+ (y node-layout-rect) padding-top border-top-width))
           (content-w (max 0 (- (w node-layout-rect)
                                padding-left padding-right
                                border-left-width border-right-width)))
           (content-h (max 0 (- (h node-layout-rect)
                                padding-top padding-bottom
                                border-top-width border-bottom-width))))
      (make-rectangle :pos (make-pos :x content-x :y content-y) :size (make-size :w content-w :h content-h)))))

(defun measure-node-intrinsic-size (node parent-absolute-content-rect parent-style-set)
  "Compute NODE’s border-box in absolute coordinates and store it under
   :LAYOUT-RECT, then recurse into its children."
  (declare (type styled-ui-node node)
           (type rectangle parent-absolute-content-rect)
           (ignore parent-style-set))           ; <— context not yet used
  (let* (;; ------------------------------------------------------------
         ;; Style & margin extraction
         ;; ------------------------------------------------------------
         (display        (style-value node :display :block))
         (margin-top     (style-value node :margin-top    0))
         (margin-right   (style-value node :margin-right  0))
         (margin-bottom  (style-value node :margin-bottom 0))
         (margin-left    (style-value node :margin-left   0))

         ;; ------------------------------------------------------------
         ;; Available space inside the parent’s content rectangle
         ;; ------------------------------------------------------------
         (avail-x ( + (x parent-absolute-content-rect) margin-left))
         (avail-y ( + (y parent-absolute-content-rect) margin-top))
         (avail-w (max 0 (- (w parent-absolute-content-rect) margin-left margin-right)))
         (avail-h (max 0 (- (h parent-absolute-content-rect) margin-top  margin-bottom)))

         ;; ------------------------------------------------------------
         ;; Requested width / height from styles
         ;; ------------------------------------------------------------
         (req-w (style-value node :width  :auto))
         (req-h (style-value node :height :auto))

         ;; Resolve :auto / <n> / “42%”
         (eff-w
           (cond ((numberp req-w)           req-w)
                 ((stringp req-w)
                  (if (alexandria:ends-with-subseq "%" req-w)
                      (* avail-w
                         (/ (parse-integer req-w :end (1- (length req-w))) 100.0))
                      avail-w))
                 (t                           avail-w)))
         (eff-h
           (cond ((numberp req-h)           req-h)
                 ((stringp req-h)
                  (if (alexandria:ends-with-subseq "%" req-h)
                      (* avail-h
                         (/ (parse-integer req-h :end (1- (length req-h))) 100.0))
                      avail-h))

                 (t                           avail-h)))


         ;; Border-box rectangle in absolute coords
         (layout-rect (make-rectangle :pos (make-pos :x avail-x :y avail-y) :size (make-size :w eff-w :h eff-h))))
    (declare (ignore display))

    ;; --------------------------------------------------------------
    ;; 1) store the rectangle on the node
    ;; --------------------------------------------------------------
    (setf (getf (ui-node-props node) :layout-rect) layout-rect)

    ;; --------------------------------------------------------------
    ;; 2) recurse into children — naive block-flow for now
    ;; --------------------------------------------------------------
    (let* ((children       (ui-node-children node))
           (child-content  (make-rectangle
                            :pos (make-pos
                                  :x (+ avail-x margin-left)
                                  :y (+ avail-y margin-top))
                            :size (make-size :w (- eff-w margin-left margin-right)
                                             :h (- eff-h margin-top  margin-bottom)))))
      (loop for child in children
            do (measure-node-intrinsic-size child child-content nil))

      ;; Return the rectangle for callers that might care
      layout-rect)))

;; (defun measure-node-intrinsic-size (node parent-absolute-content-rect parent-style-set)
;;   "PARENT-ABSOLUTE-CONTENT-RECT: The absolute rectangle defining the bounding box
;;                                    within which this node's border-box must fit.
;;    PARENT-STYLE-SET: The style-set of the parent (for context, not heavily used yet
;;    This function computes and sets the :LAYOUT-RECT property (absolute coordinates
;;     on the NODE and all its descendants."
;;   (declare (type styled-ui-node node)
;;            (type rectangle parent-absolute-content-rect)
;;            (type (or null style-set) parent-style-set))
;;   (let* ((node-id (getf (ui-node-props node) :id (gensym "ANON-NODE-")))
;;          (display (style-value node :display :block)) ; Default to block display
;;          (node-styles (styles node))

;;          ;; Margins for the current node
;;          (margin-top (style-value node :margin-top 0))
;;          (margin-right (style-value node :margin-right 0))
;;          (margin-bottom (style-value node :margin-bottom 0))
;;          (margin-left (style-value node :margin-left 0))

;;          ;; Available space for this node's border-box, considering its margins
;;          (available-outer-x (+ (x parent-absolute-content-rect) margin-left))
;;          (available-outer-y (+ (y parent-absolute-content-rect) margin-top))
;;          (available-outer-w (max 0 (- (w parent-absolute-content-rect) margin-left margin-right)))
;;          (available-outer-h (max 0 (- (h parent-absolute-content-rect) margin-top margin-bottom)))

;;          ;; Requested width/height from style
;;          ;; Percentage resolution needs parent's content width/height.
;;          (requested-w (style-value node :width :auto))
;;          (requested-h (style-value node :height :auto))

;;          ;; Effective width/height for this node's border-box.
;;          ;; If :auto, it will be determined by content or flex/grid algorithm.
;;          ;; If a number, it's used directly.
;;          ;; Percentages need to be resolved against available_outer_w/h.
;;          (eff-w (cond ((numberp requested-w) requested-w)
;;                       ((stringp requested-w) ; Percentage string e.g. "50%"
;;                        (if (and (alexandria:ends-with-subseq "%" requested-w) (> (length requested-w) 1))
;;                            (* (/ available-outer-w 100.0)
;;                               (parse-integer
;;                                (subseq requested-w 0 (- (length requested-w) 1))))
;;                            available-outer-w))
;;                       ((eq requested-w :auto) available-outer-w)
;;                       (t available-outer-w)))
;;          (eff-h (cond ((numberp requested-h) requested-h)
;;                       ((stringp requested-h) ; Percentage string e.g. "50%"
;;                        (if (and (alexandria:ends-with-subseq "%" requested-h) (> (length requested-h) 1))
;;                            (* (/ available-outer-h 100.0)
;;                               (parse-integer
;;                                (subseq requested-h 0 (- (length requested-h) 1)))))))))))


;;;-----------------------------------------------------------------------------
;;; Main Recursive Layout Function & Dispatcher
;;;-----------------------------------------------------------------------------

(defun layout-node (node parent-absolute-content-rect parent-style-set)
  "Recursively computes the layout for NODE and its children.
   NODE: The styled-ui-node to lay out.
   PARENT-ABSOLUTE-CONTENT-RECT: The absolute rectangle defining the bounding box
                                   within which this node's border-box must fit.
   PARENT-STYLE-SET: The style-set of the parent (for context, not heavily used yet).
   This function computes and sets the :LAYOUT-RECT property (absolute coordinates)
   on the NODE and all its descendants.
   Returns the modified NODE."
  (log-info "Running layout-node for node ~A with parent-absolute-content-rect: ~S"
            node parent-absolute-content-rect)
  (unless (typep node 'styled-ui-node)
    (log-warn "LAYOUT: Attempting to lay out a non-styled-ui-node: ~A" node)
    (return-from layout-node node))
  (log-debug "LAYOUT: Starting layout for node ~A with parent-absolute-content-rect: ~S"
             (getf (ui-node-props node) :id (gensym "ANON-NODE-")) parent-absolute-content-rect)
  (let* ((node-id (getf (ui-node-props node) :id (gensym "ANON-NODE-")))
         (display (style-value node :display :block)) ; Default to block display
         ;; Canonical: use style-map slot if present, else inline :style from props, else nil
         (node-styles (cond
                        ((and (typep node 'styled-ui-node)
                              (ignore-errors (slot-exists-p node 'elmtui.view.api::style-map)))
                         (ignore-errors (styled-ui-node-style-map node)))
                        ((getf (ui-node-props node) :style))
                        (t nil)))
         ;; --- PATCH: Robust width/height resolution for root and containers ---
         (requested-w (style-value node :width :auto))
         (requested-h (style-value node :height :auto))
         (is-root (null parent-absolute-content-rect)) ; If parent rect is NIL, treat as root
         (available-outer-w (if is-root
                                ;; Defensive: try to get from node's props, else fallback to 80
                                (let ((screen-w (getf (ui-node-props node) :screen-width)))
                                  (or (and screen-w (numberp screen-w) screen-w) 80))
                                (max 0 (- (w parent-absolute-content-rect)
                                          (style-value node :margin-left 0)
                                          (style-value node :margin-right 0)))))
         (available-outer-h (if is-root
                                (let ((screen-h (getf (ui-node-props node) :screen-height)))
                                  (or (and screen-h (numberp screen-h) screen-h) 24))
                                (max 0 (- (h parent-absolute-content-rect)
                                          (style-value node :margin-top 0)
                                          (style-value node :margin-bottom 0)))))
         (eff-w (cond ((numberp requested-w) (min requested-w available-outer-w))
                      ((or (eq requested-w :auto) (eq requested-w :fill) (null requested-w)) available-outer-w)
                      ((stringp requested-w)
                       (if (and (alexandria:ends-with-subseq "%" requested-w) (> (length requested-w) 1))
                           (let* ((percentage-val (parse-integer (subseq requested-w 0 (1- (length requested-w)))))
                                  (parent-dim-for-percentage (if is-root available-outer-w (w parent-absolute-content-rect))))
                             (max 0 (min available-outer-w
                                         (floor (* parent-dim-for-percentage (/ percentage-val 100.0))))))
                           available-outer-w))
                      (t available-outer-w)))
         (eff-h (cond ((numberp requested-h) (min requested-h available-outer-h))
                      ((or (eq requested-h :auto) (eq requested-h :fill) (null requested-h)) available-outer-h)
                      ((stringp requested-h)
                       (if (and (alexandria:ends-with-subseq "%" requested-h) (> (length requested-h) 1))
                           (let* ((percentage-val (parse-integer (subseq requested-h 0 (1- (length requested-h)))))
                                  (parent-dim-for-percentage (if is-root available-outer-h (h parent-absolute-content-rect))))
                             (max 0 (min available-outer-h
                                         (floor (* parent-dim-for-percentage (/ percentage-val 100.0))))))
                           available-outer-h))
                      (t available-outer-h)))
         (node-layout-rect-tmp (let ((r (make-rectangle :pos (make-pos :x (if is-root 0 (x parent-absolute-content-rect))
                                                                       :y (if is-root 0 (y parent-absolute-content-rect)))
                                                        :size (make-size :w eff-w :h eff-h))))
                                 (setf (getf (ui-node-props node) :layout-rect) r)
                                 r))
         ;; Actually assign the computed rect to the node's props for downstream use



         ;; Margins for the current node
         (margin-top (style-value node :margin-top 0))
         (margin-right (style-value node :margin-right 0))
         (margin-bottom (style-value node :margin-bottom 0))
         (margin-left (style-value node :margin-left 0))

         ;; Available space for this node's border-box, considering its margins
         (available-outer-x (+ (x parent-absolute-content-rect) margin-left))
         (available-outer-y (+ (y parent-absolute-content-rect) margin-top))
         (available-outer-w (max 0 (- (w parent-absolute-content-rect) margin-left margin-right)))
         (available-outer-h (max 0 (- (h parent-absolute-content-rect) margin-top margin-bottom)))

         ;; Requested width/height from style (could be :auto, number, percentage)
         ;; Percentage resolution needs parent's content width/height.
         (requested-w (style-value node :width :auto))
         (requested-h (style-value node :height :auto))

         ;; Effective width/height for this node's border-box.
         ;; If :auto, it will be determined by content or flex/grid algorithm.
         ;; If a number, it's used directly (clamped by available space for non-scrolling).
         ;; Percentages need to be resolved against available_outer_w/h.
         (eff-w (or (cond ((numberp requested-w) (min requested-w available-outer-w))
                          ((stringp requested-w) ; Percentage string e.g. "50%"
                           (if (and (alexandria:ends-with-subseq "%" requested-w) (> (length requested-w) 1))
                               (let* ((percentage-val (parse-integer (subseq requested-w 0 (1- (length requested-w)))))
                                      (parent-dim-for-percentage (w parent-absolute-content-rect)))
                                 (max 0 (min available-outer-w ; Clamp to available space
                                             (floor (* parent-dim-for-percentage (/ percentage-val 100.0))))))
                               (progn (log-warn "LAYOUT: Invalid percentage width string: ~S for node ~A. Using available." requested-w node-id)
                                      available-outer-w)))
                          ((eq requested-w :auto) available-outer-w) ; Placeholder, flex/grid/block will determine
                                        ; (t available-outer-w)
                          )
                    available-outer-w)) ; Fallback to available space if no effective width found
         (eff-h (or (cond ((numberp requested-h) (min requested-h available-outer-h))
                          ((stringp requested-h) ; Percentage string e.g. "50%"
                           (if (and (alexandria:ends-with-subseq "%" requested-h) (> (length requested-h) 1))
                               (let* ((percentage-val (parse-integer (subseq requested-h 0 (1- (length requested-h)))))
                                      (parent-dim-for-percentage (h parent-absolute-content-rect)))
                                 (max 0 (min available-outer-h ; Clamp to available space
                                             (floor (* parent-dim-for-percentage (/ percentage-val 100.0))))))
                               (progn (log-warn "LAYOUT: Invalid percentage height string: ~S for node ~A. Using available." requested-h node-id)
                                      available-outer-h)))
                          ((eq requested-h :auto) available-outer-h) ; Placeholder, flex/grid/block will determine
                          ;; (t available-outer-h)
                          )
                    available-outer-h)) ; Fallback to available space if no effective height found

         ;; This is the initial estimate for the node's own border-box rectangle.
         ;; Flex/Grid might adjust eff-w and eff-h if they were :auto.

         (node-layout-rect (make-rectangle :pos (make-pos :x available-outer-x :y available-outer-y) :size (make-size :w eff-w :h eff-h))))
    (declare (ignore node-layout-rect-tmp)) ; We use node-layout-rect directly now
    ;; --------------------------------------------------------------
    (log-debug "LAYOUT: ~A (~A) display:~S. ParentAbsContentRect:~S. Assigned initial layout_rect:~S"
               (ui-node-type node) node-id display parent-absolute-content-rect node-layout-rect)
    (setf (getf (ui-node-props node) :layout-rect) node-layout-rect)
    (log-debug "LAYOUT: Initial frame for ~A (~A) display:~S. ParentAbsContentRect:~S. Assigned initial layout_rect:~S"
               (ui-node-type node) node-id display parent-absolute-content-rect node-layout-rect)

    (if (eq display :none)
        (progn
          (log-info "LAYOUT: ~A (~A) display:none. Setting zero size." (ui-node-type node) node-id)
          (setf (w (getf (ui-node-props node) :layout-rect)) 0)
          (setf (h (getf (ui-node-props node) :layout-rect)) 0)
          (setf (ui-node-children node) nil)) ; No children to lay out
        ;; Else, proceed with layout for visible display types
        (let* ((self-content-rect (calculate-content-rect node-layout-rect node))
               (final-node-rect node-layout-rect) ; Will be updated by flex/grid if size is auto
               (laid-out-children nil))
          (log-debug "LAYOUT: ~A (~A) self_content_rect for children: ~S" (ui-node-type node) node-id self-content-rect)

          (case display
            (:flex
             (log-info "LAYOUT: ~A (~A) dispatching to FLEX layout in ~S"
                       (ui-node-type node) node-id self-content-rect)

             ;; Run flex layout: returns the flex‑container object
             (let* ((flex-container (elmtui.view.layout.flex:compute-flex-layout
                                     node self-content-rect parent-style-set))
                    (item-rects     (mapcar #'elmtui.view.layout.flex::rectangle
                                            (elmtui.view.layout.flex:flex-item-children
                                             flex-container))))
               ;; Recurse for every UI child with its absolute rectangle
               (setf laid-out-children
                     (loop for child in (ui-node-children node)
                           for rect  in item-rects
                           collect (layout-node child rect node-styles)))

               (setf final-node-rect (getf (ui-node-props node) :layout-rect))))
            ;; (:flex
            ;;  (log-info "LAYOUT: ~A (~A) dispatching to FLEX layout in ~S"
            ;;            (ui-node-type node) node-id self-content-rect)

            ;;  ;; 1. Run flex layout – returns the *container* object, not a rectangle
            ;;  (let* ((flex-container (elmtui.view.layout.flex:compute-flex-layout
            ;;                          node self-content-rect parent-style-set))
            ;;         ;; We need the list of flex‑items to fetch the child rectangles.
            ;;         (item-rects (mapcar #'elmtui.view.layout.flex::rectangle
            ;;                             (elmtui.view.layout.flex:flex-item-children flex-container))))

            ;;    ;; 2. Recurse into the UI‑children, handing each its OWN absolute rect
            ;;    (setf laid-out-children
            ;;          (loop for child   in (ui-node-children node)
            ;;                for rect    in item-rects
            ;;                collect (layout-node child rect node-styles)))

            ;;    ;; 3. The container’s own :layout-rect has already been set by flex.
            ;;    (setf final-node-rect (getf (ui-node-props node) :layout-rect))))
            ;; (:flex
            ;;  (log-info "LAYOUT: ~A (~A) dispatching to FLEX layout in ~S" (ui-node-type node) node-id self-content-rect)
            ;;  ;; compute-flex-layout is expected to:
            ;;  ;; 1. Calculate the layout for children within self-content-rect.
            ;;  ;; 2. Set :layout-rect on each child.
            ;;  ;; 3. Return the final rectangle for the flex container itself (node-layout-rect might be updated).
            ;;  (setf final-node-rect (elmtui.view.layout.flex:compute-flex-layout
            ;;                         node
            ;;                         self-content-rect
            ;;                         parent-style-set
            ;;                         ))
            ;;  (setf (getf (ui-node-props node) :layout-rect) final-node-rect)
            ;;  ;; Children of the flex container now have their :layout-rects set by compute-flex-layout.
            ;;  ;; We must recurse into them to lay out *their* children.
            ;;  (setf laid-out-children
            ;;        (loop for i below (length (ui-node-children node))
            ;;              ;; child in (ui-node-children node)
            ;;              ;; for child-flex = (et.flex:flex-item-children final-node-rect)
            ;;              collect (let
            ;;                          ((child (nth i (ui-node-children node)))
            ;;                           (rect (nth i (elmtui.view.layout.flex:flex-item-children final-node-rect))))
            ;;                        (layout-node child
            ;;                                     ;; (getf (ui-node-props child) :layout-rect)
            ;;                             ; Child's border-box is parent_abs_content_rect for its children
            ;;                                     rect
            ;;                                     node-styles)))))
            (:grid
             (log-info "LAYOUT: ~A (~A) dispatching to GRID layout in ~S" (ui-node-type node) node-id self-content-rect)
             ;; layout-grid-container-impl is expected to:
             ;; 1. Calculate layout for children within self-content-rect.
             ;; 2. Set :layout-rect on each child.
             ;; 3. Return the final rectangle for the grid container itself.
             (setf final-node-rect (layout-grid-container-impl node self-content-rect))
             (setf (getf (ui-node-props node) :layout-rect) final-node-rect)
             ;; Recurse for children of the grid container
             (setf laid-out-children
                   (loop for child in (ui-node-children node)
                         collect (layout-node child
                                              (getf (ui-node-props child) :layout-rect)
                                              node-styles))))
            (:block
                (log-info "LAYOUT: ~A (~A) dispatching to BLOCK layout in ~S" (ui-node-type node) node-id self-content-rect)
              (let ((current-child-y-offset 0)
                    (max-child-width 0)
                    (previous-child-margin-bottom 0)) ; For margin collapsing (simplified)
                (setf laid-out-children
                      (loop for child-node in (ui-node-children node)
                            collect (let* ((child-margin-top (style-value child-node :margin-top 0))
                                           (child-margin-bottom (style-value child-node :margin-bottom 0))
                                           ;; Simplified margin collapsing: take max of prev bottom and current top
                                           (effective-margin-top (max previous-child-margin-bottom child-margin-top))
                                           (child-available-parent-rect
                                             (make-rectangle
                                              :pos (make-pos :x (x self-content-rect) ; Child x is relative to parent content-box x
                                                             :y (+ (y self-content-rect) current-child-y-offset effective-margin-top))
                                              :size (make-size :w (w self-content-rect)
                                                               :h (max 0 (- (h self-content-rect) current-child-y-offset effective-margin-top)))))
                                           (laid-out-child (layout-node child-node child-available-parent-rect node-styles)))
                                      ;; Y offset for next child is current offset + this child's margin-top + this child's height + this child's border-box
                                      ;; However, layout-node already placed the child considering its own margins relative to child-available-parent-rect.
                                      ;; So, the height of its layout-rect IS its border-box height.
                                      ;; The current-child-y-offset should advance by the space taken by the child, including its top margin (already handled by effective-margin-top)
                                      ;; and its entire height (border-box).
                                      (incf current-child-y-offset (+ effective-margin-top (h (getf (ui-node-props laid-out-child) :layout-rect))))
                                      (setf max-child-width (max max-child-width (w (getf (ui-node-props laid-out-child) :layout-rect))))
                                      (setf previous-child-margin-bottom child-margin-bottom) ; Store for next iteration
                                      laid-out-child)))
                ;; If container height is auto, adjust it based on children
                (when (eq requested-h :auto)
                  (let* ((total-padding-border-h (- (h node-layout-rect) (h self-content-rect)))
                         ;; Add the last child's bottom margin if it wasn't collapsed with a subsequent non-existent child
                         (final-content-height (+ current-child-y-offset previous-child-margin-bottom)))
                    (setf (h final-node-rect) (+ final-content-height total-padding-border-h))))
                ;; If container width is auto, adjust it based on children's max width + padding/border
                (when (eq requested-w :auto)
                  (let* ((total-padding-border-w (- (w node-layout-rect) (w self-content-rect))))
                    ;; max-child-width is the border-box width of the widest child.
                    ;; The container's content width needs to accommodate this.
                    (setf (w final-node-rect) (+ max-child-width total-padding-border-w))))
                (setf (getf (ui-node-props node) :layout-rect) final-node-rect)))
            (:inline
             (log-warn "LAYOUT: Inline layout not yet implemented for ~A (~S). Treating as block for children." (ui-node-type node) node-id)
             ;; Fallback to block-like layout for children for now
             (setf laid-out-children
                   (loop for child-node in (ui-node-children node)
                         collect (layout-node child-node self-content-rect node-styles))))
            (t
             (log-warn "LAYOUT: ~A (~A) unknown display type ~S, treating as :block for children" (ui-node-type node) node-id display)
             (setf laid-out-children
                   (loop for child-node in (ui-node-children node)
                         collect (layout-node child-node self-content-rect node-styles)))))

          (log-info "LAYOUT: ~A (~A) final layout-rect after children: ~S"
                    (ui-node-type node) node-id final-node-rect)
          (setf (ui-node-children node) laid-out-children)))

    (log-debug "LAYOUT: Final computed rect for ~A (~A): ~S" (ui-node-type node) node-id (getf (ui-node-props node) :layout-rect))
    node))

;;;-----------------------------------------------------------------------------
;;; Top-Level Entry Point
;;;-----------------------------------------------------------------------------

(defun layout-tree (styled-root-node screen-rect)
  "Computes and sets the :LAYOUT-RECT property for STYLED-ROOT-NODE and all its descendants.
   SCREEN-RECT: The initial RECTANGLE representing the available screen space.
   Returns the modified STYLED-ROOT-NODE with layout information."
  (let ((root-node
          (cond
            ((typep styled-root-node 'styled-ui-node) styled-root-node)
            ((and (listp styled-root-node)
                  (= (length styled-root-node) 1)
                  (typep (first styled-root-node) 'styled-ui-node))
             (first styled-root-node))
            ((and (listp styled-root-node)
                  (every #'ui-node-p styled-root-node))
             (progn
               (log-warn "LAYOUT-TREE: Root is a list of multiple nodes. Using first node for layout. List: ~S" styled-root-node)
               (first styled-root-node)))
            (t
             (log-error "LAYOUT-TREE: Root node is not a styled-ui-node: ~A" styled-root-node)
             (return-from layout-tree styled-root-node)))))
    (unless (typep screen-rect 'rectangle)
      (log-error "LAYOUT-TREE: screen-rect is not a rectangle: ~A" screen-rect)
      (return-from layout-tree root-node))

    (log-info "LAYOUT-TREE: Starting layout for root ~S in screen rect ~S"
              (getf (ui-node-props root-node) :id "N/A") screen-rect)

    (layout-node root-node screen-rect nil)
    root-node))

;;;-----------------------------------------------------------------------------
;;; Dispatch Methods (Placeholder for explicit grid dispatch if needed)
;;; The main layout-node function uses a CASE statement for dispatch.
;;; If we wanted to use generic functions for dispatch, it would look like this:
;;;-----------------------------------------------------------------------------

;; (defgeneric dispatch-layout (display node available-rect parent-style-set)
;;   (:documentation "Dispatches to the appropriate layout algorithm based on display type."))

;; (defmethod dispatch-layout ((display (eql :grid)) node available-rect parent-style-set)
;;   (elmtui.view.layout.grid:layout-grid-container-impl node available-rect))

;; (defmethod dispatch-layout ((display (eql :flex)) node available-rect parent-style-set)
;;   (elmtui.view.layout.flex:compute-flex-layout node available-rect))

;; ... other methods ...

;; (defmethod dispatch-layout (display node available-rect parent-style-set)
;;   ;; Default (e.g. block)
;;   (log-warn "LAYOUT: No specific dispatch for display type ~S on node ~S. Using default block logic."
;;             display (getf (ui-node-props node) :id "N/A"))
;;   ;; ... block layout logic directly here or call a block-layout function ...

;;;-------------------------------------------------------------------------------
;;; Deprecated Public Layout Functions (Adapt or Remove)
;;;-------------------------------------------------------------------------------

;; (defun layout-vbox (nodes container-rect &rest container-props &key &allow-other-keys)
;;   (declare (ignore nodes container-rect container-props))
;;   (log-warn "layout-vbox is deprecated.")
;;   nil)

;; (defun layout-hbox (nodes container-rect &rest container-props &key &allow-other-keys)
;;   (declare (ignore nodes container-rect container-props))
;;   (log-warn "layout-hbox is deprecated.")
;;   nil)

;; (defun layout-grid (nodes rows cols container-rect &key gap)
;;   (declare (ignore nodes rows cols container-rect gap))
;;   (log-warn "layout-grid is deprecated. Use display:grid style.")
;;   nil)

(defun dump-rect-tree (node &optional (depth 0))
  "Print the layout tree with absolute rectangles for quick inspection."
  (format t "~&~v@T~A: ~S~%"
          (* 2 depth)
          (or (getf (ui-node-props node) :id) (ui-node-type node))
          (getf (ui-node-props node) :layout-rect))
  (dolist (child (ui-node-children node))
    (dump-rect-tree child (1+ depth))))
