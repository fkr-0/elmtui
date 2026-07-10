;;;; tests/root-viewport-tests.lisp
;;;; FiveAM tests for :elmtui.ui.widgets.root-viewport

(uiop:define-package :elmtui.ui.widgets.root-viewport.tests
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.widgets.root-viewport
    ;; SUT public API
    #:root-viewport #:make-root-viewport
    #:anchor-type
    ;; SUT internals we want for algorithmic testing
    #:compute-anchor-solution
    #:%recompute-anchoring
    #:%apply-overflow-y)
  (:import-from :elmtui.state
    #:make-state)
  (:import-from :elmtui.state.update
    #:make-update-context)
  (:import-from :elmtui.utils #:as)
  (:import-from :elmtui.ui.api
    #:init #:view)  ; we only call :view for gating (no rendering)
  (:export #:run-root-viewport-tests))

(in-package :elmtui.ui.widgets.root-viewport.tests)

(def-suite root-viewport

  :in elmtui.tests:elmtui-test
  )
(in-suite root-viewport)
;;;; --------------------------------------------------------------------------
;;;; Small utilities for state patching used by the SUT
;;;; --------------------------------------------------------------------------

(defun %plist-hash-table (plist)
  "Convert PLIST to a hash-table."
  (let ((ht (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr
      do (setf (gethash k ht) v))
    ht))

(defun %plist-put-in (plist path value)
  "Functional-ish put: returns new PLIST with PATH set to VALUE.
PATH is a list of keywords like (:app :rv :width)."
  (labels ((put (cell ks)
             (if (endp ks)
               value
               (let* ((cell* (if (listp cell) cell nil))
                       (k (first ks))
                       (rest (rest ks))
                       (sub (getf cell* k)))
                 (setf sub (put (or sub nil) rest))
                 (let ((out (copy-list cell*)))
                   (setf (getf out k) sub)
                   out)))))
    (put plist path)))

(defun %apply-patches (state patches)
  "Patches are ( (path value) ... ); path is a list; return new state."
  (reduce (lambda (s p)
            (destructuring-bind (path value) p
              (%plist-put-in s path value)))
    patches :initial-value state))

(defun %make-test-ctx (base-path state)
  "Create an update context for STATE rooted at BASE-PATH."
  (let ((app (make-state :initial state :backend :plist)))
    (make-update-context app :base-path base-path)))

;;;; --------------------------------------------------------------------------
;;;; 0) Init normalization
;;;; --------------------------------------------------------------------------

(test init-normalizes-dotted-initial-cursor-pos
  (let ((rv (make-root-viewport :rv)))
    (multiple-value-bind (_component patches)
      (init rv :id-path '(:app :rv)
        :initial-terminal-dimensions '(10 5)
        :initial-cursor-pos '(3 . 4))
      (declare (ignore _component))
      (is (some (lambda (patch)
                  (and (equal (first patch) '(:components :app :rv :initial-cursor-pos))
                    (equal (second patch) '(3 4))))
            patches)
        "Dotted cursor positions are normalized to proper two-element lists."))))

;;;; --------------------------------------------------------------------------
;;;; 1) View gating: return NIL until both size & cursor are known
;;;; --------------------------------------------------------------------------

(test view-gates-until-ready
  (let* ((id-path '(:app :rv))
          (rv (make-root-viewport :rv))
          (dsl '(:root-viewport :anchor :below-cursor))
          (state nil))
    (multiple-value-bind (component patches)
      (init rv :id-path id-path
        :initial-terminal-dimensions '(0 0)
        :initial-cursor-pos '(0 . 0)
        :dsl dsl)
      (declare (ignore component))
      (setf state (%apply-patches state patches)))

    (is (null (view rv state :id-path id-path))
      "Without terminal size & cursor pos, view must be NIL.")

    ;; Simulate SUT becoming ready by setting the flags it checks
    (flet ((mark-ready (st base-path)
             (let* ((ready-patches
                      (list (list (append base-path '(:size-known)) t)
                        (list (append base-path '(:terminal-size)) '(20 10))
                        (list (append base-path '(:width)) 20)
                        (list (append base-path '(:height)) 10)
                        (list (append base-path '(:offset-x)) 0)
                        (list (append base-path '(:offset-y)) 0))))
               (%apply-patches st ready-patches))))
      ;; canonical (:components …) path
      (let* ((canonical-path (cons :components id-path))
              (canon-state (mark-ready state canonical-path)))
        (is (consp (view rv canon-state :id-path canonical-path))
          "Canonical state path must produce DSL once ready.")
        (is (consp (view rv canon-state :id-path id-path))
          "Non-canonical ID-PATH is normalized to canonical component state path."))
      ;; legacy state path without :components prefix is no longer supported
      (let* ((legacy-state (mark-ready state id-path)))
        (is (null (view rv legacy-state :id-path id-path))
          "Legacy non-components state path should not resolve.")))))

;;;; --------------------------------------------------------------------------
;;;; 2) Anchoring math: position semantics & growth labels
;;;; --------------------------------------------------------------------------

(test anchor-above-cursor-bottom-left-semantics
  ;; Terminal 20x20, cursor at row=10 col=0; desired W=12 H=5
  (multiple-value-bind (oy ox ap growth eff)
    (compute-anchor-solution :above-cursor 12 5 20 20 10 0)
    (declare (ignore eff))
    (is (= (car ap) (+ oy 4))
      "above-cursor: anchor-pos.row is bottom row of rect (oy + height - 1).")
    (is (= (cdr ap) ox)
      "above-cursor: anchor-pos.col is left (top-left col).")
    (is (eql growth :top-right)
      "above-cursor: growth is :top-right.")))

(test anchor-below-cursor-top-left-semantics
  (multiple-value-bind (oy ox ap growth eff)
    (compute-anchor-solution :below-cursor 8 6 20 20 10 0)
    (declare (ignore eff))
    (is (= (car ap) oy)
      "below-cursor: anchor-pos.row equals top-left row.")
    (is (= (cdr ap) ox)
      "below-cursor: anchor-pos.col equals top-left col.")
    (is (eql growth :bottom-right)
      "below-cursor: growth is :bottom-right.")))

(test anchor-top-left-bottom-right-growth
  (multiple-value-bind (oy ox ap growth eff)
    (compute-anchor-solution :top-left 5 5 20 20 0 0)
    (declare (ignore ap eff))
    (is (= oy 0))
    (is (= ox 0))
    (is (eql growth :bottom-right))))

(test edge-clamp-right-column-near-border
  ;; Cursor at col=19; desired width 20 should clamp to x=0 so full rect is visible.
  (multiple-value-bind (oy ox ap growth eff)
    (compute-anchor-solution :above-cursor 20 3 20 20 10 19)
    (declare (ignore oy ap growth))
    (is (= ox 0) "When desired width hits right edge, the rectangle shifts left to fit.")
    (is (= (car eff) 20))
    (is (= (cdr eff) 3))))

;;;; --------------------------------------------------------------------------
;;;; 3) Overflow policy (vertical): :scroll vs :truncate
;;;; --------------------------------------------------------------------------

(defun %mk-state-for-overflow (anchor rows cols cur-row cur-col width height &key (issued 0))
  "Build a minimal state subtree used by %apply-overflow-y."
  (let ((st '()))
    (dolist (p
              `(((:anchor) ,anchor)
                 ((:terminal-size) (,cols ,rows))
                 ((:cursor-pos) (,cur-col ,cur-row))
                 ((:height) ,height)
                 ((:width) ,width)
                 ((:issued-scroll-net) ,issued)))
      (setf st (%plist-put-in st (first p) (second p))))
    st))

(test overflow-below-cursor-scroll
  ;; rows=20, cursor row=20 (1-based) → 1 row remaining; height=4 => need scroll-down 3.
  (let* ((st (%mk-state-for-overflow :below-cursor 20 80 20 0 30 4))
          (st-path '(:app :rv))
          (state (%plist-put-in '() st-path st))
          (ctx (%make-test-ctx st-path state)))
    (multiple-value-bind (patches commands)
      (%apply-overflow-y ctx :scroll 0 0)
      (is (find '(:render :scroll-down 3) commands :test #'equal)
        "Below-cursor + overflow :scroll → issue :scroll-down by the deficit.")
      (is (some (lambda (p) (and (equal (first p) (append st-path '(:issued-scroll-net)))
                              (= (second p) 3)))
            patches)
        "Issued scroll net must accumulate by 3."))))

(test overflow-below-cursor-truncate
  ;; Same geometry, but policy :truncate → height becomes 1; no commands.
  (let* ((st (%mk-state-for-overflow :below-cursor 20 80 20 0 30 4))
          (st-path '(:app :rv))
          (state (%plist-put-in '() st-path st))
          (ctx (%make-test-ctx st-path state)))
    (multiple-value-bind (patches commands)
      (%apply-overflow-y ctx :truncate 0 0)
      (is (null commands) "Truncate issues no :render commands.")
      (is (some (lambda (p) (and (equal (first p) (append st-path '(:height)))
                              (= (second p) 1)))
            patches)
        "Truncate sets height to available rows (1)."))))

(test overflow-above-cursor-scroll
  ;; rows=20, cursor row=2 (1-based) → rows available above = 1; height=5 => need scroll-up 4.
  (let* ((st (%mk-state-for-overflow :above-cursor 20 80 2 0 30 5))
          (st-path '(:app :rv))
          (state (%plist-put-in '() st-path st))
          (ctx (%make-test-ctx st-path state)))
    (multiple-value-bind (patches commands)
      (%apply-overflow-y ctx :scroll 0 0)
      (declare (ignore patches))
      (is (find '(:render :scroll-up 4) commands :test #'equal)))))

;;;; --------------------------------------------------------------------------
;;;; 4) Manual mode: clamping and no re-anchoring on resize/cursor
;;;; --------------------------------------------------------------------------

(defun %mk-state-for-manual (rows cols width height off-y off-x &key growth)
  (let ((st '()))
    (dolist (p
              `(((:anchor) :manual)
                 ((:terminal-size) (,cols ,rows))
                 ((:width) ,width)
                 ((:height) ,height)
                 ((:offset-x) ,off-y)
                 ((:offset-y) ,off-x)
                 ,@(when growth `(((:anchor-growth) ,growth)))))
      (setf st (%plist-put-in st (first p) (second p))))
    st))

(test manual-mode-recompute-only-clamps
  ;; Start somewhere near the bottom-right; grow terminal smaller; ensure clamping but no repositioning logic.
  (let* ((st (%mk-state-for-manual 40 100 20 10 35 90 :growth :bottom-right))
          (st-path '(:app :rv))
          (state (%plist-put-in '() st-path st))
          (ctx (%make-test-ctx st-path state)))
    (multiple-value-bind (oy ox ap growth eff)
      (%recompute-anchoring ctx)
      ;; In manual mode, offsets returned are the (possibly clamped) stored offsets
      ;; Note: rows/cols in state are 40x100, height=10,width=20 → max off-x = 30, off-y = 80
      (is (= oy 30))
      (is (= ox 80))
      (is (equal ap (cons 30 80)) "In manual mode anchor-pos is top-left (row . col).")
      (is (eql growth :bottom-right))
      (is (equal eff (cons 20 10))))))

(test manual-mode-growth-default
  ;; If no growth stored, fall back to :bottom-right.
  (let* ((st (%mk-state-for-manual 24 60 10 6 3 7))
          (st-path '(:app :rv))
          (state (%plist-put-in '() st-path st))
          (ctx (%make-test-ctx st-path state)))
    (multiple-value-bind (_oy _ox _ap growth _eff)
      (%recompute-anchoring ctx)
      (declare (ignore _oy _ox _ap _eff))
      (is (eql growth :bottom-right)))))

;;;; --------------------------------------------------------------------------
;;;; Runner
;;;; --------------------------------------------------------------------------

(defun run-root-viewport-tests ()
  (run! :root-viewport))
