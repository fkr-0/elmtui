;;; src/tools/packager.lisp
;;; Simple packager to dump a fast-boot executable Lisp image (SBCL)

(uiop:define-package :elmtui.packager
  (:use :cl)
  (:import-from :asdf #:load-system)
  (:import-from :uiop #:command-line-arguments)
  (:export #:main))

(in-package :elmtui.packager)

(defun print-usage (&optional (stream *standard-output*))
  (format stream
          "Usage: elmtui-packager [options]\n\n~
           Options:\n~
             --system|-s <asdf-system>    Load ASDF system before dumping\n~
             --file|-f   <file.lisp>      Load a Lisp file before dumping\n~
             --eval|-e   <form>           Eval a Lisp form before dumping\n~
             --entry|-E  <pkg:sym>        Entry function for dumped image\n~
             --output|-o <path>           Output binary path\n~
           Examples:\n~
             elmtui-packager -s elmtui -E elmtui:dev-main -o ./elmtui-dev\n~
             elmtui-packager -s elmtui -f examples/fzy-picker.lisp \\\n+                              -E elmtui.examples.fzy-picker:run-fzy-picker -o ./fzy\n"))

(defun parse-args (argv)
  (let ((systems '()) (files '()) (evals '()) (entry nil) (output nil))
    (loop for (opt val . rest) on argv by #'cddr do
      (flet ((ensure-value () (or val (error "Missing value for option ~A" opt))))
        (case (intern (string-upcase opt) :keyword)
          ((:--SYSTEM :-S) (push (ensure-value) systems))
          ((:--FILE   :-f) (push (uiop:ensure-pathname (ensure-value)) files))
          ((:--EVAL   :-e) (push (ensure-value) evals))
          ((:--ENTRY  :-E :--ENTRYPOINT)
           (setf entry (ensure-value)))
          ((:--OUTPUT :-o) (setf output (uiop:ensure-pathname (ensure-value))))
          (t (error "Unknown option: ~A" opt)))))
    (values (nreverse systems) (nreverse files) (nreverse evals) entry output)))

(defun maybe-read-symbol (s)
  (when s
    (multiple-value-bind (sym pos) (ignore-errors (read-from-string s))
      (declare (ignore pos))
      (unless sym (error "Cannot read entry symbol from ~S" s))
      sym)))

(defun ensure-entry-fn (entry-spec)
  (let* ((sym (maybe-read-symbol entry-spec))
         (fn  (and sym (symbol-function sym))))
    (unless (and sym (fboundp sym))
      (error "Entry function not fbound: ~A" entry-spec))
    fn))

(defun do-dump (output entry-fn)
  #+sbcl
  (progn
    (format t "Dumping image to ~A ...~%" output)
    (finish-output)
    (sb-ext:save-lisp-and-die (namestring output)
                              :toplevel entry-fn
                              :executable t
                              :compression 9))
  #-sbcl
  (error "Image dumping currently supported only on SBCL."))

(defun main ()
  (let ((argv (command-line-arguments)))
    (handler-case
        (progn
          (when (or (null argv) (member "-h" argv :test #'string=)
                    (member "--help" argv :test #'string=))
            (print-usage)
            (uiop:quit 0))
          (multiple-value-bind (systems files evals entry-spec output)
              (parse-args argv)
            (dolist (sys systems) (load-system sys))
            (dolist (f files) (load f))
            (dolist (form evals) (eval (read-from-string form)))
            (unless entry-spec (error "--entry is required"))
            (unless output (error "--output is required"))
            (let ((entry (ensure-entry-fn entry-spec)))
              (do-dump output entry))))
      (error (e)
        (format *error-output* "Packager error: ~A~%" e)
        (print-usage *error-output*)
        (uiop:quit 2)))))
