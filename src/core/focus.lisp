;;;===============================================================
;;; File: src/core/focus/manager.lisp
;;; Consolidated Focus Management System
;;;
;;; This is a consolidated version of the focus management system that
;;; combines functionality from:
;;;   - src/core/focus-manager.lisp (now in src/core/focus/legacy/)
;;;   - src/core/keymap/focus-integration.lisp (now in src/core/focus/legacy/)
;;;   - src/core/focus/directional.lisp (functionality merged, file removed)
;;;   - src/core/focus/context.lisp (functionality merged, file removed)
;;;===============================================================
(uiop:define-package :elmtui.core.focus
  (:use :cl :log4cl)
  (:import-from :cl-styles.api
                #:stylable-id) ; Only import what's actually there
  ;; (:import-from :elmtui.core.keymap.event-integration
  ;;               #:handle-key-event
  ;;               #:handle-key-binding)
  (:import-from :elmtui.view.position ; Import from our new module
                #:element-position
                #:make-element-position
                #:element-position-x
                #:element-position-y
                #:element-position-width
                #:element-position-height
                #:element-position-right
                #:element-position-bottom
                #:element-position-center-x
                #:element-position-center-y
                #:element-grid-coordinates
                #:make-element-grid-coordinates
                #:element-grid-coordinates-row
                #:element-grid-coordinates-col
                #:element-grid-coordinates-row-span
                #:element-grid-coordinates-col-span
                #:direction-to-position
                #:find-nearest-in-direction)
  (:import-from :elmtui.core.event-types
                #:key-event
                #:key-event-p
                #:key-event-type
                #:key-event-key
                #:key-event-modifiers)

  (:import-from :elmtui.state.api
                #:state-ref)
  (:import-from :cl-state.core
                #:application-state)
  ;; Imports for keymap integration (from legacy focus-integration.lisp)
  (:import-from :elmtui.keymaps
   #:key-event->normalized-key
   #:keymap-context-name
   #:deactivate-context
   #:activate-context
   :normalized-key-key      ; Added for handle-default-navigation-keys
                :normalized-key-modifiers ; Added for handle-default-navigation-keys
   :keymap-bindings         ; Added for list-active-keybindings
                :normalized-key->string  ; Added for list-active-keybindings
   :keymap-context
                :current-context
   :lookup-binding
                :*global-keymap-context*
   :*registry*
                :*contexts*
   :*active-contexts*
                :add-keybinding
   :resolve-keymap-reference
                :make-keymap-context
   :add-keymap-to-context
                :find-context


   :keymap-context-keymaps
                :keymap-context-parent

                )
  (:import-from :elmtui.core.event-async
   :dispatch-event-async) ; Added for handle-key-binding

  (:export
   ;; Focus manager struct
   #:focus-manager
   #:make-focus-manager
   #:focus-manager-current-focus
   #:focus-manager-focusable-elements
   #:focus-manager-focus-history
   #:focus-manager-focus-ring-dirty-p
   #:focus-manager-active-focus-context
   #:focus-manager-context-data

   ;; Core focus functions
   #:recalculate-focusable-elements
   #:set-focus
   #:get-next-focusable
   #:get-previous-focusable
   #:clear-focus
   #:request-focus
   #:get-current-focus
   #:focus-previous-from-history
   #:collect-focusable-elements
   #:collect-focusable-ids

   ;; Focus Context Management
   #:register-focus-context
   #:activate-focus-context
   #:get-context-last-focus

   ;; Tab navigation
   #:tab-navigate
   #:handle-tab-navigation

   ;; Directional navigation
   #:navigate-up
   #:navigate-down
   #:navigate-left
   #:navigate-right

   ;; Event handling
   #:handle-focus-message ; Added from legacy focus-manager
   ;; #:handle-key-event ; Added from legacy focus-integration
   #:handle-key-event-for-component
   ;; #:handle-key-binding ; Added from legacy focus-integration
   #:handle-navigation-keys
   #:handle-default-navigation-keys ; Added from legacy focus-integration

   ;; Keymap integration helpers
   #:find-component-keymap-context ; Added from legacy focus-integration
   #:list-active-keybindings ; Added from legacy focus-integration
   ))

(in-package :elmtui.core.focus)

;;;-----------------------------------------------------------------------------
;;; Helper Structures
;;;-----------------------------------------------------------------------------

(defstruct focus-context-data
  "Stores data for a specific focus context."
  (last-focus nil :type (or null keyword symbol))) ; Last focused element in this context

;;;-----------------------------------------------------------------------------
;;; Focus Manager Structure
;;;-----------------------------------------------------------------------------

(defstruct (focus-manager (:constructor %make-focus-manager))
  "Manages focus state and navigation in the application."
  (current-focus nil :type (or null keyword symbol))    ; ID of currently focused widget
  (focusable-elements nil :type list)                   ; Ordered list of focusable IDs
  (focus-history nil :type list)                        ; Stack of previous focus IDs
  (focus-ring-dirty-p t :type boolean)                  ; Whether focusable-elements needs recalculation
  (context-data (make-hash-table :test 'equal) :type hash-table) ; Stores context-id -> focus-context-data struct
  (active-focus-context nil :type (or null keyword symbol)))   ; ID of the currently active focus context

(defun make-focus-manager (&key initial-focus initial-context-ids initial-active-context)
  "Create a new focus manager.
   INITIAL-FOCUS: The ID of the element to focus initially.
   INITIAL-CONTEXT-IDS: A list of context IDs to register initially.
   INITIAL-ACTIVE-CONTEXT: The ID of the context to make active initially."
  (let ((manager (%make-focus-manager :current-focus initial-focus)))
    (when initial-context-ids
      (dolist (context-id initial-context-ids)
        (register-focus-context manager context-id)))
    (when (and initial-active-context (gethash initial-active-context (focus-manager-context-data manager)))
      (setf (focus-manager-active-focus-context manager) initial-active-context)
      ;; If there's an initial focus and an active context, store it as last-focus for that context
      (when initial-focus
        (let ((data (gethash initial-active-context (focus-manager-context-data manager))))
          (when data (setf (focus-context-data-last-focus data) initial-focus)))))
    manager))

;;;-----------------------------------------------------------------------------
;;; Focus Context Management
;;;-----------------------------------------------------------------------------

(defun register-focus-context (focus-manager context-id)
  "Register a new focus context with the focus manager."
  (unless (gethash context-id (focus-manager-context-data focus-manager))
    (setf (gethash context-id (focus-manager-context-data focus-manager))
          (make-focus-context-data)))

  ;; If this is the first context registered and no active context is set, make it active.
  (unless (focus-manager-active-focus-context focus-manager)
    (setf (focus-manager-active-focus-context focus-manager) context-id))

  context-id)

(defun activate-focus-context (focus-manager context-id &key app-state)
  "Activate a focus context in the focus manager.
   Saves current focus to the outgoing context's last-focus.
   Restores focus from the incoming context's last-focus if available."
  (let ((current-active-context (focus-manager-active-focus-context focus-manager)))
    (when (and context-id (gethash context-id (focus-manager-context-data focus-manager)))
      (unless (eq current-active-context context-id)
        ;; Save current focus to the last-focus of the outgoing active context (if any)
        (when current-active-context
          (let ((outgoing-data (gethash current-active-context (focus-manager-context-data focus-manager))))
            (when outgoing-data
              (setf (focus-context-data-last-focus outgoing-data)
                    (focus-manager-current-focus focus-manager)))))

        ;; Set the new active context
        (setf (focus-manager-active-focus-context focus-manager) context-id)
        (setf (focus-manager-focus-ring-dirty-p focus-manager) t) ; Recalculate focusable elements for new context potentially

        ;; Restore focus from the last-focus of the new active context (if any)
        (let* ((incoming-data (gethash context-id (focus-manager-context-data focus-manager)))
               (last-focus-in-new-context (when incoming-data (focus-context-data-last-focus incoming-data))))
          (if last-focus-in-new-context
              (set-focus focus-manager last-focus-in-new-context :app-state app-state)
              (clear-focus focus-manager :app-state app-state))) ; Or clear focus if no last focus known
        context-id))))

(defun get-context-last-focus (focus-manager context-id)
  "Returns the last known focused element ID for the given context-id."
  (let ((data (gethash context-id (focus-manager-context-data focus-manager))))
    (when data
      (focus-context-data-last-focus data))))

;;;-----------------------------------------------------------------------------
;;; Core Focus Functions
;;;-----------------------------------------------------------------------------

(defun get-current-focus (focus-manager)
  "Returns the ID of the currently focused element."
  (focus-manager-current-focus focus-manager))

(defgeneric component-gained-focus (component-id app-state)
  (:documentation "Called when a component gains focus.")
  (:method (component-id app-state)
    (log-debug "Component ~A gained focus" component-id)
    nil))

(defgeneric component-lost-focus (component-id app-state)
  (:documentation "Called when a component loses focus.")
  (:method (component-id app-state)
    (log-debug "Component ~A lost focus" component-id)
    nil))

(defun set-focus (focus-manager element-id &key app-state)
  "Set focus to ELEMENT-ID. Notifies the focused component and keymap system.
   Also updates the last-focus for the active context."
  (let ((previous-focus (focus-manager-current-focus focus-manager)))
    (unless (eq previous-focus element-id)
      ;; Notify component that lost focus
      (when (and previous-focus app-state)
        (component-lost-focus previous-focus app-state))

      ;; Update focus manager state
      (when previous-focus
        (pushnew previous-focus (focus-manager-focus-history focus-manager)))
      (setf (focus-manager-current-focus focus-manager) element-id)

      ;; Update last-focus for the active context
      (let ((active-context-id (focus-manager-active-focus-context focus-manager)))
        (when active-context-id
          (let ((context-data (gethash active-context-id (focus-manager-context-data focus-manager))))
            (when context-data
              (setf (focus-context-data-last-focus context-data) element-id)))))

      ;; Notify component that gained focus
      (when (and element-id app-state)
        (component-gained-focus element-id app-state))

      element-id)))

(defun clear-focus (focus-manager &key app-state)
  "Clears the current focus."
  (set-focus focus-manager nil :app-state app-state))


;;;-----------------------------------------------------------------------------
;;; Focus Navigation Functions
;;;-----------------------------------------------------------------------------

(defun get-next-focusable (focus-manager current-id)
  "Returns the ID of the next focusable element after CURRENT-ID.
   If CURRENT-ID is nil or not found, returns the first focusable element.
   Wraps around to the beginning if at the end."
  (let ((focusable (focus-manager-focusable-elements focus-manager)))
    (when focusable
      (if current-id
          (let ((pos (position current-id focusable)))
            (if pos
                (nth (mod (1+ pos) (length focusable)) focusable)
                (first focusable)))
          (first focusable)))))

(defun get-previous-focusable (focus-manager current-id)
  "Returns the ID of the previous focusable element before CURRENT-ID.
   If CURRENT-ID is nil or not found, returns the last focusable element.
   Wraps around to the end if at the beginning."
  (let ((focusable (focus-manager-focusable-elements focus-manager)))
    (when focusable
      (if current-id
          (let ((pos (position current-id focusable)))
            (if pos
                (nth (mod (1- pos) (length focusable)) focusable)
                (first (last focusable))))
          (first (last focusable))))))

(defun request-focus (focus-manager target-id &key app-state)
  "Requests focus for a specific element.
   When used with app-state, sets focus immediately."
  (when focus-manager
    (set-focus focus-manager target-id :app-state app-state)))

(defun focus-previous-from-history (focus-manager &key app-state)
  "Sets focus to the previous element in the focus history."
  (let ((history (focus-manager-focus-history focus-manager)))
    (when history
      (let ((prev-focus (pop (focus-manager-focus-history focus-manager))))
        (setf (focus-manager-focus-history focus-manager) history)
        (set-focus focus-manager prev-focus :app-state app-state)))))

;;;-----------------------------------------------------------------------------
;;; Tab Navigation
;;;-----------------------------------------------------------------------------

(defun tab-navigate (focus-manager direction &key app-state)
  "Navigate through focusable elements using Tab key.
   DIRECTION can be :forward or :backward."
  (let ((current-focus (focus-manager-current-focus focus-manager))
        (next-focus nil))

    ;; Determine the next focus based on direction
    (setf next-focus
          (case direction
            (:forward (get-next-focusable focus-manager current-focus))
            (:backward (get-previous-focusable focus-manager current-focus))
            (otherwise current-focus)))

    ;; Set focus if it changed
    (when (and next-focus (not (eq next-focus current-focus)))
      (set-focus focus-manager next-focus :app-state app-state))))

(defun handle-tab-navigation (focus-manager event &key app-state)
  "Handles Tab and Shift+Tab navigation events."
  (when (key-event-p event)
    (let ((key (key-event-key event))
          (modifiers (key-event-modifiers event)))

      (cond
        ;; Tab - focus next element
        ((and (eq key :tab) (not (member :shift modifiers)))
         (tab-navigate focus-manager :forward :app-state app-state)
         t)

        ;; Shift-Tab - focus previous element
        ((and (eq key :tab) (member :shift modifiers))
         (tab-navigate focus-manager :backward :app-state app-state)
         t)

        ;; Other keys - not handled
        (t nil)))))

;;;-----------------------------------------------------------------------------
;;; Directional Navigation (Integrated from directional.lisp)
;;;-----------------------------------------------------------------------------

;; Helper: Element Position Registry (can be part of focus-manager or separate)
;; For now, let's assume element positions are stored elsewhere or passed in.
;; If we integrate fully, focus-manager might need a slot for this.
;; For this integration, we'll assume functions like `get-element-position`
;; and `get-all-element-positions` are available and work on the UI tree or a registry.

(defun calculate-nav-distance (rect1-x rect1-y rect2-x rect2-y direction)
  "Calculate a weighted distance score for navigation.
   Prefer elements that are directly in the specified direction.
   Returns a weighted score considering both primary direction and orthogonal deviation."
  (let* ((dx (- rect2-x rect1-x))
         (dy (- rect2-y rect1-y))
         (dx-abs (abs dx))
         (dy-abs (abs dy))
         ;; Primary distance along the axis of navigation
         (primary-dist (case direction
                         ((:up :down) dy-abs)
                         ((:left :right) dx-abs)
                         (otherwise most-positive-fixnum))) ; Handle unexpected directions
         ;; Secondary distance perpendicular to the axis of navigation
         (secondary-dist (case direction
                           ((:up :down) dx-abs)
                           ((:left :right) dy-abs)
                           (otherwise most-positive-fixnum)))) ; Handle unexpected directions
    ;; ... rest of your distance calculation logic using primary-dist and secondary-dist ...
    ;; For example, a weighted sum or a more complex heuristic:
    (if (or (= primary-dist most-positive-fixnum)
            (= secondary-dist most-positive-fixnum))
        most-positive-fixnum ; Propagate if direction was invalid
        (+ (* primary-dist 2) secondary-dist)))) ; Example heuristic

(defun find-grid-adjacent (source-grid-coords direction ui-tree)
  "Placeholder for finding an adjacent element in a grid layout.
  SOURCE-GRID-COORDS: An element-grid-coordinates struct.
  DIRECTION: One of :UP, :DOWN, :LEFT, :RIGHT.
  UI-TREE: The current UI tree.
  Returns an element node or NIL."
  (let* ( ;; TODO this cant be right?
         (next-in-ui-tree
           (find-nearest-in-direction
            ui-tree
            (element-grid-coordinates-col source-grid-coords)
            direction)))
    (when next-in-ui-tree
      (let ((next-coords (element-grid-coordinates next-in-ui-tree)))
        ;; Check if the next element is actually adjacent in the grid
        (when (and next-coords
                   (case direction
                     (:up (= (element-grid-coordinates-row next-coords)
                             (1- (element-grid-coordinates-row source-grid-coords))))
                     (:down (= (element-grid-coordinates-row next-coords)
                               (1+ (element-grid-coordinates-row source-grid-coords))))
                     (:left (= (element-grid-coordinates-col next-coords)
                               (1- (element-grid-coordinates-col source-grid-coords))))
                     (:right (= (element-grid-coordinates-col next-coords)
                                (1+ (element-grid-coordinates-col source-grid-coords))))))
          next-in-ui-tree)))))


(defun find-closest-in-direction (focus-manager source-id direction ui-tree)
  "Finds the closest element to source-id in the specified direction.
   UI-TREE is needed to get element positions and properties."
  ;; Early return if we have no source
  (unless source-id (return-from find-closest-in-direction nil))

  (let* ((source-element (find source-id (collect-focusable-elements ui-tree) :key #'stylable-id :test #'equal))
         (source-pos (when source-element (element-position source-element)))
         (source-grid-coords (when source-element (element-grid-coordinates source-element))))

    ;; Early return if we can't determine the source position
    (unless source-pos
      (log-debug "Source element ~A has no position data, cannot navigate" source-id)
      (return-from find-closest-in-direction nil))

    ;; Extract source position details for easier access
    (let* ((source-x (getf source-pos :x 0))
           (source-y (getf source-pos :y 0))
           (source-width (getf source-pos :width 1))
           (source-height (getf source-pos :height 1))
           (source-center-x (+ source-x (/ source-width 2)))
           (source-center-y (+ source-y (/ source-height 2)))
           (candidates '()))

      ;; Try grid navigation first if we have grid coordinates
      (when source-grid-coords
        (log-debug "Attempting grid navigation for ~A with coords ~A" source-id source-grid-coords)
        (let ((adj (find-grid-adjacent source-grid-coords direction ui-tree)))
          (when adj
            (log-debug "Found grid adjacent element: ~A" (stylable-id adj))
            (return-from find-closest-in-direction (stylable-id adj)))))

      ;; If grid navigation failed or wasn't applicable, try spatial navigation
      (log-debug "Performing spatial navigation from ~A in direction ~A" source-id direction)

      ;; Collect all potential candidates in the specified direction
      (dolist (el (focus-manager-focusable-elements focus-manager))
        (unless (equal el source-id) ; Don't consider the source itself
          (let* ((target-element (find el (collect-focusable-elements ui-tree) :key #'stylable-id :test #'equal))
                 (pos (when target-element (element-position target-element))))
            (when pos ; Only consider elements with position data
              (let* ((target-x (getf pos :x 0))
                     (target-y (getf pos :y 0))
                     (target-width (getf pos :width 1))
                     (target-height (getf pos :height 1))
                     (target-center-x (+ target-x (/ target-width 2)))
                     (target-center-y (+ target-y (/ target-height 2))))

                ;; Check if the target is in the correct direction
                (case direction
                  (:up
                   (when (< target-center-y source-center-y) ; Target is above source
                     ;; Check for horizontal alignment/overlap
                     (when (or
                            ;; Source center is within target width
                            (and (<= target-x source-center-x)
                                 (>= (+ target-x target-width) source-center-x))
                            ;; Target center is within source width
                            (and (<= source-x target-center-x)
                                 (>= (+ source-x source-width) target-center-x))
                            ;; Partial overlap between source and target
                            (and (< target-x (+ source-x source-width))
                                 (> (+ target-x target-width) source-x)))
                       (push (list el (calculate-nav-distance
                                       source-center-x source-center-y
                                       target-center-x target-center-y
                                       direction))
                             candidates))))

                  (:down
                   (when (> target-center-y source-center-y) ; Target is below source
                     (when (or
                            (and (<= target-x source-center-x)
                                 (>= (+ target-x target-width) source-center-x))
                            (and (<= source-x target-center-x)
                                 (>= (+ source-x source-width) target-center-x))
                            (and (< target-x (+ source-x source-width))
                                 (> (+ target-x target-width) source-x)))
                       (push (list el (calculate-nav-distance
                                       source-center-x source-center-y
                                       target-center-x target-center-y
                                       direction))
                             candidates))))

                  (:left
                   (when (< target-center-x source-center-x) ; Target is left of source
                     (when (or
                            ;; Source center is within target height
                            (and (<= target-y source-center-y)
                                 (>= (+ target-y target-height) source-center-y))
                            ;; Target center is within source height
                            (and (<= source-y target-center-y)
                                 (>= (+ source-y source-height) target-center-y))
                            ;; Partial overlap between source and target
                            (and (< target-y (+ source-y source-height))
                                 (> (+ target-y target-height) source-y)))
                       (push (list el (calculate-nav-distance
                                       source-center-x source-center-y
                                       target-center-x target-center-y
                                       direction))
                             candidates))))

                  (:right
                   (when (> target-center-x source-center-x) ; Target is right of source
                     (when (or
                            (and (<= target-y source-center-y)
                                 (>= (+ target-y target-height) source-center-y))
                            (and (<= source-y target-center-y)
                                 (>= (+ source-y source-height) target-center-y))
                            (and (< target-y (+ source-y source-height))
                                 (> (+ target-y target-height) source-y)))
                       (push (list el (calculate-nav-distance
                                       source-center-x source-center-y
                                       target-center-x target-center-y
                                       direction))
                             candidates))))))))))

      ;; Sort candidates by distance score (lower is better)
      (when candidates
        (let ((sorted-candidates (sort candidates #'< :key #'second)))
          (log-debug "Found ~D candidate(s) for navigation in direction ~A from ~A"
                     (length sorted-candidates) direction source-id)
          (log-debug "Best candidate: ~A with score ~A"
                     (first (first sorted-candidates))
                     (second (first sorted-candidates)))
          (first (first sorted-candidates)))))))

(defun navigate-direction (focus-manager direction &key app-state ui-tree)
  "Navigate focus in a spatial direction (one of :up, :down, :left, :right).
   UI-TREE is required for spatial/grid navigation."
  (let ((current-focus (focus-manager-current-focus focus-manager)))
    (unless current-focus
      (log-debug "No current focus, cannot navigate in direction: ~A" direction)
      (return-from navigate-direction nil))

    (let ((next-focus nil))
      ;; Attempt spatial navigation if we have a UI tree
      (if ui-tree
          (progn
            (log-debug "Attempting directional navigation from ~A in direction ~A" current-focus direction)
            (setf next-focus (find-closest-in-direction focus-manager current-focus direction ui-tree))
            (if next-focus
                (log-debug "Found next focus target: ~A" next-focus)
                (log-debug "No suitable target found in direction: ~A" direction)))

          ;; Fall back to simple tab order if no UI tree is provided
          (progn
            (log-warn "UI Tree not provided for directional navigation, falling back to tab order.")
            (setf next-focus
                  (case direction
                    ((:up :left) (get-previous-focusable focus-manager current-focus))
                    ((:down :right) (get-next-focusable focus-manager current-focus))
                    (otherwise current-focus)))))

      ;; Set focus to the new target if found
      (when (and next-focus (not (eq next-focus current-focus)))
        (log-debug "Setting focus from ~A to ~A" current-focus next-focus)
        (set-focus focus-manager next-focus :app-state app-state)
        t))))

(defun navigate-up (focus-manager &key app-state ui-tree)
  "Navigate focus upward."
  (navigate-direction focus-manager :up :app-state app-state :ui-tree ui-tree))

(defun navigate-down (focus-manager &key app-state ui-tree)
  "Navigate focus downward."
  (navigate-direction focus-manager :down :app-state app-state :ui-tree ui-tree))

(defun navigate-left (focus-manager &key app-state ui-tree)
  "Navigate focus to the left."
  (navigate-direction focus-manager :left :app-state app-state :ui-tree ui-tree))

(defun navigate-right (focus-manager &key app-state ui-tree)
  "Navigate focus to the right."
  (navigate-direction focus-manager :right :app-state app-state :ui-tree ui-tree))

;; Potentially, `register-element-position`, `unregister-element-position`,
;; and `define-grid-navigation` would be utility functions called by the view/widget system
;; to populate the necessary :position and :grid-coordinates properties on elements, rather than
;; being part of the focus manager itself. The focus manager would then read these properties.
;; For now, these are exported if direct manipulation is needed, but ideally the UI elements
;; themselves would declare their layout information.

;;;-----------------------------------------------------------------------------
;;; Event Handling
;;;-----------------------------------------------------------------------------

(defun handle-key-event-for-component (focus-manager key-event component-id &key app-state)
  "Handle a key event for a specific component.
   Returns T if the event was handled, NIL otherwise."
  (log-debug "Unhandled key event: ~A" key-event)
  (let ((normalized-key (key-event->normalized-key key-event)))
    (when normalized-key
      (let ((focused-element (focus-manager-current-focus focus-manager))
            (keymap-context (current-context))
            (normalized-key-modifiers (normalized-key-modifiers normalized-key))
            (binding (lookup-binding normalized-key)))
        (log-debug "component-id: ~A Key event: ~A, normalized: ~A, binding: ~A" component-id key-event normalized-key binding )
        (log-debug "Keymap context: ~A modifiers: ~A focused ~A" keymap-context normalized-key-modifiers focused-element)
        (when binding
          (handle-key-binding binding :app-state app-state)
          t))))
  ;; In a full implementation, this would look up component keymap
  ;; and dispatch to appropriate handler
  nil)

(defun handle-navigation-keys (focus-manager key-event &key app-state ui-tree)
  "Handle standard navigation keys like arrows, etc.
   UI-TREE is passed down for directional navigation."
  (when (key-event-p key-event)
    (let ((key (key-event-key key-event)))
      (case key
        (:up (navigate-up focus-manager :app-state app-state :ui-tree ui-tree) t)
        (:down (navigate-down focus-manager :app-state app-state :ui-tree ui-tree) t)
        (:left (navigate-left focus-manager :app-state app-state :ui-tree ui-tree) t)
        (:right (navigate-right focus-manager :app-state app-state :ui-tree ui-tree) t)
        (otherwise nil)))))

(defun handle-focus-message (focus-manager message &key app-state)
  "Handles focus-related messages.
   Returns a plist describing the state changes to be made, or NIL if no changes.
   This function now operates directly on the focus-manager instance passed to it,
   and expects app-state for context when calling set-focus or other operations
   that might interact with the broader application state (e.g., component-gained/lost-focus hooks).
   It returns T if a message was handled and resulted in a change, NIL otherwise."
  (let ((normalized-message (if (listp message) message
                                (et.keymaps:key-event->normalized-key message))))

    (if (not (listp normalized-message))
        nil ; Not a list-based message
        (let ((msg-type (first normalized-message))
              (changed-p nil))
          (case msg-type
            (:request-focus
             (let ((widget-id (getf (rest normalized-message) :widget-id)))
               (when widget-id
                 (set-focus focus-manager widget-id :app-state app-state)
                 (setf changed-p t))))

            (:focus-next
             (let* ((current-focus (focus-manager-current-focus focus-manager))
                    (next-focus (get-next-focusable focus-manager current-focus)))
               (when next-focus
                 (set-focus focus-manager next-focus :app-state app-state)
                 (setf changed-p t))))

            (:focus-previous
             (let* ((current-focus (focus-manager-current-focus focus-manager))
                    (prev-focus (get-previous-focusable focus-manager current-focus)))
               (when prev-focus
                 (set-focus focus-manager prev-focus :app-state app-state)
                 (setf changed-p t))))

            (:update-focusable-ids ; This message type might be re-evaluated or handled by recalculate-focusable-elements
             (let* ((new-ids (getf (rest normalized-message) :ids))
                    (current-focus (focus-manager-current-focus focus-manager)))
               (setf (focus-manager-focusable-elements focus-manager) new-ids)
               (setf (focus-manager-focus-ring-dirty-p focus-manager) nil)
               ;; If current focus is no longer valid or nil, set to first of new-ids
               (when (or (not (member current-focus new-ids :test #'equal))
                         (and (null current-focus) new-ids))
                 (let ((new-focus-target (first new-ids)))
                   (set-focus focus-manager new-focus-target :app-state app-state)))
               (setf changed-p t))))
          changed-p))))

;;;-----------------------------------------------------------------------------
;;; Keymap Integration & Top-Level Key Event Handling (from legacy focus-integration.lisp)
;;;-----------------------------------------------------------------------------

;; Copied from legacy/focus-integration.lisp and adapted
(defun find-component-keymap-context (component-id app-state)
  "Find or create a keymap context for a component.
   CONTROLS keymap activation based on widget model keymap definitions."
  (when (and component-id app-state)
    (let* ((component-path (list :widgets component-id)) ; This path might need to be more flexible
           (widget-model (state-ref app-state component-path)))
      (when widget-model
        (let ((keymap-id (getf widget-model :keymap-id))
              (active-keymap (getf widget-model :active-keymap)))
          (cond
            (active-keymap ; Direct keymap reference in widget model
             (let ((context (make-keymap-context :name component-id)))
               (add-keymap-to-context context active-keymap) ; Using add-keymap-to-context helper
               (when *global-keymap-context*
                 (setf (keymap-context-parent context) *global-keymap-context*))
               context))
            (keymap-id ; Named keymap reference
             (let ((found-ctx (find-context keymap-id)))
               (if found-ctx
                   found-ctx
                   (progn
                     (log-warn "Keymap context \'~A\' not found for component \'~A\'."
                               keymap-id component-id)
                     nil))))
            (t nil)))))))

;; Adapted from legacy component-gained-focus / component-lost-focus methods
(defmethod component-gained-focus :after ((component-id t) (app-state application-state))
  "Called when a component gains focus. Activates its keymap context."
  (let ((context (find-component-keymap-context component-id app-state)))
    (when context
      (activate-context context)
      (log-debug "Activated keymap context \'~A\' for component ~A" (keymap-context-name context) component-id))))

(defmethod component-lost-focus :after ((component-id t) (app-state application-state))
  "Called when a component loses focus. Deactivates its keymap context."
  (let ((context (find-component-keymap-context component-id app-state)))
    (when context
      (deactivate-context context)
      (log-debug "Deactivated keymap context \'~A\' for component ~A" (keymap-context-name context) component-id))))



;; Copied from legacy/focus-integration.lisp and adapted
(defmethod handle-key-binding (binding &key app-state)
  "Execute the action associated with a key binding."
  (log-debug "Handling key binding: ~A" binding)
  (let ((type (getf binding :type))
        (target (getf binding :target)))
    (case type
      (:action
       (when (fboundp target)
         (funcall target app-state)
         t))
      (:message
       (dispatch-event-async target) ; Assuming dispatch-event-async is available
       t)
      (t
       (log-warn "Unknown binding type: ~A" type)
       nil))))

;; Copied from legacy/focus-integration.lisp and adapted
;; This is a more specific version of the handle-key-event-for-component that was a stub
(defun handle-key-event-for-focused-component (focus-manager key-event &key app-state)
  "Handle a key event for the currently focused component.
   Looks up keybindings in the component's active keymap context.
   Returns T if the event was handled, NIL otherwise."
  (let* ((current-focus-id (focus-manager-current-focus focus-manager))
         (component-context (when current-focus-id (find-component-keymap-context current-focus-id app-state)))
         (active-context (if component-context component-context (current-context)))) ; Fallback to global/current context
    (when active-context
      (log-debug "Handling key event for component ~A in context ~A" current-focus-id (keymap-context-name active-context))
      (let* ((normalized-key (key-event->normalized-key key-event))
             (binding (when normalized-key (elmtui.keymaps:lookup-binding-in active-context normalized-key :include-parents t))))
        (when binding
          (handle-key-binding binding :app-state app-state))))))

;; Copied from legacy/focus-integration.lisp and adapted
(defun handle-default-navigation-keys (focus-manager key-event &key app-state ui-tree)
  "Handle standard navigation keys including arrows, tab, escape, etc.
   Provides a comprehensive set of default navigation behaviors.
   Returns T if the event was handled, NIL otherwise."
  (when (key-event-p key-event)
    (let* ((key (key-event-key key-event))
           (modifiers (key-event-modifiers key-event)))

      (cond
        ;; Arrow Keys - Directional Navigation
        ((eq key :up)
         (navigate-up focus-manager :app-state app-state :ui-tree ui-tree)
         t)
        ((eq key :down)
         (navigate-down focus-manager :app-state app-state :ui-tree ui-tree)
         t)
        ((eq key :left)
         (navigate-left focus-manager :app-state app-state :ui-tree ui-tree)
         t)
        ((eq key :right)
         (navigate-right focus-manager :app-state app-state :ui-tree ui-tree)
         t)

        ;; Tab Navigation
        ((and (eq key :tab) (not (member :shift modifiers)))
         (tab-navigate focus-manager :forward :app-state app-state)
         t)
        ((and (eq key :tab) (member :shift modifiers))
         (tab-navigate focus-manager :backward :app-state app-state)
         t)

        ;; Escape - Could clear focus or go back depending on app needs
        ((eq key :escape)
         ;; This implementation clears focus, but could be customized per app
         (clear-focus focus-manager :app-state app-state)
         t)

        ;; Home/End - Could navigate to first/last focusable
        ((eq key :home)
         (when (focus-manager-focusable-elements focus-manager)
           (set-focus focus-manager (first (focus-manager-focusable-elements focus-manager)) :app-state app-state)
           t))
        ((eq key :end)
         (when (focus-manager-focusable-elements focus-manager)
           (set-focus focus-manager (first (last (focus-manager-focusable-elements focus-manager))) :app-state app-state)
           t))

        ;; Enter/Space - Could be handled by application-specific code
        ;; Typically trigger an action on the focused element

        ;; No match - not handled
        (t nil)))
    ;; Not a key event
    nil))

;; Top-level key event handler, adapted from legacy focus-integration.lisp
(defmethod handle-key-event (focus-manager key-event &key app-state ui-tree)
  "Handle a key event with focus awareness.
   1. Routes the event to the focused component's keymap.
   2. If not handled, tries default navigation keys (Tab, Arrows).
   3. If still not handled, could try global keybindings (though current-context handles this).
   UI-TREE is passed for directional navigation."
  (log-debug "Handling key event: ~A, Current Focus: ~A" key-event (focus-manager-current-focus focus-manager))
  (cond
    ;; If there's a focused component, try its specific keymap first
    ((and (focus-manager-current-focus focus-manager)
          (handle-key-event-for-focused-component focus-manager key-event :app-state app-state))
     t) ; Event handled by focused component

    ;; If not handled by component, or no component focused, try default navigation
    ((handle-default-navigation-keys focus-manager key-event :app-state app-state :ui-tree ui-tree)
     t) ; Event handled by default navigation

    ;; Optionally, could add a call to a global key handler here if not covered by current-context logic
    ;; (t (handle-global-key-event key-event :app-state app-state))

    (t nil))) ; Event not handled

;; Copied from legacy/focus-integration.lisp and adapted
(defun list-active-keybindings (focus-manager &key component-id app-state)
  "List all active keybindings for a component or globally.
   Returns a list of plists with :key, :description, :type and :source fields."
  (let* ((context (if component-id
                      (find-component-keymap-context component-id app-state)
                      (current-context))) ; Or perhaps the active focus context's associated keymap?
         (result nil))
    (labels ((collect-from-context (ctx)
               (when ctx
                 (dolist (km-ref (keymap-context-keymaps ctx))
                   (let ((keymap (resolve-keymap-reference km-ref)))
                     (when keymap
                       (maphash
                        (lambda (key binding)
                          (push (list :key (if (listp key)
                                               (format nil "~{~A~^ ~}" (mapcar #'normalized-key->string key))
                                               (normalized-key->string key))
                                      :description (getf binding :description "")
                                      :type (getf binding :type)
                                      :source (or (getf binding :source)
                                                  (keymap-context-name ctx)
                                                  :unknown))
                                result))
                        (keymap-bindings keymap)))))
                 ;; Include parent contexts
                 (let ((parent (keymap-context-parent ctx)))
                   (when parent (collect-from-context parent))))))
      (when context (collect-from-context context)))
    (log-info "Current Focus: ~A Active KeyBindings:" (focus-manager-current-focus focus-manager))
    (mapcar (lambda (k )
              (log-info "=     | ~A" k ))
            result)
    result))

;;;-----------------------------------------------------------------------------
;;; Focusable Elements Collection
;;;-----------------------------------------------------------------------------

(defun collect-focusable-elements (ui-tree)
  "Traverses the UI tree and collects all elements that are focusable.
   Returns a list of element objects that can receive focus."
  ;; This implementation will depend on the structure of your UI tree
  ;; Here's a simplified version that assumes a nested structure with :focusable property
  (labels ((collect-recursive (node result)
             (if (null node)
                 result
                 (let ((new-result
                         (if (and (getf node :focusable) (getf node :id))
                             (cons node result)
                             result)))
                   (if (listp (getf node :children))
                       (reduce #'collect-recursive (getf node :children) :initial-value new-result)
                       new-result)))))
    (collect-recursive ui-tree nil)))

(defun collect-focusable-ids (ui-tree)
  "Traverses the UI tree and collects IDs of all elements that are focusable.
   Returns a list of element IDs that can receive focus."
  (mapcar #'stylable-id (collect-focusable-elements ui-tree)))

(defun recalculate-focusable-elements (focus-manager ui-tree &key app-state preserve-focus)
  "Recalculates the list of focusable elements based on the current UI tree.
   Returns the updated list. If preserve-focus is T, tries to maintain current focus.
   If the current focus is no longer valid, either clears focus or sets to the first element."
  (let* ((old-current-focus (focus-manager-current-focus focus-manager))
         (new-focusable-elements (collect-focusable-ids ui-tree)))

    ;; Update the focus-manager with the new elements
    (setf (focus-manager-focusable-elements focus-manager) new-focusable-elements)
    (setf (focus-manager-focus-ring-dirty-p focus-manager) nil)

    ;; Check if we need to update the current focus
    (unless (or (null old-current-focus)
                (and preserve-focus (member old-current-focus new-focusable-elements :test #'equal)))
      ;; Current focus is no longer valid
      (if new-focusable-elements
          ;; Set to first available element
          (set-focus focus-manager (first new-focusable-elements) :app-state app-state)
          ;; No focusable elements, clear focus
          (clear-focus focus-manager :app-state app-state)))

    ;; Return the new list
    new-focusable-elements))

;;;-----------------------------------------------------------------------------
;;; Recalculate and Collect Focusable Elements (Refined)
;;;-----------------------------------------------------------------------------

(defun find-focusable-elements-in-tree (ui-tree-node)
  "Traverse the UI tree (assumed Hiccup-style: (type props &rest children))
   and return a list of all focusable element *nodes* (the plists themselves)
   in depth-first traversal order.
   This function expects the `ui-tree-node` to be the root of the UI tree,
   typically obtained from `(state-ref app-state :ui-tree)`."
  (let* ((focusable-nodes '())) ; Changed from focusable-ids
    (labels ((is-element-node (node)
               "Checks if a node is an element (keyword type, props, children)."
               (and (listp node) (keywordp (first node))))

             (get-node-properties (node)
               "Safely get properties of an element node.
                Assumes properties are a plist as the second element."
               (when (and (is-element-node node) (listp (second node)) (keywordp (first (second node))))
                 (second node)))

             (get-node-children (node)
               "Safely get children of an element node.
                Assumes children are the cddr of the node list."
               (when (is-element-node node)
                 (cddr node)))

             (traverse (node)
               (when (is-element-node node)
                 (let* ((props (get-node-properties node))
                        (node-id (when props (getf props :id))) ; Still need ID to check if it's a component
                        (is-focusable (when props (getf props :focusable)))
                        (is-disabled (when props (getf props :disabled))))

                   ;; Check if current node is focusable and has an ID
                   (when (and node-id is-focusable (not is-disabled))
                     (push node focusable-nodes)) ; Push the node itself

                   ;; Traverse children
                   (dolist (child (get-node-children node))
                     (traverse child))))))

      (traverse ui-tree-node)
      (nreverse focusable-nodes)))) ; Reverse to get depth-first order

;; collect-focusable-elements and collect-focusable-ids are now effectively
;; handled by recalculate-focusable-elements and the direct use of
;; (focus-manager-focusable-elements focus-manager). If a separate collection function
;; is needed without modifying the focus-manager state, it can be:
;; (defun collect-focusable-elements (ui-tree)
;;   "Traverses the UI tree and collects all elements that are focusable.
;;    Returns a list of element objects that can receive focus."
;;   ;; This implementation will depend on the structure of your UI tree
;;   ;; Here's a simplified version that assumes a nested structure with :focusable property
;;   (labels ((collect-recursive (node result)
;;              (if (null node)
;;                  result
;;                  (let ((new-result
;;                          (if (and (getf node :focusable) (getf node :id))
;;                              (cons node result)
;;                              result)))
;;                    (if (listp (getf node :children))
;;                        (reduce #'collect-recursive (getf node :children) :initial-value new-result)
;;                        new-result)))))
;;     (collect-recursive ui-tree nil)))

;; (defun collect-focusable-ids (ui-tree)
;;   "Traverses the UI tree and collects IDs of all elements that are focusable.
;;    Returns a list of element IDs that can receive focus."
;;   (mapcar #'stylable-id (collect-focusable-elements ui-tree)))

;; Ensure existing functions like get-next/previous-focusable use the
;; (focus-manager-focusable-elements focus-manager) which is updated by
;; recalculate-focusable-elements.

;; The old handle-key-event-for-component was a stub, replaced by
;; handle-key-event-for-focused-component.
;; The old handle-navigation-keys is kept for directional navigation.
