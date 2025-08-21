(uiop:define-package :elmtui.view.layout.flex
  (:use :cl)
  (:nicknames :et.flex)
  (:import-from :log4cl #:log-info #:log-warn #:log-error)
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:pos-x #:pos-y #:size-w #:size-h
                #:size #:pos
                #:make-rectangle #:make-pos #:make-size
                #:dx! #:dy!)
  (:import-from :elmtui.view.element
                #:el/children #:el/layout-rect #:el/styles-of
                #:el/props #:el/style #:el/content #:setf
                #:intrinsic-size-of )
  (:import-from :elmtui.view.base-elements
                #:copy-element
                #:base-element #:element-children #:element-style #:element-layout
                #:element-id)
  (:import-from :elmtui.view.layout.size-utils
                #:compute-layout
                #:content-rect-of
                #:measure-node-intrinsic-size)
  (:import-from :elmtui.view.api #:layout-node)
  (:export
   #:compute-flex-layout
   #:content-box))

(in-package :elmtui.view.layout.flex)
(defun %get-styles (node)
  (elmtui.view.element:el/styles node))

(defun style-value (node key &optional default)
  (let ((st (%get-styles node)))
    (cond
      ((hash-table-p st) (gethash key st default))
      ((listp st)        (getf st key default))
      (t default))))

(defun style-value* (node key &optional default)
  (let ((v (style-value node key :__missing__)))
    (if (eq v :__missing__)
        (case key
          (:flex-direction (or (style-value node :direction nil) default))
          (:justify-content (or (style-value node :justify nil) default))
          (:align-items    (or (style-value node :align nil) default))
          (t default))
        v)))

(defclass flex-item ()
  ((node :initarg :node :reader node-of)
   (rect :initarg :rect :accessor rect-of)
   (order :initarg :order :initform 0 :reader order-of)
   (grow :initarg :grow :initform 0.0 :reader grow-of)
   (children :initarg :children :initform nil :accessor children-of)
   (shrink :initarg :shrink :initform 1.0 :reader shrink-of)
   (basis-spec :initarg :basis-spec :initform :auto :reader basis-spec-of)
   (min-w :initarg :min-w :initform 0 :reader min-w-of)
   (max-w :initarg :max-w :initform most-positive-fixnum :reader max-w-of)
   (min-h :initarg :min-h :initform 0 :reader min-h-of)
   (max-h :initarg :max-h :initform most-positive-fixnum :reader max-h-of)
   (mt :initarg :mt :initform 0 :reader mt-of)
   (mr :initarg :mr :initform 0 :reader mr-of)
   (mb :initarg :mb :initform 0 :reader mb-of)
   (ml :initarg :ml :initform 0 :reader ml-of)
   (base-main :initform 0.0 :accessor base-main-of)
   (final-main :initform 0.0 :accessor final-main-of)
   (final-cross :initform 0.0 :accessor final-cross-of)))

(defun make-flex-item (node rect)
  (make-instance 'flex-item
                 :node node
                 :children
                 (when (el/children node)
                   (mapcar (lambda (c)
                             (let ((child-rect (or (el/layout-rect c)
                                                   (make-rectangle :pos (make-pos :x 0 :y 0)
                                                                   :size (make-size :w 0 :h 0)))))
                               (make-flex-item c child-rect)))
                           (el/children node)))
                 :rect rect
                 :order (style-value node :order 0)
                 :grow (coerce (style-value node :flex-grow 0) 'double-float)
                 :shrink (coerce (style-value node :flex-shrink 1) 'double-float)
                 :basis-spec (or (style-value node :flex-basis nil) :auto)
                 :min-w (style-value node :min-width 0)
                 :max-w (style-value node :max-width most-positive-fixnum)
                 :min-h (style-value node :min-height 0)
                 :max-h (style-value node :max-height most-positive-fixnum)
                 :mt (style-value node :margin-top 0)
                 :mr (style-value node :margin-right 0)
                 :mb (style-value node :margin-bottom 0)
                 :ml (style-value node :margin-left 0)))

(defun kw (v &optional default)
  (etypecase v
    (null (or default nil))
    (keyword v)
    (string (intern (string-upcase v) :keyword))
    (symbol (intern (string-upcase (symbol-name v)) :keyword))))

(defun parse-gap (styles direction)
  "Return (values main-gap cross-gap) from :gap/:row-gap/:column-gap per direction."
  (let* ((gap (getf styles :gap (getf styles :grid-gap 0)))
         (rg  (getf styles :row-gap gap))
         (cg  (getf styles :column-gap gap)))
    (ecase (kw direction :row)
      (:row (values cg rg))
      (:row-reverse (values cg rg))
      (:column (values rg cg))
      (:column-reverse (values rg cg)))))

(defun border-main (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (w (rect-of it)))
    ((:column :column-reverse) (h (rect-of it)))))

(defun border-cross (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (h (rect-of it)))
    ((:column :column-reverse) (w (rect-of it)))))

(defun set-border-main (it dir v)
  (ecase (kw dir :row)
    ((:row :row-reverse) (setf (w (rect-of it)) (round v)))
    ((:column :column-reverse) (setf (h (rect-of it)) (round v)))))

(defun set-border-cross (it dir v)
  (ecase (kw dir :row)
    ((:row :row-reverse) (setf (h (rect-of it)) (round v)))
    ((:column :column-reverse) (setf (w (rect-of it)) (round v)))))

(defun margin-main-start (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (ml-of it))
    ((:column :column-reverse) (mt-of it))))

(defun margin-main-end (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (mr-of it))
    ((:column :column-reverse) (mb-of it))))

(defun margin-cross-start (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (mt-of it))
    ((:column :column-reverse) (ml-of it))))

(defun margin-cross-end (it dir)
  (ecase (kw dir :row)
    ((:row :row-reverse) (mb-of it))
    ((:column :column-reverse) (mr-of it))))

(defun margin-box-main (it dir)
  (+ (margin-main-start it dir)
     (border-main it dir)
     (margin-main-end it dir)))

(defun margin-box-cross (it dir)
  (+ (margin-cross-start it dir)
     (border-cross it dir)
     (margin-cross-end it dir)))

(defun resolve-initial-bases! (items dir avail-main)
  (dolist (it items)
    (let* ((spec (basis-spec-of it))
           (base (cond
                   ((numberp spec) spec)
                   ((stringp spec)
                    (let ((len (length spec)))
                      (if (and (> len 1) (char= #\% (char spec (1- len))))
                          (* (/ (parse-integer spec :end (1- len)) 100.0) (max 0 avail-main))
                          0)))
                   ((eq spec :auto)
                    (multiple-value-bind (minw maxw minh maxh)
                        (measure-node-intrinsic-size (node-of it) avail-main avail-main)
                      (declare (ignore maxw maxh))
                      (ecase (kw dir :row)
                        ((:row :row-reverse)
                         (or (style-value (node-of it) :width nil) minw 0))
                        ((:column :column-reverse)
                         (or (style-value (node-of it) :height nil) minh 0)))))
                   (t 0))))
      (setf (base-main-of it)
            (ecase (kw dir :row)
              ((:row :row-reverse) (max (min-w-of it) (min base (max-w-of it))))
              ((:column :column-reverse) (max (min-h-of it) (min base (max-h-of it))))))
      (set-border-main it dir (base-main-of it)))))

(defun definite-cross-size-p (it dir)
  (let* ((node (node-of it)))
    (ecase (kw dir :row)
      ((:row :row-reverse)
       (let ((v (style-value node :height nil)))
         (and v (not (eql v :auto)) (numberp v))))
      ((:column :column-reverse)
       (let ((v (style-value node :width nil)))
         (and v (not (eql v :auto)) (numberp v)))))))

(defun resolve-initial-cross! (items dir)
  "If a child declares a definite cross size, seed its border-cross to that value."
  (dolist (it items)
    (let* ((node (node-of it)))
      (ecase (kw dir :row)
        ((:row :row-reverse)
         (let ((decl (style-value node :height nil)))
           (when (and decl (numberp decl))
             (set-border-cross it :row
                               (clamp decl (min-h-of it) (max-h-of it))))))
        ((:column :column-reverse)
         (let ((decl (style-value node :width nil)))
           (when (and decl (numberp decl))
             (set-border-cross it :column
                               (clamp decl (min-w-of it) (max-w-of it))))))))))


;;; ------------------------------------------------------------
;;; CHANGE: :stretch behavior in cross-axis alignment
;;; - stretch only if cross size is not definite
;;; - otherwise, keep current cross size and position like flex-start
;;; ------------------------------------------------------------




(defun resolve-flex-in-line! (line dir avail-main main-gap)
  (let* ((items (getf line :items))
         (n (length items)))
    (when (zerop n) (return-from resolve-flex-in-line!))
    (let* ((sum-margins (reduce #'+ items :key (lambda (it) (+ (margin-main-start it dir) (margin-main-end it dir))) :initial-value 0.0))
           (gaps-total (* (max 0 (1- n)) main-gap))
           (sum-basis (reduce #'+ items :key #'base-main-of :initial-value 0.0))
           (free-space (- (max 0 avail-main) sum-margins gaps-total sum-basis)))
      (cond
        ((> free-space 0)
         (let ((total-grow (reduce #'+ items :key #'grow-of :initial-value 0.0)))
           (when (> total-grow 0)
             (dolist (it items)
               (incf (base-main-of it) (* free-space (/ (grow-of it) total-grow)))))))
        ((< free-space 0)
         (let* ((weighted-shrinks (mapcar (lambda (it) (* (shrink-of it) (base-main-of it))) items))
                (total-shrink (reduce #'+ weighted-shrinks :initial-value 0.0)))
           (when (> total-shrink 0)
             (loop for it in items
                   for weighted-shrink in weighted-shrinks
                   do (decf (base-main-of it) (* (- free-space) (/ weighted-shrink total-shrink))))))))
      (dolist (it items)
        (setf (final-main-of it)
              (ecase (kw dir :row)
                ((:row :row-reverse) (max (min-w-of it) (min (base-main-of it) (max-w-of it))))
                ((:column :column-reverse) (max (min-h-of it) (min (base-main-of it) (max-h-of it))))))
        (set-border-main it dir (final-main-of it))))))

(defun mirror-main-for-reverse! (lines dir content-start content-size)
  (when (member (kw dir :row) '(:row-reverse :column-reverse))
    (dolist (ln lines)
      (dolist (it (getf ln :items))
        (ecase (kw dir :row)
          (:row-reverse
           (let* ((left (x (rect-of it)))
                  (margin-box (margin-box-main it :row))
                  (right (+ left margin-box))
                  (new-left (+ content-start (- content-size right))))
             (setf (x (rect-of it)) (round (+ new-left (margin-main-start it :row))))))
          (:column-reverse
           (let* ((top (y (rect-of it)))
                  (margin-box (margin-box-main it :column))
                  (bottom (+ top margin-box))
                  (new-top (+ content-start (- content-size bottom))))
             (setf (y (rect-of it)) (round (+ new-top (margin-main-start it :column)))))))))))

;; (defun commit-and-recurse! (items container-styles)
;;   (declare (ignore container-styles))
;;   (log-info "C&R!")
;;   (mapcar (lambda (it)
;;             (let ((node (node-of it)))
;;               (setf (el/layout-rect node) (rect-of it))

;;               node))
;;           items))
(defun %layout-child (child child-rect)
  "Dispatch layout for CHILD given its rect. Falls back gracefully if APIs differ."
  (setf (el/layout-rect child) child-rect)
  ;; Try base-elements:compute-layout first
  (cond
    ((and (find-package :elmtui.view.base-elements)
          (fboundp (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements)))
     (funcall (intern "COMPUTE-LAYOUT" :elmtui.view.base-elements)
              child child-rect))
    ;; Fallback to view.layout:layout-node if exported
    ((and (find-package :elmtui.view.layout)
          (fboundp (intern "LAYOUT-NODE" :elmtui.view.layout)))
     (funcall (intern "LAYOUT-NODE" :elmtui.view.layout)
              child child-rect nil))
    ;; Otherwise just return child with rect set
    (t child)))

;; (defun commit-and-recurse! (items container-styles)
;;   "Write the computed rectangles back and recurse so nested containers layout, too."
;;   (declare (ignore container-styles))
;;   (mapcar (lambda (it)
;;             (let* ((node (node-of it))
;;                    (rect (rect-of it)))
;;               ;; Always set child's rect
;;               (setf (el/layout-rect node) rect)
;;               ;; If child has its own children or declares a display, lay it out now.
;;               (if (or (el/children node)
;;                       (style-value node :display nil)
;;                       (style-value node :flex-direction nil)
;;                       (style-value node :direction nil))
;;                   (%layout-child node rect)
;;                   (progn
;;                     (log-info "Node Resulting: ~A : ~A" node (el/layout-rect node))
;;                     node))))
;;           items))

;; (defun style-value (node key &optional default)
;;   (let ((st (elmtui.view.element:el/styles node)))
;;     (cond
;;       ((hash-table-p st) (gethash key st default))
;;       ((listp st)        (getf st key default))
;;       (t                 default))))

;; (defun style-value* (node key &optional default)
;;   (let ((v (style-value node key :__missing__)))
;;     (if (eq v :__missing__)
;;         (case key
;;           (:flex-direction (or (style-value node :direction nil) default))
;;           (:justify-content (or (style-value node :justify nil) default))
;;           (:align-items    (or (style-value node :align nil) default))
;;           (t default))
;;         v)))

(defun px-or (v fallback)
  (if (or (null v) (eql v :auto)) fallback v))

(defun margins (node)
  (let ((m (style-value node :margin 0)))
    (values (style-value node :margin-top m)
            (style-value node :margin-right m)
            (style-value node :margin-bottom m)
            (style-value node :margin-left m))))

(defun paddings (node)
  (let ((p (style-value node :padding 0)))
    (values (style-value node :padding-top p)
            (style-value node :padding-right p)
            (style-value node :padding-bottom p)
            (style-value node :padding-left p))))

;; (defun content-box (outer-rect node)
;;   (multiple-value-bind (mt mr mb ml) (margins node)
;;     (declare (ignore mt mr mb ml)))
;;   (multiple-value-bind (pt pr pb pl) (paddings node)
;;     (let* ((pos (pos outer-rect))
;;            (size (size outer-rect))
;;            (cw (max 0 (- (size-w size) (+ pl pr))))
;;            (ch (max 0 (- (size-h size) (+ pt pb))))
;;            (cx (+ (pos-x pos) pl))
;;            (cy (+ (pos-y pos) pt)))
;;       (make-rectangle :pos (make-pos :x cx :y cy)
;;                       :size (make-size :w cw :h ch)))))

(defun axis-and-cross (node)
  (let* ((dir (style-value* node :flex-direction :row)))
    (values (if (eql dir :column) :y :x)
            (if (eql dir :column) :x :y)
            dir)))

(defun size->main (size main-axis)
  (ecase main-axis
    (:x (size-w size))
    (:y (size-h size))))

(defun size->cross (size main-axis)
  (ecase main-axis
    (:x (size-h size))
    (:y (size-w size))))

(defun make-size-main-cross (main cross main-axis)
  (if (eql main-axis :x)
      (make-size :w main :h cross)
      (make-size :w cross :h main)))

(defun rect-with (rect &key x y w h)
  (let* ((pos (pos rect))
         (size (size rect)))
    (make-rectangle :pos (make-pos :x (or x (pos-x pos))
                                   :y (or y (pos-y pos)))
                    :size (make-size :w (or w (size-w size))
                                     :h (or h (size-h size))))))

(defun clamp (v lo hi) (max lo (min v hi)))

;; 1) collect-lines: don't add main-gap before the first item

;; FIX 1: first-item gap accounting
;; (defun collect-lines (items dir avail-main main-gap)
;;   (let ((sorted (sort (copy-list items) #'< :key #'order-of))
;;         (lines '())
;;         (current-items '())
;;         (current-main 0.0)
;;         (current-cross 0.0))
;;     (labels ((flush-line ()
;;                (when current-items
;;                  (let ((main-used (+ current-main (max 0 (* main-gap (1- (length current-items)))))))
;;                    (push (list :items (nreverse current-items)
;;                                :main-used main-used
;;                                :cross-max current-cross)
;;                          lines)))
;;                (setf current-items nil current-main 0.0 current-cross 0.0)))
;;       (dolist (it sorted)
;;         (let ((item-main (margin-box-main it dir))
;;               (item-cross (margin-box-cross it dir)))
;;           (if (and current-items (> (+ current-main item-main main-gap) avail-main))
;;               (progn
;;                 (flush-line)
;;                 (setf current-items (list it)
;;                       current-main item-main
;;                       current-cross (max current-cross item-cross)))
;;               (progn
;;                 (if (null current-items)
;;                     (incf current-main item-main)               ; first item: no gap
;;                     (incf current-main (+ item-main main-gap))) ; subsequent: add gap
;;                 (push it current-items)
;;                 (setf current-cross (max current-cross item-cross))))))
;;       (flush-line)
;;       (nreverse lines))))

;; FIX 2: add content-start to main-axis placement
;; (defun justify-line! (line dir avail-main main-gap justify-content reversep content-start)
;;   (let* ((items (copy-list (getf line :items)))
;;          (n (length items)))
;;     (when reversep (setf items (nreverse items)))
;;     (when (zerop n) (return-from justify-line!))
;;     (let* ((sum-margins (reduce #'+ items
;;                                 :key (lambda (it)
;;                                        (+ (margin-main-start it dir) (margin-main-end it dir)))
;;                                 :initial-value 0.0))
;;            (sum-main (reduce #'+ items :key #'final-main-of :initial-value 0.0))
;;            (fixed-gaps (* (max 0 (1- n)) main-gap))
;;            (used-space (+ sum-margins sum-main fixed-gaps))
;;            (free-space (max 0 (- avail-main used-space)))
;;            (leading-space 0.0) (extra-gap 0.0))
;;       (ecase (kw justify-content :flex-start)
;;         (:flex-start (setf leading-space 0.0 extra-gap 0.0))
;;         (:flex-end (setf leading-space free-space extra-gap 0.0))
;;         (:center (setf leading-space (/ free-space 2.0) extra-gap 0.0))
;;         (:space-between (setf leading-space 0.0 extra-gap (if (> n 1) (/ free-space (1- n)) 0.0)))
;;         (:space-around (let ((gap (/ free-space n)))
;;                          (setf leading-space (/ gap 2.0) extra-gap gap)))
;;         (:space-evenly (let ((gap (/ free-space (1+ n))))
;;                          (setf leading-space gap extra-gap gap))))
;;       (let ((cursor (+ content-start leading-space)))
;;         (dolist (it items)
;;           (let ((pos (+ cursor (margin-main-start it dir))))
;;             (ecase (kw dir :row)
;;               ((:row :row-reverse) (setf (x (rect-of it)) (round pos)))
;;               ((:column :column-reverse) (setf (y (rect-of it)) (round pos)))))
;;           (incf cursor (+ (final-main-of it)
;;                           (margin-main-end it dir)
;;                           main-gap
;;                           extra-gap)))))))

;; FIX 3: add content-cross-start to cross-axis placement
;; (defun align-lines-and-items! (lines container dir avail-cross cross-gap content-cross-start)
;;   (let* ((align-content (kw (style-value container :align-content :stretch) :stretch))
;;          (align-items (kw (style-value container :align-items :stretch) :stretch))
;;          (num-lines (length lines)))
;;     (when (zerop num-lines) (return-from align-lines-and-items!))
;;     (let* ((sum-cross (reduce #'+ lines :key (lambda (ln) (getf ln :cross-max)) :initial-value 0.0))
;;            (fixed-gaps (* (max 0 (1- num-lines)) cross-gap))
;;            (used-space (+ sum-cross fixed-gaps))
;;            (free-space (max 0 (- avail-cross used-space)))
;;            (leading-space 0.0) (between-space 0.0))
;;       (ecase align-content
;;         (:flex-start (setf leading-space 0.0 between-space 0.0))
;;         (:flex-end (setf leading-space free-space between-space 0.0))
;;         (:center (setf leading-space (/ free-space 2.0) between-space 0.0))
;;         (:space-between (setf leading-space 0.0 between-space (if (> num-lines 1) (/ free-space (1- num-lines)) 0.0)))
;;         (:space-around (let ((gap (/ free-space num-lines)))
;;                          (setf leading-space (/ gap 2.0) between-space gap)))
;;         (:space-evenly (let ((gap (/ free-space (1+ num-lines))))
;;                          (setf leading-space gap between-space gap)))
;;         (:stretch (when (> free-space 0)
;;                     (let ((add (/ free-space num-lines)))
;;                       (dolist (ln lines)
;;                         (incf (getf ln :cross-max) add))))))
;;       (let ((line-cursor (+ content-cross-start leading-space)))
;;         (dolist (ln lines)
;;           (let* ((line-cross-size (getf ln :cross-max)))
;;             (dolist (it (getf ln :items))
;;               (let* ((align-self (kw (or (style-value (node-of it) :align-self nil) align-items) :stretch))
;;                      (margin-start (margin-cross-start it dir))
;;                      (margin-end (margin-cross-end it dir))
;;                      (line-space (max 0 (- line-cross-size margin-start margin-end)))
;;                      (current-cross-size (border-cross it dir)))
;;                 (ecase align-self
;;                   (:stretch
;;                    (set-border-cross it dir line-space)
;;                    (setf (final-cross-of it) line-space)
;;                    (ecase (kw dir :row)
;;                      ((:row :row-reverse) (setf (y (rect-of it)) (round (+ line-cursor margin-start))))
;;                      ((:column :column-reverse) (setf (x (rect-of it)) (round (+ line-cursor margin-start))))))
;;                   (:flex-start
;;                    (ecase (kw dir :row)
;;                      ((:row :row-reverse) (setf (y (rect-of it)) (round (+ line-cursor margin-start))))
;;                      ((:column :column-reverse) (setf (x (rect-of it)) (round (+ line-cursor margin-start))))))
;;                   (:flex-end
;;                    (ecase (kw dir :row)
;;                      ((:row :row-reverse)
;;                       (setf (y (rect-of it)) (round (+ line-cursor (- line-cross-size current-cross-size margin-end)))))
;;                      ((:column :column-reverse)
;;                       (setf (x (rect-of it)) (round (+ line-cursor (- line-cross-size current-cross-size margin-end)))))))
;;                   (:center
;;                    (let ((offset (/ (- line-space current-cross-size) 2.0)))
;;                      (ecase (kw dir :row)
;;                        ((:row :row-reverse) (setf (y (rect-of it)) (round (+ line-cursor margin-start offset))))
;;                        ((:column :column-reverse) (setf (x (rect-of it)) (round (+ line-cursor margin-start offset))))))))))
;;             (incf line-cursor line-cross-size)
;;             (incf line-cursor between-space)))))))




;;; ---------- bugfix: do NOT reverse here; mirroring handles reverse dirs ---

(defun justify-line! (line dir avail-main main-gap justify-content content-start)
  (let* ((items (getf line :items))
         (n (length items)))
    (when (zerop n) (return-from justify-line!))
    (let* ((sum-margins (reduce #'+ items
                                :key (lambda (it)
                                       (+ (margin-main-start it dir)
                                          (margin-main-end it dir)))
                                :initial-value 0.0))
           (sum-main (reduce #'+ items :key #'final-main-of :initial-value 0.0))
           (fixed-gaps (* (max 0 (1- n)) main-gap))
           (used-space (+ sum-margins sum-main fixed-gaps))
           (free-space (max 0 (- avail-main used-space)))
           (leading-space 0.0) (extra-gap 0.0))
      (ecase (kw justify-content :flex-start)
        (:flex-start (setf leading-space 0.0 extra-gap 0.0))
        (:flex-end   (setf leading-space free-space extra-gap 0.0))
        (:center     (setf leading-space (/ free-space 2.0) extra-gap 0.0))
        (:space-between (setf leading-space 0.0
                              extra-gap (if (> n 1) (/ free-space (1- n)) 0.0)))
        (:space-around (let ((gap (/ free-space n)))
                         (setf leading-space (/ gap 2.0) extra-gap gap)))
        (:space-evenly (let ((gap (/ free-space (1+ n))))
                         (setf leading-space gap extra-gap gap))))
      (let ((cursor (+ content-start leading-space)))
        (dolist (it items)
          (let ((pos (+ cursor (margin-main-start it dir))))
            (ecase (kw dir :row)
              ((:row :row-reverse) (setf (x (rect-of it)) (round pos)))
              ((:column :column-reverse) (setf (y (rect-of it)) (round pos)))))
          (incf cursor (+ (final-main-of it)
                          (margin-main-end it dir)
                          main-gap
                          extra-gap)))))))

;;; ---------- commit: preserve sizes; recurse only when needed --------------

;; (defun %child-display (node)
;;   (kw (style-value node :display :block) :block))

;; (defun commit-and-recurse! (items container-styles)
;;   (declare (ignore container-styles))
;;   (mapcar (lambda (it)
;;             (let* ((node (node-of it))
;;                    (rect (rect-of it)))
;;               ;; 1) Write the rect computed by flex (do NOT let block override it).
;;               (setf (el/layout-rect node) rect)
;;               ;; 2) Only recurse for layouting nested content when node is a layout container.
;;               (case (%child-display node)
;;                 (:flex
;;                  ;; Let the flex engine layout this child's subtree within its rect.
;;                  (compute-flex-layout node rect nil))
;;                 (:grid
;;                  (elmtui.view.layout.grid:layout-grid-container-impl node rect))
;;                 (t
;;                  ;; For block children: do nothing here. The core fallback
;;                  ;; (dispatch-layout in core.lisp) will translate/offset their children
;;                  ;; when/if someone asks it to layout them. This prevents width/height
;;                  ;; clobbering that caused 0-width & full cross-size.
;;                  node))))
;;           items))
(defun content-box (outer-rect node)
  "Content box = outer minus paddings; margins are external."
  (multiple-value-bind (pt pr pb pl)
      (let* ((p (style-value node :padding 0)))
        (values (style-value node :padding-top p)
                (style-value node :padding-right p)
                (style-value node :padding-bottom p)
                (style-value node :padding-left p)))
    (declare (ignore pt pr pb pl))
    (let* ((cx (+ (x outer-rect) (style-value node :padding-left 0)))
           (cy (+ (y outer-rect) (style-value node :padding-top 0)))
           (cw (max 0 (- (w outer-rect)
                         (+ (style-value node :padding-left 0)
                            (style-value node :padding-right 0)))))
           (ch (max 0 (- (h outer-rect)
                         (+ (style-value node :padding-top 0)
                            (style-value node :padding-bottom 0))))))
      (make-rectangle :pos (make-pos :x cx :y cy)
                      :size (make-size :w cw :h ch)))))

(defun %translate-children-into-content! (node)
  "Translate immediate children into NODE’s content origin (no re-sizing)."
  (let* ((outer (el/layout-rect node))
         (content (content-box outer node))
         (ox (x content)) (oy (y content)))
    (dolist (gc (el/children node))
      (let ((r (or (el/layout-rect gc)
                   (make-rectangle :pos (make-pos :x 0 :y 0)
                                   :size (make-size :w 0 :h 0)))))
        (setf (el/layout-rect gc)
              (make-rectangle
               :pos  (make-pos :x (+ ox (x r)) :y (+ oy (y r)))
               :size (make-size :w (w r) :h (h r))))))))

(defun %child-display (node)
  (kw (style-value node :display :block) :block))

(defun commit-and-recurse! (items _container-styles)
  (declare (ignore _container-styles))
  (mapcar (lambda (it)
            (let* ((node (node-of it))
                   (rect (rect-of it)))
              (setf (el/layout-rect node) rect)
              (ecase (%child-display node)
                (:flex
                 (compute-layout :flex node rect))
                (:grid
                 (compute-layout :grid node rect))
                (:block
                    ;; do not rescale; just translate grandchildren into content box now
                    (%translate-children-into-content! node)
                  node))))

          items)
  ;; after commit-and-recurse!


  )
;;; ---------- top-level: mirror ONLY once for reverse directions ------------

;; == elmtui/src/view/layout/flex.lisp ==
;;; Flexbox: add :flex-wrap ( :nowrap | :wrap | :wrap-reverse )
;;; - Multi-line rows/columns with :gap handling
;;; - align-content across lines
;;; - wrap-reverse mirrors lines over the cross-axis content box


;;; ------------------------------------------------------------
;;; helpers already in your file (assumed present):
;;;   kw, style-value, style-value*, margin-* helpers,
;;;   border-main/cross, set-border-main/cross,
;;;   margin-box-main, margin-box-cross,
;;;   resolve-initial-bases!, resolve-flex-in-line!,
;;;   justify-line!, align-lines-and-items!,
;;;   commit-and-recurse!, content-box, clamp, etc.
;;; ------------------------------------------------------------

;;; NEW: collect-lines with wrap awareness
(defun collect-lines (items dir avail-main main-gap wrap-mode)
  "Return a list of line plists:
     (:items items-in-line :main-used used-main-without-trailing-gap :cross-max max-cross)
   If WRAP-MODE is :nowrap, everything goes into a single line and we never flush."
  (let ((sorted (sort (copy-list items) #'< :key #'order-of))
        (lines '())
        (current-items '())
        (current-main 0.0)
        (current-cross 0.0))
    (labels ((flush-line ()
               (when current-items
                 (let ((main-used (+ current-main (max 0 (* main-gap (1- (length current-items)))))))
                   (push (list :items (nreverse current-items)
                               :main-used main-used
                               :cross-max current-cross)
                         lines)))
               (setf current-items nil current-main 0.0 current-cross 0.0))
             (would-overflow-p (add-main)
               (and (not (eql (kw wrap-mode :nowrap) :nowrap))
                    (plusp (length current-items))
                    (> (+ current-main add-main main-gap) (max 0 avail-main)))))
      (dolist (it sorted)
        (let ((item-main (margin-box-main it dir))
              (item-cross (margin-box-cross it dir)))
          (if (would-overflow-p item-main)
              (progn
                (flush-line)
                (setf current-items (list it)
                      current-main item-main
                      current-cross (max current-cross item-cross)))
              (progn
                ;; first child in line: no leading gap
                (if (null current-items)
                    (incf current-main item-main)
                    (incf current-main (+ item-main main-gap)))
                (push it current-items)
                (setf current-cross (max current-cross item-cross))))))
      (flush-line)
      (nreverse lines))))

;;; NEW: mirror over the CROSS axis (for wrap-reverse)
(defun mirror-cross-for-wrap-reverse! (lines dir content-start content-size)
  "Mirror positions along the cross axis within [content-start, content-start+content-size]."
  (dolist (ln lines)
    (dolist (it (getf ln :items))
      (ecase (kw dir :row)
        (:row
         (let* ((top (y (rect-of it)))
                (mbox (margin-box-cross it :row))
                (bottom (+ top mbox))
                (new-top (+ content-start (- content-size bottom))))
           (setf (y (rect-of it)) (round (+ new-top (margin-cross-start it :row))))))
        (:row-reverse
         (let* ((top (y (rect-of it)))
                (mbox (margin-box-cross it :row))
                (bottom (+ top mbox))
                (new-top (+ content-start (- content-size bottom))))
           (setf (y (rect-of it)) (round (+ new-top (margin-cross-start it :row))))))
        (:column
         (let* ((left (x (rect-of it)))
                (mbox (margin-box-cross it :column))
                (right (+ left mbox))
                (new-left (+ content-start (- content-size right))))
           (setf (x (rect-of it)) (round (+ new-left (margin-cross-start it :column))))))
        (:column-reverse
         (let* ((left (x (rect-of it)))
                (mbox (margin-box-cross it :column))
                (right (+ left mbox))
                (new-left (+ content-start (- content-size right))))
           (setf (x (rect-of it)) (round (+ new-left (margin-cross-start it :column))))))))))

;;; CHANGE: align-lines-and-items! — extend signature with WRAP-MODE
(defun align-lines-and-items! (lines container dir avail-cross cross-gap content-cross-start)
  "Place lines along cross axis according to align-content, then align items per align-items/align-self.
   WRAP-MODE affects only the stacking direction of lines; if :wrap-reverse, we stack normally
   then mirror across cross axis (done in compute-flex-layout after this call)."
  (let* ((align-content (kw (style-value container :align-content :stretch) :stretch))
         (align-items   (kw (style-value container :align-items   :stretch) :stretch))
         (num-lines (length lines)))
    (when (zerop num-lines) (return-from align-lines-and-items!))
    (let* ((sum-cross (reduce #'+ lines :key (lambda (ln) (getf ln :cross-max)) :initial-value 0.0))
           (fixed-gaps (* (max 0 (1- num-lines)) cross-gap))
           (used-space (+ sum-cross fixed-gaps))
           (free-space (max 0 (- avail-cross used-space)))
           (leading-space 0.0) (between-space 0.0))
      (ecase align-content
        (:flex-start   (setf leading-space 0.0 between-space 0.0))
        (:flex-end     (setf leading-space free-space between-space 0.0))
        (:center       (setf leading-space (/ free-space 2.0) between-space 0.0))
        (:space-between(setf leading-space 0.0 between-space (if (> num-lines 1) (/ free-space (1- num-lines)) 0.0)))
        (:space-around (let ((gap (/ free-space num-lines)))
                         (setf leading-space (/ gap 2.0) between-space gap)))
        (:space-evenly (let ((gap (/ free-space (1+ num-lines))))
                         (setf leading-space gap between-space gap)))
        (:stretch      (when (> free-space 0)
                         (let ((add (/ free-space num-lines)))
                           (dolist (ln lines)
                             (incf (getf ln :cross-max) add))))))
      ;; NOTE on wrap-reverse:
      ;; We still place lines from cross-start; mirroring is applied afterwards.
      (let ((line-cursor (+ content-cross-start leading-space)))
        (dolist (ln lines)
          (let* ((line-cross-size (getf ln :cross-max)))
            (dolist (it (getf ln :items))
              (let* ((align-self (kw (or (style-value (node-of it) :align-self nil) align-items) :stretch))
                     (margin-start (margin-cross-start it dir))
                     (margin-end   (margin-cross-end   it dir))
                     (line-space (max 0 (- line-cross-size margin-start margin-end)))
                     (current-cross-size (border-cross it dir)))
                (ecase align-self
                  (:stretch
                   ;; only stretch when cross size isn't definite (per earlier fix)
                   (if (definite-cross-size-p it dir)
                       (ecase (kw dir :row)
                         ((:row :row-reverse)
                          (setf (y (rect-of it)) (round (+ line-cursor margin-start)))
                          (setf (final-cross-of it) current-cross-size))
                         ((:column :column-reverse)
                          (setf (x (rect-of it)) (round (+ line-cursor margin-start)))
                          (setf (final-cross-of it) current-cross-size)))
                       (progn
                         (set-border-cross it dir line-space)
                         (setf (final-cross-of it) line-space)
                         (ecase (kw dir :row)
                           ((:row :row-reverse)
                            (setf (y (rect-of it)) (round (+ line-cursor margin-start))))
                           ((:column :column-reverse)
                            (setf (x (rect-of it)) (round (+ line-cursor margin-start))))))))
                  (:flex-start
                   (ecase (kw dir :row)
                     ((:row :row-reverse)
                      (setf (y (rect-of it)) (round (+ line-cursor margin-start))))
                     ((:column :column-reverse)
                      (setf (x (rect-of it)) (round (+ line-cursor margin-start))))))
                  (:flex-end
                   (ecase (kw dir :row)
                     ((:row :row-reverse)
                      (setf (y (rect-of it)) (round (+ line-cursor (- line-cross-size current-cross-size margin-end)))))
                     ((:column :column-reverse)
                      (setf (x (rect-of it)) (round (+ line-cursor (- line-cross-size current-cross-size margin-end)))))))
                  (:center
                   (let ((offset (/ (- line-space current-cross-size) 2.0)))
                     (ecase (kw dir :row)
                       ((:row :row-reverse)
                        (setf (y (rect-of it)) (round (+ line-cursor margin-start offset))))
                       ((:column :column-reverse)
                        (setf (x (rect-of it)) (round (+ line-cursor margin-start offset))))))))))
            (incf line-cursor line-cross-size)
            (incf line-cursor between-space)))))))

;;; CHANGE: compute-flex-layout — thread wrap-mode and cross-mirroring
(defun compute-flex-layout (container-node &optional given-rect parent-style-set)
  (declare (ignore parent-style-set))
  (unless (typep container-node 'base-element)
    (return-from compute-flex-layout nil))

                                        ; in compute-flex-layout (flex)

  (let* ((styles (or (ignore-errors (elmtui.view.element:el/styles container-node))
                     (ignore-errors (element-style container-node))))
         (dir (kw (style-value container-node :flex-direction :row) :row))
         (wrap-mode (kw (style-value container-node :flex-wrap :nowrap) :nowrap))
         (outer-rect (or given-rect
                         (el/layout-rect container-node)
                         (make-rectangle :pos (make-pos :x 0 :y 0)
                                         :size (make-size :w 0 :h 0))))
         (content-rect (content-box outer-rect container-node))
         (content-x (x content-rect))
         (content-y (y content-rect))
         (avail-main (ecase dir
                       ((:row :row-reverse) (w content-rect))
                       ((:column :column-reverse) (h content-rect))))
         (avail-cross (ecase dir
                        ((:row :row-reverse) (h content-rect))
                        ((:column :column-reverse) (w content-rect))))
         (children (el/children container-node))
         (items (mapcar (lambda (n)
                          (let* ((r (or (el/layout-rect n)
                                        (make-rectangle :pos (make-pos :x content-x :y content-y)
                                                        :size (make-size :w 0 :h 0)))))
                            (make-flex-item n r)))
                        children))
         (justify-content (kw (style-value container-node :justify-content :flex-start) :flex-start))
         (main-gap 0) (cross-gap 0))
    (multiple-value-setq (main-gap cross-gap) (parse-gap styles dir))
    ;; 1) main bases + seed cross (explicit :height/:width)
    (resolve-initial-bases! items dir avail-main)
    (resolve-initial-cross!  items dir)
    ;; 2) line breaking with wrap
    (let ((lines (collect-lines items dir avail-main main-gap wrap-mode)))
      ;; 3) flexing within line
      (dolist (ln lines)
        (resolve-flex-in-line! ln dir avail-main main-gap))
      ;; 4) main-axis placement (per line)
      (dolist (ln lines)
        (justify-line! ln dir avail-main main-gap justify-content
                       (ecase dir
                         ((:row :row-reverse) content-x)
                         ((:column :column-reverse) content-y))))
      ;; 5) cross-axis placement (lines + items)
      (align-lines-and-items! lines container-node dir avail-cross cross-gap
                              (ecase dir
                                ((:row :row-reverse) content-y)
                                ((:column :column-reverse) content-x)))
      ;; 6) main reverse (row-reverse/column-reverse) — mirror on main axis
      (ecase dir
        (:row           nil)
        (:column        nil)
        (:row-reverse   (mirror-main-for-reverse! lines :row content-x (w content-rect)))
        (:column-reverse(mirror-main-for-reverse! lines :column content-y (h content-rect))))
      ;; 7) wrap-reverse — mirror on cross axis
      (when (eql wrap-mode :wrap-reverse)
        (ecase dir
          ((:row :row-reverse)
           (mirror-cross-for-wrap-reverse! lines dir content-y (h content-rect)))
          ((:column :column-reverse)
           (mirror-cross-for-wrap-reverse! lines dir content-x (w content-rect)))))
      ;; 8) commit & recurse (your existing function)
      (let* ((laid-out-children (commit-and-recurse! items styles))
             (new-container (copy-element container-node )))
        (dolist (it items)
          (when (or (zerop (elmtui.view.geo:w (rect-of it)))
                    (zerop (elmtui.view.geo:h (rect-of it))))
            (log:warn "flex item ~S ended with zero size: ~A"
                      (ignore-errors (elmtui.view.base-elements:element-id (node-of it)))
                      (rect-of it))))
        (setf (elmtui.view.element:el/children new-container) laid-out-children)
        (setf (el/layout-rect new-container) outer-rect)
        (log-info "flex ~A dir=~A outer=~S content=~S"
                  (elmtui.view.base-elements:element-id container-node) dir
                  (list (x outer-rect) (y outer-rect) (w outer-rect) (h outer-rect))
                  (list (x content-rect) (y content-rect) (w content-rect) (h content-rect)))
        new-container))))
;; == end/flex.lisp ==

;;; --- recurse to layout children ------------------------------------------

(defmethod compute-layout ((style (eql :flex)) node rect &key (parent-styles nil) &allow-other-keys)
  (compute-flex-layout node rect parent-styles))
