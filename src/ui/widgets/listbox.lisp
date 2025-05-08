;;;===============================================================
;;; File: src/ui/widgets/listbox.lisp
;;; Elm-style ListBox Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.listbox
  (:use :cl :alexandria)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:import-from :elmtui.core.events #:cmd)
  ;; TODO: Import specific key symbols if needed
  (:export #:listbox-model #:make-listbox-model ; Struct and constructor
           ;; Accessors
           #:listbox-model-id
           #:listbox-model-items
           #:listbox-model-selected-index
           #:listbox-model-scroll-offset
           #:listbox-model-is-focused
           #:listbox-model-on-select
           ;; Core TEA functions
           #:init-listbox #:update-listbox #:view-listbox
           ;; Message types
           #:msg-listbox-key-press
           #:msg-listbox-select-index
           #:msg-listbox-set-items
           #:msg-listbox-scroll-up
           #:msg-listbox-scroll-down
           #:msg-listbox-focus
           #:msg-listbox-blur))
(in-package :elmtui.ui.widgets.listbox)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (listbox-model (:constructor %make-listbox-model))
  "Model for a listbox widget."
  (id (error "ID must be provided.") :type T :read-only t)
  (items nil :type list) ; List of items (e.g., strings, plists)
  (selected-index nil :type (or null unsigned-byte)) ; Index of the selected item
  (scroll-offset 0 :type unsigned-byte) ; Index of the first visible item
  (is-focused nil :type boolean)
  (on-select nil :type T)) ; Message to dispatch when an item is selected

;;;---------------------------------------------------------------
;;; Messages (Keywords)
;;;---------------------------------------------------------------
;; (:listbox-key-press :key <key-event-data>) - For up/down/page navigation, enter
;; (:listbox-select-index :index <index>) - Direct selection
;; (:listbox-set-items :items <new-item-list>) - Replace items
;; (:listbox-scroll-up :amount <n>)
;; (:listbox-scroll-down :amount <n>)
;; (:listbox-focus)
;; (:listbox-blur)

