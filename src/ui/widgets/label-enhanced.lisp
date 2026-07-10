;;;===============================================================
;;; File: src/ui/widgets/label-enhanced.lisp
;;; Enhanced Label Widget with DSL Integration and Contracts
;;;===============================================================
(uiop:define-package :elmtui.ui.widgets.label-enhanced
  (:use :cl :alexandria)
  (:import-from :elmtui.view.dsl 
                #:dsl->ui-node)
  (:import-from :elmtui.state.model
                #:defmodel-contracted #:defpatch #:make-state-patch #:apply-state-patches)
  (:import-from :elmtui.contracts
                #:defupdate-hybrid #:defview)
  (:import-from :elmtui.ui.defcomponent #:defcomponent)
  (:import-from :elmtui.ui.api #:id-from-path)
  (:export 
   #:label-enhanced #:make-label-enhanced
   ;; Label state model
   #:label-state #:make-label-state #:validate-label-state
   ;; Label operations
   #:update-label-text #:set-label-style #:set-label-target
   ;; Legacy compatibility
   #:label))

(in-package :elmtui.ui.widgets.label-enhanced)

;; Lightweight shims for DSL helpers
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (fboundp 'validate-base-dsl)
    (defun validate-base-dsl (dsl) dsl))
  (unless (fboundp 'expand-base-dsl)
    (defun expand-base-dsl (dsl) dsl)))

;;;--------------------------------------------------------------
;;; Enhanced Label State Model
;;;--------------------------------------------------------------

(defmodel-contracted label-state
  ((text "Label" :type string :required t
         :validator (lambda (v) (stringp v)))
   (for nil :type (or null keyword string)
        :documentation "ID of the element this label is associated with")
   (text-color nil :type (or null keyword string)
               :documentation "Text color for the label")
   (background-color nil :type (or null keyword string)
                     :documentation "Background color for the label")
   (font-weight :normal :type keyword
                :validator (lambda (v) (member v '(:normal :bold :light))))
   (font-style :normal :type keyword
               :validator (lambda (v) (member v '(:normal :italic :oblique))))
   (text-decoration nil :type (or null keyword)
                    :validator (lambda (v) (or (null v) (member v '(:underline :overline :line-through)))))
   (alignment :left :type keyword
              :validator (lambda (v) (member v '(:left :center :right :justify))))
   (wrap t :type boolean :documentation "Whether text should wrap")
   (truncate nil :type (or null keyword)
             :validator (lambda (v) (or (null v) (member v '(:ellipsis :clip)))))
   (aria-role :label :type keyword)
   (accessibility-hint nil :type (or null string))
   (visible t :type boolean)
   (focusable nil :type boolean :documentation "Whether the label can receive focus"))
  
  :validation (lambda (state)
                ;; Custom validation rules
                (when (and (getf state :truncate) (not (getf state :wrap)))
                  (warn "Label has truncate but wrap is disabled - may not display correctly"))
                
                (when (and (getf state :for) (not (keywordp (getf state :for))))
                  (unless (stringp (getf state :for))
                    (error "Label :for attribute must be keyword or string"))))
  
  :transactions
  ((update-text-transaction (state new-text)
     "Transaction to update label text"
     (list (make-state-patch :path '(:text) :value new-text :operation :set)))
   
   (set-style-transaction (state style-updates)
     "Transaction to update label styling"
     (loop for (prop value) on style-updates by #'cddr
           collect (make-state-patch :path (list prop) :value value :operation :set)))
   
   (set-accessibility-transaction (state role hint)
     "Transaction to update accessibility properties"
     (list (make-state-patch :path '(:aria-role) :value role :operation :set)
           (make-state-patch :path '(:accessibility-hint) :value hint :operation :set))))
  
  :observers
  ((lambda (old-state new-state change-type)
     (declare (ignore old-state new-state change-type))
     nil))
  
  :documentation "Enhanced label state model with comprehensive styling and accessibility"
  :export-accessors t)

;;;--------------------------------------------------------------
;;; Label Patch Operations
;;;--------------------------------------------------------------

(defpatch update-label-text (state new-text)
  "Updates the label text with validation"
  (make-state-patch :path '(:text) 
                   :value new-text 
                   :operation :set
                   :validator (lambda (v) (and (stringp v) (> (length v) 0)))
                   :source :user-action
                   :metadata (list :old-text (getf state :text))))

(defpatch set-label-style (state property value)
  "Updates a label style property"
  (let ((valid-properties '(:text-color :background-color :font-weight :font-style 
                           :text-decoration :alignment :wrap :truncate)))
    (unless (member property valid-properties)
      (error "Invalid label style property: ~A" property))
    
    (make-state-patch :path (list property)
                     :value value
                     :operation :set
                     :source :style-update
                     :metadata (list :property property :old-value (getf state property)))))

(defpatch set-label-target (state target-id)
  "Sets the target element this label is associated with"
  (make-state-patch :path '(:for)
                   :value target-id
                   :operation :set
                   :validator (lambda (v) (or (null v) (keywordp v) (stringp v)))
                   :source :association-update))

;;;--------------------------------------------------------------
;;; Enhanced Label Component (using defcomponent)
;;;--------------------------------------------------------------

(defcomponent label-enhanced ()
  (:metadata
   (:documentation "Enhanced label component with styling and accessibility metadata."))
  
  (:state
   (text "Label" :type string)
   (for nil :type (or null keyword string))
   (style nil :type (or null list))
   (accessibility nil :type (or null list)))
  
  (:init (props id-path)
    (let ((initial-state (make-label-state 
                         :text (getf props :text (getf props :initial-text "Label"))
                         :for (getf props :for (getf props :initial-for nil))
                         :text-color (getf props :text-color)
                         :background-color (getf props :background-color)
                         :font-weight (getf props :font-weight :normal)
                         :font-style (getf props :font-style :normal)
                         :alignment (getf props :alignment :left)
                         :wrap (getf props :wrap t)
                         :visible (getf props :visible t)
                         :focusable (getf props :focusable nil))))
      (values initial-state nil)))
  
  (:update (message state app-state id-path)
    (:set-text (new-text)
      (let ((patches (update-label-text state new-text)))
        (values (apply-state-patches state (list patches)) nil)))
    
    (:set-style (property value)
      (let ((patches (set-label-style state property value)))
        (values (apply-state-patches state (list patches)) nil)))
    
    (:set-for (target-id)
      (let ((patches (set-label-target state target-id)))
        (values (apply-state-patches state (list patches)) nil)))
    
    (:set-visibility (visible)
      (values (list* :visible visible state) nil))
    
    (:focus ()
      (if (getf state :focusable)
          (values state (list (list :focus-element :id (id-from-path id-path))))
          (values state nil)))
    
    (:blur ()
      (values state (list (list :blur-element :id (id-from-path id-path))))))
  
  (:view (state app-state id-path children)
    (declare (ignore app-state children))
    (let* ((component-id (id-from-path id-path))
           (text (getf state :text "Label"))
           (for-target (getf state :for))
           (text-color (getf state :text-color))
           (background-color (getf state :background-color))
           (font-weight (getf state :font-weight :normal))
           (font-style (getf state :font-style :normal))
           (text-decoration (getf state :text-decoration))
           (alignment (getf state :alignment :left))
           (wrap (getf state :wrap t))
           (truncate-mode (getf state :truncate))
           (visible (getf state :visible t))
           (focusable (getf state :focusable nil))
           (aria-role (getf state :aria-role :label))
           (accessibility-hint (getf state :accessibility-hint)))
      
      ;; Build style properties
      (let ((style-props nil))
        (when text-color
          (setf (getf style-props :color) text-color))
        (when background-color
          (setf (getf style-props :background-color) background-color))
        (when (not (eq font-weight :normal))
          (setf (getf style-props :font-weight) font-weight))
        (when (not (eq font-style :normal))
          (setf (getf style-props :font-style) font-style))
        (when text-decoration
          (setf (getf style-props :text-decoration) text-decoration))
        (when (not (eq alignment :left))
          (setf (getf style-props :text-align) alignment))
        (when (not wrap)
          (setf (getf style-props :white-space) :nowrap))
        (when truncate-mode
          (setf (getf style-props :text-overflow) truncate-mode))
        (when (not visible)
          (setf (getf style-props :display) :none)))
      
      ;; Generate base DSL
      (let ((label-dsl
             `(:label
               :id ,component-id
               :text ,text
               :class (:ui-label 
                      ,@(when for-target '(:has-target))
                      ,@(when focusable '(:focusable))
                      ,@(when (not visible) '(:hidden)))
               :style ,style-props
               :focusable ,focusable
               :aria-role ,aria-role
               ,@(when for-target `(:for ,for-target))
               ,@(when accessibility-hint `(:aria-label ,accessibility-hint)))))
        
        ;; Validate and expand the DSL
        (validate-base-dsl label-dsl)
        (expand-base-dsl label-dsl)))))

;;;--------------------------------------------------------------
;;; Contract-Enforced Functions for Direct Use
;;;--------------------------------------------------------------

(defupdate-hybrid label-enhanced-update (message model)
    :message-type nil :prefer-typed nil
  "Enhanced label update function for direct use"
  
  (let ((msg-type (if (listp message) (first message) message))
        (msg-data (when (listp message) (rest message))))
    
    (case msg-type
      (:set-text
       (let ((new-text (if (listp message) (getf msg-data :text) message)))
         (when (stringp new-text)
           (let ((patches (update-label-text model new-text)))
             (values (apply-state-patches model (list patches)) nil)))))
      
      (:set-style
       (let ((property (getf msg-data :property))
             (value (getf msg-data :value)))
         (when (and property value)
           (let ((patches (set-label-style model property value)))
             (values (apply-state-patches model (list patches)) nil)))))
      
      (:set-for
       (let ((target (getf msg-data :target)))
         (let ((patches (set-label-target model target)))
           (values (apply-state-patches model (list patches)) nil))))
      
      (t (values nil nil)))))

(defview label-enhanced-view (model)
  "Enhanced label view function for direct use"
  
  (let* ((text (getf model :text "Label"))
         (component-id (getf model :id :label))
         (for-target (getf model :for))
         (style-props (build-label-style-props model))
         (classes (build-label-classes model)))
    
    ;; Generate and validate base DSL
    (let ((label-dsl
           `(:label
             :id ,component-id
             :text ,text
             :class ,classes
             :style ,style-props
             :focusable ,(getf model :focusable nil)
             :aria-role ,(getf model :aria-role :label)
             ,@(when for-target `(:for ,for-target))
             ,@(when (getf model :accessibility-hint)
                 `(:aria-label ,(getf model :accessibility-hint))))))
      
      (validate-base-dsl label-dsl)
      label-dsl)))

;;;--------------------------------------------------------------
;;; Helper Functions
;;;--------------------------------------------------------------

(defun build-label-style-props (model)
  "Builds style properties from label state"
  (let ((style-props nil))
    (when (getf model :text-color)
      (setf (getf style-props :color) (getf model :text-color)))
    (when (getf model :background-color)
      (setf (getf style-props :background-color) (getf model :background-color)))
    (when (not (eq (getf model :font-weight :normal) :normal))
      (setf (getf style-props :font-weight) (getf model :font-weight)))
    (when (not (eq (getf model :font-style :normal) :normal))
      (setf (getf style-props :font-style) (getf model :font-style)))
    (when (getf model :text-decoration)
      (setf (getf style-props :text-decoration) (getf model :text-decoration)))
    (when (not (eq (getf model :alignment :left) :left))
      (setf (getf style-props :text-align) (getf model :alignment)))
    (when (not (getf model :wrap t))
      (setf (getf style-props :white-space) :nowrap))
    (when (getf model :truncate)
      (setf (getf style-props :text-overflow) (getf model :truncate)))
    (when (not (getf model :visible t))
      (setf (getf style-props :display) :none))
    style-props))

(defun build-label-classes (model)
  "Builds CSS classes from label state"
  (let ((classes '(:ui-label)))
    (when (getf model :for)
      (push :has-target classes))
    (when (getf model :focusable)
      (push :focusable classes))
    (when (not (getf model :visible t))
      (push :hidden classes))
    (when (eq (getf model :font-weight) :bold)
      (push :bold classes))
    (when (eq (getf model :font-style) :italic)
      (push :italic classes))
    (nreverse classes)))

;;;--------------------------------------------------------------
;;; Legacy Compatibility
;;;--------------------------------------------------------------

;; Legacy label class for compatibility
(defclass label (label-enhanced)
  ()
  (:documentation "Legacy label compatibility class"))

(defun make-label-enhanced (&key id text for style)
  "Creates a new enhanced label instance"
  (make-instance 'label-enhanced :id id :text text :for for :style style))

;; Legacy factory function
(defun make-label (&key id text for)
  "Legacy label factory function"
  (make-label-enhanced :id id :text text :for for))

;;;--------------------------------------------------------------
;;; Label Utilities
;;;--------------------------------------------------------------

(defun label-text-metrics (label-state)
  "Calculates text metrics for layout purposes"
  (let ((text (getf label-state :text))
        (wrap (getf label-state :wrap t)))
    (list :text-length (length text)
          :estimated-width (if wrap 
                             :flexible 
                             (length text))
          :estimated-height (if wrap 
                              :flexible
                              1)
          :requires-wrapping wrap)))

(defun format-label-for-display (label-state max-width)
  "Formats label text for display within width constraints"
  (let ((text (getf label-state :text))
        (wrap (getf label-state :wrap t))
        (truncate-mode (getf label-state :truncate)))
    
    (cond
      ;; No width constraint
      ((null max-width) text)
      
      ;; Text fits within width
      ((<= (length text) max-width) text)
      
      ;; Wrapping enabled
      (wrap (split-text-for-wrapping text max-width))
      
      ;; Truncation enabled
      (truncate-mode (truncate-text text max-width truncate-mode))
      
      ;; Default: clip text
      (t (subseq text 0 (min (length text) max-width))))))

(defun split-label-words (text)
  "Split TEXT on spaces without requiring the optional SPLIT-SEQUENCE system."
  (let ((words nil)
        (start 0))
    (loop for pos = (position #\Space text :start start)
          do (push (subseq text start pos) words)
          while pos
          do (setf start (1+ pos)))
    (nreverse words)))

(defun split-text-for-wrapping (text max-width)
  "Splits text into lines for wrapping"
  (let ((words (split-label-words text))
        (lines nil)
        (current-line ""))
    
    (dolist (word words)
      (let ((test-line (if (string= current-line "")
                          word
                          (concatenate 'string current-line " " word))))
        (if (<= (length test-line) max-width)
            (setf current-line test-line)
            (progn
              (when (not (string= current-line ""))
                (push current-line lines))
              (setf current-line word)))))
    
    (when (not (string= current-line ""))
      (push current-line lines))
    
    (nreverse lines)))

(defun truncate-text (text max-width mode)
  "Truncates text according to the specified mode"
  (case mode
    (:ellipsis 
     (if (> (length text) max-width)
         (concatenate 'string 
                     (subseq text 0 (max 0 (- max-width 3)))
                     "...")
         text))
    (:clip
     (subseq text 0 (min (length text) max-width)))
    (t text)))

;;;--------------------------------------------------------------
;;; Development and Debugging Support
;;;--------------------------------------------------------------

(defun describe-label-state (label-state &optional stream)
  "Return detailed information about LABEL-STATE as a string.
When STREAM is non-NIL, also write the description to that stream."
  (let ((description
          (with-output-to-string (out)
            (format out "~&Label State:~%")
            (format out "  Text: '~A'~%" (getf label-state :text))
            (format out "  For: ~A~%" (getf label-state :for))
            (format out "  Style: ~A~%" (build-label-style-props label-state))
            (format out "  Classes: ~A~%" (build-label-classes label-state))
            (format out "  Visible: ~A~%" (getf label-state :visible))
            (format out "  Focusable: ~A~%" (getf label-state :focusable))
            (format out "  Accessibility: role=~A, hint='~A'~%"
                    (getf label-state :aria-role)
                    (getf label-state :accessibility-hint)))))
    (when stream
      (write-string description stream))
    description))

(defun validate-label-accessibility (label-state)
  "Validates label accessibility properties"
  (let ((issues nil))
    
    ;; Check for empty text
    (when (or (null (getf label-state :text))
             (string= (getf label-state :text) ""))
      (push "Label has empty text" issues))
    
    ;; Check for target association
    (when (and (getf label-state :for)
              (not (or (keywordp (getf label-state :for))
                      (stringp (getf label-state :for)))))
      (push "Label :for attribute is not a valid identifier" issues))
    
    ;; Check role
    (unless (getf label-state :aria-role)
      (push "Label missing aria-role" issues))
    
    ;; Return issues or t if valid
    (if issues
        issues
        t)))
