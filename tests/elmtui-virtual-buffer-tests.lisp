(uiop:define-package :elmtui.tests.virtual-buffer
  (:use :cl :fiveam :elmtui.platform.backend.common.virtual-buffer)
  (:export #:elmtui.virtual-buffer-suite))

(in-package :elmtui.tests.virtual-buffer)

(def-suite elmtui.virtual-buffer-suite
  :description "Tests for the virtual terminal buffer.")

(in-suite elmtui.virtual-buffer-suite)

(test make-virtual-buffer-creates-buffer-with-correct-dimensions-and-initial-cells
      "Test `make-virtual-buffer` for correct dimensions and cell initialization."
      (let ((buffer (make-virtual-buffer 10 5)))
        (is (= (buffer-width buffer) 10))
        (is (= (buffer-height buffer) 5))
        (is (typep (virtual-terminal-buffer-cells buffer) '(simple-array buffer-cell (* *))))
        (is (equal (array-dimensions (virtual-terminal-buffer-cells buffer)) '(5 10)))
        (let ((default-cell (default-buffer-cell)))
          (loop for r from 0 below 5
                do (loop for c from 0 below 10
                         do (is (buffer-cell-equal-p
                                 (aref (virtual-terminal-buffer-cells buffer) r c)
                                 (default-buffer-cell))))))))

(test make-virtual-buffer-with-zero-dimensions
      "Test `make-virtual-buffer` with zero width and height."
      (let ((buffer-zero-width (make-virtual-buffer 0 5)))
        (is (= (buffer-width buffer-zero-width) 0))
        (is (= (buffer-height buffer-zero-width) 5))
        (is (equal (array-dimensions (virtual-terminal-buffer-cells buffer-zero-width)) '(5 0))))

      (let ((buffer-zero-height (make-virtual-buffer 10 0)))
        (is (= (buffer-width buffer-zero-height) 10))
        (is (= (buffer-height buffer-zero-height) 0))
        (is (equal (array-dimensions (virtual-terminal-buffer-cells buffer-zero-height)) '(0 10))))

      (let ((buffer-zero-both (make-virtual-buffer 0 0)))
        (is (= (buffer-width buffer-zero-both) 0))
        (is (= (buffer-height buffer-zero-both) 0))
        (is (equal (array-dimensions (virtual-terminal-buffer-cells buffer-zero-both)) '(0 0)))))

(test make-virtual-buffer-signals-type-error-for-negative-dimensions
      "Test `make-virtual-buffer` signals type-error for negative dimensions."
      (signals type-error (make-virtual-buffer -1 5))
      (signals type-error (make-virtual-buffer 10 -1))
      (signals type-error (make-virtual-buffer -1 -1)))


(test buffer-cell-equal-p-compares-cells "Test `buffer-cell-equal-p` for various cell comparisons."
      (let ((cell1 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\a :style '(:fg :red)))
            (cell2 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\a :style '(:fg :red)))
            (cell3 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\b :style '(:fg :red)))
            (cell4 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\a :style '(:fg :blue)))
            (cell5 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\a :style '(:fg :red :bg :black))))
        (is (buffer-cell-equal-p cell1 cell2))
        (is (not (buffer-cell-equal-p cell1 cell3)))
        (is (not (buffer-cell-equal-p cell1 cell4)))
        (is (not (buffer-cell-equal-p cell1 cell5)))
        (is (buffer-cell-equal-p (default-buffer-cell) (default-buffer-cell)))))

(test buffer-cell-at-retrieves-cell-copy-and-handles-bounds "Test `buffer-cell-at` retrieves a copy and handles bounds."
      (let ((buffer (make-virtual-buffer 2 2))) (set-buffer-cell-at buffer 0 0 #\x '(:fg :green))
        (let ((cell-copy (buffer-cell-at buffer 0 0)))
          (is (char= (buffer-cell-char cell-copy) #\x))
          (is (equalp (buffer-cell-style cell-copy) '(:fg :green))) ;; Modify copy and check original is unchanged (setf (buffer-cell-char cell-copy) #\y) (setf (buffer-cell-style cell-copy) '(:fg :blue)) (let ((original-still (buffer-cell-at buffer 0 0))) (is (char= (buffer-cell-char original-still) #\x)) (is (equalp (buffer-cell-style original-still) '(:fg :green)))))

          ;; Test out-of-bounds access
          (signals invalid-buffer-coordinates-error (buffer-cell-at buffer 2 0))
          (signals invalid-buffer-coordinates-error (buffer-cell-at buffer 0 2))
          (signals invalid-buffer-coordinates-error (buffer-cell-at buffer -1 0))
          (signals invalid-buffer-coordinates-error (buffer-cell-at buffer 0 -1))

          ;; Test restart: use-value
          (let ((fallback-cell (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\F :style '(:fallback t))))
            (handler-bind ((invalid-buffer-coordinates-error
                             (lambda (c)
                               (declare (ignore c))
                               (invoke-restart 'use-value fallback-cell))))
              (let ((cell (buffer-cell-at buffer 2 0))) ; Out of bounds
                (is (buffer-cell-equal-p cell fallback-cell)))))

          ;; Test restart: clip-coordinates
          (set-buffer-cell-at buffer 0 1 #\X '(:clip-test)) ; cell (0,1)
          (handler-bind ((invalid-buffer-coordinates-error
                           (lambda (c)
                             (declare (ignore c))
                             (invoke-restart 'clip-coordinates))))
            ;; Clip to (0,1) from various out-of-bounds positions
            (is (buffer-cell-equal-p (buffer-cell-at buffer 0 5) ; clips to (0,1)
                                     (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\X :style '(:clip-test))))
            (is (buffer-cell-equal-p (buffer-cell-at buffer 5 0) ; clips to (1,0) which is default
                                     (default-buffer-cell)))
            (is (buffer-cell-equal-p (buffer-cell-at buffer -1 1) ; clips to (0,1)
                                     (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\X :style '(:clip-test))))))
        ))

(test set-buffer-cell-at-modifies-cell-and-handles-bounds
      "Test `set-buffer-cell-at` modifies the correct cell and handles bounds."
      (let ((buffer (make-virtual-buffer 2 2)))
        (set-buffer-cell-at buffer 1 1 #\z '(:bg :blue))
        (let ((cell (buffer-cell-at buffer 1 1))) (is (char= (buffer-cell-char cell) #\z)) (is (equalp (buffer-cell-style cell) '(:bg :blue))))

        ;; Check that other cells are not affected (still default)
        (is (buffer-cell-equal-p (buffer-cell-at buffer 0 0) (default-buffer-cell)))

        ;; Test out-of-bounds access
        (signals invalid-buffer-coordinates-error (set-buffer-cell-at buffer 2 0 #\a nil))
        (signals invalid-buffer-coordinates-error (set-buffer-cell-at buffer 0 2 #\a nil))
        (signals invalid-buffer-coordinates-error (set-buffer-cell-at buffer -1 0 #\a nil))
        (signals invalid-buffer-coordinates-error (set-buffer-cell-at buffer 0 -1 #\a nil))

        ;; Test restart: use-value (to skip operation)
        (let ((original-char (buffer-cell-char (buffer-cell-at buffer 0 0)))
              (original-style (buffer-cell-style (buffer-cell-at buffer 0 0))))
          (handler-bind ((invalid-buffer-coordinates-error
                           (lambda (c)
                             (declare (ignore c))
                             (invoke-restart 'use-value))))   ; Invoke with no args to skip
            (set-buffer-cell-at buffer 2 0 #\W '(:danger t))) ; Out of bounds
          ;; Verify cell 0,0 was not changed by the failed set
          (is (char= (buffer-cell-char (buffer-cell-at buffer 0 0)) original-char))
          (is (equalp (buffer-cell-style (buffer-cell-at buffer 0 0)) original-style)))

        ;; Test restart: clip-coordinates for set-buffer-cell-at
        (let ((buffer (make-virtual-buffer 2 2)))
          (set-buffer-cell-at buffer 0 0 #\A '(:original-a))
          (set-buffer-cell-at buffer 1 1 #\B '(:original-b))

          (handler-bind ((invalid-buffer-coordinates-error
                           (lambda (c)
                             (declare (ignore c))
                             (invoke-restart 'clip-coordinates))))
            ;; Attempt to set out of bounds, should clip and set at (1,1)
            (set-buffer-cell-at buffer 5 5 #\C '(:clipped-c)))
          (is (char= (buffer-cell-char (buffer-cell-at buffer 1 1)) #\C))
          (is (equalp (buffer-cell-style (buffer-cell-at buffer 1 1)) '(:clipped-c)))
          ;; Ensure (0,0) was not affected
          (is (char= (buffer-cell-char (buffer-cell-at buffer 0 0)) #\A))

          (handler-bind ((invalid-buffer-coordinates-error
                           (lambda (c)
                             (declare (ignore c))
                             (invoke-restart 'clip-coordinates))))
            ;; Attempt to set out of bounds (negative), should clip and set at (0,0)
            (set-buffer-cell-at buffer -5 -5 #\D '(:clipped-d)))
          (is (char= (buffer-cell-char (buffer-cell-at buffer 0 0)) #\D))
          (is (equalp (buffer-cell-style (buffer-cell-at buffer 0 0)) '(:clipped-d)))
          ;; Ensure (1,1) was not affected by this second clip
          (is (char= (buffer-cell-char (buffer-cell-at buffer 1 1)) #\C)))
        ))

(test fill-buffer-region-fills-correctly-and-clips
      "Test `fill-buffer-region` for correct filling and clipping."
      (let ((buffer (make-virtual-buffer 5 3))) ; 5 wide, 3 high
        ;; Fill a region within bounds
        (fill-buffer-region buffer 1 1 2 1 #\F '(:fill t)) ; row 1, col 1, width 2, height 1
        (is (char= (buffer-cell-char (buffer-cell-at buffer 1 1)) #\F))
        (is (equalp (buffer-cell-style (buffer-cell-at buffer 1 1)) '(:fill t)))
        (is (char= (buffer-cell-char (buffer-cell-at buffer 1 2)) #\F))
        (is (equalp (buffer-cell-style (buffer-cell-at buffer 1 2)) '(:fill t)))
        ;; Check adjacent cells are not affected
        (is (buffer-cell-equal-p (buffer-cell-at buffer 0 0) (default-buffer-cell)))
        (is (buffer-cell-equal-p (buffer-cell-at buffer 1 0) (default-buffer-cell)))
        (is (buffer-cell-equal-p (buffer-cell-at buffer 1 3) (default-buffer-cell)))

        ;; Fill with clipping (partially out of bounds)
        ;; Top-left out
        (fill-buffer-region buffer -1 -1 3 2 #\C '(:clip t)) ; row -1, col -1, width 3, height 2
                                        ; Expected fill: (0,0) (0,1) (1,0) (1,1)
        (is (char= (buffer-cell-char (buffer-cell-at buffer 0 0)) #\C))
        (is (char= (buffer-cell-char (buffer-cell-at buffer 0 1)) #\C))
        (is (char= (buffer-cell-char (buffer-cell-at buffer 1 0)) #\C))
        (is (char= (buffer-cell-char (buffer-cell-at buffer 1 1)) #\C)) ; This was #\F before
        (is (equalp (buffer-cell-style (buffer-cell-at buffer 0 0)) '(:clip t)))

        ;; Bottom-right out
        (fill-buffer-region buffer 2 3 3 2 #\B '(:bottom t)) ; row 2, col 3, width 3, height 2
                                        ; Expected fill: (2,3) (2,4)
        (is (char= (buffer-cell-char (buffer-cell-at buffer 2 3)) #\B))
        (is (char= (buffer-cell-char (buffer-cell-at buffer 2 4)) #\B))
        (is (equalp (buffer-cell-style (buffer-cell-at buffer 2 3)) '(:bottom t)))
        ;; Check a cell that should not be touched by this fill
        (is (char= (buffer-cell-char (buffer-cell-at buffer 0 0)) #\C)) ; Still from previous fill

        ;; Fill completely out of bounds (should do nothing)
        (let ((buffer-copy (copy-virtual-buffer buffer)))
          (fill-buffer-region buffer 10 10 2 2 #\O '(:out t))
          (loop for r from 0 below (buffer-height buffer)
                do (loop for c from 0 below (buffer-width buffer)
                         do (is (buffer-cell-equal-p (buffer-cell-at buffer r c)
                                                     (buffer-cell-at buffer-copy r c))))))

        ;; Fill with zero width/height (should do nothing)
        (let ((buffer-copy (copy-virtual-buffer buffer)))
          (fill-buffer-region buffer 1 1 0 1 #\Z '(:zero t))
          (fill-buffer-region buffer 1 1 1 0 #\Z '(:zero t))
          (loop for r from 0 below (buffer-height buffer)
                do (loop for c from 0 below (buffer-width buffer)
                         do (is (buffer-cell-equal-p (buffer-cell-at buffer r c)
                                                     (buffer-cell-at buffer-copy r c))))))))

(test clear-buffer-fills-with-specified-or-default-char-style
      "Test `clear-buffer` fills the entire buffer."
      (let ((buffer (make-virtual-buffer 3 2)))
        ;; Set some initial content
        (set-buffer-cell-at buffer 0 0 #\x '(:fg :red))
        (set-buffer-cell-at buffer 1 1 #\y '(:bg :blue))

        ;; Clear with default values
        (clear-buffer buffer)
        (loop for r from 0 below (buffer-height buffer)
              do (loop for c from 0 below (buffer-width buffer)
                       do (is (buffer-cell-equal-p (buffer-cell-at buffer r c)
                                                   (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\Space :style nil)))))

        ;; Clear with specified values
        (clear-buffer buffer :default-char #\C :default-style '(:cleared t))
        (loop for r from 0 below (buffer-height buffer)
              do (loop for c from 0 below (buffer-width buffer)
                       do (is (buffer-cell-equal-p (buffer-cell-at buffer r c)
                                                   (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\C :style '(:cleared t))))))))

(test resize-buffer-handles-expansion-shrinkage-and-content-preservation
      "Test `resize-buffer` for various resize scenarios."
      (let ((original-buffer (make-virtual-buffer 3 2))) ; 3 wide, 2 high
        (set-buffer-cell-at original-buffer 0 0 #\A '(:a))
        (set-buffer-cell-at original-buffer 0 1 #\B '(:b))
        (set-buffer-cell-at original-buffer 0 2 #\C '(:c))
        (set-buffer-cell-at original-buffer 1 0 #\D '(:d))
        (set-buffer-cell-at original-buffer 1 1 #\E '(:e))
        (set-buffer-cell-at original-buffer 1 2 #\F '(:f))

        ;; Test expansion
        (let ((expanded-buffer (resize-buffer original-buffer 4 3 :default-char #\X :default-style '(:expanded))))
          (is (= (buffer-width expanded-buffer) 4))
          (is (= (buffer-height expanded-buffer) 3))
          ;; Check copied content
          (is (char= (buffer-cell-char (buffer-cell-at expanded-buffer 0 0)) #\A))
          (is (equalp (buffer-cell-style (buffer-cell-at expanded-buffer 0 0)) '(:a)))
          (is (char= (buffer-cell-char (buffer-cell-at expanded-buffer 1 2)) #\F))
          (is (equalp (buffer-cell-style (buffer-cell-at expanded-buffer 1 2)) '(:f)))
          ;; Check new areas (right column)
          (is (char= (buffer-cell-char (buffer-cell-at expanded-buffer 0 3)) #\X))
          (is (equalp (buffer-cell-style (buffer-cell-at expanded-buffer 0 3)) '(:expanded)))
          (is (char= (buffer-cell-char (buffer-cell-at expanded-buffer 1 3)) #\X))
          (is (equalp (buffer-cell-style (buffer-cell-at expanded-buffer 1 3)) '(:expanded)))
          ;; Check new areas (bottom row)
          (loop for c from 0 below 4
                do (is (char= (buffer-cell-char (buffer-cell-at expanded-buffer 2 c)) #\X)))
          (is (equalp (buffer-cell-style (buffer-cell-at expanded-buffer 2 0)) '(:expanded))))

        ;; Test shrinkage
        (let ((shrunk-buffer (resize-buffer original-buffer 2 1 :default-char #\Y :default-style '(:shrunk))))
          (is (= (buffer-width shrunk-buffer) 2))
          (is (= (buffer-height shrunk-buffer) 1))
          ;; Check copied content
          (is (char= (buffer-cell-char (buffer-cell-at shrunk-buffer 0 0)) #\A))
          (is (equalp (buffer-cell-style (buffer-cell-at shrunk-buffer 0 0)) '(:a)))
          (is (char= (buffer-cell-char (buffer-cell-at shrunk-buffer 0 1)) #\B))
          (is (equalp (buffer-cell-style (buffer-cell-at shrunk-buffer 0 1)) '(:b)))
          ;; Ensure it doesn't have cells from original that are now out of bounds
          (signals invalid-buffer-coordinates-error (buffer-cell-at shrunk-buffer 0 2))
          (signals invalid-buffer-coordinates-error (buffer-cell-at shrunk-buffer 1 0)))

        ;; Test resize to same dimensions
        (let ((same-size-buffer (resize-buffer original-buffer 3 2 :default-char #\Z :default-style '(:same))))
          (is (= (buffer-width same-size-buffer) 3))
          (is (= (buffer-height same-size-buffer) 2))
          (loop for r from 0 below 2
                do (loop for c from 0 below 3
                         do (is (buffer-cell-equal-p (buffer-cell-at same-size-buffer r c)
                                                     (buffer-cell-at original-buffer r c))))))

        ;; Test resize to zero dimensions
        (let ((zero-buffer (resize-buffer original-buffer 0 0)))
          (is (= (buffer-width zero-buffer) 0))
          (is (= (buffer-height zero-buffer) 0))
          (signals invalid-buffer-coordinates-error (buffer-cell-at zero-buffer 0 0)))

        ;; Test resize from zero dimensions
        (let ((empty-buffer (make-virtual-buffer 0 0))
              (resized-from-empty (resize-buffer empty-buffer 2 2 :default-char #\N :default-style '(:new))))
          (is (= (buffer-width resized-from-empty) 2))
          (is (= (buffer-height resized-from-empty) 2))
          (is (char= (buffer-cell-char (buffer-cell-at resized-from-empty 0 0)) #\N))
          (is (equalp (buffer-cell-style (buffer-cell-at resized-from-empty 0 0)) '(:new))))))

(test copy-virtual-buffer-creates-deep-copy
      "Test `copy-virtual-buffer` for deep copy verification."
      (let ((original-buffer (make-virtual-buffer 2 1)))
        (set-buffer-cell-at original-buffer 0 0 #\X '(:original t))
        (let ((copied-buffer (copy-virtual-buffer original-buffer)))
          ;; Check dimensions and content
          (is (= (buffer-width copied-buffer) 2))
          (is (= (buffer-height copied-buffer) 1))
          (is (char= (buffer-cell-char (buffer-cell-at copied-buffer 0 0)) #\X))
          (is (equalp (buffer-cell-style (buffer-cell-at copied-buffer 0 0)) '(:original t)))

          ;; Modify original and check copy is unaffected
          (set-buffer-cell-at original-buffer 0 0 #\Y '(:modified t))
          (is (char= (buffer-cell-char (buffer-cell-at copied-buffer 0 0)) #\X))
          (is (equalp (buffer-cell-style (buffer-cell-at copied-buffer 0 0)) '(:original t)))

          ;; Modify copy and check original is unaffected
          (set-buffer-cell-at copied-buffer 0 1 #\Z '(:added_to_copy t))
          (is (buffer-cell-equal-p (buffer-cell-at original-buffer 0 1) (default-buffer-cell)))
          (is (char= (buffer-cell-char (buffer-cell-at original-buffer 0 0)) #\Y)) ; Original's modification

          ;; Ensure locks are different objects
          (is (not (eq (buffer-lock original-buffer) (buffer-lock copied-buffer))))

          ;; Ensure cells array is a different object
          (is (not (eq (virtual-terminal-buffer-cells original-buffer)
                       (virtual-terminal-buffer-cells copied-buffer))))
          ;; Ensure individual cell objects are different
          (is (not (eq (aref (virtual-terminal-buffer-cells original-buffer) 0 0)
                       (aref (virtual-terminal-buffer-cells copied-buffer) 0 0)))))))

(test terminal-style-buffer-cell-roundtrip
      "Test writing, reading, and comparing buffer cells using terminal-style structs."
      (let* ((buf (make-virtual-buffer 3 2))
             (style1 (elmtui.backend.common.ansi-styling:make-terminal-style
                      :fg-color (elmtui.backend.common.ansi-styling:make-termcolor :simple :red)
                      :bg-color (elmtui.backend.common.ansi-styling:make-termcolor :simple :blue)
                      :bold t
                      :underline t))
             (style2 (elmtui.backend.common.ansi-styling:make-terminal-style
                      :fg-color (elmtui.backend.common.ansi-styling:make-termcolor :simple :red)
                      :bg-color (elmtui.backend.common.ansi-styling:make-termcolor :simple :blue)
                      :bold t
                      :underline t)))
        (set-buffer-cell-at buf 1 1 #\Z style1)
        (let ((cell (buffer-cell-at buf 1 1)))
          (is (char= (buffer-cell-char cell) #\Z))
          (is (typep (buffer-cell-style cell) 'elmtui.backend.common.ansi-styling:terminal-style))
          (is (equal (elmtui.backend.common.ansi-styling:terminal-style-fg-color (buffer-cell-style cell))
                     (elmtui.backend.common.ansi-styling:make-termcolor :simple :red)))
          (is (equal (elmtui.backend.common.ansi-styling:terminal-style-bg-color (buffer-cell-style cell))
                     (elmtui.backend.common.ansi-styling:make-termcolor :simple :blue)))
          (is (eq (elmtui.backend.common.ansi-styling:terminal-style-bold (buffer-cell-style cell)) t))
          (is (eq (elmtui.backend.common.ansi-styling:terminal-style-underline (buffer-cell-style cell)) t))
          ;; Compare two cells with identical terminal-style structs
          (let ((cell2 (elmtui.platform.backend.common.virtual-buffer::%make-buffer-cell :char #\Z :style style2)))
            (is (buffer-cell-equal-p cell cell2))))))

(test print-buffer-to-string-formats-correctly
      "Test `print-buffer-to-string` for correct string representation."
      (let ((buffer (make-virtual-buffer 2 2)))
        (set-buffer-cell-at buffer 0 0 #\A '(:fg :red))
        (set-buffer-cell-at buffer 0 1 #\B nil)
        (set-buffer-cell-at buffer 1 0 #\C '(:bg :blue :attr (:bold)))
        (set-buffer-cell-at buffer 1 1 #\D '(:fg :green))

        (is (string= (print-buffer-to-string buffer)
                     (format nil "AB~%CD")))

        (is (string= (print-buffer-to-string buffer :show-styles-p t)
                     (format nil "A(:FG :RED)B()~%C(:BG :BLUE :ATTR (:BOLD))D(:FG :GREEN)"))))

      ;; Test with empty buffer
      (let ((empty-buffer (make-virtual-buffer 0 0)))
        (is (string= (print-buffer-to-string empty-buffer) ""))
        (is (string= (print-buffer-to-string empty-buffer :show-styles-p t) "")))

      ;; Test with buffer with zero width
      (let ((zero-width-buffer (make-virtual-buffer 0 2)))
        (is (string= (print-buffer-to-string zero-width-buffer) (format nil "~%"))) ; Two lines, but empty
        (is (string= (print-buffer-to-string zero-width-buffer :show-styles-p t) (format nil "~%"))))

      ;; Test with buffer with zero height
      (let ((zero-height-buffer (make-virtual-buffer 2 0)))
        (is (string= (print-buffer-to-string zero-height-buffer) ""))
        (is (string= (print-buffer-to-string zero-height-buffer :show-styles-p t) ""))))
