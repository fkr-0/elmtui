                                        ; == elmtui/view/tree-transforms.lisp ==
(uiop:define-package :elmtui.view.tree-transforms
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.contracts
    #:define-stage #:pipeline-contract-violation
    #:ctx-viewport-rect) ; <-- use viewport rect from ctx
  (:import-from :elmtui.view.base-elements
    #:base-element #:element-dirty-p #:base-element-p
    #:compute-layout #:rect= #:element-changed-p
    #:padding-needed-p #:make-padding-wrapper
    #:base-dsl-p #:dsl->objects)
  (:import-from :elmtui.view.layout.size-utils #:compute-size #:content-rect-of)
  (:import-from :elmtui.view.layout #:layout-node)
  (:import-from :elmtui.view.geo
    #:rectangle #:make-size #:make-pos #:make-rectangle #:x #:y #:w #:h)
  (:export #:process-tree #:resolve-components #:layout-tree-top-down))

(in-package :elmtui.view.tree-transforms)

;; --- helper: keyword-ify symbols/strings ----------------------------------
(defun %kw (v &optional default)
  (etypecase v
    ((or null number) (or v default))
    (keyword v)
    (string (intern (string-upcase v) :keyword))
    (symbol (intern (string-upcase (symbol-name v)) :keyword))))

(defun %canon-style-plist (plist)
  "Return a new plist with keys keywordized and selected enum values normalized.
   Skips malformed leading values; only processes proper key/value pairs.
   Do not touch structured values like color tuples (e.g., (:rgb 255 0 0))."
  (labels ((norm-enum (x)
             (cond ((or (null x) (numberp x) (hash-table-p x) (listp x)) x)
               ((or (stringp x) (symbolp x)) (%kw x x))
               (t x)))
            (norm-dim (x)
              (cond ((or (null x) (numberp x) (hash-table-p x) (listp x)) x)
                ((or (stringp x) (symbolp x)) (let ((vk (%kw x x))) (if (eq vk :AUTO) :auto x)))
                (t x))))
    (let ((out '())
           (cursor plist))
      (loop while cursor do
        (let ((k (first cursor)))
          (cond
            ((keywordp k)
              (let ((v (second cursor)))
                (let* ((kk (%kw k))
                        (vv (cond
                              ((member kk '(:display :flex-direction :direction :justify-content :justify :align-items :align-self :flex-wrap :position :overflow :visibility) :test #'eq)
                                (norm-enum v))
                              ((member kk '(:width :height :min-width :min-height :max-width :max-height :flex-basis) :test #'eq)
                                (norm-dim v))
                              (t v))))
                  (setf out (nconc out (list kk vv))))
                (setf cursor (cddr cursor))))
            (t
              ;; Skip stray value
              (setf cursor (rest cursor))))))
      out)))

(defun %get-style (el)
  "Fetch style from protocol view first, fallback to base-element slot."
  (or (ignore-errors (elmtui.view.element:el/styles el))
    (ignore-errors (elmtui.view.base-elements:element-style el))
    nil))

(defun %set-style! (el new-style)
  "Write style back consistently to both views."
  (setf (elmtui.view.element:el/styles el) new-style)
  (ignore-errors (setf (elmtui.view.base-elements:element-style el) new-style)))

(defun expand-element-style (el &key ctx)
  "Normalize style keys/values to keywords and store them back. Style-group
   expansion is now handled by cl-styles engine; avoid legacy macros here."
  (declare (ignore ctx))
  (let* ((raw (%get-style el))
          (canon (%canon-style-plist raw))
          (expanded canon))
    (unless (equal raw expanded)
      (%set-style! el expanded))
    el))

(defun ensure-flex-display (el &key ctx)
  "If a node declares :flex-direction but no :display, set :display :flex.
   Helps older DSL that omit explicit display while using flex semantics."
  (declare (ignore ctx))
  (let* ((st (%get-style el)))
    (when (and (listp st)
            (getf st :flex-direction nil)
            (null (getf st :display nil)))
      (let ((new (nconc (copy-list st) (list :display :flex))))
        (%set-style! el new)))
    el))

(defun transform-bottom-up (fn el &key ctx)
  (let ((kids (elmtui.view.element:el/children el)))
    (when kids
      (setf (elmtui.view.element:el/children el)
        (mapcar (lambda (c) (transform-bottom-up fn c :ctx ctx)) kids)))
    (funcall fn el :ctx ctx)))

(defun transform-top-down (fn el &key ctx)
  (let* ((new-el (funcall fn el :ctx ctx))
          ;; (_ (log-info "TD with ~A el to new el: ~A -> ~A" fn el new-el))
          (kids (and new-el (elmtui.view.element:el/children new-el))))
    (when kids
      (setf (elmtui.view.element:el/children new-el)
        (remove nil
          (mapcar (lambda (c) (transform-top-down fn c :ctx ctx))
            (remove nil kids)))))
    new-el))

(defun %element-summary (el)
  "Return a short description of EL for logging."
  (cond
    ((null el) "nil")
    ((ignore-errors (elmtui.view.element:el/type el))
     (let* ((type (ignore-errors (elmtui.view.element:el/type el)))
            (id (ignore-errors (elmtui.view.element:el/id el))))
       (format nil "~(~a~)~@[ id=~a~]" type id)))
    ((keywordp el) (string-downcase (symbol-name el)))
    (t (format nil "~A" el))))

(defun %rect-summary (rect)
  (if (and rect (ignore-errors (w rect)))
      (format nil "~dx~d" (w rect) (h rect))
      (format nil "~A" rect)))

(defun resolve-dsl (el)
  "Turn DSL-spec nodes into base-element instances."
  (cond
    ((base-element-p el) el)
    ((base-dsl-p el) (dsl->objects el))
    ((and (listp el) (every #'base-dsl-p el)) (mapcar #'dsl->objects el))
    (t el)))

(defun mark-dirty-if-changed (el)
  (when (element-changed-p el)
    (setf (element-dirty-p el) t))
  el)

(defun resolve-components (node &key ctx)
  "Normalize NODE to object tree: if it's already a base-element tree, return it;
   if it's DSL, resolve components and convert to objects."
  (log-debug "Resolving components for ~A" node)
  (cond
    ((elmtui.view.base-elements:base-element-p node) node)
    (t
      (let ((resolved (elmtui.view.dsl:dsl->ui-node node (elmtui.contracts:ctx-state ctx))))
        (if resolved
          (elmtui.view.base-elements:dsl->objects resolved)
          (progn
            (log-debug "resolve-components: unresolved node ~A; returning NIL." node)
            nil))))))


(defun pass-dirty (el &key ctx)
  (declare (ignore ctx))
  (mark-dirty-if-changed el))

(defun %ensure-root-rect (root ctx root-rect)
  "Pick a robust root rect: explicit arg > ctx.viewport > existing layout > error."
  (or root-rect
    (ctx-viewport-rect ctx)
    (elmtui.view.element:el/layout-rect root)
    (progn
      (log-error "No root rectangle provided and no viewport in ctx; using 0x0 at (0,0).")
      (make-rectangle :pos (make-pos :x 0 :y 0)
        :size (make-size :w 0 :h 0)))))


(defun pass-layout-bottom-up (el &key ctx)
  ;; If someone invokes bottom-up, at least provide a real parent rect.
  (let* ((parent (or (elmtui.contracts:ctx-viewport-rect ctx)
                   (elmtui.view.element:el/layout-rect el)
                   (elmtui.view.geo:make-rectangle
                     :pos  (elmtui.view.geo:make-pos :x 0 :y 0)
                     :size (elmtui.view.geo:make-size :w 0 :h 0)))))
    (let ((rect (compute-layout el parent)))
      (unless (and (elmtui.view.element:el/layout-rect el)
                (rect= (elmtui.view.element:el/layout-rect el) rect))
        (setf (elmtui.view.element:el/layout-rect el) rect)))
    el))

(defun layout-tree-top-down (root root-rect)
  "Top-down layout: lay out NODE in PARENT-RECT; recurse passing each CHILD'S OWN rect.
   Critical: each child receives its own computed rect, not the parent's rect. If a child
   rect is missing, fall back to the parent's content box once."
  (labels ((walk (node parent-rect)
             (let* ((laid-node (elmtui.view.base-elements:compute-layout node parent-rect))
                     (parent-rect* (elmtui.view.element:el/layout-rect laid-node)))
               (when (null parent-rect*)
                 (error "layout-node failed to assign a rect to ~S" node))
               (log-debug "layout assigned ~A" (%element-summary node))
               (when (elmtui.view.element:el/children laid-node)
                 (setf (elmtui.view.element:el/children laid-node)
                   (mapcar (lambda (child)
                             (let ((child-rect (elmtui.view.element:el/layout-rect child)))
                               (unless child-rect
                                 ;; Fallback: use parent's content box for one step
                                 (setf child-rect (elmtui.view.layout.size-utils:content-rect-of parent-rect* laid-node)))
                               (walk child child-rect)))
                     (elmtui.view.element:el/children laid-node))))
               laid-node)))
    (walk root root-rect)))



;; 1) pick a root rect: explicitly passed, else from ctx.viewport
(defun %root-rect-or-viewport (root ctx root-rect)
  (declare (ignore root))
  (or root-rect
    (elmtui.contracts:ctx-viewport-rect ctx)
    (elmtui.view.geo:make-rectangle
      :pos  (elmtui.view.geo:make-pos :x 0 :y 0)
      :size (elmtui.view.geo:make-size :w 80 :h 24)))) ; sane fallback for tests

;; 2) top-down *measure* that threads parent content size to children
(defun measure-tree-top-down (root root-rect)
  "Compute intrinsic sizes top-down. Each node is measured with its parent content size so
   percentages resolve. We do *not* assign layout rects here."
  (labels ((content-box (outer-rect node)
             ;; reuse your flex/content-box helper to remove paddings
             (elmtui.view.layout.flex::content-box outer-rect node))
            (make-outer-from-size (node size)
              (declare (ignore node))
              ;; provisional outer rect at origin with measured size
              (elmtui.view.geo:make-rectangle
                :pos  (elmtui.view.geo:make-pos :x 0 :y 0)
                :size (elmtui.view.geo:make-size :w (elmtui.view.geo:w size)
                        :h (elmtui.view.geo:h size))))
            (walk (node parent-content-rect)
              (let* (;; (pcw (elmtui.view.geo:w parent-content-rect))
                      ;; (pch (elmtui.view.geo:h parent-content-rect))
                      ;; IMPORTANT: pass parent content W/H so % resolve
                      (measured (elmtui.view.layout.size-utils:compute-size node (et.geo:size parent-content-rect))))
                ;; record intrinsic size
                (setf (elmtui.view.base-elements:element-size node) measured)
                ;; derive this node's content-box for its children
                (let* ((provisional (make-outer-from-size node measured))
                        (child-parent (content-box provisional node))
                        (kids (elmtui.view.base-elements:element-children node)))
                  (when kids
                    (setf (elmtui.view.base-elements:element-children node)
                      (mapcar (lambda (c) (walk c child-parent)) kids))))
                node)))
    (log-debug "measure root ~A" (%element-summary root))
    (walk root (elmtui.view.layout.flex::content-box root-rect root))))

;; 3) wire it into the pipeline before layout
(defun process-tree (root &key ctx root-rect)
  "Pipeline: resolve → expand styles → measure(top-down) → layout(top-down) → mark-dirty.

   Return the fully processed tree or NIL if resolution failed.

   ARGS:
     ROOT - root node of the tree to process
     :CTX - application context (elmtui.contracts:app-context)
     :ROOT-RECT - rectangle to use as the root layout rectangle; if NIL,
                  ctx.viewport-rect is used.

   STEPS:
     1) Resolve components: convert DSL to base-element instances
     2) Expand element styles: normalize style plists
     3) Measure tree top-down: compute intrinsic sizes
     4) Layout tree top-down: compute layout rects
     5) Mark dirty nodes: flag nodes that changed during processing

   NOTES:
     - If a stylesheet is present in CTX, apply it after style expansion.
     - If ROOT-RECT is not provided, CTX's viewport rectangle is used.
     - If component resolution fails (returns NIL), the entire process aborts
       and NIL is returned.

   RETURNS:
     The fully processed tree with layout information, or NIL if resolution failed."
  (labels ((ensure-node (x)
             (cond
               ((elmtui.view.base-elements:base-element-p x) x)
               ((and (listp x)
                  (every #'elmtui.view.base-elements:base-element-p x))
                 (first x))
               (t x))))
    (log-debug "process-tree root ~A rect ~A" (%element-summary root) (%rect-summary root-rect))
    (let* ((p1 (transform-top-down #'resolve-components root :ctx ctx)))
      (when (null p1)
        (log-debug "process-tree: component resolution returned NIL; aborting.")
        (return-from process-tree nil))
      (let* (;; (_ (log-info "Resolve components done ~A" p1))
              (p2 (transform-top-down #'expand-element-style p1 :ctx ctx))
              ;; Apply cl-styles if a stylesheet is present in ctx. Use :objects so
              ;; set-computed-style is invoked and styles merge into inline.
              ;; (_ (log-info "expand element style 1 done ~A" p2))
              (p2 (progn
                    (ignore-errors
                      (let ((sheet (elmtui.contracts:ctx-stylesheet ctx)))
                        (when sheet
                          (cl-styles.engine:apply-stylesheet-to-tree p2 sheet :return :objects))
                        p2))
                    (ensure-node p2)))
              ;; (_ (log-info "ensure node done ~A" p2))
              ;; Ensure styles are present on every node before layout
              (p2 (transform-top-down #'expand-element-style p2 :ctx ctx))
              ;; (_ (log-info "expand element style 2 done"))
              (p2 (transform-top-down #'ensure-flex-display p2 :ctx ctx))
              ;; (_ (log-info "ensure flex display done"))
              (rr (%root-rect-or-viewport p2 ctx root-rect))
              (p3 (measure-tree-top-down p2 rr))
              ;; (_ (log-info "measure tree top down done"))
              (p4 (layout-tree-top-down p3 rr))
              (p5 (transform-top-down #'pass-dirty p4 :ctx ctx)))
        p5))))
;; == end/tree-transforms.lisp ==
