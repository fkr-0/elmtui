;;;===============================================================
;;; File: src/view/core.lisp
;;; View Definition, UI Node & Composition DSL
(uiop:define-package :elmtui.view.core
  (:use :cl)
  ;; (:import-from :elmtui.view.layout
  ;;               :layout-vbox :layout-hbox)
  (:import-from :elmtui.view.api
   #:ui-node-p
                :ui-node-type :ui-node-props :ui-node-children)
  (:export
   ;; Core Types
   :ui-node :ui-node-p :make-ui-node :copy-ui-node

   ;; View Definition
   :defview :with-view-context
   ;; Node Creation DSL
   :container :text :vbox :hbox :widget
   ;; Composition & Updates
   :merge-props :update-props :update-children
   :with-props :with-children
   ;; Dynamic Updates
   :view-diff :apply-diff
   ;; Accessibility
   :with-aria :accessible-p
   ;; Properties
   :get-prop :set-prop :has-prop-p :remove-prop))
(in-package :elmtui.view.core)

;;;-----------------------------------------------------------------------------
;;; UI Node Definition & Operations
;;;-----------------------------------------------------------------------------

(defclass ui-node ()
  ((type :initarg :type :accessor ui-node-type :initform 'base :type symbol)
   (props :initarg :props :accessor ui-node-props :initform nil :type list)
   (children :initarg :children :accessor ui-node-children :initform nil :type list))
  (:documentation "Intermediate tree node: type, props, children.
    Contract: type (:text|:container|:vbox|:hbox|:widget), props plist, children list."))

(defmethod ui-node-p ((n ui-node)) t)
;; Define the predicate function


(defun make-ui-node (&key type props children)
  "Create a new ui-node with validation."
  (check-type type symbol)
  (check-type props list)
  (check-type children list)
  (assert (evenp (length props)) (props) "Props must be a valid property list")
  ;; Ensure ui-node-p is defined before this assertion runs
  (assert (every #'ui-node-p children) (children) (format nil "Children must be ui-nodes: ~A~%" children))
  ;; Use make-instance instead of undefined %make-ui-node
  (make-instance 'ui-node :type type :props props :children children))

(defun copy-ui-node (node &key type props children)
  "Create a copy of NODE with optional overrides."
  (make-ui-node
   :type (or type (ui-node-type node))
   :props (or props (copy-list (ui-node-props node)))
   :children (or children (copy-list (ui-node-children node)))))

(defmethod ui-node-type ((object list))
  (error "ui-node-type was called with a list as an argument: ~S.
This function expects a single ui-node instance.
Please check the call site." object))

;;;-----------------------------------------------------------------------------
;;; Property Operations
;;;-----------------------------------------------------------------------------

(defun get-prop (node key &optional default)
  "Get property value from node's props."
  (getf (ui-node-props node) key default))

(defun set-prop (node key value)
  "Set property value in node's props, returning a new node."
  (let ((new-props (copy-list (ui-node-props node))))
    (setf (getf new-props key) value)
    (copy-ui-node node :props new-props)))

(defun has-prop-p (node key)
  "Check if node has the specified property."
  (and (member key (ui-node-props node)) t))

(defun remove-prop (node key)
  "Remove property from node's props, returning a new node."
  (let ((new-props (copy-list (ui-node-props node))))
    (remf new-props key)
    (copy-ui-node node :props new-props)))

(defun merge-props (base-props &rest prop-lists)
  "Merge multiple property lists, later values override earlier ones."
  (loop with result = (copy-list base-props)
        for props in prop-lists do
          (loop for (key value) on props by #'cddr
                do (setf (getf result key) value))
        finally (return result)))

;;;-----------------------------------------------------------------------------
;;; Node Creation DSL
;;;-----------------------------------------------------------------------------

;; Define the special variable used by with-view-context
(defvar *default-props* nil
  "Dynamically bound variable holding default properties for node creation.")

(defmacro with-view-context ((&key props) &body body)
  "Establish a view context with default properties."
  `(let ((*default-props* ,(or props '(list))))
     (declare (special *default-props*))
     ,@body))

(defmacro define-node-creator (name type)
  "Define a function to create a node of TYPE with given props and children."
  `(defun ,name (&rest args &key props &allow-other-keys)
     (let* ((children (loop for arg in args
                            when (and (not (keywordp arg))
                                      (not (and (car args) (keywordp (car args)))))
                              collect arg))
            (explicit-props (loop for (key val) on args by #'cddr
                                  when (and (keywordp key) (not (eq key :props)))
                                    nconc (list key val)))
            (final-props (merge-props
                          (or (and (boundp '*default-props*) *default-props*) nil)
                          props
                          explicit-props)))
       (make-ui-node :type ,type
                     :props final-props
                     :children children))))

;; Define standard node creators
(define-node-creator container :container)
(define-node-creator text :text)
(define-node-creator vbox :vbox)
(define-node-creator hbox :hbox)
(define-node-creator widget :widget)

;;;-----------------------------------------------------------------------------
;;; View Definition & Composition
;;;-----------------------------------------------------------------------------

(defmacro defview (name args &body body)
  "Define a pure view function: Model → UiTree.
   Contract: view returns a tree of ui-node objects."
  (let ((doc (when (stringp (car body)) (pop body))))
    `(defun ,name ,args
       ,@(when doc (list doc))
       (with-view-context ()
         ,@body))))

(defun update-props (node fn)
  "Update node's props using function FN, returning a new node."
  (copy-ui-node node :props (funcall fn (ui-node-props node))))

(defun update-children (node fn)
  "Update node's children using function FN, returning a new node."
  (copy-ui-node node :children (funcall fn (ui-node-children node))))

(defmacro with-props ((&rest props) node)
  "Add or override properties on NODE."
  `(update-props ,node
    (lambda (current-props)
      (merge-props current-props (list ,@props)))))

(defmacro with-children (children node)
  "Set children of NODE."
  `(update-children ,node (constantly ,children)))

;;;-----------------------------------------------------------------------------
;;; Dynamic View Updates
;;;-----------------------------------------------------------------------------

(defun view-diff (old-node new-node)
  "Calculate the minimal set of changes between views.
   Returns a function that can transform old-node into new-node."
  ;; TODO: Implement intelligent diffing algorithm
  (declare (ignore old-node))
  (lambda (target)
    (declare (ignore target))
    new-node))

(defun apply-diff (node diff)
  "Apply a view diff to a node."
  (funcall diff node))

;;;-----------------------------------------------------------------------------
;;; Accessibility Support
;;;-----------------------------------------------------------------------------

(defun accessible-p (node)
  "Check if node has required accessibility attributes."
  (or (get-prop node :aria-label)
      (get-prop node :aria-labelledby)
      (get-prop node :aria-describedby)))

(defmacro with-aria ((&rest aria-props) node)
  "Add ARIA attributes to NODE."
  (let ((aria-plist
          (loop for (key value) on aria-props by #'cddr
                collect (intern (format nil "ARIA-~A" key) :keyword)
                collect value)))
    `(with-props ,aria-plist ,node)))
