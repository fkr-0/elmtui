;;;===============================================================
;;; File: src/view/styled.lisp
;;; UI Node Style Integration with elmtui.style-lib
;;;===============================================================
(uiop:define-package :elmtui.view.styled
  (:use :cl)
  (:import-from :log4cl #:log-debug #:log-warn) ; Added log-warn
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

(defclass styled-ui-node (ui-node stylable)
  ;; stylable mixin provides: sid, classes, parents-of, styles, dirty
  ()
  (:documentation
   "A UI node that can be styled via elmtui.style-lib.
    It inherits from ui-node for basic structure and stylable for style-related slots and behavior."))

;; Methods implementing the stylable interface for styled-ui-node
;; These typically rely on slot-accessors provided by the 'stylable' class
;; If 'stylable' defines accessors like (stylable-id (node stylable)), etc.,
;; then explicit method definitions here might only be needed for customization.

(defmethod stylable-id ((node styled-ui-node))
  "Returns the ID of the styled node. Relies on the 'sid' slot from 'stylable'."
  (if (slot-boundp node 'elmtui.style-lib.api::sid)
      (slot-value node 'elmtui.style-lib.api::sid)
      (progn
        (log-warn "STYLED: styled-ui-node accessed for ID, but 'sid' slot unbound. Props: ~S" (ui-node-props node))
        nil))) ; Or fallback to (getf (ui-node-props node) :id) if that's desired policy

(defmethod classes ((node styled-ui-node))
  "Returns the classes of the styled node. Relies on the 'classes' slot from 'stylable'."
  (if (slot-boundp node 'elmtui.style-lib.api::classes)
      (slot-value node 'elmtui.style-lib.api::classes)
      (progn
        (log-warn "STYLED: styled-ui-node accessed for classes, but 'classes' slot unbound. Props: ~S" (ui-node-props node))
        nil)))

;; parents-of, styles, dirty/dirty-p are assumed to be accessors provided by elmtui.style-lib:stylable.

;;;-----------------------------------------------------------------------------
;;; Node Creation / Copying
;;;-----------------------------------------------------------------------------

(defun make-styled-node (&key type props children (parent nil))
  "Create a new styled UI node.
   Props should include :id and :classes for styling selectors.
   PARENT is the direct parent styled-ui-node (used for :parents initarg of stylable)."
  (log:debug "STYLED: make-styled-node - Type: ~S, Props: ~S, Children count: ~A, Parent provided: ~S"
             type props (length children) (if parent t nil))
  (let* ((provided-id (getf props :id))
         (final-id (or provided-id (gensym "NODE-")))
         (classes-prop (getf props :classes))
         (processed-classes (cond ((null classes-prop) nil)
                                  ((listp classes-prop) classes-prop)
                                  ((keywordp classes-prop) (list classes-prop))
                                  ((stringp classes-prop) (list (intern (string-upcase classes-prop) :keyword)))
                                  (t (log-warn "STYLED: Invalid :classes ~S in props for node ID ~S. Ignored." classes-prop final-id)
                                     nil)))
         ;; Props for the base ui-node part, ensure :id is the final-id
         (effective-props (let ((p (copy-list props))) (setf (getf p :id) final-id) p))
         (node (make-instance 'styled-ui-node
                              ;; Initargs for stylable mixin
                              :sid final-id
                              :classes processed-classes
                              :parents (when parent (list parent))
                              ;; :styles will be initialized below
                              :dirty t)))
    ;; Set basic ui-node slots
    (setf (ui-node-type node) type)
    (setf (ui-node-props node) effective-props)
    (setf (ui-node-children node) children)

    ;; Initialize styles slot: defaults + inline styles from :style prop
    (let ((initial-styles (copy-set *default-style-set*)))
      (let ((inline-style-data (getf props :style)))
        (when (and inline-style-data (listp inline-style-data))
          (loop for (key val) on inline-style-data by #'cddr
                do (set-style initial-styles key val))))
      (setf (styles node) initial-styles))
    node))

(defun copy-styled-node (node &key type props children parent)
  "Create a copy of a styled node with optional overrides.
   The 'styles' slot will be initialized by make-styled-node (defaults + inline from new props)
   and then populated by query-stylesheet in apply-stylesheet-to-tree.
   Children from the original node are taken as a list to be processed by the caller."
  (log:debug "STYLED: copy-styled-node - Original ID: ~S, New Parent: ~S"
             (stylable-id node) (if parent (stylable-id parent) "NIL"))
  (make-styled-node
   :type (or type (ui-node-type node))
   :props (or props (copy-list (ui-node-props node)))
   ;; Children are taken from the original node's children list.
   ;; apply-stylesheet-to-tree will iterate over these and process them.
   :children (or children (ui-node-children node))
   :parent parent))

;;;-----------------------------------------------------------------------------
;;; Style Application
;;;-----------------------------------------------------------------------------

(defgeneric apply-stylesheet-to-tree (node stylesheet &optional parent)
  (:documentation
   "Recursively applies styles from STYLESHEET to NODE and its descendants.
    Returns a NEW tree of styled-ui-nodes with styles computed.
    PARENT is the already processed parent for the current NODE."))

(defmethod apply-stylesheet-to-tree ((node styled-ui-node) stylesheet &optional parent)
  "Apply styles to an already styled-ui-node tree. Returns a new styled node."
  (log:debug "STYLED: apply-stylesheet-to-tree for styled-ui-node - ID: ~S, Type: ~S, Stylesheet: ~A, Parent ID: ~S"
             (stylable-id node) (ui-node-type node)
             (if stylesheet (stylesheet-name stylesheet) "NIL_STYLESHEET")
             (if parent (stylable-id parent) "NIL_PARENT"))

  ;; 1. Create a new node instance, copying from the original.
  ;;    'copy-styled-node' (via 'make-styled-node') sets its parent link and
  ;;    initializes its 'styles' slot (defaults + inline styles from its own props).
  (let ((new-node (copy-styled-node node :parent parent)))

    ;; 2. Apply the stylesheet.
    ;;    'query-stylesheet' uses (styles new-node) as its base, applies rules from
    ;;    'stylesheet', and handles inheritance using 'new-node's parent context.
    ;;    It returns a new style-set which becomes the computed styles for 'new-node'.
    (setf (styles new-node) (query-stylesheet stylesheet new-node))
    (log:debug "STYLED: Styles computed for ID ~S: ~S" (stylable-id new-node) (styles new-node))

    ;; 3. Mark the new-node as no longer dirty (styles are now current).
    (setf (dirty new-node) nil)

    ;; 4. Recursively process children from the original node's children list.
    ;;    Each child will be processed, and 'new-node' (the current styled node)
    ;;    will be passed as its parent.
    (setf (ui-node-children new-node)
          (loop for child in (ui-node-children node) ; Iterate original children
                collect (apply-stylesheet-to-tree child stylesheet new-node)))
    new-node))

(defmethod apply-stylesheet-to-tree ((node ui-node) stylesheet &optional parent)
  "Handle plain ui-nodes by converting them first, then applying styles. Returns a new styled node."
  (log:debug "STYLED: apply-stylesheet-to-tree for plain ui-node - Type: ~S. Converting to styled-ui-node. Parent ID: ~S"
             (ui-node-type node) (if parent (stylable-id parent) "NIL_PARENT"))

  ;; 1. Convert the plain ui-node to a styled-ui-node.
  ;;    'make-styled-node' sets its parent, initializes ID, classes from props,
  ;;    and sets initial styles (defaults + inline styles from props).
  ;;    Children are taken from the original plain node.
  (let ((styled-node (make-styled-node
                      :type (ui-node-type node)
                      :props (ui-node-props node)
                      :children (ui-node-children node)
                      :parent parent)))

    ;; 2. Now, call apply-stylesheet-to-tree on this new styled-node.
    ;;    This will dispatch to the method for styled-ui-node, which will
    ;;    apply the stylesheet and recursively process its children.
    ;;    The 'parent' argument remains the same for this call, as 'styled-node'
    ;;    is the current node being processed relative to that parent.
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
   Returns DEFAULT if NODE is not a styled-ui-node, not styled, or property not found."
  (if (and (typep node 'styled-ui-node) (slot-boundp node 'elmtui.style-lib.api::styles) (styles node))
      (value-of (styles node) property default)
      default))

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
