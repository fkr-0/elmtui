;;;===============================================================
;;; File: src/view/styled.lisp
;;; UI Node Style Integration with elmtui.style-lib
;;;===============================================================
(uiop:define-package :elmtui.view.styled
  (:use :cl)
  (:import-from :log4cl #:log-debug)
  (:import-from :elmtui.view.core
   :ui-node :make-ui-node :copy-ui-node
                :ui-node-type :ui-node-props :ui-node-children :node-type)
  (:export #:ui-node-type #:node-type) ; Export these generics
  ;; Import relevant symbols from elmtui.style-lib API and implementation details
  ;; Assuming elmtui.style-lib.api exports these based on the provided files
  (:import-from :elmtui.style-lib.api
                #:stylable #:stylable-id #:classes #:parents-of #:styles #:dirty #:dirty-p

                #:style-set #:stylesheet-name) ; Removed query-stylesheet, copy-set. Added stylesheet-name
  ;; Import default style set, value-of, and copy-set from style-set package
  (:import-from :elmtui.style-lib.style-set #:*default-style-set* #:value-of #:copy-set #:set-style
                #:style-list) ; Added copy-set
  ;; Import query-stylesheet from sheet package
  (:import-from :elmtui.style-lib.sheet #:query-stylesheet)
  (:export
   :styled-ui-node
   :make-styled-node       ; Constructor
   :copy-styled-node       ; Copier
   :apply-stylesheet-to-tree ; Main styling function
   :style-value             ; Helper to get computed style value
   :styles
   :mark-tree-dirty-for-styling ; New function to mark tree as dirty
   :with-attributes))       ; Renamed from with-styles
(in-package :elmtui.view.styled)
;; (defmethod as-plist ((node styled-ui-node))
;;   "Convert a styled-ui-node to a property list, including style information."
;;   (let ((props (ui-node-props node)))
;;     (append
;;      (list :type (ui-node-type node)
;;            :id (stylable-id node)
;;            :classes (classes node)
;;            :parents (parents-of node)
;;            :styles (styles node)
;;            :dirty (dirty-p node))
;;      props)))

;;;-----------------------------------------------------------------------------
;;; Styled UI Node Class
;;;-----------------------------------------------------------------------------

(defclass styled-ui-node (ui-node stylable)
  ;; No extra slots needed if elmtui.style-lib:stylable provides id, classes, parents, styles, dirty
  ()
  (:documentation
   "A UI node that can be styled via elmtui.style-lib.
    - Inherits node structure from ui-node.
    - Adds styling capabilities from elmtui.style-lib:stylable.
    - Assumes elmtui.style-lib:stylable provides slots/accessors for:
      id, classes, parents, styles, dirty."))

;; Methods implementing the stylable interface for styled-ui-node
(defmethod stylable-id ((node styled-ui-node))
  "Returns the :id from the node's props, synchronizing with the 'sid slot."
  ;; Check if the 'sid slot (from stylable) is bound and has a value.
  ;; The actual slot name is 'sid' in the elmtui.style-lib.api package.
  (let ((slot-id-value (when (slot-boundp node 'elmtui.style-lib.api::sid)
                         (slot-value node 'elmtui.style-lib.api::sid))))
    (if slot-id-value
        ;; If slot has a value, ensure props :id matches and return it.
        (progn
          (unless (equal (getf (ui-node-props node) :id) slot-id-value)
            (setf (getf (ui-node-props node) :id) slot-id-value))
          slot-id-value)
        ;; If slot is not bound or nil, try to initialize it from props :id.
        (let ((props-id (getf (ui-node-props node) :id)))
          (when props-id
            (setf (slot-value node 'elmtui.style-lib.api::sid) props-id))
          props-id))))

(defmethod classes ((node styled-ui-node))
  "Returns the :classes from the node's props, ensuring it's a list or nil."
  (let ((cls (getf (ui-node-props node) :classes)))
    (cond ((null cls) nil)
          ((listp cls) cls)
          (t (list cls))))) ; Wrap single class in a list

;; parents-of is assumed to be an accessor provided by elmtui.style-lib:stylable.
;; It will be set during the apply-stylesheet-to-tree traversal via :parents initarg.

;; styles is assumed to be an accessor provided by elmtui.style-lib:stylable.
;; It will be set by query-stylesheet.

;; dirty/dirty-p are assumed to be accessor/method provided by elmtui.style-lib:stylable.



;;;-----------------------------------------------------------------------------
;;; Node Creation / Copying
;;;-----------------------------------------------------------------------------

(defun make-styled-node (&key type props children (parent nil))
  "Create a new styled UI node.
   Props should include :id and :classes for styling selectors.
   PARENT is the direct parent styled-ui-node (used for :parents initarg)."
  (log:debug "STYLED: make-styled-node - Type: ~S, Props: ~S, Children count: ~A, Parent provided: ~S"
             type props (length children) (if parent t nil))
  (let* ((provided-id (getf props :id))
         (final-id (or provided-id (gensym "NODE-"))) ; Use provided ID if it exists
         (classes (getf props :classes))
         ;; Create effective-props, ensuring :id is final-id and removing any other :id from original props
         (props-without-original-id (loop for (key val) on (copy-list props) by #'cddr
                                          unless (eq key :id)
                                            collect key and collect val))
         (effective-props (list* :id final-id props-without-original-id))
         (node (make-instance 'styled-ui-node
                              :id final-id ; Use the final, correct ID
                              :classes (cond ((null classes) nil)
                                             ((listp classes) classes)
                                             (t (list classes)))
                              :parents (when parent (list parent)))))
    ;; Set basic ui-node slots
    (setf (ui-node-type node) type)
    (setf (ui-node-props node) effective-props)
    (setf (ui-node-children node) children)
    ;; Initialize styles slot, applying explicit props over defaults
    (let ((initial-styles (copy-set *default-style-set*)))
      (unless (typep initial-styles 'style-set)
        (log:error "STYLED: make-styled-node - initial-styles is NOT a style-set! Value: ~S. *default-style-set* is: ~S"
                   initial-styles *default-style-set*))
      ;; Apply explicit layout props from the node's props as base styles.
      (let ((prop-width (getf effective-props :width))
            (prop-height (getf effective-props :height))
            (prop-display (getf effective-props :display))
            (prop-flex-dir (getf effective-props :flex-direction)))
        (when prop-width (set-style initial-styles :width prop-width))
        (when prop-height (set-style initial-styles :height prop-height))
        (when prop-display (set-style initial-styles :display prop-display))
        (when prop-flex-dir (set-style initial-styles :flex-direction prop-flex-dir)))
      (setf (styles node) initial-styles))
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
  (log:debug "STYLED: apply-stylesheet-to-tree for styled-ui-node - Type: ~S, ID: ~S, Stylesheet: ~A"
             (ui-node-type node) (stylable-id node) (if stylesheet (stylesheet-name stylesheet) "NIL_STYLESHEET"))
  ;; Create a copy, setting the correct parent link for this instance
  (let ((new-node (copy-styled-node node :parent parent)))
    ;; Recompute styles if dirty
    (when (dirty-p new-node)
      (log:debug "STYLED: Node ~S is dirty, recomputing styles." (stylable-id new-node))
      ;; Ensure the parents slot is correctly set before querying
      (setf (parents-of new-node) (when parent (list parent)))
      ;; Query the stylesheet
      (let ((computed-styles (query-stylesheet stylesheet new-node)))
        (unless (typep computed-styles 'style-set)
          (log:error "STYLED: apply-stylesheet-to-tree - query-stylesheet for node ~S (ID: ~S) returned non-style-set: ~S"
                     new-node (stylable-id new-node) computed-styles))
        ;; Enhanced Logging: Log node ID, (TODO: matching rules), and final computed style-set
        (log:debug "STYLED: Node ID: ~S, Stylesheet: ~A, Final Computed Style-Set: ~S"
                   (stylable-id new-node)
                   (if stylesheet (stylesheet-name stylesheet) "NIL_STYLESHEET")
                   computed-styles)
        (setf (styles new-node) computed-styles)
        (unless (typep (styles new-node) 'style-set)
          (log:error "STYLED: apply-stylesheet-to-tree - (styles new-node) for node ~S (ID: ~S) is NOT a style-set after assignment! Value: ~S"
                     new-node (stylable-id new-node) (styles new-node)))
        (setf (dirty new-node) nil))) ; Mark as clean after styling

    ;; Recursively apply to children, passing self (new-node) as parent
    (setf (ui-node-children new-node)
          (loop for child in (ui-node-children node) ; Iterate over children of the ORIGINAL node
                collect (apply-stylesheet-to-tree child stylesheet new-node)))

    new-node))

(defmethod apply-stylesheet-to-tree ((node ui-node) stylesheet &optional parent)
  "Handle plain ui-nodes by converting them first."
  (log:debug "STYLED: apply-stylesheet-to-tree for plain ui-node - Type: ~S, converting to styled." (ui-node-type node))
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
      (let ((node-styles (styles node)))
        (unless (typep node-styles 'style-set)
          (log:error "STYLED: style-value - (styles node) for node ~S (type ~S, id ~S) is NOT a style-set! Value: ~S"
                     node (ui-node-type node) (stylable-id node) node-styles))
        (value-of node-styles property default))
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
       ;; This assumes elmtui.style-lib.stylable uses these slot names directly
       (when (find :id attributes)
         (setf (slot-value ,styled-node-var 'elmtui.style-lib.api::sid) (getf (ui-node-props ,styled-node-var) :id)))
       (when (find :classes attributes)
         (setf (slot-value ,styled-node-var 'elmtui.style-lib.api::classes) (getf (ui-node-props ,styled-node-var) :classes)))
       ;; Mark dirty as attributes potentially affecting style selection changed
       (setf (dirty ,styled-node-var) t)
       ,styled-node-var)))

(defun mark-tree-dirty-for-styling (styled-node)
  "Recursively marks STYLED-NODE and all its styled-ui-node children as dirty for styling."
  (when (typep styled-node 'styled-ui-node)
    (setf (dirty styled-node) t)
    (dolist (child (ui-node-children styled-node))
      (mark-tree-dirty-for-styling child))))
