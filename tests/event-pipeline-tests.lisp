(uiop:define-package :elmtui.tests.event-pipeline
  (:use :cl :fiveam)
  (:import-from :elmtui.core.event-pipeline
                #:make-pipeline
                #:process-event
                #:filter-pipe
                #:transform-pipe
                #:conditional-pipe))

(in-package :elmtui.tests.event-pipeline)

(def-suite event-pipeline-tests
  :in elmtui.tests:elmtui-test)
(in-suite event-pipeline-tests)

(test pipeline-processes-transform-chain
  (let* ((pipeline (make-pipeline :pipes
                                  (list
                                   (make-instance 'transform-pipe
                                                  :transform (lambda (evt)
                                                               (+ evt 1)))
                                   (make-instance 'transform-pipe
                                                  :transform (lambda (evt)
                                                               (* evt 2)))))))
    (is (= 8 (process-event pipeline 3)))))

(test pipeline-stops-on-nil-when-not-fallthrough
  (let* ((ran-transform nil)
         (pipeline (make-pipeline
                    :fallthrough nil
                    :pipes (list
                            (make-instance 'filter-pipe
                                           :filter (lambda (_evt)
                                                     (declare (ignore _evt))
                                                     nil))
                            (make-instance 'transform-pipe
                                           :transform (lambda (evt)
                                                        (setf ran-transform t)
                                                        evt))))))
    (is-false (process-event pipeline :event))
    (is-false ran-transform)))

(test conditional-pipe-selects-then-and-else
  (let* ((then-pipe (make-instance 'transform-pipe
                                   :transform (lambda (_evt)
                                                (declare (ignore _evt))
                                                :then)))
         (else-pipe (make-instance 'transform-pipe
                                   :transform (lambda (_evt)
                                                (declare (ignore _evt))
                                                :else)))
         (pipe (make-instance 'conditional-pipe
                              :condition (lambda (evt)
                                           (eq evt :ok))
                              :then then-pipe
                              :else else-pipe))
         (pipeline (make-pipeline :pipes (list pipe))))
    (is (eq :then (process-event pipeline :ok)))
    (is (eq :else (process-event pipeline :nope)))))
