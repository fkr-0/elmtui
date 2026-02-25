# tmux-capture Refactor with ANSI Style Preservation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor tmux-capture module to parse ANSI escape sequences and preserve character styles when capturing tmux output for seamless TUI transitions.

**Architecture:** The module will parse tmux `capture-pane -e` output (which includes escape sequences), extract SGR (Select Graphic Rendition) style information, and populate virtual buffers with (character, style) pairs. Uses existing `elmtui.platform.backend.common.ansi-styling` for style representation.

**Tech Stack:** Common Lisp, uiop (for subprocess), cl-inputs (terminal), FiveAM (testing), ANSI escape sequence parsing

---

## Task 1: Fix tmux binary detection

**Files:**
- Modify: `src/platform/tmux-capture.lisp:42-46`

**Step 1: Update %tmux-program to use uiop:find-program**

Current implementation only checks `/usr/bin/tmux`. Use `uiop:find-program` for proper PATH lookup.

Replace:
```lisp
(defun %tmux-program ()
  "Locate the tmux binary if available."
  (or
    (let ((path (probe-file "/usr/bin/tmux")))
      (when path (namestring path)))))
```

With:
```lisp
(defun %tmux-program ()
  "Locate the tmux binary if available."
  (ignore-errors (uiop:find-program* "tmux")))
```

**Step 2: Compile to verify**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui :force t)'`
Expected: SUCCESS; no warnings

**Step 3: Commit**

```bash
git add src/platform/tmux-capture.lisp
git commit -m "fix(tmux-capture): use uiop:find-program for PATH lookup"
```

---

## Task 2: Add ANSI sequence parsing utilities

**Files:**
- Modify: `src/platform/tmux-capture.lisp` (add new section after line 63)

**Step 1: Write the failing test for ANSI splitting**

Create test file: `tests/tmux-capture-tests.lisp`

First, set up the test suite:

```lisp
(uiop:define-package :elmtui.tests.tmux-capture
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.tmux
                #:split-by-ansi-sequences
                #:parse-ansi-sgr
                #:parse-ansi-string)
  (:export #:tmux-capture-tests))

(in-package :elmtui.tests.tmux-capture)

(def-suite tmux-capture-tests
  :in elmtui.tests:elmtui-test
  :description "Tests for tmux screen capture module")

(in-suite tmux-capture-tests)
```

Now write the first test:

```lisp
(test split-by-ansi-simple
  "Splitting a string with ANSI escape sequences works correctly"
  (let* ((input "Hello\e[31mWorld\e[0m!")
         (result (split-by-ansi-sequences input)))
    (is (= (length result) 3))
    (is (string= (first result) "Hello"))
    (is (string= (second result) "\e[31m"))
    (is (string= (third result) "World\e[0m!"))))
```

**Step 2: Run test to verify it fails**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui-tests :force t)' --eval '(5am:run! :elmtui.tests.tmux-capture)'`
Expected: FAIL with "function SPLIT-BY-ANSI-SEQUENCES not defined"

**Step 3: Implement split-by-ansi-sequences**

Add to `src/platform/tmux-capture.lisp` after line 63:

```lisp
;;;----------------------------------------------------------------
;;; ANSI Sequence Parsing
;;;----------------------------------------------------------------

(defun %esc-p (char)
  "Check if CHAR is the ESC character."
  (char= char #\Escape))

(defun split-by-ansi-sequences (content)
  "Split CONTENT into segments separated by ANSI escape sequences.
Returns a list of alternating plain text and ANSI sequences."
  (unless content
    (return-from split-by-ansi-sequences '()))
  (let ((result '())
        (current-segment (make-string-output-stream))
        (in-escape nil)
        (i 0)
        (len (length content)))
    (loop
      (when (>= i len)
        (let ((seg (get-output-stream-string current-segment)))
          (when (plusp (length seg))
            (push seg result)))
        (return))
      (let ((char (aref content i)))
        (cond
          ;; Start of escape sequence
          ((and (not in-escape) (%esc-p char))
           ;; Flush current segment
           (let ((seg (get-output-stream-string current-segment)))
             (when (plusp (length seg))
               (push seg result)))
           ;; Start new segment for escape sequence
           (setf current-segment (make-string-output-stream))
           (write-char char current-segment)
           (setf in-escape t)
           (incf i))
          ;; Inside escape sequence - look for terminator
          (in-escape
           (write-char char current-segment)
           ;; Check for ANSI terminator (letter a-z or @)
           (when (alpha-char-p char)
             (let ((seg (get-output-stream-string current-segment)))
               (push seg result))
             (setf current-segment (make-string-output-stream))
             (setf in-escape nil))
           (incf i))
          ;; Regular character
          (t
           (write-char char current-segment)
           (incf i)))))
    (nreverse result)))
```

