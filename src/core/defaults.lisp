;;;===================================================================
;;; File: src/core/defaults.lisp
;;; Centralized Default Value Management for Elmtui
;;;===================================================================
;;;
;;; Provides a unified system for managing default values across all
;;; components, backends, and subsystems. Eliminates hardcoded values
;;; and provides type-safe, documented defaults with fallback mechanisms.

(uiop:define-package :elmtui.core.defaults
  (:use :cl)
  (:import-from :alexandria #:when-let)
  (:export #:*default-registry*
    #:register-default
    #:get-default
    #:get-default-or-error
    #:with-defaults
    #:make-default-context
    #:validate-default-value
    #:default-registry
    #:default-spec
    #:default-value
    #:default-type
    #:default-documentation
    #:default-fallback
    #:default-validator))

(in-package :elmtui.core.defaults)

;;;===================================================================
;;; Default Value Registry
;;;===================================================================

(defstruct default-spec
  "Specification for a default value with metadata."
  (key nil :type (or symbol keyword) :read-only t)
  (value nil :type t :read-only nil)
  (type t :type (or symbol list) :read-only t)
  (documentation "" :type string :read-only t)
  (fallback nil :type (or null t) :read-only t)
  (validator nil :type (or null function) :read-only t)
  (category :general :type keyword :read-only t)
  (source nil :type (or null string) :read-only t))

(defvar *default-registry* (make-hash-table :test 'equal)
  "Global registry of default values for all Elmtui components.")
(defmacro register-default (key value &key
                             (type t)
                             documentation
                             fallback
                             validator
                             (category :general)
                             source)
  "Macro version of register-default for compile-time type safety.

KEY: Symbol or keyword identifying the default
VALUE: The default value
TYPE: Expected type for type checking (evaluated at macroexpansion)
DOCUMENTATION: String describing the default
FALLBACK: Fallback value if primary value is invalid
VALIDATOR: Function to validate the value
CATEGORY: Keyword for grouping related defaults
SOURCE: Source file or system where this default originated"
  `(let ((existing (gethash ,key *default-registry*)))
     (when (and existing (not (equal (default-spec-value existing) ,value)))
       (warn "Overriding existing default for key ~A (old: ~A, new: ~A)"
         ,key (default-spec-value existing) ,value))
     (let ((spec (make-default-spec :key ,key
                   :value ,value
                   :type ',type
                   :documentation (or ,documentation "")
                   :fallback ,fallback
                   :validator ,validator
                   :category ,category
                   :source ,source)))
       (setf (gethash ,key *default-registry*) spec)
       spec)))


;; (defun register-default (key value &key
;;                           (type t)
;;                           documentation
;;                           fallback
;;                           validator
;;                           (category :general)
;;                           source)
;;   "Register a default value with optional validation and metadata.

;;    KEY: Symbol or keyword identifying the default
;;    VALUE: The default value
;;    TYPE: Expected type for type checking
;;    DOCUMENTATION: String describing the default
;;    FALLBACK: Fallback value if primary value is invalid
;;    VALIDATOR: Function to validate the value
;;    CATEGORY: Keyword for grouping related defaults
;;    SOURCE: Source file or system where this default originated"

;;   (when (gethash key *default-registry*)
;;     (warn "Overriding existing default for key ~A (old: ~A, new: ~A)"
;;       key (default-spec-value (gethash key *default-registry*)) value))

;;   (let ((spec (make-default-spec :key key
;;                 :value value
;;                 :type type
;;                 :documentation (or documentation "")
;;                 :fallback fallback
;;                 :validator validator
;;                 :category category
;;                 :source source)))
;;     (setf (gethash key *default-registry*) spec)
;;     spec))

(defun get-default (key &optional (error-p nil))
  "Get a default value by key. If ERROR-P is true, signal error for missing defaults."
  (let ((spec (gethash key *default-registry*)))
    (cond
      (spec
        (validate-and-return-default spec))
      (error-p
        (error "No default registered for key ~A. Available keys: ~{~A~^, ~}"
          key (hash-table-keys *default-registry*)))
      (t nil))))

(defun get-default-or-error (key)
  "Get a default value, signaling an error if not found."
  (get-default key t))

(defun validate-and-return-default (spec)
  "Validate and return the value from a default specification."
  (handler-case
    (validate-default-value spec)
    (error (e)
      (let ((fallback (default-spec-fallback spec)))
        (if fallback
          (progn
            (warn "Default validation failed for ~A: ~A. Using fallback: ~A"
              (default-spec-key spec) e fallback)
            fallback)
          (error e))))))

(defun validate-default-value (spec)
  "Validate that a default specification is valid."
  (let ((value (default-spec-value spec))
         (type (default-spec-type spec))
         (validator (default-spec-validator spec))
         (key (default-spec-key spec)))

    ;; Type validation
    (unless (or (eq type t) (typep value type))
      (error "Default value ~A has wrong type ~A for key ~A (expected ~A)"
        value (type-of value) key type))

    ;; Custom validation
    (when validator
      (unless (funcall validator value)
        (error "Custom validation failed for default ~A = ~A for key ~A"
          key value key)))

    value))

;;;===================================================================
;;; Built-in Defaults
;;;===================================================================

;; Colors
(register-default :foreground-color :white
  :type keyword
  :documentation "Default foreground color for terminal output"
  :fallback :white
  :category :colors
  :source "platform/api.lisp")

(register-default :background-color :black
  :type keyword
  :documentation "Default background color for terminal output"
  :fallback :black
  :category :colors
  :source "platform/api.lisp")

(register-default :border-color :white
  :type keyword
  :documentation "Default border color for components"
  :fallback :white
  :category :colors
  :source "ui/widgets/")

;; Dimensions
(register-default :terminal-width 80
  :type integer
  :documentation "Default terminal width in characters"
  :fallback 80
  :validator (lambda (x) (and (integerp x) (> x 0)))
  :category :dimensions
  :source "platform/api.lisp")

(register-default :terminal-height 24
  :type integer
  :documentation "Default terminal height in characters"
  :fallback 24
  :validator (lambda (x) (and (integerp x) (> x 0)))
  :category :dimensions
  :source "platform/api.lisp")

(register-default :component-width 40
  :type integer
  :documentation "Default width for UI components"
  :fallback 40
  :validator (lambda (x) (and (integerp x) (> x 0)))
  :category :dimensions
  :source "ui/")

(register-default :component-height 20
  :type integer
  :documentation "Default height for UI components"
  :fallback 20
  :validator (lambda (x) (and (integerp x) (> x 0)))
  :category :dimensions
  :source "ui/")

;; UI Behavior
(register-default :show-scrollbar t
  :type boolean
  :documentation "Whether scrollbars are shown by default"
  :fallback t
  :category :ui-behavior
  :source "ui/widgets/scroll-panel.lisp")

(register-default :focusable t
  :type boolean
  :documentation "Whether components are focusable by default"
  :fallback t
  :category :ui-behavior
  :source "ui/")

(register-default :border-style :single
  :type keyword
  :documentation "Default border style (:none, :single, :double)"
  :fallback :single
  :validator (lambda (x) (member x '(:none :single :double)))
  :category :ui-behavior
  :source "ui/widgets/")

;; Text
(register-default :button-label "Button"
  :type string
  :documentation "Default button label text"
  :fallback "Button"
  :category :text
  :source "ui/widgets/button.lisp")

(register-default :label-text "Label"
  :type string
  :documentation "Default label text"
  :fallback "Label"
  :category :text
  :source "ui/widgets/label.lisp")

;; Performance
(register-default :input-timeout 0.1
  :type number
  :documentation "Default timeout for input operations in seconds"
  :fallback 0.1
  :validator (lambda (x) (and (numberp x) (>= x 0)))
  :category :performance
  :source "platform/input.lisp")

(register-default :render-cache-size 1000
  :type integer
  :documentation "Default size of render cache"
  :fallback 1000
  :validator (lambda (x) (and (integerp x) (> x 0)))
  :category :performance
  :source "rendering/cache.lisp")

;;;===================================================================
;;; Context Management
;;;===================================================================

(defstruct (default-context (:constructor %make-default-context))
  "Context for managing scoped defaults."
  (overrides (make-hash-table :test 'equal) :type hash-table :read-only t)
  (parent nil :type (or null default-context) :read-only t)
  (frozen-p nil :type boolean :read-only nil))

(defun make-default-context (&optional parent)
  "Create a new default context, optionally inheriting from parent."
  (%make-default-context :parent parent))

(defmacro with-defaults (overrides context-or-parent &body body)
  "Execute BODY with overridden defaults."
  `(let* ((parent-context (if (default-context-p ,context-or-parent)
                            context-or-parent
                            (make-default-context ,context-or-parent)))
           (new-context (make-default-context parent-context))
           (old-registry *default-registry*))
     ;; Apply overrides to new context
     (loop for (key value) on ,overrides by #'cddr do
       (setf (gethash key (default-context-overrides new-context)) value))

     (unwind-protect
       (progn
         ;; Temporarily use context-aware registry
         (setf *default-registry*
           (make-context-aware-registry new-context old-registry))
         (progn ,@body))
       ;; Restore original registry
       (setf *default-registry* old-registry))))

(defun make-context-aware-registry (context base-registry)
  "Create a registry that respects context overrides."
  (let ((context-registry (make-hash-table :test 'equal)))
    ;; Copy base registry
    (maphash (lambda (key spec)
               (setf (gethash key context-registry) spec))
      base-registry)

    ;; Apply context overrides
    (labels ((apply-override (ctx)
               (when ctx
                 (maphash (lambda (key value)
                            (let ((spec (gethash key context-registry)))
                              (setf (gethash key context-registry)
                                (make-default-spec
                                  :key key
                                  :value value
                                  :type (when spec (default-spec-type spec))
                                  :documentation (when spec
                                                   (format nil "~A (overridden)"
                                                     (default-spec-documentation spec)))
                                  :fallback (when spec (default-spec-fallback spec))
                                  :validator (when spec (default-spec-validator spec))
                                  :category (when spec (default-spec-category spec))
                                  :source "context-override"))))
                   (default-context-overrides ctx))
                 (apply-override (default-context-parent ctx)))))
      (apply-override context))

    context-registry))

;;;===================================================================
;;; Utility Functions
;;;===================================================================

(defun hash-table-keys (hash-table)
  "Return a list of keys from a hash table."
  (loop for key being the hash-keys of hash-table collect key))

(defun list-defaults-by-category (category)
  "List all defaults in a specific category."
  (loop for spec being the hash-values of *default-registry*
    when (eq (default-spec-category spec) category)
    collect spec))

(defun list-all-defaults ()
  "List all registered defaults with their metadata."
  (loop for spec being the hash-values of *default-registry* collect spec))

(defun validate-all-defaults ()
  "Validate all registered defaults and report any issues."
  (let ((issues '()))
    (maphash (lambda (key spec)
               (handler-case
                 (validate-default-value spec)
                 (error (e)
                   (push (list key e) issues))))
      *default-registry*)
    (if issues
      (progn
        (format t "Found ~A default validation issues:~%" (length issues))
        (dolist (issue issues)
          (format t "  ~A: ~A~%" (first issue) (second issue))))
      (format t "All defaults are valid~%"))
    (null issues)))

;;;===================================================================
;;; Convenience Functions
;;;===================================================================

(defmacro define-default (key value &rest options)
  "Convenience macro for defining defaults with better syntax."
  `(register-default ',key ,value ,@options))

(defun get-color-default (color-type &key (category :colors))
  "Get a color-related default value."
  (declare (ignore category))
  (get-default
    (if (keywordp color-type)
      color-type (intern (string-upcase color-type) :keyword))))

(defun get-dimension-default (dimension-type &key (category :dimensions))
  "Get a dimension-related default value."
  (declare (ignore category))
  (get-default
    (if (keywordp dimension-type)
      dimension-type (intern (string-upcase dimension-type) :keyword))))

(defun ensure-default-value (key &optional fallback)
  "Ensure a default value exists, creating a basic one if necessary."
  (or (get-default key)
    (when fallback
      (register-default key fallback :documentation (format nil "Auto-generated default for ~A" key))
      fallback)))

;;;===================================================================
;;; Integration Examples
;;;===================================================================

#|
;; Using defaults in components:
(defun create-button (&key label (color (get-color-default :foreground-color)))
(list :type :button :label (or label (get-default :button-label)) :color color))

;; Using scoped defaults:
(with-defaults ((:component-width 60) (:button-label "Submit"))
(create-button))  ;; Uses overridden width and label

;; Registering custom defaults:
(define-default :my-component-bg :blue
:type keyword
:category :colors
:documentation "Background color for my custom component"
:validator (lambda (x) (member x '(:blue :red :green))))
|#
