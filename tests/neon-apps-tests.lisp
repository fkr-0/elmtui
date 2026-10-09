;;;; Isolated unit tests: no terminal, no disk write, no live timer required.
(uiop:define-package :elmtui.tests.neon-apps
  (:use :cl :fiveam)
  (:import-from :elmtui.state.api #:ur-patches #:ur-commands)
  (:export #:neon-apps-tests))
(in-package :elmtui.tests.neon-apps)

(def-suite neon-apps-tests
  :description "Pong, Tetris, Nano and Less parity, views and pure updates")
(in-suite neon-apps-tests)

(defun %key (character &optional modifiers)
  (list :keyevent :key character :char character :modifiers modifiers))

(defun %patch-value (result key)
  (second (assoc (list key) (ur-patches result) :test #'equal)))

(test pong-players-and-quit
  (let* ((s (elmtui.examples.neon-pong:initial-state))
         (up (elmtui.examples.neon-pong:pong-update (%key #\w) s))
         (right (elmtui.examples.neon-pong:pong-update (%key #\k) s))
         (quit (elmtui.examples.neon-pong:pong-update (%key #\q) s)))
    (is (= 3 (%patch-value up :left-y)))
    (is (= 5 (%patch-value right :right-y)))
    (is (eq t (%patch-value quit :should-quit)))))

(test pong-no-tick-mutation-while-waiting-to-serve
  (let ((s (elmtui.examples.neon-pong:initial-state)))
    (setf (getf s :served) nil)
    (is (null (ur-patches (elmtui.examples.neon-pong:pong-update '(:tick) s))))))

(test pong-paddle-bounce-and-scoring
  (let ((s (elmtui.examples.neon-pong:initial-state)))
    (setf (getf s :ball-x) 1 (getf s :ball-y) 5
          (getf s :dx) -1 (getf s :dy) 1)
    (is (= 1 (%patch-value
               (elmtui.examples.neon-pong:pong-update :tick s) :dx)))
    (setf (getf s :ball-x) 0 (getf s :ball-y) 1
          (getf s :dx) -1 (getf s :dy) -1)
    (is (= 1 (%patch-value
               (elmtui.examples.neon-pong:pong-update :tick s)
               :right-score)))))

(test pong-view-has-telemetry-and-styled-rows
  (let* ((view (elmtui.examples.neon-pong:pong-view
                (elmtui.examples.neon-pong:initial-state)))
         (children (getf (rest view) :children)))
    (is (eq (first view) :container))
    (is (= (length children) 22))
    (is (search "NEON CIRCUIT" (getf (rest (first children)) :content)))
    (is (getf (getf (rest (first children)) :style) :fg-color))))

(test tetris-shapes-and-bounds
  (let ((well (elmtui.examples.neon-tetris::empty-well)))
    (loop for shape below 4 do
      (is (= 4 (length (elmtui.examples.neon-tetris:piece-cells shape 0)))))
    (is (elmtui.examples.neon-tetris:collision-p well 0 0 -1 0))
    (is (elmtui.examples.neon-tetris:collision-p well 1 0 4 13))
    (is (not (elmtui.examples.neon-tetris:collision-p well 0 0 4 0)))))

(test tetris-clears-full-lines-without-mutating-input
  (let ((well (elmtui.examples.neon-tetris::empty-well)))
    (setf (aref well 15) "##########")
    (multiple-value-bind (cleared count)
        (elmtui.examples.neon-tetris:clear-rows well)
      (is (= count 1))
      (is (string= (aref well 15) "##########"))
      (is (string= (aref cleared 0) ".........."))
      (is (string= (aref cleared 15) "..........")))))

(test tetris-rotate-fall-and-reset
  (let* ((s (elmtui.examples.neon-tetris:initial-state))
         (rotate (elmtui.examples.neon-tetris:tetris-update (%key #\w) s))
         (fall (elmtui.examples.neon-tetris:tetris-update :tick s))
         (reset (elmtui.examples.neon-tetris:tetris-update (%key #\r) s)))
    (is (null (ur-patches rotate))) ; O rotation has the same geometry.
    (is (= 1 (%patch-value fall :y)))
    (is (= 0 (%patch-value reset :piece-id)))))

(test tetris-ended-means-no-idle-state-changes
  (let ((s (elmtui.examples.neon-tetris:initial-state)))
    (setf (getf s :ended) t)
    (is (null (ur-patches (elmtui.examples.neon-tetris:tetris-update :tick s))))
    (is (search "STACK LAB" (getf
                             (rest (first (getf (rest
                                                 (elmtui.examples.neon-tetris:tetris-view s))
                                                :children)))
                             :content)))))

(test nano-control-exit-and-save-dialog
  (let* ((s (elmtui.examples.neon-nano:initial-state))
         (save (elmtui.examples.neon-nano:nano-update
                (%key #\o '(:control)) s))
         (exit (elmtui.examples.neon-nano:nano-update
                (%key #\x '(:control)) s)))
    (is (equal '(:modal) (first (first (ur-patches save)))))
    (is (second (first (ur-patches save))))
    (is (eq t (%patch-value exit :should-quit)))))

(test nano-visible-cursor-and-appearance
  (let* ((s (elmtui.examples.neon-nano:initial-state))
         (view (elmtui.examples.neon-nano:nano-view s))
         (children (getf (rest view) :children)))
    (is (search "MIDNIGHT EDITOR"
                (getf (rest (first children)) :content)))
    (is (some (lambda (node)
                (search "▌" (getf (rest node) :content)))
              children))))

(test less-clamps-viewport
  (let ((s (elmtui.examples.neon-less:initial-state)))
    (is (= 16 (%patch-value
               (elmtui.examples.neon-less:less-update (%key #\f) s)
               :scroll)))
    (is (= 0 (length (ur-patches
                      (elmtui.examples.neon-less:less-update (%key #\k) s)))))
    (is (> (%patch-value
            (elmtui.examples.neon-less:less-update (%key #\G) s)
            :scroll) 0))))

(test less-no-idle-tick
  (let ((s (elmtui.examples.neon-less:initial-state)))
    (is (null (ur-patches (elmtui.examples.neon-less:less-update :tick s))))
    (is (eq t (%patch-value
               (elmtui.examples.neon-less:less-update (%key #\q) s)
               :should-quit)))))
