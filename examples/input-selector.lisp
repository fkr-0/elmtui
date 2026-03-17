(uiop:define-package :elmtui.examples.input-selector
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info)
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

(defun app-update (message app-state)
  (let ((items (state-ref app-state :items))
        (filtered-items (state-ref app-state :filtered-items))
        (selected-index (state-ref app-state :selected-index))
        (query (state-ref app-state :query)))
    (labels ((ret (&key patch) (make-update-result :patches patch)))
      (cond
        ((and (listp message) (eq (first message) :key-event))
         (let ((key (second message)) (ch (third message)))
           (cond
             ((eql key :arrow-up)
              (ret :patch `(((:selected-index) ,(max 0 (1- selected-index))))))
             ((eql key :arrow-down)
              (ret :patch `(((:selected-index)
                             ,(min (max 0 (1- (length filtered-items))) (1+ selected-index))))))
             ((eql key :return)
              (if (plusp (length filtered-items))
                  (ret :patch `(((:selected-item) ,(nth selected-index filtered-items))
                                ((:should-quit) t)))
                  (ret)))
             ((eql key :escape) (ret :patch '(((:should-quit) t))))
             ((eql key :backspace)
              (let* ((q (if (plusp (length query)) (subseq query 0 (1- (length query))) ""))
                     (fi (filter-items items q)))
                (ret :patch `(((:query) ,q) ((:filtered-items) ,fi)
                              ((:selected-index) ,(min selected-index (max 0 (1- (length fi)))))))))
             ((and ch (graphic-char-p ch))
              (let* ((q (concatenate 'string query (string ch)))
                     (fi (filter-items items q)))
                (ret :patch `(((:query) ,q) ((:filtered-items) ,fi)
                              ((:selected-index) ,(min selected-index (max 0 (1- (length fi)))))))))
             (t (ret)))))
        ((typep message 'elmtui.core.event-types:key-event)
         (let ((key (elmtui.core.event-types:key-event-key message))
               (ch (elmtui.core.event-types:key-event-char message)))
           (cond
             ((eql key :arrow-up)
              (ret :patch `(((:selected-index) ,(max 0 (1- selected-index))))))
             ((eql key :arrow-down)
              (ret :patch `(((:selected-index)
                             ,(min (max 0 (1- (length filtered-items))) (1+ selected-index))))))
             ((eql key :return)
              (if (plusp (length filtered-items))
                  (ret :patch `(((:selected-item) ,(nth selected-index filtered-items))
                                ((:should-quit) t)))
                  (ret)))
             ((eql key :escape) (ret :patch '(((:should-quit) t))))
             ((eql key :backspace)
              (let* ((q (if (plusp (length query)) (subseq query 0 (1- (length query))) ""))
                     (fi (filter-items items q)))
                (ret :patch `(((:query) ,q) ((:filtered-items) ,fi)
                              ((:selected-index) ,(min selected-index (max 0 (1- (length fi)))))))))
             ((and ch (graphic-char-p ch))
              (let* ((q (concatenate 'string query (string ch)))
                     (fi (filter-items items q)))
                (ret :patch `(((:query) ,q) ((:filtered-items) ,fi)
                              ((:selected-index) ,(min selected-index (max 0 (1- (length fi)))))))))
             (t (ret)))))
        (t (ret))))))

(defun input-selector-view (app-state)
  (let* ((filtered-items (state-ref app-state :filtered-items))
         (selected-index (state-ref app-state :selected-index))
         (query (state-ref app-state :query))
         (status (format nil " ~A items | Arrow keys: Navigate | Enter: Select | ESC: Quit"
                         (length filtered-items))))
    `(:container :id :selector-container
      :style (:display :flex :flex-direction :column :width :fill :height :fill)
      :classes ("selector-container")
      :children
      ((:text :id :input-field :classes ("input-field") :content ,(format nil " > ~A" query))
       (:container :id :items :style (:display :flex :flex-direction :column :width :fill :height :fill)
        :children ,(loop for item in filtered-items
                         for idx from 0
                         collect `(:text :id ,(intern (format nil "ITEM-~A" idx) :keyword)
                                   :classes (,(if (= idx selected-index) "selected-item" "item"))
                                   :content ,item)))
       (:text :id :status :classes ("status-bar") :content ,status)))))

(defapplication input-selector-app
  :root-viewport-id :selector-root
  :initial-state-fn #'%initial-state
  :root-component-dsl '(:root-viewport :id :selector-root)
  :update-fn 'app-update
  :view-fn 'input-selector-view)

