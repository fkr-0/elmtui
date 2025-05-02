;;;===============================================================
;;; File: src/view/styled.lisp
;;; UI Node Style Integration with cl-styles
;;;===============================================================
(uiop:define-package :elmtui.view.styled
  (:use :cl)
  (:import-from :elmtui.view.core
                :ui-node :make-ui-node :copy-ui-node
                :ui-node-type :ui-node-props :ui-node-children)
  ;; Import relevant symbols from cl-styles API and implementation details
  ;; Assuming cl-styles.api exports these based on the provided files
  (:import-from :cl-styles.api
                :stylable :stylable-id :classes :parents-of :styles :dirty :dirty-p
                :style-set :query-stylesheet :value-of :copy-set)
  ;; Import default style set if needed (adjust package if necessary)
  (:import-from :cl-styles.style-set #:*default-style-set*)
  (:export
   :styled-ui-node
   :make-styled-node       ; Constructor
   :copy-styled-node       ; Copier
   :apply-stylesheet-to-tree ; Main styling function
   :style-value             ; Helper to get computed style value
   :with-attributes))       ; Renamed from with-styles
(in-package :elmtui.view.styled)

;;;-----------------------------------------------------------------------------
;;; Styled UI Node Class
;;;-----------------------------------------------------------------------------

(defclass styled-ui-node (ui-node stylable)
  ;; No extra slots needed if cl-styles:stylable provides id, classes, parents, styles, dirty
  ()
  (:documentation
   "A UI node that can be styled via cl-styles.
    - Inherits node structure from ui-node.
    - Adds styling capabilities from cl-styles:stylable.
    - Assumes cl-styles:stylable provides slots/accessors for:
      id, classes, parents, styles, dirty."))

;; Methods implementing the stylable interface for styled-ui-node
(defmethod stylable-id ((node styled-ui-node))
  "Returns the :id from the node's props."
  (getf (ui-node-props node) :id))

(defmethod classes ((node styled-ui-node))
  "Returns the :classes from the node's props, ensuring it's a list or nil."
  (let ((cls (getf (ui-node-props node) :classes)))
    (cond ((null cls) nil)
          ((listp cls) cls)
          (t (list cls))))) ; Wrap single class in a list

;; parents-of is assumed to be an accessor provided by cl-styles:stylable.
;; It will be set during the apply-stylesheet-to-tree traversal via :parents initarg.

;; styles is assumed to be an accessor provided by cl-styles:stylable.
;; It will be set by query-stylesheet.

;; dirty/dirty-p are assumed to be accessor/method provided by cl-styles:stylable.

;;;-----------------------------------------------------------------------------
;;; Node Creation / Copying
;;;-----------------------------------------------------------------------------

(defun make-styled-node (&key type props children (parent nil))
  "Create a new styled UI node.
   Props should include :id and :classes for styling selectors.
   PARENT is the direct parent styled-ui-node (used for :parents initarg)."
  (let* ((id (or (getf props :id) (gensym "NODE-"))) ; Ensure ID for stylability
         (classes (getf props :classes))
         ;; Ensure props has the potentially generated ID
         (effective-props (list* :id id (copy-list props)))
         (node (make-instance 'styled-ui-node
                              ;; Initargs for stylable superclass (assuming standard names)
                              :id id
                              :classes (cond ((null classes) nil)
                                             ((listp classes) classes)
                                             (t (list classes)))
                              ;; Pass parent list for cl-styles:stylable init
                              ;; This assumes cl-styles uses the :parents initarg
                              ;; and handles building the full ancestor list if needed,
                              ;; or that selectors only need the direct parent.
                              :parents (when parent (list parent))
                              )))
    ;; Set basic ui-node slots
    (setf (ui-node-type node) type)
    (setf (ui-node-props node) effective-props)
    (setf (ui-node-children node) children)
    ;; Initialize styles slot (assuming stylable provides it)
    (setf (styles node) (copy-set *default-style-set*)) ; Start with defaults
    (setf (dirty node) t) ; Mark as dirty initially
    node))

(defun copy-styled-node (node &key type props children parent)
  "Create a copy of a styled node with optional overrides."
  (let ((new-node (make-styled-node
                   :type (or type (ui-node-type node))
                   :props (or props (copy-list (ui-node-props node)))
                   :children (or children (copy-list (ui-node-children node)))
                   ;; Use provided parent or copy from original
                   :parent (or parent (first (parents-of node))))))
    ;; Copy computed styles from the original node
    (setf (styles new-node) (copy-set (styles node)))
    ;; Mark the new node as dirty, as its context (parent/children) might change
    (setf (dirty new-node) t)
    new-node))

;;;-----------------------------------------------------------------------------
;;; Style Application
;;;-----------------------------------------------------------------------------

(defgeneric apply-stylesheet-to-tree (node stylesheet &optional parent)
  (:documentation
   "Apply styles from STYLESHEET to NODE and its children recursively.
    Returns a new tree of styled-ui-nodes with computed styles.
    PARENT argument is used internally to build the parent chain."))

(defmethod apply-stylesheet-to-tree ((node styled-ui-node) stylesheet &optional parent)
  "Apply styles to an already styled-ui-node tree."
  ;; Create a copy, setting the correct parent link for this instance
  (let ((new-node (copy-styled-node node :parent parent)))
    ;; Recompute styles if dirty
    (when (dirty-p new-node)
      ;; Ensure the parents slot is correctly set before querying
      ;; (This might be redundant if copy-styled-node handles it via :parents initarg)
      (setf (parents-of new-node) (when parent (list parent)))
      ;; Query the stylesheet
      (setf (styles new-node) (query-stylesheet stylesheet new-node))
      (setf (dirty new-node) nil)) ; Mark as clean after styling

    ;; Recursively apply to children, passing self (new-node) as parent
    (setf (ui-node-children new-node)
          (loop for child in (ui-node-children new-node) ; Iterate over children of the *new* node copy
                collect (apply-stylesheet-to-tree child stylesheet new-node)))

    new-node))

(defmethod apply-stylesheet-to-tree ((node ui-node) stylesheet &optional parent)
  "Handle plain ui-nodes by converting them first."
  ;; Convert to styled-node, setting the parent link
  (let ((styled-node (make-styled-node
                      :type (ui-node-type node)
                      :props (ui-node-props node)
                      :children (ui-node-children node) ; Children will be processed recursively
                      :parent parent)))
    ;; Now apply styles to the newly created styled-node and its children
    ;; The recursive call inside will handle the children conversion/styling
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
   Returns DEFAULT if NODE is not a styled-ui-node or property not found."
  (if (typep node 'styled-ui-node)
      (value-of (styles node) property default)
      default))

;;;-----------------------------------------------------------------------------
;;; Attribute Macro (Renamed from with-styles)
;;;-----------------------------------------------------------------------------

(defmacro with-attributes ((&rest attributes) node)
  "Add/override attributes (like :id, :classes) in NODE's props plist.
   Ensures the node is a styled-ui-node.
   NOTE: This modifies props *before* styling. Primarily useful for setting
   attributes used by stylesheet selectors (:id, :classes).
   Avoid using for direct styling properties (e.g., :color, :width)."
  (let ((node-var (gensym "NODE"))
        (props-var (gensym "PROPS"))
        (styled-node-var (gensym "STYLED-NODE")))
    `(let* ((,node-var ,node)
            (,props-var (ui-node-props ,node-var))
            ;; Ensure node is styled, converting if necessary
            (,styled-node-var
             (if (typep ,node-var 'styled-ui-node)
                 ,node-var
                 (make-styled-node
                  :type (ui-node-type ,node-var)
                  :props ,props-var
                  :children (ui-node-children ,node-var)
                  ;; Parent link might be lost here if converted, styling needs re-run
                  ))))
       ;; Prepend new attributes (overriding existing ones in the props list)
       (setf (ui-node-props ,styled-node-var)
             (list* ,@(loop for (key value) on attributes by #'cddr
                            collect key
                            collect value)
                    ,props-var))
       ;; Update stylable info directly if :id or :classes changed
       ;; This assumes cl-styles.stylable uses these slot names directly
       (when (find :id attributes)
         (setf (slot-value ,styled-node-var 'cl-styles.api::id) (getf (ui-node-props ,styled-node-var) :id)))
       (when (find :classes attributes)
         (setf (slot-value ,styled-node-var 'cl-styles.api::classes) (getf (ui-node-props ,styled-node-var) :classes)))
       ;; Mark dirty as attributes potentially affecting style selection changed
       (setf (dirty ,styled-node-var) t)
       ,styled-node-var)))
