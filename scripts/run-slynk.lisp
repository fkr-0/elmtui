;;; Portable Slynk launcher for ElmTUI development.

(require :asdf)

(defun %environment-port (name default)
  "Read a positive integer port from NAME, falling back to DEFAULT."
  (let ((value (uiop:getenv name)))
    (if (and value (plusp (length value)))
        (handler-case
            (let ((port (parse-integer value :junk-allowed nil)))
              (if (<= 1 port 65535)
                  port
                  (error "Port is outside the valid range: ~D" port)))
          (error (condition)
            (error "Invalid ~A value ~S: ~A" name value condition)))
        default)))

(defun start-elmtui-slynk (&key
                            (port (%environment-port "ELMTUI_SLYNK_PORT" 4005)))
  "Load ElmTUI, start a Slynk server on PORT, and return the server handle."
  (asdf:load-system :slynk)
  (asdf:load-system :elmtui)
  (let ((server (uiop:symbol-call :slynk :create-server
                                  :port port
                                  :dont-close t)))
    (format t "~&ElmTUI Slynk server listening on 127.0.0.1:~D~%" port)
    (finish-output)
    server))

(defun main ()
  "Start the development server and keep this Lisp process alive."
  (start-elmtui-slynk)
  (loop (sleep 3600)))

(main)
