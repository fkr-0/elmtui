(in-package :cl-events.tests)

(def-suite :cl-events/channel :in :cl-events/tests)
(in-suite :cl-events/channel)

(test channel-put-take
  (let ((ch (make-channel :capacity 2)))
    (is (chan-put ch :a))
    (is (chan-put ch :b))
    (is (eql :a (chan-take ch)))
    (is (eql :b (chan-take ch)))))

(test channel-close-behavior
  (let ((ch (make-channel :capacity 1)))
    (is (chan-close ch))
    (is (null (chan-put ch :x)))
    (multiple-value-bind (val status)
        (chan-take ch)
      (is (null val))
      (is (eql :closed status)))))

(test mailbox-roundtrip
  (let ((mb (make-mailbox)))
    (is (mb-empty-p mb))
    (is (mb-put mb :hello))
    (is (not (mb-empty-p mb)))
    (is (eql :hello (mb-take mb)))
    (is (mb-empty-p mb))))

(test channel-no-wait
  (let ((ch (make-channel :capacity 1)))
    (multiple-value-bind (val okp)
        (cl-events.channel:no-wait ch :send nil)
      (is (not okp))
      (is (null val)))))

(test channel-put-take-bang
  (let ((ch (make-channel :capacity 1)))
    (is (cl-events.channel:channel-put! ch :x))
    (is (eql :x (cl-events.channel:channel-take! ch)))))

(test filtered-channel-drops
  (let ((ch (cl-events.channel:make-filtered-channel
             :filters (list (lambda (v) (eql v :ok))))))
    (cl-events.channel:chan-put ch :bad)
    (cl-events.channel:chan-put ch :ok)
    (is (eql :ok (cl-events.channel:chan-take ch)))))

(test select-receive
  (let ((ch (make-channel :capacity 1)))
    (cl-events.channel:chan-put ch :z)
    (multiple-value-bind (data src)
        (cl-events.channel:select (cl-events.channel:<- ch))
      (is (eql :z data))
      (is (eq ch src)))))
