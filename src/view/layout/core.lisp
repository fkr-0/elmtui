;; ;; (uiop:define-package :elmtui.view.layout
;; ;;   (:use :cl)
;; ;;   (:nicknames :et.layout)
;; ;;   (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
;; ;;   (:import-from :elmtui.view.base-elements
;; ;;                 #:base-element #:element-children #:element-style
;; ;;                 #:element-layout #:element-props)
;; ;;   (:import-from :elmtui.view.api #:layout-node)
;; ;;   (:import-from :elmtui.view.geo
;; ;;                 #:make-pos #:make-size #:pos #:size
;; ;;                 #:rectangle #:make-rectangle #:copy-rectangle
;; ;;                 #:x #:y #:w #:h)
;; ;;   (:import-from :elmtui.view.layout.size-utils #:%copy-el
;; ;;                 #:compute-size #:content-rect-of)
;; ;;   (:export #:layout-tree #:layout-node #:dispatch-layout #:style-value #:layout-grid-container-impl))

;; ;; (in-package :elmtui.view.layout)

;; ;; (defun style-value (node key &optional default)
;; ;;   (getf (element-style node) key default))



;; ;; (defgeneric layout-grid-container-impl (node available-rect)
;; ;;   (:documentation "The actual implementation for grid layout, to be defined by the grid module."))

;; ;; (defgeneric dispatch-layout (display node available-rect parent-styles)
;; ;;   (:documentation "Dispatches to the appropriate layout algorithm based on display type."))

;; ;; (defmethod dispatch-layout ((display (eql :grid)) node available-rect parent-styles)
;; ;;   (declare (ignore parent-styles))
;; ;;   (layout-grid-container-impl node available-rect))

;; ;; (defmethod dispatch-layout ((display (eql :flex)) node available-rect parent-styles)
;; ;;   (elmtui.view.layout.flex:compute-flex-layout node available-rect parent-styles))

;; ;; (defmethod dispatch-layout (display node available-rect parent-styles)
;; ;;   "Default block layout."
;; ;;   (declare (ignore display parent-styles))
;; ;;   (let* ((border-box-size (compute-size node (make-size :w (w available-rect) :h (h available-rect))))
;; ;;          (new-rect (make-rectangle
;; ;;                     :pos (make-pos :x (x available-rect) :y (y available-rect))
;; ;;                     :size border-box-size)))
;; ;;     (setf (elmtui.view.element:el/layout-rect node) new-rect)
;; ;;     node))

;; ;; (defun layout-node (node parent-rect _ctx)
;; ;;   "Dispatch by display. For :container with :direction or :flex-direction, use flex.
;; ;; For plain leaves (e.g., :text) set a rect from intrinsic size if nothing else is set."
;; ;;   (declare (ignore _ctx))
;; ;;   (cond
;; ;;     ((and (typep node 'elmtui.view.base-elements:container-element)
;; ;;           (or (style-value node :flex-direction nil)
;; ;;               (style-value node :direction nil)))
;; ;;      (elmtui.view.layout.flex:compute-flex-layout node parent-rect nil))
;; ;;     ((typep node 'elmtui.view.base-elements:text-element)
;; ;;      (let* ((content-rect (content-rect-of parent-rect node))
;; ;;             (intr (elmtui.view.element:intrinsic-size-of node content-rect))
;; ;;             (w (elmtui.view.layout.flex::clamp (w intr) 0 (w (size content-rect))))
;; ;;             (h (elmtui.view.layout.flex::clamp (h intr) 0 (h (size content-rect))))
;; ;;             (pos (pos content-rect))
;; ;;             (rect (make-rectangle :pos pos :size (make-size :w w :h h))))
;; ;;        (setf (elmtui.view.element:el/layout-rect node) rect)
;; ;;        node))
;; ;;     (t
;; ;;      (unless (elmtui.view.element:el/layout-rect node)
;; ;;        (setf (elmtui.view.element:el/layout-rect node)
;; ;;              (content-rect-of parent-rect node)))
;; ;;      node)))
;; ;;; == elmtui/src/view/layout/core.lisp ==
;; (uiop:define-package :elmtui.view.layout
;;   (:use :cl)
;;   (:nicknames :et.layout)
;;   (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
;;   (:import-from :elmtui.view.base-elements
;;                 #:base-element #:element-children #:element-style
;;                 #:element-layout #:element-props)
;;   (:import-from :elmtui.view.api #:layout-node)
;;   (:import-from :elmtui.view.geo
;;                 #:make-pos #:make-size #:pos #:size
;;                 #:rectangle #:make-rectangle #:copy-rectangle
;;                 #:x #:y #:w #:h)
;;   (:import-from :elmtui.view.layout.size-utils #:%copy-el
;;                 #:compute-size #:content-rect-of)
;;   (:export #:layout-tree #:layout-node #:dispatch-layout #:style-value #:layout-grid-container-impl))

;; (in-package :elmtui.view.layout)

;; (defun style-value (node key &optional default)
;;   (getf (element-style node) key default))

;; (defgeneric layout-grid-container-impl (node available-rect)
;;   (:documentation "The actual implementation for grid layout, to be defined by the grid module."))

;; (defgeneric dispatch-layout (display node available-rect parent-styles)
;;   (:documentation "Dispatches to the appropriate layout algorithm based on display type."))

;; (defmethod dispatch-layout ((display (eql :grid)) node available-rect parent-styles)
;;   (declare (ignore parent-styles))
;;   (layout-grid-container-impl node available-rect))

;; (defmethod dispatch-layout ((display (eql :flex)) node available-rect parent-styles)
;;   (elmtui.view.layout.flex:compute-flex-layout node available-rect parent-styles))

;; (defmethod dispatch-layout (display node available-rect parent-styles)
;;   "Default block layout."
;;   (declare (ignore display parent-styles))
;;   (let* ((border-box-size (compute-size node (make-size :w (w available-rect) :h (h available-rect))))
;;          (new-rect (make-rectangle
;;                     :pos (make-pos :x (x available-rect) :y (y available-rect))
;;                     :size border-box-size)))
;;     (setf (elmtui.view.element:el/layout-rect node) new-rect)
;;     node))

;; (defun layout-node (node parent-rect _ctx)
;;   "Dispatch by declared :display when present, else heuristics.
;;    - :display :grid → grid
;;    - :display :flex → flex
;;    - container with :flex-direction or :direction → flex
;;    - text → intrinsic block
;;    - otherwise → block content rect"
;;   (declare (ignore _ctx))
;;   (let* ((st (element-style node))
;;          (display (getf st :display nil)))
;;     (cond
;;       ((eql display :grid)
;;        (dispatch-layout :grid node parent-rect st))
;;       ((eql display :flex)
;;        (dispatch-layout :flex node parent-rect st))
;;       ((and (typep node 'elmtui.view.base-elements:container-element)
;;             (or (getf st :flex-direction nil)
;;                 (getf st :direction nil)))
;;        (elmtui.view.layout.flex:compute-flex-layout node parent-rect nil))
;;       ((typep node 'elmtui.view.base-elements:text-element)
;;        (let* ((content-rect (content-rect-of parent-rect node))
;;               (intr (elmtui.view.element:intrinsic-size-of node content-rect))
;;               (tw  (elmtui.view.layout.flex::clamp (w intr) 0 (w (size content-rect))))
;;               (th  (elmtui.view.layout.flex::clamp (h intr) 0 (h (size content-rect))))
;;               (pos (pos content-rect))
;;               (rect (make-rectangle :pos pos :size (make-size :w tw :h th))))
;;          (setf (elmtui.view.element:el/layout-rect node) rect)
;;          node))
;;       (t
;;        (unless (elmtui.view.element:el/layout-rect node)
;;          (setf (elmtui.view.element:el/layout-rect node)
;;                (content-rect-of parent-rect node)))
;;        node))))
;; ;;; == end/core.lisp ==
;; == elmtui/src/view/layout/core.lisp ==
;; Default/block layout should RESPECT a given rect coming from a parent (e.g., flex).
;; It must NOT recompute width/height in that case; it should:
;;   1) set the node's layout-rect to the given available-rect
;;   2) compute the content-box
;;   3) seed/offset children into the content origin (no stacking/sizing here)
;;      so nested content gets the correct offset (fixes GRANDCHILDREN-GET-OFFSET).
(uiop:define-package :elmtui.view.layout
  (:use :cl)
  (:nicknames :et.layout)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.view.base-elements
                #:base-element #:container-element
                #:element-children #:element-style
                #:element-layout #:element-id)
  (:import-from :elmtui.view.api #:layout-node)
  (:import-from :elmtui.view.element
                #:el/layout-rect)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size #:pos #:size
                #:rectangle #:make-rectangle
                #:x #:y #:w #:h)
  (:import-from :elmtui.view.layout.size-utils 
                #:content-rect-of #:compute-layout)
  (:export #:layout-node #:dispatch-layout #:style-value))

;; (in-package :elmtui.view.layout)

;; (defun style-value (node key &optional default)
;;   (getf (element-style node) key default))

;; (defgeneric dispatch-layout (display node available-rect parent-styles))

;; ;; GRID and FLEX are dispatched elsewhere. Here is the BLOCK fallback:

;; (defmethod dispatch-layout (display node available-rect parent-styles)
;;   "BLOCK default: honor sizes from PARENT (available-rect). Do NOT recompute them.
;;    Only set the node rect = available-rect and translate children into the content box."
;;   (declare (ignore display parent-styles))
;;   ;; 1) Keep the size we were given (this preserves flex/grid computed sizes).
;;   (setf (el/layout-rect node) available-rect)
;;   ;; 2) Offset children to our content origin so grandchildren inherit offset.
;;   (let* ((content (content-rect-of available-rect node))
;;          (cx (x content))
;;          (cy (y content)))
;;     (dolist (ch (element-children node))
;;       (let* ((cr (or (el/layout-rect ch)
;;                      (make-rectangle :pos (make-pos :x cx :y cy)
;;                                      :size (make-size :w 0 :h 0)))))
;;         ;; translate child’s pos into our content origin; keep its size untouched
;;         (setf (el/layout-rect ch)
;;               (make-rectangle :pos (make-pos :x (+ cx (x cr)) :y (+ cy (y cr)))
;;                               :size (make-size :w (w cr) :h (h cr)))))))
;;   node)

;; (defmethod layout-node (node parent-rect _ctx)
;;   "Simple dispatcher: prefer explicit :display; fallback allows flex via :flex-direction/:direction."
;;   (declare (ignore _ctx))
;;   (let* ((st (element-style node))
;;          (display (getf st :display nil)))
;;                                         ; in layout-node (core)
;;     (log-info "layout-node ~A display=~A parent-rect=~S"
;;               (class-of node) (getf (element-style node) :display)
;;               (list (x parent-rect) (y parent-rect) (w parent-rect) (h parent-rect)))


;;     (cond
;;       ((eql display :grid)
;;        (compute-layout :grid node parent-rect))
;;       ;;(elmtui.view.layout.grid:layout-grid-container-impl node parent-rect))
;;       ((eql display :flex)
;;        (compute-layout :flex node parent-rect :parent-styles st))
;;       ((and (typep node 'container-element)
;;             (or (getf st :flex-direction nil)
;;                 (getf st :direction nil)))
;;        (compute-layout :flex node parent-rect))
;;       (t
;;        ;; BLOCK default: just honor the rect and offset children
;;        (dispatch-layout nil node parent-rect st)))))
;; ;; == end/core.lisp ==
;; ;; == elmtui/view/layout/core.lisp ==
;; ;;; Dispatch on :display first, then heuristics. Block default only sets the node's rect.

(in-package :elmtui.view.layout)
(defun style-value (node key &optional default)
  (let ((st (elmtui.view.element:el/styles node)))
    (getf st key default)))

;; (defun layout-node (node parent-rect _ctx)
;;   (declare (ignore _ctx))
;;   (let* ((st (elmtui.view.base-elements:element-style node))
;;          ;; be lenient: DISPLAY may sneak in as non-keyword if something missed canonicalization
;;          (display (or (getf st :display nil)
;;                       (%kw (getf st 'display nil) nil))))
;;     (cond
;;       ((eql display :grid) (dispatch-layout :grid node parent-rect st))
;;       ((eql display :flex) (dispatch-layout :flex node parent-rect st))
;; (defun style-value (node key &optional default)
;;   (getf (elmtui.view.base-elements:element-style node) key default))

;; add this helper (export it if other files use it)
(defun %commit-rect! (node rect)
  "Write layout rect to both canonical slots."
  (setf (elmtui.view.element:el/layout-rect node) rect)

  node)

(defgeneric dispatch-layout (display node available-rect parent-styles) (:documentation "Dispatches to the appropriate layout algorithm based on display type.

  DISPLAY is a keyword (e.g., :grid, :flex) or NIL for block fallback.
  NODE is the element to layout.
  AVAILABLE-RECT is the rectangle available for NODE.
  PARENT-STYLES is the style plist of the parent element, if needed for layout
  algorithms."))

(defmethod dispatch-layout (display node available-rect parent-styles)
  "Block fallback: honor available-rect for NODE."
  (declare (ignore display parent-styles))
  (log-debug "dispatch-layout BLOCK fallback for ~A available-rect=~S"
            (class-of node)
            (list (x available-rect) (y available-rect) (w available-rect) (h available-rect)))
  ;; keep size/pos from available-rect; do NOT synthesize child rects here
  (%commit-rect! node available-rect))



(defmethod dispatch-layout ((display (eql :grid)) node available-rect parent-styles)
  (declare (ignore parent-styles))
  (elmtui.view.layout.grid:compute-grid-layout node available-rect))

(defmethod dispatch-layout ((display (eql :flex)) node available-rect parent-styles)
  (declare (ignore parent-styles))
  (elmtui.view.layout.flex:compute-flex-layout node available-rect nil))

;; (defmethod dispatch-layout (display node available-rect parent-styles)
;;   "Block fallback: honor the available-rect for NODE; do **not** synthesize child rects here."
;;   (declare (ignore display parent-styles))
;;   (let* ((border-box-size (elmtui.view.layout.size-utils:compute-size
;;                            node (elmtui.view.geo:make-size :w (elmtui.view.geo:w available-rect)
;;                                                            :h (elmtui.view.geo:h available-rect))))
;;          (rect (elmtui.view.geo:make-rectangle
;;                 :pos  (elmtui.view.geo:make-pos  :x (elmtui.view.geo:x available-rect)
;;                                                  :y (elmtui.view.geo:y available-rect))
;;                 :size border-box-size)))
;;     (setf (elmtui.view.element:el/layout-rect node) rect)
;;     node))
(defun %kw (v &optional default)
  (etypecase v
    ((or null number) (or v default))
    (keyword v)
    (string (intern (string-upcase v) :keyword))
    (symbol (intern (string-upcase (symbol-name v)) :keyword))))

(defun %style-plist-of (node)
  "Return NODE's style only for the maintained base-element protocol."
  (and (typep node 'base-element)
       (element-style node)))

(defmethod layout-node (node parent-rect _ctx)
  (declare (ignore _ctx))
  (let* ((st (%style-plist-of node))
         (display (getf st :display))
         (parent-rect* parent-rect))
  (log-debug "layout-node ~A display=~S width=~S min-width=~S height=~S min-height=~S parent-rect=~S"
              (element-id node) display
              (getf st :width) (getf st :min-width) (getf st :height) (getf st :min-height)
              (list (x parent-rect*) (y parent-rect*) (w parent-rect*) (h parent-rect*)))
    (case display
      (:flex (compute-layout :flex node parent-rect* :parent-styles st))
      (:grid (compute-layout :grid node parent-rect*))
      (otherwise
       (cond
         ;; container with explicit flex-direction but no :display
         ((and (typep node 'container-element)
               (or (getf st :flex-direction nil)
                   (getf st :direction nil)))
          (compute-layout :flex node parent-rect*))
         ;; default/block: honor rect and let tree-transforms pass content-rect to children
         (t (progn
              (%commit-rect! node parent-rect*)
              ;; Pre-seed immediate children with parent's content-rect if they lack a rect,
              ;; so the top-down pass propagates usable sizes to their layout.
              (let* ((content (elmtui.view.layout.size-utils:content-rect-of parent-rect* node))
                     (cx (x content)) (cy (y content)) (cw (w content)) (ch (h content)))
                (dolist (chh (elmtui.view.base-elements:element-children node))
                  (unless (elmtui.view.element:el/layout-rect chh)
                    (setf (elmtui.view.element:el/layout-rect chh)
                          (elmtui.view.geo:make-rectangle
                           :pos  (elmtui.view.geo:make-pos  :x cx :y cy)
                           :size (elmtui.view.geo:make-size :w cw :h ch))))))
              node)))))))
;; (defmethod layout-node (node parent-rect _ctx)
;;   "Dispatch by :display when present; fallback: flex if direction set; text → intrinsic; else block."
;;   (declare (ignore _ctx))
;;   (let* ((st (elmtui.view.element:el/styles node))

;;          (display (or (getf st :display nil)
;;                       (%kw (getf st 'display nil) nil))))
;;     (cond
;;       ((eql display :grid) (dispatch-layout :grid node parent-rect st))
;;       ((eql display :flex) (dispatch-layout :flex node parent-rect st))
;;       ((and (typep node 'elmtui.view.base-elements:container-element)
;;             (or (getf st :flex-direction nil) (getf st :direction nil)))
;;        (elmtui.view.layout.flex:compute-flex-layout node parent-rect nil))
;;       ((typep node 'elmtui.view.base-elements:text-element)
;;        (let* ((content (elmtui.view.layout.size-utils:content-rect-of parent-rect node))
;;               (intr (elmtui.view.element:intrinsic-size-of node content))
;;               (tw  (elmtui.view.geo:w intr))
;;               (th  (elmtui.view.geo:h intr))
;;               (rect (elmtui.view.geo:make-rectangle
;;                      :pos  (elmtui.view.geo:pos content)
;;                      :size (elmtui.view.geo:make-size :w tw :h th))))
;;          (setf (elmtui.view.element:el/layout-rect node) rect)
;;          node))
;;       (t (dispatch-layout nil node parent-rect st)))))
;; == end/core.lisp ==