**Step 4: Export the new function**

Add to exports list in package definition (line 28-35):

```lisp
  (:export
    #:tmux-available-p
    #:capture-pane-string
    #:capture-screen-string
    #:prefill-buffer-from-string
    #:prefill-backend-from-tmux
    #:make-buffer-from-tmux
    #:capture-lines
    #:split-by-ansi-sequences
    #:parse-ansi-sgr
    #:parse-ansi-string))
```

**Step 5: Run test to verify it passes**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui-tests :force t)' --eval '(5am:run! :elmtui.tests.tmux-capture)'`
Expected: PASS

**Step 6: Commit**

```bash
git add src/platform/tmux-capture.lisp tests/tmux-capture-tests.lisp
git commit -m "feat(tmux-capture): add ANSI sequence splitting utility"
```

---

## Task 3: Parse ANSI SGR sequences to style plists

**Files:**
- Modify: `src/platform/tmux-capture.lisp`
- Modify: `tests/tmux-capture-tests.lisp`

**Step 1: Write the failing test for SGR parsing**

Add to `tests/tmux-capture-tests.lisp`:

```lisp
(test parse-sgr-red-fg
  "Parsing SGR sequence for red foreground"
  (let ((result (parse-ansi-sgr "\e[31m")))
    (is (not (null result)))
    (is (eq (getf result :fg) :red))))

(test parse-sgr-bold
  "Parsing SGR sequence for bold attribute"
  (let ((result (parse-ansi-sgr "\e[1m")))
    (is (not (null result)))
    (is (member :bold (getf result :attrs)))))

(test parse-sgr-complex
  "Parsing complex SGR sequence with multiple attributes"
  (let ((result (parse-ansi-sgr "\e[1;31;42m")))
    (is (not (null result)))
    (is (eq (getf result :fg) :red))
    (is (eq (getf result :bg) :green))
    (is (member :bold (getf result :attrs)))))

(test parse-sgr-reset
  "Parsing SGR reset sequence"
  (let ((result (parse-ansi-sgr "\e[0m")))
    (is (null result))))
```

**Step 2: Run test to verify it fails**

Expected: FAIL with "function PARSE-ANSI-SGR not defined"

**Step 3: Implement parse-ansi-sgr**

Add to `src/platform/tmux-capture.lisp`:

