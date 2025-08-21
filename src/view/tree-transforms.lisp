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
  "Return a new plist with keys -> keywords, and common enum values -> keywords.
   Numeric and string values are kept intact."
  (let ((out '()))
    (loop for (k v) on plist by #'cddr
          for kk = (%kw k)
          for vv = (cond
                     ;; map common enums to keywords
                     ((member kk '(:display :flex-direction :direction :justify-content
                                   :justify :align-items :align-self
                                   :flex-wrap :position :overflow :visibility)
                              :test #'eq)
                      (%kw v v))
                     ;; 'auto -> :auto
                     ((and (member kk '(:width :height :min-width :min-height
                                        :max-width :max-height
                                        :flex-basis)
                                   :test #'eq)
                           (or (stringp v) (symbolp v)))
                      (let ((vk (%kw v v)))
                        (if (eq vk :AUTO) :auto v)))
                     (t v))
          do (setf out (list* kk vv out)))
    (nreverse out)))

(defun %get-style (el)
  "Fetch style from whichever slot your system currently uses."
  (elmtui.view.element:el/styles el))

(defun %set-style! (el new-style)
  "Write style back consistently."
  (setf (elmtui.view.element:el/styles el) new-style))

(defun expand-element-style (el &key ctx)
  "Normalize style keys/values to keywords, expand style groups, and store them back.
   IMPORTANT: Never copy to a wrong slot; write to (element-style el)."
  (declare (ignore ctx))
  (let* ((raw (%get-style el))
         (canon (nreverse (%canon-style-plist raw)))
         ;; if you rely on style-group macros, run them on the canonical plist
         (expanded (handler-case
                       (elmtui.style-lib.macros:expand-stylegroups canon)
                     (error () (nreverse canon)))))
    (unless (equal raw expanded)
      (%set-style! el expanded))
    el))

(defun transform-bottom-up (fn el &key ctx)
  (let ((kids (elmtui.view.element:el/children el)))
    (when kids
      (setf (elmtui.view.element:el/children el)
            (mapcar (lambda (c) (transform-bottom-up fn c :ctx ctx)) kids)))
    (funcall fn el :ctx ctx)))

(defun transform-top-down (fn el &key ctx)
  (let* ((new-el (funcall fn el :ctx ctx))
         (kids (elmtui.view.element:el/children new-el)))
    (when kids
      (setf (elmtui.view.element:el/children new-el)
            (mapcar (lambda (c) (transform-top-down fn c :ctx ctx)) kids)))
    new-el))

(defun resolve-dsl (el)
  "Turn DSL-spec nodes into base-element instances."
  (cond
    ((base-element-p el) el)
    ((base-dsl-p el) (dsl->objects el))
    ((and (listp el) (every #'base-dsl-p el)) (mapcar #'dsl->objects el))
    (t el)))

(defun measure-element (el)
  "Compute intrinsic border-box size once (no parent needed)."
  (let* ((measured (compute-size el))
         (current  (elmtui.view.element:el/size el)))
    (unless (equal current measured)
      (setf (elmtui.view.element:el/size el) measured))
    el))

(defun layout-element (el &key ctx)
  "Bottom-up fallback: try to use ctx viewport when available."
  (let* ((parent (or (ctx-viewport-rect ctx)
                     (elmtui.view.element:el/layout-rect el) ; last-known placement
                     (make-rectangle :pos (make-pos :x 0 :y 0)
                                     :size (make-size :w 0 :h 0))))
         (rect (compute-layout el parent))
         (curr (elmtui.view.element:el/layout-rect el)))
    (unless (and curr (rect= curr rect))
      (setf (elmtui.view.element:el/layout-rect el) rect))
    el))

(defun mark-dirty-if-changed (el)
  (when (element-changed-p el)
    (setf (element-dirty-p el) t))
  el)

(defun resolve-components (node &key ctx)
  "If NODE is a component, replace it with the tree from its view fn."
  (resolve-dsl ;node))
   (dsl->objects
    (elmtui.view.dsl:dsl->ui-node
     node
     (elmtui.contracts:ctx-state ctx)))))

;; (defun expand-element-style (el &key ctx)
;;   "Expand style-groups in-place. Do NOT change the slot name."
;;   (declare (ignore ctx))
;;   (let* ((old (elmtui.view.element:el/styles el))
;;          (new (elmtui.style-lib.macros:expand-stylegroups old)))
;;     (if (equal old new)
;;         el
;;         (progn
;;           ;; prefer element-style setter; also mirror to el/styles if needed
;;           (setf (element-style el) new)
;;           el))))

(defun pass-measure (el &key ctx)
  (declare (ignore ctx))
  (measure-element el))

;; (defun pass-layout-bottom-up (el &key ctx)
;;   (layout-element el :ctx ctx))

;; (defun layout-tree-top-down (root root-rect)
;;   "Top-down layout pass:
;;    1) layout-node MUST set EL/LAYOUT-RECT for NODE given PARENT-RECT
;;    2) recurse with EACH CHILD'S OWN RECT (preserves offsets)"
;;   (labels
;;       ((walk (node parent-rect)
;;          (let* ((laid (layout-node node parent-rect nil))
;;                 (rect (elmtui.view.element:el/layout-rect laid)))
;;            (when (null rect)
;;              (error "layout-node did not write :layout for ~S" node))
;;            (when (element-children laid)
;;              (setf (element-children laid)
;;                    (mapcar (lambda (c)
;;                              (let ((child-rect (elmtui.view.element:el/layout-rect c)))
;;                                (unless child-rect
;;                                  (log-warn "Child ~S has no layout-rect after laying out ~S. Using parent's content-box."
;;                                            c laid)
;;                                  (setf child-rect (content-rect-of rect laid)))
;;                                (walk c child-rect)))
;;                            (element-children laid))))
;;            laid)))
;;     (walk root root-rect)))

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


