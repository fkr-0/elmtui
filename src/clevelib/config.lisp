(uiop:define-package :cleve-elm.config
  (:use :cl )
  (:export
    :*default-dispatch-strategy*
    :*dispatch-strategies*
    :*dispatch-phases*
    :*special-targets*))
(in-package :cleve-elm.config)

(declaim (type symbol *default-dispatch-strategy*))
(defparameter *default-dispatch-strategy* nil ; :bubble
  "The default dispatch strategy to use when dispatching messages")

(declaim (type list *dispatch-strategies*))
(defparameter *dispatch-strategies* '(:bubble :capture :broadcast :central-update)
  "A list of dispatch strategies that can be used by relays:
  :bubble - The message is dispatched to the target and then to every node from the target to the root
  :capture - The message is dispatched to the target and then to every node from the target to the root")


(declaim (type list *dispatch-phases*))
(defparameter *dispatch-phases* '(:bubbling :capturing :at-target :stopped :broadcast :error :init :done))

(declaim (type list *special-targets*))
(defparameter *special-targets* '(:root :focus :self)
  "A list of special message-targets that can be used/processed by relays:
  :root - The root element
  :parent - The parent of the sender of the message
  :children - The children of the sender of the message
  :broadcast - all known targets
  :self - The sender of the message")