```lisp
(defun %sgr-code->color (code kind)
  "Convert SGR color CODE to keyword.
KIND is :fg for foreground (30-37, 90-97) or :bg for background (40-47, 100-107)."
  (let ((base (ecase kind (:fg 30) (:bg 40))))
    (cond
      ;; High intensity colors (90-97, 100-107)
      ((and (>= code 90) (<= code 97))
       (let ((offset (- code (if (eq kind :fg) 90 100))))
         (ecase offset
           (0 :bright-black)
           (1 :bright-red)
           (2 :bright-green)
           (3 :bright-yellow)
           (4 :bright-blue)
           (5 :bright-magenta)
           (6 :bright-cyan)
           (7 :bright-white))))
      ;; Normal colors (30-37, 40-47)
      ((and (>= code base) (<= code (+ base 7)))
       (let ((offset (- code base)))
         (ecase offset
           (0 :black)
           (1 :red)
           (2 :green)
           (3 :yellow)
           (4 :blue)
           (5 :magenta)
           (6 :cyan)
           (7 :white))))
      (t nil))))

(defun %sgr-code->attr (code)
  "Convert SGR attribute CODE to keyword."
  (case code
    (0 :reset)
    (1 :bold)
    (2 :dim)
    (3 :italic)
    (4 :underline)
    (5 :blink)
    (7 :inverse)
    (22 :normal-intensity)
    (23 :not-italic)
    (24 :not-underline)
    (27 :not-inverse)
    (t nil)))

(defun parse-ansi-sgr (sequence)
  "Parse an ANSI SGR (Select Graphic Rendition) sequence into a style plist.
Returns NIL if the sequence is a reset, or a plist with :fg, :bg, :attrs keys.
SEQUENCE should be a string like \"\\e[31m\" or \"\\e[1;31;42m\"."
  (unless (and sequence (> (length sequence) 2))
    (return-from parse-ansi-sgr nil))
  ;; Verify it's an SGR sequence
  (unless (and (char= (aref sequence 0) #\Escape)
               (char= (aref sequence 1) #\[)
               (alpha-char-p (aref sequence (1- (length sequence)))))
    (return-from parse-ansi-sgr nil))
  ;; Extract the part between [ and final letter
  (let* ((end (1- (length sequence)))
         (params (subseq sequence 2 end)))
    (when (string= params "")
      (return-from parse-ansi-sgr nil))
    ;; Parse semicolon-separated codes
    (let ((codes (mapcar #'parse-integer
                         (split-string params :separator '(#\;))))
          (fg nil)
          (bg nil)
          (attrs '()))
      (dolist (code codes)
        (cond
          ;; Reset
          ((= code 0)
           (return-from parse-ansi-sgr nil))
          ;; Foreground colors
          ((or (and (>= code 30) (<= code 37))
               (and (>= code 90) (<= code 97)))
           (setf fg (%sgr-code->color code :fg)))
          ;; Background colors
          ((or (and (>= code 40) (<= code 47))
               (and (>= code 100) (<= code 107)))
           (setf bg (%sgr-code->color code :bg)))
          ;; Attributes
          (t
           (let ((attr (%sgr-code->attr code)))
             (when attr
               (push attr attrs))))))
      ;; Build result plist
      (let ((result '()))
        (when fg (setf (getf result :fg) fg))
        (when bg (setf (getf result :bg) bg))
        (when attrs (setf (getf result :attrs) (nreverse attrs)))
        (when (or fg bg attrs)
          result)))))
```

Add missing dependency - need to import `split-string` from alexandria. Add to imports section (line 8):

```lisp
(:import-from :alexandria #:clamp #:split-string)
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add src/platform/tmux-capture.lisp tests/tmux-capture-tests.lisp
git commit -m "feat(tmux-capture): add ANSI SGR parsing to style plists"
```

---

## Task 4: Parse full string into (text . style) runs

**Files:**
- Modify: `src/platform/tmux-capture.lisp`
- Modify: `tests/tmux-capture-tests.lisp`

**Step 1: Write the failing test for full string parsing**

Add to `tests/tmux-capture-tests.lisp`:

```lisp
(test parse-ansi-string-simple
  "Parsing a string with one ANSI sequence"
  (let* ((input "Hello \e[31mWorld\e[0m!")
         (result (parse-ansi-string input)))
    ;; Result: (("Hello " . NIL) ("World" . (:FG :RED)) ("!" . NIL))
    (is (= (length result) 3))
    (is (string= (caar result) "Hello "))
    (is (null (cdar result)))
    (is (string= (caadr result) "World"))
    (is (eq (getf (cdadr result) :fg) :red))
    (is (string= (caaddr result) "!"))
    (is (null (cdaddr result)))))

(test parse-ansi-string-no-ansi
  "Parsing a plain string with no ANSI sequences"
  (let* ((input "Just plain text")
         (result (parse-ansi-string input)))
    (is (= (length result) 1))
    (is (string= (caar result) "Just plain text"))
    (is (null (cdar result)))))

(test parse-ansi-string-empty
  "Parsing an empty string"
  (let ((result (parse-ansi-string "")))
    (is (null result))))
```

**Step 2: Run test to verify it fails**

