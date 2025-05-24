(defpackage :elmtui.view.diff
  (:use :cl)
  (:export :diff-trees
           :apply-diff
           :create-patch
           :with-diff-options
           :component-key
           :diff-node
           :optimize-diff-settings
           :show-diff-stats))

(in-package :elmtui.view.diff)

;; Diff options and statistics
(defstruct diff-options
  (key-based-diff t :type boolean)
  (use-heuristics t :type boolean)
  (batch-updates t :type boolean)
  (skip-unchanged t :type boolean)
  (track-moves t :type boolean))

(defstruct diff-stats
  (nodes-compared 0)
  (nodes-unchanged 0)
  (nodes-added 0)
  (nodes-removed 0)
  (nodes-updated 0)
  (nodes-moved 0)
  (props-changed 0))

(defvar *diff-options* (make-diff-options)
  "Current diffing algorithm options")

(defvar *diff-stats* (make-diff-stats)
  "Statistics for the current diffing operation")

;; Environment for diff options
(defmacro with-diff-options ((&key (key-based-diff t)
                                   (use-heuristics t)
                                   (batch-updates t)
                                   (skip-unchanged t)
                                   (track-moves t))
                             &body body)
  "Execute BODY with the specified diff options"
  `(let ((*diff-options* (make-diff-options :key-based-diff ,key-based-diff
                                           :use-heuristics ,use-heuristics
                                           :batch-updates ,batch-updates
                                           :skip-unchanged ,skip-unchanged
                                           :track-moves ,track-moves))
         (*diff-stats* (make-diff-stats)))
     ,@body))

;; Diff node structure
(defstruct (diff-node (:constructor %make-diff-node))
  (type nil :type keyword)
  (path nil)
  (old-value nil)
  (new-value nil)
  (children nil :type list))

;; Create a diff node
(defun make-diff-node (type path old-value new-value &optional children)
  "Create a diff node"
  (%make-diff-node :type type
                  :path path
                  :old-value old-value
                  :new-value new-value
                  :children children))

;; Get component key
(defun component-key (node)
  "Extract a unique key from a component node"
  (let ((props (getf node :props)))
    (or (getf props :key)
        (getf props :id)
        node)))

;; Compare props
(defun diff-props (old-props new-props path)
  "Compare two sets of props and return a list of changes"
  (let ((changes nil)
        (all-keys (remove-duplicates 
                   (append (loop for (k v) on old-props by #'cddr collect k)
                           (loop for (k v) on new-props by #'cddr collect k))
                   :test #'eq)))
    
    (dolist (key all-keys)
      (let ((old-value (getf old-props key))
            (new-value (getf new-props key)))
        (unless (equal old-value new-value)
          (push (make-diff-node :prop-change 
                               (append path (list :props key))
                               old-value 
                               new-value)
                changes)
          (incf (diff-stats-props-changed *diff-stats*)))))
    
    (nreverse changes)))

;; Main diffing function for trees
(defun diff-trees (old-tree new-tree &optional (path nil))
  "Compare two UI trees and return a list of changes"
  (incf (diff-stats-nodes-compared *diff-stats*))
  
  (cond
    ;; Both nil - no changes
    ((and (null old-tree) (null new-tree))
     nil)
    
    ;; Node added
    ((null old-tree)
     (incf (diff-stats-nodes-added *diff-stats*))
     (list (make-diff-node :add path nil new-tree)))
    
    ;; Node removed
    ((null new-tree)
     (incf (diff-stats-nodes-removed *diff-stats*))
     (list (make-diff-node :remove path old-tree nil)))
    
    ;; Both are not component nodes (e.g., strings or values)
    ((and (not (listp old-tree)) (not (listp new-tree)))
     (if (equal old-tree new-tree)
         (progn
           (incf (diff-stats-nodes-unchanged *diff-stats*))
           nil)
         (progn
           (incf (diff-stats-nodes-updated *diff-stats*))
           (list (make-diff-node :replace path old-tree new-tree)))))
    
    ;; Different types of nodes
    ((or (listp old-tree) (listp new-tree))
     (if (and (listp old-tree) (listp new-tree)
              (eq (getf old-tree :type) (getf new-tree :type)))
         ;; Same component type - check props and children
         (let ((props-diff (diff-props (getf old-tree :props) 
                                       (getf new-tree :props) 
                                       path))
               (children-diff nil))
           
           ;; Apply key-based diffing to children if enabled
           (when (diff-options-key-based-diff *diff-options*)
             (setf children-diff 
                   (diff-children-keyed (getf old-tree :children)
                                        (getf new-tree :children)
                                        (append path (list :children)))))
           
           ;; Fall back to index-based diffing if no keys or disabled
           (unless children-diff
             (setf children-diff 
                   (diff-children-indexed (getf old-tree :children)
                                          (getf new-tree :children)
                                          (append path (list :children)))))
           
           ;; Combine props and children diffs
           (if (and (null props-diff) (null children-diff))
               (progn
                 (incf (diff-stats-nodes-unchanged *diff-stats*))
                 nil)
               (progn
                 (incf (diff-stats-nodes-updated *diff-stats*))
                 (append props-diff children-diff))))
         
         ;; Different component types - replace
         (progn
           (incf (diff-stats-nodes-updated *diff-stats*))
           (list (make-diff-node :replace path old-tree new-tree)))))
    
    ;; Fallback for any other case
    (t
     (if (equal old-tree new-tree)
         (progn
           (incf (diff-stats-nodes-unchanged *diff-stats*))
           nil)
         (progn
           (incf (diff-stats-nodes-updated *diff-stats*))
           (list (make-diff-node :replace path old-tree new-tree)))))))

;; Diff children by index
(defun diff-children-indexed (old-children new-children base-path)
  "Compare children arrays by index"
  (let ((max-len (max (length old-children) (length new-children)))
        (changes nil))
    (dotimes (i max-len)
      (let ((old-child (when (< i (length old-children))
                         (nth i old-children)))
            (new-child (when (< i (length new-children))
                         (nth i new-children)))
            (child-path (append base-path (list i))))
        (setf changes (append changes (diff-trees old-child new-child child-path)))))
    changes))

;; Diff children using keys
(defun diff-children-keyed (old-children new-children base-path)
  "Compare children arrays using keys"
  (when (or (null old-children) (null new-children))
    (return-from diff-children-keyed 
      (diff-children-indexed old-children new-children base-path)))
  
  ;; Build maps of key -> node and key -> index
  (let ((old-keys (make-hash-table :test #'equal))
        (new-keys (make-hash-table :test #'equal))
        (old-indices (make-hash-table :test #'equal))
        (new-indices (make-hash-table :test #'equal))
        (changes nil))
    
    ;; Map old children
    (loop for child in old-children
          for i from 0
          for key = (component-key child)
          do (progn
               (setf (gethash key old-keys) child)
               (setf (gethash key old-indices) i)))
    
    ;; Map new children
    (loop for child in new-children
          for i from 0
          for key = (component-key child)
          do (progn
               (setf (gethash key new-keys) child)
               (setf (gethash key new-indices) i)))
    
    ;; Find moved, added, and updated nodes
    (loop for child in new-children
          for new-idx from 0
          for key = (component-key child)
          do (let ((old-idx (gethash key old-indices))
                   (old-node (gethash key old-keys))
                   (child-path (append base-path (list new-idx))))
               (cond
                 ;; Node moved
                 ((and old-idx 
                       (diff-options-track-moves *diff-options*)
                       (/= old-idx new-idx))
                  (incf (diff-stats-nodes-moved *diff-stats*))
                  (push (make-diff-node :move 
                                       child-path
                                       (cons old-idx new-idx)
                                       child)
                        changes)
                  (setf changes (append changes 
                                        (diff-trees old-node child child-path))))
                 
                 ;; Node exists in both trees
                 (old-node
                  (setf changes (append changes 
                                        (diff-trees old-node child child-path))))
                 
                 ;; Node added
                 (t
                  (incf (diff-stats-nodes-added *diff-stats*))
                  (push (make-diff-node :add child-path nil child)
                        changes)))))
    
    ;; Find removed nodes
    (loop for child in old-children
          for old-idx from 0
          for key = (component-key child)
          when (not (gethash key new-keys))
          do (let ((child-path (append base-path (list old-idx))))
               (incf (diff-stats-nodes-removed *diff-stats*))
               (push (make-diff-node :remove child-path child nil)
                     changes)))
    
    (nreverse changes)))

;; Apply a diff to a tree
(defun apply-diff (tree diff)
  "Apply a diff to a tree"
  (let ((result (copy-tree tree)))  ; Work with a copy
    (dolist (change diff)
      (let ((path (diff-node-path change))
            (type (diff-node-type change)))
        (case type
          (:add (apply-add result path (diff-node-new-value change)))
          (:remove (apply-remove result path))
          (:replace (apply-replace result path (diff-node-new-value change)))
          (:prop-change (apply-prop-change result path (diff-node-new-value change)))
          (:move (apply-move result path (diff-node-old-value change) 
                            (diff-node-new-value change))))))
    result))

;; Apply operations to tree
(defun apply-add (tree path value)
  "Add a node at path"
  (let ((parent (get-node-at-path tree (butlast path)))
        (index (car (last path))))
    (when parent
      (if (listp index)
          ;; Add to props
          (setf (getf parent (car index)) value)
          ;; Add to children array
          (let ((children (getf parent :children)))
            (setf (getf parent :children)
                  (if (>= index (length children))
                      (append children (list value))
                      (let ((new-children nil))
                        (dotimes (i (1+ (length children)))
                          (cond
                            ((< i index) (push (nth i children) new-children))
                            ((= i index) (push value new-children))
                            (t (push (nth (1- i) children) new-children))))
                        (nreverse new-children)))))))))

(defun apply-remove (tree path)
  "Remove a node at path"
  (let ((parent (get-node-at-path tree (butlast path)))
        (index (car (last path))))
    (when parent
      (if (listp index)
          ;; Remove from props
          (remf (getf parent (car index)) (cadr index))
          ;; Remove from children array
          (let ((children (getf parent :children)))
            (setf (getf parent :children)
                  (append (subseq children 0 index)
                          (subseq children (1+ index)))))))))

(defun apply-replace (tree path value)
  "Replace a node at path"
  (let ((parent (get-node-at-path tree (butlast path)))
        (index (car (last path))))
    (when parent
      (if (listp index)
          ;; Replace in props
          (setf (getf parent (car index)) value)
          ;; Replace in children array
          (setf (nth index (getf parent :children)) value)))))

(defun apply-prop-change (tree path value)
  "Change a prop at path"
  (let* ((node-path (butlast path 2))
         (node (get-node-at-path tree node-path))
         (prop-key (car (last path))))
    (when node
      (setf (getf (getf node :props) prop-key) value))))

(defun apply-move (tree path old-index new-index)
  "Move a node from old-index to new-index"
  (let ((parent (get-node-at-path tree (butlast path))))
    (when parent
      (let* ((children (getf parent :children))
             (node (nth old-index children))
             ;; Remove from old position
             (temp-children (append (subseq children 0 old-index)
                                    (subseq children (1+ old-index)))))
        ;; Insert at new position
        (setf (getf parent :children)
              (append (subseq temp-children 0 new-index)
                      (list node)
                      (subseq temp-children new-index)))))))

;; Helper to get a node at a path
(defun get-node-at-path (tree path)
  "Get the node at the specified path"
  (if (null path)
      tree
      (let ((head (car path))
            (rest (cdr path)))
        (cond
          ((null tree) nil)
          ((eq head :props) (get-node-at-path (getf tree :props) rest))
          ((eq head :children) (get-node-at-path (getf tree :children) rest))
          ((integerp head) (get-node-at-path (nth head (if (listp tree) tree nil)) rest))
          ((listp head) (get-node-at-path (getf tree (car head)) rest))
          (t nil)))))

;; Create a patch
(defun create-patch (old-tree new-tree)
  "Create a patch between old-tree and new-tree"
  (diff-trees old-tree new-tree))

;; Optimize diff settings
(defun optimize-diff-settings (tree-size complexity)
  "Automatically configure optimal diff settings based on tree size and complexity"
  (let ((options (make-diff-options)))
    ;; Adjust settings based on tree size
    (when (> tree-size 1000)
      (setf (diff-options-batch-updates options) t)
      (when (> tree-size 5000)
        (setf (diff-options-use-heuristics options) t)))
    
    ;; Adjust settings based on complexity
    (case complexity
      (:low 
       (setf (diff-options-skip-unchanged options) t)
       (setf (diff-options-track-moves options) nil))
      (:medium
       (setf (diff-options-skip-unchanged options) t))
      (:high
       (setf (diff-options-use-heuristics options) t)
       (setf (diff-options-key-based-diff options) t)))
    
    options))

;; Show diff stats
(defun show-diff-stats (&optional (stats *diff-stats*))
  "Display statistics about the last diff operation"
  (format t "~&Diff Statistics:~%")
  (format t "  Nodes compared:  ~8d~%" (diff-stats-nodes-compared stats))
  (format t "  Nodes unchanged: ~8d (~3d%)~%" 
          (diff-stats-nodes-unchanged stats)
          (if (> (diff-stats-nodes-compared stats) 0)
              (round (* 100 (/ (diff-stats-nodes-unchanged stats)
                               (diff-stats-nodes-compared stats))))
              0))
  (format t "  Nodes added:     ~8d~%" (diff-stats-nodes-added stats))
  (format t "  Nodes removed:   ~8d~%" (diff-stats-nodes-removed stats))
  (format t "  Nodes updated:   ~8d~%" (diff-stats-nodes-updated stats))
  (format t "  Nodes moved:     ~8d~%" (diff-stats-nodes-moved stats))
  (format t "  Props changed:   ~8d~%" (diff-stats-props-changed stats))
  stats)

;; Example usage:
#|
(let ((old-tree '(:type :div :props (:class "container") 
                  :children ((:type :button :props (:label "OK") :children nil)
                             (:type :span :props (:text "Hello") :children nil))))
      (new-tree '(:type :div :props (:class "container") 
                  :children ((:type :span :props (:text "Hello") :children nil)
                             (:type :button :props (:label "Cancel") :children nil)))))
  
  (with-diff-options (:track-moves t)
    (let ((diff (diff-trees old-tree new-tree)))
      (show-diff-stats)
      (format t "~%Diff: ~a~%" diff)
      (let ((result (apply-diff old-tree diff)))
        (format t "~%Result equals new-tree: ~a~%" (equal result new-tree))))))
|#
