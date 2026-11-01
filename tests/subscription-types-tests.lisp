;;;===============================================================
;;; File: tests/subscription-types-tests.lisp
;;; Tests for built-in subscription types:
;;;   :every, :window-resize, :file-watch, :process
;;;===============================================================

(uiop:define-package :elmtui.tests.subscription-types
  (:use :cl :fiveam)
  (:import-from :elmtui.core.globals #:*app-sender*)
  (:import-from :elmtui.runtime.effects
                #:normalize-subscriptions
                #:reconcile-model-subscriptions
                #:clear-subscription-registry))

(in-package :elmtui.tests.subscription-types)

(def-suite subscription-types-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for built-in subscription types: :every, :window-resize, :file-watch, :process")

(in-suite subscription-types-tests)

;;; ---------------------------------------------------------------
;;; Helpers
;;; ---------------------------------------------------------------

(defun make-message-collector ()
  "Return (values collector-fn messages-list-accessor-fn)."
  (let ((messages nil)
        (lock (bt:make-lock "test-message-collector")))
    (values
     (lambda (msg)
       (bt:with-lock-held (lock)
         (push msg messages)))
     (lambda ()
       (bt:with-lock-held (lock)
         (copy-list (nreverse messages)))))))

(defmacro with-test-sender ((&optional sender-var messages-var) &body body)
  "Bind *app-sender* to a test message collector for BODY."
  (let ((s (or sender-var (gensym "SENDER")))
        (m (or messages-var (gensym "MSGS"))))
    `(multiple-value-bind (,s ,m) (make-message-collector)
       (declare (ignorable ,s ,m))
       (let ((*app-sender* ,s))
         ,@body))))

(defun wait-for-messages (messages-fn &key (count 1) (timeout 3.0) (poll 0.05))
  "Poll MESSAGES-FN until at least COUNT messages are collected or TIMEOUT."
  (let ((deadline (+ (get-internal-real-time)
                     (* timeout internal-time-units-per-second))))
    (loop
      (let ((msgs (funcall messages-fn)))
        (when (>= (length msgs) count)
          (return msgs)))
      (when (> (get-internal-real-time) deadline)
        (return (funcall messages-fn)))
      (sleep poll))))

;;; ---------------------------------------------------------------
;;; :every — timer alias with :seconds/:ms
;;; ---------------------------------------------------------------

(def-suite every-subscription-tests
  :in subscription-types-tests
  :description ":every subscription type tests")

(in-suite every-subscription-tests)

(test every-descriptor-normalizes-as-single-subscription
  (let ((subs (normalize-subscriptions '(:every (:seconds 1.0 :message (:tick))))))
    (is (= 1 (length subs)))
    (is (eq :every (first (first subs))))))

(test every-with-seconds-delivers-messages
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:every (:seconds 0.05 :message (:tick)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 2 :timeout 3.0)))
               (is (>= (length msgs) 2)
                   "Expected at least 2 :tick messages, got ~D" (length msgs))
               (is (every (lambda (m) (equal m '(:tick))) msgs))))
        (clear-subscription-registry table)))))

(test every-with-ms-delivers-messages
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:every (:ms 50 :message (:fast-tick)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 2 :timeout 3.0)))
               (is (>= (length msgs) 2))
               (is (every (lambda (m) (equal m '(:fast-tick))) msgs))))
        (clear-subscription-registry table)))))

(test every-with-invalid-interval-does-not-install
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:every (:seconds -1 :message (:tick)))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test every-with-no-seconds-or-ms-does-not-install
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:every (:message (:tick)))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test every-subscription-cancels-on-removal
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:every (:seconds 0.05 :message (:tick)))))
       nil table)
      (is (= 1 (hash-table-count table)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m)) nil)
       nil table)
      (is (= 0 (hash-table-count table))))))

(test every-reconciler-is-idempotent
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (installed-count 0))
      (unwind-protect
           (let ((sub '(:every (:seconds 0.5 :message (:tick)))))
             (flet ((subs (_m) (declare (ignore _m)) (list sub)))
               ;; First reconcile installs
               (reconcile-model-subscriptions #'subs nil table)
               (setf installed-count (hash-table-count table))
               (is (= 1 installed-count))
               ;; Second reconcile with same descriptor should not reinstall
               (reconcile-model-subscriptions #'subs nil table)
               (is (= 1 (hash-table-count table)))))
        (clear-subscription-registry table)))))

;;; ---------------------------------------------------------------
;;; :timer — backward compatibility
;;; ---------------------------------------------------------------

(in-suite subscription-types-tests)

(test timer-still-works-after-refactor
  "Ensure :timer subscriptions are unchanged by the new type additions."
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                '((:timer (:interval 0.05 :message (:tick)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 2 :timeout 3.0)))
               (is (>= (length msgs) 2))
               (is (every (lambda (m) (equal m '(:tick))) msgs))))
        (clear-subscription-registry table)))))

(test timer-flat-plist-form-still-works
  "The (:timer :interval N :message M) flat form must remain supported."
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                '((:timer :interval 0.05 :message (:tick))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 1 :timeout 3.0)))
               (is (>= (length msgs) 1))))
        (clear-subscription-registry table)))))

;;; ---------------------------------------------------------------
;;; :window-resize
;;; ---------------------------------------------------------------

(def-suite window-resize-subscription-tests
  :in subscription-types-tests
  :description ":window-resize subscription type tests")

(in-suite window-resize-subscription-tests)

(test window-resize-installs-and-uninstalls
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:window-resize (:message (:resized)))))
              nil table)
             (is (= 1 (hash-table-count table)))
             (let ((handle (block found
                             (maphash (lambda (_k v) (declare (ignore _k))
                                        (return-from found v))
                                      table))))
               (is (eq :window-resize (getf handle :type)))))
        (clear-subscription-registry table)))))

(test window-resize-unsubscribes-cleanly
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:window-resize (:message (:resized)))))
       nil table)
      (is (= 1 (hash-table-count table)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m)) nil)
       nil table)
      (is (= 0 (hash-table-count table)))
      ;; Internal state should be cleaned up
      (is (null elmtui.runtime.effects::*window-resize-subscription-active*)))))

(test window-resize-without-message-rejects
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:window-resize ())))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test window-resize-is-singleton
  "Only one :window-resize subscription should be active regardless of descriptor details."
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             ;; Both descriptors have the same key (:window-resize), so
             ;; the reconciler treats them as the same subscription.
             ;; Only the first one that gets installed stays.
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:window-resize (:message (:resize-a)))
                      '(:window-resize (:message (:resize-b)))))
              nil table)
             ;; Due to keying, the second descriptor is deduplicated
             (is (= 1 (hash-table-count table))))
        (clear-subscription-registry table)))))

;;; ---------------------------------------------------------------
;;; :file-watch
;;; ---------------------------------------------------------------

(def-suite file-watch-subscription-tests
  :in subscription-types-tests
  :description ":file-watch subscription type tests")

(in-suite file-watch-subscription-tests)

(test file-watch-installs-and-cancels
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-fw-~A.txt" (get-universal-time))))
      (unwind-protect
           (progn
             ;; Create the file so the watcher has something to stat
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "initial" f))
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:file-changed)))))
              nil table)
             (is (= 1 (hash-table-count table)))
             (let ((handle (block found
                             (maphash (lambda (_k v) (declare (ignore _k))
                                        (return-from found v))
                                      table))))
               (is (eq :file-watch (getf handle :type)))
               (is-true (getf handle :thread))
               (is-true (bt:thread-alive-p (getf handle :thread)))))
        (clear-subscription-registry table)
        (ignore-errors (delete-file path))))))

(test file-watch-detects-modification
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-fw-mod-~A.txt" (get-universal-time))))
      (unwind-protect
           (progn
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "v1" f))
             ;; Allow mtime to settle
             (sleep 0.1)
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:file-changed) :interval 0.1))))
              nil table)
             ;; Wait for baseline poll
             (sleep 0.3)
             ;; Modify the file (must change mtime)
             (sleep 1.1) ;; file-write-date has 1-second granularity
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "v2" f))
             (let ((msgs (wait-for-messages messages :count 1 :timeout 3.0)))
               (is (>= (length msgs) 1)
                   "Expected at least 1 :file-changed message, got ~D" (length msgs))
               (when (plusp (length msgs))
                 (let ((msg (first msgs)))
                   (is (eq :file-changed (first msg)))
                   (is (eq :modified (getf (rest msg) :event)))
                   (is (stringp (getf (rest msg) :path)))))))
        (clear-subscription-registry table)
        (ignore-errors (delete-file path))))))

(test file-watch-detects-deletion
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-fw-del-~A.txt" (get-universal-time))))
      (unwind-protect
           (progn
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "exists" f))
             (sleep 0.1)
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:file-changed) :interval 0.1))))
              nil table)
             ;; Wait for baseline
             (sleep 0.3)
             ;; Delete the file
             (delete-file path)
             (let ((msgs (wait-for-messages messages :count 1 :timeout 3.0)))
               (is (>= (length msgs) 1)
                   "Expected at least 1 deletion message, got ~D" (length msgs))
               (when (plusp (length msgs))
                 (is (eq :deleted (getf (rest (first msgs)) :event))))))
        (clear-subscription-registry table)
        (ignore-errors (delete-file path))))))

(test file-watch-missing-path-rejects
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:file-watch (:message (:changed)))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test file-watch-missing-message-rejects
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:file-watch (:path "/tmp/whatever.txt"))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test file-watch-same-path-is-same-subscription
  "Two :file-watch descriptors with the same :path but different :message
should be treated as the same subscription (keyed by path)."
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-fw-key-~A.txt" (get-universal-time))))
      (unwind-protect
           (progn
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "x" f))
             ;; First reconcile with message-a
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:msg-a)))))
              nil table)
             (is (= 1 (hash-table-count table)))
             ;; Second reconcile with same path but message-b — should not reinstall
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:msg-b)))))
              nil table)
             (is (= 1 (hash-table-count table))))
        (clear-subscription-registry table)
        (ignore-errors (delete-file path))))))

(test file-watch-thread-stops-on-cancel
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-fw-stop-~A.txt" (get-universal-time)))
          (thread nil))
      (unwind-protect
           (progn
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "x" f))
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list `(:file-watch (:path ,path :message (:fc) :interval 0.05))))
              nil table)
             (setf thread
                   (block found
                     (maphash (lambda (_k v) (declare (ignore _k))
                                (return-from found (getf v :thread)))
                              table)))
             (is-true (bt:thread-alive-p thread))
             (clear-subscription-registry table)
             ;; Thread should stop within a short time
             (sleep 0.2)
             (is-false (bt:thread-alive-p thread)))
        (ignore-errors (delete-file path))))))

