(uiop:define-package :elmtui.examples.minimal
  (:use :cl :log4cl)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :elmtui.keys #:key-event)
  (:import-from :elmtui.core.event-types #:key-event-parts)
  (:export #:run-minimal))

(in-package :elmtui.examples.minimal)

(defun minimal-view (model)
  (let ((key (or (getf model :last-key) "-")))
    `(:container
       :id :root
       :style (:display :block :width 20 :height 3
                :padding 1
                :bg-color :black :fg-color :white)
       :children
       ((:text :id :label
          :content ,(format nil "Hello ~A" key))))))

(defun minimal-transition (msg model)
  (multiple-value-bind (key char _mods) (key-event-parts msg)
    (declare (ignore _mods))
    (cond
      ((or key char)
       (let ((ch (or char key)))
         (values (list* :last-key (if (characterp ch) (char-upcase ch) ch)
                        model)
                 nil)))
      (t (values model nil)))))

(defun minimal-init ()
  (values (list :last-key "slurp") nil))

(deftea-app minimal
  :init   #'minimal-init
  :transition #'minimal-transition
  :view   #'minimal-view
  :root-viewport-id :minimal-root
  :anchor :below-cursor
  :height 3)

