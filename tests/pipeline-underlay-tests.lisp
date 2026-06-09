(uiop:define-package :elmtui.tests.pipeline-underlay
  (:use :cl :fiveam)
  (:import-from :elmtui.platform.tree-renderer
    #:render-laid-out-tree-to-buffer)
  (:import-from :elmtui.platform.backend.common.virtual-buffer
    #:make-virtual-buffer
    #:set-buffer-cell-at
    #:buffer-cell-at
    #:buffer-cell-char)
  (:export #:pipeline-underlay-tests))

(in-package :elmtui.tests.pipeline-underlay)

(def-suite pipeline-underlay-tests
  :in elmtui.tests:elmtui-test
  :description "Regression tests for underlay-preserving rendering")

(in-suite pipeline-underlay-tests)

(test render-to-buffer-can-preserve-existing-cells
  (let ((buffer (make-virtual-buffer 4 1)))
    (set-buffer-cell-at buffer 0 0 #\X nil)
    (render-laid-out-tree-to-buffer nil :buffer buffer :clear-buffer-p nil)
    (is (char= #\X (buffer-cell-char (buffer-cell-at buffer 0 0))))))

(test render-to-buffer-default-clears-existing-cells
  (let ((buffer (make-virtual-buffer 4 1)))
    (set-buffer-cell-at buffer 0 0 #\X nil)
    (render-laid-out-tree-to-buffer nil :buffer buffer)
    (is (not (char= #\X (buffer-cell-char (buffer-cell-at buffer 0 0)))))))

