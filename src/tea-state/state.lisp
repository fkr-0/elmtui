(uiop:define-package :elmtui.tea-state.state
  (:use :cl)
  (:import-from :elmtui.utils #:get-path #:set-path #:as
                #:copy-hash-table)
  (:export #:application-state
           #:make-application-state
           #:application-state-p
           #:application-state-data
           #:application-state-lock
           #:application-state-log
           #:application-state-history
           #:application-state-undone
           #:application-state-version
           #:application-state-observers
           #:application-state-p
           #:tx
           #:make-tx
           #:tx-p
           #:tx-id
           #:state-ref
           #:tx-name
           #:tx-changes
           #:make-state
           #:get-state))

(in-package :elmtui.tea-state.state)


;; ────────────────────────────────  Application‑state  ─────────────────────────

(defstruct application-state
  (data (make-hash-table :test 'equal))
  (lock (sb-thread:make-mutex))
  (log nil) (history nil) (undone nil) (version 0) (observers nil))

;; Deep copy helper (unchanged)
(defun deep-copy-application-state (app)
  (make-application-state
   :data (copy-hash-table (application-state-data app))
   :lock (sb-thread:make-mutex)
   :log (copy-list (application-state-log app))
   :history (copy-list (application-state-history app))
   :undone (copy-list (application-state-undone app))
   :observers (copy-list (application-state-observers app))))

;; (defmethod state-ref :before (app  key  &optional default)
;;   (format t "State-ref called with app: ~A, key: ~A, default: ~A~%" app key default))

;; (defmethod state-ref ((app list) (key list) &optional default)
;;   "Retrieve the value for KEY from the application state APP."
;;   (if (= 0 (length key))
;;       app
;;       (let ((inner-layer (state-ref app (car key) default)))
;;         (if (= 1 (length key))
;;             inner-layer
;;             (state-ref inner-layer (cdr key) default)))))

;; (state-ref
;;  (state-ref app (car key) default)
;;  (cdr key) default)))))
;; (defmethod state-ref ((app application-state) (key list) &optional default)
;;   "Retrieve the value for KEY from the application state APP."
;;   (if (= 0 (length key))
;;       (application-state-data app)
;;       (if (= 1 (length key))
;;           (state-ref app (car key) default)
;;           (state-ref
;;            (state-ref app (car key) default)
;;            (cdr key) default))))

;; (defmethod state-ref ((app application-state) key &optional default)
;;   "Retrieve the value for KEY from the application state APP."
;;   (get-state app key default))

;; (defmethod state-ref ((app list) (key null) &optional default)
;;   "Retrieve the value for KEY from the application state APP."
;;   (format t "NULLKEY")
;;   app)

;; (defmethod state-ref ((app list) key &optional default)
;;   "Retrieve the value for KEY from the application state APP."
;;   (format t "App: ~A" app)
;;   (get-path key app default))

;; (defmethod (setf state-ref) ((app application-state) key value)
;;   "Set the value for KEY in the application state APP to VALUE."
;;   (set-path key value (application-state-data app)))

;; (defmethod (setf state-ref) ((app hash-table) key value)
;;   "Set the value for KEY in the application state APP to VALUE."
;;   (set-path key value app))
                                        ; (defun application-state-p (obj)
;;   "Check if OBJ is an APPLICATION-STATE."
;;   (typep obj 'application-state))
;; ───────────────────────────────  Public accessors  ───────────────────────────

(defgeneric state-ref (place key &optional default))
;; (defgeneric (setf state-ref) (value place key))

(defmethod state-ref ((state application-state) (key t) &optional default)
  (get-path key (application-state-data state) default))

(defmethod state-ref ((state hash-table) (key t) &optional default)
  (get-path key state default))

(defmethod state-ref ((state list) (key t) &optional default)
  (get-path key state default))
(defmethod (setf state-ref) (value (state application-state) (key t))
  "Atomically store VALUE at KEY inside STATE and log the change.
   The change log stores (KEY OLD NEW) triples in most‑recent‑first order.

   This method is thread-safe and uses a mutex to ensure atomicity.

   Arguments:
    - VALUE: The new value to store.
    - STATE: The application state to modify.
    - KEY: The key at which to store the value.

    Returns the VALUE just stored.

    If the KEY does not exist, it is created with the VALUE.

    Example:
    (setf (state-ref my-app-state :counter) 42) => 42"

  (sb-thread:with-mutex ((application-state-lock state))
    (let* ((data   (application-state-data state))
           (old    (get-path key data :not-present))
           (data*  (set-path data key value)))
      (setf (application-state-data state) data*)
      (push (list key old value) (application-state-log state))
      (incf (application-state-version state))
      value)))                                        ; return the value just stored

(defmethod get-path (path (data application-state) &optional default)
  (or (if (null path)
          (application-state-data data)
          (get-path path (application-state-data data) default)
          ;; (let ((next
          ;;         (get-path path (application-state-data data) default)))
          ;;   (if (eq next default)
          ;;       default
          ;;       (get-path (cdr path) next default)))
          )
      default))
;; (defmethod get-path (path (state application-state) &optional default)
;;   "Gets value at PATH from application-state."
;;   (let ((data (application-state-data state)))
;;     (get-path path data default)))
(defmethod get-path ((path t) (state application-state) &optional default)
  "Gets value at PATH from application-state."
  (let ((data (application-state-data state)))
    (get-path path data default)))
(defmethod get-path ((path list) (state application-state) &optional default)
  "Gets value at PATH from application-state."
  (let ((data (application-state-data state)))
    (get-path path data default)))

(defun get-state (app key &optional (default nil))
  (state-ref app key default))
;;; Convenience wrapper that now delegates to the new logging setter
(defun state-set (state key new)
  "Shorthand for `(setf (state-ref STATE KEY) NEW)`."
  (setf (state-ref state key) new))
;; (defmethod (setf state-ref) (value (state application-state) (key t))
;;   (setf (application-state-data state)
;;         (set-path (application-state-data state) key value)))

;; (defmethod (setf state-ref) (value (state hash-table) (key t))
;;   (set-path state key value))

;; (defmethod (setf state-ref) (value (state list) (key t))
;;   (set-path state key value))

;; Atomic setter that logs the change (same semantics as original)
;; (defun state-set (app key new)
;;   (sb-thread:with-mutex ((application-state-lock app))
;;     (let ((old (state-ref app key :not-present)))
;;       (setf (state-ref app key) new)
;;       (push (list key old new) (application-state-log app))
;;       new)))




(defstruct tx
  id
  name
  changes)  ; list of (key old new)


;;;── Accessor ─────────────────────────────────────────────────
;; (defun get-state (app key &optional default)
;;   (gethash key (application-state-data app) default))

;;;── Factory ──────────────────────────────────────────────────
(defmethod make-state ((initial hash-table))
  (let ((app (make-application-state)))
    (when initial
      (loop for k being the hash-keys of initial using (hash-value v)
            do (setf (gethash k (application-state-data app)) v)))
    app))
(defmethod make-state ((initial null))
  (make-application-state
   :data
   (make-hash-table :test 'equal)))

(defmethod make-state ((initial list))
  (make-application-state :data
                          (as :hash-table initial :test 'equal)))
;; (defmethod get-path (path (state application-state) &optional default)
;;   "Gets value at PATH from application-state."
;;   (let ((data (application-state-data state)))
;;     (get-path path data default)))