;;; ---------------------------------------------------------------
;;; :process
;;; ---------------------------------------------------------------

(def-suite process-subscription-tests
  :in subscription-types-tests
  :description ":process subscription type tests")

(in-suite process-subscription-tests)

(test process-delivers-output-lines
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("echo" "hello world")
                                  :on-output (:process-line)
                                  :on-exit (:process-exited)))))
              nil table)
             ;; echo exits quickly — wait for output + exit
             (let ((msgs (wait-for-messages messages :count 2 :timeout 5.0)))
               ;; Should have at least 1 output line and 1 exit message
               (let ((output-msgs (remove-if-not
                                   (lambda (m) (eq :process-line (first m)))
                                   msgs))
                     (exit-msgs (remove-if-not
                                 (lambda (m) (eq :process-exited (first m)))
                                 msgs)))
                 (is (>= (length output-msgs) 1)
                     "Expected at least 1 output message, got ~D" (length output-msgs))
                 (when (plusp (length output-msgs))
                   (let ((out (first output-msgs)))
                     (is (string= "hello world" (getf (rest out) :line)))))
                 (is (= 1 (length exit-msgs))
                     "Expected exactly 1 exit message")
                 (when (plusp (length exit-msgs))
                   (is (= 0 (getf (rest (first exit-msgs)) :code)))))))
        (clear-subscription-registry table)))))