Expected: FAIL with "function PARSE-ANSI-STRING not defined"

**Step 3: Implement parse-ansi-string**

Add to `src/platform/tmux-capture.lisp`:

```lisp
(defun parse-ansi-string (content)
  "Parse CONTENT into a list of (substring . style) pairs.
ANSI escape sequences are extracted and converted to style plists.
Returns list like ((\"text\" . NIL) (\"red\" . (:FG :RED)) ...)."
  (unless content
    (return-from parse-ansi-string '()))
  (let ((segments (split-by-ansi-sequences content))
        (result '())
        (current-style nil))
    (dolist (seg segments)
      (if (and (> (length seg) 0) (%esc-p (aref seg 0)))
          ;; This is an ANSI sequence - parse it
          (let ((parsed (parse-ansi-sgr seg)))
            (if (null parsed)
                ;; Reset sequence
                (setf current-style nil)
                ;; Update current style
                (setf current-style
                      (append parsed current-style))))
          ;; This is plain text
          (when (plusp (length seg))
            (push (cons seg current-style) result))))
    (nreverse result)))
```

**Step 4: Run test to verify it passes**

Expected: PASS

**Step 5: Commit**

```bash
git add src/platform/tmux-capture.lisp tests/tmux-capture-tests.lisp
git commit -m "feat(tmux-capture): add full ANSI string parsing to style runs"
```

---

## Task 5: Update buffer prefill to handle styled content

**Files:**
- Modify: `src/platform/tmux-capture.lisp`
- Modify: `tests/tmux-capture-tests.lisp`

**Step 1: Write the failing test for styled buffer population**

Add to `tests/tmux-capture-tests.lisp`:

```lisp
(test prefill-buffer-from-styled-string
  "Prefilling a buffer with styled string content"
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 20 2))
         (content "Hello \e[31mWorld\e[0m!")
         (runs (parse-ansi-string content)))
    ;; Prefill with styled content
    (prefill-buffer-from-styled-content buffer runs 20 2)
    ;; Check that cells are populated
    (let ((cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 0 0)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\H)))
    ;; Check that red color is applied at position 6 (W)
    (let ((cell (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 0 6)))
      (is (char= (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char cell) #\W))
      (is (not (null (elmtui.platform.backend.common.virtual-buffer:buffer-cell-style cell)))))))

(test prefill-buffer-from-styled-empty
  "Prefilling with empty runs does nothing"
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 10 1))
         (runs '()))
    (prefill-buffer-from-styled-content buffer runs 10 1)
    ;; Should not error
    (is t)))
```

**Step 2: Run test to verify it fails**

Expected: FAIL with "function PREFILL-BUFFER-FROM-STYLED-CONTENT not defined"

**Step 3: Implement prefill-buffer-from-styled-content**

Add to `src/platform/tmux-capture.lisp`:

```lisp
(defun prefill-buffer-from-styled-content (buffer runs width height)
  "Fill BUFFER (virtual-terminal-buffer) with styled RUNS from parse-ansi-string.
RUNS is a list of (substring . style) pairs.
WIDTH and HEIGHT specify the buffer dimensions for wrapping."
  (when (and buffer runs)
    (with-virtual-buffer-lock (buffer)
      (clear-buffer buffer)
      (let ((row 0)
            (col 0))
        (dolist (run runs)
          (let* ((text (car run))
                 (style (cdr run))
                 (text-len (length text)))
            (loop for i from 0 below text-len
                  when (and (< row height) (< col width))
                  do (let ((char (aref text i)))
                       (set-buffer-cell-at buffer row col char style)
                       (incf col)
                       ;; Wrap to next line if needed
                       (when (>= col width)
                         (setf col 0)
                         (incf row)
                         (when (>= row height)
                           (return)))))))))
    buffer))
```

**Step 4: Export the new function**

