;;;===============================================================
;;; File: src/ui/widgets/utils.lisp
;;; Utility functions for widgets
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.utils
  (:use :cl)
  (:export :clamp))
(in-package :elmtui.ui.widgets.utils)

(defun clamp (value min max)
  "Clamps VALUE between MIN and MAX (inclusive)."
  (cond ((< value min) min)
        ((> value max) max)
        (t value)))

;;;===============================================================
;;; Focus Management Utilities
;;;===============================================================

(defun collect-focusable-ids (ui-node)
  "Recursively traverses a UI-NODE tree and collects the :widget-id
   of all nodes that have the property :focusable set to T.
   Returns a list of widget IDs in the order they appear in the tree (depth-first)."
  (when ui-node
    (let ((props (elmtui.view.core:ui-node-props ui-node))
          (children (elmtui.view.core:ui-node-children ui-node))
          (focusable-ids nil))
      ;; Check current node
      (when (getf props :focusable)
        (let ((id (getf props :widget-id)))
          (when id (push id focusable-ids))))
      ;; Recursively check children
      (dolist (child children)
        (setf focusable-ids (append focusable-ids (collect-focusable-ids child))))
      ;; Return collected IDs (reversed because of push)
      (nreverse focusable-ids))))
