(uiop:define-package #:elmtui.api
  (:use #:cl)
  (:import-from :log4cl #:log-debug #:log-error #:log-info)
  (:export #:dsl-type))

(in-package #:elmtui.api)

;; Import dsl-type from ui.dsl-resolution
(defgeneric dsl-type (type &optional props)
  (:documentation "Resolve DSL TYPE to a component class.
This generic function is the core of the polymorphic DSL resolution system.

Methods are defined per component or variant:
- Keywords resolve to classes
- Lists inject extra props
- Symbols terminate (are classes)

Returns (values class props)."))
