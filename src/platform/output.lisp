;;;===============================================================
;;; File: src/platform/output.lisp
;;; Platform Output Adapter
(uiop:define-package :elmtui.platform.output
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.core #:ui-node #:ui-node-p #:ui-node-type #:ui-node-props #:ui-node-children)
  (:import-from :elmtui.view.geo #:rectangle #:pos #:size #:x #:y #:w #:h)
  (:import-from :elmtui.view.styled #:styled-ui-node #:style-value)
  (:import-from :elmtui.platform.api #:clear-screen #:flush-output #:draw-text-at) ; Import backend API
  (:export :render-frame)) ; Removed clear-screen export, it's part of render-frame now
(in-package :elmtui.platform.output)

(defun translate-styles-for-backend (node)
  "Extracts relevant style properties and translates them into a plist
   suitable for the backend's draw-text-at function."
  ;; TODO: Implement proper color parsing (e.g., hex to terminal codes)
  ;; For now, pass colors as strings and assume backend handles them.
  (let ((fg (style-value node :foreground-color nil))
        (bg (style-value node :background-color nil))
        (attrs (style-value node :attributes nil)))
    (append (when fg `(:fg ,fg))
            (when bg `(:bg ,bg))
            (when attrs `(:attributes ,attrs)))))

(defun render-node (node backend-instance)
  "Recursively renders a single laid-out UI node and its children."
  (when (and node (typep node 'ui-node)) ; Basic check
    (let ((layout-rect (getf (ui-node-props node) :layout-rect)))
      (when (and layout-rect (typep layout-rect 'rectangle))
        ;; 1. Render the node itself (if it has direct content like text)
        (let* ((node-type (ui-node-type node))
               (props (ui-node-props node))
               (text (getf props :value "")) ; Get text value, default to empty
               (style-plist (translate-styles-for-backend node))
               (pos-x (x layout-rect))
               (pos-y (y layout-rect))
               (width (w layout-rect))
               (height (h layout-rect)))

          ;; Only draw if node type is text-like and has dimensions
          (when (and (member node-type '(:text :text-input :list-item)) ; Add other text-displaying types
                     (> width 0) (> height 0))
            ;; TODO: Handle text wrapping/clipping within the layout-rect
            (let ((clipped-text (if (> (length text) width)
                                    (subseq text 0 width)
                                    text)))
              (draw-text-at backend-instance pos-y pos-x clipped-text :style style-plist))))

        ;; 2. Render children recursively
        (dolist (child (ui-node-children node))
          (render-node child backend-instance))))))

(defun render-frame (laid-out-root-node backend-instance)
  "Renders the complete, laid-out UI tree to the terminal using the backend.
   LAID-OUT-ROOT-NODE: The root node returned by layout-tree.
   BACKEND-INSTANCE: The initialized platform backend."
  (when backend-instance
    (handler-case
        (progn
          (clear-screen backend-instance)
          (render-node laid-out-root-node backend-instance)
          (flush-output backend-instance))
      (error (e)
        ;; Log the error but try not to crash the main loop
        (log:error "Error during render-frame: ~A" e)
        ;; Optionally try to render an error message to the screen
        (ignore-errors
         (clear-screen backend-instance)
         (draw-text-at backend-instance 0 0 (format nil "Render Error: ~A" e) :style '(:fg "red"))
         (flush-output backend-instance))))))