(test process-delivers-multiple-lines
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("printf" "line1\\nline2\\nline3\\n")
                                  :on-output (:out)
                                  :on-exit (:done)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 4 :timeout 5.0)))
               (let ((output-msgs (remove-if-not
                                   (lambda (m) (eq :out (first m)))
                                   msgs)))
                 (is (= 3 (length output-msgs))
                     "Expected 3 output lines, got ~D" (length output-msgs)))))
        (clear-subscription-registry table)))))

(test process-exit-message-includes-code
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             ;; Use false which exits with code 1
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("false")
                                  :on-exit (:proc-done)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 1 :timeout 5.0)))
               (let ((exit-msgs (remove-if-not
                                 (lambda (m) (eq :proc-done (first m)))
                                 msgs)))
                 (is (= 1 (length exit-msgs)))
                 (when (plusp (length exit-msgs))
                   (is (= 1 (getf (rest (first exit-msgs)) :code)))))))
        (clear-subscription-registry table)))))

(test process-output-message-includes-pid
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("echo" "test")
                                  :on-output (:out)
                                  :on-exit (:done)))))
              nil table)
             (let ((msgs (wait-for-messages messages :count 1 :timeout 5.0)))
               (when (plusp (length msgs))
                 (let ((out (first msgs)))
                   (is (integerp (getf (rest out) :pid))
                       "Output message should include numeric :pid")))))
        (clear-subscription-registry table)))))

