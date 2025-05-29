# Event System Usage Guide

## Overview

This guide demonstrates how to use the standardized event system in ELMTUI.

## Basic Event Handling

### 1. Key Events

```lisp
;; Define a key event handler
(defmethod handle-event ((node my-custom-node) (event key-event) (phase (eql :target)))
  (case (key-event-type event)
    (:key-down 
     (case (key-event-key event)
       (:enter 
        (log:debug "Enter key pressed on ~A" (ui-node-id node))
        (perform-action node)
        (stop-propagation event))
       (:escape
        (log:debug "Escape key pressed on ~A" (ui-node-id node))
        (cancel-action node)
        (stop-propagation event))))
    (:key-up
     ;; Handle key up events
     )))

;; Create a normalized key from a key event
(let* ((key-event (make-key-event :type :key-down :key :f1 :modifiers '(:ctrl)))
       (norm-key (key-event->normalized-key key-event)))
  ;; Look up in keymap
  (lookup-keymap *global-keymap* norm-key))
```

### 2. Mouse Events

```lisp
;; Define a mouse event handler
(defmethod handle-event ((node my-custom-node) (event mouse-event) (phase (eql :target)))
  (case (mouse-event-type event)
    (:mouse-down
     (log:debug "Mouse down at (~A,~A) with button ~A on ~A" 
                (mouse-event-x event) (mouse-event-y event)
                (mouse-event-button event) (ui-node-id node))
     (handle-mouse-click node event))
    (:mouse-move
     ;; Handle mouse move
     )))
```

### 3. Event Propagation

```lisp
;; Example of capture phase handling
(defmethod handle-capture-event ((node container-node) (event mouse-event))
  ;; Pre-process event before it reaches children
  (when (container-node-intercepting-mouse-p node)
    (log:debug "Container ~A intercepting mouse event in capture phase" 
              (ui-node-id node))
    (stop-propagation event)))

;; Example of bubble phase handling
(defmethod handle-bubble-event ((node parent-node) (event key-event))
  ;; Handle event after child processing
  (when (and (eq (key-event-key event) :tab)
             (member :shift (key-event-modifiers event)))
    (log:debug "Parent ~A handling Shift-Tab in bubble phase" 
              (ui-node-id node))
    (focus-previous-element node)
    (stop-propagation event)))

;; Dispatching an event through the UI tree
(let ((event (make-mouse-event :type :mouse-down :x 10 :y 20 :button :left)))
  (dispatch-event *ui-tree* event))
```

## Focus Management

### 1. Basic Focus Operations

```lisp
;; Setting focus
(set-focus *app-state* :textfield1)

;; Getting current focus
(let ((current-focus (get-current-focus *app-state*)))
  (log:debug "Current focus is on ~A" current-focus))

;; Clearing focus
(clear-focus *app-state*)
```

### 2. Tab Navigation

```lisp
;; Finding next focusable element
(let* ((current-focus (get-current-focus *app-state*))
       (next-focus (get-next-focusable *app-state* current-focus)))
  (set-focus *app-state* next-focus))

;; Handling Tab key
(defmethod handle-event ((node root-node) (event key-event) (phase (eql :target)))
  (when (and (eq (key-event-type event) :key-down)
             (eq (key-event-key event) :tab))
    (let ((shift-pressed (member :shift (key-event-modifiers event))))
      (handle-tab-navigation *app-state* event)
      (stop-propagation event))))
```

### 3. Focus History

```lisp
;; Going back to previous focus
(focus-previous-from-history *app-state*)
```

## Keymaps

### 1. Defining Keymaps

```lisp
;; Global keymap
(define-keymap *global-keymap*
  ("C-s" :type :message :target '(:save-file) :description "Save file")
  ("C-o" :type :message :target '(:open-file) :description "Open file")
  ("F1" :type :message :target '(:show-help) :description "Show help"))

;; Widget-specific keymap
(define-keymap *text-editor-keymap*
  ("C-x" :type :message :target '(:cut) :description "Cut selection")
  ("C-c" :type :message :target '(:copy) :description "Copy selection")
  ("C-v" :type :message :target '(:paste) :description "Paste clipboard"))
```

### 2. Using Keymaps

```lisp
;; Looking up a key binding
(defun handle-key-event (app-state event)
  (let* ((keymap (state-ref app-state :active-keymap))
         (normalized-key (key-event->normalized-key event))
         (binding (lookup-keymap keymap normalized-key)))
    (when binding
      (case (getf binding :type)
        (:message
         (send-message *app-sender* (getf binding :target)))
        (:action
         (funcall (getf binding :target)))))))
```

