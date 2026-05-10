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

(test normalize-lines-uses-tail-for-visible-window
  "When content has more lines than HEIGHT, we keep the last HEIGHT lines."
  (let* ((content (format nil "L0~%L1~%L2~%L3~%L4"))
         (lines (elmtui.platform.tmux::%normalize-lines content 10 3)))
    (is (= 3 (length lines)))
    (is (string= "L2" (aref lines 0)))
    (is (string= "L3" (aref lines 1)))
    (is (string= "L4" (aref lines 2)))))

(test split-by-ansi-simple
  "Splitting a string with ANSI escape sequences works correctly"
  (let* ((input (concatenate 'string "Hello" (format nil "~C[31m" #\Escape) "World" (format nil "~C[0m" #\Escape) "!"))
          (result (split-by-ansi-sequences input)))
    ;; Result: ("Hello" "^[31m" "World" "^[0m" "!")
    (is (= (length result) 5))
    (is (string= (first result) "Hello"))
    (is (string= (second result) (format nil "~C[31m" #\Escape)))
    (is (string= (third result) "World"))
    (is (string= (fourth result) (format nil "~C[0m" #\Escape)))
    (is (string= (fifth result) "!"))))

(test parse-ansi-sgr-all-basic-colors
  "Parsing SGR sequences for all basic foreground colors"
  ;; Test codes 30-37 (black, red, green, yellow, blue, magenta, cyan, white)
  (is (equal (parse-ansi-sgr (format nil "~C[30m" #\Escape)) '(:fg :black)))
  (is (equal (parse-ansi-sgr (format nil "~C[31m" #\Escape)) '(:fg :red)))
  (is (equal (parse-ansi-sgr (format nil "~C[32m" #\Escape)) '(:fg :green)))
  (is (equal (parse-ansi-sgr (format nil "~C[33m" #\Escape)) '(:fg :yellow)))
  (is (equal (parse-ansi-sgr (format nil "~C[34m" #\Escape)) '(:fg :blue)))
  (is (equal (parse-ansi-sgr (format nil "~C[35m" #\Escape)) '(:fg :magenta)))
  (is (equal (parse-ansi-sgr (format nil "~C[36m" #\Escape)) '(:fg :cyan)))
  (is (equal (parse-ansi-sgr (format nil "~C[37m" #\Escape)) '(:fg :white))))

(test parse-ansi-sgr-background-colors
  "Parsing SGR sequences for background colors"
  ;; Test codes 40-47
  (is (equal (parse-ansi-sgr (format nil "~C[40m" #\Escape)) '(:bg :black)))
  (is (equal (parse-ansi-sgr (format nil "~C[41m" #\Escape)) '(:bg :red)))
  (is (equal (parse-ansi-sgr (format nil "~C[42m" #\Escape)) '(:bg :green)))
  (is (equal (parse-ansi-sgr (format nil "~C[43m" #\Escape)) '(:bg :yellow)))
  (is (equal (parse-ansi-sgr (format nil "~C[44m" #\Escape)) '(:bg :blue)))
  (is (equal (parse-ansi-sgr (format nil "~C[45m" #\Escape)) '(:bg :magenta)))
  (is (equal (parse-ansi-sgr (format nil "~C[46m" #\Escape)) '(:bg :cyan)))
  (is (equal (parse-ansi-sgr (format nil "~C[47m" #\Escape)) '(:bg :white))))

(test parse-ansi-sgr-bright-colors
  "Parsing SGR sequences for high-intensity colors"
  ;; Test codes 90-97 (bright foreground)
  (is (equal (parse-ansi-sgr (format nil "~C[90m" #\Escape)) '(:fg :bright-black)))
  (is (equal (parse-ansi-sgr (format nil "~C[91m" #\Escape)) '(:fg :bright-red)))
  (is (equal (parse-ansi-sgr (format nil "~C[92m" #\Escape)) '(:fg :bright-green)))
  (is (equal (parse-ansi-sgr (format nil "~C[93m" #\Escape)) '(:fg :bright-yellow)))
  (is (equal (parse-ansi-sgr (format nil "~C[94m" #\Escape)) '(:fg :bright-blue)))
  (is (equal (parse-ansi-sgr (format nil "~C[95m" #\Escape)) '(:fg :bright-magenta)))
  (is (equal (parse-ansi-sgr (format nil "~C[96m" #\Escape)) '(:fg :bright-cyan)))
  (is (equal (parse-ansi-sgr (format nil "~C[97m" #\Escape)) '(:fg :bright-white)))
  ;; Test codes 100-107 (bright background)
  (is (equal (parse-ansi-sgr (format nil "~C[100m" #\Escape)) '(:bg :bright-black)))
  (is (equal (parse-ansi-sgr (format nil "~C[101m" #\Escape)) '(:bg :bright-red))))

(test parse-ansi-sgr-attributes
  "Parsing SGR sequences for text attributes"
  (is (equal (parse-ansi-sgr (format nil "~C[1m" #\Escape)) '(:attrs (:bold))))
  (is (equal (parse-ansi-sgr (format nil "~C[2m" #\Escape)) '(:attrs (:dim))))
  (is (equal (parse-ansi-sgr (format nil "~C[3m" #\Escape)) '(:attrs (:italic))))
  (is (equal (parse-ansi-sgr (format nil "~C[4m" #\Escape)) '(:attrs (:underline))))
  (is (equal (parse-ansi-sgr (format nil "~C[5m" #\Escape)) '(:attrs (:blink))))
  (is (equal (parse-ansi-sgr (format nil "~C[7m" #\Escape)) '(:attrs (:inverse)))))

(test parse-ansi-sgr-combinations
  "Parsing SGR sequences with multiple codes (fg + bg + attrs)"
  ;; Red foreground, blue background, bold
  (let ((result (parse-ansi-sgr (format nil "~C[1;31;44m" #\Escape))))
    (is (equal (getf result :fg) :red))
    (is (equal (getf result :bg) :blue))
    (is (member :bold (getf result :attrs))))
  ;; Green foreground, white background, bold + underline
  (let ((result (parse-ansi-sgr (format nil "~C[1;4;32;47m" #\Escape))))
    (is (equal (getf result :fg) :green))
    (is (equal (getf result :bg) :white))
    (is (member :bold (getf result :attrs)))
    (is (member :underline (getf result :attrs)))))

(test parse-ansi-string-with-multiple-sequences
  "Parsing a string with multiple ANSI sequences"
  (let* ((input (concatenate 'string
                  (format nil "~C[31;1m" #\Escape) "RED"
                  (format nil "~C[0m" #\Escape) " "
                  (format nil "~C[34;4m" #\Escape) "BLUE"
                  (format nil "~C[0m" #\Escape)))
          (result (parse-ansi-string input)))
    ;; Should get: (("RED" . (:fg :red :attrs (:bold)))
    ;;              (" " . nil)
    ;;              ("BLUE" . (:fg :blue :attrs (:underline))))
    (is (= (length result) 3))
    ;; First segment: RED with bold red
    (is (string= (caar result) "RED"))
    (let ((style (cdar result)))
      (is (equal (getf style :fg) :red))
      (is (member :bold (getf style :attrs))))
    ;; Second segment: space with no style
    (is (string= (caadr result) " "))
    (is (null (cdadr result)))
    ;; Third segment: BLUE with underline blue
    (is (string= (caaddr result) "BLUE"))
    (let ((style (cdaddr result)))
      (is (equal (getf style :fg) :blue))
      (is (member :underline (getf style :attrs))))))
(test split-by-ansi-empty-string
  "Splitting an empty string returns empty list"
  (is (null (split-by-ansi-sequences ""))))

(test split-by-ansi-ansi-only
  "Splitting a string with only ANSI sequences returns just those sequences"
  (let* ((input (format nil "~C[31m~C[0m" #\Escape #\Escape))
          (result (split-by-ansi-sequences input)))
    (is (= (length result) 2))
    (is (char= (aref (first result) 0) #\Escape))
    (is (char= (aref (second result) 0) #\Escape))))

(test parse-ansi-sgr-reset-returns-nil
  "Parsing a reset sequence (code 0) returns NIL"
  (is (null (parse-ansi-sgr (format nil "~C[0m" #\Escape)))))

(test parse-ansi-sgr-invalid-code
  "Parsing an invalid SGR code returns NIL"
  (is (null (parse-ansi-sgr (format nil "~C[99m" #\Escape))))
  (is (null (parse-ansi-sgr (format nil "~C[999m" #\Escape)))))

;;;----------------------------------------------------------------
;;; 256-Color Mode Tests (ESC[38;5;n and ESC[48;5;n)
;;;----------------------------------------------------------------

(test parse-ansi-sgr-256-color-fg
  "Parsing 256-color foreground mode (38;5;n)"
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;123m" #\Escape))))
    (is (consp (getf result :fg)))
    (is (eq (first (getf result :fg)) :256))
    (is (= (second (getf result :fg)) 123)))
  ;; Test color 0 (black in 256 palette)
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;0m" #\Escape))))
    (is (equal (getf result :fg) '(:256 0))))
  ;; Test color 15 (white in 256 palette)
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;15m" #\Escape))))
    (is (equal (getf result :fg) '(:256 15))))
  ;; Test color 231 (end of color cube)
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;231m" #\Escape))))
    (is (equal (getf result :fg) '(:256 231))))
  ;; Test color 255 (end of grayscale)
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;255m" #\Escape))))
    (is (equal (getf result :fg) '(:256 255)))))

(test parse-ansi-sgr-256-color-bg
  "Parsing 256-color background mode (48;5;n)"
  (let ((result (parse-ansi-sgr (format nil "~C[48;5;123m" #\Escape))))
    (is (consp (getf result :bg)))
    (is (eq (first (getf result :bg)) :256))
    (is (= (second (getf result :bg)) 123)))
  ;; Test various 256-color background values
  (is (equal (parse-ansi-sgr (format nil "~C[48;5;0m" #\Escape)) '(:bg (:256 0))))
  (is (equal (parse-ansi-sgr (format nil "~C[48;5;127m" #\Escape)) '(:bg (:256 127)))))

(test parse-ansi-sgr-256-color-both
  "Parsing both foreground and background 256-color"
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;100;48;5;50m" #\Escape))))
    (is (equal (getf result :fg) '(:256 100)))
    (is (equal (getf result :bg) '(:256 50)))))

;;;----------------------------------------------------------------
;;; 24-bit RGB Color Mode Tests (ESC[38;2;r;g;b and ESC[48;2;r;g;b)
;;;----------------------------------------------------------------

(test parse-ansi-sgr-rgb-fg
  "Parsing RGB foreground mode (38;2;r;g;b)"
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;255;0;0m" #\Escape))))
    (is (consp (getf result :fg)))
    (is (eq (first (getf result :fg)) :rgb))
    (is (= (second (getf result :fg)) 255))
    (is (= (third (getf result :fg)) 0))
    (is (= (fourth (getf result :fg)) 0)))
  ;; Test pure green
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;0;255;0m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 0 255 0))))
  ;; Test pure blue
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;0;0;255m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 0 0 255))))
  ;; Test custom color
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;128;64;192m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 128 64 192)))))

(test parse-ansi-sgr-rgb-bg
  "Parsing RGB background mode (48;2;r;g;b)"
  (let ((result (parse-ansi-sgr (format nil "~C[48;2;255;128;64m" #\Escape))))
    (is (consp (getf result :bg)))
    (is (eq (first (getf result :bg)) :rgb))
    (is (= (second (getf result :bg)) 255))
    (is (= (third (getf result :bg)) 128))
    (is (= (fourth (getf result :bg)) 64)))
  ;; Test various RGB background colors
  (is (equal (parse-ansi-sgr (format nil "~C[48;2;100;100;100m" #\Escape)) '(:bg (:rgb 100 100 100)))))

(test parse-ansi-sgr-rgb-both
  "Parsing both foreground and background RGB"
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;255;0;0;48;2;0;0;255m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 255 0 0)))
    (is (equal (getf result :bg) '(:rgb 0 0 255)))))

(test parse-ansi-sgr-mixed-color-modes
  "Parsing mixed basic and extended color modes"
  ;; Basic foreground with 256-color background
  (let ((result (parse-ansi-sgr (format nil "~C[31;48;5;100m" #\Escape))))
    (is (equal (getf result :fg) :red))
    (is (equal (getf result :bg) '(:256 100))))
  ;; 256-color foreground with RGB background
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;50;48;2;200;200;200m" #\Escape))))
    (is (equal (getf result :fg) '(:256 50)))
    (is (equal (getf result :bg) '(:rgb 200 200 200))))
  ;; RGB foreground with basic background
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;100;150;200;44m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 100 150 200)))
    (is (equal (getf result :bg) :blue))))

;;;----------------------------------------------------------------
;;; Additional Missing ANSI SGR Codes
;;;----------------------------------------------------------------

(test parse-ansi-sgr-strike
  "Parsing strike-through attribute (code 9)"
  (is (equal (parse-ansi-sgr (format nil "~C[9m" #\Escape)) '(:attrs (:strike)))))

(test parse-ansi-sgr-italic
  "Parsing italic attribute (code 3)"
  (is (equal (parse-ansi-sgr (format nil "~C[3m" #\Escape)) '(:attrs (:italic)))))

(test parse-ansi-sgr-dim-faint
  "Parsing dim/faint attribute (code 2)"
  (is (equal (parse-ansi-sgr (format nil "~C[2m" #\Escape)) '(:attrs (:dim)))))

(test parse-ansi-sgr-blink
  "Parsing blink attribute (code 5)"
  (is (equal (parse-ansi-sgr (format nil "~C[5m" #\Escape)) '(:attrs (:blink)))))

(test parse-ansi-sgr-inverse
  "Parsing inverse/reverse attribute (code 7)"
  (is (equal (parse-ansi-sgr (format nil "~C[7m" #\Escape)) '(:attrs (:inverse)))))

(test parse-ansi-sgr-underline
  "Parsing underline attribute (code 4)"
  (is (equal (parse-ansi-sgr (format nil "~C[4m" #\Escape)) '(:attrs (:underline)))))

(test parse-ansi-sgr-multiple-attrs
  "Parsing multiple attributes together"
  (let ((result (parse-ansi-sgr (format nil "~C[1;3;4m" #\Escape))))
    (is (member :bold (getf result :attrs)))
    (is (member :italic (getf result :attrs)))
    (is (member :underline (getf result :attrs)))))

(test parse-ansi-sgr-extended-with-attrs
  "Parsing extended color modes with attributes"
  (let ((result (parse-ansi-sgr (format nil "~C[1;38;5;100m" #\Escape))))
    (is (equal (getf result :fg) '(:256 100)))
    (is (member :bold (getf result :attrs))))
  ;; RGB with bold
  (let ((result (parse-ansi-sgr (format nil "~C[38;2;255;0;0;1m" #\Escape))))
    (is (equal (getf result :fg) '(:rgb 255 0 0)))
    (is (member :bold (getf result :attrs)))))

;;;----------------------------------------------------------------
;;; Additional Missing ANSI SGR Codes
;;;----------------------------------------------------------------

(test parse-ansi-sgr-blink-rapid
  "Parsing rapid blink attribute (code 6)"
  (is (equal (parse-ansi-sgr (format nil "~C[6m" #\Escape)) '(:attrs (:blink-rapid)))))

(test parse-ansi-sgr-blink-both
  "Parsing both slow (code 5) and rapid (code 6) blink"
  ;; Just slow blink
  (is (equal (parse-ansi-sgr (format nil "~C[5m" #\Escape)) '(:attrs (:blink))))
  ;; Just rapid blink
  (is (equal (parse-ansi-sgr (format nil "~C[6m" #\Escape)) '(:attrs (:blink-rapid))))
  ;; Both - should have both in attrs
  (let ((result (parse-ansi-sgr (format nil "~C[5;6m" #\Escape))))
    (is (member :blink (getf result :attrs)))
    (is (member :blink-rapid (getf result :attrs)))))

(test parse-ansi-sgr-proportional-spacing
  "Parsing proportional spacing attribute (code 26)"
  (is (equal (parse-ansi-sgr (format nil "~C[26m" #\Escape)) '(:attrs (:proportional)))))

(test parse-ansi-sgr-overline
  "Parsing overline attribute (code 53)"
  (is (equal (parse-ansi-sgr (format nil "~C[53m" #\Escape)) '(:attrs (:overline)))))

(test parse-ansi-sgr-not-overline
  "Parsing not overline attribute (code 55)"
  (is (equal (parse-ansi-sgr (format nil "~C[55m" #\Escape)) '(:attrs (:not-overline)))))

(test parse-ansi-sgr-default-fg
  "Parsing default foreground color (code 39)"
  (is (equal (parse-ansi-sgr (format nil "~C[39m" #\Escape)) '(:fg :default))))

(test parse-ansi-sgr-default-bg
  "Parsing default background color (code 49)"
  (is (equal (parse-ansi-sgr (format nil "~C[49m" #\Escape)) '(:bg :default))))

(test parse-ansi-sgr-both-default-colors
  "Parsing both default foreground and background"
  (let ((result (parse-ansi-sgr (format nil "~C[39;49m" #\Escape))))
    (is (equal (getf result :fg) :default))
    (is (equal (getf result :bg) :default))))

(test parse-ansi-sgr-code-38-without-params
  "Parsing code 38 without extended parameters (should act as 39 - default fg)"
  (is (equal (parse-ansi-sgr (format nil "~C[38m" #\Escape)) '(:fg :default))))

(test parse-ansi-sgr-code-48-without-params
  "Parsing code 48 without extended parameters (should act as 49 - default bg)"
  (is (equal (parse-ansi-sgr (format nil "~C[48m" #\Escape)) '(:bg :default))))

(test parse-ansi-sgr-code-38-invalid-mode
  "Parsing code 38 with invalid mode (should act as default fg)"
  ;; Mode 99 is not a valid extended mode
  (is (equal (parse-ansi-sgr (format nil "~C[38;99m" #\Escape)) '(:fg :default))))

(test parse-ansi-sgr-code-48-invalid-mode
  "Parsing code 48 with invalid mode (should act as default bg)"
  (is (equal (parse-ansi-sgr (format nil "~C[48;99m" #\Escape)) '(:bg :default))))

(test parse-ansi-sgr-default-with-basic-colors
  "Parsing default colors mixed with basic colors"
  (let ((result (parse-ansi-sgr (format nil "~C[31;39m" #\Escape))))
    ;; After setting red fg, then default fg, should have default
    (is (equal (getf result :fg) :default)))
  (let ((result (parse-ansi-sgr (format nil "~C[44;49;31m" #\Escape))))
    ;; Blue bg, then default bg, then red fg
    (is (equal (getf result :bg) :default))
    (is (equal (getf result :fg) :red))))

(test parse-ansi-sgr-complex-combination
  "Parsing complex combination of colors and attributes"
  ;; Bold, red fg, blue bg, underline
  (let ((result (parse-ansi-sgr (format nil "~C[1;31;44;4m" #\Escape))))
    (is (equal (getf result :fg) :red))
    (is (equal (getf result :bg) :blue))
    (is (member :bold (getf result :attrs)))
    (is (member :underline (getf result :attrs))))
  ;; 256-color fg, RGB bg, italic, strike
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;123;48;2;100;150;200;3;9m" #\Escape))))
    (is (equal (getf result :fg) '(:256 123)))
    (is (equal (getf result :bg) '(:rgb 100 150 200)))
    (is (member :italic (getf result :attrs)))
    (is (member :strike (getf result :attrs)))))

(test parse-ansi-sgr-reset-clears-extended-colors
  "Parsing reset code should clear all extended colors too"
  ;; Set extended colors, then reset
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;100m" #\Escape))))
    (is (equal (getf result :fg) '(:256 100))))
  ;; Reset returns NIL
  (is (null (parse-ansi-sgr (format nil "~C[0m" #\Escape)))))

(test parse-ansi-sgr-off-attributes
  "Parsing attribute off codes"
  (is (equal (parse-ansi-sgr (format nil "~C[22m" #\Escape)) '(:attrs (:normal-intensity))))
  (is (equal (parse-ansi-sgr (format nil "~C[23m" #\Escape)) '(:attrs (:not-italic))))
  (is (equal (parse-ansi-sgr (format nil "~C[24m" #\Escape)) '(:attrs (:not-underline))))
  (is (equal (parse-ansi-sgr (format nil "~C[25m" #\Escape)) '(:attrs (:blink-off))))
  (is (equal (parse-ansi-sgr (format nil "~C[27m" #\Escape)) '(:attrs (:not-inverse))))
  (is (equal (parse-ansi-sgr (format nil "~C[28m" #\Escape)) '(:attrs (:not-hidden))))
  (is (equal (parse-ansi-sgr (format nil "~C[29m" #\Escape)) '(:attrs (:not-strike)))))

(test parse-ansi-sgr-sequence-with-defaults
  "Parsing sequences with default color codes interspersed"
  ;; Set 256 fg, then default, then basic red
  (let ((result (parse-ansi-sgr (format nil "~C[38;5;50;39;31m" #\Escape))))
    ;; Last color wins (red)
    (is (equal (getf result :fg) :red)))
  ;; Set RGB bg, then default, then basic blue
  (let ((result (parse-ansi-sgr (format nil "~C[48;2;100;100;100;49;44m" #\Escape))))
    ;; Last color wins (blue)
    (is (equal (getf result :bg) :blue))))

(test prefill-buffer-from-styled-content-preserves-newlines
  "Styled tmux prefill should treat embedded newlines as row breaks."
  (let* ((buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer 5 2))
         (runs '(("ab
cd" . nil))))
    (elmtui.platform.tmux:prefill-buffer-from-styled-content buffer runs 5 2)
    (is (char= #\a
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 0 0))))
    (is (char= #\b
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 0 1))))
    (is (char= #\c
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 1 0))))
    (is (char= #\d
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 1 1))))
    (is (char= #\Space
               (elmtui.platform.backend.common.virtual-buffer:buffer-cell-char
                (elmtui.platform.backend.common.virtual-buffer:buffer-cell-at buffer 0 2))))))
