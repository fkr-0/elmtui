;;;; tests/style-classes-tests.lisp — FiveAM suite for the defstyle / :class system.

(uiop:define-package :elmtui.tests.style-classes
  (:use :cl :fiveam)
  (:import-from :elmtui.ui.styles
                #:*style-registry*
                #:defstyle
                #:resolve-style-class
                #:resolve-style-classes
                #:merge-styles
                #:resolve-node-styles
                #:apply-theme
                #:clear-style-registry)
  (:import-from :elmtui.view.base-elements
                #:dsl->objects
                #:element-style
                #:element-id)
  (:export #:style-classes-suite))

(in-package :elmtui.tests.style-classes)

(def-suite style-classes-suite
  :description "Tests for the defstyle / :class style-class system"
  :in elmtui.tests::elmtui-test)

(in-suite style-classes-suite)

;;;--------------------------------------------------------------
;;; Helper: run body with a clean registry, restoring afterwards.
;;;--------------------------------------------------------------
(defmacro with-fresh-registry (&body body)
  "Execute BODY with an empty style registry, restoring the original afterwards."
  (let ((saved (gensym "SAVED")))
    `(let ((,saved (alexandria:copy-hash-table *style-registry*)))
       (unwind-protect
            (progn
              (clear-style-registry)
              ,@body)
         (setf *style-registry* ,saved)))))

;;;==============================================================
;;; 1. Registry CRUD
;;;==============================================================

(test defstyle-registers-style
  "defstyle stores a style plist in the registry under the given keyword."
  (with-fresh-registry
    (defstyle :test-a (:bold t :fg :red))
    (is (equal '(:bold t :fg :red) (gethash :test-a *style-registry*)))))

(test defstyle-overwrites-previous
  "A second defstyle with the same name replaces the first definition."
  (with-fresh-registry
    (defstyle :test-ow (:bold t))
    (defstyle :test-ow (:dim t))
    (is (equal '(:dim t) (gethash :test-ow *style-registry*)))))

(test resolve-style-class-retrieves
  "resolve-style-class returns the registered plist."
  (with-fresh-registry
    (defstyle :test-r (:fg :green))
    (is (equal '(:fg :green) (resolve-style-class :test-r)))))

(test resolve-style-class-unknown-signals-error
  "resolve-style-class signals an error for an unregistered name."
  (with-fresh-registry
    (signals error (resolve-style-class :nonexistent-style-42))))

(test clear-style-registry-empties
  "clear-style-registry removes all entries."
  (with-fresh-registry
    (defstyle :test-cl (:bold t))
    (clear-style-registry)
    (is (zerop (hash-table-count *style-registry*)))))

;;;==============================================================
;;; 2. Class composition and merge precedence
;;;==============================================================

(test resolve-single-class
  "resolve-style-classes with a single keyword returns that class's style."
  (with-fresh-registry
    (defstyle :single (:display :flex))
    (is (equal '(:display :flex) (resolve-style-classes :single)))))

(test resolve-multiple-classes-merge-order
  "Later classes in the list override earlier ones on key conflict."
  (with-fresh-registry
    (defstyle :base-c (:fg :red :bold t))
    (defstyle :overlay-c (:fg :blue :dim t))
    (let ((merged (resolve-style-classes '(:base-c :overlay-c))))
      ;; :fg should be :blue (overlay wins), :bold from base, :dim from overlay
      (is (eql :blue (getf merged :fg)))
      (is (eql t (getf merged :bold)))
      (is (eql t (getf merged :dim))))))

(test resolve-classes-list-with-no-conflict
  "Multiple classes with disjoint properties produce a union."
  (with-fresh-registry
    (defstyle :width-c (:width 40))
    (defstyle :height-c (:height 20))
    (let ((merged (resolve-style-classes '(:width-c :height-c))))
      (is (eql 40 (getf merged :width)))
      (is (eql 20 (getf merged :height))))))

(test resolve-classes-three-way-override
  "Three classes: last wins on triply-defined keys."
  (with-fresh-registry
    (defstyle :c1 (:fg :red :bg :black))
    (defstyle :c2 (:fg :green))
    (defstyle :c3 (:fg :blue))
    (let ((merged (resolve-style-classes '(:c1 :c2 :c3))))
      (is (eql :blue (getf merged :fg)))
      (is (eql :black (getf merged :bg))))))

;;;==============================================================
;;; 3. merge-styles: inline wins on conflict
;;;==============================================================

(test merge-styles-inline-wins
  "Inline style properties override class style properties."
  (let ((class-style '(:bold t :fg :red :padding 2))
        (inline-style '(:fg :green :dim t)))
    (let ((merged (merge-styles class-style inline-style)))
      (is (eql :green (getf merged :fg)) "Inline :fg wins")
      (is (eql t (getf merged :bold)) "Class :bold preserved")
      (is (eql 2 (getf merged :padding)) "Class :padding preserved")
      (is (eql t (getf merged :dim)) "Inline :dim added"))))

(test merge-styles-empty-inline
  "Empty inline style returns a copy of class style."
  (let ((class-style '(:bold t)))
    (let ((merged (merge-styles class-style nil)))
      (is (equal '(:bold t) merged))
      ;; Must be a fresh copy, not EQ
      (is (not (eq class-style merged))))))

(test merge-styles-empty-class
  "Empty class style with inline returns inline properties."
  (let ((merged (merge-styles nil '(:fg :cyan))))
    (is (eql :cyan (getf merged :fg)))))

;;;==============================================================
;;; 4. resolve-node-styles (DSL integration)
;;;==============================================================

(test resolve-node-styles-no-class
  "Props without :class are returned unchanged."
  (let ((props '(:id :foo :style (:bold t))))
    (is (eq props (resolve-node-styles props)))))

(test resolve-node-styles-class-only
  "A node with :class but no :style gets the class style as :style."
  (with-fresh-registry
    (defstyle :test-ns (:fg :cyan :bold t))
    (let ((result (resolve-node-styles '(:id :bar :class :test-ns))))
      ;; :class consumed
      (is (null (getf result :class)))
      ;; :style has class properties
      (is (eql :cyan (getf (getf result :style) :fg)))
      (is (eql t (getf (getf result :style) :bold))))))

(test resolve-node-styles-class-and-style-merge
  "Inline :style overrides :class-resolved properties."
  (with-fresh-registry
    (defstyle :test-ns2 (:fg :red :bold t))
    (let ((result (resolve-node-styles '(:id :baz :class :test-ns2 :style (:fg :green)))))
      (is (null (getf result :class)))
      ;; Inline :fg :green wins over class :fg :red
      (is (eql :green (getf (getf result :style) :fg)))
      ;; Class :bold preserved
      (is (eql t (getf (getf result :style) :bold))))))

(test resolve-node-styles-multi-class
  "A list of class keywords is resolved and merged."
  (with-fresh-registry
    (defstyle :mc-a (:display :flex :fg :red))
    (defstyle :mc-b (:fg :blue :padding 1))
    (let ((result (resolve-node-styles '(:id :multi :class (:mc-a :mc-b)))))
      (is (eql :flex (getf (getf result :style) :display)))
      ;; :mc-b overrides :mc-a's :fg
      (is (eql :blue (getf (getf result :style) :fg)))
      (is (eql 1 (getf (getf result :style) :padding))))))

;;;==============================================================
;;; 5. DSL->objects integration: end-to-end
;;;==============================================================

(test dsl-node-with-class-gets-merged-style
  "A DSL node with :class :flex-column gets the correct style on the element."
  ;; :flex-column is a built-in preset
  (let ((el (dsl->objects '(:container :id :e2e-fc :class :flex-column))))
    (let ((style (element-style el)))
      (is (eql :flex (getf style :display)))
      (is (eql :column (getf style :flex-direction))))))

(test dsl-node-class-and-inline-style
  "Inline :style on a DSL node wins over :class-resolved properties."
  (with-fresh-registry
    (defstyle :e2e-base (:bold t :fg :red :display :flex))
    (let ((el (dsl->objects '(:text :id :e2e-mix :content "hi"
                              :class :e2e-base :style (:fg :green)))))
      (let ((style (element-style el)))
        ;; Inline wins for :fg
        (is (eql :green (getf style :fg)))
        ;; Class :bold preserved
        (is (eql t (getf style :bold)))))))

(test dsl-node-multi-class-integration
  "A DSL node with :class (:flex-column :padded) gets both merged."
  ;; :flex-column and :padded are built-in presets
  (let ((el (dsl->objects '(:container :id :e2e-multi
                            :class (:flex-column :padded)))))
    (let ((style (element-style el)))
      (is (eql :flex (getf style :display)))
      (is (eql :column (getf style :flex-direction)))
      (is (eql 1 (getf style :padding-x)))
      (is (eql 1 (getf style :padding-y))))))

(test dsl-node-without-class-unchanged
  "A DSL node with only :style and no :class works as before."
  (let ((el (dsl->objects '(:text :id :e2e-plain :content "ok"
                            :style (:bold t)))))
    (is (eql t (getf (element-style el) :bold)))))

;;;==============================================================
;;; 6. Built-in presets are available
;;;==============================================================

(test builtin-presets-registered
  "All eight built-in presets are in the registry."
  (dolist (name '(:flex-row :flex-column :bold :dim
                  :centered :padded :bordered :bordered-rounded))
    (is (not (null (gethash name elmtui.ui.styles::*style-registry*)))
        (format nil "Built-in preset ~S should be registered" name))))

(test builtin-flex-row-content
  "The :flex-row preset has the expected properties."
  (let ((style (resolve-style-class :flex-row)))
    (is (eql :flex (getf style :display)))
    (is (eql :row (getf style :flex-direction)))))

(test builtin-bordered-content
  "The :bordered preset sets :border :single."
  (let ((style (resolve-style-class :bordered)))
    (is (eql :single (getf style :border)))))

;;;==============================================================
;;; 7. Theme integration
;;;==============================================================

(test apply-theme-registers-styles
  "apply-theme registers multiple named styles at once."
  (with-fresh-registry
    (apply-theme '(:th-title (:bold t :fg :cyan)
                   :th-muted (:dim t :fg :white)))
    (is (equal '(:bold t :fg :cyan) (resolve-style-class :th-title)))
    (is (equal '(:dim t :fg :white) (resolve-style-class :th-muted)))))

(test apply-theme-overwrites-existing
  "apply-theme overwrites previously registered styles."
  (with-fresh-registry
    (defstyle :th-x (:fg :red))
    (apply-theme '(:th-x (:fg :blue)))
    (is (eql :blue (getf (resolve-style-class :th-x) :fg)))))

;;;==============================================================
;;; 8. Edge cases
;;;==============================================================

(test empty-class-list
  "An empty class list resolves to an empty style."
  (with-fresh-registry
    (is (null (resolve-style-classes '())))))

(test class-with-nil-style-value
  "A style class may contain NIL values without error."
  (with-fresh-registry
    (defstyle :nil-val (:border nil :bold t))
    (let ((style (resolve-style-class :nil-val)))
      ;; NIL is a valid value; getf returns NIL for :border
      (is (null (getf style :border)))
      (is (eql t (getf style :bold))))))
