;;;===============================================================
;;; File: src/view/layout-debug.lisp
;;; Layout Debugging Utilities
;;;===============================================================
(uiop:define-package :elmtui.view.layout-debug
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.view.layout #:get-lr)
  (:import-from :elmtui.view.geo
                #:rectangle #:x #:y #:w #:h #:make-rectangle)
  (:export 
   #:*debug-layout* 
   #:with-layout-debugging 
   #:format-layout-tree
   #:debug-overlay-node
   #:add-layout-debug-overlays
   #:print-node-box-model))
(in-package :elmtui.view.layout-debug)

;;;-----------------------------------------------------------------------------
;;; Debug Configuration
;;;-----------------------------------------------------------------------------

(defvar *debug-layout* nil
  "When non-nil, enables layout debugging features.
   Values:
   - nil: No debugging
   - :basic: Show basic layout info
   - :verbose: Show detailed layout info
   - :visual: Add visual indicators to rendered output")

(defmacro with-layout-debugging ((level) &body body)
  "Executes body with layout debugging enabled at specified level."
  `(let ((*debug-layout* ,level))
     ,@body))

;;;-----------------------------------------------------------------------------
;;; Layout Inspection
;;;-----------------------------------------------------------------------------

(defun format-box-model (node)
  "Returns a formatted string showing the box model properties of a node."
  (check-type node styled-ui-node)
  (let* ((id (getf (ui-node-props node) :id))
         (type (ui-node-props node))
         (margin-top (style-value node :margin-top 0))
         (margin-right (style-value node :margin-right 0))
         (margin-bottom (style-value node :margin-bottom 0))
         (margin-left (style-value node :margin-left 0))
         (border-top (style-value node :border-top-width 0))
         (border-right (style-value node :border-right-width 0))
         (border-bottom (style-value node :border-bottom-width 0))
         (border-left (style-value node :border-left-width 0))
         (padding-top (style-value node :padding-top 0))
         (padding-right (style-value node :padding-right 0))
         (padding-bottom (style-value node :padding-bottom 0))
         (padding-left (style-value node :padding-left 0))
         (width (style-value node :width :auto))
         (height (style-value node :height :auto))
         (layout-rect (get-lr node)))

    (with-output-to-string (s)
      (format s "Box Model for ~A (ID: ~A)~%" type id)
      (format s "┌─────────────────────────────────────────────────────┐~%")
      (format s "│ Margin: T:~A R:~A B:~A L:~A~%" 
              margin-top margin-right margin-bottom margin-left)
      (format s "│ Border: T:~A R:~A B:~A L:~A~%" 
              border-top border-right border-bottom border-left)
      (format s "│ Padding: T:~A R:~A B:~A L:~A~%" 
              padding-top padding-right padding-bottom padding-left)
      (format s "│ Content: W:~A H:~A~%" 
              (if (eq width :auto) "auto" width)
              (if (eq height :auto) "auto" height))
      (when layout-rect
        (format s "│ Layout: X:~A Y:~A W:~A H:~A~%" 
                (x layout-rect) (y layout-rect) (w layout-rect) (h layout-rect)))
      (format s "└─────────────────────────────────────────────────────┘~%"))))

(defun format-layout-tree (node &optional (indent 0))
  "Formats the layout tree starting at node, showing the hierarchy."
  (check-type node ui-node)
  (let ((indent-str (make-string indent :initial-element #\Space))
        (id (getf (ui-node-props node) :id))
        (type (ui-node-props node))
        (lr (get-lr node)))

    (with-output-to-string (s)
      (format s "~A~A (ID: ~A)~%" indent-str type id)
      (when lr
        (format s "~A  Layout: X:~A Y:~A W:~A H:~A~%" 
                indent-str (x lr) (y lr) (w lr) (h lr)))
      
      (when (typep node 'styled-ui-node)
        (let ((display (style-value node :display :block))
              (flex-dir (style-value node :flex-direction :row))
              (justify (style-value node :justify-content :flex-start))
              (align (style-value node :align-items :stretch)))
          
          (format s "~A  Display: ~A~%" indent-str display)
          (when (eq display :flex)
            (format s "~A  Flex: ~A Justify: ~A Align: ~A~%" 
                    indent-str flex-dir justify align))))
      
      ;; Format children
      (loop for child in (ui-node-children node)
            for child-str = (format-layout-tree child (+ indent 4))
            do (format s "~A" child-str)))))

(defun print-node-box-model (node)
  "Prints the box model for a node to the console."
  (check-type node ui-node)
  (format t "~A" (format-box-model node))
  node)

;;;-----------------------------------------------------------------------------
;;; Visual Debugging
;;;-----------------------------------------------------------------------------

(defun debug-overlay-node (node)
  "Creates a debugging overlay for a node to visualize margins, borders, and padding."
  (check-type node styled-ui-node)
  (let* ((lr (get-lr node))
         (id (getf (ui-node-props node) :id)))
    
    (when (and lr id)
      ;; Create an overlay node that highlights this node's position and size
      (let* ((margin-top (style-value node :margin-top 0))
             (margin-right (style-value node :margin-right 0))
             (margin-bottom (style-value node :margin-bottom 0))
             (margin-left (style-value node :margin-left 0))
             
             ;; Create rectangle that includes margins
             (margin-rect (make-rectangle 
                           :x (- (x lr) margin-left)
                           :y (- (y lr) margin-top)
                           :w (+ (w lr) margin-left margin-right)
                           :h (+ (h lr) margin-top margin-bottom)))
             
             ;; Create debug node for this element
             (debug-node (make-instance 'styled-ui-node
                                        :type :debug-overlay
                                        :props (list :id (format nil "debug-~A" id)
                                                     :original-id id)
                                        :children nil)))
        
        ;; Set layout rectangle
        (setf (get-lr debug-node) margin-rect)
        
        ;; Style the debug overlay based on node type
        (let ((border-color (case (getf (ui-node-props node) :type)
                              (:div :blue)
                              (:button :green)
                              (:text-input :red)
                              (otherwise :gray))))
          
          ;; Apply debug styles
          (setf (style-value debug-node :border-style) :dashed)
          (setf (style-value debug-node :border-color) border-color)
          (setf (style-value debug-node :background-color) nil)
          (setf (style-value debug-node :opacity) 0.5))
        
        debug-node))))

(defun add-layout-debug-overlays (root-node)
  "Adds debug overlay nodes to visualize the layout of each node in the tree."
  (check-type root-node ui-node)
  
  ;; Only proceed if layout debugging is enabled at visual level
  (unless (eq *debug-layout* :visual)
    (return-from add-layout-debug-overlays root-node))
  
  ;; Collect all overlay nodes
  (let ((overlays '()))
    ;; Recursively create overlays for all nodes in the tree
    (labels ((process-node (node)
               ;; Add this node's overlay
               (when (typep node 'styled-ui-node)
                 (let ((overlay (debug-overlay-node node)))
                   (when overlay
                     (push overlay overlays))))
               
               ;; Process children
               (dolist (child (ui-node-children node))
                 (process-node child))))
      
      (process-node root-node)
      
      ;; Create a container for overlays and add it as a sibling to root
      (let ((overlay-container (make-instance 'styled-ui-node
                                              :type :debug-overlay-container
                                              :props (list :id "debug-overlay-container")
                                              :children (nreverse overlays))))
        
        ;; Return both the original root and the overlay container
        (values root-node overlay-container)))))

;;;-----------------------------------------------------------------------------
;;; Export/Log Functions
;;;-----------------------------------------------------------------------------

(defun export-layout-info (root-node &key (format :text) (stream *standard-output*))
  "Exports layout information for debugging purposes.
   FORMAT: :text (human-readable), :json, :sexpr (s-expression)"
  (check-type root-node ui-node)
  
  (case format
    (:text
     (format stream "~A~%" (format-layout-tree root-node)))
    
    (:json
     (format stream "{\"layout\": \"TODO: Implement JSON export\"}~%"))
    
    (:sexpr
     (let ((layout-data '()))
       ;; Build s-expression data
       (labels ((collect-node-data (node)
                  (let* ((id (getf (ui-node-props node) :id))
                         (type (ui-node-props node))
                         (lr (get-lr node))
                         (node-data `(:id ,id :type ,type
                                     ,@(when lr `(:x ,(x lr) :y ,(y lr)
                                                  :width ,(w lr) :height ,(h lr))))))
                    
                    ;; Add this node's data
                    (push node-data layout-data)
                    
                    ;; Process children
                    (dolist (child (ui-node-children node))
                      (collect-node-data child)))))
         
         (collect-node-data root-node)
         (format stream "~S~%" (nreverse layout-data)))))
    
    (otherwise
     (error "Unknown export format: ~A" format))))
