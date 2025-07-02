;;; == elmtui/pipeline/main.lisp ==
(in-package #:elmtui.pipeline)

(define-pipeline render-frame
  (elmtui.view.tree-transforms:render-view) ; Stage 1 (wrap later)
  elmtui.view.styled-wrapper:apply-style+contract
  elmtui.view.tree-transforms:resolve-view
  elmtui.view.tree-transforms:layout-view
  elmtui.platform.tree-renderer:render-laid-out-tree-to-virtual-terminal-buffer
  elmtui.platform.backend.terminal.diff-renderer:compute-buffer-diff)
;;; == end/main.lisp ==