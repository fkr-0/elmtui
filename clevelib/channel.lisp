(uiop:define-package :clevelib.channel
  (:export :go :-> :<- :channel :channel-close
    :make-channel :channel-closed :channel-capacity :channel-length :channel-empty-p :channel-full-p :gogo)
  (:use :cl :bt :clevelib.queue))
(in-package :clevelib.channel)

;; ======================================================================
;; Channels
;; ======================================================================
;; The implementation is based on go channels.

;; Channels are a synchronization primitive that allow one thread to
;; send a value to another thread.  A channel is a queue with a lock
;; and a condition variable.  The lock is used to protect the queue
;; from concurrent access.  The condition variable is used to signal
;; when the queue is empty.

;; Here is a comparison between channels and the priority queue implementation
;; in queue.lisp:

;; Purpose: Channels enable communication between goroutines. Queues allow
;; concurrent producers/consumers to safely add and remove items.

;; Implementation: Channels have send and receive operations built into Go. The
;; queue uses locks and condition variables for synchronization.

;; Blocking: Both channels and the queue implementation support blocking and
;; non-blocking variants of send/receive and enqueue/dequeue.

;; Prioritization: The queue supports prioritized items using separate queues.
;; Channels typically treat all messages equally.

;; Buffering: Channels have configurable buffering capacity. The queue size is
;; unbounded.

;; Closing: Channels can be closed to indicate no more sends. The queue has no
;; equivalent.

;; Select: Go's select statement allows selecting over multiple channels. The
;; queue does not offer an equivalent.



;; (defclass channel ()
;;   ((closed :initform nil :type boolean)
;;     (lock :type bt:lock)
;;     (queue :type clevelib.queue:priority-queue)
;;     ;; (channel-empty-condition :type bt:condition-variable)
;;     )
;;   (:documentation "A channel is a queue with modified behaviour and "))



;; (defun make-channel ()
;;   (make-channel))

;; ;; (defmethod receive ((value t) (channel channel)
;; ;;   (bt:with-lock-held ((channel-lock channel))
;; ;;     (enqueue value (channel-queue channel))
;; ;;     (bt:condition-notify (channel-empty-condition channel))))

;; ;; (defmethod send ((value t) (queue clevelib.queue:priority-queue))
;; ;;   (bt:with-lock-held ((channel-lock channel))
;; ;;     (loop while (null (channel-queue channel))
;; ;;       do (bt:condition-wait (channel-empty-condition channel) (channel-lock channel)))
;; ;;     (dequeue (channel-queue channel))))

;; ;; (defun channel-close (channel)
;; ;;   (bt:with-lock-held ((channel-lock channel))
;; ;;     (setf (channel-closed channel) t)
;; ;;     (bt:condition-notify-all (channel-empty-condition channel))))

;; send(value) - Send a value through the channel. This may block if the channel's buffer is full.

;; receive() - Receive a value from the channel. This may block if the channel is empty.

;; close() - Close the channel, indicating no more values will be sent. Further send attempts will fail.

;; Additional methods a channel may provide include:

;; capacity() - Get the channel's buffer capacity.

;; len() - Get the current buffer length/number of elements queued.

;; is_closed() - Check if the channel is closed.
;; (defmethod send ((value t) (channel channel))
;;   (bt:with-lock-held ((channel-lock channel))
;;     (enqueue value (channel-queue channel))
;;     (bt:condition-notify (channel-empty-condition channel))))

;; (defmethod receive ((channel channel))
;;   (bt:with-lock-held ((channel-lock channel))
;;     (loop while (null (channel-queue channel))
;;       do (bt:condition-wait (channel-empty-condition channel) (channel-lock channel)))
;;     (dequeue (channel-queue channel))))

;; (defmethod channel-close ((channel channel))
;;   (bt:with-lock-held ((channel-lock channel))
;;     (setf (channel-closed channel) t)
;;     (bt:condition-notify-all (channel-empty-condition channel))))

;; (defmethod channel-closed-p ((channel channel))
;;   (channel-closed channel))

;; (defmethod channel-capacity ((channel channel))
;;   (queue-capacity (channel-queue channel)))

;; (defmethod channel-length ((channel channel))
;;   (queue-length (channel-queue channel)))

;; (defmethod channel-empty-p ((channel channel))
;;   (queue-empty-p (channel-queue channel)))

;; (defmethod channel-full-p ((channel channel))
;;   (queue-full-p (channel-queue channel)))

;; ;; ======================================================================
;; ;; Select
;; ;; ======================================================================
;; ;;
;; ;; The select statement lets a goroutine wait on multiple communication
;; ;; operations. E.g.:
;; ;;
;; ;; (select
;; ;;  (send channel1 value1)
;; ;;  (send channel2 value2)
;; ;;  (receive channel3)
;; ;;  (receive channel4))
;; ;;  (default (print "no communication"))
;; ;;  )
;; ;;
;; ;; The select statement blocks until one of the operations can proceed.
;; ;; If multiple operations can proceed, one is chosen at random.
;; ;; If none of the operations can proceed and a default clause is present,
;; ;; the default clause is executed.
;; ;;
;; ;; In Go, the select statement is typically used to implement timeouts
;; ;; and non-blocking communication.  The select statement is also used
;; ;; to implement the default case of a switch statement.
;; ;;
;; ;; Timeout Example:
;; ;; (select
;; ;; (send channel value) ;; Either send the value or block
;; ;; (default (print "timeout")) ;; If the send blocks, print timeout
;; ;; )
;; ;;
;; ;; Non-blocking Example:
;; ;; (select
;; ;; (send channel value) ;; Either send the value or block
;; ;; (default (print "channel full")) ;; If the send blocks, print timeout
;; ;; )
;; ;;
;; ;; The select statement is implemented using a priority queue of
;; ;; operations.  The priority queue is ordered by the time the operation
;; ;; was added to the queue.  The select statement adds operations to the
;; ;; queue and then blocks until an operation can proceed.  When an
;; ;; operation can proceed, it is removed from the queue and executed.
;; ;; If the operation is a send or receive, the value is returned.
;; ;;
;; ;;
;; ;; The select statement blocks until one of the operations can proceed.
(defclass operation ()
  ((priority :initform 0 :type fixnum :accessor priority)
    (operation :type function :accessor operation)
    (send-operation-p :initform nil :type boolean :accessor send-operation-p)
    (send-operation-result :initform nil :type t :accessor send-operation-result)
    (receive-operation-p :initform nil :type boolean :accessor receive-operation-p)
    (receive-operation-result :initform nil :type t :accessor receive-operation-result)
    (default-operation-p :initform nil :type boolean :accessor default-operation-p)))
