;;;===============================================================
;;; File: src/core/event-propagation.lisp
;;; Event Propagation System
;;;===============================================================
(uiop:define-package :elmtui.core.event-propagation
  (:use :cl :alexandria)
  (:import-from :log4cl #:log-debug #:log-info #:log-warn)
  (:import-from :cl-styles.api  #:stylable-id)
  (:import-from :elmtui.core.event-types
                #:mouse-event
                #:ui-event
                #:ui-event-p
                #:ui-event-type
                #:ui-event-target
                #:ui-event-consumed-p
                #:key-event-p
                #:mouse-event-p
                #:stop-propagation)
  (:import-from :elmtui.view.api
                #:ui-node
                #:ui-node-parent
                #:ui-node-children)
  (:export 
   #:find-event-target
   #:find-ui-node-by-id
   #:get-ui-tree-path
   #:dispatch-event
   #:handle-event
   #:handle-capture-event
   #:handle-bubble-event))

(in-package :elmtui.core.event-propagation)

;;;-----------------------------------------------------------------------------
;;; UI Tree Traversal
;;;-----------------------------------------------------------------------------

(defun traverse-ui-tree-down (root-node visitor-fn)
  "Traverse the UI tree in a depth-first pre-order fashion, calling visitor-fn on each node.
   If visitor-fn returns non-nil, traversal of that branch is stopped.
   ROOT-NODE: The starting node.
   VISITOR-FN: A function taking a node as argument and returning t to stop traversal of that branch."
  (when root-node
    (when (funcall visitor-fn root-node)
      (return-from traverse-ui-tree-down t))
    (loop for child in (ui-node-children root-node)
          when (traverse-ui-tree-down child visitor-fn)
            return t)))

(defun find-ui-node-by-id (root-node id)
  "Finds a UI node with the given ID in the UI tree.
   ROOT-NODE: The root node of the UI tree.
   ID: The ID to search for.
   Returns the found node or nil if not found."
  (when root-node
    (if (equal (stylable-id root-node) id)
        root-node
        (loop for child in (ui-node-children root-node)
              for found = (find-ui-node-by-id child id)
              when found return found))))

(defun get-ui-tree-path (root-node target-id)
  "Returns a list of nodes from ROOT-NODE to the node with TARGET-ID.
   The first element is the root node, the last is the target node.
   Returns nil if the target node is not found."
  (when root-node
    (if (equal (stylable-id root-node) target-id)
        (list root-node)
        (loop for child in (ui-node-children root-node)
              for path = (get-ui-tree-path child target-id)
              when path return (cons root-node path)))))

(defgeneric find-event-target (event ui-tree)
  (:documentation "Finds the target UI node for an event."))

(defmethod find-event-target ((event ui-event) ui-tree)
  "Returns the target node for an event with an explicit target ID."
  (when (ui-event-target event)
    (find-ui-node-by-id ui-tree (ui-event-target event))))

(defmethod find-event-target ((event ui-event) ui-tree)
  "Finds the deepest node at the event's coordinates."
  ;; This would normally use hit testing based on coordinates,
  ;; which is more complex than we can implement here.
  ;; For now, we just use the target if specified, or return nil.
  (when (ui-event-target event)
    (find-ui-node-by-id ui-tree (ui-event-target event))))

;;;-----------------------------------------------------------------------------
;;; Event Handling
;;;-----------------------------------------------------------------------------

(defgeneric handle-event (node event phase)
  (:documentation "Handles an event at a node.
                  PHASE can be :capture, :target, or :bubble."))

(defmethod handle-event ((node null) event phase)
  ;; Default method for nil nodes
  (log-debug "Event ~A in phase ~A ignored by nil node" event phase)
  nil)

;; (defmethod handle-event ((node styled-ui-node) event phase)
;;   "Default event handler implementation for UI nodes."
;;   ;; By default, delegate to more specific handlers based on phase
;;   (case phase
;;     (:capture (handle-capture-event node event))
;;     (:target
;;      ;; For target phase, try to find a specific handler based on event type
;;      (let ((handler (get-event-handler node event)))
;;        (if handler
;;            (funcall handler node event)
;;            (log-debug "No specific handler for event ~A on target ~A"
;;                       (ui-event-type event) (stylable-id node)))))
;;     (:bubble (handle-bubble-event node event))
;;     (otherwise
;;      (log-warn "Unknown event phase: ~A" phase)
;;      nil)))

(defgeneric handle-capture-event (node event)
  (:documentation "Handles an event in the capturing phase."))

;; (defmethod handle-capture-event ((node styled-ui-node) event)
;;   "Default implementation for capture phase."
;;   ;; Default implementation does nothing during capture
;;   (log-debug "Capture phase for event ~A on node ~A"
;;              (ui-event-type event) (stylable-id node))
;;   nil)

(defgeneric handle-bubble-event (node event)
  (:documentation "Handles an event in the bubbling phase."))

;; (defmethod handle-bubble-event ((node styled-ui-node) event)
;;   "Default implementation for bubble phase."
;;   ;; Default implementation does nothing during bubble
;;   (log-debug "Bubble phase for event ~A on node ~A"
;;              (ui-event-type event) (stylable-id node))
;;   nil)

;; (defun get-event-handler (node event)
;;   "Returns a function that can handle the specific event type for this node.
;;    Looks for an :ON-<EVENT-TYPE> property in the node's 'properties' slot
;;    (assumed to be a plist) that holds a function."
;;   ;; (when (and node event (typep node 'styled-ui-node))
;;   ;;   (let* ((event-type (ui-event-type event)) ; e.g., :CLICK
;;   ;;          (handler-key (when event-type
;;   ;;                         (intern (concatenate 'string "ON-" (symbol-name event-type)) :keyword)))) ; e.g., :ON-CLICK
;;   ;;     (when handler-key
;;   ;;       ;; Assuming 'properties' is a slot in styled-ui-node that holds a plist of event handlers and other props.
;;   ;;       (if (slot-exists-p node 'properties)
;;   ;;           (let ((handler-fn (getf (slot-value node 'properties) handler-key)))
;;   ;;             (when (functionp handler-fn)
;;   ;;               handler-fn))
;;   ;;           (progn
;;   ;;             (log-warn "Node ~A of type ~A does not have a 'properties' slot. Cannot find handler for ~A."
;;   ;;                       (if (ignore-errors (stylable-id node)) ; Check if stylable-id is safe to call
;;   ;;                           (stylable-id node)
;;   ;;                           "UNKNOWN-ID")
;;   ;;                       (type-of node)
;;   ;;                       handler-key)
;;   ;;             nil)))))
;;   )

;;;-----------------------------------------------------------------------------
;;; Event Dispatch
;;;-----------------------------------------------------------------------------

(defun dispatch-event (ui-tree event)
  "Dispatches an event through the UI tree with capturing and bubbling phases.
   UI-TREE: The root node of the UI tree.
   EVENT: The event to dispatch.
   Returns t if the event was handled, nil otherwise."
  (let ((target (or (find-event-target event ui-tree)
                    ui-tree))) ; Default to root if no target found
    
    ;; Find the path from root to target
    (let ((path (get-ui-tree-path ui-tree (stylable-id target))))
      (when path
        ;; Capturing phase: root -> target (excluding target)
        (log-debug "Starting capture phase for event: ~A" (ui-event-type event))
        (loop for node in path
              for i from 0 below (1- (length path)) ; Stop before target
              do (handle-event node event :capture)
              until (ui-event-consumed-p event))
        
        ;; Target phase: only if event not consumed during capture
        (unless (ui-event-consumed-p event)
          (log-debug "Target phase for event: ~A on node: ~A" 
                     (ui-event-type event) (stylable-id target))
          (handle-event target event :target))
        
        ;; Bubbling phase: target -> root (excluding target, in reverse order)
        (unless (ui-event-consumed-p event)
          (log-debug "Starting bubble phase for event: ~A" (ui-event-type event))
          (loop for node in (reverse path)
                for i from 0 below (1- (length path)) ; Stop before root (which is now last)
                do (handle-event node event :bubble)
                until (ui-event-consumed-p event)))
        
        ;; Return whether the event was consumed
        (ui-event-consumed-p event)))))
