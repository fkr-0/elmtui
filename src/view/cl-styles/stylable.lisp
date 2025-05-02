;;; ───────────────────────── 5. Stylable  ─────────────────────────────────
(uiop:define-package :cl-styles.stylable
  (:use :cl :cl-styles.util :cl-styles.types :cl-styles.style-set)
  (:import-from :cl-styles.style-set
   :style-set-styles :set-style :value-raw :copy-set)
  (:import-from :cl-styles.types
   :stylable :stylable-id :classes :parents-of)

  (:export :stylable :styles :stylable-id :classes :parents-of :dirty :dirty-p))

(in-package :cl-styles.stylable)

(defclass stylable (cl-styles.types:stylable)
  ((sid     :initarg :id      :accessor stylable-id)
   (classes :initarg :classes :initform nil :accessor classes)
   (styles  :accessor styles :initform (copy-set cl-styles.style-set::*default-style-set*))
   (parents :initarg :parents :initform nil :accessor parents-of)
   (dirty   :initform t :accessor dirty)))

(defmethod dirty-p ((s stylable)) (dirty s))
