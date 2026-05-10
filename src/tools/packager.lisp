;;; src/tools/packager.lisp
;;; Packager for dumping a fast-boot executable image (SBCL)

(uiop:define-package :elmtui.packager
  (:use :cl)
  (:import-from :asdf #:load-system)
  (:import-from :uiop #:command-line-arguments #:ensure-pathname #:quit)
  (:export #:main))

(in-package :elmtui.packager)

(defun print-usage (&optional (stream *standard-output*))
  (format stream
          "Usage: elmtui-packager [options]~%~%~
Options:~%~
  --system|-s <asdf-system>    Load ASDF system before dumping~%~
  --file|-f   <file.lisp>      Load a Lisp file before dumping~%~
  --eval|-e   <form>           Eval a Lisp form before dumping~%~
  --entry|-E  <pkg:sym>        Entry function for dumped image~%~
  --output|-o <path>           Output binary path~%~
  --help|-h                    Print this help~%~%~
Examples:~%~
  elmtui-packager -s elmtui -E my-app:run -o ./my-app~%~
  elmtui-packager -s elmtui -f examples/fzy-picker.lisp -E elmtui.examples.fzy-picker:run-fzy-picker -o ./fzy~%"))

(defun %read-form (text)
  (let ((*read-eval* nil))
    (multiple-value-bind (form pos)
        (read-from-string text nil nil)
      (declare (ignore pos))
      (unless form
        (error "Could not read Lisp form from ~S" text))
      form)))

(defun %parse-args (argv)
  "Return plist with keys :systems :files :evals :entry :output." 
  (let ((systems '())
        (files '())
        (evals '())
        (entry nil)
        (output nil)
        (help nil)
        (i 0)
        (n (length argv)))
    (labels ((at-end-p () (>= i n))
             (current () (elt argv i))
             (next-value ()
               (when (>= (1+ i) n)
                 (error "Missing value for option ~A" (current)))
               (prog1 (elt argv (1+ i))
                 (incf i 2))))
      (loop until (at-end-p) do
        (let ((arg (current)))
          (cond
            ((or (string= arg "-h") (string= arg "--help"))
             (setf help t)
             (incf i 1))
            ((or (string= arg "-s") (string= arg "--system"))
             (push (next-value) systems))
            ((or (string= arg "-f") (string= arg "--file"))
             (push (ensure-pathname (next-value)) files))
            ((or (string= arg "-e") (string= arg "--eval"))
             (push (next-value) evals))
            ((or (string= arg "-E") (string= arg "--entry")
                 (string= arg "-X") (string= arg "--entrypoint"))
             (setf entry (next-value)))
            ((or (string= arg "-o") (string= arg "--output"))
             (setf output (ensure-pathname (next-value))))
            (t
             (error "Unknown option: ~A" arg)))))
    (list :systems (nreverse systems)
          :files (nreverse files)
          :evals (nreverse evals)
          :entry entry
          :output output
          :help help))))

(defun %resolve-entry-function (entry-spec)
  (let ((sym (%read-form entry-spec)))
    (unless (and (symbolp sym) (fboundp sym))
      (error "Entry function not fbound: ~A" entry-spec))
    (symbol-function sym)))

(defun %run-load-phase (cfg)
  (dolist (sys (getf cfg :systems))
    (load-system sys))
  (dolist (file (getf cfg :files))
    (load file))
  (dolist (form-text (getf cfg :evals))
    (eval (%read-form form-text))))

(defun %dump-image (output entry-fn)
  #+sbcl
  (progn
    (format t "Dumping image to ~A ...~%" output)
    (finish-output)
    (sb-ext:save-lisp-and-die (namestring output)
                              :toplevel entry-fn
                              :executable t
                              :compression 9))
  #-sbcl
  (error "Image dumping is currently supported only on SBCL."))

(defun %validate-required-options (cfg)
  (unless (getf cfg :entry)
    (error "--entry|-E is required"))
  (unless (getf cfg :output)
    (error "--output|-o is required")))

(defun run-packager (&optional (argv (command-line-arguments)))
  (let ((cfg (%parse-args argv)))
    (when (or (null argv) (getf cfg :help))
      (print-usage)
      (return-from run-packager 0))
    (%validate-required-options cfg)
    (%run-load-phase cfg)
    (let ((entry-fn (%resolve-entry-function (getf cfg :entry))))
      (%dump-image (getf cfg :output) entry-fn))
    0))

(defun main ()
  (handler-case
      (quit (run-packager))
    (error (e)
      (format *error-output* "Packager error: ~A~%" e)
      (print-usage *error-output*)
      (quit 2))))
