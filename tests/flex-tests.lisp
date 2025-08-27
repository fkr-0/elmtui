;; ;; == tests/flex-offset-test.lisp ==
;; ;;; Patch #4 – FiveAM regression (run (fiveam:run! :flex-offset)) ─────────────

;; (uiop:define-package :elmtui.flex.tests
;;   (:use :cl :fiveam :elmtui.view.geo :elmtui.view.base-elements :elmtui.view.element)
;;   (:import-from :elmtui.view.layout.flex #:flex-item #:children-of
;;                 #:rect-of #:compute-flex-layout))
;; (in-package :elmtui.flex.tests)

;; (def-suite flex-offset
;;   :in elmtui.tests:elmtui-test
;;   :description "Comprehensive test suite for Elmtui contract system")
;; (in-suite flex-offset)

;; (test grandchildren-get-offset
;;   (let* ((root (make-instance 'flex-item
;;                               :rect (elmtui.view.geo:make-rectangle
;;                                      :pos (elmtui.view.geo:make-pos :x 10 :y 5)
;;                                      :size (elmtui.view.geo:make-size :w 100 :h 40))
;;                               :children nil))
;;          (child-a (make-instance 'flex-item
;;                                  :rect (elmtui.view.geo:make-rectangle
;;                                         :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                                         :size (elmtui.view.geo:make-size :w 30 :h 20))
;;                                  :children nil))
;;          (grand (make-instance 'flex-item
;;                                :rect (elmtui.view.geo:make-rectangle
;;                                       :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                                       :size (elmtui.view.geo:make-size :w 10 :h 10)))))
;;     (push grand (children-of child-a))
;;     (push child-a (children-of root))

;;     (compute-flex-layout root)
;;     ;; (layout-flex-container root)
;;     ;; (dump-rect-tree
;;     ;; root)
;;     ;; (list grand child-a root)
;;     (is (= 10 (elmtui.view.geo:x (rect-of child-a))))
;;     ;; we expect child-a to be positioned at (10, 5) relative to root,
;;     ;; because root's rectangle starts at (10, 5) and child-a's rectangle starts at (0, 0)
;;     (is (= 5  (elmtui.view.geo:y (rect-of child-a))))
;;     (is (= 10 (elmtui.view.geo:x (rect-of grand)))
;;         (format nil "grandchild got X ~A offset" (elmtui.view.geo:x (rect-of grand))))
;;     (is (= 5  (elmtui.view.geo:y (rect-of grand)))
;;         (format nil "grandchild got Y ~A offset" (elmtui.view.geo:y (rect-of grand))))
;;     ))

;; ;; (let ((r (et.geo:make-rectangle
;; ;;   :pos (et.geo:make-pos :x 10 :y 5)
;; ;;   :size (et.geo:make-size :w 100 :h 40))))
;; ;;   (et.geo::dx! r 20))
;; ;;; == elmtui/tests/flex-fiveam.lisp ==
;; ;;; FiveAM regression tests for elmtui Flex layout
;; ;;; - Uses a thin compatibility layer to adapt to the current public API.
;; ;;; - Focus: placement, gaps, margins, grow/shrink, basis, min/max, alignment, directions.
;; ;; == elmtui/tests/helpers/style-compat.lisp ==
;; (defun %add-style (node &rest kvs)
;;   ;; add to element-style
;;   (let* ((st (elmtui.view.base-elements:element-style node)))
;;     (setf (elmtui.view.base-elements:element-style node) (append kvs st)))
;;   ;; add to el/styles if exported
;;   (when (and (find-package :elmtui.view.element)
;;              (fboundp (intern "EL/STYLES" :elmtui.view.element)))
;;     (let ((cur (ignore-errors (funcall (intern "EL/STYLES" :elmtui.view.element) node))))
;;       (etypecase cur
;;         (hash-table (loop for (k v) on kvs by #'cddr do (setf (gethash k cur) v)))
;;         (null       (setf (elmtui.view.element:el/styles node) (copy-list kvs)))
;;         (list       (setf (elmtui.view.element:el/styles node)
;;                           (append kvs cur)))
;;         )))
;;   node)
;; ;; == end/style-compat.lisp ==

;; ;;; ------------------------------------------------------------
;; ;;; Compatibility layer (adapts to either compute-layout or layout-node)
;; ;;; ------------------------------------------------------------


;; (defun %call-layout (root parent-rect)
;;   "Try public layout entrypoints. Prefer base-elements:compute-layout if present.
;;    Fallback to view.layout:layout-node. Return the laid-out root."
;;   (cond
;;     ((and (find-package :elmtui.view.base-elements)
;;           (%maybe-symbol :elmtui.view.base-elements 'compute-layout)
;;           (fboundp (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements)))
;;      (funcall (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements) root parent-rect))
;;     ((and (find-package :elmtui.view.layout)
;;           (%maybe-symbol :elmtui.view.layout 'layout-node)
;;           (fboundp (intern "LAYOUT-NODE" :elmtui.view.layout)))
;;      (funcall (intern "LAYOUT-NODE" :elmtui.view.layout) root parent-rect nil))
;;     (t
;;      (error "No known public layout entrypoint found."))))

;; (defun %layout-rect-of (node)
;;   "Access the node layout rectangle in a portable way."
;;   (let* ((sym (%maybe-symbol :elmtui.view.base-elements 'element-layout-rect)))
;;     (if (and sym (fboundp sym))
;;         (funcall sym node)
;;         ;; Fallback to elmtui.view.element:el/layout-rect if exposed
;;         (let* ((sym2 (and (find-package :elmtui.view.element)
;;                           (find-symbol (string 'el/layout-rect) :elmtui.view.element))))
;;           (if (and sym2 (fboundp sym2))
;;               (funcall sym2 node)
;;               (error "Cannot read layout rect."))))))

;; (defun %set-children (parent kids)
;;   (setf (element-children parent) kids)
;;   parent)

;; ;; (defun %add-style (node &rest kvs)
;; ;;   (let* ((st (element-style node)))
;; ;;     (setf (element-style node) (append kvs st)))
;; ;;   node)

;; (defun %box (&key id (w nil) (h nil) (styles nil))
;;   "Simple container-element with optional fixed width/height and extra styles."
;;   (let ((node (make-instance 'container-element
;;                              :id id
;;                              :style (copy-list styles))))
;;     (when w (push :width (element-style node))
;;           (push w (element-style node)))
;;     (when h (push :height (element-style node))
;;           (push h (element-style node)))
;;     node))

;; (defun %rect->list (node)
;;   (let* ((r (%layout-rect-of node)))
;;     (list (element-id node) (x r) (y r) (w r) (h r))))

;; (defun %children-rects (node)
;;   (mapcar #'%rect->list (element-children node)))

;; (defun %root (&key (display :flex) (dir :row) (styles '()))
;;   (make-instance 'container-element
;;                  :id :root
;;                  :style (append (list :display display :flex-direction dir) (copy-list styles))))

;; (defun %layout-root (&key (root-styles '()) (dir :row)
;;                        (children '())
;;                        (parent-w 60) (parent-h 20))
;;   (let* ((root (%root :display :flex :dir dir :styles root-styles))
;;          (_ (%set-children root children))
;;          (parent (make-rectangle :pos (make-pos :x 0 :y 0)
;;                                  :size (make-size :w parent-w :h parent-h)))
;;          (laid (%call-layout root parent)))
;;     (declare (ignore _))
;;     laid))

;; ;;; ------------------------------------------------------------
;; ;;; Helpers for assertions
;; ;;; ------------------------------------------------------------

;; (defun approx= (a b &optional (eps 0.0001))
;;   (< (abs (- (coerce a 'double-float) (coerce b 'double-float))) eps))

;; (defmacro is-eql (a b)
;;   `(is (eql ,a ,b)))

;; (defmacro is-≈ (a b &optional (eps 0.0001))
;;   `(is (approx= ,a ,b ,eps)))



;; (test row-basic-padding-gap
;;   "Row layout: positions respect padding and gap."
;;   (let* ((a (%box :id :a :w 10 :h 3))
;;          (b (%box :id :b :w 5  :h 3))
;;          (c (%box :id :c :w 7  :h 3))
;;          (root ( %layout-root
;;                  :dir :row
;;                  :root-styles '(:padding-left 1 :padding-top 1 :gap 2)
;;                  :children (list a b c)
;;                  :parent-w 40 :parent-h 10)))
;;     (let* ((cr (%children-rects root)))
;;       ;; Expected x: 1, 13, 20  | y: 1 for all
;;       (is (equal cr
;;                  (list
;;                   '(:a 1 1 10 3)
;;                   '(:b 13 1 5 3)
;;                   '(:c 20 1 7 3)))))))



;; (test gap-and-margins
;;   "Verify gap + margins accumulate on main axis, and row/column mapping of :row-gap/:column-gap."
;;   (let* ((a (%box :id :a :w 4 :h 2 :styles '(:margin-left 1 :margin-right 1)))
;;          (b (%box :id :b :w 4 :h 2))
;;          (r (%layout-root :dir :row
;;                           :root-styles '(:padding-left 1 :gap 2 :row-gap 9 :column-gap 2)
;;                           :children (list a b)
;;                           :parent-w 40 :parent-h 10)))
;;     (let* ((ar (%layout-rect-of (child-by-id r :a)))
;;            (br (%layout-rect-of (child-by-id r :b))))
;;       ;; a.x starts at padding-left + margin-left
;;       (is (= (x ar) (+ 1 1)))
;;       ;; b.x = a.x + a.margin-left + a.width + a.margin-right + main-gap
;;       (is (= (x br) (+ (x ar) 1 4 1 2))))))

;; (test grow-distribution
;;   "Positive free space is split by flex-grow ratios."
;;   (let* ((root-w 40)
;;          ;; content width ~ 38 if pad-left/right=1
;;          (a (%box :id :a :w 5 :h 2 :styles '(:flex-grow 1)))
;;          (b (%box :id :b :w 5 :h 2 :styles '(:flex-grow 3)))
;;          (r (%layout-root :dir :row
;;                           :root-styles '(:padding-left 1 :padding-right 1 :justify-content :flex-start)
;;                           :children (list a b)
;;                           :parent-w root-w :parent-h 8))
;;          (ar (%layout-rect-of (child-by-id r :a)))
;;          (br (%layout-rect-of (child-by-id r :b)))
;;          (content-w (- root-w 1 1))
;;          (free (- content-w 10)))
;;     ;; a width = 5 + free*(1/4), b width = 5 + free*(3/4)
;;     (is-≈ (w ar) (+ 5 (* free (/ 1 4.0))))
;;     (is-≈ (w br) (+ 5 (* free (/ 3 4.0))))))
                                        ; == elmtui/tests/flex-fiveam.lisp ==
(uiop:define-package :elmtui.tests.flex
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo
                #:make-pos #:make-size #:make-rectangle #:x #:y #:w #:h)
  (:import-from :elmtui.view.base-elements
                #:container-element #:element-children #:element-style #:element-id)
  (:import-from :elmtui.view.element #:el/layout-rect)
  (:export #:run-flex-tests))

(in-package :elmtui.tests.flex)
(defun child-by-id (node id)
  (find id (element-children node) :key #'element-id))
(defun %maybe-symbol (pkg name)
  (ignore-errors (find-symbol (string name) pkg)))
(defun %call-layout (root parent-rect)
  (cond
    ((and (find-package :elmtui.view.base-elements)
          (fboundp (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements)))
     (funcall (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements) root parent-rect))
    ((and (find-package :elmtui.view.layout)
          (fboundp (intern "LAYOUT-NODE" :elmtui.view.layout)))
     (funcall (intern "LAYOUT-NODE" :elmtui.view.layout) root parent-rect nil))
    (t (error "No layout entrypoint."))))

;; (defun %box (&key id w h styles)
;;   (let ((n (make-instance 'container-element :id id :style (copy-list styles))))
;;     (when w (setf (element-style n) (append (list :width w) (element-style n))))
;;     (when h (setf (element-style n) (append (list :height h) (element-style n))))
;;     n))



(defun %rect (node) (el/layout-rect node))
(defun %child (root id) (find id (element-children root) :key #'element-id))
(defun approx= (a b &optional (eps 1e-4))
  (< (abs (- (coerce a 'double-float) (coerce b 'double-float))) eps))
(defun %layout-rect-of (node)
  "Access the node layout rectangle in a portable way."
  (let* ((sym (%maybe-symbol :elmtui.view.base-elements 'element-layout-rect)))
    (if (and sym (fboundp sym))
        (funcall sym node)
        ;; Fallback to elmtui.view.element:el/layout-rect if exposed
        (let* ((sym2 (and (find-package :elmtui.view.element)
                          (find-symbol (string 'el/layout-rect) :elmtui.view.element))))
          (if (and sym2 (fboundp sym2))
              (funcall sym2 node)
              (error "Cannot read layout rect."))))))

(defun %set-children (parent kids)
  (setf (element-children parent) kids)
  parent)

;; (defun %add-style (node &rest kvs)
;;   (let* ((st (element-style node)))
;;     (setf (element-style node) (append kvs st)))
;;   node)
(defun %box (&key id (w nil) (h nil) (styles nil))
  "Simple container-element with optional fixed width/height and extra styles."
  (let ((node (make-instance 'container-element
                             :id id
                             :style (copy-list styles))))
    (when w (push :width (element-style node))
          (push w (element-style node)))
    (when h (push :height (element-style node))
          (push h (element-style node)))
    node))


(defun %rect->list (node)
  (let* ((r (%layout-rect-of node)))
    (list (element-id node) (x r) (y r) (w r) (h r))))

(defun %children-rects (node)
  (mapcar #'%rect->list (element-children node)))

(defun %root (&key (display :flex) (dir :row) (styles '()))
  (make-instance 'container-element
                 :id :root
                 :style (append (list :display display :flex-direction dir) (copy-list styles))))
(defun %root2 (&key dir styles children pw ph)
  (let ((r (make-instance 'container-element :id :root
                                             :style (append (list :display :flex :flex-direction dir) styles))))
    (setf (element-children r) children)
    (%call-layout r (make-rectangle :pos (make-pos :x 0 :y 0)
                                    :size (make-size :w pw :h ph)))))
(defun %layout-root (&key (root-styles '()) (dir :row)
                       (children '())
                       (parent-w 60) (parent-h 20))
  (let* ((root (%root :display :flex :dir dir :styles root-styles))
         (_ (%set-children root children))
         (parent (make-rectangle :pos (make-pos :x 0 :y 0)
                                 :size (make-size :w parent-w :h parent-h)))
         (laid (%call-layout root parent)))
    (declare (ignore _))
    laid))

(def-suite elmtui/flex
  :in elmtui.tests:elmtui-test
  )
(in-suite elmtui/flex)


(test row-basic-padding-gap
  (let* ((a (%box :id :a :w 10 :h 3))
         (b (%box :id :b :w 5  :h 3))
         (c (%box :id :c :w 7  :h 3))
         (root (%root2 :dir :row :styles '(:padding-left 1 :padding-top 1 :gap 2)
                       :children (list a b c) :pw 40 :ph 10)))
    (is (equal (mapcar (lambda (n)
                         (let ((r (%rect n)))
                           (list (element-id n) (x r) (y r) (w r) (h r))))
                       (element-children root))
               '((:A 1 1 10 3) (:B 13 1 5 3) (:C 20 1 7 3))))))

;;; --- GAP-AND-MARGINS: account for ml(prev) correctly ----------------------

(test gap-and-margins
  (let* ((a (%box :id :a :w 4 :h 2 :styles '(:margin-left 1 :margin-right 1)))
         (b (%box :id :b :w 4 :h 2))
         (root (%root2 :dir :row
                       :styles '(:padding-left 1 :gap 2)
                       :children (list a b) :pw 40 :ph 10)))
    (let* ((ar (%rect (%child root :a)))
           (br (%rect (%child root :b))))
      ;; first item starts at content-start + ml(a)
      (is (= (x ar) (+ 1 1))) ; 1 pad-left + 1 ml(a)
      ;; next item starts at content-start + w(a) + mr(a) + gap + ml(b)
      ;; here ml(b)=0 → 1 + 4 + 1 + 2 = 8
      (is (= (x br) (+ 1 4 1 2)))
      (is (= (w ar) 4))
      (is (= (w br) 4)))))
(test justify-content-variants
  (let* ((pad 1) (pw 30)
         (root (%root2 :dir :row
                       :styles (list :padding-left pad :padding-right pad
                                     :padding-top pad :justify-content :flex-start)
                       :children (list (%box :id :a :w 5 :h 2)
                                       (%box :id :b :w 5 :h 2))
                       :pw pw :ph 8)))
    (let* ((a (%rect (%child root :a)))
           (b (%rect (%child root :b))))
      (is (= (x a) 1))
      (is (= (x b) 6))
      (is (= (y a) 1))
      (is (= (y b) 1))
      (is (= (w a) 5))
      (is (= (w b) 5)))))

;; (test gap-and-margins
;;   (let* ((a (%box :id :a :w 4 :h 2 :styles '(:margin-left 1 :margin-right 1)))
;;          (b (%box :id :b :w 4 :h 2))
;;          (root (%root :dir :row
;;                       :styles '(:padding-left 1 :gap 2)
;;                       :children (list a b) :pw 40 :ph 10)))
;;     (let* ((ar (%rect (%child root :a)))
;;            (br (%rect (%child root :b))))
;;       (is (= (x ar) (+ 1 1)))                      ; pad-left + ml(a)
;;       (is (= (x br) (+ (x ar) 4 1 2)))             ; + w(a) + mr(a) + gap
;;       (is (= (w ar) 4))
;;       (is (= (w br) 4)))))

(test grow-distribution
  (let* ((pw 40) (pl 1) (pr 1)
         (a (%box :id :a :w 5 :h 2 :styles '(:flex-grow 1)))
         (b (%box :id :b :w 5 :h 2 :styles '(:flex-grow 3)))
         (root (%root2 :dir :row
                       :styles (list :padding-left pl :padding-right pr :justify-content :flex-start)
                       :children (list a b) :pw pw :ph 8))
         (ar (%rect (%child root :a)))
         (br (%rect (%child root :b)))
         (content-w (- pw pl pr))
         (free (- content-w (+ 5 5))))
    (is (approx= (w ar) (+ 5 (* free (/ 1 4.0)))))
    (is (approx= (w br) (+ 5 (* free (/ 3 4.0)))))))

(test direction-reverse
  "row-reverse and column-reverse mirroring around content box."
  (let* ((a (%box :id :a :w 4 :h 2))
         (b (%box :id :b :w 6 :h 2))
         ;; ROW-REVERSE
         (r1 (%layout-root :dir :row-reverse
                           :root-styles '(:padding-left 1 :padding-right 1 :padding-top 1 :gap 1)
                           :children (list a b)
                           :parent-w 20 :parent-h 8))
         (a1 (%layout-rect-of (child-by-id r1 :a)))
         (b1 (%layout-rect-of (child-by-id r1 :b)))
         ;; COLUMN-REVERSE
         (r2 (%layout-root :dir :column-reverse
                           :root-styles '(:padding-left 1 :padding-top 1 :padding-bottom 1 :gap 1 :height 12)
                           :children (list (%box :id :c :w 4 :h 2)
                                           (%box :id :d :w 4 :h 3))
                           :parent-w 12 :parent-h 12))
         (c2 (%layout-rect-of (child-by-id r2 :c)))
         (d2 (%layout-rect-of (child-by-id r2 :d))))
    ;; For row-reverse: :a should appear to the LEFT of :b (mirrored), both within content box
    (is (< (x a1) (x b1)))
    ;; For column-reverse: :c above :d after mirroring (smaller y means closer to top)
    (is (< (y c2) (y d2)))))
;; (defun run-flex-tests () (run! :elmtui/flex))
                                        ; == end/flex-fiveam.lisp ==

;; (test justify-content-variants
;;   "Verify horizontal distribution strategies."
;;   (let* ((a (%box :id :a :w 5 :h 2))
;;          (b (%box :id :b :w 5 :h 2))
;;          (root-w 30)
;;          (pad 1)
;;          (gap 0)
;;          (free (- root-w pad pad 5 5))) ; content width minus items
;;     ;; flex-start
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :flex-start :gap gap)
;;                             :children (list a b) :parent-w root-w :parent-h 8)))
;;       (is (equal (%children-rects r) (list '(:a 1 1 5 2) '(:b 6 1 5 2)))))
;;     ;; flex-end
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :flex-end :gap gap)
;;                             :children (list (%box :id :a :w 5 :h 2)
;;                                             (%box :id :b :w 5 :h 2))
;;                             :parent-w root-w :parent-h 8)))
;;       (let* ((b-x (- (- root-w pad) 5))
;;              (a-x (- b-x 5)))
;;         (is (equal (%children-rects r) (list (list :a a-x 1 5 2) (list :b b-x 1 5 2))))))
;;     ;; center
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :center :gap gap)
;;                             :children (list (%box :id :a :w 5 :h 2)
;;                                             (%box :id :b :w 5 :h 2))
;;                             :parent-w root-w :parent-h 8)))
;;       (let* ((lead (/ free 2))
;;              (a-x (+ pad lead))
;;              (b-x (+ a-x 5)))
;;         (is (equal (%children-rects r) (list (list :a (round a-x) 1 5 2)
;;                                              (list :b (round b-x) 1 5 2))))))
;;     ;; space-between (two items → flush edges)
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :space-between :gap gap)
;;                             :children (list (%box :id :a :w 5 :h 2)
;;                                             (%box :id :b :w 5 :h 2))
;;                             :parent-w root-w :parent-h 8)))
;;       (let* ((a-x pad)
;;              (b-x (- (- root-w pad) 5)))
;;         (is (equal (%children-rects r) (list (list :a a-x 1 5 2)
;;                                              (list :b b-x 1 5 2))))))
;;     ;; space-around
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :space-around :gap gap)
;;                             :children (list (%box :id :a :w 5 :h 2)
;;                                             (%box :id :b :w 5 :h 2))
;;                             :parent-w root-w :parent-h 8)))
;;       (let* ((content (- root-w pad pad))
;;              (free (- content 10))
;;              (gap (/ free 2.0))        ; n=2 → around: each gets gap, leading is gap/2
;;              (a-x (+ pad (/ gap 2.0)))
;;              (b-x (+ a-x 5 gap)))
;;         (is-≈ (second (%rect->list (child-by-id r :a))) (round a-x))
;;         (is-≈ (second (%rect->list (child-by-id r :b))) (round b-x))))
;;     ;; space-evenly
;;     (let* ((r (%layout-root :dir :row
;;                             :root-styles (list :padding-left pad :padding-right pad
;;                                                :padding-top pad :justify-content :space-evenly :gap gap)
;;                             :children (list (%box :id :a :w 5 :h 2)
;;                                             (%box :id :b :w 5 :h 2))
;;                             :parent-w root-w :parent-h 8)))
;;       (let* ((content (- root-w pad pad))
;;              (free (- content 10))
;;              (gap (/ free 3.0))        ; n=2 → evenly: leading/between/trailing all = free/(n+1)
;;              (a-x (+ pad gap))
;;              (b-x (+ a-x 5 gap)))
;;         (is-≈ (second (%rect->list (child-by-id r :a))) (round a-x))
;;         (is-≈ (second (%rect->list (child-by-id r :b))) (round b-x))))))

;; (test align-items-and-self
;;   "Cross-axis alignment and align-self override."
;;   (let* ((a (%box :id :a :w 6 :h 2))
;;          (b (%box :id :b :w 6 :h 3))
;;          ;; root height 10, padding-top 1 → content height 9
;;          (r (%layout-root :dir :row
;;                           :root-styles '(:padding-top 1 :height 10 :align-items :center)
;;                           :children (list a (%add-style b :align-self :flex-end))
;;                           :parent-w 30 :parent-h 10)))
;;     (let* ((ar (%layout-rect-of (child-by-id r :a)))
;;            (br (%layout-rect-of (child-by-id r :b)))
;;            (content-top 1)
;;            (content-h 9))
;;       ;; center for :a
;;       (is-≈ (y ar) (round (+ content-top (/ (- content-h (h ar)) 2.0))))
;;       ;; flex-end for :b
;;       (is-≈ (y br) (round (+ content-top (- content-h (h br))))))))
;; == elmtui/tests/flex-wrap-fiveam.lisp ==
(uiop:define-package :elmtui.tests.flex-wrap
  (:use :cl :fiveam)
  (:import-from :elmtui.view.geo #:make-rectangle #:make-pos #:make-size #:x #:y #:w #:h)
  (:import-from :elmtui.view.base-elements
                #:container-element #:element-children #:element-style #:element-id)
  (:import-from :elmtui.view.element #:el/layout-rect)
  (:export #:run-wrap-tests))

(in-package :elmtui.tests.flex-wrap)

(defun %call-layout (root rect)
  (cond
    ((fboundp (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements))
     (funcall (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements) root rect))
    ((fboundp (intern "LAYOUT-NODE" :elmtui.view.layout))
     (funcall (intern "LAYOUT-NODE" :elmtui.view.layout) root rect nil))
    (t (error "No layout entrypoint."))))

(defun %box (&key id w h styles)
  (let ((n (make-instance 'container-element :id id :style (copy-list styles))))
    (when w (setf (element-style n) (append (list :width w) (element-style n))))
    (when h (setf (element-style n) (append (list :height h) (element-style n))))
    n))

(defun %root (&key dir wrap styles children pw ph)
  (let ((r (make-instance 'container-element :id :root
                                             :style (append (list :display :flex :flex-direction dir :flex-wrap wrap) styles))))
    (setf (element-children r) children)
    (%call-layout r (make-rectangle :pos (make-pos :x 0 :y 0)
                                    :size (make-size :w pw :h ph)))))

(defun %rect (node) (el/layout-rect node))
(defun %child (root id) (find id (element-children root) :key #'element-id))

(def-suite elmtui/flex-wrap
  :in elmtui.tests:elmtui-test
  )
(in-suite elmtui/flex-wrap)

(test wrap-breaks-lines-row
  (let* ((a (%box :id :a :w 9 :h 2))
         (b (%box :id :b :w 9 :h 2))
         (c (%box :id :c :w 9 :h 2))
         ;; content width 20 (pad-left=1 pad-right=1), gap=2
         (root (%root :dir :row :wrap :wrap
                      :styles '(:padding-left 1 :padding-right 1 :gap 2)
                      :children (list a b c) :pw 22 :ph 8)))
    ;; Expect: [A,B] on first line (1 + 9 + 2 + 9 = 21) fits, C wraps.
    (let ((ar (%rect (%child root :a)))
          (br (%rect (%child root :b)))
          (cr (%rect (%child root :c))))
      (is (= (y ar) (y br)))           ; same line
      (is (< (y ar) (y cr)))           ; C wrapped to next line
      (is (= (x ar) 1))                ; content-x
      (is (= (x br) (+ 1 9 2)))        ; A + gap
      (is (= (x cr) 1)))))

(test wrap-reverse-stacks-from-end
  (let* ((a (%box :id :a :w 9 :h 2))
         (b (%box :id :b :w 9 :h 2))
         (c (%box :id :c :w 9 :h 2))
         (root (%root :dir :row :wrap :wrap-reverse
                      :styles '(:padding-left 1 :padding-right 1 :gap 2 :align-content :flex-start)
                      :children (list a b c) :pw 22 :ph 10)))
    (let ((ar (%rect (%child root :a)))
          (cr (%rect (%child root :c))))
      ;; With wrap-reverse, the wrapped line (C) should be ABOVE the first line for row direction
      (is (< (y cr) (y ar))))))
