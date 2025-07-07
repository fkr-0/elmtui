;; == nested-path/src/path-utils.lisp =========================================
;;; Minimal “one-file library” – load it with  (load "path-utils.lisp")
;;; or drop it into ASDF/Quicklisp as you like.
;;; --------------------------------------------------------------------------
(uiop:define-package :elmtui.state.utils
  (:use :cl )
  ;; (:import-from :elmtui.statelib.observe ...) ; If needed

  ;; Define what this package EXPORTS. Since elmtui.state.api is the public interface,
  ;; this package might not need to export much, or it re-exports specific API symbols
  ;; if it provides the canonical implementation for them.
  ;; For now, assuming elmtui.state.api handles all public exports.
  ;; If elmtui.state defines functions that are part of the API, they should be exported there.
  (:export
   #:get-path #:set-path #:remove-path
   #:parse-plist-and-children))
(in-package :elmtui.state.utils)

;;; 1. Helpers ────────────────────────────────────────────────────────────────
(defun %alist-p (obj)
  "True when OBJ is a proper association list (every element is a dotted pair)."
  (and (listp obj)
       (every #'consp obj)))

(defun parse-plist-and-children (args)
 "Parses a list of arguments into a property list and a list of children."
 (let ((i (or (loop for i from 0 below (length args) by 2
                    unless (and (< (1+ i) (length args)) (keywordp (nth i args)))
                      return i)
              (length args))))
   (values (subseq args 0 i) (subseq args i))))

(defun %empty-container-p (obj)
  "Predicate used by REMOVE-PATH to decide whether to prune a branch."
  (typecase obj
    (hash-table (= (hash-table-count obj) 0))
    (list       (null obj))
    (t          nil)))

(defun %get-entry (container key default)
  (cond
    ((hash-table-p container)
     (multiple-value-bind (v foundp) (gethash key container)
       (if foundp v default)))

    ((listp container)
     (if (%alist-p container)                  ; alist
         (let ((pair (assoc key container)))
           (if pair (cdr pair) default))
         (getf container key default)))        ; plist

    (t default)))

(defun %set-entry (container key value)
  "Destructively insert KEY ⇒ VALUE in CONTAINER; return (possibly new) container."
  (when (null key)
    (error "SET-ENTRY: KEY cannot be NIL"))
  (cond
    ((hash-table-p container)
     (setf (gethash key container) value)
     container)

    ((listp container)
     (if (%alist-p container)
         ;; -------- alist ----------
         (let ((pair (assoc key container)))
           (if pair
               (setf (cdr pair) value)                     ; overwrite
               (if container
                   (nconc container (list (cons key value))) ; append
                   (setq container (list (cons key value))))) ; first pair
           container)
         ;; -------- plist ----------
         (progn
           (setf (getf container key) value)               ; handles nil, too
           container)))

    (t (error "SET-ENTRY: unsupported container type ~S" (type-of container)))))

(defun %remove-entry (container key)
  "Remove KEY (single level).  ⇒ two values: NEW-CONTAINER, REMOVEDP."
  (cond
    ((hash-table-p container)
     (values container (remhash key container)))           ; REMHASH returns flag

    ((listp container)
     (if (%alist-p container)
         ;; -------- alist ----------
         (let* ((before (length container))
                (new    (delete key container :key #'car :test #'eq :count 1)))
           (values new (/= before (length new))))
         ;; -------- plist ----------
         (let ((foundp (remf container key)))
           (values container foundp))))

    (t (values container nil))))                            ; unsupported → nothing

;;; 2. Public API ─────────────────────────────────────────────────────────────
(defun get-path (data path &optional (default nil))
  "Read value at PATH inside DATA; return DEFAULT if anything is missing.
   PATH may be a symbol/keyword (single level) or a proper list."
  (cond
    ((null path) data)

    ((symbolp path)
     (%get-entry data path default))

    ((consp path)
     (let ((next (%get-entry data (car path) default)))
       (if (eq next default)
           default
           (get-path next (cdr path) default))))

    (t default)))

(defun set-path (data path value &key (createp nil))
  "Return *updated* DATA with VALUE stored at PATH.
   When CREATEP is NIL and an intermediate key is missing, signals an error.

   NB: For plists/alists the call may return a *new* top-level list
       (needed when DATA was NIL).  Always use the returned value."
  (labels ((%ensure-child (container key)
             ;; Return child, and container (maybe changed if we had to create)
             (let ((child (%get-entry container key nil)))
               (cond
                 (child (values child container))
                 (createp
                  (let ((new-child (make-hash-table)))      ; default style
                    (values new-child (%set-entry container key new-child))))
                 (t
                  (error "Missing intermediate node ~A in PATH ~A (and :CREATEP NIL)"
                         key path))))))
    (cond
      ((symbolp path)                                       ; leaf
       (%set-entry data path value))

      ((consp path)
       (multiple-value-bind (child container*) (%ensure-child data (car path))
         (let* ((new-child (set-path child (cdr path) value :createp createp))
                (container** (if (eq child new-child)
                                 container*
                                 (%set-entry container* (car path) new-child))))
           container**)))

      (t (error "SET-PATH: invalid PATH ~S" path)))))

(defun remove-path (data path &key (prune-empty t))
  "Delete the entry at PATH.
   ⇒ two values: NEW-DATA  REMOVEDP   (boolean).
   When PRUNE-EMPTY is true, empty containers created by the deletion
   are recursively removed."
  (cond
    ;; leaf --------------------------------------------------------------
    ((symbolp path)
     (%remove-entry data path))

    ;; interior ----------------------------------------------------------
    ((consp path)
     (let* ((key   (car path))
            (rest  (cdr path))
            (child (%get-entry data key nil)))
       (if (null child)                                     ; nothing down there
           (values data nil)
           (multiple-value-bind (new-child removedp) (remove-path child rest
                                                                  :prune-empty prune-empty)
             (if (not removedp)                             ; nothing removed in branch
                 (values data nil)
                 (let* ((child-empty (%empty-container-p new-child))
                        (data* (cond
                                 ((and prune-empty child-empty)
                                  (car (%remove-entry data key))) ; drop branch
                                 (child-empty            ; keep empty shell
                                  (%set-entry data key (typecase child
                                                         (hash-table (make-hash-table))
                                                         (t nil)))
                                  )
                                 (t (%set-entry data key new-child)))))
                   (values data* t)))))))

    (t (values data nil))))
;; == end/path-utils.lisp =====================================================
