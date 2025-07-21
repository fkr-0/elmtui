(uiop:define-package #:elmtui.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:import-from #:elmtui.core.globals #:*applications* #:*dsl-type-to-component-class*)
  (:export #:get-component-class-for-dsl-type))

(in-package #:elmtui.api)

(defgeneric get-component-class-for-dsl-type (dsl-type)
  (:documentation "Return the class associated with the given DSL type."))
