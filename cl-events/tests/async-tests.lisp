(in-package :cl-events.tests)

(def-suite :cl-events/async :in :cl-events/tests)
(in-suite :cl-events/async)

(test spawn-task-returns-thread
  (let ((th (spawn-task (lambda () nil) :name "test")))
    (is (bt:threadp th))))

(test future-await-roundtrip
  (let ((mb (future (lambda () 42))))
    (is (= 42 (await mb)))))

(test cancel-destroys-thread
  (let ((th (spawn-task (lambda () (sleep 10)) :name "sleep")))
    (is (cancel th))))

(test schedule-after-returns-thread
  (let ((th (schedule-after 0.01 (lambda () nil))))
    (is (bt:threadp th))))

(test schedule-every-returns-thread
  (let ((th (schedule-every 0.01 (lambda () nil))))
    (is (bt:threadp th))))

(test promise-resolve-await
  (let ((p (cl-events.async:make-promise)))
    (cl-events.async:resolve-promise p 42)
    (is (= 42 (cl-events.async:await p)))))

(test async-task-basic
  (let* ((task (cl-events.async:new-task (lambda () 7)))
         (started (cl-events.async:async-exec task)))
    (is (not (null started)))
    (is (= 7 (cl-events.async:await task)))))

(test promise-chain-basic
  (let* ((p (cl-events.async:make-promise))
         (p2 (cl-events.async:chain p (lambda (v) (+ v 1)))))
    (cl-events.async:resolve-promise p 41)
    (is (= 42 (cl-events.async:await p2)))))

(test promise-all-mixed
  (let* ((p1 (cl-events.async:make-promise))
         (t2 (cl-events.async:new-task (lambda () 2)))
         (all (cl-events.async:all (list p1 t2))))
    (cl-events.async:async-exec t2)
    (cl-events.async:resolve-promise p1 1)
    (is (equal '(1 2) (cl-events.async:await all)))))

(test promise-race-mixed
  (let* ((p1 (cl-events.async:make-promise))
         (t2 (cl-events.async:new-task (lambda () (sleep 0.02) 2)))
         (race (cl-events.async:race (list p1 t2))))
    (cl-events.async:async-exec t2)
    (cl-events.async:resolve-promise p1 9)
    (is (= 9 (cl-events.async:await race)))))