Add to exports (already added in Task 2, verify it's there):

```lisp
    #:prefill-buffer-from-styled-content
```

**Step 5: Run test to verify it passes**

Expected: PASS

**Step 6: Commit**

```bash
git add src/platform/tmux-capture.lisp tests/tmux-capture-tests.lisp
git commit -m "feat(tmux-capture): add styled buffer prefill function"
```

---

## Task 6: Update high-level functions to use styled parsing

**Files:**
- Modify: `src/platform/tmux-capture.lisp`

**Step 1: Update capture-pane-string to use screen mode by default for styles**

The current implementation has a mode parameter but :screen mode includes escape sequences.

Verify current implementation:

```lisp
(defun capture-pane-string (&key (mode :pane))
  "Capture the current tmux pane (MODE :pane or :screen) and return it as a string."
  (case mode
    (:screen (%run-tmux "capture-pane" "-e" "-J" "-p"))
    (otherwise (%run-tmux "capture-pane" "-p"))))
```

Update to always use `-e` flag (include escape sequences):

```lisp
(defun capture-pane-string (&key (mode :pane))
  "Capture the current tmux pane (MODE :pane or :screen) and return it as a string.
The -e flag ensures escape sequences are included for style preservation."
  (case mode
    (:screen (%run-tmux "capture-pane" "-e" "-J" "-p"))
    (otherwise (%run-tmux "capture-pane" "-e" "-p"))))
```

**Step 2: Add make-buffer-from-tmux-styled**

```lisp
(defun make-buffer-from-tmux-styled (width height &key (mode :pane))
  "Create a virtual buffer populated from tmux output with ANSI styles parsed."
  (when (tmux-available-p)
    (let ((content (capture-pane-string :mode mode)))
      (when content
        (let* ((runs (parse-ansi-string content))
               (buffer (make-virtual-buffer width height)))
          (prefill-buffer-from-styled-content buffer runs width height)
          buffer)))))
```

**Step 3: Update prefill-backend-from-tmux to use styled version**

```lisp
(defun prefill-backend-from-tmux (backend &key (mode :pane) (styled t))
  "Prefill terminal backend buffers from current tmux capture.
If STYLED is T, parse ANSI escape sequences for color/style information.
Returns a virtual buffer copy that can be used as the driver's previous frame."
  (when (and (tmux-available-p)
          (typep backend 'terminal-instance))
    (let* ((width (term-w backend))
            (height (term-h backend))
            (content (capture-pane-string :mode mode)))
      (when (and content width height)
        (let ((front (terminal-instance-front-buffer backend))
               (back (terminal-instance-back-buffer backend))
               (runs (parse-ansi-string content)))
          (when front
            (prefill-buffer-from-styled-content front runs width height))
          (when back
            (prefill-buffer-from-styled-content back runs width height))
          (let ((snapshot (make-virtual-buffer width height)))
            (prefill-buffer-from-styled-content snapshot runs width height)
            snapshot))))))
```

**Step 4: Export new function**

Add to exports:

```lisp
    #:make-buffer-from-tmux-styled
```

**Step 5: Compile to verify**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui :force t)'`
Expected: SUCCESS

**Step 6: Commit**

```bash
git add src/platform/tmux-capture.lisp
git commit -m "feat(tmux-capture): update high-level functions to use styled parsing"
```

---

## Task 7: Add integration tests (require tmux)

**Files:**
- Modify: `tests/tmux-capture-tests.lisp`

**Step 1: Add integration test suite**

Add to `tests/tmux-capture-tests.lisp`:

```lisp
(def-suite tmux-capture-integration-tests
  :in elmtui.tests:elmtui-test
  :description "Integration tests requiring tmux to be installed")

(in-suite tmux-capture-integration-tests)

(test tmux-available-detects-installation
  "tmux-available-p returns true when tmux is installed"
  ;; This test may pass or fail depending on environment
  ;; That's ok - it documents expected behavior
  (is (booleanp (tmux-available-p))))

(test capture-pane-string-returns-string
  "capture-pane-string returns a string when tmux is available"
  (skip-if (not (tmux-available-p)) "tmux not available")
  (let ((result (capture-pane-string)))
    (is (stringp result))
    (is (plusp (length result)))))

(test parse-captured-content
  "Content from capture-pane-string can be parsed"
  (skip-if (not (tmux-available-p)) "tmux not available")
  (let* ((content (capture-pane-string))
         (runs (parse-ansi-string content)))
    (is (listp runs))))
```

