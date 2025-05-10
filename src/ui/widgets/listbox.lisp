;;;===============================================================
;;; File: src/ui/widgets/listbox.lisp
;;; Elm-style ListBox Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.listbox
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.core #:make-ui-node #:ui-node)
  (:import-from :elmtui.core.events #:cmd)
  ;; TODO: Import specific key symbols if needed
  (:export #:listbox-model #:make-listbox-model ; Struct and constructor
           ;; Accessors
           #:listbox-model-id
           #:listbox-model-items
           #:listbox-model-height
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
  (height 10 :type unsigned-byte) ; Visible height in lines
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
;;; Helper Functions
;;;---------------------------------------------------------------
(defun clamp-index (idx item-count)
  "Clamps the index within valid bounds for the list.
   IDX: The index to clamp
   ITEM-COUNT: Total number of items
   Returns a valid index or NIL if input was NIL."
  (when idx 
    (alexandria:clamp idx 0 (max 0 (1- item-count)))))

(defun clamp-scroll (offset height item-count)
  "Clamps the scroll offset within valid bounds.
   OFFSET: Current scroll position
   HEIGHT: Visible height of the viewport
   ITEM-COUNT: Total number of items
   Returns a valid scroll offset."
  (alexandria:clamp offset 0 (max 0 (- item-count height))))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-listbox (id &key
                          (items nil)
                          (selected-index nil)
                          (height 10)
                          (on-select nil))
  "Initializes a new listbox model.
   Returns (values listbox-model initial-command)."
  (values (%make-listbox-model :id id
                               :items items
                               :selected-index selected-index
                               :scroll-offset 0
                               :height height ; Store height
                               :is-focused nil
                               :on-select on-select)
          nil))

;;;---------------------------------------------------------------
;;; Update
;;;---------------------------------------------------------------
(defun update-listbox (msg model)
  "Updates the listbox model based on a message. PURE function.
   Returns (values new-listbox-model command-list)."
  (check-type model listbox-model)
  ;; Create a fresh copy to modify and return
  (let ((new-model (copy-structure model))
        (commands nil)
        (selection-changed nil)
        (item-count (length (listbox-model-items model)))
        (msg-data (when (listp msg) (rest msg))))

    ;; Modify the *copy* (new-model) based on the message
    (case (first msg)
      ;; --- Keyboard Navigation (when focused) ---
      (:listbox-key-press
       (when (listbox-model-is-focused model) ; Check focus on original model
         (let* ((key-data (getf msg-data :key))
                (key-sym (getf key-data :key-sym))
                (current-index (listbox-model-selected-index model))) ; Use original index
           (case key-sym
             (:up
              (when (> item-count 0)
                (let ((new-idx (clamp-index (if current-index (1- current-index) (1- item-count)) item-count)))
                  (when new-idx
                    (setf (listbox-model-selected-index new-model) new-idx ; Modify copy
                          selection-changed t)))))
             (:down
              (when (> item-count 0)
                (let ((new-idx (clamp-index (if current-index (1+ current-index) 0) item-count)))
                  (when new-idx
                    (setf (listbox-model-selected-index new-model) new-idx ; Modify copy
                          selection-changed t)))))
             ;; TODO: Add PageUp, PageDown, Home, End handling (requires knowing view height)
             (:enter
              (when (and current-index (listbox-model-on-select model)) ; Check original model
                (setf selection-changed t)))))))

      ;; --- Direct Manipulation ---
      (:listbox-select-index
       (let ((new-idx (clamp-index (getf msg-data :index) item-count)))
         (when (and new-idx (not (equal new-idx (listbox-model-selected-index model)))) ; Compare with original
           (setf (listbox-model-selected-index new-model) new-idx ; Modify copy
                 selection-changed t))))

      (:listbox-set-items
       (let* ((new-items (getf msg-data :items))
              (new-item-count (length new-items))
              (current-index (listbox-model-selected-index model)) ; Use original
              (current-offset (listbox-model-scroll-offset model)) ; Use original
              (current-height (listbox-model-height model)) ; Use original
              (clamped-index (clamp-index current-index new-item-count))
              (clamped-offset (clamp-scroll current-offset current-height new-item-count)))
         (setf (listbox-model-items new-model) new-items ; Modify copy
               (listbox-model-selected-index new-model) clamped-index
               (listbox-model-scroll-offset new-model) clamped-offset)))

      ;; --- Scrolling ---
      (:listbox-scroll-up
       (let* ((amount (or (getf msg-data :amount) 1))
              (current-offset (listbox-model-scroll-offset model)) ; Use original
              (current-height (listbox-model-height model)) ; Use original
              (new-offset (max 0 (- current-offset amount))))
         (setf (listbox-model-scroll-offset new-model) ; Modify copy
               (clamp-scroll new-offset current-height item-count))))

      (:listbox-scroll-down
       (let* ((amount (or (getf msg-data :amount) 1))
              (current-offset (listbox-model-scroll-offset model)) ; Use original
              (current-height (listbox-model-height model)) ; Use original
              (new-offset (+ current-offset amount)))
         (setf (listbox-model-scroll-offset new-model) ; Modify copy
               (clamp-scroll new-offset current-height item-count))))

      ;; --- Focus ---
      (:listbox-focus
       (unless (listbox-model-is-focused model) ; Check original
         (setf (listbox-model-is-focused new-model) t))) ; Modify copy

      (:listbox-blur
       (when (listbox-model-is-focused model) ; Check original
         (setf (listbox-model-is-focused new-model) nil)))) ; Modify copy

    ;; --- Post-update Actions ---
    ;; Generate commands based on the *new* model state
    (when (and selection-changed (listbox-model-on-select new-model))
      (let* ((selected-idx (listbox-model-selected-index new-model))
             (selected-item (when selected-idx (nth selected-idx (listbox-model-items new-model))))
             (on-select-msg (listbox-model-on-select new-model)))
        (push (if (listp on-select-msg)
                  (append on-select-msg (list :index selected-idx :item selected-item))
                  on-select-msg)
              commands)))

    ;; Return the *new* model and commands
    (values new-model (nreverse commands))))

;;;---------------------------------------------------------------
;;; View
;;;---------------------------------------------------------------
(defun view-listbox (model global-current-focus-id &optional dispatch-fn)
  "Creates a UI-NODE representation of the listbox.
   MODEL: The current listbox-model instance.
   GLOBAL-CURRENT-FOCUS-ID: The ID of the widget that currently has global focus.
   DISPATCH-FN: (Optional) A function to call to dispatch messages for events like clicks.
   Returns a UI-NODE."
  (check-type model listbox-model)
  (let* ((items (listbox-model-items model))
         (selected-idx (listbox-model-selected-index model))
         (scroll-offset (listbox-model-scroll-offset model))
         (widget-id (listbox-model-id model))
         (is-globally-focused (equal widget-id global-current-focus-id))
         (visible-height (listbox-model-height model)) ; Use height from model
         (visible-items (subseq items scroll-offset (min (length items) (+ scroll-offset visible-height)))))

    ;; (format t "DEBUG: Listbox ~A, Global Focus: ~A, Is Globally Focused: ~A~%" widget-id global-current-focus-id is-globally-focused)
    ;; (format t "DEBUG: Visible items for ~A: ~A~%" widget-id visible-items)
    (make-ui-node
     :type :list-box ; Specific type for renderer
     :props (list :widget-id widget-id
                  ;; :height visible-height ; Height is now handled by style system
                  :class (if is-globally-focused "listbox listbox-focused" "listbox")
                  :scroll-offset scroll-offset
                  :item-count (length items)
                  :focusable t ; This widget can be focused
                  ;; Click on item to select
                  :events (when dispatch-fn
                            (list (list :click ; Platform needs to provide item index on click
                                        (lambda (&key item-index) ; item-index relative to visible items
                                          (when item-index
                                            (let ((actual-index (+ scroll-offset item-index)))
                                              (funcall dispatch-fn (list msg-listbox-select-index :index actual-index)))))))))
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
