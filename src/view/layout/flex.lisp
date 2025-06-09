;;;----------------------------------------------------------------------------
;;; Helper Functions for Multi-Line Flex Layout
;;;----------------------------------------------------------------------------
(defun collect-all-items-initial-data (children is-row main-axis-size)
  "Collects initial data for all flex items.
   Calculates hypothetical-main-size based on flex-basis or styled main dimension,
   and gathers other relevant flex properties for each item."
  (let ((items-data \\\'()))
    (loop for child in children do
      (when (typep child \\\'styled-ui-node)
        (let* ((child-styles (styles child))
               (child-props (ui-node-props child))
               (order (style-value child-styles :order 0)) ; Get order
               (flex-basis (style-value child-styles :flex-basis :auto))
               (flex-grow (style-value child-styles :flex-grow 0))
               (flex-shrink (style-value child-styles :flex-shrink 1))
               (align-self (style-value child-styles :align-self :auto))
               
               (styled-main-dim (if is-row (style-value child-styles :width) (style-value child-styles :height)))
               ;; (styled-cross-dim (if is-row (style-value child-styles :height) (style-value child-styles :width))) ; Unused
               
               (min-main-dim (if is-row (style-value child-styles :min-width 0) (style-value child-styles :min-height 0)))
               (max-main-dim (if is-row (style-value child-styles :max-width most-positive-fixnum) (style-value child-styles :max-height most-positive-fixnum)))
               ;; (min-cross-dim (if is-row (style-value child-styles :min-height 0) (style-value child-styles :min-width 0))) ; Unused
               ;; (max-cross-dim (if is-row (style-value child-styles :max-height most-positive-fixnum) (style-value child-styles :max-width most-positive-fixnum))) ; Unused
               
               (hypothetical-main-size 0))
          ;; Determine hypothetical main size based on flex-basis, then styled main dimension
          (cond
            ((numberp flex-basis) (setf hypothetical-main-size flex-basis))
            ((and (consp flex-basis) (eq (car flex-basis) :percentage) (numberp (cadr flex-basis)))
             ;; Percentage flex-basis is relative to flex container's inner main size
             (setf hypothetical-main-size (* main-axis-size (/ (cadr flex-basis) 100.0))))
            ((eq flex-basis :content)
             (setf hypothetical-main-size (get-item-content-main-size child is-row)))
            ((eq flex-basis :auto)
             (if (numberp styled-main-dim)
                 (setf hypothetical-main-size styled-main-dim)
                 ;; If auto and no explicit size, try content size as basis
                 (setf hypothetical-main-size (get-item-content-main-size child is-row))))
            (t (setf hypothetical-main-size (get-item-content-main-size child is-row)))) ; Default for unhandled basis

          ;; Clamp by min/max
          (setf hypothetical-main-size (max min-main-dim (min hypothetical-main-size max-main-dim)))
          
          (push (list :node child :props child-props :styles child-styles :order order
                      :hypothetical-main-size hypothetical-main-size
                      :final-main-size hypothetical-main-size ; Initialize final with hypothetical
                      :flex-grow flex-grow :flex-shrink flex-shrink
                      :align-self align-self
                      :min-main min-main-dim :max-main max-main-dim
                      :main-pos 0.0 :cross-pos 0.0 :final-cross-size 0.0)
                items-data))))
    (nreverse items-data)))

(defun process-one-flex-line (line-items-initial-data line-available-main-size container-total-cross-size
                               justify-content align-items is-row)
  "Processes a single line of flex items.
   Calculates final main sizes, main-axis positions, final cross sizes, and cross-axis positions.
   Modifies and returns the list of item data for the line."
  (let ((processed-line-items (mapcar #'(lambda (item) (copy-list item)) line-items-initial-data)))

    ;; 1. Resolve Flexible Lengths (Main Axis) for this line
    (let* ((total-hypothetical-main-size (loop for item in processed-line-items sum (getf item :hypothetical-main-size)))
           (remaining-space (- line-available-main-size total-hypothetical-main-size))
           (total-flex-grow (loop for item in processed-line-items when (> (getf item :flex-grow 0) 0) sum (getf item :flex-grow)))
           (total-flex-shrink-weighted (loop for item in processed-line-items when (> (getf item :flex-shrink 0) 0) sum (* (getf item :flex-shrink) (getf item :hypothetical-main-size)))))
      (cond
        ((and (> remaining-space 0) (> total-flex-grow 0)) ; Grow
         (loop for item in processed-line-items when (> (getf item :flex-grow 0) 0) do
           (let* ((grow-share (/ (getf item :flex-grow) total-flex-grow))
                  (space-to-add (* remaining-space grow-share))
                  (new-size (+ (getf item :final-main-size) space-to-add)))
             (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main)))))))
        ((and (< remaining-space 0) (> total-flex-shrink-weighted 0)) ; Shrink
         (let ((space-to-remove (abs remaining-space)))
           (loop for item in processed-line-items when (> (getf item :flex-shrink 0) 0) do
             (let* ((shrink-factor (if (> total-flex-shrink-weighted 0)
                                       (/ (* (getf item :flex-shrink) (getf item :hypothetical-main-size)) total-flex-shrink-weighted)
                                       ;; Fallback if total-flex-shrink-weighted is 0 (e.g. all items have 0 hypothetical size)
                                       (/ 1.0 (count-if #'(lambda (it) (> (getf it :flex-shrink 0) 0)) processed-line-items))))
                    (reduction (* space-to-remove shrink-factor))
                    (new-size (- (getf item :final-main-size) reduction)))
               (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main))))))))))

    ;; 2. Main Axis Alignment (justify-content) for this line
    (let* ((num-items (length processed-line-items))
           (total-final-main-size (loop for item in processed-line-items sum (getf item :final-main-size)))
           (current-remaining-space (- line-available-main-size total-final-main-size))
           (main-offset 0.0))
      (cond
        ((eq justify-content :flex-end) (setf main-offset current-remaining-space))
        ((eq justify-content :center) (setf main-offset (/ current-remaining-space 2)))
        ((eq justify-content :space-between) (when (> num-items 1) (setf main-offset 0)))
        ((eq justify-content :space-around) (if (> num-items 0) (setf main-offset (/ current-remaining-space (* 2 num-items)))))
        ((eq justify-content :space-evenly) (if (> num-items 0) (setf main-offset (/ current-remaining-space (+ 1 num-items)))))
        (t (setf main-offset 0))) ; :flex-start or default

      (loop for item in processed-line-items do
        (setf (getf item :main-pos) main-offset) ; main-pos is from start of line
        (incf main-offset (getf item :final-main-size))
        (cond
          ((and (eq justify-content :space-between) (> num-items 1))
           (when (< (position item processed-line-items :test #\'eq) (1- num-items)) ; Not the last item
             (incf main-offset (/ current-remaining-space (1- num-items)))))
          ((eq justify-content :space-around)
           (incf main-offset (/ current-remaining-space num-items))) ; Space after item
          ((eq justify-content :space-evenly)
           (incf main-offset (/ current-remaining-space (+ 1 num-items))))))) ; Space after item
    
    ;; 3. Cross Axis Sizing and Alignment for this line
    (loop for item in processed-line-items do
      (let* ((item-align-self (getf item :align-self))
             (effective-align (if (eq item-align-self :auto) align-items item-align-self))
             (styled-cross-dim (getf item :styled-cross-dim))
             (final-cross-size 0)
             (cross-pos 0))
        (cond
          ((and (eq effective-align :stretch) (eq styled-cross-dim :auto))
           (setf final-cross-size container-total-cross-size)) ; Stretch to line\'s effective cross size (passed as container-total-cross-size)
          ((numberp styled-cross-dim) (setf final-cross-size styled-cross-dim))
          (t (setf final-cross-size (if is-row 3 5)))) ; Default cross size
        (setf final-cross-size (max (getf item :min-cross) (min final-cross-size (getf item :max-cross))))
        (setf (getf item :final-cross-size) final-cross-size)
        (cond
          ((eq effective-align :flex-end) (setf cross-pos (- container-total-cross-size final-cross-size)))
          ((eq effective-align :center) (setf cross-pos (/ (- container-total-cross-size final-cross-size) 2)))
          (t (setf cross-pos 0))) ; :flex-start or :stretch (position at start)
        (setf (getf item :cross-pos) cross-pos)))
    processed-line-items))

(defun calculate-line-actual-cross-size (processed-line-items _is-row)
  "Determines the effective cross-size of a line based on its items."
  (declare (ignore _is-row)) ; May be used later for baseline or other complex scenarios
  (if (null processed-line-items)
      0
      (loop for item in processed-line-items
            maximize (getf item :final-cross-size))))

;;;----------------------------------------------------------------------------
;;; Helper function to get content-based size (placeholder)
;;;----------------------------------------------------------------------------
(defun get-item-content-main-size (item is-row)
  "Placeholder function to get the content-based main size of a flex item.
   This would need to inspect the item's content (e.g., text length for a label)
   or potentially trigger a pre-layout calculation for complex children.
   For now, returns a default value."
  (declare (ignore item))
  (if is-row 5 3)) ; Default content size: 5 for width, 3 for height

;;;----------------------------------------------------------------------------
;;; Top-Level Flex Layout Computation Function
;;;----------------------------------------------------------------------------
(defun compute-flex-layout (flex-container-node parent-absolute-content-rect parent-style-set)
  "Computes the layout for a flex container and its children using a simplified Flexbox model.
   Handles multiple flex lines if `flex-wrap` is `wrap` or `wrap-reverse`.
   Supports flex-direction, justify-content, align-items, align-self, align-content,
   flex-grow, flex-shrink, flex-basis (including percentages and :content), order, and min/max sizes.

   LIMITATIONS & TODOs:
   - Baseline Alignment (`align-items: :baseline`, `align-self: :baseline`):
     TODO: Implement baseline alignment. This requires items to report their baseline position.
           For text-based elements, this is the baseline of the first line of text.
           This can be complex in a TUI context if not all elements have clear text baselines.
           Currently, :baseline is treated as :flex-start.
   - Gaps (`row-gap`, `column-gap`): Not yet implemented between lines or items.
     TODO: Add support for flexbox gaps.
   - Intrinsic Aspect Ratios: Not considered.
   - Margin/Padding/Border on Flex Items: Assumed to be handled by the caller (`layout-view`)
     by adjusting the space available to this function and interpreting item rects.
   - Floating Point Precision: Calculations use floating point numbers. Final rects are rounded.
  "

  (declare (ignore parent-style-set))

  (log:debug "FLEX-LAYOUT (Multi-line, Enhanced): Computing layout for ~S in available rect ~S"
             (getf (ui-node-props flex-container-node) :id "N/A")
             parent-absolute-content-rect)

  ;; 1. Extract Flex Container Properties & Determine Axes
  (let* ((container-styles (styles flex-container-node))
         (flex-direction (style-value container-styles :flex-direction :row))
         (flex-wrap (style-value container-styles :flex-wrap :nowrap))
         (justify-content (style-value container-styles :justify-content :flex-start))
         (align-items (style-value container-styles :align-items :stretch))
         (align-content (style-value container-styles :align-content :stretch))

         (styled-container-width (style-value container-styles :width))
         (styled-container-height (style-value container-styles :height))

         (container-content-x (x parent-absolute-content-rect))
         (container-content-y (y parent-absolute-content-rect))
         (available-width (if (numberp styled-container-width) styled-container-width (w parent-absolute-content-rect)))
         (available-height (if (numberp styled-container-height) styled-container-height (h parent-absolute-content-rect)))

         (is-row (member flex-direction '(:row :row-reverse)))
         (is-column (member flex-direction '(:column :column-reverse)))
         (is-main-axis-reverse (member flex-direction '(:row-reverse :column-reverse)))

         (main-axis-size (if is-row available-width available-height))
         (cross-axis-size (if is-row available-height available-width))
         
         (children (ui-node-children flex-container-node))
         (all-items-initial-data \'()))

    (log:trace "FLEX-LAYOUT: Dir: ~A, Wrap: ~A, Container Avail W: ~A, H: ~A, MainSize: ~A, CrossSize: ~A"
               flex-direction flex-wrap available-width available-height main-axis-size cross-axis-size)

    ;; 2. Collect Initial Data for All Flex Items
    (loop for child in children do
      (when (typep child \'styled-ui-node)
        (let* ((child-styles (styles child))
               (child-props (ui-node-props child))
               (order (style-value child-styles :order 0)) ; Get order
               (flex-basis (style-value child-styles :flex-basis :auto))
               (flex-grow (style-value child-styles :flex-grow 0))
               (flex-shrink (style-value child-styles :flex-shrink 1))
               (align-self (style-value child-styles :align-self :auto))
               
               (styled-main-dim (if is-row (style-value child-styles :width) (style-value child-styles :height)))
               (styled-cross-dim (if is-row (style-value child-styles :height) (style-value child-styles :width)))

               (min-main-dim (if is-row (style-value child-styles :min-width 0) (style-value child-styles :min-height 0)))
               (max-main-dim (if is-row (style-value child-styles :max-width most-positive-fixnum) (style-value child-styles :max-height most-positive-fixnum)))
               (min-cross-dim (if is-row (style-value child-styles :min-height 0) (style-value child-styles :min-width 0)))
               (max-cross-dim (if is-row (style-value child-styles :max-height most-positive-fixnum) (style-value child-styles :max-width most-positive-fixnum)))
               
               (hypothetical-main-size 0))
          ;; Determine hypothetical main size based on flex-basis, then styled main dimension
          (cond
            ((numberp flex-basis) (setf hypothetical-main-size flex-basis))
            ((and (consp flex-basis) (eq (car flex-basis) :percentage) (numberp (cadr flex-basis)))
             ;; Percentage flex-basis is relative to flex container's inner main size
             (setf hypothetical-main-size (* main-axis-size (/ (cadr flex-basis) 100.0))))
            ((eq flex-basis :content)
             (setf hypothetical-main-size (get-item-content-main-size child is-row)))
            ((eq flex-basis :auto)
             (if (numberp styled-main-dim)
                 (setf hypothetical-main-size styled-main-dim)
                 ;; If auto and no explicit size, try content size as basis
                 (setf hypothetical-main-size (get-item-content-main-size child is-row))))
            (t (setf hypothetical-main-size (get-item-content-main-size child is-row)))) ; Default for unhandled basis

          ;; Clamp by min/max
          (setf hypothetical-main-size (max min-main-dim (min hypothetical-main-size max-main-dim)))
          
          (push (list :node child :props child-props :styles child-styles :order order
                      :hypothetical-main-size hypothetical-main-size
                      :final-main-size hypothetical-main-size ; Initialize final with hypothetical
                      :flex-grow flex-grow :flex-shrink flex-shrink
                      :align-self align-self
                      :min-main min-main-dim :max-main max-main-dim
                      :main-pos 0.0 :cross-pos 0.0 :final-cross-size 0.0)
                all-items-initial-data))))
    (setf all-items-initial-data (nreverse all-items-initial-data)) ; Preserve original child order

    ;; 3. Line Breaking: Group items into flex lines
    (let ((flex-lines \'())
          (current-line-items \'())
          (current-line-main-size-used 0.0))
      (loop for item-data in all-items-initial-data do
        (let ((item-hypothetical-main-size (getf item-data :hypothetical-main-size)))
          ;; If nowrap, or first item on line, or item fits
          (if (or (eq flex-wrap :nowrap)
                  (null current-line-items)
                  (<= (+ current-line-main-size-used item-hypothetical-main-size) main-axis-size))
              (progn
                (push item-data current-line-items)
                (incf current-line-main-size-used item-hypothetical-main-size))
              (progn ; Overflow, finalize current line and start new one
                (when current-line-items (push (nreverse current-line-items) flex-lines))
                (setf current-line-items (list item-data))
                (setf current-line-main-size-used item-hypothetical-main-size)))))
      (when current-line-items (push (nreverse current-line-items) flex-lines))
      (setf flex-lines (nreverse flex-lines))) ; Lines are now in source order

    ;; 4. Process Each Flex Line: Main Axis Sizing and Justification, Cross Axis Sizing of Items
    (let ((processed-lines-data \'())) ; Will store list of plists: (:items items-on-line :line-initial-cross-size max-cross-on-line)
      (loop for line-items in flex-lines do
        ;; 4a. Resolve Flexible Lengths (Main Axis) for this line
        (let* ((total-hypothetical-main-size-on-line (loop for item in line-items sum (getf item :hypothetical-main-size)))
               (remaining-space-on-line (- main-axis-size total-hypothetical-main-size-on-line))
               (total-flex-grow (loop for item in line-items when (> (getf item :flex-grow 0) 0) sum (getf item :flex-grow)))
               (total-flex-shrink-weighted (loop for item in line-items 
                                                 when (> (getf item :flex-shrink 0) 0) 
                                                 sum (* (getf item :flex-shrink) (getf item :hypothetical-main-size)))))
          (cond
            ;; Distribute positive remaining space (Growing)
            ((and (> remaining-space-on-line 0) (> total-flex-grow 0))
             (loop for item in line-items
                   when (> (getf item :flex-grow 0) 0) do
               (let* ((grow-share (/ (getf item :flex-grow) total-flex-grow))
                      (space-to-add (* remaining-space-on-line grow-share))
                      (new-size (+ (getf item :final-main-size) space-to-add)))
                 (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main)))))))
            ;; Distribute negative remaining space (Shrinking)
            ((and (< remaining-space-on-line 0) (> total-flex-shrink-weighted 0))
             (let ((space-to-remove (abs remaining-space-on-line)))
               (loop for item in line-items
                     when (> (getf item :flex-shrink 0) 0) do
                 (let* ((shrink-share (/ (* (getf item :flex-shrink) (getf item :hypothetical-main-size)) total-flex-shrink-weighted))
                        (reduction (* space-to-remove shrink-share))
                        (new-size (- (getf item :final-main-size) reduction)))
                   (setf (getf item :final-main-size) (max (getf item :min-main) (min new-size (getf item :max-main))))))))))
        
        ;; 4b. Main Axis Alignment (justify-content) for this line
        (let* ((num-items-on-line (length line-items))
               (total-final-main-size-on-line (loop for item in line-items sum (getf item :final-main-size)))
               (current-remaining-space-for-justify (- main-axis-size total-final-main-size-on-line))
               (main-offset 0.0)
               (items-for-positioning (if is-main-axis-reverse (reverse line-items) line-items)))
          (cond
            ((eq justify-content :flex-end) (setf main-offset current-remaining-space-for-justify))
            ((eq justify-content :center) (setf main-offset (/ current-remaining-space-for-justify 2)))
            ((eq justify-content :space-between) 
             (when (> num-items-on-line 1) (setf main-offset 0))) ; First item at start
            ((eq justify-content :space-around)
             (if (> num-items-on-line 0) (setf main-offset (/ current-remaining-space-for-justify (* 2 num-items-on-line)))))
            ((eq justify-content :space-evenly)
             (if (> num-items-on-line 0) (setf main-offset (/ current-remaining-space-for-justify (+ 1 num-items-on-line)))))
            (t (setf main-offset 0))) ; :flex-start or default

          (loop for item in items-for-positioning for idx from 0 do
            (setf (getf item :main-pos) main-offset) ; Store main-pos relative to line start
            (incf main-offset (getf item :final-main-size))
            (cond
              ((and (eq justify-content :space-between) (> num-items-on-line 1) (< idx (1- num-items-on-line))) ; Not the last item
               (incf main-offset (/ current-remaining-space-for-justify (1- num-items-on-line))))
              ((eq justify-content :space-around)
               (incf main-offset (/ current-remaining-space-for-justify num-items-on-line))) ; Space after item
              ((eq justify-content :space-evenly)
               (incf main-offset (/ current-remaining-space-for-justify (+ 1 num-items-on-line)))))))) ; Space after item

        ;; 4c. Cross Axis Sizing for items on this line & Determine Max Line Cross Size
        (let ((max-cross-size-this-line 0.0))
          (loop for item in line-items do
            (let* ((item-styles (getf item :styles))
                   (align-self-val (getf item :align-self))
                   (effective-align-item (if (eq align-self-val :auto) align-items align-self-val))
                   ;; Handle :baseline as :flex-start for now in sizing/positioning
                   (effective-align-item-for-sizing (if (eq effective-align-item :baseline) :flex-start effective-align-item))
                   (styled-cross-dim (getf item :styled-cross-dim))
                   (final-cross-size 0))
              (cond
                ((numberp styled-cross-dim) (setf final-cross-size styled-cross-dim))
                ((eq styled-cross-dim :auto)
                 (if (eq effective-align-item-for-sizing :stretch)
                     (setf final-cross-size -1) ; Mark for later stretch
                     (setf final-cross-size (get-item-content-main-size item (not is-row))))) ; Use content size for cross if auto and not stretch
                (t (setf final-cross-size (get-item-content-main-size item (not is-row))))) ; Default cross size for other values

              (when (/= final-cross-size -1) ; If not marked for stretch
                (setf final-cross-size (max (getf item :min-cross) (min final-cross-size (getf item :max-cross)))))
              (setf (getf item :final-cross-size) final-cross-size) ; Store this, might be -1 (needs resolving)
              
              ;; Update max-cross-size-this-line based on definite sizes
              (when (> final-cross-size 0) (setf max-cross-size-this-line (max max-cross-size-this-line final-cross-size)))))
          
          ;; Resolve any -1 (stretch) final-cross-sizes to the max definite size on the line
          ;; If all items were -1 or 0, use a default line height.
          (when (and (= max-cross-size-this-line 0) (some (lambda (it) (eql (getf it :final-cross-size) -1)) line-items))
             (setf max-cross-size-this-line (if is-row 3 5))) ; Default line height if all items are stretch and no fixed height items

          (loop for item in line-items do
             (when (eql (getf item :final-cross-size) -1)
                (setf (getf item :final-cross-size) 
                      (max (getf item :min-cross) (min max-cross-size-this-line (getf item :max-cross))))))
          ;; Recalculate max-cross-size-this-line based on actual final sizes of items on this line
          (setf max-cross-size-this-line (loop for item in line-items maximizing (getf item :final-cross-size)))

          (push (list :items line-items :line-initial-cross-size max-cross-size-this-line) processed-lines-data)))
      (setf processed-lines-data (nreverse processed-lines-data)) ; Lines data in source order

      ;; 5. Determine Container's Final Cross Size (if auto) & Handle flex-wrap: wrap-reverse for line order
      (let* ((accumulated-initial-cross-size (loop for p-line-data in processed-lines-data sum (getf p-line-data :line-initial-cross-size)))
             (final-container-cross-size cross-axis-size)) ; Start with available/styled cross size
        (when (eq (if is-row styled-container-height styled-container-width) :auto)
          (setf final-container-cross-size accumulated-initial-cross-size)
          ;; Clamp by container's min/max cross
          (setf final-container-cross-size 
                (max (if is-row (style-value container-styles :min-height 0) (style-value container-styles :min-width 0))
                     (min final-container-cross-size 
                          (if is-row (style-value container-styles :max-height most-positive-fixnum) 
                                     (style-value container-styles :max-width most-positive-fixnum)))))
          (setf cross-axis-size final-container-cross-size)) ; Update effective cross-axis-size for align-content

        ;; If wrap-reverse, lines are laid out from the cross-end. Reverse the list for processing.
        (when (eq flex-wrap :wrap-reverse)
          (setf processed-lines-data (reverse processed-lines-data))))

      ;; 6. Cross Axis Alignment of Lines (align-content) and Items within lines
      (let* ((num-lines (length processed-lines-data))
             (total-initial-line-cross-sizes-sum (loop for p-line-data in processed-lines-data sum (getf p-line-data :line-initial-cross-size)))
             (inter-line-gap 0.0) 
             (total-gap-space (* (max 0 (1- num-lines)) inter-line-gap))
             (remaining-container-cross-space (- cross-axis-size total-initial-line-cross-sizes-sum total-gap-space))
             (current-line-cross-offset 0.0))

        ;; Determine starting offset and per-line spacing for align-content
        (cond
          ((eq align-content :flex-start) (setf current-line-cross-offset 0.0))
          ((eq align-content :flex-end) (setf current-line-cross-offset remaining-container-cross-space))
          ((eq align-content :center) (setf current-line-cross-offset (/ remaining-container-cross-space 2)))
          ((eq align-content :space-between)
           (setf current-line-cross-offset 0.0)
           (when (> num-lines 1) (setf inter-line-gap (/ remaining-container-cross-space (1- num-lines)))))
          ((eq align-content :space-around)
           (if (> num-lines 0)
               (let ((space-per-line (/ remaining-container-cross-space num-lines)))
                 (setf current-line-cross-offset (/ space-per-line 2))
                 (setf inter-line-gap space-per-line)) ; This gap includes the space before/after
             (setf current-line-cross-offset 0.0)))
          ((eq align-content :space-evenly)
           (if (> num-lines 0)
               (let ((space-per-division (/ remaining-container-cross-space (1+ num-lines))))
                 (setf current-line-cross-offset space-per-division)
                 (setf inter-line-gap space-per-division))
             (setf current-line-cross-offset 0.0)))
          ((eq align-content :stretch)
           (setf current-line-cross-offset 0.0)
           (when (> num-lines 0)
             (let ((stretched-line-alloc-size (/ (- cross-axis-size total-gap-space) num-lines)))
               (loop for p-line-data in processed-lines-data do
                 (setf (getf p-line-data :effective-line-cross-size) stretched-line-alloc-size))))))
        
        ;; Set cross-pos for items within each line, and position lines
        (loop for p-line-data in processed-lines-data do
          (let* ((line-items (getf p-line-data :items))
                 ;; Use :line-initial-cross-size for item alignment unless line is stretched by align-content
                 (line-intrinsic-cross-size (getf p-line-data :line-initial-cross-size))
                 (effective-line-cross-size-for-alignment 
                  (getf p-line-data :effective-line-cross-size line-intrinsic-cross-size)))
            (loop for item in line-items do
              (let* ((align-self-val (getf item :align-self))
                     (effective-align-item (if (eq align-self-val :auto) align-items align-self-val))
                     (item-final-cross-size (getf item :final-cross-size)))
                
                ;; If align-content is :stretch AND item's effective-align is :stretch,
                ;; its final cross size should be the effective-line-cross-size (the stretched line height).
                (when (and (eq align-content :stretch) (eq effective-align-item :stretch))
                  (setf item-final-cross-size 
                        (max (getf item :min-cross) 
                             (min effective-line-cross-size-for-alignment (getf item :max-cross))))
                  (setf (getf item :final-cross-size) item-final-cross-size))

                (let ((item-cross-offset-in-line 0.0))
                  (cond
                    ((eq effective-align-item :flex-end) 
                     (setf item-cross-offset-in-line (- effective-line-cross-size-for-alignment item-final-cross-size)))
                    ((eq effective-align-item :center) 
                     (setf item-cross-offset-in-line (/ (- effective-line-cross-size-for-alignment item-final-cross-size) 2)))
                    ((eq effective-align-item :stretch) 
                     (setf item-cross-offset-in-line 0.0)) 
                    ;; :baseline is treated as :flex-start here. True baseline needs baseline metrics.
                    (t (setf item-cross-offset-in-line 0.0))) 
                  (setf (getf item :cross-pos) (+ current-line-cross-offset item-cross-offset-in-line)))))
            (incf current-line-cross-offset (+ (getf p-line-data :effective-line-cross-size effective-line-cross-size-for-alignment) inter-line-gap)))))

      ;; 7. Set Layout Rects for Children
      (let ((actual-content-main-extent 0)  ;; Max main extent used by content
            (actual-content-cross-extent 0)) ;; Max cross extent used by content
        ;; Iterate through the original (non-wrap-reversed) processed_lines_data to get items
        ;; in their final calculated positions. The :cross-pos is now absolute.
        (loop for p-line-data in processed-lines-data do 
          (loop for item in (getf p-line-data :items) do
            (let* ((child-node (getf item :node))
                   (item-main-pos (getf item :main-pos)) ; Relative to line start
                   (item-cross-pos (getf item :cross-pos)) ; Absolute in container cross axis
                   (item-final-main (getf item :final-main-size))
                   (item-final-cross (getf item :final-cross-size))
                   (child-x 0) (child-y 0) (child-w 0) (child-h 0))

              (if is-row
                  (setf child-x (+ container-content-x (if is-main-axis-reverse (- main-axis-size item-main-pos item-final-main) item-main-pos))
                        child-y (+ container-content-y item-cross-pos)
                        child-w item-final-main
                        child-h item-final-cross)
                  (setf child-x (+ container-content-x item-cross-pos) 
                        child-y (+ container-content-y (if is-main-axis-reverse (- main-axis-size item-main-pos item-final-main) item-main-pos))
                        child-w item-final-cross
                        child-h item-final-main))
              
              (let ((child-rect (make-rectangle :x (round child-x) :y (round child-y) :w (round child-w) :h (round child-h))))
                (setf (getf (ui-node-props child-node) :layout-rect) child-rect)
                (log:trace "FLEX-LAYOUT: Child ~S (order ~A) (main:~A crs:~A) at rect ~S"
                           (getf (ui-node-props child-node) :id "N/A") (getf item :order)
                           item-final-main item-final-cross child-rect)
                ;; Update actual extents
                (setf actual-content-main-extent (max actual-content-main-extent 
                                                      (if is-row (+ item-main-pos item-final-main) (+ item-cross-pos item-final-cross))))
                (setf actual-content-cross-extent (max actual-content-cross-extent 
                                                       (if is-row (+ item-cross-pos item-final-cross) (+ item-main-pos item-final-main)))))))))
        
        ;; 8. Determine Final Container Rectangle
        (let ((final-container-w available-width)
              (final-container-h available-height))
          (if is-row
              (progn
                (when (eq styled-container-width :auto) (setf final-container-w actual-content-main-extent))
                (when (eq styled-container-height :auto) (setf final-container-h actual-content-cross-extent)))
              (progn
                (when (eq styled-container-width :auto) (setf final-container-w actual-content-cross-extent))
                (when (eq styled-container-height :auto) (setf final-container-h actual-content-main-extent))))
          
          (when (eq styled-container-width :auto)
            (setf final-container-w (max (style-value container-styles :min-width 0)
                                         (min final-container-w (style-value container-styles :max-width most-positive-fixnum)))))
          (when (eq styled-container-height :auto)
            (setf final-container-h (max (style-value container-styles :min-height 0)
                                         (min final-container-h (style-value container-styles :max-height most-positive-fixnum)))))

          (make-rectangle :x container-content-x
                          :y container-content-y
                          :w (round final-container-w)
                          :h (round final-container-h)))))))