(defclass select ()
  ((operations :type clevelib.queue:priority-queue :initarg :operations :accessor operations)
    (lock :type bt:lock :initarg :lock :accessor lock)
    (condition-v :initform (bt:make-condition-variable) :type bt::condition-variable :initarg :condition-v :accessor condition-v)
    (result :type t :initform nil :accessor result)
    (closed :initform nil :type boolean :accessor closed))
  (:documentation "A select statement is a priority queue of operations."))


(defun make-select ()
  (make-instance 'select
    :operations (clevelib.queue:make-queue)
    :lock (bt:make-lock)
    :condition-v (bt:make-condition-variable)))



(defmethod select-wait ((select select))
  "Wait for an operation to be ready.  If the select statement is closed,
  return nil.  If the select statement is not closed, block until an
  operation can proceed and return the result of the operation. An existing
result is signaled by the operations queue being empty."
  (bt:with-lock-held ((lock select))
    (loop while (null (select-result select))
      do (bt:condition-wait (condition-v select) (lock select)))))

(defmethod select-result ((select select))
  "Return the result of the select statement.  If the select statement
  is closed, return nil.  If the select statement is not closed, block
  until an operation can proceed and return the result of the operation."
  (unless (closed select)
    (if (null (result select))
      (select-wait select)))
  (result select))

(defmethod select-close ((select select))
  "Close the select statement. Closed select statements will not accept
  new operations."
  (bt:with-lock-held ((lock select))
    (setf (closed select) t)
    (sb-thread:condition-broadcast (condition-v select))))

(defmethod select-closed-p ((select select))
  "Return t if the select statement is closed. Closed select statements
  will not accept new operations."
  (closed select))

(defmethod select-add-operation ((select select) (operation operation))
  "Add an operation to the select statement.  If the select statement is
  closed, return nil.  If the select statement is not closed, add the
  operation to the priority queue and return t."
  (unless (closed select)
    (bt:with-lock-held ((lock select))
      (clevelib.queue:enqueue operation (operations select))
      (bt:condition-notify (condition-v select))
      t)))

;; (defmethod select-remove-operation ((select select) (operation operation))
;;   "Remove an operation from the select statement.  If the select statement
;;   is closed, return nil.  If the select statement is not closed, remove the
;;   operation from the priority queue and return t."
;;   (unless (closed select)
;;     (bt:with-lock-held ((select-lock select))
;;       (clevelib.queue:remove operation (operations select))
;;       (bt:condition-notify (condition-v select))
;;       t)))


;; (defmethod execute-operation ((select select) (operation operation))
;;   "Execute an operation.  If the operation is a send or receive, return
;;   the value.  If the operation is a default, return t."
;;   (let ((result (funcall operation)))
;;     (if (send-operation-p operation)
;;       (send-operation-result operation)
;;       (if (receive-operation-p operation)
;;         (receive-operation-result operation)
;;         t))))



