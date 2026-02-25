(in-package :cl-styles.adapters)

(defun normalize-tui-style-plist (plist)
  "Normalize a TUI-oriented style plist into canonical keys used by renderers.
The return value is a plist with normalized keys and aliases collapsed:
  :fg-color, :bg-color, :attrs."
  (let* ((normalized (normalize-declarations plist))
         (fg (or (getf normalized :fg-color)
                 (getf normalized :fg)
                 (getf normalized :color)))
         (bg (or (getf normalized :bg-color)
                 (getf normalized :bg)
                 (getf normalized :background-color)
                 (getf normalized :background)))
         (attrs (or (getf normalized :attrs)
                    (getf normalized :attributes))))
    (list :fg-color fg
          :bg-color bg
          :attrs attrs)))
