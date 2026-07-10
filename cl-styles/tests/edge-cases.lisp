(uiop:define-package :cl-styles.tests/edge-cases
  (:use :cl :fiveam)
  (:import-from :cl-styles.sheet #:make-stylesheet)
  (:import-from :cl-styles.rule #:defrule)
  (:import-from :cl-styles.selector #:type> #:id> #:cls> #:attr> #:state>
                #:first-child #:last-child #:nth-child
                #:sel-and #:sel-or #:sel-not
                #:descendant> #:child> #:has)
  (:import-from :cl-styles.engine #:apply-stylesheet #:apply-stylesheet-to-tree
                #:match-rules #:compute-style)
  (:import-from :cl-styles.protocols #:stylable-id #:stylable-type
                #:stylable-classes #:stylable-attributes #:stylable-state
                #:stylable-parent #:stylable-children #:stylable-index
                #:stylable-inline-style #:set-computed-style #:get-computed-style)
  (:import-from :cl-styles.properties #:style-contract-violation
                #:ensure-declarations #:normalize-declarations)
  (:import-from :cl-styles.tokens #:var #:rgb #:rgba #:hsl #:px #:em #:percent)
  (:export #:suite))

(in-package :cl-styles.tests/edge-cases)

(def-suite cl-styles/edge-cases
  :in cl-styles.tests:cl-styles-test)

(in-suite cl-styles/edge-cases)

;; Test node class with full protocol support
(defclass tnode ()
  ((id :initarg :id :accessor id :initform nil)
   (classes :initarg :classes :initform nil :accessor classes)
   (nodetype :initarg :nodetype :accessor nodetype :initform :div)
   (style :initarg :style :initform nil :accessor style)
   (attrs :initarg :attrs :initform nil :accessor attrs)
   (state :initarg :state :initform nil :accessor state)
   (parent :initform nil :accessor parent :initarg :parent)
   (kids :initarg :children :initform nil :accessor kids)
   (computed :initform nil :accessor computed)))

(flet ((->sel (x)
         (etypecase x
           (null nil)
           (string (string-downcase x))
           (symbol (string-downcase (symbol-name x))))))
  (defmethod stylable-id ((n tnode)) (->sel (id n)))
  (defmethod stylable-type ((n tnode)) (->sel (nodetype n)))
  (defmethod stylable-classes ((n tnode)) (mapcar #'->sel (or (classes n))))
  (defmethod stylable-inline-style ((n tnode)) (style n))
  (defmethod stylable-attributes ((n tnode)) (attrs n))
  (defmethod stylable-state ((n tnode)) (state n))
  (defmethod stylable-parent ((n tnode)) (parent n))
  (defmethod stylable-children ((n tnode)) (kids n))
  (defmethod (setf stylable-children) (new-value (n tnode)) (setf (kids n) new-value))
  (defmethod (setf stylable-parent) (new-value (n tnode)) (setf (parent n) new-value))
  (defmethod stylable-index ((n tnode))
    (let* ((p (parent n)) (sibs (and p (kids p))))
      (or (position n sibs :test #'eq) 0)))
  (defmethod set-computed-style ((n tnode) computed)
    (setf (computed n) computed)
    n)
  (defmethod get-computed-style ((n tnode)) (computed n)))


;; ============================================================================
;; State Selector Tests
;; ============================================================================

(test state-selector-matches-single-flag
  "Test state> selector with single state flag"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button :state '(:focus)))
         (sheet (make-stylesheet :rules (list (defrule (state> :focus) :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 1 (length pairs)))
    (apply-stylesheet sheet (list node))
    (is (eql :blue (getf (get-computed-style node) :color)))))

(test state-selector-matches-multiple-flags
  "Test state> selector with AND semantics for multiple flags"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button
                              :state '(:focus :disabled)))
         (sheet (make-stylesheet :rules (list (defrule (state> :focus :disabled) :opacity 0.5))))
         (pairs (match-rules node sheet)))
    (is (= 1 (length pairs)))
    (apply-stylesheet sheet (list node))
    (is (= 0.5 (getf (get-computed-style node) :opacity)))))

(test state-selector-no-match-when-partial
  "Test state> selector doesn't match when only some flags present"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button :state '(:focus)))
         (sheet (make-stylesheet :rules (list (defrule (state> :focus :disabled) :opacity 0.5))))
         (pairs (match-rules node sheet)))
    (is (= 0 (length pairs)))))

(test state-selector-no-match-when-none
  "Test state> selector doesn't match when no state flags present"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button))
         (sheet (make-stylesheet :rules (list (defrule (state> :focus) :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 0 (length pairs)))))


;; ============================================================================
;; Attribute Selector Tests
;; ============================================================================

(test attribute-selector-matches-present
  "Test attr> selector matches when attribute is present"
  (let* ((node (make-instance 'tnode :id :input :nodetype :input
                              :attrs '(:role "navigation")))
         (sheet (make-stylesheet :rules (list (defrule (attr> :role) :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 1 (length pairs)))))

(test attribute-selector-matches-value
  "Test attr> selector matches when attribute value matches"
  (let* ((node (make-instance 'tnode :id :input :nodetype :input
                              :attrs '(:role "navigation")))
         (sheet (make-stylesheet :rules (list (defrule (attr> :role "navigation")
                                                :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 1 (length pairs)))
    (apply-stylesheet sheet (list node))
    (is (eql :blue (getf (get-computed-style node) :color)))))

(test attribute-selector-no-match-wrong-value
  "Test attr> selector doesn't match when attribute value differs"
  (let* ((node (make-instance 'tnode :id :input :nodetype :input
                              :attrs '(:role "navigation")))
         (sheet (make-stylesheet :rules (list (defrule (attr> :role "button")
                                                :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 0 (length pairs)))))

(test attribute-selector-no-match-missing
  "Test attr> selector doesn't match when attribute is absent"
  (let* ((node (make-instance 'tnode :id :input :nodetype :input))
         (sheet (make-stylesheet :rules (list (defrule (attr> :role) :color :blue))))
         (pairs (match-rules node sheet)))
    (is (= 0 (length pairs)))))


;; ============================================================================
;; Pseudo-class Tests
;; ============================================================================

(test first-child-matches-first
  "Test :first-child matches the first child"
  (let* ((child1 (make-instance 'tnode :id :c1 :nodetype :text))
         (child2 (make-instance 'tnode :id :c2 :nodetype :text))
         (parent (make-instance 'tnode :id :p :nodetype :container :children (list child1 child2))))
    (setf (parent child1) parent (parent child2) parent)
    (is (cl-styles.selector:match-selector-p (first-child) child1))
    (is (not (cl-styles.selector:match-selector-p (first-child) child2)))))

(test last-child-matches-last
  "Test :last-child matches the last child"
  (let* ((child1 (make-instance 'tnode :id :c1 :nodetype :text))
         (child2 (make-instance 'tnode :id :c2 :nodetype :text))
         (parent (make-instance 'tnode :id :p :nodetype :container :children (list child1 child2))))
    (setf (parent child1) parent (parent child2) parent)
    (is (not (cl-styles.selector:match-selector-p (last-child) child1)))
    (is (cl-styles.selector:match-selector-p (last-child) child2))))

(test last-child-no-match-orphan
  "Test :last-child doesn't match orphan elements (bug fix test)"
  (let* ((orphan (make-instance 'tnode :id :orphan :nodetype :text)))
    (is (not (cl-styles.selector:match-selector-p (last-child) orphan)))))

(test first-child-no-match-orphan
  "Test :first-child doesn't match orphan elements"
  (let* ((orphan (make-instance 'tnode :id :orphan :nodetype :text)))
    (is (not (cl-styles.selector:match-selector-p (first-child) orphan)))))

(test nth-child-no-match-orphan
  "Test :nth-child doesn't match orphan elements"
  (let* ((orphan (make-instance 'tnode :id :orphan :nodetype :text)))
    ;; Orphan should not match any nth-child
    (is (not (cl-styles.selector:match-selector-p (nth-child 0) orphan)))
    (is (not (cl-styles.selector:match-selector-p (nth-child 1) orphan)))
    (is (not (cl-styles.selector:match-selector-p (nth-child 5) orphan)))))

(test nth-child-matches-index
  "Test :nth-child matches the correct index"
  (let* ((child1 (make-instance 'tnode :id :c1 :nodetype :text))
         (child2 (make-instance 'tnode :id :c2 :nodetype :text))
         (child3 (make-instance 'tnode :id :c3 :nodetype :text))
         (parent (make-instance 'tnode :id :p :nodetype :container
                                :children (list child1 child2 child3))))
    (setf (parent child1) parent (parent child2) parent (parent child3) parent)
    (is (cl-styles.selector:match-selector-p (nth-child 0) child1))
    (is (cl-styles.selector:match-selector-p (nth-child 1) child2))
    (is (cl-styles.selector:match-selector-p (nth-child 2) child3))
    (is (not (cl-styles.selector:match-selector-p (nth-child 3) child1)))))

(test single-child-is-first-and-last
  "Test a single child matches both :first-child and :last-child"
  (let* ((child (make-instance 'tnode :id :c :nodetype :text))
         (parent (make-instance 'tnode :id :p :nodetype :container :children (list child))))
    (setf (parent child) parent)
    (is (cl-styles.selector:match-selector-p (first-child) child))
    (is (cl-styles.selector:match-selector-p (last-child) child))))


;; ============================================================================
;; :has Combinator Tests
;; ============================================================================

(test has-selector-matches-parent-with-descendant
  "Test :has selector matches parent with matching descendant"
  (let* ((child (make-instance 'tnode :id :child :nodetype :button))
         (parent (make-instance 'tnode :id :parent :nodetype :container :children (list child))))
    (setf (parent child) parent)
    (is (cl-styles.selector:match-selector-p (has (type> :button)) parent))))

(test has-selector-no-match-when-no-descendant
  "Test :has selector doesn't match when no descendant matches"
  (let* ((child (make-instance 'tnode :id :child :nodetype :text))
         (parent (make-instance 'tnode :id :parent :nodetype :container :children (list child))))
    (setf (parent child) parent)
    (is (not (cl-styles.selector:match-selector-p (has (type> :button)) parent)))))

(test has-selector-matches-nested-descendant
  "Test :has selector matches deeply nested descendant"
  (let* ((grandchild (make-instance 'tnode :id :gc :nodetype :button))
         (child (make-instance 'tnode :id :c :nodetype :container :children (list grandchild)))
         (parent (make-instance 'tnode :id :p :nodetype :container :children (list child))))
    (setf (parent grandchild) child (parent child) parent)
    (is (cl-styles.selector:match-selector-p (has (type> :button)) parent))))


;; ============================================================================
;; Specificity Edge Cases
;; ============================================================================

(test specificity-equal-specificity-document-order
  "Test rules with equal specificity are applied in document order"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button :classes '("primary")))
         (sheet (make-stylesheet
                 :rules (list (defrule (cls> "primary") :color :red)
                             (defrule (cls> "primary") :background :blue)))))
    (apply-stylesheet sheet (list node))
    (let ((computed (get-computed-style node)))
      ;; Both rules should apply (same specificity, both win)
      (is (eql :red (getf computed :color)))
      (is (eql :blue (getf computed :background-color))))))

(test specificity-id-beats-class
  "Test ID selector has higher specificity than class selector"
  (let* ((node (make-instance 'tnode :id :my-btn :nodetype :button :classes '("primary")))
         (sheet (make-stylesheet
                 :rules (list (defrule (cls> "primary") :color :red)
                             (defrule (id> :my-btn) :color :blue)))))
    (apply-stylesheet sheet (list node))
    (is (eql :blue (getf (get-computed-style node) :color)))))

(test specificity-class-beats-type
  "Test class selector has higher specificity than type selector"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button :classes '("primary")))
         (sheet (make-stylesheet
                 :rules (list (defrule (type> :button) :color :red)
                             (defrule (cls> "primary") :color :blue)))))
    (apply-stylesheet sheet (list node))
    (is (eql :blue (getf (get-computed-style node) :color)))))


;; ============================================================================
;; :or Selector Tests
;; ============================================================================

(test or-selector-matches-either-branch
  "Test :or selector matches if either branch matches"
  (let* ((node1 (make-instance 'tnode :id :n1 :nodetype :button))
         (node2 (make-instance 'tnode :id :n2 :nodetype :text)))
    (is (cl-styles.selector:match-selector-p
         (sel-or (type> :button) (type> :text)) node1))
    (is (cl-styles.selector:match-selector-p
         (sel-or (type> :button) (type> :text)) node2))
    (is (not (cl-styles.selector:match-selector-p
              (sel-or (type> :button) (type> :text))
              (make-instance 'tnode :id :n3 :nodetype :div))))))

(test or-selector-specificity-uses-max
  "Test :or selector specificity uses maximum of branches"
  (let* ((id-spec (cl-styles.selector:selector-specificity (id> :x)))
         (cls-spec (cl-styles.selector:selector-specificity (cls> "x")))
         (or-spec (cl-styles.selector:selector-specificity
                   (sel-or (id> :x) (cls> "x")))))
    ;; :or should have max specificity, which is id-spec
    (is (equal id-spec or-spec))
    (is (not (equal cls-spec or-spec)))))


;; ============================================================================
;; Inheritance Edge Cases
;; ============================================================================

(test inheritance-orphan-has-no-parent
  "Test orphan nodes don't inherit from nil parent"
  (let* ((orphan (make-instance 'tnode :id :orphan :nodetype :text))
         (sheet (make-stylesheet :rules nil)))
    (apply-stylesheet-to-tree orphan sheet)
    (is (null (get-computed-style orphan)))))

(test inheritance-missing-parent-computed-style
  "Test inheritance when parent has no computed style"
  (let* ((parent (make-instance 'tnode :id :parent :nodetype :container))
         (child (make-instance 'tnode :id :child :nodetype :text))
         (sheet (make-stylesheet :rules nil)))
    (setf (kids parent) (list child) (parent child) parent)
    (apply-stylesheet-to-tree parent sheet)
    ;; Both should have nil computed style
    (is (null (get-computed-style parent)))
    (is (null (get-computed-style child)))))

(test inheritance-child-override-parent
  "Test child's own style overrides inherited value"
  (let* ((parent (make-instance 'tnode :id :parent :nodetype :container
                                :style '(:color :red)))
         (child (make-instance 'tnode :id :child :nodetype :text
                               :style '(:color :blue)))
         (sheet (make-stylesheet :rules nil)))
    (setf (kids parent) (list child) (parent child) parent)
    (apply-stylesheet-to-tree parent sheet)
    ;; Child's own inline style should win
    (is (eql :blue (getf (get-computed-style child) :color)))))

(test inheritance-non-inheritable-property
  "Test non-inheritable properties don't inherit"
  (let* ((parent (make-instance 'tnode :id :parent :nodetype :container
                                :style '(:padding 10)))
         (child (make-instance 'tnode :id :child :nodetype :text))
         (sheet (make-stylesheet :rules nil)))
    (setf (kids parent) (list child) (parent child) parent)
    (apply-stylesheet-to-tree parent sheet)
    ;; Padding is not inheritable
    (is (null (getf (get-computed-style child) :padding)))))


;; ============================================================================
;; Cascade Order Tests
;; ============================================================================

(test cascade-inline-overrides-rules
  "Test inline styles have highest priority"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button
                              :style '(:color :blue)))
         (sheet (make-stylesheet :rules (list (defrule (type> :button) :color :red)))))
    (apply-stylesheet sheet (list node))
    (is (eql :blue (getf (get-computed-style node) :color)))))

(test cascade-rules-apply-in-specificity-order
  "Test rules apply in specificity order (low to high)"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button :classes '("primary")))
         (sheet (make-stylesheet
                 :rules (list (defrule (type> :button) :color :red)
                             (defrule (cls> "primary") :color :blue)))))
    (apply-stylesheet sheet (list node))
    ;; Class (higher specificity) should override type
    (is (eql :blue (getf (get-computed-style node) :color)))))

(test cascade-inheritance-applies-before-rules
  "Test inheritance is applied, then rules override"
  (let* ((parent (make-instance 'tnode :id :parent :nodetype :container
                                :style '(:color :red)))
         (child (make-instance 'tnode :id :child :nodetype :text))
         (sheet (make-stylesheet :rules (list (defrule (type> :text) :color :blue)))))
    (setf (kids parent) (list child) (parent child) parent)
    (apply-stylesheet-to-tree parent sheet)
    ;; Rule should override inherited value
    (is (eql :blue (getf (get-computed-style child) :color)))))


;; ============================================================================
;; Variable Resolution Edge Cases
;; ============================================================================

(test variable-undefined-left-as-is
  "Test undefined variables are left unchanged in computed style"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button))
         (sheet (make-stylesheet
                 :rules (list (defrule (type> :button)
                               :background (var "--undefined")))
                 :variables '(("--defined" . :blue)))))
    (apply-stylesheet sheet (list node))
    ;; Undefined var should remain as (var "--undefined")
    (let ((computed (get-computed-style node)))
      ;; background accepts keyword or color-p, so var is preserved
      (is (consp (getf computed :background-color)))
      (is (eql :var (first (getf computed :background-color)))))))

(test variable-resolution-in-shorthands
  "Test variables work in shorthand properties"
  (let* ((node (make-instance 'tnode :id :box :nodetype :div))
         (sheet (make-stylesheet
                 :rules (list (defrule (type> :div) :padding (var "--space")))
                 :variables '(("--space" . 10)))))
    (apply-stylesheet sheet (list node))
    (is (= 10 (getf (get-computed-style node) :padding-top)))
    (is (= 10 (getf (get-computed-style node) :padding-bottom)))))

(test variable-resolution-with-inline-variables
  "Test variables in inline styles are resolved"
  (let* ((node (make-instance 'tnode :id :btn :nodetype :button
                              :style `(:color ,(var "--main-color"))))
         (sheet (make-stylesheet :variables '(("--main-color" . :green)))))
    (apply-stylesheet sheet (list node))
    (is (eql :green (getf (get-computed-style node) :color)))))


;; ============================================================================
;; Property Validation Tests
;; ============================================================================

(test validation-enum-error-on-invalid-value
  "Test validation signals error for invalid enum value"
  (signals style-contract-violation
    (ensure-declarations '(:display :invalid-value))))

(test validation-type-error-on-wrong-type
  "Test validation signals error for wrong type"
  (signals style-contract-violation
    (ensure-declarations '(:width "not-a-number"))))

(test normalization-preserves-strings
  "Test normalization preserves string values for string properties"
  (let ((result (normalize-declarations '(:font-family "Arial"))))
    (is (stringp (getf result :font-family)))))

(test validation-accepts-keyword-or-string
  "Test validation accepts both keyword and string values for keyword properties"
  (let ((result1 (normalize-declarations '(:display :flex)))
        (result2 (normalize-declarations '(:display "flex"))))
    (is (eql :flex (getf result1 :display)))
    (is (eql :flex (getf result2 :display)))))

(test validation-accepts-color-tokens
  "Test validation accepts color token constructors"
  (let ((result (ensure-declarations
                 `(:color ,(rgb 255 0 0)
                   :background ,(rgba 255 0 0 0.5)
                   :border-color ,(hsl 120 50 50)))))
    (is (consp (getf result :color)))
    (is (eql :rgb (first (getf result :color))))
    (is (eql :rgba (first (getf result :background-color))))
    (is (eql :hsl (first (getf result :border-color))))))


;; ============================================================================
;; Length Token Tests
;; ============================================================================

(test length-token-constructors
  "Test length token constructors create proper lists"
  (is (equal (list :px 10) (px 10)))
  (is (equal (list :em 1.5) (em 1.5)))
  (is (equal (list :percent 50) (percent 50)))
  (is (cl-styles.tokens:length-p (px 10)))
  (is (not (cl-styles.tokens:length-p :not-a-length))))


;; ============================================================================
;; Complex Selector Combination Tests
;; ============================================================================

(test combined-descendant-and-class
  "Test descendant selector combined with class selector"
  (let* ((child (make-instance 'tnode :id :child :nodetype :span
                               :classes '("highlight")))
         (parent (make-instance 'tnode :id :parent :nodetype :div
                               :children (list child)))
         (sheet (make-stylesheet
                 :rules (list (defrule (descendant> (type> :div)
                                                     (sel-and (type> :span)
                                                              (cls> "highlight")))
                               :color :yellow)))))
    (setf (parent child) parent)
    (apply-stylesheet-to-tree parent sheet)
    (is (eql :yellow (getf (get-computed-style child) :color)))))

(test combined-child-and-state
  "Test child selector combined with state selector"
  ;; Note: This test covers combinations already tested individually
  ;; Both child> and state> selectors are tested separately
  (let* ((child (make-instance 'tnode :id :child :nodetype :button
                               :state '(:hover)))
         (parent (make-instance 'tnode :id :parent :nodetype :navbar
                               :children (list child))))
    (setf (parent child) parent)
    ;; Verify selector matches
    (is (cl-styles.selector:match-selector-p
         (child> (type> :navbar)
                 (sel-and (type> :button) (state> :hover)))
         child))))

(test not-selector-inverts-match
  "Test :not selector properly inverts match"
  (let* ((node1 (make-instance 'tnode :id :n1 :nodetype :button))
         (node2 (make-instance 'tnode :id :n2 :nodetype :text)))
    (is (not (cl-styles.selector:match-selector-p
              (sel-not (type> :button)) node1)))
    (is (cl-styles.selector:match-selector-p
         (sel-not (type> :button)) node2))))