;; ======================================================================
;; Channels
;; ======================================================================
;;
;; Channels are the pipes that connect concurrent goroutines. You can
;; send values into channels from one goroutine and receive those values
;; into another goroutine.
;;
;; Channels are first-class values, just like strings or integers.
;; Channels can be passed around like any other value.
;; A channel has a type, the type of the values that can be sent and
;; received on the channel.  The zero value of a channel is nil.
;; The nil channel is not usable.
;; The make function allocates and initializes channels.
;; unbuffered and communication succeeds only when both a sender and
;; receiver are ready.
;;
;; Channels support two operations, send and receive.
;; The send operation sends a value into the channel.
;; The receive operation receives a value from the channel.
;; The <- operator specifies the channel direction, send or receive.
;; If no direction is given, the channel is bidirectional.
;; A send statement sends a value on a channel.
;; A receive expression receives a value from a channel.
;; The arrow can be interpreted as the data flow direction.
;;
;; ch <- v  // Send v to channel ch.
;; v := <-ch // Receive from ch, and
;;           // assign value to v.
;;
;;
;; make(chan t) - unbuffered channel
;; make(chan t, n) - buffered channel
;; The capacity, in number of elements, sets the size of the buffer in
;; the channel.  If the capacity is zero or absent, the channel is unbuffered
;; and communication succeeds only when both a sender and receiver are ready.
;; Otherwise, the channel is buffered and communication succeeds without
;; blocking if the buffer is not full (sends) or not empty (receives).
;;
;; A channel may be closed with the close function.
;; The multi-valued receive operation returns a received value and a
;; boolean indicating whether the channel is closed.
;; The close function may be applied to a channel variable v to close it.
;; The multi-valued receive operation returns a received value and a
;;
;; v, ok := <-ch
;; If ok is false, the channel is closed and all values in the channel
;; have already been received.
;;
;; We will try to emulate the behavior of Go channels as closely as possible including
;; the arrow notation through the use of macros.
;;
;; The channel class is a wrapper around a queue.  The queue is used to
;; store the values sent to the channel.  The queue is a first-in-first-out
;; queue.  The queue is implemented using a linked list.
;;
;; The channel class also contains a lock and a condition variable.
;; The lock is used to protect the queue.  The condition variable is
;; used to signal when a value is available in the queue.
;;
;; An example of the resulting DSL using the arrow notation with macros '->' and '<-':
;; (let ((channel (make-channel)))
;;  (go (loop (let ((value (<- channel)))
;;            (print value))))
;;            (-> channel 1)
;;            (-> channel 2)
;;            (-> channel 3)
;;            (-> channel 4)
;;
;; The channel class is a wrapper around a queue.  The queue is used to
;; store the values sent to the channel.  The queue is a first-in-first-out
;; queue.  The queue is implemented using a linked list.
;; The channel class also contains a lock and a condition variable.
;;
;;

(defclass channel ()
  ((queue :type clevelib.queue:queue :initarg :queue :initform (clevelib.queue:make-queue) :accessor channel-queue)
    (capacity :accessor channel-capacity :initform 0 :type fixnum :initarg :capacity :documentation "The capacity of the channel.")
    (lock-r :type bt:lock :initarg :lock-r :accessor channel-lock-r)
    (lock-s :type bt:lock :initarg :lock-s :accessor channel-lock-s)
    (lock-sync :type bt:lock :initarg :lock-sync :accessor channel-lock-sync)
    (condition :type sb-thread:waitqueue :initarg :condition :accessor channel-condition)
    (condition-wait-receive :type sb-thread:waitqueue :initarg :condition-wait-receive :accessor channel-condition-wait-receive :initform (sb-thread:make-waitqueue) :documentation "The condition variable used to signal when a value is available in the queue.")
    (condition-wait-send :type sb-thread:waitqueue :initarg :condition-wait-send :accessor channel-condition-wait-send :initform (sb-thread:make-waitqueue) :documentation "The condition variable used to signal when a value can be sent to the queue.")
    (closed :initform nil :type boolean :accessor channel-closed :initarg :closed))
  (:documentation "A channel is a queue of values."))

(defmethod initialize-instance :after ((channel channel) &key)
  "Initialize the channel.  If the capacity is zero, set the capacity to
  the maximum fixnum."
  (declare (ignore))
  ;; (when (zerop (channel-capacity channel))
  ;;   (setf (channel-capacity channel) most-positive-fixnum))
  )

(defun make-channel (&key (capacity 0) (closed nil))
  "Make a channel. BUFFERED is t if the channel is buffered, nil otherwise.
Buffered channels have a capacity.  CLOSED is t if the channel is closed,"
  (make-instance 'channel
    :capacity capacity
    :closed closed
    :lock-r (bt:make-lock)
    :lock-s (bt:make-lock)
    :condition (bt:make-condition-variable)))


(defmethod channel-lock ((channel channel))
  "Return the lock of the channel."
  (channel-lock-s channel))



(defmethod channel-close ((channel channel))
  "Close the channel."
  (bt:with-lock-held ((channel-lock-s channel))
    (setf (channel-closed channel) t)
    (sb-thread:condition-broadcast (channel-condition channel)))) ;; broadcast to all threads
;; waiting on the condition variable

(defmethod no-wait ((channel channel) &key (send t))
  "Return t if waiting on send/receive may skip blocking"
  (if send
    (and (< 0 (channel-capacity channel)) (< (clevelib.queue:counter (channel-queue channel))(channel-capacity channel) ))
    (not (zerop (clevelib.queue:counter (channel-queue channel))))))

(defmethod channel-send ((channel channel) value)
  "Send a value to the channel.  If the channel is closed, an error is signaled."
  (bt:with-lock-held ((channel-lock-s channel))
                                        ;format t "entered send lock value ~a~%" value)
    (when (channel-closed channel)
      (error "Channel is closed."))
                                        ;format t "waiting on send condition value ~a~%" value)
                                        ;format t "sending value ~a~%" value)
    (let ((nw (no-wait channel :send t)))
      (clevelib.queue:enqueue  (channel-queue channel)value)
                                        ;format t "enqueuing finished. waiting on receive confirm ~a" value)
      (unless nw (bt:condition-wait (channel-condition-wait-receive channel) (channel-lock-s channel)))
      ;; (bt:condition-wait (channel-condition channel) (clevelib.queue:queue-lock (channel-queue channel)) )

      (when (channel-closed channel)
        (error "Channel is closed."))
      ))
  ;; (sb-thread:condition-broadcast (channel-condition channel))
  )

