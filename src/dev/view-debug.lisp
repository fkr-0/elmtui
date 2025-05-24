;;;===============================================================
;;; File: src/dev/view-debug.lisp
;;; View System Debugging Tools
;;;===============================================================
(uiop:define-package :elmtui.dev.view-debug
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info)
  (:import-from :elmtui.view.core 
                #:ui-node #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.styled 
                #:styled-ui-node #:style-value)
  (:import-from :elmtui.view.layout 
                #:get-lr)
  (:import-from :elmtui.view.geo
                #:rectangle #:x #:y #:w #:h)
  (:import-from :elmtui.view.layout-debug
                #:format-layout-tree
                #:format-box-model)
  (:import-from :elmtui.view.diff-renderer
                #:diff-nodes
                #:print-patches)
  (:export 
   #:inspector-window
   #:debug-view-tree
   #:trace-view-updates
   #:visualize-diff
   #:export-view-tree))
(in-package :elmtui.dev.view-debug)

;;;-----------------------------------------------------------------------------
;;; View Inspector Components
;;;-----------------------------------------------------------------------------

(defun props-to-string (props)
  "Converts a property list to a readable string representation."
  (with-output-to-string (s)
    (loop for (key val) on props by #'cddr
          do (format s "~A: ~S~%" key val))))

(defun node-info-string (node)
  "Creates a detailed information string about a node."
  (with-output-to-string (s)
    (format s "Type: ~A~%" (ui-node-type node))
    (format s "ID: ~A~%" (getf (ui-node-props node) :id))
    (format s "Children: ~A~%" (length (ui-node-children node)))
    
    (when (typep node 'styled-ui-node)
      (let ((display (style-value node :display :block))
            (lr (get-lr node)))
        (format s "Display: ~A~%" display)
        (when lr
          (format s "Position: (~A,~A)~%" (x lr) (y lr))
          (format s "Size: ~Ax~A~%" (w lr) (h lr)))))
    
    (format s "~%Properties:~%~A" (props-to-string (ui-node-props node)))))

(defun inspector-window (node &key (width 60) (height 20))
  "Creates a debug overlay window showing node information.
   
   NODE: The node to inspect.
   WIDTH: Width of the inspector window.
   HEIGHT: Height of the inspector window.
   
   Returns a UI node representing the inspector window."
  
  (let ((info-text (node-info-string node))
        (box-model (format-box-model node))
        (id (getf (ui-node-props node) :id)))
    
    ;; Create an overlay window
    (make-instance 'styled-ui-node
                  :type :debug-inspector
                  :props (list :id (format nil "inspector-~A" id)
                              :title (format nil "Inspector: ~A (~A)" 
                                            id (ui-node-type node))
                              :width width
                              :height height)
                  :children (list
                             ;; Tab controls
                             (make-instance 'styled-ui-node
                                           :type :debug-tabs
                                           :props (list :id (format nil "inspector-tabs-~A" id))
                                           :children (list
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-tab
                                                                    :props (list :id "props-tab"
                                                                                :label "Properties")
                                                                    :children nil)
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-tab
                                                                    :props (list :id "box-tab"
                                                                                :label "Box Model")
                                                                    :children nil)
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-tab
                                                                    :props (list :id "tree-tab"
                                                                                :label "Tree")
                                                                    :children nil)))
                             
                             ;; Content area
                             (make-instance 'styled-ui-node
                                           :type :debug-content
                                           :props (list :id (format nil "inspector-content-~A" id))
                                           :children (list
                                                      ;; Properties tab
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-panel
                                                                    :props (list :id "props-panel"
                                                                                :visible t)
                                                                    :children (list
                                                                               (make-instance 'styled-ui-node
                                                                                             :type :text
                                                                                             :props (list :id "props-text"
                                                                                                         :value info-text)
                                                                                             :children nil)))
                                                      
                                                      ;; Box model tab
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-panel
                                                                    :props (list :id "box-panel"
                                                                                :visible nil)
                                                                    :children (list
                                                                               (make-instance 'styled-ui-node
                                                                                             :type :text
                                                                                             :props (list :id "box-text"
                                                                                                         :value box-model)
                                                                                             :children nil)))
                                                      
                                                      ;; Tree tab
                                                      (make-instance 'styled-ui-node
                                                                    :type :debug-panel
                                                                    :props (list :id "tree-panel"
                                                                                :visible nil)
                                                                    :children (list
                                                                               (make-instance 'styled-ui-node
                                                                                             :type :text
                                                                                             :props (list :id "tree-text"
                                                                                                         :value (format-layout-tree node))
                                                                                             :children nil))))))))))

;;;-----------------------------------------------------------------------------
;;; View Tree Visualization
;;;-----------------------------------------------------------------------------

(defun debug-view-tree (root &optional output-file)
  "Renders a visual representation of the view tree.
   If OUTPUT-FILE is provided, saves the visualization to that file.
   Otherwise, returns a string representation."
  
  (labels ((node-to-list (node depth)
             (let ((indent (make-string depth :initial-element #\Space))
                   (id (getf (ui-node-props node) :id))
                   (type (ui-node-type node))
                   (lr (get-lr node)))
               
               (with-output-to-string (s)
                 ;; Node header
                 (format s "~A~A~A ~A~%" 
                        indent
                        (if (zerop depth) "● " "├─")
                        type
                        (if id (format nil "(#~A)" id) ""))
                 
                 ;; Position/size if available
                 (when lr
                   (format s "~A│ pos: (~A,~A) size: ~Ax~A~%" 
                          indent (x lr) (y lr) (w lr) (h lr)))
                 
                 ;; Children
                 (loop for child in (ui-node-children node)
                       for child-repr = (node-to-list child (+ depth 2))
                       do (format s "~A│~%" indent)
                       do (format s "~A" child-repr))))))
    
    (let ((tree-repr (node-to-list root 0)))
      (if output-file
          (with-open-file (f output-file :direction :output :if-exists :supersede)
            (write-string tree-repr f)
            (format t "View tree visualization saved to ~A~%" output-file))
          tree-repr))))

(defun trace-view-updates (old-view new-view &key (level :basic))
  "Traces the differences between two view trees.
   LEVEL can be :basic, :detailed, or :verbose."
  
  (let* ((patches (diff-nodes old-view new-view))
         (patch-count (length patches)))
    
    (format t "~&View Update: ~A patches~%" patch-count)
    
    (case level
      (:basic
       (format t "Types of changes: ~{~A~^, ~}~%"
              (remove-duplicates (mapcar #'diff-renderer::patch-type patches))))
      
      (:detailed
       (print-patches patches))
      
      (:verbose
       (print-patches patches)
       (format t "~%Old tree:~%~A~%" (debug-view-tree old-view))
       (format t "~%New tree:~%~A~%" (debug-view-tree new-view))))
    
    patches))

(defun visualize-diff (old-view new-view output-file)
  "Creates a visual diff between two view trees and saves it to a file."
  
  (let ((patches (diff-nodes old-view new-view)))
    (with-open-file (f output-file :direction :output :if-exists :supersede)
      ;; Write header
      (format f "<!DOCTYPE html>~%<html><head>~%")
      (format f "<title>ElmTUI View Diff</title>~%")
      (format f "<style>~%")
      (format f "body { font-family: monospace; }~%")
      (format f ".patch { margin: 10px 0; padding: 5px; border: 1px solid #ccc; }~%")
      (format f ".patch-replace { background-color: #ffdddd; }~%")
      (format f ".patch-props { background-color: #ddffdd; }~%")
      (format f ".patch-add { background-color: #ddddff; }~%")
      (format f ".patch-remove { background-color: #ffddff; }~%")
      (format f "</style>~%")
      (format f "</head><body>~%")
      
      ;; Write diff summary
      (format f "<h1>View Diff: ~A changes</h1>~%" (length patches))
      
      ;; Write patches
      (loop for patch in patches
            for i from 1
            do (format f "<div class=\"patch patch-~(~A~)\">~%" 
                      (diff-renderer::patch-type patch))
            do (format f "<h3>~A. ~A at path: ~A</h3>~%" 
                      i (diff-renderer::patch-type patch)
                      (diff-renderer::patch-path patch))
            do (case (diff-renderer::patch-type patch)
                 (:props
                  (format f "<pre>~A</pre>~%" 
                         (props-to-string (diff-renderer::patch-data patch))))
                 (:replace
                  (let ((new-node (diff-renderer::patch-data patch)))
                    (format f "<p>Replace with: ~A (ID: ~A)</p>~%" 
                           (ui-node-type new-node)
                           (getf (ui-node-props new-node) :id))))
                 (:add
                  (let ((new-node (diff-renderer::patch-data patch)))
                    (format f "<p>Add: ~A (ID: ~A)</p>~%" 
                           (ui-node-type new-node)
                           (getf (ui-node-props new-node) :id))))
                 (:remove
                  (format f "<p>Remove node</p>~%"))
                 (:move
                  (format f "<p>Move to position: ~A</p>~%" 
                         (diff-renderer::patch-data patch))))
            do (format f "</div>~%"))
      
      ;; Write footer
      (format f "</body></html>~%"))
    
    (format t "Diff visualization saved to ~A~%" output-file)))

;;;-----------------------------------------------------------------------------
;;; Debug Menu and Utilities
;;;-----------------------------------------------------------------------------

(defun export-view-tree (root format output-file)
  "Exports a view tree in the specified format.
   FORMAT can be :text, :html, :json, or :dot (GraphViz)."
  
  (case format
    (:text
     (with-open-file (f output-file :direction :output :if-exists :supersede)
       (write-string (debug-view-tree root) f)))
    
    (:html
     (with-open-file (f output-file :direction :output :if-exists :supersede)
       ;; Write header
       (format f "<!DOCTYPE html>~%<html><head>~%")
       (format f "<title>ElmTUI View Tree</title>~%")
       (format f "<style>~%")
       (format f "body { font-family: monospace; }~%")
       (format f ".node { margin-left: 20px; }~%")
       (format f ".node-header { cursor: pointer; }~%")
       (format f ".node-content { margin-left: 20px; display: none; }~%")
       (format f ".node-expanded .node-content { display: block; }~%")
       (format f ".props { color: #666; }~%")
       (format f "</style>~%")
       (format f "<script>~%")
       (format f "function toggleNode(id) {~%")
       (format f "  const node = document.getElementById(id);~%")
       (format f "  node.classList.toggle('node-expanded');~%")
       (format f "}~%")
       (format f "</script>~%")
       (format f "</head><body>~%")
       
       ;; Write tree
       (labels ((write-node (node id)
                  (let ((node-id (format nil "node-~A" id))
                        (lr (get-lr node)))
                    
                    (format f "<div class=\"node\" id=\"~A\">~%" node-id)
                    
                    ;; Node header
                    (format f "<div class=\"node-header\" onclick=\"toggleNode('~A')\">~%" node-id)
                    (format f "<strong>~A</strong> " (ui-node-type node))
                    (format f "<span class=\"id\">(ID: ~A)</span>~%" 
                           (getf (ui-node-props node) :id))
                    (format f "</div>~%")
                    
                    ;; Node content (hidden by default)
                    (format f "<div class=\"node-content\">~%")
                    
                    ;; Position/size if available
                    (when lr
                      (format f "<div class=\"geo\">Position: (~A,~A) Size: ~Ax~A</div>~%" 
                             (x lr) (y lr) (w lr) (h lr)))
                    
                    ;; Properties
                    (format f "<div class=\"props\">~%<pre>")
                    (loop for (key val) on (ui-node-props node) by #'cddr
                          do (format f "~A: ~S~%" key val))
                    (format f "</pre>~%</div>~%")
                    
                    ;; Children
                    (when (ui-node-children node)
                      (format f "<div class=\"children\">~%")
                      (loop for child in (ui-node-children node)
                            for child-id from 0
                            do (write-node child (format nil "~A-~A" id child-id)))
                      (format f "</div>~%"))
                    
                    (format f "</div>~%") ; End node-content
                    (format f "</div>~%")))) ; End node
         
         (write-node root "root"))
       
       ;; Write footer
       (format f "</body></html>~%")))
    
    (:json
     (with-open-file (f output-file :direction :output :if-exists :supersede)
       (labels ((node-to-json (node)
                  (with-output-to-string (s)
                    (format s "{\"type\":\"~A\"," (ui-node-type node))
                    
                    ;; ID
                    (let ((id (getf (ui-node-props node) :id)))
                      (format s "\"id\":~:[null~;\"~A\"~]," id id))
                    
                    ;; Position/size
                    (let ((lr (get-lr node)))
                      (if lr
                          (format s "\"position\":{\"x\":~A,\"y\":~A,\"width\":~A,\"height\":~A}," 
                                 (x lr) (y lr) (w lr) (h lr))
                          (format s "\"position\":null,")))
                    
                    ;; Props (simplified)
                    (format s "\"props\":{")
                    (loop for (key val) on (ui-node-props node) by #'cddr
                          for first = t then nil
                          unless first do (format s ",")
                          do (format s "\"~(~A~)\":~A" 
                                    key 
                                    (if (or (stringp val) (numberp val) (eq val t) (eq val nil))
                                        (format nil "~S" val)
                                        "\"[complex value]\"")))
                    (format s "},")
                    
                    ;; Children
                    (format s "\"children\":[")
                    (loop for child in (ui-node-children node)
                          for first = t then nil
                          unless first do (format s ",")
                          do (format s "~A" (node-to-json child)))
                    (format s "]}")
                    )))
         
         (format f "~A~%" (node-to-json root)))))
    
    (:dot
     (with-open-file (f output-file :direction :output :if-exists :supersede)
       ;; Write GraphViz DOT format
       (format f "digraph view_tree {~%")
       (format f "  node [shape=box, fontname=\"sans-serif\"];~%")
       
       ;; Generate nodes and edges
       (let ((node-counter 0))
         (labels ((process-node (node parent-id)
                    (let ((node-id (format nil "node_~A" (incf node-counter)))
                          (label (format nil "~A\\n~A" 
                                        (ui-node-type node)
                                        (or (getf (ui-node-props node) :id) ""))))
                      
                      ;; Define node
                      (format f "  ~A [label=\"~A\"];~%" node-id label)
                      
                      ;; Connect to parent if any
                      (when parent-id
                        (format f "  ~A -> ~A;~%" parent-id node-id))
                      
                      ;; Process children
                      (loop for child in (ui-node-children node)
                            do (process-node child node-id)))))
           
           (process-node root nil)))
       
       (format f "}~%")))
    
    (otherwise
     (error "Unsupported export format: ~A" format)))
  
  (format t "View tree exported to ~A in ~A format~%" output-file format))
