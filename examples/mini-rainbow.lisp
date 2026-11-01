;;;===============================================================
;;; File: examples/mini-rainbow.lisp
;;;
;;; Description: A minimal example demonstrating a 7x7 rainbow-colored
;;; box that spawns below the cursor.
;;;===============================================================

(uiop:define-package :elmtui.examples.mini-rainbow
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app.tea-core #:deftea-app)
  (:import-from :cl-styles.api #:rgb #:defrule #:defstylesheet #:cls> #:type>)
  (:import-from :elmtui.keys #:key-event)
  (:import-from :elmtui.core.event-types #:key-event-parts)
  (:export #:run-mini-rainbow))

(in-package :elmtui.examples.mini-rainbow)
(defparameter rainbow-stylesheet
  (defstylesheet
    ;; Container base style
    (defrule (type> :container)
      :display :block
      :box :single
      :gap 0
      :width 1
      :height 1)
    (DEFRULE (CLS> "red-stripe")
      :BG-COLOR
      (list 255 0 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "pink-stripe")
      :BG-COLOR
      (list 255 192 203)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "orange-stripe")
      :BG-COLOR
      (list 255 165 0)
      :WIDTH
      2
      :HEIGHT
      1)
    (DEFRULE (CLS> "yellow-stripe")
      :BG-COLOR
      (list 255 255 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "green-stripe")
      :BG-COLOR
      (list 0 255 0)
      :WIDTH
      1
      :HEIGHT
      1)
    (DEFRULE (CLS> "blue-stripe")
      :BG-COLOR
      (list 0 0 255)
      :WIDTH
      3
      :HEIGHT
      1)
    (DEFRULE (CLS> "indigo-stripe")
      :BG-COLOR
      (list 75 0 130)
      :WIDTH
      3
      :HEIGHT
      1)
    (DEFRULE (CLS> "violet-stripe")
      :BG-COLOR
      (list 238 130 238)
      :WIDTH
      1
      :HEIGHT
      1)
    ;; Generate individual stripe rules
    ;; (generate-stripe-rules-forms)
    )

  "Stylesheet for the rainbow application.")
(defun app-transition (message model)
  "Direct model-replacement transition for mini-rainbow."
  (multiple-value-bind (key char _mods) (key-event-parts message)
    (declare (ignore _mods))
    (cond
      ((or (member key '(:escape :q :Q))
           (member char '(#\q #\Q)))
       (values (list* :should-quit t model) nil))
      ((or (eq key :space) (eql char #\Space))
       (let* ((current (getf model :orientation :row))
              (next (if (eq current :row) :column :row)))
         (values (list* :orientation next model) nil)))
      (t (values model nil)))))

(defun rainbow-terminal-depth ()
  "Use RGB only when advertised; otherwise use 256 or basic terminal colors."
  (let ((term (string-downcase (or (uiop:getenv "TERM") "")))
        (ct (string-downcase (or (uiop:getenv "COLORTERM") ""))))
    (cond ((or (search "truecolor" ct) (search "24bit" ct)) :truecolor)
          ((search "256color" term) :indexed)
          (t :basic))))

(defun rainbow-select-color (value index)
  "Convert a rainbow color to the supported native DSL token."
  (ecase (rainbow-terminal-depth)
    (:truecolor (if (and (consp value) (eq (first value) :rgb))
                    value (cons :rgb value)))
    (:indexed (list :256 (nth index '(196 208 226 46 27 54 201))))
    (:basic (nth index '(:red :yellow :white :green :blue :cyan :magenta)))))

(defun view (model)
  "Small deterministic rainbow with individually colored visible text runs."
  (let ((orientation (getf model :orientation :row))
        (palette '((:rgb 255 75 94) (:rgb 255 160 79) (:rgb 255 225 99)
                   (:rgb 88 220 150) (:rgb 65 175 255) (:rgb 135 118 255)
                   (:rgb 221 111 232))))
    `(:container :id :mini-rainbow-content
       :style (:display :flex :flex-direction :column :box :single :width 54 :height 12)
       :children
       ((:text :id :mini-rainbow-title
               :content "RAINBOW / mini   Space: rotate  |  q: quit"
               :style (:fg-color :cyan :bold t))
        (:text :id :mini-rainbow-direction
               :content ,(format nil "Direction: ~A | Color mode: ~A" orientation (rainbow-terminal-depth)))
        (:container :id :mini-rainbow-palette
           :style (:display :flex
                   :flex-direction ,(if (eq orientation :row) :row :column)
                   :width 49 :height 8)
           :children
           ,(loop for color in palette for index from 0
                  collect `(:text
                             :id ,(intern (format nil "MINI-STRIPE-~D" index) :keyword)
                             :content ,(if (eq orientation :row) "#######"
                                           (make-string 48 :initial-element #\#))
                             :style (:fg-color ,(rainbow-select-color color index)
                                     :bg-color :black
                                     :height 1
                                     :width ,(if (eq orientation :row) 7 48)))))))))

(defun mini-rainbow-init ()
  (values (list :current-stylesheet nil
                :orientation :row
                :switch-count 0)
          nil))

(deftea-app mini-rainbow
  :init       #'mini-rainbow-init
  :transition #'app-transition
  :view       #'view
  :root-viewport-id :root
  :anchor     :below-cursor
  :height     12)