**Step 2: Compile and run integration tests**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui-tests :force t)' --eval '(5am:run! :elmtui.tests.tmux-capture)'`

If tmux is installed: Integration tests PASS
If tmux is not installed: Integration tests SKIP

**Step 3: Commit**

```bash
git add tests/tmux-capture-tests.lisp
git commit -m "test(tmux-capture): add integration tests for tmux capture"
```

---

## Task 8: Update test system definition

**Files:**
- Modify: `elmtui-tests.asd`

**Step 1: Add tmux-capture-tests to test system**

Find the tests module and add the new test file:

```lisp
(:module "tests"
  :pathname "tests/"
  :components (
    ;; ... existing test files ...
    (:file "tmux-capture-tests" :depends-on ("cleanup-regression-tests"))
    ))
```

**Step 2: Compile test system**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui-tests :force t)'`
Expected: SUCCESS

**Step 3: Run all tmux-capture tests**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(5am:run! :elmtui.tests.tmux-capture)'`
Expected: All unit tests PASS; integration tests SKIP or PASS depending on tmux

**Step 4: Commit**

```bash
git add elmtui-tests.asd
git commit -m "build(tests): add tmux-capture-tests to test suite"
```

---

## Task 9: Document usage in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add tmux-capture usage section**

Add before "## Key Files" section:

```markdown
## Tmux Screen Capture

The `elmtui.platform.tmux` module provides seamless TUI transitions by capturing the current tmux pane contents before starting the application.

### Usage

To enable tmux prefill in your application:

```lisp
(run-app-platform app-spec
  :platform-options '(:prefill-from-tmux t
                     :tmux-prefill-mode :screen))
```

Options:
- `:prefill-from-tmux` - Enable tmux capture (boolean, default: NIL)
- `:tmux-prefill-mode` - `:pane` (default) or `:screen` for full history

### API Functions

- `(tmux-available-p)` - Check if running inside tmux
- `(capture-pane-string &key mode)` - Get raw tmux output as string
- `(parse-ansi-string content)` - Parse ANSI styles into (text . style) runs
- `(make-buffer-from-tmux-styled width height &key mode)` - Create styled buffer
- `(prefill-backend-from-tmux backend &key mode styled)` - Prefill backend buffers

### Style Preservation

When `styled` is T (default), ANSI escape sequences are parsed and stored as cell styles:
- Colors: `:fg`, `:bg` keywords (e.g., `:red`, `:green`, `:blue`)
- Attributes: `:bold`, `:italic`, `:underline`, `:inverse`

```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(tmux-capture): add usage documentation"
```

---

## Task 10: Final verification and cleanup

**Files:**
- Various

**Step 1: Run full test suite**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --load run-tests-clpm.lisp`
Expected: All tests PASS (tmux integration tests may SKIP if tmux unavailable)

**Step 2: Check for compiler warnings**

Run: `clpm bundle exec --with-client sbcl -- --noinform --non-interactive --eval '(asdf:compile-system :elmtui :force t)'`
Expected: SUCCESS with no warnings

**Step 3: Verify no parentheses errors**

Use sexp-manipulator skill's validation:

```bash
python3 ~/.claude/skills/sexp-manipulator/scripts/sexp_utils.py validate src/platform/tmux-capture.lisp
python3 ~/.claude/skills/sexp-manipulator/scripts/sexp_utils.py validate tests/tmux-capture-tests.lisp
```
Expected: "All parentheses balanced!"

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(tmux-capture): complete refactor with ANSI style preservation"
```

---

## Summary

This plan:
1. **Fixed** tmux binary detection using `uiop:find-program`
2. **Added** ANSI sequence parsing utilities with full test coverage
3. **Implemented** style preservation via (text . style) run parsing
4. **Updated** buffer prefill to handle styled content
5. **Provided** both unit tests (mocked) and integration tests (require tmux)
6. **Documented** usage in CLAUDE.md

Total estimated time: 2-3 hours for all tasks.
