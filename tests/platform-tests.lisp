;;;===============================================================
;;; File: tests/platform-tests.lisp
;;;
;;; Description: Comprehensive tests for platform backend layer
;;; Tests virtual buffer, terminal styling, and basic rendering
;;;===============================================================

(uiop:define-package :elmtui.platform.tests
  (:use :cl :fiveam :alexandria)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
                #:make-virtual-buffer
                #:buffer-width
                #:buffer-height
                #:buffer-cell-at
                #:set-buffer-cell-at
                #:clear-buffer
                #:fill-buffer-region
                #:write-string-to-buffer
                #:resize-buffer
                #:copy-virtual-buffer
                #:copy-buffer-contents
                #:buffer-cell-char
                #:buffer-cell-style
                #:make-buffer-cell
                #:buffer-cell-equal-p
                #:virtual-terminal-buffer)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:make-terminal-style
                #:terminal-style-fg-color
                #:terminal-style-bg-color
                #:make-termcolor
                #:terminal-color-simple
                #:copy-term-style
                #:style-to-terminal-style
                #:terminal-style-fg-color-val
                #:terminal-style-bg-color-val)
  (:export #:run-platform-tests))

(in-package :elmtui.platform.tests)

;; Define test suite
(def-suite platform-test-suite
  :description "Test suite for platform backend functionality")
(in-suite platform-test-suite)

;;;===============================================================
;;; Virtual Buffer Creation Tests
;;;===============================================================

(test virtual-buffer-create
  "Test basic virtual buffer creation"
  (let ((buf (make-virtual-buffer 80 24)))
    (is (typep buf 'virtual-terminal-buffer))
    (is (= (buffer-width buf) 80))
    (is (= (buffer-height buf) 24))
    ;; Buffer should be initialized with default cells
    (let ((cell (buffer-cell-at buf 0 0)))
      (is (typep cell 'elmtui.platform.backend.common.virtual-buffer::buffer-cell)))))

(test virtual-buffer-default-cell
  "Test that buffer cells have default values"
  (let ((buf (make-virtual-buffer 10 10)))
    (let ((cell (buffer-cell-at buf 5 5)))
      (is (char= (buffer-cell-char cell) #\Space))
      (is (null (buffer-cell-style cell))))))

(test virtual-buffer-size-validation
  "Test buffer creation with various sizes"
  (let ((small-buf (make-virtual-buffer 5 5))
        (large-buf (make-virtual-buffer 200 100)))
    (is (= (buffer-width small-buf) 5))
    (is (= (buffer-height small-buf) 5))
    (is (= (buffer-width large-buf) 200))
    (is (= (buffer-height large-buf) 100))))

;;;===============================================================
;;; Cell Operations Tests
;;;===============================================================

(test buffer-cell-at-basic
  "Test reading cells from buffer"
  (let ((buf (make-virtual-buffer 10 10)))
    ;; All cells should be space by default
    (dotimes (row 10)
      (dotimes (col 10)
        (let ((cell (buffer-cell-at buf row col)))
          (is (char= (buffer-cell-char cell) #\Space)))))))

(test set-buffer-cell-at-basic
  "Test writing cells to buffer"
  (let ((buf (make-virtual-buffer 10 10)))
    ;; Set a character - Note: set-buffer-cell-at takes (buffer row col char style)
    (set-buffer-cell-at buf 0 0 #\X nil)
    (let ((cell (buffer-cell-at buf 0 0)))
      (is (char= (buffer-cell-char cell) #\X)))

    ;; Set multiple characters
    (set-buffer-cell-at buf 5 5 #\Y nil)
    (set-buffer-cell-at buf 9 9 #\Z nil)

    (is (char= (buffer-cell-char (buffer-cell-at buf 5 5)) #\Y))
    (is (char= (buffer-cell-char (buffer-cell-at buf 9 9)) #\Z))))

(test buffer-cell-equality
  "Test cell equality comparison"
  (let ((cell1 (make-buffer-cell :char #\A))
        (cell2 (make-buffer-cell :char #\A))
        (cell3 (make-buffer-cell :char #\B)))
    (is (buffer-cell-equal-p cell1 cell2))
    (is (not (buffer-cell-equal-p cell1 cell3)))))

;;;===============================================================
;;; String Writing Tests
;;;===============================================================

(test write-string-simple
  "Test simple string writing to buffer"
  (let ((buf (make-virtual-buffer 20 5)))
    ;; write-string-to-buffer takes (buffer start-row start-col string style)
    (write-string-to-buffer buf 0 0 "Hello" nil)
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\H))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 1)) #\e))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 2)) #\l))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 3)) #\l))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 4)) #\o))
    ;; Rest should still be spaces
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 5)) #\Space))))

(test write-string-multiple-lines
  "Test writing strings across multiple lines"
  (let ((buf (make-virtual-buffer 20 5)))
    (write-string-to-buffer buf 0 0 "Line 1" nil)
    (write-string-to-buffer buf 1 0 "Line 2" nil)
    (write-string-to-buffer buf 2 0 "Line 3" nil)

    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\L))
    (is (char= (buffer-cell-char (buffer-cell-at buf 1 0)) #\L))
    (is (char= (buffer-cell-char (buffer-cell-at buf 2 0)) #\L))))

(test write-string-with-style
  "Test writing styled text to buffer"
  (let ((buf (make-virtual-buffer 20 5))
        (red-style (style-to-terminal-style '(:fg-color :red))))
    ;; write-string-to-buffer takes (buffer start-row start-col string style)
    (write-string-to-buffer buf 0 0 "Styled" red-style)

    ;; Check characters
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\S))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 1)) #\t))

    ;; Check style was applied
    (let ((cell (buffer-cell-at buf 0 0)))
      (is (not (null (buffer-cell-style cell)))))))

;;;===============================================================
;;; Buffer Operations Tests
;;;===============================================================

(test clear-buffer-basic
  "Test clearing the entire buffer"
  (let ((buf (make-virtual-buffer 10 10)))
    ;; Write some content
    (write-string-to-buffer buf 0 0 "Hello World" nil)
    (write-string-to-buffer buf 5 0 "Another line" nil)

    ;; Clear buffer
    (clear-buffer buf)

    ;; Check all cells are spaces
    (dotimes (row 10)
      (dotimes (col 10)
        (is (char= (buffer-cell-char (buffer-cell-at buf row col)) #\Space))))))

(test fill-buffer-region-basic
  "Test filling a region of the buffer"
  (let ((buf (make-virtual-buffer 20 10)))
    ;; fill-buffer-region takes (buffer row col width height char style)
    (fill-buffer-region buf 2 2 5 5 #\X nil)

    ;; Check filled cells
    (dotimes (row 5)
      (dotimes (col 5)
        (let ((buf-row (+ 2 row))
              (buf-col (+ 2 col)))
          (is (char= (buffer-cell-char (buffer-cell-at buf buf-row buf-col)) #\X)))))

    ;; Check cells outside region are unchanged
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\Space))
    (is (char= (buffer-cell-char (buffer-cell-at buf 9 9)) #\Space))))

(test resize-buffer-grow
  "Test growing buffer size"
  (let ((buf (make-virtual-buffer 10 10)))
    (write-string-to-buffer buf 0 0 "Test" nil)

    ;; Resize to larger (returns new buffer)
    (setf buf (resize-buffer buf 20 20))

    (is (= (buffer-width buf) 20))
    (is (= (buffer-height buf) 20))
    ;; Original content should be preserved
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\T))))

(test resize-buffer-shrink
  "Test shrinking buffer size"
  (let ((buf (make-virtual-buffer 20 20)))
    (write-string-to-buffer buf 0 0 "Test" nil)

    ;; Resize to smaller (returns new buffer)
    (setf buf (resize-buffer buf 10 10))

    (is (= (buffer-width buf) 10))
    (is (= (buffer-height buf) 10))
    ;; Content should still be there
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\T))))

(test copy-virtual-buffer
  "Test cloning a buffer"
  (let ((buf1 (make-virtual-buffer 10 10)))
    (write-string-to-buffer buf1 0 0 "Original" nil)
    (write-string-to-buffer buf1 5 5 "Content" nil)

    ;; Copy buffer
    (let ((buf2 (copy-virtual-buffer buf1)))
      ;; Should be independent but same content
      (is (= (buffer-width buf2) 10))
      (is (= (buffer-height buf2) 10))
      (is (char= (buffer-cell-char (buffer-cell-at buf2 0 0)) #\O))
      (is (char= (buffer-cell-char (buffer-cell-at buf2 5 5)) #\C))

      ;; Modifying copy should not affect original
      (write-string-to-buffer buf2 0 0 "Modified" nil)
      (is (char= (buffer-cell-char (buffer-cell-at buf1 0 0)) #\O))
      (is (char= (buffer-cell-char (buffer-cell-at buf2 0 0)) #\M)))))

(test copy-buffer-contents
  "Test copying contents between buffers"
  (let ((src-buf (make-virtual-buffer 10 10))
        (dst-buf (make-virtual-buffer 10 10)))
    (write-string-to-buffer src-buf 0 0 "Source Data" nil)

    ;; Copy contents (source -> target)
    (copy-buffer-contents src-buf dst-buf)

    ;; Destination should have source content
    (is (char= (buffer-cell-char (buffer-cell-at dst-buf 0 0)) #\S))
    (is (char= (buffer-cell-char (buffer-cell-at dst-buf 0 1)) #\o))
    (is (char= (buffer-cell-char (buffer-cell-at dst-buf 0 2)) #\u))))

;;;===============================================================
;;; ANSI Styling Tests
;;;===============================================================

(test terminal-style-create
  "Test creating terminal styles"
  (let ((style (make-terminal-style
                 :fg-color (make-termcolor :simple :red)
                 :bg-color (make-termcolor :simple :blue))))
    (is (not (null style)))
    (is (not (null (terminal-style-fg-color style))))
    (is (not (null (terminal-style-bg-color style))))))

(test termcolor-simple
  "Test creating simple terminal colors"
  (let ((red (make-termcolor :simple :red))
        (blue (make-termcolor :simple :blue)))
    (is (eq (terminal-color-simple red) :red))
    (is (eq (terminal-color-simple blue) :blue))))

(test copy-term-style
  "Test copying terminal styles"
  (let* ((orig (make-terminal-style
                 :fg-color (make-termcolor :simple :green)))
         (copy (copy-term-style orig)))
    ;; Styles should be equal but not identical
    (is (eq (terminal-color-simple
              (terminal-style-fg-color copy))
            :green))
    (is (not (eq orig copy)))))

(test style-to-terminal-style
  "Test converting style plist to terminal style"
  (let* ((style-plist '(:fg-color :red :bg-color :blue))
         (term-style (style-to-terminal-style style-plist)))
    (is (not (null term-style)))
    (is (not (null (terminal-style-fg-color term-style))))
    (is (not (null (terminal-style-bg-color term-style)))))

  ;; Canonical cl-styles color tokens must survive the renderer boundary.
  (let ((rgb-style (style-to-terminal-style
                    '(:color (:rgb 12 34 56)
                      :background-color (:rgb 65 43 21)))))
    (is (equal '(12 34 56) (terminal-style-fg-color-val rgb-style)))
    (is (equal '(65 43 21) (terminal-style-bg-color-val rgb-style))))

  ;; Test with empty style
  (let ((empty-style (style-to-terminal-style nil)))
    (is (or (null empty-style)
            (and (null (terminal-style-fg-color empty-style))
                 (null (terminal-style-bg-color empty-style)))))))

;;;===============================================================
;;; Integration Tests
;;;===============================================================

(test buffer-write-read-cycle
  "Test complete write-read cycle"
  (let ((buf (make-virtual-buffer 40 10)))
    ;; Write multiple strings
    (write-string-to-buffer buf 0 0 "Line 1: Hello" nil)
    (write-string-to-buffer buf 1 0 "Line 2: World" nil)
    (write-string-to-buffer buf 2 0 "Line 3: Test" nil)

    ;; Verify content
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\L))
    (is (char= (buffer-cell-char (buffer-cell-at buf 1 0)) #\L))
    (is (char= (buffer-cell-char (buffer-cell-at buf 2 0)) #\L))

    ;; Clear and verify
    (clear-buffer buf)
    (dotimes (row 3)
      (is (char= (buffer-cell-char (buffer-cell-at buf row 0)) #\Space)))))

(test buffer-stress-test
  "Test buffer operations with larger data"
  (let ((buf (make-virtual-buffer 80 24)))
    ;; Fill entire buffer
    (dotimes (row 24)
      (write-string-to-buffer buf row 0
        (format nil "Row ~2d: ~72a" row #\*) nil))

    ;; Verify some random cells
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\R))
    (is (char= (buffer-cell-char (buffer-cell-at buf 10 0)) #\R))
    (is (char= (buffer-cell-char (buffer-cell-at buf 23 0)) #\R))

    ;; Clear and verify
    (clear-buffer buf)
    (is (char= (buffer-cell-char (buffer-cell-at buf 10 50)) #\Space))))

(test buffer-cell-with-styles
  "Test creating cells with various styles"
  (let ((buf (make-virtual-buffer 20 10))
        (red-style (style-to-terminal-style '(:fg-color :red)))
        (blue-style (style-to-terminal-style '(:fg-color :blue)))
        (bold-style (style-to-terminal-style '(:attributes (:bold)))))

    ;; Write cells with different styles
    (set-buffer-cell-at buf 0 0 #\R red-style)
    (set-buffer-cell-at buf 0 1 #\B blue-style)
    (set-buffer-cell-at buf 0 2 #\X bold-style)

    (is (char= (buffer-cell-char (buffer-cell-at buf 0 0)) #\R))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 1)) #\B))
    (is (char= (buffer-cell-char (buffer-cell-at buf 0 2)) #\X))

    ;; Verify styles were applied
    (is (not (null (buffer-cell-style (buffer-cell-at buf 0 0)))))
    (is (not (null (buffer-cell-style (buffer-cell-at buf 0 1)))))
    (is (not (null (buffer-cell-style (buffer-cell-at buf 0 2)))))))

;;;===============================================================
;;; Run Tests
;;;===============================================================

(defun run-platform-tests ()
  "Run all platform backend tests"
  (run! 'platform-test-suite))