(defmethod channel-receive ((channel channel))
  "Receive a value from the channel.  If the channel is closed, an error is signaled."
  (bt:with-lock-held ((channel-lock-r channel))
    (when (channel-closed channel)
      (error "Channel is closed."))
                                        ;format t "broadcasting receive condition~%")
                                        ;format t "waiting on queue blockread~%")
    (bt:condition-notify (channel-condition-wait-send channel))
    (sb-thread:condition-broadcast (channel-condition-wait-send channel))
    (let* ((nw (and (> (channel-capacity channel) 0) (no-wait channel :send nil)))
            (v (if nw (clevelib.queue:dequeue-no-wait (channel-queue channel))
                 (clevelib.queue:dequeue-wait (channel-queue channel)  ))))
      (bt:condition-notify (channel-condition-wait-receive channel))
      (sb-thread:condition-broadcast (channel-condition-wait-receive channel))

                                        ;format t "Received value ~a~%" v)

      ;; (sb-thread:condition-broadcast (channel-condition channel))
      v)))
;; DSL - As it turns out, we do not need macros to implement the DSL. We can
;; implement the DSL using functions.  The DSL is implemented below using


(defmacro gogo (body)
  "Start a new thread to execute the body."
  `(bt:make-thread (lambda () ,body)))

(defun -> (channel value)
  "Send a value to the channel."
  (channel-send channel value))

(defun <- (channel)
  "Receive a value from the channel."
  (channel-receive channel))

(defmacro select (&rest operations)
  "Create a select statement.  The select statement is a priority queue
  of operations.  The select statement blocks until one of the operations
  can proceed.  If multiple operations can proceed, one is chosen at
  random.  If none of the operations can proceed and a default clause
  is present, the default clause is executed."
  `(let ((select (make-select)))
     (bt:with-lock-held ((lock select))
       (loop for operation in ',operations
         do (enqueue (operations select) operation )))
     (select-wait select)
     (select-result select)))

;; (let (
;;        (c1 (make-channel))
;;        (c2 (make-channel))
;;        (c3 (make-channel)))

;;   (select
;;     (-> c1 1)
;;     (-> c2 2)
;;     (-> c3 3)
;;     )
;;   (gogo (<- c2 ))
;;   )

;; If we want non-blocking send and receive operations, we can implement
;; them as in go using the select statement.  The select statement chooses
;; which of a set of possible send or receive operations will proceed.
;; It looks similar to a switch statement but with the cases all referring
;; to communication operations.

;; select {
;; case i := <-c:
;;    // use i
;; default:
;;   // receiving from c would block
;;   }

;; select {
;; case c <- x:
;;   // value sent
;;   default:
;;   // sending x on c would block
;;   }
;;   The default case in a select is run if no other case is ready.
;;   Use a default case to try a send or receive without blocking:
;;   select {
;;   case i := <-c:
;;   // use i
;;   default:
;;   // receiving from c would block
;;   print("no communication")
;;   }
;;
;;   The default case in a select is run if no other case is ready and it
;;   never blocks.


