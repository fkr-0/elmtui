;;;===============================================================
;;; File: src/view/diff-renderer.lisp
;;; Enhanced Diff-based Rendering for View System
;;;===============================================================
(uiop:define-package :elmtui.view.diff-renderer
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.view.geo
                #:rectangle #:x #:y #:w #:h)
  (:export 
   #:diff-nodes
   #:diff-patch
   #:apply-patches
   #:patch-type
   #:patch-path
   #:patch-data
   #:*diff-debug*
   #:with-diff-debugging))
(in-package :elmtui.view.diff-renderer)

;;;-----------------------------------------------------------------------------
;;; Diff Configuration
;;;-----------------------------------------------------------------------------

(defvar *diff-debug* nil
  "When non-nil, enables debug output for the diffing process.
   Values:
   - nil: No debugging
   - :basic: Show basic diff info
   - :verbose: Show detailed diff info
   - :patches: Show generated patches")

(defmacro with-diff-debugging ((level) &body body)
  "Executes body with diff debugging enabled at specified level."
  `(let ((*diff-debug* ,level))
     ,@body))

;;;-----------------------------------------------------------------------------
;;; Diff Patch Structures
;;;-----------------------------------------------------------------------------

(defstruct diff-patch
  "Represents a single change to be applied to a view tree."
  (type nil :type symbol :read-only t)   ; :replace, :props, :add, :remove, etc.
  (path nil :type list :read-only t)      ; Path to the node in the tree (list of indices)
  (data nil :type t :read-only t))        ; Patch-specific data

;;;-----------------------------------------------------------------------------
;;; Node Identification and Path Calculation
;;;-----------------------------------------------------------------------------

(defun node-key (node)
  "Returns a key that uniquely identifies a node within its siblings.
   Uses :key prop if present, falls back to :id, then type + index."
  (or (getf (ui-node-props node) :key)
      (getf (ui-node-props node) :id)
      (ui-node-type node)))

(defun find-node-path (root target &optional path)
  "Finds the path to a target node in a tree.
   Returns a list of indices that can be used to navigate to the node."
  (if (eq root target)
      (nreverse path)
      (loop for child in (ui-node-children root)
            for i from 0
            for child-path = (find-node-path child target (cons i path))
            when child-path
              return child-path
            finally (return nil))))

(defun node-at-path (root path)
  "Returns the node at the given path in the tree."
  (if (null path)
      root
      (let ((index (first path)))
        (when (< index (length (ui-node-children root)))
          (node-at-path (nth index (ui-node-children root))
                       (rest path))))))

;;;-----------------------------------------------------------------------------
;;; Core Diffing Algorithm
;;;-----------------------------------------------------------------------------

(defun same-node-type-p (node1 node2)
  "Returns true if the nodes have the same type."
  (eq (ui-node-type node1) (ui-node-type node2)))

(defun props-equal-p (props1 props2 &key ignore-keys)
  "Returns true if the property lists are equivalent.
   IGNORE-KEYS: List of keys to ignore in the comparison."
  (flet ((relevant-props (props)
           (loop for (key val) on props by #'cddr
                 unless (member key ignore-keys)
                   collect key and collect val)))
    (equal (relevant-props props1) (relevant-props props2))))

(defun diff-props (old-props new-props &key ignore-keys)
  "Returns a list of updated properties from old-props to new-props.
   Result format: (:key1 new-val1 :key2 new-val2 ...)
   IGNORE-KEYS: List of keys to ignore in the comparison."
  
  (let ((result nil))
    ;; Find changed and added props
    (loop for (key val) on new-props by #'cddr
          unless (member key ignore-keys)
            do (let ((old-val (getf old-props key 'not-found)))
                 (unless (equal val old-val)
                   (setf result (list* key val result)))))
    
    ;; Find removed props (set to nil)
    (loop for (key val) on old-props by #'cddr
          unless (or (member key ignore-keys)
                     (member key result)
                     (getf new-props key 'not-found))
            do (setf result (list* key nil result)))
    
    (nreverse result)))

(defun calculate-edits (old-list new-list &key (key-fn #'node-key))
  "Calculates minimum edits to transform old-list to new-list.
   Uses key-fn to identify matching elements.
   Returns three values:
   1. Items only in old list (to be removed)
   2. Items only in new list (to be added)
   3. Pairs of matching items (old . new) (to be potentially updated)"
  
  ;; Build key -> item maps
  (let ((old-map (make-hash-table :test 'equal))
        (new-map (make-hash-table :test 'equal)))
    
    (loop for item in old-list
          for key = (funcall key-fn item)
          do (setf (gethash key old-map) item))
    
    (loop for item in new-list
          for key = (funcall key-fn item)
          do (setf (gethash key new-map) item))
    
    ;; Calculate differences
    (let ((removes nil)
          (adds nil)
          (updates nil))
      
      ;; Find removes and updates
      (loop for old-item in old-list
            for key = (funcall key-fn old-item)
            for new-item = (gethash key new-map)
            if new-item
              do (push (cons old-item new-item) updates)
            else
              do (push old-item removes))
      
      ;; Find adds
      (loop for new-item in new-list
            for key = (funcall key-fn new-item)
            unless (gethash key old-map)
              do (push new-item adds))
      
      ;; Return results
      (values (nreverse removes) (nreverse adds) (nreverse updates)))))

(defun diff-nodes (old-node new-node &key path)
  "Computes the difference between two UI node trees.
   Returns a list of diff-patch structures that can be applied to transform
   old-node into new-node.
   
   PATH: Optional initial path context (for recursive calls)."
  
  (let ((patches nil))
    (labels ((add-patch (type path data)
               (when *diff-debug*
                 (log:debug "Adding patch: ~A at ~A with ~A" type path data))
               (push (make-diff-patch :type type :path path :data data) patches))
             
             (diff-node-children (old-children new-children parent-path)
               ;; Optimized child diffing using key-based matching
               (multiple-value-bind (removes adds updates)
                   (calculate-edits old-children new-children)
                 
                 ;; Process removed children
                 (loop for item in removes
                       for index = (position item old-children)
                       when index
                         do (add-patch :remove (append parent-path (list index)) nil))
                 
                 ;; Process added children
                 (loop for item in adds
                       for index = (position item new-children)
                       when index
                         do (add-patch :add (append parent-path (list index)) item))
                 
                 ;; Process updated children
                 (loop for (old-item . new-item) in updates
                       for old-index = (position old-item old-children)
                       for new-index = (position new-item new-children)
                       when (and old-index new-index)
                         do (cond
                              ;; Different node types - replace
                              ((not (same-node-type-p old-item new-item))
                               (add-patch :replace (append parent-path (list old-index)) new-item))
                              
                              ;; Same type but different position - move
                              ((not (= old-index new-index))
                               (add-patch :move (append parent-path (list old-index)) new-index))
                              
                              ;; Same type, same position - recursively diff
                              (t
                               (let ((child-patches 
                                      (diff-nodes old-item new-item 
                                                :path (append parent-path (list old-index)))))
                                 (setf patches (append patches child-patches)))))))))
      
      ;; Start the diff process
      (cond
        ;; Both nil - no diff
        ((and (null old-node) (null new-node))
         nil)
        
        ;; Old nil, new exists - add
        ((null old-node)
         (add-patch :add path new-node))
        
        ;; Old exists, new nil - remove
        ((null new-node)
         (add-patch :remove path nil))
        
        ;; Different types - replace
        ((not (same-node-type-p old-node new-node))
         (add-patch :replace path new-node))
        
        ;; Same type - check props and children
        (t
         ;; Check props
         (let ((props-diff (diff-props (ui-node-props old-node) 
                                      (ui-node-props new-node))))
           (when props-diff
             (add-patch :props path props-diff)))
         
         ;; Check children
         (diff-node-children (ui-node-children old-node)
                            (ui-node-children new-node)
                            (or path '()))))))
    
    ;; Return all patches
    (nreverse patches)))

;;;-----------------------------------------------------------------------------
;;; Patch Application
;;;-----------------------------------------------------------------------------

(defun make-patch-applier (root-node)
  "Creates a closure that can apply patches to the given root node.
   Returns a function that takes a patch and returns the updated node tree."
  
  (let ((current-tree root-node))
    (lambda (patch)
      (setf current-tree (apply-patch current-tree patch))
      current-tree)))

(defun apply-patch (root patch)
  "Applies a single patch to the node tree.
   Returns the updated tree."
  
  (let* ((path (patch-path patch))
         (parent-path (butlast path))
         (index (when (not (null path)) (car (last path))))
         (parent (if parent-path 
                     (node-at-path root parent-path)
                     root)))
    
    (case (patch-type patch)
      ;; Replace node
      (:replace
       (if (null path)
           ;; Root replacement
           (patch-data patch)
           ;; Child replacement
           (let ((new-children (copy-list (ui-node-children parent))))
             (setf (nth index new-children) (patch-data patch))
             (setf (ui-node-children parent) new-children)
             root)))
      
      ;; Update properties
      (:props
       (if (null path)
           ;; Root props update
           (let ((new-root (copy-ui-node root)))
             (setf (ui-node-props new-root) 
                   (apply #'append (ui-node-props root) (patch-data patch)))
             new-root)
           ;; Child props update
           (let* ((node (node-at-path root path))
                  (updated-node (copy-ui-node node)))
             (setf (ui-node-props updated-node) 
                   (apply #'append (ui-node-props node) (patch-data patch)))
             (let ((new-children (copy-list (ui-node-children parent))))
               (setf (nth index new-children) updated-node)
               (setf (ui-node-children parent) new-children)
               root))))
      
      ;; Add node
      (:add
       (if (null path)
           ;; Can't add at root
           (error "Cannot add at root path")
           ;; Add child
           (let ((new-children (copy-list (ui-node-children parent))))
             (if (>= index (length new-children))
                 (setf new-children (append new-children (list (patch-data patch))))
                 (setf new-children (append (subseq new-children 0 index)
                                           (list (patch-data patch))
                                           (subseq new-children index))))
             (setf (ui-node-children parent) new-children)
             root)))
      
      ;; Remove node
      (:remove
       (if (null path)
           ;; Can't remove root
           (error "Cannot remove root node")
           ;; Remove child
           (let ((new-children (copy-list (ui-node-children parent))))
             (setf new-children (append (subseq new-children 0 index)
                                       (subseq new-children (1+ index))))
             (setf (ui-node-children parent) new-children)
             root)))
      
      ;; Move node
      (:move
       (if (null path)
           ;; Can't move root
           (error "Cannot move root node")
           ;; Move child
           (let* ((new-children (copy-list (ui-node-children parent)))
                  (node (nth index new-children))
                  (target-index (patch-data patch)))
             ;; Remove from original position
             (setf new-children (append (subseq new-children 0 index)
                                       (subseq new-children (1+ index))))
             ;; Insert at new position
             (setf new-children (append (subseq new-children 0 target-index)
                                       (list node)
                                       (subseq new-children target-index)))
             (setf (ui-node-children parent) new-children)
             root)))
      
      ;; Unknown patch type
      (otherwise
       (error "Unknown patch type: ~A" (patch-type patch))))))

(defun apply-patches (root patches)
  "Applies a list of patches to the node tree.
   Returns the updated tree."
  
  (if (null patches)
      root
      (let ((applier (make-patch-applier root)))
        (dolist (patch patches)
          (funcall applier patch))
        (funcall applier nil)))) ; Return final tree

;;;-----------------------------------------------------------------------------
;;; Helper Functions for Copy Operations
;;;-----------------------------------------------------------------------------

(defun copy-ui-node (node)
  "Creates a shallow copy of a UI node.
   Children are shared with the original node."
  
  (let ((copy (make-instance (class-of node))))
    ;; Copy slots
    (setf (ui-node-type copy) (ui-node-type node))
    (setf (ui-node-props copy) (copy-list (ui-node-props node)))
    (setf (ui-node-children copy) (ui-node-children node))
    
    ;; Copy additional slots for styled-ui-node
    (when (typep node 'styled-ui-node)
      (let ((slots '(style classes dirty layout-rect)))
        (dolist (slot slots)
          (when (slot-exists-p node slot)
            (setf (slot-value copy slot) (slot-value node slot))))))
    
    copy))

;;;-----------------------------------------------------------------------------
;;; Optimization Strategies
;;;-----------------------------------------------------------------------------

(defun optimize-patches (patches)
  "Optimizes a list of patches to minimize rendering operations.
   Returns an optimized list of patches."
  
  (let ((result nil)
        (props-patches (make-hash-table :test 'equal)))
    
    ;; Group property patches for the same node
    (dolist (patch patches)
      (if (eq (patch-type patch) :props)
          (let ((path (patch-path patch))
                (props (patch-data patch)))
            (if (gethash path props-patches)
                ;; Merge with existing props patch
                (setf (gethash path props-patches)
                      (append (gethash path props-patches) props))
                ;; New props patch
                (setf (gethash path props-patches) props)))
          ;; Non-props patch
          (push patch result)))
    
    ;; Add the merged props patches
    (maphash (lambda (path props)
               (push (make-diff-patch :type :props :path path :data props) result))
             props-patches)
    
    ;; Analyze patches to find more optimizations
    ;; (e.g., replace + props -> just replace)
    (let ((optimized nil)
          (replaced-paths nil))
      
      ;; Find replacement patches
      (dolist (patch result)
        (when (eq (patch-type patch) :replace)
          (push (patch-path patch) replaced-paths)))
      
      ;; Filter out redundant patches
      (dolist (patch result)
        (let ((path (patch-path patch)))
          (if (and (not (eq (patch-type patch) :replace))
                   (member path replaced-paths :test #'equal))
              ;; Skip, this node is already being replaced
              nil
              ;; Keep this patch
              (push patch optimized))))
      
      ;; Return optimized patches in original order
      (nreverse optimized))))

;;;-----------------------------------------------------------------------------
;;; Debugging Utilities
;;;-----------------------------------------------------------------------------

(defun print-patches (patches)
  "Prints a human-readable representation of diff patches."
  (format t "~&Diff Patches:~%")
  (loop for patch in patches
        for i from 1
        do (format t "  ~A. ~A at ~A: ~A~%" 
                  i (patch-type patch) (patch-path patch)
                  (case (patch-type patch)
                    (:props (patch-data patch))
                    (:replace (ui-node-type (patch-data patch)))
                    (:add (ui-node-type (patch-data patch)))
                    (:move (format nil "to position ~A" (patch-data patch)))
                    (otherwise (patch-data patch))))))

(defun export-patches-to-json (patches stream)
  "Exports patches to a JSON format for external visualization."
  (format stream "{\"patches\": [~%")
  (loop for patch in patches
        for i from 1
        do (format stream "  {\"type\": \"~(~A~)\", \"path\": ~A, \"data\": ~A}~:[~;,~]~%" 
                  (patch-type patch)
                  (if (null (patch-path patch)) "[]" 
                      (format nil "[~{~A~^, ~}]" (patch-path patch)))
                  (case (patch-type patch)
                    (:props "\"props\"") ; Simplified for this example
                    (:replace (format nil "\"replace:~(~A~)\"" 
                                     (ui-node-type (patch-data patch))))
                    (:add (format nil "\"add:~(~A~)\"" 
                                  (ui-node-type (patch-data patch))))
                    (:move (format nil "\"to:~A\"" (patch-data patch)))
                    (otherwise "null"))
                  (< i (length patches))))
  (format stream "]}~%"))
