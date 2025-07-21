;;;===============================================================
;;; File: src/view/dsl/base.lisp
;;; Enhanced Base DSL System with Validation and Expansion
;;;===============================================================
(uiop:define-package :elmtui.view.dsl.base
  (:use :cl :alexandria)
  (:export
   ;; Core DSL functions
   #:validate-base-dsl #:expand-base-dsl #:normalize-base-dsl
   ;; Element definition and registry
   #:define-base-element #:get-element-spec #:*base-element-types*
   ;; DSL predicates and utilities
   #:base-dsl-p #:element-type-p #:valid-property-p
   ;; DSL transformation
   #:dsl-element-type #:dsl-properties #:dsl-children
   #:make-dsl-element #:update-dsl-element
   ;; DSL query and traversal
   #:find-elements-by-type #:find-element-by-id #:map-dsl-elements
   ;; Statistics and debugging
   #:dsl-statistics #:describe-element-type #:validate-dsl-tree
   ;; Error conditions
   #:base-dsl-error))

(in-package :elmtui.view.dsl.base)

;;;--------------------------------------------------------------
;;; Base DSL Grammar and Element Registry
;;;--------------------------------------------------------------

;; Core element types with their specifications
(defparameter *base-element-types*
  `((:container
     :description "Generic container for other elements"
     :valid-properties (:id :children :style :class :layout :padding :margin :gap)
     :required-properties ()
     :default-properties (:layout :vertical)
     :content-model :children)

    (:text
     :description "Text content element"
     :valid-properties (:id :content :style :class :wrap :align :color)
     :required-properties (:content)
     :default-properties (:wrap t :align :left)
     :content-model :text)

    (:separator
     :description "Visual separator element"
     :valid-properties (:id :orientation :style :class :thickness)
     :required-properties ()
     :default-properties (:orientation :horizontal :thickness 1)
     :content-model :void)

    (:spacer
     :description "Empty space element for layout"
     :valid-properties (:id :width :height :style :class)
     :required-properties ()
     :default-properties (:width 0 :height 0)
     :content-model :void)

    ;; (:label
    ;;  :description "Text label element"
    ;;  :valid-properties (:id :text :style :class :for :color)
    ;;  :required-properties (:text)
    ;;  :default-properties ()
    ;;  :content-model :text)

    ;; (:button
    ;;  :description "Interactive button element"
    ;;  :valid-properties (:id :text :style :class :disabled :on-click :focusable)
    ;;  :required-properties (:text)
    ;;  :default-properties (:disabled nil :focusable t)
    ;;  :content-model :interactive)

    ;; (:input
    ;;  :description "Text input element"
    ;;  :valid-properties (:id :type :value :placeholder :style :class :disabled
    ;;                         :on-change :on-focus :on-blur :focusable :required)
    ;;  :required-properties (:type)
    ;;  :default-properties (:type :text :disabled nil :focusable t :required nil)
    ;;  :content-model :form)

    ;; (:textarea
    ;;  :description "Multi-line text input"
    ;;  :valid-properties (:id :value :placeholder :rows :cols :style :class
    ;;                         :disabled :on-change :on-focus :on-blur :focusable :required)
    ;;  :required-properties ()
    ;;  :default-properties (:rows 4 :cols 40 :disabled nil :focusable t :required nil)
    ;;  :content-model :form)

    ;; (:select
    ;;  :description "Selection dropdown element"
    ;;  :valid-properties (:id :value :options :style :class :disabled
    ;;                     :on-change :focusable :multiple)
    ;;  :required-properties (:options)
    ;;  :default-properties (:disabled nil :focusable t :multiple nil)
    ;;  :content-model :form)

    ;; (:checkbox
    ;;  :description "Checkbox input element"
    ;;  :valid-properties (:id :checked :label :style :class :disabled
    ;;                     :on-change :focusable)
    ;;  :required-properties ()
    ;;  :default-properties (:checked nil :disabled nil :focusable t)
    ;;  :content-model :form)

    ;; (:radio
    ;;  :description "Radio button input element"
    ;;  :valid-properties (:id :checked :label :name :value :style :class
    ;;                         :disabled :on-change :focusable)
    ;;  :required-properties (:name)
    ;;  :default-properties (:checked nil :disabled nil :focusable t)
    ;;  :content-model :form)

    ;; (:image
    ;;  :description "Image display element"
    ;;  :valid-properties (:id :src :alt :width :height :style :class)
    ;;  :required-properties (:src)
    ;;  :default-properties ()
    ;;  :content-model :media)

    ;; (:link
    ;;  :description "Hyperlink element"
    ;;  :valid-properties (:id :href :text :target :style :class :on-click)
    ;;  :required-properties (:href :text)
    ;;  :default-properties (:target :_self)
    ;;  :content-model :interactive)

    ;; (:list
    ;;  :description "List container element"
    ;;  :valid-properties (:id :items :style :class :ordered :item-style)
    ;;  :required-properties (:items)
    ;;  :default-properties (:ordered nil)
    ;;  :content-model :children)

    ;; (:table
    ;;  :description "Table element with rows and columns"
    ;;  :valid-properties (:id :headers :rows :style :class :border :cell-padding)
    ;;  :required-properties (:rows)
    ;;  :default-properties (:border t :cell-padding 1)
    ;;  :content-model :tabular)

    ))

(defun get-element-spec (element-type)
  "Retrieves the specification for a base element type"
  (find element-type *base-element-types* :key #'first))

(defmacro define-base-element (type &key description valid-properties
                                      required-properties default-properties
                                      content-model)
  "Defines a new base DSL element type"
  `(progn
     (setf *base-element-types*
           (cons (list ,type
                       :description ,description
                       :valid-properties ',valid-properties
                       :required-properties ',required-properties
                       :default-properties ',default-properties
                       :content-model ,content-model)
                 (remove ,type *base-element-types* :key #'first)))
     ,type))

;;;--------------------------------------------------------------
;;; DSL Validation Functions
;;;--------------------------------------------------------------

(define-condition base-dsl-error (error)
  ((element :initarg :element :reader dsl-error-element)
   (reason :initarg :reason :reader dsl-error-reason)
   (context :initarg :context :reader dsl-error-context :initform nil))
  (:report (lambda (condition stream)
             (format stream "Base DSL Error in ~A: ~A~@[ (~A)~]"
                     (dsl-error-element condition)
                     (dsl-error-reason condition)
                     (dsl-error-context condition)))))

(defun base-dsl-p (dsl)
  "Predicate to check if something is valid base DSL"
  (handler-case
      (progn (validate-base-dsl dsl) t)
    (base-dsl-error () nil)))

(defun element-type-p (type)
  "Predicate to check if a type is a valid element type"
  (and (keywordp type)
       (not (null (get-element-spec type)))))

(defun valid-property-p (element-type property)
  "Predicate to check if a property is valid for an element type"
  (let ((spec (get-element-spec element-type)))
    (when spec
      (member property (getf (rest spec) :valid-properties)))))

(defun validate-base-dsl (dsl &optional (context "base DSL"))
  "Validates base DSL structure against grammar and element specifications"
  (cond
    ;; Text content is always valid
    ((stringp dsl) dsl)

    ;; Numeric content is always valid
    ((numberp dsl) dsl)

    ;; NIL is valid (represents empty content)
    ((null dsl) dsl)

    ;; List of DSL elements
    ((and (listp dsl) (not (keywordp (first dsl))))
     (dolist (element dsl)
       (validate-base-dsl element (format nil "~A list item" context)))
     dsl)

    ;; Single DSL element
    ((and (listp dsl) (keywordp (first dsl)))
     (validate-dsl-element dsl context))

    ;; Invalid structure
    (t (error 'base-dsl-error
              :element dsl
              :reason "Invalid DSL structure: must be string, number, nil, or (keyword ...)"
              :context context))))

(defun validate-dsl-element (element context)
  "Validates a single DSL element"
  (let* ((element-type (first element))
         (properties (rest element))
         (element-spec (get-element-spec element-type)))

    ;; Check if element type exists
    (unless element-spec
      (error 'base-dsl-error
             :element element
             :reason (format nil "Unknown element type: ~A" element-type)
             :context context))

    ;; Validate properties structure (must be plist)
    (unless (evenp (length properties))
      (error 'base-dsl-error
             :element element
             :reason "Properties must be a property list (even number of elements)"
             :context context))

    ;; Extract property specifications
    (let ((valid-props (getf (rest element-spec) :valid-properties))
          (required-props (getf (rest element-spec) :required-properties))
          (content-model (getf (rest element-spec) :content-model)))

      ;; Validate required properties
      (dolist (req-prop required-props)
        (unless (getf properties req-prop)
          (error 'base-dsl-error
                 :element element
                 :reason (format nil "Missing required property: ~A" req-prop)
                 :context context)))

      ;; Validate property keys
      (loop for (prop value) on properties by #'cddr
            unless (member prop valid-props)
              do (warn "Unknown property ~A in ~A element (context: ~A)"
                       prop element-type context))

      ;; Validate content model constraints
      (validate-content-model element content-model context)

      ;; Recursively validate children if present
      (let ((children (getf properties :children)))
        (when children
          (validate-children children element-type context))))

    element))

(defun validate-content-model (element content-model context)
  "Validates element against its content model"
  (let ((properties (rest element)))
    (case content-model
      (:void
       ;; Void elements cannot have children
       (when (getf properties :children)
         (error 'base-dsl-error
                :element element
                :reason "Void elements cannot have children"
                :context context)))

      (:text
       ;; Text elements should have text content
       (unless (or (getf properties :text)
                   (getf properties :content))
         (warn "Text element without content in ~A" context)))

      (:children
       ;; Container elements should typically have children
       (unless (getf properties :children)
         (warn "Container element without children in ~A" context)))

      (:form
       ;; Form elements should have value-related properties
       (unless (or (member :value properties)
                   (member :checked properties)
                   (member :selected properties))
         (warn "Form element without value property in ~A" context))))))

(defun validate-children (children element-type context)
  "Validates children of a DSL element"
  (declare (ignore element-type))
  (let ((child-context (format nil "~A > children" context)))
    (cond
      ((null children) nil)  ; No children is valid

      ((listp children)
       ;; Validate each child
       (dolist (child children)
         (validate-base-dsl child child-context)))

      (t
       (error 'base-dsl-error
              :element children
              :reason ":children must be a list"
              :context child-context)))))

;;;--------------------------------------------------------------
;;; Helper function for checking property existence
;;;--------------------------------------------------------------

(defun property-exists-p (plist property)
  "Checks if a property key exists in a plist, regardless of its value"
  (member property plist))

;;;--------------------------------------------------------------
;;; DSL Expansion and Normalization
;;;--------------------------------------------------------------

(defun expand-base-dsl (dsl &optional (context "expansion"))
  "Expands base DSL with default properties and normalization"
  (cond
    ;; Primitive content - return as-is
    ((or (stringp dsl) (numberp dsl) (null dsl)) dsl)

    ;; List of elements - expand each
    ((and (listp dsl) (not (keywordp (first dsl))))
     (mapcar (lambda (element)
               (expand-base-dsl element context))
             dsl))

    ;; Single element - expand with defaults
    ((and (listp dsl) (keywordp (first dsl)))
     (expand-dsl-element dsl context))

    ;; Unknown structure - return as-is with warning
    (t
     (warn "Cannot expand unknown DSL structure: ~A (context: ~A)" dsl context)
     dsl)))

(defun expand-dsl-element (element context)
  "Expands a single DSL element with default properties"
  (let* ((element-type (first element))
         (properties (rest element))
         (element-spec (get-element-spec element-type)))

    (if element-spec
        (let ((defaults (getf (rest element-spec) :default-properties))
              (expanded-props (copy-list properties)))

          ;; Merge defaults (existing properties take precedence)
          ;; FIXED: Use property-exists-p to check if property key exists, not just if value is non-nil
          (loop for (default-prop default-value) on defaults by #'cddr
                unless (property-exists-p expanded-props default-prop)
                  do (setf (getf expanded-props default-prop) default-value))

          ;; Recursively expand children
          (let ((children (getf expanded-props :children)))
            (when children
              (setf (getf expanded-props :children)
                    (expand-base-dsl children
                                     (format nil "~A > children" context)))))

          ;; Return expanded element
          (list* element-type expanded-props))

        ;; Unknown element type - return as-is
        (progn
          (warn "Cannot expand unknown element type: ~A (context: ~A)"
                element-type context)
          element))))

(defun normalize-base-dsl (dsl)
  "Normalizes DSL by ensuring consistent structure"
  (let ((validated-dsl (validate-base-dsl dsl "normalization")))
    (expand-base-dsl validated-dsl "normalization")))

;;;--------------------------------------------------------------
;;; DSL Manipulation Utilities
;;;--------------------------------------------------------------

(defun dsl-element-type (element)
  "Extracts the element type from a DSL element"
  (when (and (listp element) (keywordp (first element)))
    (first element)))

(defun dsl-properties (element)
  "Extracts the properties plist from a DSL element"
  (when (and (listp element) (keywordp (first element)))
    (rest element)))

(defun dsl-children (element)
  "Extracts the children from a DSL element"
  (when (and (listp element) (keywordp (first element)))
    (getf (rest element) :children)))

(defun make-dsl-element (type &rest properties)
  "Constructs a DSL element with validation"
  (let ((element (list* type properties)))
    (validate-base-dsl element "construction")
    element))

(defun update-dsl-element (element &rest property-updates)
  "Updates properties of a DSL element"
  (when (and (listp element) (keywordp (first element)))
    (let* ((element-type (first element))
           (current-props (rest element))
           (updated-props (copy-list current-props)))

      ;; Apply updates
      (loop for (prop value) on property-updates by #'cddr
            do (setf (getf updated-props prop) value))

      ;; Validate and return updated element
      (let ((updated-element (list* element-type updated-props)))
        (validate-base-dsl updated-element "update")
        updated-element))))

;;;--------------------------------------------------------------
;;; DSL Query and Traversal
;;;--------------------------------------------------------------

(defun find-elements-by-type (dsl element-type)
  "Finds all elements of a specific type in DSL tree"
  (let ((results nil))
    (labels ((traverse (node)
               (cond
                 ((and (listp node) (keywordp (first node)))
                  (when (eq (first node) element-type)
                    (push node results))
                  (let ((children (getf (rest node) :children)))
                    (when children
                      (if (listp children)
                          (mapc #'traverse children)
                          (traverse children)))))

                 ((listp node)
                  (mapc #'traverse node)))))
      (traverse dsl)
      (nreverse results))))

(defun find-element-by-id (dsl id)
  "Finds an element by its :id property"
  (labels ((traverse (node)
             (cond
               ((and (listp node) (keywordp (first node)))
                (if (eq (getf (rest node) :id) id)
                    node
                    (let ((children (getf (rest node) :children)))
                      (when children
                        (if (listp children)
                            (some #'traverse children)
                            (traverse children))))))

               ((listp node)
                (some #'traverse node)))))
    (traverse dsl)))

(defun map-dsl-elements (function dsl)
  "Maps a function over all DSL elements"
  (labels ((map-traverse (node)
             (cond
               ((and (listp node) (keywordp (first node)))
                (let* ((transformed (funcall function node))
                       (children (getf (rest transformed) :children)))
                  (if children
                      (update-dsl-element transformed
                                          :children (if (listp children)
                                                        (mapcar #'map-traverse children)
                                                        (map-traverse children)))
                      transformed)))

               ((listp node)
                (mapcar #'map-traverse node))

               (t node))))
    (map-traverse dsl)))

;;;--------------------------------------------------------------
;;; Development and Debugging Support
;;;--------------------------------------------------------------

(defun describe-element-type (element-type)
  "Provides detailed information about an element type"
  (let ((spec (get-element-spec element-type)))
    (if spec
        (format t "~&Element Type: ~A~%~
                   Description: ~A~%~
                   Valid Properties: ~{~A~^, ~}~%~
                   Required Properties: ~{~A~^, ~}~%~
                   Default Properties: ~{~A ~S~^, ~}~%~
                   Content Model: ~A~%"
                element-type
                (getf (rest spec) :description)
                (getf (rest spec) :valid-properties)
                (getf (rest spec) :required-properties)
                (getf (rest spec) :default-properties)
                (getf (rest spec) :content-model))
        (format t "~&Unknown element type: ~A~%" element-type))))

(defun validate-dsl-tree (dsl &key (output-stream t))
  "Validates a DSL tree and reports detailed results"
  (handler-case
      (progn
        (validate-base-dsl dsl)
        (format output-stream "~&✓ DSL validation passed~%")
        t)
    (base-dsl-error (e)
      (format output-stream "~&✗ DSL validation failed:~%  ~A~%" e)
      nil)
    (error (e)
      (format output-stream "~&✗ Unexpected error during DSL validation:~%  ~A~%" e)
      nil)))

(defun dsl-statistics (dsl)
  "Generates statistics about a DSL tree"
  (let ((element-counts (make-hash-table))
        (total-elements 0)
        (max-depth 0))

    (labels ((count-elements (node depth)
               (setf max-depth (max max-depth depth))
               (cond
                 ((and (listp node) (keywordp (first node)))
                  (incf total-elements)
                  (incf (gethash (first node) element-counts 0))
                  (let ((children (getf (rest node) :children)))
                    (when children
                      (if (listp children)
                          (mapc (lambda (child) (count-elements child (1+ depth))) children)
                          (count-elements children (1+ depth))))))

                 ((listp node)
                  (mapc (lambda (child) (count-elements child depth)) node)))))

      (count-elements dsl 0)

      (list :total-elements total-elements
            :max-depth max-depth
            :element-types (hash-table-count element-counts)
            :element-counts (alexandria:hash-table-alist element-counts)))))