## Asynchronous Event Handling

### 1. Event Channels

```lisp
;; Starting event processing
(start-event-processing 
 (lambda () *ui-tree*)      ; Function that returns current UI tree
 (lambda () *app-state*))   ; Function that returns current app state

;; Dispatching an event asynchronously
(dispatch-event-async 
 (make-key-event :type :key-down :key :f5)
 :priority :high)
```

### 2. Event Scheduling

```lisp
;; Schedule a delayed event
(schedule-event 
 (make-ui-event :type :refresh :target :data-view)
 5000)  ; 5 seconds

;; Create a repeating event
(schedule-repeating-event
 (make-ui-event :type :update-clock :target :status-bar)
 1000    ; Every second
 nil)    ; Indefinitely
```

### 3. Throttling and Debouncing

```lisp
;; Create a debounced function
(let ((resize-handler (debounce 
                       (lambda (width height)
                         (log:debug "Resizing to ~Ax~A" width height)
                         (resize-ui width height))
                       250)))  ; 250ms debounce
  ;; Use it to handle resize events
  (defmethod handle-event ((node window-node) (event resize-event) (phase (eql :target)))
    (funcall resize-handler 
             (resize-event-width event) 
             (resize-event-height event))))

;; Create a throttled function
(let ((update-handler (throttle
                       (lambda (data)
                         (log:debug "Updating with ~A" data)
                         (update-view data))
                       100)))  ; Max 10 updates per second
  ;; Use it for frequent updates
  (defun on-data-received (data)
    (funcall update-handler data)))
```

## Animation Framework

### 1. Basic Animation

```lisp
;; Create a simple fade-in animation
(let ((widget (find-widget *ui-tree* :notification)))
  (create-animation
   1.0                                    ; Duration in seconds
   (lambda (progress)                     ; Update function
     (setf (widget-opacity widget) progress))
   :easing-fn #'ease-in-out              ; Easing function
   :complete-fn                          ; On completion
   (lambda () 
     (log:debug "Fade-in complete for ~A" (widget-id widget)))))
```

### 2. Value Transitions

```lisp
;; Animate widget position
(let ((widget (find-widget *ui-tree* :dialog)))
  (create-transition
   -100 0 0.5                            ; From -100 to 0 over 0.5 seconds
   (lambda (value)                       ; Update function with interpolated value
     (setf (widget-position-y widget) value))
   :easing-fn #'bounce))                 ; With bounce effect
```

### 3. Animation Sequences

```lisp
;; Create a sequence of animations
(let* ((widget (find-widget *ui-tree* :popup))
       (fade-in (create-animation 
                 0.3 (lambda (p) (setf (widget-opacity widget) p))))
       (slide-in (create-transition 
                  -50 0 0.5 (lambda (v) (setf (widget-position-y widget) v))))
       (highlight (create-animation 
                   0.2 (lambda (p) (setf (widget-highlight widget) p))
                   :complete-fn (lambda () (setf (widget-highlight widget) nil)))))
  ;; Run animations in sequence
  (create-sequence (list fade-in slide-in highlight)))
```

### 4. Parallel Animations

```lisp
;; Run multiple animations at once
(let* ((widget (find-widget *ui-tree* :card))
       (fade-in (create-animation 
                 0.5 (lambda (p) (setf (widget-opacity widget) p))))
       (expand-width (create-transition 
                      0 300 0.5 (lambda (v) (setf (widget-width widget) v))))
       (expand-height (create-transition 
                       0 200 0.5 (lambda (v) (setf (widget-height widget) v)))))
  ;; Run all animations in parallel
  (create-parallel (list fade-in expand-width expand-height)))
```

## Integration with Message System

```lisp
;; Converting events to messages
(defun event->message (event)
  "Converts an event to a message for the update function."
  (typecase event
    (key-event
     (case (key-event-type event)
       (:key-down
        (case (key-event-key event)
          (:enter '(:submit-form))
          (:escape '(:cancel-action))
          (otherwise nil)))
       (otherwise nil)))
    
    (mouse-event
     (case (mouse-event-type event)
       (:mouse-down
        `(:element-clicked 
          :x ,(mouse-event-x event) 
          :y ,(mouse-event-y event)
          :button ,(mouse-event-button event)))
       (otherwise nil)))
    
    (otherwise nil)))

;; Dispatch message from event
(defun handle-ui-event (app-state event)
  (let ((msg (event->message event)))
    (when msg
      (send-message *app-sender* msg))))
```
