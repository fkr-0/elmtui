;;; ───────────────────────── 5. Stylable  ─────────────────────────────────
(uiop:define-package :elmtui.style-lib.stylable
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.api :elmtui.style-lib.style-set)
  (:import-from :elmtui.style-lib.style-set
   :style-set-styles :set-style :value-raw :copy-set)
  (:import-from :elmtui.style-lib.api :dirty-p
                :stylable :stylable-id :classes :parents-of)

  (:export :stylable :styles :stylable-id :classes :parents-of :dirty :dirty-p))

(in-package :elmtui.style-lib.stylable)

(defclass stylable-impl (elmtui.style-lib.api:stylable)
  ((sid     :initarg :id      :accessor stylable-id)
   (classes :initarg :classes :initform nil :accessor classes)
   (styles  :accessor styles :initform (copy-set elmtui.style-lib.style-set::*default-style-set*))
   (parents :initarg :parents :initform nil :accessor parents-of)
   (dirty   :initform t :accessor dirty)))

(defmethod dirty-p ((s stylable)) (dirty s))
