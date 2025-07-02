;;;===============================================================
;;; File: src/view/styled.lisp
;;; UI Node Style Integration with elmtui.style-lib
;;;===============================================================
(uiop:define-package :elmtui.view.styled
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-warn) ; Added log-warn
  (:import-from :elmtui.view.api :styled-ui-node :styled-ui-node-style-map)
  (:import-from :elmtui.view.core
   :ui-node :make-ui-node :copy-ui-node
                :ui-node-type :ui-node-props :ui-node-children :node-type)
  ;; Import relevant symbols from elmtui.style-lib API and implementation details
  (:import-from :elmtui.style-lib.api
                #:stylable #:stylable-id #:classes #:parents-of #:styles #:dirty #:dirty-p
                #:make-style-set ; Ensure make-style-set is available

                #:stylesheet-rules ; For checking if stylesheet is empty, if needed
                #:style-set #:stylesheet-name)
  ;; Import default style set, value-of, and copy-set from style-set package
  (:import-from :elmtui.style-lib.style-set #:*default-style-set* #:value-of #:copy-set #:set-style
                #:merge-sets!) ; Added merge-sets! for inline styles
  ;; Import query-stylesheet from sheet package
  (:import-from :elmtui.style-lib.sheet #:query-stylesheet)
  (:export
   #:ui-node-children
   #:ui-node-props
   #:styled-ui-node
   :make-styled-node       ; Constructor
   :copy-styled-node       ; Copier
   :apply-stylesheet-to-tree ; Main styling function
   :style-value             ; Helper to get computed style value
   :styles                  ; Re-export from style-lib.api
   :mark-tree-dirty-for-styling
   :with-attributes))
(in-package :elmtui.view.styled)

;;;-----------------------------------------------------------------------------
;;; Styled UI Node Class
;;;-----------------------------------------------------------------------------

(defmethod stylable-id ((node styled-ui-node))
  "Returns the ID of the styled node from its props."
  (getf (ui-node-props node) :id))

(defmethod classes ((node styled-ui-node))
  "Returns the classes of the styled node from its props."
  (let ((classes-prop (getf (ui-node-props node) :classes)))
    (cond ((null classes-prop) nil)
          ((listp classes-prop) classes-prop)
          ((keywordp classes-prop) (list classes-prop))
          ((stringp classes-prop) (list (intern (string-upcase classes-prop) :keyword)))
          (t (log-warn "STYLED: Invalid :classes ~S in props for node ID ~S. Ignored." 
                       classes-prop (getf (ui-node-props node) :id))
             nil))))

;; parents-of, styles, dirty/dirty-p would be handled by stylesheet system if needed

;;;-----------------------------------------------------------------------------
;;; Node Creation / Copying
;;;-----------------------------------------------------------------------------

(defun make-styled-node (&key type props children (parent nil))
  "Create a new styled UI node.
   Props should include :id and :classes for styling selectors.
   PARENT is the direct parent styled-ui-node (used for :parents initarg of stylable)."
  (log-debug "STYLED: make-styled-node - Type: ~S, Props: ~S, Children count: ~A, Parent provided: ~S"
             type props (length children) (if parent t nil))
  (let* ((provided-id (getf props :id))
         (final-id (or provided-id (gensym "NODE-")))
         ;; Props for the base ui-node part, ensure :id is the final-id
         (effective-props (let ((p (copy-list props))) (setf (getf p :id) final-id) p))
         (node (make-instance 'styled-ui-node
                              ;; Only use the initargs that styled-ui-node actually accepts
                              :style-map nil))) ; Initialize with empty style-map for now
    (log:debug "STYLED: make-styled-node - Created node with ID: ~S, Type: ~S, Effective Props: ~S"
               final-id type effective-props)
    ;; Set basic ui-node slots
    (setf (ui-node-type node) type)
    (setf (ui-node-props node) effective-props)
    (setf (ui-node-children node) children)

    ;; Initialize style-map: convert inline styles from :style prop to a plist
    (let ((inline-style-data (getf props :style)))
      (when (and inline-style-data (listp inline-style-data))
        (setf (styled-ui-node-style-map node) inline-style-data)))
    node))

(defun copy-styled-node (node &key type props children parent)
  "Create a copy of a styled node with optional overrides.
   The 'styles' slot will be initialized by make-styled-node (defaults + inline from new props)
   and then populated by query-stylesheet in apply-stylesheet-to-tree.
   Children from the original node are taken as a list to be processed by the caller."
  (log:debug "STYLED: copy-styled-node - Original ID: ~S, New Parent: ~S"
             (getf (ui-node-props node) :id) (if parent (getf (ui-node-props parent) :id) "NIL"))
  (make-styled-node
   :type (or type (ui-node-type node))
   :props (or props (copy-list (ui-node-props node)))
   ;; Children are taken from the original node's children list.
   ;; apply-stylesheet-to-tree will iterate over these and process them.

   :children (or children (ui-node-children node))
   :parent parent))
(defmethod ui-node-props ((node list))
  "Raises a backtracing error if ui-node-props is called on a raw DSL list/plist."
  (error "ui-node-props called on a list/plist: ~S~%Backtrace:~%~A"
         node
         (with-output-to-string (s)
           (let ((*print-length* 10) (*print-level* 4))
             (sb-debug:backtrace 10 s)))))
;;;-----------------------------------------------------------------------------
;;; Style Application
;;;-----------------------------------------------------------------------------

(defmethod stylable-id ((node list))
  "Fallback for stylable-id on raw DSL lists. Returns :id if present, else NIL."
  (getf node :id))

;; Improved: Always convert DSL list directly to styled-ui-node, not ui-node, for robust style handling
(defmethod apply-stylesheet-to-tree ((node list) stylesheet &optional parent)
  "Handle DSL property list trees by converting directly to a styled-ui-node, then applying styles. Correctly threads parent."
  (log:debug "STYLED: apply-stylesheet-to-tree for DSL list. Converting to styled-ui-node. Parent: ~S"
             (if parent (ignore-errors (stylable-id parent)) "NIL_PARENT"))
  (let* ((type (first node))
         (props (loop for (k v) on (rest node) by #'cddr
                      until (eq k :children)
                      append (list k v)))
         (children (getf (rest node) :children))
         (styled-children (mapcar (lambda (child)
                                    (apply-stylesheet-to-tree child stylesheet nil))
                                  children))
         (styled-node (make-styled-node :type type :props props :children styled-children :parent parent)))
    ;; Now, call apply-stylesheet-to-tree on this new styled-node to ensure full style application
    (apply-stylesheet-to-tree styled-node stylesheet parent)))
(defgeneric apply-stylesheet-to-tree (node stylesheet &optional parent)
  (:documentation
   "Recursively applies styles from STYLESHEET to NODE and its descendants.
    Returns a NEW tree of styled-ui-nodes with styles computed.
    PARENT is the already processed parent for the current NODE."))

(defmethod apply-stylesheet-to-tree ((node styled-ui-node) stylesheet &optional parent)
  "Apply styles to an already styled-ui-node tree. Returns a new styled node."
  (log:debug "STYLED: apply-stylesheet-to-tree for styled-ui-node - ID: ~S, Type: ~S, Stylesheet: ~A, Parent ID: ~S"
             (getf (ui-node-props node) :id) (ui-node-type node)
             (if stylesheet (stylesheet-name stylesheet) "NIL_STYLESHEET")
             (if parent (getf (ui-node-props parent) :id) "NIL_PARENT"))

  ;; 1. Create a new node instance, copying from the original.
  ;;    'copy-styled-node' (via 'make-styled-node') sets its parent link and
  ;;    initializes its 'style-map' slot with inline styles from its own props.
  (let ((new-node (copy-styled-node node :parent parent)))

    ;; 2. Apply the stylesheet.
    ;;    For now, we just keep the inline styles since the stylesheet system is simplified
    ;;    In the future, this would query the stylesheet and compute final styles
    (log:debug "STYLED: Style-map for ID ~S: ~S" (getf (ui-node-props new-node) :id) (styled-ui-node-style-map new-node))

    ;; 3. Recursively process children from the original node's children list.
    ;;    Each child will be processed, and 'new-node' (the current styled node)
    ;;    will be passed as its parent.
    (setf (ui-node-children new-node)
          (loop for child in (ui-node-children node) ; Iterate original children
                collect (apply-stylesheet-to-tree child stylesheet new-node)))
    new-node))

(defmethod apply-stylesheet-to-tree ((node ui-node) stylesheet &optional parent)
  "Handle plain ui-nodes by converting them first, then applying styles. Returns a new styled node.
   Ensures that all children are also styled-ui-nodes before proceeding."
  (log:debug "STYLED: apply-stylesheet-to-tree for plain ui-node - Type: ~S. Converting to styled-ui-node. Parent ID: ~S"
             (ui-node-type node) (if parent (ignore-errors (stylable-id parent)) "NIL_PARENT"))

  ;; Recursively style all children first, ensuring the entire tree is styled.
  (let* ((styled-children (mapcar (lambda (child)
                                    (if (typep child 'styled-ui-node)
                                        child
                                        (apply-stylesheet-to-tree child stylesheet nil)))
                                  (ui-node-children node)))
         (styled-node (make-styled-node
                       :type (ui-node-type node)
                       :props (ui-node-props node)
                       :children styled-children
                       :parent parent)))
    ;; Now, call apply-stylesheet-to-tree on this new styled-node.
    (apply-stylesheet-to-tree styled-node stylesheet parent)))

(defmethod apply-stylesheet-to-tree ((node null) stylesheet &optional parent)
  "Base case for recursion: nil node returns nil."
  (declare (ignore stylesheet parent))
  nil)

;;;-----------------------------------------------------------------------------
;;; Style Value Access Helper
;;;-----------------------------------------------------------------------------

(defun style-value (node property &optional default)
  "Get the computed style value of PROPERTY for NODE.
   Returns DEFAULT if NODE is not a styled-ui-node, not styled, or property not found.
   Looks up in style-map (computed/cascaded), then falls back to inline :style in props, then DEFAULT."
  (cond
    ((typep node 'styled-ui-node)
     (let* ((style-map (ignore-errors (styled-ui-node-style-map node)))
            (inline-style (getf (ui-node-props node) :style)))
       (cond
         ((and style-map (listp style-map) (getf style-map property))
          (getf style-map property))
         ((and inline-style (listp inline-style) (getf inline-style property))
          (getf inline-style property))
         (t default))))
    (t default)))

;;;-----------------------------------------------------------------------------
;;; Attribute Macro
;;;-----------------------------------------------------------------------------

(defmacro with-attributes ((&rest attributes) node-form)
  "Evaluates NODE-FORM, then modifies its props by setting ATTRIBUTES.
   Returns the modified node. ATTRIBUTES is a plist.
   Example: (with-attributes (:id \"my-id\" :classes '(:foo :bar)) (make-ui-node ...))"
  (let ((node-var (gensym "NODE"))
        (props-var (gensym "PROPS")))
    `(let* ((,node-var ,node-form)
            (,props-var (copy-list (ui-node-props ,node-var)))) ; Work on a copy
       (loop for (key val) on (list ,@attributes) by #'cddr
             do (setf (getf ,props-var key) val))
       (setf (ui-node-props ,node-var) ,props-var)
       ;; If it's a styled-ui-node, its stylable slots might need updating too
       ;; For :id and :classes, make-styled-node/copy-styled-node handle this from props.
       ;; If attributes are changed after creation, these might need explicit update
       ;; and styling marked as dirty.
       (when (typep ,node-var 'styled-ui-node)
         (let ((new-id (getf ,props-var :id))
               (new-classes (getf ,props-var :classes)))
           (when (and new-id (not (equal new-id (stylable-id ,node-var))))
             (setf (slot-value ,node-var 'elmtui.style-lib.api::sid) new-id)
             (setf (dirty ,node-var) t))
           (when (and new-classes (not (equal new-classes (classes ,node-var))))
             (setf (slot-value ,node-var 'elmtui.style-lib.api::classes)
                   (cond ((null new-classes) nil)
                         ((listp new-classes) new-classes)
                         ((keywordp new-classes) (list new-classes))
                         ((stringp new-classes) (list (intern (string-upcase new-classes) :keyword)))
                         (t (classes ,node-var)))) ; Revert to old if invalid
             (setf (dirty ,node-var) t))))
       ,node-var)))

;;;-----------------------------------------------------------------------------
;;; Mark Tree Dirty
;;;-----------------------------------------------------------------------------
(defun mark-tree-dirty-for-styling (styled-node)
  "Recursively marks STYLED-NODE and all its styled-ui-node children as dirty for styling."
  (when (typep styled-node 'styled-ui-node)
    (setf (dirty styled-node) t)
    (dolist (child (ui-node-children styled-node))
      (mark-tree-dirty-for-styling child))))
