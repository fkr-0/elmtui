(uiop:define-package :cl-styles.tests/properties
  (:use :cl :fiveam)
  (:import-from :cl-styles.api)
  (:export))

(in-package :cl-styles.tests/properties)

(def-suite cl-styles/properties
  :in cl-styles.tests:cl-styles-test)

(in-suite cl-styles/properties)

(test groups-and-layouts
      (let* ((pad (cl-styles.properties:properties-for-group :padding))
             (mg  (cl-styles.properties:properties-for-group :margin))
             (box (cl-styles.properties:properties-for-group :box))
             (flex (cl-styles.properties:properties-for-layout :flex))
             (grid (cl-styles.properties:properties-for-layout :grid)))
        (is (member :padding-left pad))
        (is (member :margin-right mg))
        (is (member :border-top-width box))
        (is (member :flex-direction flex))
        (is (member :grid-template-columns grid))))

(test property-normalization-and-validation
      (let* ((decls '(:align-items :start :flex-direction "row" :grid-auto-flow :row-dense :width 10))
             (ens   (cl-styles.properties:ensure-declarations decls)))
        (is (eql :flex-start (getf ens :align-items)))
        (is (eql :row (getf ens :flex-direction)))
        (is (eql :row-dense (getf ens :grid-auto-flow)))
        (is (= 10 (getf ens :width))))
      ;; invalid enum should signal
      (is (signals cl-styles.properties:style-contract-violation
                   (cl-styles.properties:ensure-declarations '(:display :weird)))))

(test shorthands-flex-and-gap
      (let* ((decl '(:flex (2 3 4) :gap (1 2)))
             (exp  (cl-styles.rule:expand-shorthands decl)))
        (is (= 2 (getf exp :flex-grow)))
        (is (= 3 (getf exp :flex-shrink)))
        (is (= 4 (getf exp :flex-basis)))
        (is (= 1 (getf exp :row-gap)))
        (is (= 2 (getf exp :column-gap)))))

(test border-shorthand
      (let* ((decl `(:border (2 :solid ,(cl-styles.tokens:rgb 255 0 0))))
             (exp  (cl-styles.rule:expand-shorthands decl)))
        (is (= 2 (getf exp :border-top-width)))
        (is (eql :solid (getf exp :border-left-style)))
        (is (equal (cl-styles.tokens:rgb 255 0 0) (getf exp :border-right-color)))))
