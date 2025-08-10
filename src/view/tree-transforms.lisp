(uiop:define-package :elmtui.view.tree-transforms
  (:use :cl :alexandria :log4cl)
  ;; contracts & pipeline utilities (optional)
  (:import-from :elmtui.contracts #:define-stage #:pipeline-contract-violation)
  ;; (:import-from :example.component.protocol
  ;;               #:component-p #:component-view)
  (:import-from :elmtui.view.base-elements
                #:base-element #:base-element-p
                #:element-style #:element-children
                #:element-props #:element-size
                #:element-layout
                #:element-dirty-p
                #:compute-layout #:rect=
                #:element-changed-p)
  (:import-from :elmtui.view.layout.size-utils #:compute-size)

  (:import-from :elmtui.view.layout #:layout-node)
  (:import-from :elmtui.view.geo #:rectangle #:make-size #:make-pos #:make-rectangle #:x #:y #:w #:h)
  (:import-from :elmtui.view.base-elements
                #:base-element
                #:base-element-p
                #:element-id
                #:element-style
                #:element-children
                #:element-props
                #:element-size
                #:element-layout
                #:element-dirty-p
                #:element-changed-p
                #:padding-needed-p
                #:make-padding-wrapper
                ;; DSL bridge
                #:base-dsl-p
                #:dsl->objects
                #:rect=
                #:compute-layout)
  (:export #:process-tree #:resolve-components #:layout-tree-top-down))


(in-package :elmtui.view.tree-transforms)

;;; ──────────────────────────────────────────────────────────────────────────
;;; Generic traversal
;;; ──────────────────────────────────────────────────────────────────────────

(defun %copy-element-like (el &key (children :keep) (style :keep) (props :keep))
  "Shallow-copy EL, optionally replacing CHILDREN / STYLE / PROPS.
This preserves the element's slots; transient computed props (weak table)
are not copied (on purpose)."
  (let* ((class (class-of el))
         (new (make-instance class)))
    ;; copy all bound slots 1:1
    (dolist (slot (sb-mop:class-slots class))
      (let ((name (sb-mop:slot-definition-name slot)))
        (when (slot-boundp el name)
          (setf (slot-value new name) (slot-value el name)))))
    ;; overrides
    (when (not (eq children :keep))
      (setf (slot-value new 'element-children) children))
    (when (not (eq style :keep))
      (setf (element-style new) style))
    (when (not (eq props :keep))
      (setf (element-props new) props))
    new))

;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 1: DSL Resolution
;;; ──────────────────────────────────────────────────────────────────────────

(defun resolve-dsl (el)
  "Turn DSL-spec nodes into base-element instances."
  (cond
    ((base-element-p el) el)
    ((base-dsl-p el) (dsl->objects el))
    ((and (listp el) (every #'base-dsl-p el)) (mapcar #'dsl->objects el))
    (t el)))

;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 2: Style Expansion
;;; ──────────────────────────────────────────────────────────────────────────



;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 3: Semantic Injection
;;; ──────────────────────────────────────────────────────────────────────────

;; (defun semantic-injection (el)
;;   "Inject wrappers (e.g., padding) if required by style."
;;   (let ((kids (and (typep el 'base-element) (element-children el))))
;;     (if (and kids (padding-needed-p el))
;;         (%copy-element-like el :children (list (make-padding-wrapper el kids)))
;;         el)))

;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 4: Measure (bottom-up)
;;; ──────────────────────────────────────────────────────────────────────────

(defun measure-element (el)
  "Compute intrinsic border-box size. Parent is optional; compute-size
will infer a reasonable parent content size when missing."
  (let* ((measured (elmtui.view.layout.size-utils:compute-size el))
         (current (element-size el)))
    (if (equal current measured)
        el
        (progn (setf (element-size el) measured) el))))

;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 5a: Layout (bottom-up, parent-optional)
;;; ──────────────────────────────────────────────────────────────────────────

(defun layout-element (el)
  "Assign layout rects from parent constraints (inferred if absent).
Prefer the top-down variant (layout-tree-top-down) for full fidelity."
  (let* ((rect (compute-layout el))
         (curr (element-layout el)))
    (if (and curr (rect= curr rect))
        el
        (progn (setf (element-layout el) rect) el))))

;;; ──────────────────────────────────────────────────────────────────────────
;;; Pass 6: Dirty Flag
;;; ──────────────────────────────────────────────────────────────────────────

(defun mark-dirty-if-changed (el)
  "Mark element dirty if :size or :layout changed since last snapshot."
  (when (element-changed-p el)
    (setf (element-dirty-p el) t))
  el)


;; == exampleproject/src/view/tree-transforms.lisp ==
;; Tree transforms updated: *component expansion* is the source of structure.
;; ----------------------------------------------------------------------------


;; ── traversal helpers (unchanged idea) ──────────────────────────────────────
(defun %copy-el (el &key children style props)
  (let* ((class (class-of el))
         (new   (make-instance class)))
    (dolist (slot (sb-mop:class-slots class))
      (let ((name (sb-mop:slot-definition-name slot)))
        (when (slot-boundp el name)
          (setf (slot-value new name) (slot-value el name)))))
    (when children (setf (element-children new) children))
    (when style    (setf (element-style new) style))
    (when props    (setf (element-props new) props))
    new))

(defun transform-top-down (fn el &key ctx)
  (let* ((node (funcall fn el ctx))
         (kids (and (typep node 'base-element) (element-children node))))
    (if (null kids)
        node
        (let ((new-kids (mapcar (lambda (c) (transform-top-down fn c :ctx ctx)) kids)))
          (if (eq kids new-kids) node (%copy-el node :children new-kids))))))

(defun transform-bottom-up (fn el &key ctx)
  (let* ((kids (and (typep el 'base-element) (element-children el)))
         (new-kids (when kids (mapcar (lambda (c) (transform-bottom-up fn c :ctx ctx)) kids)))
         (with-kids (if (and kids (not (eq kids new-kids))) (%copy-el el :children new-kids) el)))
    (funcall fn with-kids ctx)))

;; ── Pass 1: component expansion (this replaces semantic injection) ──────────
(defun resolve-components (node &optional ctx)
  "If NODE is a component, replace it with the *tree* returned by (component-view node :ctx ctx).
   Otherwise, return NODE (and traversal will descend)."
                                        ;(cond
  (let ((tree (dsl->objects (elmtui.view.dsl:dsl->ui-node node (elmtui.contracts:ctx-state ctx)))))
    tree))
;; ((elmtui.view.dsl:render-dsl-to-resolved-tree node ctx)
;; NOTE: component-view returns a *tree of base-elements*, which becomes the new node.
;;  (or (component-view node :ctx ctx)
;;      ;; Allow components to render nothing
;;      nil))
;; (t node)))

;; ── Pass 2: style expansion (optional; if you use style groups) ────────────
(defun expand-element-style (el &optional ctx)
  (declare (ignore ctx))
  (let* ((old (elmtui.view.element:el/styles el))
         (new (elmtui.style-lib.macros:expand-stylegroups old)))
    (if (equal old new) el (%copy-el el :style new))))
;; (defun expand-element-style (el)
;;   "Expand stylegroups in element's style plist (idempotent)."
;;   (let* ((old (element-style el))
;;          (new (elmtui.style-lib.properties::expand-style old)))
;;     (if (equal old new)
;;         el
;;         (%copy-element-like el :style new))))
;; ── Pass 3: measure (bottom-up) ────────────────────────────────────────────
(defun pass-measure (el &optional ctx)
  (declare (ignore ctx))
  (let* ((measured (compute-size el))
         (current  (element-size el)))
    (if (equal current measured)
        el
        (progn (setf (element-size el) measured) el))))

;; ── Pass 4: layout (top-down precise, or bottom-up fallback) ───────────────
(defun pass-layout-bottom-up (el &optional ctx)
  (declare (ignore ctx))
  (let* ((rect (compute-layout el))
         (curr (element-layout el)))
    (if (and curr (rect= curr rect)) el (progn (setf (element-layout el) rect) el))))

(defun layout-tree-top-down (root root-rect)
  (labels ((walk (node parent-rect)
             (let* ((laid (layout-node node parent-rect nil))
                    (rect (elmtui.view.element:el/layout-rect laid))
                    (kids (element-children laid)))
               (when (null rect)
                 (error "layout-node did not write :layout for ~S" node))
               (when kids
                 (setf (element-children laid)
                       (mapcar (lambda (c) (walk c rect))
                                kids)))
               laid)))
    (walk root root-rect)))

;; ── Pass 5: dirty mark ─────────────────────────────────────────────────────
(defun pass-dirty (el &optional ctx)
  (declare (ignore ctx))
  (when (element-changed-p el)
    (setf (element-dirty-p el) t))
  el)

;; ── Orchestration ──────────────────────────────────────────────────────────
(defun process-tree (root &key ctx root-rect)
  "Pipeline:
   1) resolve-components (top-down) — *component view methods expand the tree*
   2) expand-element-style (top-down)
   3) measure (bottom-up)
   4) layout: top-down precise if ROOT-RECT, else bottom-up fallback
   5) pass-dirty (top-down)"
  (let* ((p1 (transform-top-down #'resolve-components root :ctx ctx))
         (p2 (transform-top-down #'expand-element-style p1 :ctx ctx))
         (p3 (transform-bottom-up #'pass-measure p2 :ctx ctx))
         (p4 (if root-rect
                 (layout-tree-top-down p3 root-rect)
                 (transform-bottom-up #'pass-layout-bottom-up p3 :ctx ctx)))

         (p5 (transform-top-down #'pass-dirty p4 :ctx ctx)))
    p5))
