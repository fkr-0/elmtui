;;;; API Tests
;;;; Tests for the core elmtui.api module

(uiop:define-package :elmtui-tests.api
  (:use :cl :fiveam)
  (:import-from :elmtui.api #:dsl-type)
  (:export #:api-suite))

(in-package :elmtui-tests.api)

(def-suite api-suite
  :in elmtui.tests:elmtui-test
  :description "Test suite for core API")

(in-suite api-suite)

(test dsl-type-generic-exported
  "dsl-type generic is exported from elmtui.api"
  (is (fboundp 'elmtui.api:dsl-type))
  (is (symbol-package 'elmtui.api:dsl-type)))
