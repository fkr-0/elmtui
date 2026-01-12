;;;===============================================================
;;; File: examples/mini-rainbow.lisp
;;;
;;; Description: A minimal example demonstrating a 7x7 rainbow-colored
;;; box that spawns below the cursor.
;;;===============================================================

(uiop:define-package :elmtui.examples.mini-rainbow
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :cl-styles.api #:rgb #:defrule #:defstylesheet #:cls> #:type>)
  (:import-from :elmtui.core.event-types
                #:key-event #:key-event-key #:key-event-char #:key-event-type)
  (:import-from :elmtui.tea-state.api #:make-update-result #:state-ref)
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
(defun app-update (message app-state)
  (labels ((quit-result ()
             (make-update-result :patches '(((:should-quit) t)))))
    (flet ((handle-key (key ch type)
             (log4cl:log-info "mini-rainbow: key event key=~S char=~S type=~S"
                              key ch type)
             (cond
               ((or (member key '(:escape :q :Q))
                    (member ch '(#\q #\Q)))
                (quit-result))
               (t
                (let* ((current (state-ref app-state :orientation :row))
                       (next (if (eq current :row) :column :row)))
                  (make-update-result :patches `(((:orientation) ,next))))))))
      (cond
        ((and (listp message) (eq (first message) :app-quit-requested))
         (quit-result))
        ((and (listp message) (eq (first message) :keyevent))
         (let* ((payload (rest message))
                (key (getf payload :key))
                (char (or (getf payload :char)
                          (let ((event (getf payload :event)))
                            (when (typep event 'key-event)
                              (key-event-char event)))))
                (event (getf payload :event))
                (etype (if (typep event 'key-event)
                         (key-event-type event)
                         :keyevent)))
           (handle-key key char etype)))
        ((typep message 'key-event)
         (handle-key (key-event-key message)
                     (key-event-char message)
                     (key-event-type message)))
        (t
         (make-update-result))))))

(defun view (app-state)
  (labels ((rand-color ()
             (list (random 256) (random 256) (random 256)))
           (cell-id (row col)
             (intern (format nil "CELL-~D-~D" row col) :keyword))
           (cell-node (row col &key (flex-dir :column))
             `(:text
                :id ,(cell-id row col)
                :style (:width 1 :height 1
                         :min-width 1 :min-height 1
                         :display :flex :flex-direction ,flex-dir
                         :fg-color ,(rand-color)
                         :bg-color ,(rand-color))
                :content " "))
           (row-node (row)
             `(:container
                 :id ,(intern (format nil "ROW-~D" row) :keyword)
                 :style (:box :ascii
                          :height 3 :min-height 3
                          :width :fill :min-width 3
                          :border-style :ascii :border-width 1
                          :display :flex :flex-direction :row
                          :bg-color ,(rand-color)
                          :fg-color ,(rand-color))
                 :children ,(loop for col from 0 below 7
                                  collect (cell-node row col :flex-dir :column))))
           (column-node (col)
             `(:container
                 :id ,(intern (format nil "COL-~D" col) :keyword)
                 :style (:box :ascii
                          :width 3 :min-width 3
                          :height :fill :min-height 3
                          :border-style :ascii :border-width 1
                          :display :flex :flex-direction :column
                          :bg-color ,(rand-color)
                          :fg-color ,(rand-color))
                 :children ,(loop for row from 0 below 7
                                  collect (cell-node row col :flex-dir :row)))))
    (let* ((orientation (state-ref app-state :orientation :row))
           (row-major (eq orientation :row))
           (rows (loop for i from 0 below 7 collect (row-node i)))
           (columns (loop for j from 0 below 7 collect (column-node j))))
      `(:container
          :id :main
          :style (:box :ascii
                   :width :auto
                   :height 34
                   :display :flex
                   :flex-direction ,(if row-major :column :row)
                   :padding 0 :margin 0 :spacing 0 :gap 0
                   :border-style :double :border-width 1
                   :fg-color ,(rand-color))
          :children ,(if row-major rows columns)))))

(defapplication mini-rainbow
  :root-component-dsl
  `(:root-viewport
     :id :root)
  :update-fn 'app-update
  ;; :stylesheet rainbow-stylesheet
  :view-fn #'view
  :root-viewport-id :root
  :initial-state-plist (list :current-stylesheet rainbow-stylesheet
                         :should-quit nil
                         :orientation :row
                         :switch-count 0))

;; (defun run-mini-rainbow ()
;;   "Run the mini-rainbow example."
;;   (elmtui.app.api:run-application (make-instance 'mini-rainbow)))
