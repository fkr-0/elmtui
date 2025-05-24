(uiop:define-package :elmtui.examples.input-selector
  (:use :cl :alexandria :log4cl)
  (:import-from :log4cl #:log-info #:log-debug)
  (:import-from :elmtui.ui.widgets.utils
                #:widget-focused-p #:defwidget-view)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.runtime #:def-elm-app #:run-app)
  (:import-from :elmtui.style-lib.rule #:defrule)
  (:import-from :elmtui.style-lib.sheet #:defstylesheet)
  (:import-from :elmtui.state.update #:defupdate)
  (:export
   :main
   :run-input-selector-app))

(in-package :elmtui.examples.input-selector)

;;;--------------------------------------------------------------
;;; Stylesheet Definition
;;;--------------------------------------------------------------
(defstylesheet input-selector-stylesheet
  (defrule ".selector-container"
    :background-color (elmtui.style-lib.styles:rgb '(25 25 25))
    :color (elmtui.style-lib.styles:rgb '(200 200 200)))
  
  (defrule ".input-field"
    :background-color (elmtui.style-lib.styles:rgb '(50 50 50))
    :color (elmtui.style-lib.styles:rgb '(255 255 255))
    :padding 1
    :height 1)
  
  (defrule ".item"
    :padding-left 1
    :padding-right 1
    :height 1)
  
  (defrule ".selected-item"
    :background-color (elmtui.style-lib.styles:rgb '(50 100 150))
    :color (elmtui.style-lib.styles:rgb '(255 255 255))
    :padding-left 1
    :padding-right 1
    :height 1)
  
  (defrule ".status-bar"
    :background-color (elmtui.style-lib.styles:rgb '(50 50 50))
    :color (elmtui.style-lib.styles:rgb '(255 255 255))
    :padding 1
    :height 1))

;;;--------------------------------------------------------------
;;; Sample Data
;;;--------------------------------------------------------------

(defun generate-sample-items ()
  "Generate a list of sample items. In a real application, this might read from stdin."
  (append
   (loop for i from 1 to 20
         collect (format nil "Option ~A" i))
   (list "Apple" "Banana" "Cherry" "Date" "Elderberry" "Fig" "Grape" "Honeydew")
   (list "Red" "Green" "Blue" "Yellow" "Purple" "Orange" "Pink" "Brown" "Black" "White")
   (list "One" "Two" "Three" "Four" "Five" "Six" "Seven" "Eight" "Nine" "Ten")))

;;;--------------------------------------------------------------
;;; Application Definition
;;;--------------------------------------------------------------

(defun app-init ()
  "Initializes the application model."
  (let ((items (generate-sample-items)))
    (values
     ;; Initial application state
     (list :current-stylesheet input-selector-stylesheet
           :items items
           :filtered-items items
           :selected-index 0
           :query ""
           :should-quit nil
           :selected-item nil)
     ;; No initial commands
     nil)))

(defun filter-items (items query)
  "Filter items based on the query string."
  (if (string= query "")
      items
      (remove-if-not
       (lambda (item)
         (search (string-downcase query) (string-downcase item)))
       items)))

(defupdate app-update (app-state message)
  "Handles updates to the application state based on messages."
  (let ((items (getf app-state :items))
        (filtered-items (getf app-state :filtered-items))
        (selected-index (getf app-state :selected-index))
        (query (getf app-state :query)))
    
    (cond
      ;; Handle key events for navigation and interaction
      ((and (listp message) (eq (first message) :key-event))
       (let ((key-code (second message))
             (char (third message))
             (modifiers (fourth message)))
         (cond
           ;; Move selection up
           ((eql key-code :arrow-up)
            (values (list :selected-index (max 0 (1- selected-index))) nil))
           
           ;; Move selection down
           ((eql key-code :arrow-down)
            (values (list :selected-index (min (1- (length filtered-items))
                                               (1+ selected-index)))
                    nil))
           
           ;; Enter selects the current item
           ((eql key-code :return)
            (if (plusp (length filtered-items))
                (values (list :selected-item (nth selected-index filtered-items)
                              :should-quit t)
                        nil)
                (values nil nil)))
           
           ;; Escape quits without selecting
           ((eql key-code :escape)
            (values (list :should-quit t) nil))
           
           ;; Backspace removes the last character from the query
           ((eql key-code :backspace)
            (let ((new-query (if (plusp (length query))
                                 (subseq query 0 (1- (length query)))
                                 "")))
              (let ((new-filtered-items (filter-items items new-query)))
                (values (list :query new-query
                              :filtered-items new-filtered-items
                              :selected-index (min selected-index
                                                   (max 0 (1- (length new-filtered-items)))))
                        nil))))
           
           ;; Regular characters update the query
           ((and char (graphic-char-p char))
            (let* ((new-query (concatenate 'string query (string char)))
                   (new-filtered-items (filter-items items new-query)))
              (values (list :query new-query
                            :filtered-items new-filtered-items
                            :selected-index (min selected-index
                                                 (max 0 (1- (length new-filtered-items)))))
                      nil)))
           
           ;; Default: no state change
           (t (values nil nil)))))
      
      ;; Handle struct-based key events
      ((typep message 'elmtui.core.event-types:key-event)
       (let ((key (elmtui.core.event-types:key-event-key message))
             (char (elmtui.core.event-types:key-event-char message)))
         (cond
           ;; Move selection up
           ((eql key :arrow-up)
            (values (list :selected-index (max 0 (1- selected-index))) nil))
           
           ;; Move selection down
           ((eql key :arrow-down)
            (values (list :selected-index (min (1- (length filtered-items))
                                               (1+ selected-index)))
                    nil))
           
           ;; Enter selects the current item
           ((eql key :return)
            (if (plusp (length filtered-items))
                (values (list :selected-item (nth selected-index filtered-items)
                              :should-quit t)
                        nil)
                (values nil nil)))
           
           ;; Escape quits without selecting
           ((eql key :escape)
            (values (list :should-quit t) nil))
           
           ;; Backspace removes the last character from the query
           ((eql key :backspace)
            (let ((new-query (if (plusp (length query))
                                 (subseq query 0 (1- (length query)))
                                 "")))
              (let ((new-filtered-items (filter-items items new-query)))
                (values (list :query new-query
                              :filtered-items new-filtered-items
                              :selected-index (min selected-index
                                                   (max 0 (1- (length new-filtered-items)))))
                        nil))))
           
           ;; Regular characters update the query
           ((and char (graphic-char-p char))
            (let* ((new-query (concatenate 'string query (string char)))
                   (new-filtered-items (filter-items items new-query)))
              (values (list :query new-query
                            :filtered-items new-filtered-items
                            :selected-index (min selected-index
                                                 (max 0 (1- (length new-filtered-items)))))
                      nil)))
           
           ;; Default: no state change
           (t (values nil nil)))))
      
      ;; Default: no state change
      (t (values nil nil)))))

(defun input-selector-view (app-state dispatch-fn)
  "Renders the input selector UI."
  (let ((filtered-items (getf app-state :filtered-items))
        (selected-index (getf app-state :selected-index))
        (query (getf app-state :query)))
    
    (multiple-value-bind (term-width term-height)
        (elmtui.platform.api:get-terminal-dimensions)
      
      (let* ((visible-items-count (- term-height 3)) ; Input field + status bar + margin
             (start-index (max 0 (- selected-index (floor visible-items-count 2))))
             (end-index (min (length filtered-items) (+ start-index visible-items-count)))
             (visible-items (subseq filtered-items start-index end-index))
             (status-text (format nil " ~A items | Arrow keys: Navigate | Enter: Select | ESC: Quit" 
                                  (length filtered-items))))
        
        ;; Main container
        (make-styled-node
         :type :container
         :props (list :id :selector-container
                      :classes "selector-container"
                      :direction :vertical
                      :height :fill
                      :width :fill)
         :children 
         (list
          ;; Input field
          (make-styled-node
           :type :text
           :props (list :id :input-field
                        :classes "input-field"
                        :text (format nil " > ~A" query)))
          
          ;; Items list
          (make-styled-node
           :type :container
           :props (list :id :items-container
                        :direction :vertical
                        :height (- term-height 2)  ; Leave space for input and status
                        :width term-width)
           :children
           (loop for item in visible-items
                 for idx from start-index
                 collect (make-styled-node
                          :type :text
                          :props (list :id (intern (format nil "ITEM-~A" idx) :keyword)
                                       :classes (if (= idx selected-index)
                                                    "selected-item"
                                                    "item")
                                       :text item))))
          
          ;; Status bar
          (make-styled-node
           :type :text
           :props (list :id :status-bar
                        :classes "status-bar"
                        :text status-text))))))))

(def-elm-app input-selector-app
  :init #'app-init
  :update #'app-update
  :view #'input-selector-view)

(defun main ()
  "Run the input selector application."
  (let* ((result (elmtui.runtime:run-app :app-name 'input-selector-app))
         (selected-item (getf result :selected-item)))
    (when selected-item
      (format t "~&Selected: ~A~%" selected-item))
    selected-item))

(defun run-input-selector-app ()
  "Run the input selector application."
  (main))
