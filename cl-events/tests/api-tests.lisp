(in-package :cl-events.tests)

(def-suite :cl-events/api :in :cl-events/tests)
(in-suite :cl-events/api)

(test api-reexports-available
  (is (fboundp 'cl-events.api:make-event))
  (is (fboundp 'cl-events.api:make-channel))
  (is (fboundp 'cl-events.api:make-event-bus))
  (is (fboundp 'cl-events.api:run-app-loop)))
