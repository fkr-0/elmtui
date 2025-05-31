(uiop:define-package :cleve-elm.channel
  (:export :go :-> :<- :channel :channel-close :channel-queue
           :make-channel :channel-closed :channel-capacity :channel-length :channel-empty-p :channel-full-p :gogo
   :channel-add-filter :channel-remove-filter :filter-channel :filtered-channel :make-filtered-channel
           :channel-take! :channel-put!
           :apply-filter :pass-through-p)
  (:use :cl :bt :cleve-elm.queue))
(in-package :cleve-elm.channel)

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
;;     (queue :type cleve-elm.queue:priority-queue)
;;     ;; (channel-empty-condition :type bt:condition-variable)
;;     )
;;   (:documentation "A channel is a queue with modified behaviour and "))



;; (defun make-channel ()
;;   (make-channel))

;; ;; (defmethod receive ((value t) (channel channel)
;; ;;   (bt:with-lock-held ((channel-lock channel))
;; ;;     (enqueue value (channel-queue channel))
;; ;;     (bt:condition-notify (channel-empty-condition channel))))

;; ;; (defmethod send ((value t) (queue cleve-elm.queue:priority-queue))
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
  ((priority                :initform 0     :type fixnum   :accessor priority)
   (operation               :type function   :accessor operation)
   (send-operation-p        :initform nil   :type boolean  :accessor send-operation-p)
   (send-operation-result   :initform nil   :type t        :accessor send-operation-result)
   (receive-operation-p     :initform nil   :type boolean  :accessor receive-operation-p)
   (receive-operation-result :initform nil   :type t        :accessor receive-operation-result)
   (default-operation-p     :initform nil   :type boolean  :accessor default-operation-p)))

(defclass select ()
  ((operations :type cleve-elm.queue:priority-queue
               :initarg :operations :accessor operations)
   (lock       :type bt:lock
               :initarg :lock       :accessor lock)
   (condition-v :initform (bt:make-condition-variable)
                :type bt::condition-variable
                :initarg :condition-v :accessor condition-v)
   (result     :type t :initform nil :accessor result)
   (closed     :initform nil :type boolean :accessor closed))
  (:documentation "A select statement is a priority queue of operations with optional timeout."))

(defun make-select ()
  (make-instance 'select
                 :operations (cleve-elm.queue:make-queue)
                 :lock       (bt:make-lock)
                 :condition-v (bt:make-condition-variable)))

;;;; exampleproject/src/select.lisp

(defmethod select-wait ((sel select) &optional timeout)
  "Wait until an operation completes or TIMEOUT seconds elapse.
Returns T if an operation completed, NIL on timeout or if closed."
  (bt:with-lock-held ((lock sel))
    (if timeout
        ;; timed wait
        (loop while (and (null (result sel)) (not (closed sel)))
              do
                 ;; sb-thread:condition-wait returns NIL on timeout
                 (unless (bt:condition-wait (condition-v sel) (lock sel) :timeout timeout)
                   (return nil)))
        ;; infinite wait
        (loop while (and (null (result sel)) (not (closed sel)))
              do (bt:condition-wait (condition-v sel) (lock sel))))
    t))

(defmethod select-result ((sel select))
  "Non-blocking accessor for the result slot."
  (result sel))
(defmethod select-add-operation ((sel select) (op operation))
  "Add an operation to the select. Returns t if added."  ;;
  (unless (closed sel)
    (bt:with-lock-held ((lock sel))
      (cleve-elm.queue:enqueue op (operations sel))
      (bt:condition-notify (condition-v sel))
      t)))

(defmacro select (&rest args)
  "Like `make-select`+`select-wait`+`select-result`, but inlined.
Accepts an optional keyword `:timeout SECS`.  Returns the operation result
or NIL on timeout or if closed before any op fires."
  (let ((timeout nil)
        (ops '()))
    ;; parse KEYWORDS vs operations
    (loop while args
          if (keywordp (first args))
            do (case (first args)
                 (:timeout
                  (setq timeout (second args))
                  (setq args (cddr args)))
                 (otherwise
                  (error "SELECT: unexpected keyword ~S" (first args))))
          else
            do (push (pop args) ops))
    (setq ops (nreverse ops))
    `(let ((sel (make-select)))
       ;; enqueue each operation under lock
       (bt:with-lock-held ((lock sel))
         ,@(mapcar (lambda (op)
                     `(select-add-operation sel ,op))
                   ops))
       ;; wait (with optional timeout)
       (if (select-wait sel ,timeout)
           (select-result sel)
           ;; timed out
           nil))))



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
  ((queue :type cleve-elm.queue:queue :initarg :queue :initform (cleve-elm.queue:make-queue) :accessor channel-queue)
   (capacity :accessor channel-capacity :initform 0 :type fixnum :initarg :capacity :documentation "The capacity of the channel.")
   (name :initarg :name :accessor channel-name :type string :initform "channel" :documentation "The name of the channel.")
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

(defun make-channel (&key (capacity 0) (closed nil) (name nil))
  "Make a channel. BUFFERED is t if the channel is buffered, nil otherwise.
Buffered channels have a capacity.  CLOSED is t if the channel is closed,"
  (make-instance 'channel
                 :name name
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
      (and (< 0 (channel-capacity channel)) (< (cleve-elm.queue:counter (channel-queue channel))(channel-capacity channel) ))
      (not (zerop (cleve-elm.queue:counter (channel-queue channel))))))

(defmethod channel-send ((channel channel) value)
  "Send a value to the channel.  If the channel is closed, an error is signaled."
  (bt:with-lock-held ((channel-lock-s channel))
                                        ;format t "entered send lock value ~a~%" value)
    (when (channel-closed channel)
      (error "Channel is closed."))
                                        ;format t "waiting on send condition value ~a~%" value)
                                        ;format t "sending value ~a~%" value)
    (let ((nw (no-wait channel :send t)))
      (cleve-elm.queue:enqueue  (channel-queue channel)value)
                                        ;format t "enqueuing finished. waiting on receive confirm ~a" value)
      (unless nw (bt:condition-wait (channel-condition-wait-receive channel) (channel-lock-s channel)))
      ;; (bt:condition-wait (channel-condition channel) (cleve-elm.queue:queue-lock (channel-queue channel)) )

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
           (v (if nw (cleve-elm.queue:dequeue-no-wait (channel-queue channel))
                  (cleve-elm.queue:dequeue-wait (channel-queue channel)  ))))
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

