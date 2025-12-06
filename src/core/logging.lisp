;;;;  elmtui/logging.lisp
;;;;  Minimal facility for per-subsystem loggers using LOG4CL

(uiop:define-package #:elmtui.core.logging
  (:use #:cl #:log4cl)      ; import LOG4CL public symbols
  (:import-from :log4cl :logger :remove-all-appenders)
  (:export #:setup-ui-loggers
           #:subsystem-logger
           #:with-subsystem-logger))

(in-package #:elmtui.core.logging)

;;; ------------------------------------------------------------------
(defparameter *default-subsystems*
  '(:rendering :layout :styling :event :update :view)
  "Ordered list of UI subsystems for which we create dedicated loggers.

You can override this when calling `SETUP-UI-LOGGERS` by passing the
:SUBSYSTEMS keyword with your own list.")
(declaim (type list *default-subsystems*))

;;; ------------------------------------------------------------------
(defun %make-file-appender (pathname &key (layout :simple))
  "Internal helper – returns a fresh FILE-APPENDER that *appends* to PATHNAME."
  (declare (type (or pathname string) pathname) (type keyword layout))
  (check-type pathname (or pathname string))
  (check-type layout keyword)
  ;; LOG4CL will expand the path when we write the first entry.
  (make-instance 'file-appender
                 :file pathname
                 :layout layout
                 :append t))

;;; ------------------------------------------------------------------
(defun setup-ui-loggers
    (&key
       (directory #p"./")       ; where to put the *-*.log files
       (subsystems *default-subsystems*)
       (level :debug)
       (layout :simple))
  "Create one logger per SUBSYSTEM and attach a dedicated FILE-APPENDER to each.

Arguments
---------
DIRECTORY   ― pathname designator for the log directory
SUBSYSTEMS  ― list of symbols naming logical UI areas
LEVEL       ― minimum sever­ity accepted by every subsystem logger
LAYOUT      ― `:simple` or `:pattern` (cf. LOG4CL manual)

Return value
------------
An alist of (SUBSYSTEM . LOGGER) pairs for convenient programmatic use.

Calling this function repeatedly REPLACES all appenders of already-existing
loggers, so you can reconfigure at runtime (e.g. switch on DEBUG)."
  (declare (type (or pathname string) directory)
           (type list subsystems)
           (type keyword level layout))
  (check-type directory (or pathname string))
  (check-type subsystems list)
  (check-type level keyword)
  (check-type layout keyword)
  (let ((results '()))
    (dolist (sub subsystems)
      (let* ((logger-name (format nil "ELMTUI.~A" sub))
             (logger       (make-logger logger-name))       ; fetch or create
             (file         (merge-pathnames
                            (format nil "elmtui-~(~A~).log" sub)
                            directory))
             (app          (%make-file-appender file :layout layout)))
        ;; Purge any stale appenders and attach the fresh file-appender
        (remove-all-appenders logger)
        (add-appender logger app)
        (set-log-level logger level)
        ;; Store association for caller
        (push (cons sub logger) results)))
    (log:info "UI loggers initialised: ~S" subsystems)
    (nreverse results)))
;;; ------------------------------------------------------------------
(defun subsystem-logger (subsystem)
  "Return the logger object for SUBSYSTEM (a keyword or string).

If the logger does not exist yet, it is *created on demand* **without**
any appenders.  Call `SETUP-UI-LOGGERS` first if you want automatic
file appenders."
  (declare (type (or keyword string) subsystem))
  (check-type subsystem (or keyword string))
  (make-logger (format nil "ELMTUI.~A" subsystem)))

;;; ------------------------------------------------------------------
(defmacro with-subsystem-logger (subsystem &body body)
  "Execute BODY with *logger* rebound to the SUBSYSTEM logger.

Example
-------
```lisp
(with-subsystem-logger :rendering
  (log:debug \"Drawing the main canvas\"))
```"
  (declare (type (or keyword string) subsystem))
  ;; No runtime check-type for macro argument here, it's compile-time.
  `(let ((*logger* (subsystem-logger ,subsystem)))
     ,@body))

;;; ------------------------------------------------------------------
;;; (provide 'elmtui/logging)
