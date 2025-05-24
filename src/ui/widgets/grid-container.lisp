;;;===============================================================
;;; File: src/ui/widgets/grid-container.lisp
;;; Standardized Grid Container Widget
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.grid-container
  (:use :cl :alexandria)
  (:import-from :elmtui.view.styled #:make-styled-node)
  (:import-from :elmtui.ui.widgets.utils
                #:defwidget-view
                #:with-widget-model
                #:widget-focused-p)
  ;; (:import-from :elmtui.view.grid-layout
  ;;               #:grid-template
  ;;               #:grid-area
  ;;               #:grid-auto-flow
  ;;               #:compute-grid-layout)
  (:export #:grid-container-model #:make-grid-container-model ; Struct and constructor
           ;; Accessors
           #:grid-container-model-id
           #:grid-container-model-template-rows
           #:grid-container-model-template-columns
           #:grid-container-model-template-areas
           #:grid-container-model-auto-flow
           #:grid-container-model-gap
           #:grid-container-model-row-gap
           #:grid-container-model-column-gap
           ;; Functions
           #:init-grid-container #:view-grid-container))
(in-package :elmtui.ui.widgets.grid-container)

;;;---------------------------------------------------------------
;;; Model
;;;---------------------------------------------------------------
(defstruct (grid-container-model (:constructor %make-grid-container-model))
  "Model for a grid container widget.
   ID: Unique identifier.
   TEMPLATE-ROWS: Grid template rows specification.
   TEMPLATE-COLUMNS: Grid template columns specification.
   TEMPLATE-AREAS: Grid template areas specification.
   AUTO-FLOW: Grid auto-flow property.
   GAP: Grid gap.
   ROW-GAP: Grid row gap.
   COLUMN-GAP: Grid column gap."
  (id (error "ID must be provided.") :type T :read-only t)
  (template-rows '("auto") :type list)
  (template-columns '("1fr") :type list)
  (template-areas nil :type (or null string list))
  (auto-flow "row" :type string)
  (gap 0 :type number)
  (row-gap nil :type (or null number))
  (column-gap nil :type (or null number))
  (justify-content "start" :type string)
  (align-content "start" :type string)
  (justify-items "stretch" :type string)
  (align-items "stretch" :type string))

;;;---------------------------------------------------------------
;;; Init
;;;---------------------------------------------------------------
(defun init-grid-container (id &key
                                    (template-rows '("auto"))
                                    (template-columns '("1fr"))
                                    template-areas
                                    (auto-flow "row")
                                    (gap 0)
                                    row-gap
                                    column-gap
                                    (justify-content "start")
                                    (align-content "start")
                                    (justify-items "stretch")
                                    (align-items "stretch"))
  "Initializes a new grid container model.
   Returns (values grid-container-model initial-command)."
  (values (%make-grid-container-model :id id
                                      :template-rows template-rows
                                      :template-columns template-columns
                                      :template-areas template-areas
                                      :auto-flow auto-flow
                                      :gap gap
                                      :row-gap row-gap
                                      :column-gap column-gap
                                      :justify-content justify-content
                                      :align-content align-content
                                      :justify-items justify-items
                                      :align-items align-items)
          nil)) ; No initial commands

;;;---------------------------------------------------------------
;;; View (STANDARDIZED FORMAT)
;;;---------------------------------------------------------------
(defwidget-view view-grid-container (app-state
                                        :model-var model :widget-id-var widget-id
                                        :add-args (template-rows
                                                   template-columns
                                                   template-areas
                                                   auto-flow
                                                   gap
                                                   row-gap
                                                   column-gap
                                                   justify-content
                                                   align-content
                                                   justify-items
                                                   align-items
                                                   width
                                                   height
                                                   children
                                                   class)
                                        :documentation
                                        "Creates a UI representation of a grid container.
   APP-STATE: The application state.
   WIDGET-ID: The unique ID for this grid container (required).
   TEMPLATE-ROWS: Grid template rows specification.
   TEMPLATE-COLUMNS: Grid template columns specification.
   TEMPLATE-AREAS: Grid template areas specification.
   AUTO-FLOW: Grid auto-flow property.
   GAP: Grid gap.
   ROW-GAP: Grid row gap.
   COLUMN-GAP: Grid column gap.
   JUSTIFY-CONTENT: Content justification along main axis.
   ALIGN-CONTENT: Content alignment along cross axis.
   JUSTIFY-ITEMS: Default item justification.
   ALIGN-ITEMS: Default item alignment.
   WIDTH: Container width.
   HEIGHT: Container height.
   CHILDREN: Child elements to place in the grid.
   CLASS: Additional CSS classes to apply.")

  ;; Determine effective values from model and/or provided props
  (let* ((effective-template-rows (or template-rows
                                      (when model (grid-container-model-template-rows model))
                                      '("auto")))
         (effective-template-columns (or template-columns
                                         (when model (grid-container-model-template-columns model))
                                         '("1fr")))
         (effective-template-areas (or template-areas
                                       (when model (grid-container-model-template-areas model))
                                       nil))
         (effective-auto-flow (or auto-flow
                                  (when model (grid-container-model-auto-flow model))
                                  "row"))
         (effective-gap (or gap
                            (when model (grid-container-model-gap model))
                            0))
         (effective-row-gap (or row-gap
                                (when model (grid-container-model-row-gap model))
                                effective-gap))
         (effective-column-gap (or column-gap
                                   (when model (grid-container-model-column-gap model))
                                   effective-gap))
         (effective-justify-content (or justify-content
                                        (when model (grid-container-model-justify-content model))
                                        "start"))
         (effective-align-content (or align-content
                                      (when model (grid-container-model-align-content model))
                                      "start"))
         (effective-justify-items (or justify-items
                                      (when model (grid-container-model-justify-items model))
                                      "stretch"))
         (effective-align-items (or align-items
                                    (when model (grid-container-model-align-items model))
                                    "stretch"))
         ;; Build CSS classes
         (base-class "grid-container")
         (custom-class class)
         (all-classes (remove nil (list base-class custom-class))))

    ;; Create the styled node representing the grid container
    (make-styled-node
     :type :div
     :props (list* :id widget-id
                   :display :grid
                   :grid-template-rows effective-template-rows
                   :grid-template-columns effective-template-columns
                   :grid-auto-flow effective-auto-flow
                   :gap effective-gap
                   :row-gap effective-row-gap
                   :column-gap effective-column-gap
                   :justify-content effective-justify-content
                   :align-content effective-align-content
                   :justify-items effective-justify-items
                   :align-items effective-align-items
                   :class (format nil "~{~A~^ ~}" all-classes)
                   (append
                    (when effective-template-areas
                      (list :grid-template-areas effective-template-areas))
                    (when width (list :width width))
                    (when height (list :height height))))
     :children children)))

;;;---------------------------------------------------------------
;;; Standalone Grid Item Creator
;;;---------------------------------------------------------------
(defun grid-item (&key id area row row-span col col-span align justify class children)
  "Creates a grid item with the specified properties.
   ID: Item identifier.
   AREA: Named grid area to place this item.
   ROW: Starting row number.
   ROW-SPAN: Number of rows to span.
   COL: Starting column number.
   COL-SPAN: Number of columns to span.
   ALIGN: Self-alignment in cell.
   JUSTIFY: Self-justification in cell.
   CLASS: Additional CSS classes.
   CHILDREN: Child elements.

   Returns a styled-node representing the grid item."
  (let* ((row-start (or row 1))
         (row-end (when row-span (+ row-start row-span)))
         (col-start (or col 1))
         (col-end (when col-span (+ col-start col-span)))
         (base-class "grid-item")
         (all-classes (remove nil (list base-class class))))

    (make-styled-node
     :type :div
     :props (list* :class (format nil "~{~A~^ ~}" all-classes)
                   (append
                    (when id (list :id id))
                    (when area (list :grid-area area))
                    (when row-start (list :grid-row-start row-start))
                    (when row-end (list :grid-row-end row-end))
                    (when col-start (list :grid-column-start col-start))
                    (when col-end (list :grid-column-end col-end))
                    (when align (list :align-self align))
                    (when justify (list :justify-self justify))))
     :children children)))

;;;---------------------------------------------------------------
;;; Helper Functions for Responsive Grids
;;;---------------------------------------------------------------
(defun responsive-grid (id &key
                             (base-config '(:template-columns ("1fr")))
                             breakpoints
                             gap
                             class
                             children)
  "Creates a responsive grid container that changes layout based on viewport width.
   ID: Container identifier.
   BASE-CONFIG: Default grid configuration for all viewport sizes.
   BREAKPOINTS: Alist mapping viewport width thresholds to grid configurations.
   GAP: Grid gap.
   CLASS: Additional CSS classes.
   CHILDREN: Child elements.

   Returns a styled-node representing the responsive grid."
  (let* ((base-template-rows (getf base-config :template-rows '("auto")))
         (base-template-columns (getf base-config :template-columns '("1fr")))
         (base-template-areas (getf base-config :template-areas nil))
         (base-auto-flow (getf base-config :auto-flow "row"))
         (effective-gap (or gap 0))
         (base-class "responsive-grid")
         (all-classes (remove nil (list base-class class)))

         ;; Generate media query properties based on breakpoints
         (media-queries
           (when breakpoints
             (loop for (width . config) in breakpoints
                   for template-rows = (getf config :template-rows)
                   for template-columns = (getf config :template-columns)
                   for template-areas = (getf config :template-areas)
                   collect (list :min-width width
                                 :grid-template-rows (or template-rows base-template-rows)
                                 :grid-template-columns (or template-columns base-template-columns)
                                 :grid-template-areas (or template-areas base-template-areas))))))

    (make-styled-node
     :type :div
     :props (list* :id id
                   :display :grid
                   :grid-template-rows base-template-rows
                   :grid-template-columns base-template-columns
                   :grid-auto-flow base-auto-flow
                   :gap effective-gap
                   :class (format nil "~{~A~^ ~}" all-classes)
                   :media-queries media-queries ; Media queries for responsive behavior
                   (when base-template-areas
                     (list :grid-template-areas base-template-areas)))
     :children children)))