;; (defun expand-element-style (el &key ctx)
;;   ;; Expand style groups *in place* without copying the wrong slot.
;;   (declare (ignore ctx))
;;   (let* ((old (elmtui.view.element:el/styles el))
;;          (new (elmtui.style-lib.macros:expand-stylegroups old)))
;;     (if (equal old new)
;;         el
;;         (progn
;;           (setf (elmtui.view.base-elements:element-style el) new)
;;           el))))

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
   If a child somehow has no rect after parent layout, fall back to the parent's content box once."
  (labels ((walk (node parent-rect)
             (let* ((laid (layout-node node parent-rect nil))
                    (rect (elmtui.view.element:el/layout-rect laid)))
               (when (null rect)
                 (error "layout-node did not write :layout for ~S" node))
               (setf (elmtui.view.element:el/layout-rect node) rect)
               (when (elmtui.view.element:el/children laid)
                 (setf (elmtui.view.element:el/children laid)
                       (mapcar (lambda (c)
                                 (let ((child-rect (elmtui.view.element:el/layout-rect c)))
                                   (unless child-rect
                                     (log-warn "Child ~S had no rect after laying out ~S. Using parent's content-box."
                                               c laid)
                                     (setf child-rect (elmtui.view.layout.size-utils:content-rect-of rect laid)))
                                   (walk c child-rect)))
                               (elmtui.view.element:el/children laid))))
               laid)))
    (walk root root-rect)))


;; (defun %root-rect-or-viewport (root ctx maybe-root-rect)
;;   (or maybe-root-rect
;;       (elmtui.contracts:ctx-viewport-rect ctx)
;;       (elmtui.view.element:el/layout-rect root)
;;       (elmtui.view.geo:make-rectangle
;;        :pos  (elmtui.view.geo:make-pos :x 0 :y 0)
;;        :size (elmtui.view.geo:make-size :w 0 :h 0))))

;; (defun process-tree (root &key ctx root-rect)
;;   "Pipeline: resolve → expand styles → measure → layout (top-down using viewport) → mark-dirty."
;;   (let* ((p1 (transform-top-down #'resolve-components root :ctx ctx))
;;          (p2 (transform-top-down #'expand-element-style p1 :ctx ctx))
;;          (p3 (transform-bottom-up #'pass-measure p2 :ctx ctx))
;;          (rr (%root-rect-or-viewport p3 ctx root-rect))
;;          (p4 (layout-tree-top-down p3 rr))
;;          (p5 (transform-top-down #'pass-dirty p4 :ctx ctx)))
;;     p5))

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
    (walk root (elmtui.view.layout.flex::content-box root-rect root))))

;; 3) wire it into the pipeline before layout
(defun process-tree (root &key ctx root-rect)
  "Pipeline: resolve → expand styles → measure(top-down) → layout(top-down) → mark-dirty."
  (let* ((p1 (transform-top-down #'resolve-components root :ctx ctx))
         (p2 (transform-top-down #'expand-element-style p1 :ctx ctx))
         (rr (%root-rect-or-viewport p2 ctx root-rect))
         (p3 (measure-tree-top-down p2 rr))
         (p4 (layout-tree-top-down p3 rr))
         (p5 (transform-top-down #'pass-dirty p4 :ctx ctx)))
    p5))
;; == end/tree-transforms.lisp ==
