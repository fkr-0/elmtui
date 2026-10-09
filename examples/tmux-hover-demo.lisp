;;; Public hover compatibility runners for the shared ElmTUI inspector.
(uiop:define-package :elmtui-examples.tmux-hover-demo (:use :cl) (:export #:run-tmux-hover-demo #:run-tmux-hover-inspector))

(in-package :elmtui-examples.tmux-hover-demo)

(defun run-tmux-hover-demo (&key (backend-type :terminal) (mode :pane)) "Compatibility entry point for the normal-buffer ElmTUI inspector." (run-tmux-hover-inspector :backend-type backend-type :mode mode))

(defun run-tmux-hover-inspector (&key (backend-type :terminal) (mode :pane)) "Use the maintained ElmTUI TEA app; never manage terminal I/O here." (elmtui-examples.cursor-inspector:run-cursor-inspector :backend-type backend-type :tmux-mode mode :title "tmux-hover-demo"))