;; ======================================================================
;; Filtered Channels
;; ======================================================================
;; Enhanced channel implementation with filtering capabilities

(defclass filtered-channel (channel)
  ((filters :initform nil :accessor channel-filters :type list :documentation "List of filter functions that messages must pass through"))
  (:documentation "A channel that can filter messages before they are processed. Each filter function should return T if the message should be processed, NIL otherwise."))

(defun make-filtered-channel (&key (capacity 0) (closed nil) (filters nil))
  "Create a filtered channel with the given capacity, closed state, and filter functions.
Each filter function should take a message as argument and return T if the message should pass, NIL otherwise."
  (let ((channel (make-instance 'filtered-channel
                                :capacity capacity
                                :closed closed
                                :lock-r (bt:make-lock)
                                :lock-s (bt:make-lock)
                                :condition (bt:make-condition-variable))))
    (when filters
      (setf (channel-filters channel) filters))
    channel))

(defun pass-through-p (message filters)
  "Determine if message should pass through the filters.
Returns T if the message passes all filters, NIL otherwise."
  (every (lambda (filter) (funcall filter message)) filters))

(defun channel-add-filter (channel filter)
  "Add a filter function to a filtered channel.
Returns the channel with the filter added."
  (if (typep channel 'filtered-channel)
      (progn
        (push filter (channel-filters channel))
        channel)
      (error "Cannot add filter to non-filtered channel")))

(defun channel-remove-filter (channel filter)
  "Remove a filter function from a filtered channel.
Returns the channel with the filter removed."
  (if (typep channel 'filtered-channel)
      (progn
        (setf (channel-filters channel)
              (remove filter (channel-filters channel)))
        channel)
      (error "Cannot remove filter from non-filtered channel")))

(defun apply-filter (channel filter-fn)
  "Apply a filter function to a channel, creating a new filtered channel.
The new channel will receive only messages that pass the filter."
  (let ((filtered-chan (make-filtered-channel 
                        :capacity (channel-capacity channel)
                        :filters (list filter-fn))))
    
    ;; Start a goroutine to forward messages
    (gogo
     (loop
       (let ((msg (<- channel)))
         (when (funcall filter-fn msg)
           (-> filtered-chan msg)))))

    filtered-chan))

;; Enhanced channel-send method for filtered channels
(defmethod channel-send :around ((channel filtered-channel) value)
  "Send a value to the filtered channel, applying filters first.
   Only sends the value if it passes all filters."
  (let ((filters (channel-filters channel)))
    (if (or (null filters)
            (pass-through-p value filters))
        (call-next-method) ; Value passes filters, send it
        nil))) ; Value doesn't pass filters, silently drop it

;; Enhanced channel-receive method for filtered channels
(defmethod channel-receive :around ((channel filtered-channel))
  "Receive a value from the filtered channel.
   Will continue attempting to receive until a value passes all filters
   or the channel is closed."
  (loop
    (let ((value (call-next-method)))
      ;; If we got a value, ensure it passes filters
      (when (or (null (channel-filters channel))
                (pass-through-p value (channel-filters channel)))
        (return value)))))

(defun channel-take! (channel &key (timeout nil))
  "Take a value from the channel, applying filters.
   Returns the value if it was received, nil otherwise.
    If TIMEOUT is provided, it will wait for the specified time before
    returning nil if no value is received."
  (bt:with-lock-held ((channel-lock-r channel))
    (when (channel-closed channel)
      (error "Channel is closed."))
    (let ((value (if timeout
                     (sb-thread:condition-wait
                      (channel-condition-wait-send channel)
                      (channel-lock-r channel) :timeout timeout)
                     (sb-thread:condition-wait (channel-condition-wait-send channel) (channel-lock-r channel)))))
      ;; Check if the value passes the filters
      (if (and value
               (pass-through-p value (channel-filters channel)))
          value
          nil))))

(defun channel-put! (channel value)
  "Put a value into the channel, applying filters.
   Returns t if the value was sent, nil otherwise."
  (if (pass-through-p value (channel-filters channel))
      (channel-send channel value)
      nil))
