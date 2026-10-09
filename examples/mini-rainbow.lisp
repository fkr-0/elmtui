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
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
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

(defun view (state)
  "Small deterministic rainbow with individually colored visible text runs."
  (let ((orientation (state-ref state :orientation :row))
        (palette '((:rgb 255 75 94) (:rgb 255 160 79) (:rgb 255 225 99)
                   (:rgb 88 220 150) (:rgb 65 175 255) (:rgb 135 118 255)
                   (:rgb 221 111 232))))
    `(:container :id :mini-rainbow-content
       :style (:display :flex :flex-direction :column :width 54 :height 12)
       :children
       ((:text :id :mini-rainbow-title
               :content "RAINBOW / mini   Space: rotate  |  q: quit"
               :style (:fg-color :cyan :bold t))
        (:text :id :mini-rainbow-direction
               :content ,(format nil "Direction: ~A" orientation))
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
                             :style (:fg-color ,color
                                     :height 1
                                     :width ,(if (eq orientation :row) 7 48)))))))))

(defun %mini-rainbow-initial-state ()
  (list :current-stylesheet nil
        :should-quit nil
        :orientation :row
        :switch-count 0))

(defapplication mini-rainbow
  :root-component-dsl
  '(:root-viewport :id :root :anchor :below-cursor :width 54 :height 12 :blank-on-exit t :child-dsl-spec (:view nil))
  :update-fn 'app-update
  ;; :stylesheet rainbow-stylesheet
  :view-fn #'view
  :root-viewport-id :root
  :initial-state-fn #'%mini-rainbow-initial-state)

;; (defun run-mini-rainbow ()
;;   "Run the mini-rainbow example."
;;   (elmtui.app.api:run-application (make-instance 'mini-rainbow)))