(defparameter msg-listbox-key-press :listbox-key-press)
(defparameter msg-listbox-select-index :listbox-select-index)
(defparameter msg-listbox-set-items :listbox-set-items)
(defparameter msg-listbox-scroll-up :listbox-scroll-up)
(defparameter msg-listbox-scroll-down :listbox-scroll-down)
(defparameter msg-listbox-focus :listbox-focus)
(defparameter msg-listbox-blur :listbox-blur)

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-listbox (id &key (items nil) (selected-index nil) (on-select nil))
  "Initializes a new listbox model.
   Returns (values listbox-model initial-command)."
  (values (%make-listbox-model :id id
                               :items items
                               :selected-index selected-index
                               :scroll-offset 0
                               :is-focused nil
                               :on-select on-select)
          nil))

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-listbox (msg model)
  "Updates the listbox model based on a message.
   Returns (values new-listbox-model command-list)."
  (check-type model listbox-model)
  (let ((new-model (copy-structure model))
        (commands nil)
        (selection-changed nil)
        (item-count (length (listbox-model-items model))))

    (flet ((clamp-index (idx)
             (when idx (alexandria:clamp idx 0 (max 0 (1- item-count)))))
           (clamp-scroll (offset height) ; Height is needed for page up/down, assume 10 for now
             (alexandria:clamp offset 0 (max 0 (- item-count height)))))

      (etypecase msg
        ;; --- Keyboard Navigation (when focused) ---
        ((cons (eql msg-listbox-key-press))
         (when (listbox-model-is-focused new-model)
           (let* ((key-data (getf (rest msg) :key))
                  (key-sym (getf key-data :key-sym))
                  (current-index (listbox-model-selected-index new-model)))
             (case key-sym
               (:up
                (when (> item-count 0)
                  (let ((new-idx (if current-index (max 0 (1- current-index)) (1- item-count))))
                    (setf (listbox-model-selected-index new-model) new-idx)
                    (setf selection-changed t)
                    ;; TODO: Adjust scroll-offset if selection goes out of view
                    )))
               (:down
                (when (> item-count 0)
                  (let ((new-idx (if current-index (min (1- item-count) (1+ current-index)) 0)))
                    (setf (listbox-model-selected-index new-model) new-idx)
                    (setf selection-changed t)
                    ;; TODO: Adjust scroll-offset if selection goes out of view
                    )))
               ;; TODO: Add PageUp, PageDown, Home, End handling (requires knowing view height)
               (:enter
                (when (and current-index (listbox-model-on-select new-model))
                  (setf selection-changed t)))) ; Trigger on-select command below
               ))))

        ;; --- Direct Manipulation ---
        ((cons (eql msg-listbox-select-index))
         (let ((new-idx (clamp-index (getf (rest msg) :index))))
           (unless (equal new-idx (listbox-model-selected-index new-model))
             (setf (listbox-model-selected-index new-model) new-idx)
             (setf selection-changed t))))

        ((cons (eql msg-listbox-set-items))
         (let ((new-items (getf (rest msg) :items)))
           (setf (listbox-model-items new-model) new-items)
           ;; Reset selection and scroll on item change? Or try to preserve? Resetting is simpler.
           (setf (listbox-model-selected-index new-model) (clamp-index (listbox-model-selected-index new-model)))
           (setf (listbox-model-scroll-offset new-model) (clamp-scroll (listbox-model-scroll-offset new-model) 10)) ; Assume height 10
           ))

        ;; --- Scrolling ---
        ((cons (eql msg-listbox-scroll-up))
         (let ((amount (or (getf (rest msg) :amount) 1)))
           (setf (listbox-model-scroll-offset new-model)
                 (clamp-scroll (max 0 (- (listbox-model-scroll-offset new-model) amount)) 10)))) ; Assume height 10

        ((cons (eql msg-listbox-scroll-down))
         (let ((amount (or (getf (rest msg) :amount) 1)))
           (setf (listbox-model-scroll-offset new-model)
                 (clamp-scroll (+ (listbox-model-scroll-offset new-model) amount) 10)))) ; Assume height 10

        ;; --- Focus ---
        ((eql msg msg-listbox-focus)
         (setf (listbox-model-is-focused new-model) t))

        ((eql msg msg-listbox-blur)
         (setf (listbox-model-is-focused new-model) nil))
        ))

    ;; --- Post-update Actions ---
    (when (and selection-changed (listbox-model-on-select new-model))
      (let* ((selected-idx (listbox-model-selected-index new-model))
             (selected-item (when selected-idx (nth selected-idx (listbox-model-items new-model))))
             (on-select-msg (listbox-model-on-select new-model)))
        ;; Assume on-select message might need index and/or item
        (if (listp on-select-msg)
            (push (append on-select-msg (list :index selected-idx :item selected-item)) commands)
            (push on-select-msg commands)))) ; Simple signal

    (values new-model (nreverse commands))))


;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-listbox (model dispatch-fn) ; Removed is-focused arg, using model's slot directly
  "Creates a UI-NODE representation of the listbox.
   MODEL: The current listbox-model instance.
   DISPATCH-FN: A function to call to dispatch messages.
   Returns a UI-NODE."
  (check-type model listbox-model)
  (let* ((items (listbox-model-items model))
         (selected-idx (listbox-model-selected-index model))
         (scroll-offset (listbox-model-scroll-offset model))
         (is-focused (listbox-model-is-focused model)) ; Get focus state from model
         ;; TODO: Determine visible height from layout properties passed down or context. Assume 10 for now.
         (visible-height 10)
         (visible-items (subseq items scroll-offset (min (length items) (+ scroll-offset visible-height)))))

    (make-ui-node
     :type :list-box ; Specific type for renderer
     :props (list :widget-id (listbox-model-id model)
                  :class (if is-focused "listbox listbox-focused" "listbox") ; Use is-focused here
                  :scroll-offset scroll-offset
                  :item-count (length items)
                  :focusable t
                  ;; Click on item to select
                  :events (list (list :click ; Platform needs to provide item index on click
                                      (lambda (&key item-index)
                                        (when item-index
                                          (funcall dispatch-fn (list msg-listbox-select-index :index item-index)))))))
     :children (loop for item in visible-items
                     for item-index from scroll-offset
                     collect (make-ui-node
                              :type :list-item ; Specific type for list items
                              :props (list :widget-id (list (listbox-model-id model) item-index) ; Compound ID
                                           :value item ; Assuming item is string or has label
                                           :class (if (equal item-index selected-idx)
                                                      "list-item list-item-selected"
                                                      "list-item")
                                           :selected (equal item-index selected-idx))
                              :children (list (make-ui-node :type :text
                                                            :props (list :value (if (stringp item) item (getf item :label "?")))
                                                            :children nil)))))))
