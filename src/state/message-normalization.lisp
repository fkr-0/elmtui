(uiop:define-package :elmtui.cl-state.message-normalization
  (:use :cl)
  (:export
   #:message-variant-p
   #:canonicalize-message-variant
   #:validate-message-instance))

(in-package :elmtui.cl-state.message-normalization)

(defun message-variant-p (message-type message-instance)
  "Delegating boundary module for message variant checks used by state/contracts."
  (elmtui.state.msg:message-variant-p message-type message-instance))

(defun canonicalize-message-variant (message-type message-instance)
  "Delegating boundary module for message variant canonicalization."
  (elmtui.state.msg:canonicalize-message-variant message-type message-instance))

(defun validate-message-instance (message-type message-instance)
  "Validate MESSAGE-INSTANCE against DEFMSG schema for MESSAGE-TYPE.
Returns two values:
  1) canonicalized message instance on success, NIL on failure
  2) failure reason string on failure, NIL on success."
  (let ((schema (gethash message-type elmtui.state.msg::*message-schemas*)))
    (unless schema
      (return-from validate-message-instance
        (values nil (format nil "No schema registered for message type ~S." message-type))))
    (unless (listp message-instance)
      (return-from validate-message-instance
        (values nil
                (format nil "Message instance for ~S is not a list: ~S"
                        message-type message-instance))))
    (let ((canonical (elmtui.state.msg:canonicalize-message-variant
                      message-type message-instance)))
      (unless canonical
        (return-from validate-message-instance
          (values nil
                  (format nil "Unknown variant ~S for message type ~S."
                          (first message-instance) message-type))))
      (let* ((variant-key (first canonical))
             (variant-def
               (find variant-key
                     (elmtui.state.msg:message-schema-variants schema)
                     :key #'elmtui.state.msg:variant-definition-name))
             (expected-args (and variant-def
                                 (elmtui.state.msg:variant-definition-args variant-def)))
             (provided-args-plist (rest canonical)))
        (unless variant-def
          (return-from validate-message-instance
            (values nil
                    (format nil "Unknown canonical variant ~S for message type ~S."
                            variant-key message-type))))
        (unless (= (length provided-args-plist) (* 2 (length expected-args)))
          (return-from validate-message-instance
            (values nil
                    (format nil
                            "Incorrect number of arguments for variant ~S of ~S. Expected ~D, got ~D."
                            variant-key message-type (* 2 (length expected-args))
                            (length provided-args-plist)))))
        (loop for arg-def in expected-args
              for expected-keyword = (elmtui.state.msg:arg-def-keyword arg-def)
              for expected-type = (elmtui.state.msg:arg-def-type arg-def)
              for value = (getf provided-args-plist expected-keyword :not-found)
              do
                 (when (eq value :not-found)
                   (return-from validate-message-instance
                     (values nil
                             (format nil "Missing keyword argument ~S for variant ~S of ~S."
                                     expected-keyword variant-key message-type))))
                 (unless (typep value expected-type)
                   (return-from validate-message-instance
                     (values nil
                             (format nil
                                     "Type error for argument ~S in variant ~S of ~S. Expected ~S, got ~S (value: ~S)."
                                     expected-keyword variant-key message-type
                                     expected-type (type-of value) value)))))
        (values canonical nil)))))
