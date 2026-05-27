;;;===============================================================
;;; File: src/ui/widgets/listbox.lisp
;;; Standardized Elm-style ListBox Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.listbox
  (:use :cl :alexandria :log4cl)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.core.async #:cmd-async)
  (:import-from :elmtui.core.events #:send-message)
  (:import-from :elmtui.ui.widgets.utils
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  (:export #:listbox-model #:make-listbox-model ; Struct and constructor
           ;; Accessors
           #:listbox-model-id
           #:listbox-model-items
           #:listbox-model-height
           #:listbox-model-selected-index
           #:listbox-model-scroll-offset
           #:listbox-model-on-select
           ;; Core TEA functions
           #:init-listbox #:update-listbox #:view-listbox
           ;; Message types
           #:msg-listbox-key-press
           #:msg-listbox-select-index
           #:msg-listbox-set-items
           #:msg-listbox-scroll-up
           #:msg-listbox-scroll-down))
(in-package :elmtui.ui.widgets.listbox)

;;;---------------------------------------------------------------
;;; Helper Functions
;;;---------------------------------------------------------------
(defun clamp-index (idx item-count)
  "Clamps the index within valid bounds for the list."
  (when idx
    (alexandria:clamp idx 0 (max 0 (1- item-count)))))

(defun clamp-scroll (offset height item-count)
  "Clamps the scroll offset within valid bounds."
  (alexandria:clamp offset 0 (max 0 (- item-count height))))

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (listbox-model (:constructor %make-listbox-model))
  "Model for a listbox widget.
   ID: Unique identifier.
   ITEMS: List of items to display.
   SELECTED-INDEX: Index of the currently selected item.
   SCROLL-OFFSET: Index of first visible item.
   HEIGHT: Number of visible items.
   ON-SELECT: Message to dispatch when item selected."
  (id (error "ID must be provided.") :type T :read-only t)
  (items nil :type list)
  (selected-index nil :type (or null unsigned-byte))
  (scroll-offset 0 :type unsigned-byte)
  (height 10 :type unsigned-byte)
  (on-select nil :type T))

;;;---------------------------------------------------------------
;;; Messages (Keywords)
;;;---------------------------------------------------------------
(defparameter msg-listbox-key-press :listbox-key-press)
(defparameter msg-listbox-select-index :listbox-select-index)
(defparameter msg-listbox-set-items :listbox-set-items)
(defparameter msg-listbox-scroll-up :listbox-scroll-up)
(defparameter msg-listbox-scroll-down :listbox-scroll-down)

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
                               :selected-index (clamp-index selected-index (length items))
                               :scroll-offset 0
                               :height height
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

    (cond
      ;; --- Keyboard Navigation ---
      ((and (consp msg) (eq (car msg) msg-listbox-key-press))
       (let* ((key-sym (getf (rest msg) :key))
              (current-index (listbox-model-selected-index model)))
         (case key-sym
           ((:up :k)
            (when (> item-count 0)
              (let ((new-idx (clamp-index (if current-index (1- current-index) (1- item-count)) item-count)))
                (when new-idx
                  (setf (listbox-model-selected-index new-model) new-idx
                        selection-changed t)))))
           ((:down :j)
            (when (> item-count 0)
              (let ((new-idx (clamp-index (if current-index (1+ current-index) 0) item-count)))
                (when new-idx
                  (setf (listbox-model-selected-index new-model) new-idx
                        selection-changed t)))))
           ((:page-up)
            (when (> item-count 0)
              (let* ((height (listbox-model-height model))
                     (new-idx (clamp-index (if current-index (- current-index height) 0) item-count)))
                (when new-idx
                  (setf (listbox-model-selected-index new-model) new-idx
                        selection-changed t)))))
           ((:page-down)
            (when (> item-count 0)
              (let* ((height (listbox-model-height model))
                     (new-idx (clamp-index (if current-index (+ current-index height) 0) item-count)))
                (when new-idx
                  (setf (listbox-model-selected-index new-model) new-idx
                        selection-changed t)))))
           ((:home)
            (when (> item-count 0)
              (setf (listbox-model-selected-index new-model) 0
                    selection-changed t)))
           ((:end)
            (when (> item-count 0)
              (setf (listbox-model-selected-index new-model) (1- item-count)
                    selection-changed t)))
           ((:enter)
            (when (and current-index (listbox-model-on-select model))
              (setf selection-changed t))))))

      ;; --- Direct Selection ---
      ((and (consp msg) (eq (car msg) msg-listbox-select-index))
       (let ((new-idx (clamp-index (getf (rest msg) :index) item-count)))
         (when (and new-idx (not (equal new-idx (listbox-model-selected-index model))))
           (setf (listbox-model-selected-index new-model) new-idx
                 selection-changed t))))

      ;; --- Update Items ---
      ((and (consp msg) (eq (car msg) msg-listbox-set-items))
       (let* ((new-items (getf (rest msg) :items))
              (new-item-count (length new-items))
              (current-index (listbox-model-selected-index model))
              (current-offset (listbox-model-scroll-offset model))
              (current-height (listbox-model-height model))
              (clamped-index (clamp-index current-index new-item-count))
              (clamped-offset (clamp-scroll current-offset current-height new-item-count)))
         (setf (listbox-model-items new-model) new-items
               (listbox-model-selected-index new-model) clamped-index
               (listbox-model-scroll-offset new-model) clamped-offset)))

      ;; --- Scrolling ---
      ((and (consp msg) (eq (car msg) msg-listbox-scroll-up))
       (let* ((amount (or (getf (rest msg) :amount) 1))
              (current-offset (listbox-model-scroll-offset model))
              (current-height (listbox-model-height model))
              (new-offset (max 0 (- current-offset amount))))
         (setf (listbox-model-scroll-offset new-model)
               (clamp-scroll new-offset current-height item-count))))

      ((and (consp msg) (eq (car msg) msg-listbox-scroll-down))
       (let* ((amount (or (getf (rest msg) :amount) 1))
              (current-offset (listbox-model-scroll-offset model))
              (current-height (listbox-model-height model))
              (new-offset (+ current-offset amount)))
         (setf (listbox-model-scroll-offset new-model)
               (clamp-scroll new-offset current-height item-count))))
      (t
       (warn "Unhandled listbox message: ~S" msg)))

    ;; --- Update scroll to ensure selected item is visible ---
    (let ((selected-idx (listbox-model-selected-index new-model)))
      (when selected-idx
        (let ((scroll-offset (listbox-model-scroll-offset new-model))
              (visible-height (listbox-model-height new-model)))
          (cond ((< selected-idx scroll-offset)
                 (setf (listbox-model-scroll-offset new-model) selected-idx))
                ((>= selected-idx (+ scroll-offset visible-height))
                 (setf (listbox-model-scroll-offset new-model)
                       (max 0 (- selected-idx (1- visible-height)))))))))

    ;; Generate commands based on selection change
    (when (and selection-changed (listbox-model-on-select new-model))
      (let* ((selected-idx (listbox-model-selected-index new-model))
             (selected-item (when selected-idx (nth selected-idx (listbox-model-items new-model))))
             (on-select-msg (listbox-model-on-select new-model)))
        (push (cmd-async #'send-message
                         :args (if (listp on-select-msg)
                                   (append on-select-msg (list :index selected-idx :item selected-item))
                                   on-select-msg))
              commands)))

    (values new-model commands)))

