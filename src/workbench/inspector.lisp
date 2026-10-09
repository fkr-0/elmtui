(defpackage :elmtui.workbench.inspector
  (:use :cl)
  (:export :make-inspector-session :snapshot-image :inspect-object
           :register-object :record-diagnostic :inspector-session-generation
           :watch-variable :unwatch-variable :clear-watches :watched-variables
           :inspector-theme :make-inspector-theme :inspector-style
           :inspector-theme-section-title :inspector-theme-selected
           :inspector-theme-normal :inspector-theme-watch
           :inspector-theme-changed-watch :inspector-theme-unbound-watch
           :inspector-theme-diagnostic))
(in-package :elmtui.workbench.inspector)
(defstruct (inspector-session (:constructor %make-inspector-session))
  generation
  (cache (make-hash-table :test 'equal))
  (objects (make-hash-table))
  (watches (make-hash-table :test 'eq))
  watch-order
  (next-id 0)
  diagnostics
  (max-items 256)
  (max-depth 3)
  (max-length 12)
  (max-preview 100))
(defun make-inspector-session (&key (max-items 256) (max-depth 3) (max-length 12) (max-preview 100)) (%make-inspector-session :max-items (min 512 (max 1 max-items)) :max-depth (min 4 (max 0 max-depth)) :max-length (min 16 (max 1 max-length)) :max-preview (min 256 (max 1 max-preview))))
(defun %label (thing) (let ((type (type-of thing))) (if (symbolp type) (symbol-name type) "OBJECT")))
(defun %bounded-text (session value)
  (let* ((text (if (stringp value) value (princ-to-string value)))
         (limit (inspector-session-max-preview session)))
    (subseq text 0 (min (length text) limit))))
(defun %preview (session thing) (%bounded-text session (typecase thing (null "NIL") (string (if (> (length thing) (inspector-session-max-preview session)) (concatenate 'string (subseq thing 0 (inspector-session-max-preview session)) "...") (copy-seq thing))) (symbol (symbol-name thing)) (character (string thing)) (fixnum (write-to-string thing :escape nil :readably nil)) (number "#<NUMBER>") (cons "#<CONS>") (hash-table "#<HASH-TABLE>") (vector "#<VECTOR>") (t (concatenate 'string "#<" (%label thing) ">")))))
(defun register-object (session object) (when (>= (hash-table-count (inspector-session-objects session)) (inspector-session-max-items session)) (clrhash (inspector-session-objects session))) (let ((handle (incf (inspector-session-next-id session)))) (setf (gethash handle (inspector-session-objects session)) object) handle))
(defun %object-tree (session thing depth seen) (let ((head (list :type (%label thing) :preview (%preview session thing)))) (cond ((not (or (consp thing) (hash-table-p thing) (and (vectorp thing) (not (stringp thing))))) head) ((gethash thing seen) (append head (list :cycle t))) ((zerop depth) (append head (list :truncated t))) (t (setf (gethash thing seen) t) (append head (list :children (cond ((consp thing) (list (list :index :car :value (%object-tree session (car thing) (1- depth) seen)) (list :index :cdr :value (%object-tree session (cdr thing) (1- depth) seen)))) ((hash-table-p thing) (loop for key being the hash-keys of thing using (hash-value val) for i from 0 below (inspector-session-max-length session) collect (list :key (%object-tree session key (1- depth) seen) :value (%object-tree session val (1- depth) seen)))) (t (loop for x across thing for i from 0 below (inspector-session-max-length session) collect (list :index i :value (%object-tree session x (1- depth) seen)))))))))))
(defun inspect-object (session handle request-id &key (page 0) (page-size 25) depth) (multiple-value-bind (thing present) (gethash handle (inspector-session-objects session)) (if (not present) (list :kind :object-inspection :status :not-found :request-id request-id :handle handle) (let* ((d (if (and (integerp depth) (>= depth 0)) (min depth (inspector-session-max-depth session)) (inspector-session-max-depth session))) (tree (%object-tree session thing d (make-hash-table :test 'eq))) (children (getf tree :children)) (page (if (and (integerp page) (>= page 0)) page 0)) (size (min (inspector-session-max-length session) (max 1 (if (integerp page-size) page-size 25)))) (start (* size page))) (setf (getf tree :children) (loop for row in children for i from 0 when (and (>= i start) (< i (+ start size))) collect row)) (list :kind :object-inspection :status :ok :request-id request-id :handle handle :page page :page-size size :total (length children) :has-more (< (+ start size) (length children)) :object tree)))))
(defun record-diagnostic (session type summary &key request-id) (check-type summary string) (let ((row (list :kind :diagnostic :type type :request-id request-id :summary (subseq summary 0 (min (length summary) (inspector-session-max-preview session)))))) (push row (inspector-session-diagnostics session)) (setf (inspector-session-diagnostics session) (subseq (inspector-session-diagnostics session) 0 (min (length (inspector-session-diagnostics session)) (inspector-session-max-items session)))) (clrhash (inspector-session-cache session)) row))

(defstruct (inspector-theme (:constructor %make-inspector-theme))
  section-title selected normal watch changed-watch unbound-watch diagnostic)

(defun make-inspector-theme
    (&key
       (section-title '(:fg-color :cyan :bold t))
       (selected '(:fg-color :black :bg-color :cyan :bold t))
       (normal '(:fg-color :white))
       (watch '(:fg-color :white))
       (changed-watch '(:fg-color :yellow :bold t))
       (unbound-watch '(:fg-color :gray))
       (diagnostic '(:fg-color :red)))
  (%make-inspector-theme
   :section-title (copy-list section-title)
   :selected (copy-list selected)
   :normal (copy-list normal)
   :watch (copy-list watch)
   :changed-watch (copy-list changed-watch)
   :unbound-watch (copy-list unbound-watch)
   :diagnostic (copy-list diagnostic)))

(defun inspector-style (theme role)
  (check-type theme inspector-theme)
  (copy-list
   (ecase role
     (:section-title (inspector-theme-section-title theme))
     (:selected (inspector-theme-selected theme))
     (:normal (inspector-theme-normal theme))
     (:watch (inspector-theme-watch theme))
     (:watch-changed (inspector-theme-changed-watch theme))
     (:watch-unbound (inspector-theme-unbound-watch theme))
     (:diagnostic (inspector-theme-diagnostic theme)))))

(defun watched-variables (session)
  (copy-list (inspector-session-watch-order session)))

(defun watch-variable (session symbol)
  (check-type symbol symbol)
  (multiple-value-bind (state present)
      (gethash symbol (inspector-session-watches session))
    (declare (ignore state))
    (unless present
      (setf (gethash symbol (inspector-session-watches session))
            (list :sampled nil))
      (setf (inspector-session-watch-order session)
            (append (inspector-session-watch-order session)
                    (list symbol)))))
  symbol)

(defun unwatch-variable (session symbol)
  (check-type symbol symbol)
  (remhash symbol (inspector-session-watches session))
  (setf (inspector-session-watch-order session)
        (remove symbol (inspector-session-watch-order session) :test #'eq))
  symbol)

(defun clear-watches (session)
  (clrhash (inspector-session-watches session))
  (setf (inspector-session-watch-order session) nil)
  session)

(defun %watch-symbol-id (symbol)
  (let ((package (symbol-package symbol)))
    (if package
        (format nil "~A::~A" (package-name package) (symbol-name symbol))
        (format nil "#:~A" (symbol-name symbol)))))

(defun %watch-row (session symbol)
  (let* ((boundp (boundp symbol))
         (value (and boundp (symbol-value symbol)))
         (state (gethash symbol (inspector-session-watches session)))
         (sampled (getf state :sampled))
         (old-boundp (getf state :boundp))
         (old-value (getf state :value))
         (changed (and sampled
                       (or (not (eql boundp old-boundp))
                           (and boundp old-boundp
                                (not (eql value old-value))))))
         (role (cond ((not boundp) :watch-unbound)
                     (changed :watch-changed)
                     (t :watch))))
    (setf (gethash symbol (inspector-session-watches session))
          (list :sampled t :boundp boundp :value value))
    (append
     (list :kind :watch
           :id (%bounded-text session (%watch-symbol-id symbol))
           :symbol symbol
           :name (%bounded-text session (symbol-name symbol))
           :package (let ((package (symbol-package symbol)))
                      (and package (%bounded-text session (package-name package))))
           :binding :global-or-special
           :boundp (not (null boundp))
           :changed (not (null changed))
           :style-role role)
     (if boundp
         (list :preview (%preview session value)
               :handle (register-object session value))
         (list :preview "<unbound>")))))

(defun %watch-rows (session)
  (loop for symbol in (inspector-session-watch-order session)
        collect (%watch-row session symbol)))

(defun %row-matches-query-p (row query)
  (or (null query)
      (zerop (length query))
      (let ((needle (string-upcase query)))
        (some (lambda (value)
                (and (stringp value)
                     (search needle (string-upcase value))))
              (list (getf row :name)
                    (getf row :package)
                    (getf row :summary)
                    (getf row :preview))))))

(defun %filter-rows (rows query)
  (if (and query (plusp (length query)))
      (remove-if-not (lambda (row) (%row-matches-query-p row query)) rows)
      rows))

(defun %symbol-rows (s p)
  (let ((pkg (and p (find-package p)))
        (rows nil)
        (n 0)
        (scanned 0))
    (when pkg
      (do-symbols (sym pkg)
        (when (>= n (inspector-session-max-items s)) (return))
        (incf scanned)
        (when (> scanned (* 8 (inspector-session-max-items s))) (return))
        (multiple-value-bind (found status)
            (find-symbol (symbol-name sym) pkg)
          (when (and (eq found sym)
                     (member status '(:internal :external))
                     (< n (inspector-session-max-items s)))
            (incf n)
            (let ((bound (boundp sym)))
              (push
               (append
                (list :kind :symbol
                      :symbol sym
                      :watchable t
                      :name (%bounded-text s (symbol-name sym))
                      :visibility status
                      :binding :global-or-special
                      :boundp (not (null bound))
                      :style-role :normal)
                (when bound
                  (let ((value (symbol-value sym)))
                    (list :preview (%preview s value)
                          :handle (register-object s value)))))
               rows))))))
    (sort rows #'string< :key (lambda (row) (getf row :name)))))
(defun %section-rows (s section package)
  (case section
    (:packages
     (loop for p in (sort (copy-list (list-all-packages)) #'string<
                          :key #'package-name)
           for i from 0 below (inspector-session-max-items s)
           collect (list :kind :package :name (package-name p)
                         :nicknames (copy-list (package-nicknames p)))))
    (:symbols (%symbol-rows s package))
    (:watches (%watch-rows s))
    (:asdf-systems
     (let* ((pkg (find-package :asdf))
            (fn (and pkg (find-symbol "ALREADY-LOADED-SYSTEMS" pkg))))
       (when (and fn (fboundp fn))
         (loop for name in (sort
                            (remove-if-not #'stringp
                                           (copy-list
                                            (funcall (symbol-function fn))))
                            #'string<)
               for i from 0 below (inspector-session-max-items s)
               collect (list :kind :asdf-system :name name)))))
    (:threads
     #+sb-thread
     (loop for th in (sb-thread:list-all-threads)
           for i from 0 below (inspector-session-max-items s)
           collect (list :kind :thread
                         :name (or (sb-thread:thread-name th) "unnamed")
                         :alive (not (null (sb-thread:thread-alive-p th)))))
     #-sb-thread nil)
    (:diagnostics (copy-list (inspector-session-diagnostics s)))
    (otherwise nil)))
(defun snapshot-image
    (session generation
     &key request-id (section :packages) package (page 0) (page-size 25)
       query refresh interrupted)
  (when interrupted
    (return-from snapshot-image
      (list :kind :image-snapshot :status :interrupted
            :request-id request-id :generation generation :section section
            :entries nil :total 0)))
  (when (or refresh
            (not (equal generation (inspector-session-generation session))))
    (clrhash (inspector-session-cache session))
    (clrhash (inspector-session-objects session))
    (setf (inspector-session-generation session) generation))
  (let ((key (list section package query))
        (page (if (and (integerp page) (>= page 0)) page 0))
        (size (min 50 (max 1 (if (integerp page-size) page-size 25)))))
    (multiple-value-bind (rows found)
        (if (eq section :watches)
            (values (%filter-rows (%section-rows session section package) query) t)
            (gethash key (inspector-session-cache session)))
      (unless found
        (setf rows (%filter-rows (%section-rows session section package) query))
        (setf (gethash key (inspector-session-cache session)) rows))
      (let ((start (* page size))
            (total (length rows)))
        (list :kind :image-snapshot
              :status (if (member section
                                  '(:packages :symbols :watches :asdf-systems
                                    :threads :diagnostics))
                          :ok
                          :unsupported)
              :request-id request-id
              :generation generation
              :section section
              :package package
              :query query
              :page page
              :page-size size
              :total total
              :bounded t
              :possibly-truncated (or (eq section :symbols) (>= total (inspector-session-max-items session)))
              :has-more (< (+ start size) total)
              :entries
              (loop for row in rows
                    for i from 0
                    when (and (>= i start) (< i (+ start size)))
                      collect (copy-tree row)))))))
