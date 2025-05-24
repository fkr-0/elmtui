;;; ───────────────────────── 5. Stylable  ─────────────────────────────────
(uiop:define-package :elmtui.style-lib.stylable
  (:use :cl :elmtui.style-lib.util :elmtui.style-lib.api :elmtui.style-lib.style-set)
  (:import-from :elmtui.style-lib.style-set
   :style-set-styles :set-style :copy-set)
  (:import-from :elmtui.style-lib.api :dirty-p
                :stylable :stylable-id :classes :parents-of)

  (:export :stylable :styles :stylable-id :classes  :dirty :dirty-p))

(in-package :elmtui.style-lib.stylable)

;; (defclass stylable-impl (stylable)
;;   ((sid     :initarg :id      :accessor stylable-id)
;;    (classes :initarg :classes :initform nil :accessor classes)
;;    (styles  :accessor styles :initform (copy-set elmtui.style-lib.style-set::*default-style-set*))
;;    (parents :initarg :parents :initform nil :accessor impl-parents-of)
;;    (dirty   :initform t :accessor dirty)))

;; (defmethod parents-of ((s stylable))
;;   "Return the parents of the stylable object S."
;;   (impl-parents-of s)
;;   ;; (if (and (typep s 'stylable-impl) (not (null (impl-parents-of s))))
;;   ;;     (mapcar #'stylable-id (impl-parents-of s))
;;   ;;     nil)
;;   )
;; (defmethod (setf parents-of) ((s stylable) v)
;;   "Set the parents of the stylable object S to V."
;;   (setf (impl-parents-of s) v))
(defmethod dirty-p ((s stylable)) (dirty s))
