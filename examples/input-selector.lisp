(uiop:define-package :elmtui.examples.input-selector
  (:use :cl :alexandria :log4cl)
  (:import-from :cl-styles.api #:defrule #:defstylesheet #:cls> #:rgb)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:export #:run-input-selector-app))

(in-package :elmtui.examples.input-selector)

;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
(defparameter input-selector-stylesheet
  (defstylesheet
    (defrule (cls> "selector-container")
      :background-color (rgb 25 25 25)
      :color (rgb 200 200 200))
    (defrule (cls> "input-field")
      :background-color (rgb 50 50 50)
      :color (rgb 255 255 255)
      :padding 1
      :height 1)
    (defrule (cls> "item")
      :padding-left 1
      :padding-right 1
      :height 1)
    (defrule (cls> "selected-item")
      :background-color (rgb 50 100 150)
      :color (rgb 255 255 255)
      :padding-left 1
      :padding-right 1
      :height 1)
    (defrule (cls> "status-bar")
      :background-color (rgb 50 50 50)
      :color (rgb 255 255 255)
      :padding 1
      :height 1)))

(defun generate-sample-items ()
  "Generate a list of sample items."
  (append
   (loop for i from 1 to 20 collect (format nil "Option ~A" i))
   (list "Apple" "Banana" "Cherry" "Date" "Elderberry" "Fig" "Grape" "Honeydew")
   (list "Red" "Green" "Blue" "Yellow" "Purple" "Orange" "Pink" "Brown" "Black" "White")
   (list "One" "Two" "Three" "Four" "Five" "Six" "Seven" "Eight" "Nine" "Ten")))

(defun %initial-state ()
  (let ((items (generate-sample-items)))
    (list :current-stylesheet input-selector-stylesheet
          :items items
          :filtered-items items
          :selected-index 0
          :query ""
          :should-quit nil
          :selected-item nil)))

(defun filter-items (items query)
  (if (string= query "")
      items
      (remove-if-not
       (lambda (item)
         (search (string-downcase query) (string-downcase item)))
       items)))

(defun %key-event-parts (message) "Return KEY and CHAR for struct, canonical keyevent, or legacy list shapes." (cond ((typep message 'elmtui.core.event-types:key-event) (values (elmtui.core.event-types:key-event-key message) (elmtui.core.event-types:key-event-char message))) ((and (consp message) (member (first message) ' (:keyevent :key-event) :test #'eq)) (let ((tail (rest message))) (if (and tail (member (first tail) ' (:key :char :event :modifiers) :test #'eq)) (values (getf tail :key) (getf tail :char)) (values (second message) (third message))))) (t (values nil nil))))


(defun app-update (message app-state)
  (let ((items (state-ref app-state :items))
        (filtered-items (state-ref app-state :filtered-items))
        (selected-index (state-ref app-state :selected-index))
        (query (state-ref app-state :query)))
    (labels ((ret (&key patches) (make-update-result :patches patches)))
      (multiple-value-bind (key ch) (%key-event-parts message)
        (cond
          ((member key '(:arrow-up :up) :test #'eq)
           (ret :patches (list (list '(:selected-index) (max 0 (1- selected-index))))))
          ((member key '(:arrow-down :down) :test #'eq)
           (ret :patches (list (list '(:selected-index)
                                     (min (max 0 (1- (length filtered-items))) (1+ selected-index))))))
          ((member key '(:enter :return) :test #'eq)
           (if (plusp (length filtered-items))
               (ret :patches (list (list '(:selected-item) (nth selected-index filtered-items))
                                   (list '(:should-quit) t)))
               (ret)))
          ((eq key :escape) (ret :patches '(((:should-quit) t))))
          ((eq key :backspace)
           (let* ((new-query (if (plusp (length query)) (subseq query 0 (1- (length query))) ""))
                  (new-items (filter-items items new-query)))
             (ret :patches (list (list '(:query) new-query)
                                 (list '(:filtered-items) new-items)
                                 (list '(:selected-index)
                                       (min selected-index (max 0 (1- (length new-items)))))))))
          ((and ch (graphic-char-p ch))
           (let* ((new-query (concatenate 'string query (string ch)))
                  (new-items (filter-items items new-query)))
             (ret :patches (list (list '(:query) new-query)
                                 (list '(:filtered-items) new-items)
                                 (list '(:selected-index)
                                       (min selected-index (max 0 (1- (length new-items)))))))))
          (t (ret)))))))


(defun input-selector-view (app-state)
  (let* ((filtered-items (state-ref app-state :filtered-items))
         (selected-index (state-ref app-state :selected-index))
         (query (state-ref app-state :query))
         (status (format nil " ~A items | Arrow keys: Navigate | Enter: Select | ESC: Quit"
                         (length filtered-items))))
    `(:container :id :selector-container
      :style (:display :flex :flex-direction :column :width 80 :height 30)
      :classes ("selector-container")
      :children
      ((:text :id :input-field :classes ("input-field") :content ,(format nil " > ~A" query))
       (:container :id :items :style (:display :flex :flex-direction :column :width 80 :height 26)
        :children ,(loop for item in filtered-items
                         for idx from 0
                         collect `(:text :id ,(intern (format nil "ITEM-~A" idx) :keyword)
                                   :classes (,(if (= idx selected-index) "selected-item" "item"))
                                   :content ,item)))
       (:text :id :status :classes ("status-bar") :content ,status)))))

(defapplication input-selector-app
  :root-viewport-id :selector-root
  :initial-state-fn #'%initial-state
  :root-component-dsl '(:root-viewport :id :selector-root
                        :anchor :below-cursor
                        :width 80 :height 30
                        :child-dsl-spec (:view nil))
  :update-fn 'app-update
  :view-fn 'input-selector-view)
