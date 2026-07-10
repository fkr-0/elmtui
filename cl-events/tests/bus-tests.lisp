(in-package :cl-events.tests)

(def-suite :cl-events/bus :in :cl-events/tests)
(in-suite :cl-events/bus)

(defstruct test-event topic payload)

(defmethod cl-events.protocols:event-topic ((evt test-event))
  (test-event-topic evt))

(test subscribe-publish-roundtrip
  (let* ((bus (make-event-bus))
         (ch (subscribe bus :topic))
         (evt (make-test-event :topic :topic :payload 1)))
    (is (publish-event bus evt))
    (is (eq evt (chan-take ch)))))

(test unsubscribe-stops-delivery
  (let* ((bus (make-event-bus))
         (ch (subscribe bus :topic))
         (evt (make-test-event :topic :topic :payload 2)))
    (unsubscribe bus :topic ch)
    (publish-event bus evt)
    (let* ((queue (slot-value ch 'cl-events.channel::queue))
           (count (fill-pointer queue)))
      (is (= 0 count)))))
