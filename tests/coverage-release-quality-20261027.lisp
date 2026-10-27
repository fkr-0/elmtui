;;;; E4 release-coverage behavioral matrix (2026-10-27).
;;;; Loaded explicitly by scripts/coverage.lisp; tests are NOT instrumented.
(defpackage :elmtui.tests.coverage-release-20261027
  (:use :cl :fiveam)
  (:local-nicknames (:state :elmtui.state.model)
                    (:view :elmtui.view.core)
                    (:glyph :elmtui.view.layout.size-utils)
                    (:vb :elmtui.platform.backend.common.virtual-buffer)
                    (:diff :elmtui.render.diff)
                    (:focus :elmtui.core.focus)
                    (:geo :elmtui.view.geo)
                    (:base :elmtui.view.base-elements)))
(in-package :elmtui.tests.coverage-release-20261027)

(def-suite coverage-release-20261027 :in elmtui.tests:elmtui-test)
(in-suite coverage-release-20261027)

(test state-patch-batch-preserves-previous-tree
  "Nested changes and append/prepend retain the previous snapshot."
  (let* ((before '(:settings (:theme :light :counter 3 :obsolete t)
                   :history (:middle)))
         (patches (list
                   (state:make-state-patch :path '(:settings :theme)
                                           :value :dark :operation :set)
                   (state:make-state-patch :path '(:settings :counter)
                                           :value #'1+ :operation :update)
                   (state:make-state-patch :path '(:settings :obsolete)
                                           :operation :delete)
                   (state:make-state-patch :path '(:history)
                                           :value :first :operation :prepend)
                   (state:make-state-patch :path '(:history)
                                           :value :last :operation :append)))
         (after (state:apply-state-patches before patches)))
    (is (eq :light (state:get-state-value before '(:settings :theme))))
    (is (= 3 (state:get-state-value before '(:settings :counter))))
    (is (eq :dark (state:get-state-value after '(:settings :theme))))
    (is (= 4 (state:get-state-value after '(:settings :counter))))
    (is (eq :missing (state:get-state-value after '(:settings :obsolete) :missing)))
    (is (equal '(:first :middle :last) (state:get-state-value after '(:history))))
    (is (equal '(:middle) (state:get-state-value before '(:history))))))

(test state-patch-errors-do-not-commit-partial-work
  "An invalid operation throws; the already-applied patch is only in a copy."
  (let* ((previous '(:count 1 :nested (:value 2)))
         (patches (list
                   (state:make-state-patch :path '(:count)
                                           :value 9 :operation :set)
                   (state:make-state-patch :path '(:nested :value)
                                           :value 7 :operation :impossible))))
    (signals error (state:apply-state-patches previous patches))
    (is (= 1 (state:get-state-value previous '(:count))))
    (is (= 2 (state:get-state-value previous '(:nested :value))))))

(state:deftransaction e4-abort-after-invalid-operation (old)
  (list
   (state:make-state-patch :path '(:count) :value 99 :operation :set)
   (state:make-state-patch :path '(:count) :value nil :operation :invalid)))

(test legacy-transaction-failure-returns-original-state
  "A transaction cannot expose its partially-mutated working copy after error."
  (let ((before '(:count 4 :label "stable")) (diagnostics 0))
    (handler-bind ((warning (lambda (condition)
                              (declare (ignore condition))
                              (incf diagnostics)
                              (muffle-warning))))
      (multiple-value-bind (after record)
          (e4-abort-after-invalid-operation before)
        (is (eq before after))
        (is (null record))
        (is (= 4 (getf after :count)))
        (is (string= "stable" (getf after :label)))))
    (is (= 1 diagnostics))))

(test state-helpers-nested-update-merge-and-diff
  "Read, update and merge preserve the caller's nested persistent snapshot."
  (let* ((previous '(:nested (:value 3) :status :old))
         (changed (state:update-state-value previous '(:nested :value) #'1+))
         (merged (state:merge-state-updates changed '(:status :new) '(:extra 7)))
         (changes (state:diff-states previous merged)))
    (is (= 3 (state:get-state-value previous '(:nested :value))))
    (is (= 4 (state:get-state-value changed '(:nested :value))))
    (is (eq :new (state:get-state-value merged '(:status))))
    (is (= 7 (state:get-state-value merged '(:extra))))
    (is (= 3 (length changes)))
    (is (member :nested (mapcar #'second changes)))
    (is (member :status (mapcar #'second changes)))
    (is (member :extra (mapcar #'second changes)))
    (let ((reverse (state:diff-states merged previous)))
      (is (= 3 (length reverse)))
      (is (member '(:removed :extra 7 nil) reverse :test #'equal)))))

(test view-replacement-and-context-unwind
  "View tree replacement is total, and scoped props unwind after errors."
  (let ((old (list :old)) (next (list :new)))
    (let ((replacement (view:view-diff old next)))
      (is (eq next (view:apply-diff old replacement)))
      (is (eq next (view:apply-diff :anything replacement)))))
  (let ((view::*default-props* '(:root 1)))
    (view:with-view-context (:props '(:child 2))
      (is (equal '(:child 2) view::*default-props*))
      (view:with-view-context (:props '(:grandchild 3))
        (is (equal '(:grandchild 3) view::*default-props*)))
      (is (equal '(:child 2) view::*default-props*)))
    (signals error
      (view:with-view-context (:props '(:temporary 4))
        (error "intentional context unwind")))
    (is (equal '(:root 1) view::*default-props*))))

(test renderer-physical-slice-protects-graphemes
  "Cell-based clipping must avoid half of a wide glyph or combining sequence."
  (is (= 5 (glyph:terminal-string-width "A界éB")))
  (is (string= "界é" (glyph:terminal-string-slice "A界éB" 1 4)))
  (is (string= " " (glyph:terminal-string-slice "A界B" 1 2)))
  (is (string= " " (glyph:terminal-string-slice "A界B" 2 3)))
  (is (string= "B" (glyph:terminal-string-slice "A界B" 3 4)))
  (is (= 9 (glyph:terminal-string-width (format nil "x~CT" #\Tab)))))

(test focus-ring-reconciles-after-component-removal
  "The focused component disappearing must not retain an unreachable focus ID."
  (let ((manager (focus:make-focus-manager :initial-focus :editing)))
    (focus:recalculate-focusable-elements
     manager '(:container (:id :root)
               (:button (:id :opening :focusable t))
               (:button (:id :editing :focusable t))
               (:button (:id :unavailable :focusable t :disabled t)))
     :preserve-focus t)
    (is (eq :editing (focus:get-current-focus manager)))
    (is (equal '(:opening :editing)
               (focus:focus-manager-focusable-elements manager)))
    (focus:recalculate-focusable-elements
     manager '(:container (:id :root)
               (:button (:id :opening :focusable t))
               (:button (:id :unavailable :focusable t :disabled t)))
     :preserve-focus t)
    (is (eq :opening (focus:get-current-focus manager)))
    (is (equal '(:opening)
               (focus:focus-manager-focusable-elements manager)))
    (focus:recalculate-focusable-elements manager nil :preserve-focus t)
    (is (null (focus:get-current-focus manager)))))

(test flex-wrap-uses-actual-available-space
  "Sibling boxes wrap only when their combined widths exceed the parent."
  (let* ((root (make-instance 'base:container-element
                               :id :layout-root
                               :style '(:display :flex :flex-direction :row
                                        :flex-wrap :wrap :gap 1
                                        :height 10 :width 15)))
         (a (make-instance 'base:container-element
                           :id :a :style '(:width 5 :height 2)))
         (b (make-instance 'base:container-element
                           :id :b :style '(:width 5 :height 2)))
         (c (make-instance 'base:container-element
                           :id :c :style '(:width 5 :height 2))))
    (setf (base:element-children root) (list a b c))
    (base:compute-layout root
                         (geo:make-rectangle
                          :pos (geo:make-pos :x 0 :y 0)
                          :size (geo:make-size :w 15 :h 10)))
    (let ((ar (elmtui.view.element:el/layout-rect a))
          (br (elmtui.view.element:el/layout-rect b))
          (cr (elmtui.view.element:el/layout-rect c)))
      (is (< (geo:x ar) (geo:x br)))
      (is (> (geo:y cr) (geo:y ar)))
      (is (<= (geo:x cr) 15)))))
