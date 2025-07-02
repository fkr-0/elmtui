;;; == elmtui/view/styled-wrapper.lisp ==
(in-package #:elmtui.view.styled)

(define-stage apply-style+contract
    (elmtui.contracts::ui-node elmtui.contracts::styled-ui-node)
    (node stylesheet)
  ;; delegate to the original impl
  (apply-stylesheet-to-tree node stylesheet))
;;; == end/styled-wrapper.lisp ==