;;;---------------------------------------------------------------
;;; View (STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-listbox (app-state
                              :model-var model
                              :widget-id-var widget-id
                              :add-args ( items
                                          height
                                          selected-index
                                          on-select
                                          empty-text
                                          tooltip aria-label
                                          class width)
                              :documentation
                              "Creates a UI representation of a listbox.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this listbox (required).
   ITEMS: List of items to display. Each item can be a string or a plist with :label.
   HEIGHT: Number of items to display at once.
   SELECTED-INDEX: Index of the currently selected item.
   ON-SELECT: Message to dispatch when an item is selected.
   EMPTY-TEXT: Text to display when the list is empty.
   TOOLTIP: Optional tooltip text to display on hover.
   ARIA-LABEL: Accessibility label for screen readers.
   CLASS: Additional CSS classes to apply.
   WIDTH: Width in columns.

Usage:
   (view-listbox app-state
                   :widget-id :my-listbox
                   :items '(\"Item 1\" \"Item 2\" \"Item 3\")
                   :height 5
                   :selected-index 1
                   :on-select (list :msg-type :item-selected)
                   :empty-text \"No items available\"
                   :tooltip \"Select an item\"
                   :aria-label \"List of items\"
                   :class \"custom-listbox\"
                   :width 20)")
  ;; Determine effective values from model and/or provided props
  (let* ((effective-items (or items
                              (when model (listbox-model-items model))
                              nil))
         (effective-height (or height
                               (when model (listbox-model-height model))
                               10))
         (effective-selected-index (or selected-index
                                       (when model (listbox-model-selected-index model))
                                       nil))
         (effective-on-select (or on-select
                                  (when model (listbox-model-on-select model))
                                  nil))
         (scroll-offset (when model (listbox-model-scroll-offset model)))
         (effective-empty-text (or empty-text "No items"))
         (is-focused (widget-focused-p app-state widget-id))

         ;; Calculate visible items
         (item-count (length effective-items))
         (visible-items (if scroll-offset
                            (subseq effective-items
                                    scroll-offset
                                    (min item-count (+ scroll-offset effective-height)))
                            effective-items))

         ;; Build CSS classes
         (base-class "listbox")

         (focused-class (when is-focused "listbox-focused"))
         (empty-class (when (zerop item-count) "listbox-empty"))
         (custom-class class)
         (all-classes (remove nil (list base-class focused-class empty-class custom-class))))

    ;; Create the styled node representing the listbox
    (list :container
          :props (list* :id widget-id
                        :item-count item-count
                        :height effective-height
                        :scroll-offset (or scroll-offset 0)
                        :focusable (not (zerop item-count))
                        :class (format nil "~{~A~^ ~}" all-classes) ; Join classes with spaces
                        :aria-role "listbox"
                        :aria-multiselectable "false"
                        ;; Include optional properties only if provided
                        (append
                         (when width (list :width width))
                         (when tooltip (list :title tooltip))
                         (when aria-label (list :aria-label aria-label))
                         (when effective-on-select (progn
                                                     (log-info "Listbox on-select: ~A" effective-on-select)
                                                     (list :on-select effective-on-select)))))
          ;; Build child nodes for each visible item
          :children (if (zerop item-count)
                        ;; Empty state
                        (list :text :content effective-empty-text
                                    :props (list :value effective-empty-text
                                                 :class "listbox-empty-text")
                                    :children nil)
                        ;; Items
                        (loop for item in visible-items
                              for visible-index from 0
                              for actual-index = (+ (or scroll-offset 0) visible-index)
                              for is-selected = (equal actual-index effective-selected-index)
                              for item-text = (if (stringp item) item (getf item :label (format nil "Item ~A" actual-index)))
                              collect (list :text
                                            :type :list-item
                                            :props (list :id (format nil "~A-item-~A" widget-id actual-index)
                                                         :value item-text
                                                         :selected is-selected
                                                         :index actual-index
                                                         :aria-role "option"
                                                         :aria-selected (if is-selected "true" "false")
                                                         :class (if is-selected "list-item list-item-selected" "list-item"))
                                            :children (list :text
                                                            :content item-text
                                                            :props (list :value item-text)
                                                            :children nil)))))))

;;;---------------------------------------------------------------
;;; Backward Compatibility Wrapper
;;;---------------------------------------------------------------
;; This is a temporary function to maintain backward compatibility
;; during transition to the new widget pattern
                                        ; (defun view-listbox (model &key current-focus-id dispatch-fn)
;;   "DEPRECATED: Use view-listbox instead."
;;   (warn "view-listbox is deprecated. Use view-listbox with app-state and :widget-id instead.")
;;   (let* ((items (listbox-model-items model))
;;          (selected-idx (listbox-model-selected-index model))
;;          (scroll-offset (listbox-model-scroll-offset model))
;;          (widget-id (listbox-model-id model))
;;          (is-focused (equal widget-id current-focus-id))
;;          (visible-height (listbox-model-height model))
;;          (visible-items (subseq items scroll-offset (min (length items) (+ scroll-offset visible-height)))))

;;     (make-styled-node
;;      :type :list-box
;;      :props (list :id widget-id
;;                   :item-count (length items)
;;                   :scroll-offset scroll-offset
;;                   :focusable t
;;                   :class (if is-focused "listbox listbox-focused" "listbox")
;;                   :aria-role "listbox"
;;                   :aria-multiselectable "false")
;;      :children (loop for item in visible-items
;;                      for item-index from scroll-offset
;;                      collect (let ((item-class (if (equal item-index selected-idx)
;;                                                    "list-item list-item-selected"
;;                                                    "list-item")))
;;                                (make-styled-node
;;                                 :type :list-item
;;                                 :props (list :id (format nil "~A-item-~A" widget-id item-index)
;;                                              :value (if (stringp item) item (getf item :label "?"))
;;                                              :selected (equal item-index selected-idx)
;;                                              :class item-class)
;;                                 :children (list (make-styled-node
;;                                                  :type :text
;;                                                  :props (list :value (if (stringp item) item (getf item :label "?")))
;;                                                  :children nil))))))))
