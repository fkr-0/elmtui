(uiop:define-package :elmtui.view.layout.grid
  (:use :cl)
  (:nicknames :et.grid)
  (:import-from :elmtui.view.base-elements #:copy-element
                #:base-element #:element-children #:element-style #:element-id #:element-layout)
  (:import-from :elmtui.view.element :el/styles-of #:el/layout-rect)
  (:import-from :elmtui.view.api
                #:layout-node )
  (:import-from :elmtui.view.geo
                #:rectangle #:pos #:size #:h #:w #:x #:y
                #:make-rectangle #:make-pos #:make-size #:copy-rectangle)
  (:import-from :elmtui.view.layout.size-utils
                #:compute-layout
                #:content-rect-of ;; #:%copy-el
                #:measure-node-intrinsic-size)
  (:import-from :elmtui.utils
                #:ensure-list
                #:trim-string
                #:blank-string-p
                #:split-string-literal)
  (:export
   #:compute-grid-layout))

(in-package :elmtui.view.layout.grid)

(defstruct grid-track
  index type definition base-size fr-units growth-limit is-flexible items
  min-contribution max-contribution final-size)

(defstruct (grid-item (:constructor %make-grid-item))
  node id raw-col-start raw-col-end raw-row-start raw-row-end
  col-start col-end row-start row-end col-span row-span placed-p
  min-content-width max-content-width min-content-height max-content-height
  align-self justify-self)

(defun make-grid-item (&rest args)
  (apply #'%make-grid-item args))

(defun parse-grid-template-areas (areas-string-list)
  (let ((area-map (make-hash-table :test 'equal))
        (row-idx 0))
    (dolist (row-str areas-string-list)
      (let ((col-idx 0)
            (tokens (uiop:split-string row-str :separator " ")))
        (dolist (token tokens)
          (unless (string= token ".")
            (let ((existing (gethash token area-map)))
              (if existing
                  (progn
                    (setf (getf existing :row-end) (max (getf existing :row-end) (1+ row-idx)))
                    (setf (getf existing :col-end) (max (getf existing :col-end) (1+ col-idx))))
                  (setf (gethash token area-map)
                        (list :name token
                              :row-start row-idx :col-start col-idx
                              :row-end (1+ row-idx) :col-end (1+ col-idx))))))
          (incf col-idx))
        (incf row-idx)))
    area-map))

(defun update-item-intrinsic-dimensions (grid-item c-avail-w c-avail-h)
  (multiple-value-bind (min-w max-w min-h max-h)
      (measure-node-intrinsic-size (grid-item-node grid-item) c-avail-w c-avail-h)
    (setf (grid-item-min-content-width grid-item) min-w
          (grid-item-max-content-width grid-item) max-w
          (grid-item-min-content-height grid-item) min-h
          (grid-item-max-content-height grid-item) max-h))
  grid-item)

(defun kw (x)
  (etypecase x
    (keyword x)
    (string (intern (string-upcase x) :keyword))
    (null nil)
    (symbol (intern (string-upcase (symbol-name x)) :keyword))))

(defun normalize-gap (styles)
  (let* ((gap (or (el/styles-of styles :gap nil) (el/styles-of styles :grid-gap nil)))
         (rg (or (el/styles-of styles :row-gap nil) (el/styles-of styles :grid-row-gap nil) gap 0))
         (cg (or (el/styles-of styles :column-gap nil) (el/styles-of styles :grid-column-gap nil) gap 0)))
    (values (or rg 0) (or cg 0))))

(defun %decimal-number-string-p (value)
  (let ((dot (position #\. value)))
    (and (plusp (length value))
         (if dot
             (and (> dot 0)
                  (< dot (1- (length value)))
                  (null (position #\. value :start (1+ dot)))
                  (every #'digit-char-p (subseq value 0 dot))
                  (every #'digit-char-p (subseq value (1+ dot))))
             (every #'digit-char-p value)))))

(defun %parse-decimal-number (value)
  (let ((dot (position #\. value)))
    (if dot
        (+ (parse-integer value :end dot)
           (/ (parse-integer value :start (1+ dot))
              (expt 10 (- (length value) dot 1))))
        (parse-integer value))))

(defun %fractional-track-string-p (value)
  (and (> (length value) 2)
       (string-equal "fr" value :start2 (- (length value) 2))
       (%decimal-number-string-p (subseq value 0 (- (length value) 2)))))

(defun %parse-track-token (value)
  (let ((value (string-downcase (trim-string value))))
    (cond
      ((%fractional-track-string-p value)
       (list :fr
             (%parse-decimal-number
              (subseq value 0 (- (length value) 2)))))
      ((%decimal-number-string-p value)
       (%parse-decimal-number value))
      (t
       (kw value)))))

(defun %parse-minmax-track (value)
  (let* ((value (trim-string value))
         (open (position #\( value))
         (close (position #\) value :from-end t)))
    (when (and open
               close
               (= close (1- (length value)))
               (string-equal "minmax"
                             (trim-string (subseq value 0 open))))
      (let* ((body (subseq value (1+ open) close))
             (parts (split-string-literal "," body :limit 2)))
        (when (and (= (length parts) 2)
                   (= (count #\, body) 1))
          (list :minmax
                (%parse-track-token (first parts))
                (%parse-track-token (second parts))))))))

(defun parse-track-def (def)
  (cond
    ((numberp def) def)
    ((stringp def)
     (let ((value (trim-string def)))
       (cond
         ((blank-string-p value) :auto)
         ((%parse-minmax-track value))
         (t (%parse-track-token value)))))
    (t (kw def))))

(defun parse-track-defs (defs)
  (mapcar #'parse-track-def defs))

(defun resolve-grid-line-spec (line-spec line-count named-areas is-end-line default-span dimension)
  (labels ((named->idx (name)
             (let ((area (and (hash-table-p named-areas) (gethash name named-areas))))
               (when area
                 (ecase dimension
                   (:columns (if is-end-line (getf area :col-end) (getf area :col-start)))
                   (:rows (if is-end-line (getf area :row-end) (getf area :row-start))))))))
    (cond
      ((integerp line-spec)
       (let* ((val (if (< line-spec 0) (+ (1+ line-count) line-spec) line-spec))
              (zero (max 0 (1- val))))
         (min (max 0 zero) line-count)))
      ((stringp line-spec) (or (named->idx line-spec) :auto))
      ((eq line-spec :auto) (if (and is-end-line (numberp default-span)) (list :span default-span) :auto))
      ((and (consp line-spec) (eq (car line-spec) :span)) line-spec)
      (t :auto))))

(defun initialize-grid-tracks (track-defs)
  (loop for i from 0
        for raw in (parse-track-defs track-defs)
        for type = (cond
                     ((numberp raw) :fixed)
                     ((and (consp raw) (eq (car raw) :fr)) :fr)
                     ((and (consp raw) (eq (car raw) :minmax)) :minmax)
                     (t :content))
        collect
        (make-grid-track
         :index i :type type :definition raw
         :base-size (if (eq type :fixed) (coerce raw 'double-float) 0.0d0)
         :fr-units (if (eq type :fr) (coerce (cadr raw) 'double-float) 0.0d0)
         :growth-limit (if (eq type :minmax)
                           (let ((maxb (caddr raw)))
                             (cond
                               ((numberp maxb) (coerce maxb 'double-float))
                               ((and (consp maxb) (eq (car maxb) :fr)) most-positive-double-float)
                               (t most-positive-double-float)))
                           most-positive-double-float)
         :is-flexible (not (eq type :fixed)))))

(defun make-occupancy (cols rows) (make-array (list rows cols) :initial-element nil))
(defun occupied-p (occ c r) (aref occ r c))
(defun occupy (occ c0 r0 c1 r1)
  (loop for r from r0 below r1 do (loop for c from c0 below c1 do (setf (aref occ r c) t))))

(defun find-slot (occ span-c span-r auto-flow)
  (let* ((rows (array-dimension occ 0))
         (cols (array-dimension occ 1)))
    (labels ((fits (c r)
               (and (<= (+ c span-c) cols) (<= (+ r span-r) rows)
                    (loop for rr from r below (+ r span-r) always
                                                           (loop for cc from c below (+ c span-c) always (not (aref occ rr cc)))))))
      (ecase auto-flow
        (:row (loop for r from 0 below rows do (loop for c from 0 below cols do (when (fits c r) (return-from find-slot (values c r))))))
        (:column (loop for c from 0 below cols do (loop for r from 0 below rows do (when (fits c r) (return-from find-slot (values c r)))))))
      (values nil nil))))

(defun normalize-align (val default)
  (let ((k (or (kw val) default)))
    (or (and (member k '(:start :end :center :stretch)) k) default)))

;; (defun %copy-el (el &key children)
;;   (let* ((class (class-of el))
;;          (new   (make-instance class)))
;;     (dolist (slot (sb-mop:class-slots (class-of el)))
;;       (let ((name (sb-mop:slot-definition-name slot)))
;;         (when (slot-boundp el name)
;;           (setf (slot-value new name) (slot-value el name)))))
;;     (when children (setf (element-children new) children))
;;     new))

(defun perform-track-sizing-iteration (col-tracks row-tracks grid-items available-width available-height col-gap row-gap)
  (dolist (track col-tracks) (setf (grid-track-min-contribution track) 0.0 (grid-track-max-contribution track) 0.0 (grid-track-items track) nil))
  (dolist (track row-tracks) (setf (grid-track-min-contribution track) 0.0 (grid-track-max-contribution track) 0.0 (grid-track-items track) nil))
  (dolist (item grid-items)
    (loop for i from (grid-item-col-start item) to (1- (grid-item-col-end item))
          do (when (< i (length col-tracks))
               (let ((track (nth i col-tracks)))
                 (push item (grid-track-items track))
                 (setf (grid-track-min-contribution track) (max (grid-track-min-contribution track) (/ (grid-item-min-content-width item) (grid-item-col-span item))))
                 (setf (grid-track-max-contribution track) (max (grid-track-max-contribution track) (/ (grid-item-max-content-width item) (grid-item-col-span item)))))))
    (loop for i from (grid-item-row-start item) to (1- (grid-item-row-end item))
          do (when (< i (length row-tracks))
               (let ((track (nth i row-tracks)))
                 (push item (grid-track-items track))
                 (setf (grid-track-min-contribution track) (max (grid-track-min-contribution track) (/ (grid-item-min-content-height item) (grid-item-row-span item))))
                 (setf (grid-track-max-contribution track) (max (grid-track-max-contribution track) (/ (grid-item-max-content-height item) (grid-item-row-span item))))))))
  (resolve-content-based-track-sizes col-tracks grid-items :width)
  (resolve-content-based-track-sizes row-tracks grid-items :height)
  (resolve-minmax-track-sizes col-tracks grid-items :width available-width (* (max 0 (1- (length col-tracks))) col-gap))
  (resolve-minmax-track-sizes row-tracks grid-items :height available-height (* (max 0 (1- (length row-tracks))) row-gap))
  (distribute-flexible-space col-tracks available-width (* (max 0 (1- (length col-tracks))) col-gap))
  (distribute-flexible-space row-tracks available-height (* (max 0 (1- (length row-tracks))) row-gap))
  (and (every (lambda (tr) (not (grid-track-is-flexible tr))) col-tracks)
       (every (lambda (tr) (not (grid-track-is-flexible tr))) row-tracks)))

(defun resolve-content-based-track-sizes (tracks items dimension)
  (declare (ignore items))
  (dolist (track tracks)
    (when (eq (grid-track-type track) :content)
      (let ((min-c 0.0) (max-c 0.0))
        (dolist (item (grid-track-items track))
          (let* ((item-span (if (eq dimension :width) (grid-item-col-span item) (grid-item-row-span item)))
                 (item-min (if (eq dimension :width) (grid-item-min-content-width item) (grid-item-min-content-height item)))
                 (item-max (if (eq dimension :width) (grid-item-max-content-width item) (grid-item-max-content-height item))))
            (when (and item-span (> item-span 0))
              (let ((contrib-min (/ item-min item-span))
                    (contrib-max (/ item-max item-span)))
                (setf min-c (max min-c contrib-min))
                (setf max-c (max max-c contrib-max))))))
        (setf (grid-track-base-size track)
              (case (grid-track-definition track)
                (:min-content min-c)
                (:max-content max-c)
                (t min-c)))
        (setf (grid-track-growth-limit track) (max (grid-track-base-size track) max-c))
        (setf (grid-track-is-flexible track) nil))))
  tracks)

(defun resolve-minmax-track-sizes (tracks items dimension available-space total-gap)
  (declare (ignore items dimension available-space total-gap))
  (dolist (track tracks)
    (when (eq (grid-track-type track) :minmax)
      (let* ((minmax-def (grid-track-definition track))
             (min-bound (cadr minmax-def))
             (max-bound (caddr minmax-def)))
        (setf min-bound
              (cond
                ((numberp min-bound) min-bound)
                ((eq min-bound :auto) (grid-track-min-contribution track))
                ((eq min-bound :min-content) (grid-track-min-contribution track))
                ((eq min-bound :max-content) (grid-track-max-contribution track))
                (t 0.0)))
        (setf max-bound
              (cond
                ((numberp max-bound) max-bound)
                ((eq max-bound :auto) (grid-track-max-contribution track))
                ((eq max-bound :fr) most-positive-double-float)
                ((eq max-bound :min-content) (grid-track-min-contribution track))
                ((eq max-bound :max-content) (grid-track-max-contribution track))
                (t most-positive-double-float)))
        (setf (grid-track-base-size track) (max min-bound (grid-track-base-size track) (grid-track-min-contribution track)))
        (setf (grid-track-growth-limit track) (min max-bound (grid-track-max-contribution track)))
        (when (numberp max-bound)
          (setf (grid-track-base-size track) (min (grid-track-base-size track) max-bound))
          (when (>= (grid-track-base-size track) max-bound)
            (setf (grid-track-is-flexible track) nil))))))
  tracks)

(defun distribute-flexible-space (tracks available-space total-gap-size)
  (let* ((num-flexible-auto (loop for track in tracks count (and (grid-track-is-flexible track) (eq (grid-track-definition track) :auto))))
         (total-fr-units (loop for track in tracks when (and (grid-track-is-flexible track) (> (grid-track-fr-units track) 0)) sum (grid-track-fr-units track)))
         (fixed-size (loop for track in tracks unless (grid-track-is-flexible track) sum (grid-track-base-size track)))
         (space-for-flexible (max 0.0 (- available-space fixed-size total-gap-size))))
    (when (> space-for-flexible 0)
      (cond
        ((> total-fr-units 0)
         (let ((size-per-fr (/ space-for-flexible total-fr-units)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track) (> (grid-track-fr-units track) 0))
               (let ((growth (max 0 (* (grid-track-fr-units track) size-per-fr))))
                 (incf (grid-track-base-size track) growth)
                 (setf (grid-track-base-size track) (min (grid-track-base-size track) (grid-track-growth-limit track)))
                 (setf (grid-track-is-flexible track) nil))))))
        ((> num-flexible-auto 0)
         (let ((size-per-auto (/ space-for-flexible num-flexible-auto)))
           (dolist (track tracks)
             (when (and (grid-track-is-flexible track) (eq (grid-track-definition track) :auto))
               (incf (grid-track-base-size track) size-per-auto)
               (setf (grid-track-base-size track) (min (grid-track-base-size track) (grid-track-growth-limit track)))
               (setf (grid-track-is-flexible track) nil))))))))
  tracks)

(defun calculate-final-track-sizes (tracks)
  (dolist (track tracks)
    (setf (grid-track-final-size track) (max 0.0 (grid-track-base-size track))))
  tracks)

(defun align-item-in-area (item-node item-layout-rect grid-area-rect align-self justify-self)
  ;; (unless (and item-node (typep item-node 'base-element))
  ;;   (error "align-item-in-area requires a base-element."))
  (declare (ignore item-node))
  (let ((final-rect (copy-rectangle item-layout-rect))
        (item-w (w item-layout-rect)) (item-h (h item-layout-rect))
        (area-w (w grid-area-rect)) (area-h (h grid-area-rect)))
    (case justify-self
      (:start (setf (x final-rect) (x grid-area-rect)))
      (:end (setf (x final-rect) (+ (x grid-area-rect) (- area-w item-w))))
      (:center (setf (x final-rect) (+ (x grid-area-rect) (round (/ (- area-w item-w) 2)))))
      (:stretch (setf (x final-rect) (x grid-area-rect)) (setf (w final-rect) area-w)))
    (case align-self
      (:start (setf (y final-rect) (y grid-area-rect)))
      (:end (setf (y final-rect) (+ (y grid-area-rect) (- area-h item-h))))
      (:center (setf (y final-rect) (+ (y grid-area-rect) (round (/ (- area-h item-h) 2)))))
      (:stretch (setf (y final-rect) (y grid-area-rect)) (setf (h final-rect) area-h)))
    final-rect))

(defmethod compute-grid-layout (grid-container-node available-rect)
  (unless (and grid-container-node (typep grid-container-node 'base-element))
    (error "layout-grid-container requires a base-element."))
  (unless (typep available-rect 'rectangle)
    (error "layout-grid-container requires a rectangle."))

  (let* ((container-styles (element-style grid-container-node))
         (container-content-rect (elmtui.view.layout.size-utils:content-rect-of available-rect grid-container-node))
         (children (remove-if-not (lambda (el) (typep el 'base-element)) (element-children grid-container-node)))
         (template-areas-str (el/styles-of grid-container-node :grid-template-areas))
         (named-area-map (when template-areas-str (parse-grid-template-areas (ensure-list template-areas-str))))
         (col-defs (ensure-list (el/styles-of grid-container-node :grid-template-columns '(:auto))))
         (row-defs (ensure-list (el/styles-of grid-container-node :grid-template-rows '(:auto))))
         (auto-flow (kw (el/styles-of grid-container-node :grid-auto-flow :row)))
         (grid-auto-cols (el/styles-of grid-container-node :grid-auto-columns :auto))
         (grid-auto-rows (el/styles-of grid-container-node :grid-auto-rows :auto))
         (explicit-col-count (length col-defs))
         (explicit-row-count (length row-defs)))
    (multiple-value-bind (row-gap col-gap) (normalize-gap container-styles)
      (let* ((raws (loop for ch in children collect
                                            (let* ((st (element-style ch))
                                                   (ga (getf st :grid-area nil))
                                                   (gcs (getf st :grid-column-start :auto))
                                                   (gce (getf st :grid-column-end :auto))
                                                   (grs (getf st :grid-row-start :auto))
                                                   (gre (getf st :grid-row-end :auto)))
                                              (when (and (stringp ga) named-area-map)
                                                (let ((def (gethash ga named-area-map)))
                                                  (when def
                                                    (setf gcs (getf def :col-start) gce (getf def :col-end)
                                                          grs (getf def :row-start) gre (getf def :row-end)))))
                                              (list :node ch
                                                    :cs (resolve-grid-line-spec gcs explicit-col-count named-area-map nil 1 :columns)
                                                    :ce (resolve-grid-line-spec gce explicit-col-count named-area-map t 1 :columns)
                                                    :rs (resolve-grid-line-spec grs explicit-row-count named-area-map nil 1 :rows)
                                                    :re (resolve-grid-line-spec gre explicit-row-count named-area-map t 1 :rows)))))
             (max-cols explicit-col-count)
             (max-rows explicit-row-count)
             (placed '()))
        (dolist (r raws)
          (let* ((cs (getf r :cs)) (ce (getf r :ce)) (rs (getf r :rs)) (re (getf r :re)))
            ;; Do NOT coerce :auto starts to 0 here; keep them for auto-placement.
            ;; Only resolve end-lines from (:span n) when we have numeric starts.
            (when (and (numberp cs) (consp ce)) (setf ce (+ cs (cadr ce))))
            (when (and (numberp rs) (consp re)) (setf re (+ rs (cadr re))))
            ;; Track max only for fully numeric placements (explicitly positioned items).
            (when (and (numberp ce)) (setf max-cols (max max-cols ce)))
            (when (and (numberp re)) (setf max-rows (max max-rows re)))
            (setf (getf r :cs) cs (getf r :ce) ce (getf r :rs) rs (getf r :re) re)))
        (when (> max-cols explicit-col-count)
          (setf col-defs (append col-defs (make-list (- max-cols explicit-col-count) :initial-element grid-auto-cols))))
        (when (> max-rows explicit-row-count)
          (setf row-defs (append row-defs (make-list (- max-rows explicit-row-count) :initial-element grid-auto-rows))))
        (let ((occ (make-occupancy (length col-defs) (length row-defs))))
          (dolist (r raws)
            (let* ((node (getf r :node))
                   (cs (getf r :cs)) (ce (getf r :ce))
                   (rs (getf r :rs)) (re (getf r :re))
                   ;; Determine spans: prefer (:span n), else derive from numeric ends, else 1.
                   (span-c (cond
                             ((and (consp ce) (eq (car ce) :span)) (max 1 (cadr ce)))
                             ((and (numberp cs) (numberp ce)) (max 1 (- ce cs)))
                             (t 1)))
                   (span-r (cond
                             ((and (consp re) (eq (car re) :span)) (max 1 (cadr re)))
                             ((and (numberp rs) (numberp re)) (max 1 (- re rs)))
                             (t 1))))
              ;; Auto-placement if either start is :auto
              (when (or (eq cs :auto) (eq rs :auto))
                (multiple-value-bind (c r0) (find-slot occ span-c span-r (or auto-flow :row))
                  (when (and c r0)
                    (setf cs c rs r0
                          ce (+ c span-c)
                          re (+ r0 span-r)))))
              ;; If any ends are still (:span n) (with numeric starts), resolve them now.
              (when (and (numberp cs) (consp ce)) (setf ce (+ cs (cadr ce))))
              (when (and (numberp rs) (consp re)) (setf re (+ rs (cadr re))))
              ;; Occupy and record.
              (occupy occ cs rs ce re)
              (push (make-grid-item :node node :id (element-id node)
                                    :col-start cs :col-end ce :row-start rs :row-end re
                                    :col-span span-c :row-span span-r :placed-p t)
                    placed))))
        (setf placed (nreverse placed))
        (let* ((avail-w (max 0 (- (w container-content-rect) (* (max 0 (1- (length col-defs))) col-gap))))
               (avail-h (max 0 (- (h container-content-rect) (* (max 0 (1- (length row-defs))) row-gap))))
               (col-tracks (initialize-grid-tracks col-defs))
               (row-tracks (initialize-grid-tracks row-defs)))
          (dolist (it placed)
            (update-item-intrinsic-dimensions it (w container-content-rect) (h container-content-rect)))
          (loop repeat 10 do (when (perform-track-sizing-iteration col-tracks row-tracks placed avail-w avail-h col-gap row-gap) (return)))
          (calculate-final-track-sizes col-tracks)
          (calculate-final-track-sizes row-tracks)
          (let* ((final-col-sizes (mapcar #'grid-track-final-size col-tracks))
                 (final-row-sizes (mapcar #'grid-track-final-size row-tracks))
                 (num-cols (length final-col-sizes))
                 (num-rows (length final-row-sizes))
                 (total-cols (+ (reduce #'+ final-col-sizes)
                                (* (max 0 (1- num-cols)) col-gap)))
                 (total-rows (+ (reduce #'+ final-row-sizes)
                                (* (max 0 (1- num-rows)) row-gap)))
                 ;; Container-level alignment (justify-content/align-content)
                 (jc (kw (or (el/styles-of grid-container-node :justify-content "start") "start")))
                 (ac (kw (or (el/styles-of grid-container-node :align-content   "start") "start")))
                 (free-x (max 0 (- (w container-content-rect) total-cols)))
                 (free-y (max 0 (- (h container-content-rect) total-rows)))
                 (lead-x 0.0) (lead-y 0.0) (extra-cg 0.0) (extra-rg 0.0)
                 (out-children '()))
            ;; horizontal (justify-content)
            (ecase jc
              (:start (setf lead-x 0.0 extra-cg 0.0))
              (:end   (setf lead-x free-x extra-cg 0.0))
              (:center(setf lead-x (/ free-x 2.0) extra-cg 0.0))
              (:space-between (setf lead-x 0.0 extra-cg (if (> num-cols 1) (/ free-x (max 1 (1- num-cols))) 0.0)))
              (:space-around  (let ((g (/ free-x (max 1 num-cols)))) (setf lead-x (/ g 2.0) extra-cg g)))
              (:space-evenly  (let ((g (/ free-x (1+ num-cols)))) (setf lead-x g extra-cg g)))
              (:stretch       (let ((g (/ free-x (max 1 (1- num-cols))))) (setf lead-x 0.0 extra-cg (if (> num-cols 1) g 0.0)))))
            ;; vertical (align-content)
            (ecase ac
              (:start (setf lead-y 0.0 extra-rg 0.0))
              (:end   (setf lead-y free-y extra-rg 0.0))
              (:center(setf lead-y (/ free-y 2.0) extra-rg 0.0))
              (:space-between (setf lead-y 0.0 extra-rg (if (> num-rows 1) (/ free-y (max 1 (1- num-rows))) 0.0)))
              (:space-around  (let ((g (/ free-y (max 1 num-rows)))) (setf lead-y (/ g 2.0) extra-rg g)))
              (:space-evenly  (let ((g (/ free-y (1+ num-rows)))) (setf lead-y g extra-rg g)))
              (:stretch       (let ((g (/ free-y (max 1 (1- num-rows))))) (setf lead-y 0.0 extra-rg (if (> num-rows 1) g 0.0)))))
            (dolist (gi placed)
              (let* ((cs (grid-item-col-start gi)) (ce (grid-item-col-end gi))
                     (rs (grid-item-row-start gi)) (re (grid-item-row-end gi))
                     (area-x (+ (x container-content-rect)
                                lead-x
                                (loop for i from 0 below cs sum (or (nth i final-col-sizes) 0.0))
                                (* cs (+ col-gap extra-cg))))
                     (area-y (+ (y container-content-rect)
                                lead-y
                                (loop for i from 0 below rs sum (or (nth i final-row-sizes) 0.0))
                                (* rs (+ row-gap extra-rg))))
                     (area-w (max 0 (+ (loop for i from cs below ce sum (or (nth i final-col-sizes) 0.0))
                                       (* (max 0 (1- (- ce cs))) (+ col-gap extra-cg)))))
                     (area-h (max 0 (+ (loop for i from rs below re sum (or (nth i final-row-sizes) 0.0))
                                       (* (max 0 (1- (- re rs))) (+ row-gap extra-rg)))))
                     (grid-area-rect (let* ((rw (max 1 (round area-w)))
                                            (rh (max 1 (round area-h))))
                                       (make-rectangle :pos (make-pos :x (round area-x) :y (round area-y))
                                                       :size (make-size :w rw :h rh))))
                     (item (grid-item-node gi))
                     (st (element-style item))
                     (align (normalize-align (getf st :align-self (getf container-styles :align-items :stretch)) :stretch))
                     (justify (normalize-align (getf st :justify-self (getf container-styles :justify-items :stretch)) :stretch)))
                (cond
                  ((and (eq align :stretch) (eq justify :stretch))
                   (let ((laid (layout-node item grid-area-rect container-styles)))
                     (setf (elmtui.view.element:el/layout-rect laid) grid-area-rect)
                     (push laid out-children)))
                  (t
                   (let* ((laid (layout-node item grid-area-rect container-styles))
                           (child-rect (el/layout-rect laid))
                          (final (align-item-in-area laid child-rect grid-area-rect align justify)))
                     (setf (elmtui.view.element:el/layout-rect laid) final)
                     (push laid out-children))))))
            (let* ((cw (or (and (eq (el/styles-of grid-container-node :width :auto) :auto) total-cols)
                           (w container-content-rect)))
                   (ch (or (and (eq (el/styles-of grid-container-node :height :auto) :auto) total-rows)
                           (h container-content-rect)))
                   (new (copy-element grid-container-node )))
              (setf (elmtui.view.element:el/children new) (nreverse out-children))
              (setf (elmtui.view.element:el/layout-rect new)
                    (make-rectangle :pos (make-pos :x (x container-content-rect) :y (y container-content-rect))
                                    :size (make-size :w
                                                     (floor cw) :h (floor ch))))
              new)))))))
(defmethod compute-layout ((style (eql :grid)) node rect &key &allow-other-keys)
  (compute-grid-layout node rect))
