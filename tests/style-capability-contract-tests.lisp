;;; CI-enforced single source of truth for ElmTUI terminal style capabilities.
(uiop:define-package :elmtui.tests.style-capability-contract
  (:use :cl :fiveam))
(in-package :elmtui.tests.style-capability-contract)

(def-suite style-capability-contract-suite :in elmtui.tests:elmtui-test
  :description "Every cl-styles property has one honest terminal support tier")
(in-suite style-capability-contract-suite)

(test all-canonical-properties-are-classified-exactly-once
  (let* ((groups elmtui.platform.tree-renderer::*style-property-capabilities*)
         (report (elmtui.platform.tree-renderer:style-property-capability-report))
         (all (loop for group in groups append (rest group))))
    (is (= 4 (length groups)))
    (is (equal '(:rendered :layout-only :metadata-only :unimplemented)
               (mapcar #'first groups)))
    (is (= (length all) (length (remove-duplicates all))))
    (is (= (length all) (length report)))
    (dolist (entry report)
      (is (member (cdr entry) '(:rendered :layout-only
                                :metadata-only :unimplemented)))
      (is (= 1 (count (car entry) all)))
      (is (eq (cdr entry)
              (elmtui.platform.tree-renderer:style-property-capability
               (car entry)))))
    (dolist (key all)
      (is (cl-styles.properties:property-definition key)))))

(test property-aliases-derive-same-tier-and-unknown-is-distinct
  (maphash
   (lambda (alias canonical)
     (is (eq (elmtui.platform.tree-renderer:style-property-capability alias)
             (elmtui.platform.tree-renderer:style-property-capability canonical))))
   cl-styles.properties::*property-aliases*)
  (is (null (elmtui.platform.tree-renderer:style-property-capability
             :not-a-real-style-property)))
  (is (eq :rendered
          (elmtui.platform.tree-renderer:style-property-capability :opacity)))
  (is (eq :rendered
          (elmtui.platform.tree-renderer:style-property-capability :z-index)))
  (is (eq :unimplemented
          (elmtui.platform.tree-renderer:style-property-capability
           :border-radius))))
