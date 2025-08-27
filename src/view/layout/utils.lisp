(uiop:define-package :elmtui.view.layout.size-utils
  (:use :cl)
  (:import-from #:log4cl :log-info)
  (:import-from :elmtui.view.geo
                #:size #:make-size #:size-w #:size-h #:make-rectangle #:make-pos
                #:w #:h #:x #:y #:rectangle)

  (:import-from :elmtui.view.element
                #:el/styles #:el/children #:el/props #:el/styles-of)
  (:import-from :elmtui.view.base-elements
                #:element-children
                #:base-element #:element-props #:element-style)

  (:export
   #:measure-node-intrinsic-size
   #:content-rect-of
   #:compute-layout
   #:compute-size))

(in-package :elmtui.view.layout.size-utils)

;;;; ---------- style access ----------

(defun %style-plist (node)
  "Return raw style storage (plist or hash-table) from either slot."
  (or (ignore-errors (elmtui.view.element:el/styles node))
      (ignore-errors (elmtui.view.base-elements:element-style node))
      nil))

(defun style-value (node key &optional default)
  "Read KEY from style regardless of backing store shape."
  (let ((st (%style-plist node)))
    (cond
      ((hash-table-p st) (multiple-value-bind (v p) (gethash key st)
                           (if p v default)))
      ((listp st) (getf st key default))
      (t default))))

;;;; ---------- small helpers ----------

(defun percentp (x)
  (and (stringp x)
       (> (length x) 1)
       (char= #\% (char x (1- (length x))))))

(defun percent-of (s total)
  "Return S% of TOTAL. If TOTAL is not a number, treat as 0."
  (when (percentp s)
    (let* ((n (ignore-errors (parse-integer s :end (1- (length s))))))
      (when (numberp n)
        (let ((tot (if (numberp total) (max 0 total) 0)))
          (* (/ n 100.0d0) tot))))))

(defun clamp (v lo hi) (max lo (min v hi)))
(defun num-or-nil (v)   (and (numberp v) v))
(defun num+ (x)         (and (numberp x) (>= x 0) x))

(defparameter *default-root-content-size*
  (elmtui.view.geo:make-size :w 80 :h 24))

(defun infer-parent-content-size (el)
  "Try to infer a usable parent content size for EL."
  (let* ((existing (ignore-errors (elmtui.view.element:el/layout-rect el)))
         (sw (num+ (style-value el :width nil)))
         (sh (num+ (style-value el :height nil))))
    (cond
      ((typep existing 'elmtui.view.geo:rectangle)
       (elmtui.view.geo:make-size
        :w (elmtui.view.geo:w existing)
        :h (elmtui.view.geo:h existing)))
      ((and sw sh)
       (elmtui.view.geo:make-size :w sw :h sh))
      (t *default-root-content-size*))))

;;;; ---------- intrinsic measurement ----------

(defun %string-display-width (s)
  "Very naive monospace width: character count."
  (length (or s "")))

(defun %text-wrap (node)
  (or (ignore-errors (elmtui.view.base-elements:text-wrap node))
      (ignore-errors (slot-value node 'wrap))
      t))

(defun %text-content (node)
  (or (ignore-errors (elmtui.view.base-elements:text-content node))
      (ignore-errors (slot-value node 'content))
      ""))

(defun measure-node-intrinsic-size (node container-w container-h)
  "Return 4 values: (minw maxw minh maxh). Never NIL.
   Rules:
   - number         → that number (clamped)
   - \"NN%\"        → NN% of container axis (clamped), non-numeric container ⇒ 0
   - :auto | :fill → min-content (min-width/min-height)
   - text           → width≈string length (or wrapped to container-w); height≥1"
  (declare (ignore container-h))
  (labels ((pct (v total) (percent-of v total)))
    (typecase node
      (elmtui.view.base-elements:text-element
       (let* ((wrap (%text-wrap node))
              (text (%text-content node))
              (mw  (or (style-value node :min-width  0) 0))
              (mh  (or (style-value node :min-height 0) 0))
              (Mxw (or (style-value node :max-width  most-positive-fixnum)
                       most-positive-fixnum))
              (Mxh (or (style-value node :max-height most-positive-fixnum)
                       most-positive-fixnum))
              (wstr (%string-display-width text)))
         (cond
           ((and wrap (numberp container-w) (> container-w 0))
            (let* ((w (min wstr container-w))
                   (h (max 1 (ceiling (/ (max 1 wstr) (max 1 container-w))))))
              (values (max mw (min w Mxw)) Mxw
                      (max mh (min h Mxh)) Mxh)))
           (t
            (values (max mw (min wstr Mxw)) Mxw
                    (max mh (min 1    Mxh)) Mxh)))))

      (elmtui.view.base-elements:separator-element
       (let ((orientation (ignore-errors (elmtui.view.base-elements:separator-orientation node)))
             (thickness  (or (ignore-errors (elmtui.view.base-elements:separator-thickness node)) 1)))
         (if (eq orientation :horizontal)
             (values 0 most-positive-fixnum thickness thickness)
             (values thickness thickness 0 most-positive-fixnum))))

      (elmtui.view.base-elements:spacer-element
       (let ((width  (or (ignore-errors (elmtui.view.base-elements:spacer-width node))  0))
             (height (or (ignore-errors (elmtui.view.base-elements:spacer-height node)) 0)))
         (values width width height height)))

      (t
       (let* ((is-text (typep node 'elmtui.view.base-elements:text-element))
              (mw  (or (style-value node :min-width  0) 0))
              (Mxw (or (style-value node :max-width  most-positive-fixnum)
                       most-positive-fixnum))
              (w   (or (style-value node :width :auto) :auto))
              (mh  (or (style-value node :min-height (if is-text 1 0))
                       (if is-text 1 0)))
              (Mxh (or (style-value node :max-height most-positive-fixnum)
                       most-positive-fixnum))
              (h   (or (style-value node :height :auto) :auto))
              (ar  (style-value node :aspect-ratio nil))

              (resolved-w
                (cond
                  ((numberp w) (max 0 (min w Mxw)))
                  (t (let ((p (pct w container-w)))
                       (if (numberp p) (max 0 (min p Mxw))
                           (max 0 (min mw Mxw)))))))

              (resolved-h
                (cond
                  ((numberp h) (max 0 (min h Mxh)))
                  (t (let* ((pct-total (if (and (numberp container-w) (numberp ar))
                                           (/ container-w ar)
                                           container-w))
                            (p (pct h pct-total)))
                       (if (numberp p) (max 0 (min p Mxh))
                           (max 0 (min mh Mxh))))))))
         (values resolved-w
                 (if (numberp w) (max 0 (min w Mxw)) (max 0 Mxw))
                 resolved-h
                 (if (numberp h) (max 0 (min h Mxh)) (max 0 Mxh))))))))

;;;; ---------- public size API ----------

(defun compute-size* (node parent-content-width parent-content-height)
  "Return content-box W,H for NODE under given parent content size."
  (labels ((res (spec axis)
             (cond
               ((num-or-nil spec) spec)
               ((eql spec :fill)
                (if (eq axis :w) parent-content-width parent-content-height))
               ((percentp spec)
                (if (eq axis :w)
                    (percent-of spec parent-content-width)
                    (percent-of spec parent-content-height)))
               (t :auto))))
    (let* ((sw   (style-value node :width  :auto))
           (sh   (style-value node :height :auto))
           (minw (or (style-value node :min-width  0) 0))
           (maxw (or (style-value node :max-width  most-positive-fixnum) most-positive-fixnum))
           (minh (or (style-value node :min-height 0) 0))
           (maxh (or (style-value node :max-height most-positive-fixnum) most-positive-fixnum))
           (rw (res sw :w))
           (rh (res sh :h)))
      (multiple-value-bind (mincw maxcw minch maxch)
          (measure-node-intrinsic-size node parent-content-width parent-content-height)
        (declare (ignore maxcw maxch))
        (let* ((w0 (if (eq rw :auto) (or mincw 0) rw))
               (h0 (if (eq rh :auto) (or minch 0) rh))
               (w  (clamp w0 minw maxw))
               (h  (clamp h0 minh maxh)))
          (values (round w) (round h)))))))

(defun compute-size (el &optional parent-content-size)
  "Compute border-box size for EL under optional parent CONTENT size (size struct)."
  (let* ((pcs (or parent-content-size
                  (infer-parent-content-size el))))
    (multiple-value-bind (w h)
        (compute-size* el
                       (elmtui.view.geo:w pcs)
                       (elmtui.view.geo:h pcs))
      (elmtui.view.geo:make-size :w w :h h))))

(defgeneric content-rect-of (outer-rect element)
  (:documentation "Return ELEMENT’s content box rectangle given its OUTER-RECT.
  OUTER-RECT is a border-box; this subtracts paddings and borders from OUTER-RECT
  and returns the inner content rectangle used for child layout. Does not perform
  any measurement; purely geometric.")
  (:method ((outer-rect elmtui.view.geo:rectangle)
            (element elmtui.view.base-elements:base-element))
    (let* ((pt (or (el/styles-of element :padding-top    0) 0))
           (pr (or (el/styles-of element :padding-right  0) 0))
           (pb (or (el/styles-of element :padding-bottom 0) 0))
           (pl (or (el/styles-of element :padding-left   0) 0))
           (bs (or (el/styles-of element :border-style :none) :none))
           (bw (if (eq bs :none) 0 (or (el/styles-of element :border-width 1) 1)))
           (bt (if (eq bs :none) 0 (or (el/styles-of element :border-top-width    bw) bw)))
           (br (if (eq bs :none) 0 (or (el/styles-of element :border-right-width  bw) bw)))
           (bb (if (eq bs :none) 0 (or (el/styles-of element :border-bottom-width bw) bw)))
           (bl (if (eq bs :none) 0 (or (el/styles-of element :border-left-width   bw) bw)))
           (cx (+ (elmtui.view.geo:x outer-rect) pl bl))
           (cy (+ (elmtui.view.geo:y outer-rect) pt bt))
           (cw (max 0 (- (elmtui.view.geo:w outer-rect) pl pr bl br)))
           (ch (max 0 (- (elmtui.view.geo:h outer-rect) pt pb bt bb))))
      (log-info "content-rect-of: outer=~A, element=~A => content-rect=~A"
                outer-rect element
                (elmtui.view.geo:make-rectangle
                 :pos  (elmtui.view.geo:make-pos  :x cx :y cy)
                 :size (elmtui.view.geo:make-size :w cw :h ch)))
      (elmtui.view.geo:make-rectangle
       :pos  (elmtui.view.geo:make-pos  :x cx :y cy)
       :size (elmtui.view.geo:make-size :w cw :h ch))))
  (:method ((outer-rect elmtui.view.geo:rectangle)
            (element t))
    (error (format nil "content-rect-of: Unsupported element type ~A" (type-of element)))))
;; Fallback for non-elements: return outer rect as-is
;; outer-rect))

(defgeneric compute-layout (style node rect &key &allow-other-keys)
  (:documentation "Compute the layout for a node based on its style and available rect.
   Returns the node with its layout rect set."))