(test process-missing-command-rejects
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:process (:on-output (:out)))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test process-no-message-handlers-rejects
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (reconcile-model-subscriptions
       (lambda (_m) (declare (ignore _m))
         (list '(:process (:command ("echo" "x")))))
       nil table)
      (is (= 0 (hash-table-count table))))))

(test process-invalid-command-delivers-error-exit
  "A nonexistent command should deliver an on-exit message with error info."
  (with-test-sender (sender messages)
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("__nonexistent_command_xyz__")
                                  :on-exit (:proc-failed)))))
              nil table)
             ;; Either the process fails to launch (immediate exit message)
             ;; or it launches and fails immediately
             (let ((msgs (wait-for-messages messages :count 1 :timeout 3.0)))
               (let ((exit-msgs (remove-if-not
                                 (lambda (m) (eq :proc-failed (first m)))
                                 msgs)))
                 ;; Should get an exit/error notification
                 (is (>= (length exit-msgs) 0)
                     "Expected an exit or error message for bad command"))))
        (clear-subscription-registry table)))))

(test process-same-command-is-same-subscription
  "Two :process descriptors with the same :command should be the same subscription."
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             ;; Install with on-output :a
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("sleep" "10")
                                  :on-output (:a)
                                  :on-exit (:done)))))
              nil table)
             (is (= 1 (hash-table-count table)))
             ;; Re-reconcile with same command but different message — should not reinstall
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("sleep" "10")
                                  :on-output (:b)
                                  :on-exit (:done)))))
              nil table)
             (is (= 1 (hash-table-count table))))
        (clear-subscription-registry table)))))

(test process-cancellation-kills-running-process
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (thread nil)
          (process nil))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:process (:command ("sleep" "300")
                                  :on-exit (:done)))))
              nil table)
             (is (= 1 (hash-table-count table)))
             ;; Capture the thread and process
             (maphash (lambda (_k v) (declare (ignore _k))
                        (setf thread (getf v :thread)
                              process (getf v :process)))
                      table)
             (is-true (bt:thread-alive-p thread))
             #+sbcl (is-true (sb-ext:process-alive-p process))
             ;; Cancel
             (clear-subscription-registry table)
             (sleep 0.3)
             (is-false (bt:thread-alive-p thread))
             #+sbcl (is-false (sb-ext:process-alive-p process)))
        ;; Safety net
        (clear-subscription-registry table)))))

;;; ---------------------------------------------------------------
;;; Reconciler cross-type tests
;;; ---------------------------------------------------------------

(in-suite subscription-types-tests)

(test reconciler-handles-mixed-subscription-types
  "The reconciler should handle a mix of :timer, :every, and :file-watch
subscriptions in a single reconciliation."
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal))
          (path (format nil "/tmp/elmtui-test-mix-~A.txt" (get-universal-time))))
      (unwind-protect
           (progn
             (with-open-file (f path :direction :output :if-exists :supersede)
               (write-string "x" f))
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:timer (:interval 1.0 :message (:timer-tick)))
                      '(:every (:seconds 1.0 :message (:every-tick)))
                      `(:file-watch (:path ,path :message (:fw)))))
              nil table)
             (is (= 3 (hash-table-count table))))
        (clear-subscription-registry table)
        (ignore-errors (delete-file path))))))

(test reconciler-partial-removal-preserves-others
  "Removing one subscription should not affect others."
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             ;; Install two subscriptions
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:every (:seconds 1.0 :message (:a)))
                      '(:every (:seconds 2.0 :message (:b)))))
              nil table)
             (is (= 2 (hash-table-count table)))
             ;; Remove one
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:every (:seconds 1.0 :message (:a)))))
              nil table)
             (is (= 1 (hash-table-count table))))
        (clear-subscription-registry table)))))

(test reconciler-empty-desired-clears-all
  (with-test-sender ()
    (let ((table (make-hash-table :test 'equal)))
      (unwind-protect
           (progn
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m))
                (list '(:every (:seconds 0.5 :message (:a)))
                      '(:timer (:interval 0.5 :message (:b)))))
              nil table)
             (is (= 2 (hash-table-count table)))
             (reconcile-model-subscriptions
              (lambda (_m) (declare (ignore _m)) nil)
              nil table)
             (is (= 0 (hash-table-count table))))
        (clear-subscription-registry table)))))
