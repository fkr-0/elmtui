(uiop:define-package :elmtui.tests.diff-renderer
  (:use :cl :fiveam
        :elmtui.platform.backend.common.virtual-buffer
   :elmtui.platform.backend.terminal.diff-renderer)
  (:export #:elmtui.diff-renderer-suite))

(in-package :elmtui.tests.diff-renderer)

(def-suite elmtui.diff-renderer-suite
  :description "Tests for the diffing renderer.")

(in-suite elmtui.diff-renderer-suite)

(test compute-buffer-diff-identical-buffers
  "Test `compute-buffer-diff` returns empty list for identical buffers."
  (let* ((buffer-a (make-virtual-buffer 5 3))
         (buffer-b (copy-virtual-buffer buffer-a)))
    (is (null (compute-buffer-diff buffer-a buffer-b)))))

(test compute-buffer-diff-single-cell-change
  "Test `compute-buffer-diff` for a single cell change."
  (let* ((front (make-virtual-buffer 3 2))
         (back (copy-virtual-buffer front)))
    ;; Change char only
    (set-buffer-cell-at back 0 0 #\X nil)
    (is (equalp (compute-buffer-diff front back)
                '((:type :write-chars :row 0 :start-col 0 :chars "X" :style nil))))

    ;; Change style only
    (let* ((front-style (make-virtual-buffer 3 2))
           (back-style (copy-virtual-buffer front-style)))
      (set-buffer-cell-at back-style 1 1 #\Space '(:fg :red))
      (is (equalp (compute-buffer-diff front-style back-style)
                  '((:type :write-chars :row 1 :start-col 1 :chars " " :style '(:fg :red))))))

    ;; Change both char and style
    (let* ((front-both (make-virtual-buffer 3 2))
           (back-both (copy-virtual-buffer front-both)))
      (set-buffer-cell-at back-both 0 2 #\Y '(:bg :blue))
      (is (equalp (compute-buffer-diff front-both back-both)
                  '((:type :write-chars :row 0 :start-col 2 :chars "Y" :style '(:bg :blue))))))))

(test compute-buffer-diff-multiple-disjoint-changes
  "Test `compute-buffer-diff` for multiple disjoint cell changes."
  (let* ((front (make-virtual-buffer 5 5))
         (back (copy-virtual-buffer front)))
    (set-buffer-cell-at back 0 0 #\A '(:s1))
    (set-buffer-cell-at back 2 2 #\B '(:s2))
    (set-buffer-cell-at back 4 4 #\C '(:s3))
    (let ((diff (compute-buffer-diff front back)))
      (is (= (length diff) 3))
      (is (member '(:type :write-chars :row 0 :start-col 0 :chars "A" :style '(:s1)) diff :test #'equalp))
      (is (member '(:type :write-chars :row 2 :start-col 2 :chars "B" :style '(:s2)) diff :test #'equalp))
      (is (member '(:type :write-chars :row 4 :start-col 4 :chars "C" :style '(:s3)) diff :test #'equalp)))))

(test compute-buffer-diff-contiguous-changes-same-style
  "Test `compute-buffer-diff` batches contiguous changes with the same style."
  (let* ((front (make-virtual-buffer 5 1))
         (back (copy-virtual-buffer front)))
    (set-buffer-cell-at back 0 1 #\E '(:batch))
    (set-buffer-cell-at back 0 2 #\L '(:batch))
    (set-buffer-cell-at back 0 3 #\M '(:batch))
    (let ((diff (compute-buffer-diff front back)))
      (is (= (length diff) 1))
      (is (equalp (first diff)
                  '(:type :write-chars :row 0 :start-col 1 :chars "ELM" :style '(:batch)))))))

(test compute-buffer-diff-contiguous-changes-different-styles
  "Test `compute-buffer-diff` creates separate ops for contiguous changes with different styles."
  (let* ((front (make-virtual-buffer 5 1))
         (back (copy-virtual-buffer front)))
    (set-buffer-cell-at back 0 1 #\A '(:s1))
    (set-buffer-cell-at back 0 2 #\B '(:s2))
    (set-buffer-cell-at back 0 3 #\C '(:s1))
    (let ((diff (compute-buffer-diff front back)))
      (is (= (length diff) 3))
      (is (equalp (nth 0 diff) '(:type :write-chars :row 0 :start-col 1 :chars "A" :style '(:s1))))
      (is (equalp (nth 1 diff) '(:type :write-chars :row 0 :start-col 2 :chars "B" :style '(:s2))))
      (is (equalp (nth 2 diff) '(:type :write-chars :row 0 :start-col 3 :chars "C" :style '(:s1)))))))

(test compute-buffer-diff-full-buffer-change
  "Test `compute-buffer-diff` for a full buffer change."
  (let* ((front (make-virtual-buffer 2 2))
         (back (make-virtual-buffer 2 2)))
    (set-buffer-cell-at back 0 0 #\1 '(:s1))
    (set-buffer-cell-at back 0 1 #\2 '(:s2))
    (set-buffer-cell-at back 1 0 #\3 '(:s3))
    (set-buffer-cell-at back 1 1 #\4 '(:s4))
    (let ((diff (compute-buffer-diff front back)))
      (is (= (length diff) 4)) ; Expect 4 separate ops due to different styles
      (is (member '(:type :write-chars :row 0 :start-col 0 :chars "1" :style '(:s1)) diff :test #'equalp))
      (is (member '(:type :write-chars :row 0 :start-col 1 :chars "2" :style '(:s2)) diff :test #'equalp))
      (is (member '(:type :write-chars :row 1 :start-col 0 :chars "3" :style '(:s3)) diff :test #'equalp))
      (is (member '(:type :write-chars :row 1 :start-col 1 :chars "4" :style '(:s4)) diff :test #'equalp)))))

(test compute-buffer-diff-incompatible-dimensions
  "Test `compute-buffer-diff` signals error for incompatible dimensions."
  (let ((buffer1 (make-virtual-buffer 5 3))
        (buffer2 (make-virtual-buffer 6 3))
        (buffer3 (make-virtual-buffer 5 4)))
    (signals buffers-not-compatible-error (compute-buffer-diff buffer1 buffer2))
    (signals buffers-not-compatible-error (compute-buffer-diff buffer1 buffer3))))

;; Mock terminal instance for apply-terminal-diff tests
(defclass mock-terminal-instance ()
  ((stream :initform (make-string-output-stream) :reader mock-terminal-instance-stream)
   (io-lock :initform (bt:make-recursive-lock "mock-terminal-lock") :reader mock-terminal-instance-io-lock)
   (current-style :initform nil :accessor mock-terminal-instance-current-style)
   (sent-sequences :initform nil :accessor mock-terminal-instance-sent-sequences)
   (written-strings :initform nil :accessor mock-terminal-instance-written-strings)
   (applied-styles :initform nil :accessor mock-terminal-instance-applied-styles)))

;; (defmethod elmtui.platform.backend.terminal::terminal-instance-stream ((instance mock-terminal-instance))
;;   (mock-terminal-instance-stream instance))

;; (defmethod elmtui.platform.backend.terminal::with-terminal-lock ((instance mock-terminal-instance) &body body)
;;   ;; In tests, we assume the lock is held by the caller (the test function)
;;   ;; so we just execute the body directly.
;;   (declare (ignore instance))
;;   `(progn ,@body))

;; (defmethod elmtui.platform.backend.terminal:send-sequence ((instance mock-terminal-instance) sequence-key &rest args)
;;   (push (list* sequence-key args) (mock-terminal-instance-sent-sequences instance)))

;; (defmethod elmtui.platform.backend.terminal::apply-style-diff ((instance mock-terminal-instance) new-style)
;;   (push new-style (mock-terminal-instance-applied-styles instance))
;;   (setf (mock-terminal-instance-current-style instance) new-style))

;; (defmethod elmtui.platform.api:term-style ((instance mock-terminal-instance))
;;   ;; This is used by apply-terminal-diff to get the initial style
;;   (mock-terminal-instance-current-style instance))

;; (defmethod finish-output ((stream string-stream))
;;   ;; Mock finish-output for string streams
;;   (get-output-stream-string stream))

(test apply-terminal-diff-empty-diff
  "Test `apply-terminal-diff` does nothing for an empty diff list."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (apply-terminal-diff mock-term '())
    (is (null (mock-terminal-instance-sent-sequences mock-term)))
    (is (null (mock-terminal-instance-written-strings mock-term)))
    (is (null (mock-terminal-instance-applied-styles mock-term)))))

(test apply-terminal-diff-single-write-chars
  "Test `apply-terminal-diff` for a single :write-chars op."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (apply-terminal-diff mock-term '((:type :write-chars :row 1 :start-col 5 :chars "Hello" :style '(:fg :white))))
    ;; Expected calls: set style, move cursor, write string, finish output
    (is (equalp (nreverse (mock-terminal-instance-applied-styles mock-term))
                '((:fg :white))))
    (is (equalp (nreverse (mock-terminal-instance-sent-sequences mock-term))
                '((:cursor-set-position 2 6)))) ; 1-based coordinates for terminal
    ;; We don't directly capture write-string calls, but the effect on the stream
    (is (string= (get-output-stream-string (mock-terminal-instance-stream mock-term))
                 "Hello"))))

(test apply-terminal-diff-multiple-write-chars-same-style-contiguous
  "Test `apply-terminal-diff` for contiguous :write-chars ops with same style."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (apply-terminal-diff mock-term '((:type :write-chars :row 0 :start-col 0 :chars "ABC" :style '(:s1))
                                     (:type :write-chars :row 0 :start-col 3 :chars "DEF" :style '(:s1))))
    ;; Expected calls: set style, move cursor to (0,0), write "ABC", write "DEF", finish output
    (is (equalp (nreverse (mock-terminal-instance-applied-styles mock-term))
                '((:s1)))) ; Style set only once
    (is (equalp (nreverse (mock-terminal-instance-sent-sequences mock-term))
                '((:cursor-set-position 1 1)))) ; Cursor moved only once
    (is (string= (get-output-stream-string (mock-terminal-instance-stream mock-term))
                 "ABCDEF"))))

(test apply-terminal-diff-multiple-write-chars-different-styles
  "Test `apply-terminal-diff` for :write-chars ops with different styles."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (apply-terminal-diff mock-term '((:type :write-chars :row 0 :start-col 0 :chars "A" :style '(:s1))
                                     (:type :write-chars :row 0 :start-col 1 :chars "B" :style '(:s2))
                                     (:type :write-chars :row 0 :start-col 2 :chars "C" :style '(:s1))))
    ;; Expected calls: set s1, move to (0,0), write A, set s2, write B, set s1, write C, finish output
    (is (equalp (nreverse (mock-terminal-instance-applied-styles mock-term))
                '((:s1) (:s2) (:s1)))) ; Style set multiple times
    (is (equalp (nreverse (mock-terminal-instance-sent-sequences mock-term))
                '((:cursor-set-position 1 1) ; Move for A
                  (:cursor-set-position 1 2) ; Move for B (optional, but happens if not contiguous)
                  (:cursor-set-position 1 3)))) ; Move for C (optional)
    ;; Note: The current apply-terminal-diff implementation *does* move the cursor
    ;; even if the ops are contiguous but have different styles. This is acceptable
    ;; for correctness, though potentially not maximally performant.
    (is (string= (get-output-stream-string (mock-terminal-instance-stream mock-term))
                 "ABC"))))

(test apply-terminal-diff-multiple-write-chars-disjoint
  "Test `apply-terminal-diff` for disjoint :write-chars ops."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (apply-terminal-diff mock-term '((:type :write-chars :row 0 :start-col 0 :chars "A" :style '(:s1))
                                     (:type :write-chars :row 1 :start-col 1 :chars "B" :style '(:s2))))
    ;; Expected calls: set s1, move to (0,0), write A, set s2, move to (1,1), write B, finish output
    (is (equalp (nreverse (mock-terminal-instance-applied-styles mock-term))
                '((:s1) (:s2))))
    (is (equalp (nreverse (mock-terminal-instance-sent-sequences mock-term))
                '((:cursor-set-position 1 1)
                  (:cursor-set-position 2 2))))
    (is (string= (get-output-stream-string (mock-terminal-instance-stream mock-term))
                 "AB"))))

(test apply-terminal-diff-initial-style
  "Test `apply-terminal-diff` uses the terminal's initial style."
  (let ((mock-term (make-instance 'mock-terminal-instance)))
    (setf (mock-terminal-instance-current-style mock-term) '(:initial :style))
    (apply-terminal-diff mock-term '((:type :write-chars :row 0 :start-col 0 :chars "A" :style '(:initial :style))
                                     (:type :write-chars :row 0 :start-col 1 :chars "B" :style '(:new :style))))
    ;; Expected calls: move to (0,0), write A (no style change needed), set new style, move to (0,1), write B, finish output
    (is (equalp (nreverse (mock-terminal-instance-applied-styles mock-term))
                '((:new :style)))) ; Only the new style is applied
    (is (equalp (nreverse (mock-terminal-instance-sent-sequences mock-term))
                '((:cursor-set-position 1 1)
                  (:cursor-set-position 1 2))))
    (is (string= (get-output-stream-string (mock-terminal-instance-stream mock-term))
                 "AB"))))
