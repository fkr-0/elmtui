;;; Elmtui FZF-like fuzzy finder (working example).

(uiop:define-package :elmtui.examples.fzf-finder
  (:use :cl :alexandria)
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.app.api #:run-application)
  (:import-from :elmtui.state.api #:make-update-result #:state-ref)
  (:import-from :elmtui.core.event-types #:key-event #:key-event-key #:key-event-char)
  (:export #:run-fzf-finder #:run-fzf-on-stdin #:main))

(in-package :elmtui.examples.fzf-finder)

(defun make-initial-finder-state (items &key (prompt "Find: "))
  `(:items ,items
    :prompt ,prompt
    :input-text ""
    :matches ,items
    :selected-index 0
    :should-quit nil))

(defun fuzzy-score (pattern text)
  (let ((p (string-downcase pattern))
        (txt (string-downcase text)))
    (cond
      ((string= p "") 0.0)
      ((search p txt) 10.0)
      ((every (lambda (c) (find c txt)) p) 1.0)
      (t -1.0))))

(defun calculate-matches (items input-text)
  (if (string= input-text "")
      items
      (loop for item in items
            for score = (fuzzy-score input-text item)
            when (>= score 0)
              collect (cons score item) into scored
            finally (return (mapcar #'cdr (sort scored #'> :key #'car))))))

(defun update-finder-app (message app-state)
  (let* ((items (state-ref app-state :items '()))
         (input (state-ref app-state :input-text ""))
         (matches (state-ref app-state :matches '()))
         (selected (state-ref app-state :selected-index 0)))
    (labels ((set-input (new)
               (let* ((new-matches (calculate-matches items new))
                      (new-selected (if (null new-matches) 0 (min selected (1- (length new-matches))))))
                 (make-update-result :patches (list (list '(:input-text) new)
                                                    (list '(:matches) new-matches)
                                                    (list '(:selected-index) new-selected)))))
             (quit () (make-update-result :patches '(((:should-quit) t)))))
      (cond
        ((typep message 'key-event)
         (let ((key (key-event-key message))
               (ch (key-event-char message)))
           (cond
             ((eq key :escape) (quit))
             ((member key '(:enter :return) :test #'eq)
              (if (null matches)
                  (make-update-result)
                  (make-update-result :patches (list (list '(:selected-item) (nth selected matches))
                                                     (list '(:should-quit) t)))))
             ((member key '(:arrow-up :up) :test #'eq)
              (if (null matches) (make-update-result)
                  (make-update-result :patches (list (list '(:selected-index) (max 0 (1- selected)))))))
             ((member key '(:arrow-down :down) :test #'eq)
              (if (null matches) (make-update-result)
                  (make-update-result :patches (list (list '(:selected-index)
                                                           (min (1- (length matches)) (1+ selected)))))))
             ((member key '(:backspace :delete) :test #'eq)
              (set-input (if (plusp (length input)) (subseq input 0 (1- (length input))) "")))
             ((and ch (graphic-char-p ch))
              (set-input (concatenate 'string input (string ch))))
             (t (make-update-result)))))
        ((and (consp message) (eq (first message) :app-quit-requested)) (quit))
        (t (make-update-result))))))


(defun view-finder-app (app-state)
  (let* ((prompt (state-ref app-state :prompt "Find: "))
         (input (state-ref app-state :input-text ""))
         (matches (state-ref app-state :matches '()))
         (selected (state-ref app-state :selected-index 0)))
    `(:container :id :fzf-root :style (:display :flex :flex-direction :column :width 64)
      :children
      ((:text :id :input :content ,(format nil "~A~A" prompt input))
       (:container :id :matches :style (:display :flex :flex-direction :column)
        :children
        ,(loop for item in matches
               for idx from 0
               collect `(:text :id ,(intern (format nil "MATCH-~D" idx) :keyword)
                         :content ,(format nil "~A ~A" (if (= idx selected) ">" " ") item))))
       (:text :id :help :content "Type to filter | Up/Down | Enter select | q/Esc quit")))))

(progn
  (defparameter *finder-initial-items* '("alpha" "beta" "gamma") "Items used by the next finder run.")
  (defparameter *finder-initial-prompt* "Find: " "Prompt used by the next finder run.")
  (defun %make-initial-finder-state ()
    (make-initial-finder-state *finder-initial-items* :prompt *finder-initial-prompt*)))


(defapplication fzf-finder
  :root-viewport-id :fzf-finder-root
  :initial-state-fn #'%make-initial-finder-state
  :root-component-dsl '(:layout :id :fzf-root)
  :update-fn #'update-finder-app
  :view-fn #'view-finder-app)

(defun show-fzf-finder (items &key (prompt "Find: ") (backend-type :terminal) platform-options argv)
  "Run the finder with caller-provided ITEMS and PROMPT."
  (let ((*finder-initial-items* (copy-list items))
        (*finder-initial-prompt* prompt))
    (run-fzf-finder :platform backend-type :platform-options platform-options :argv argv)))


(defun run-fzf-on-stdin (&key (backend-type :terminal))
  "Read newline-delimited choices from standard input and launch the finder."
  (let ((items (loop for line = (read-line *standard-input* nil nil) while line collect line)))
    (show-fzf-finder items :prompt "filter> " :backend-type backend-type)))


(defun main () (run-fzf-on-stdin))
