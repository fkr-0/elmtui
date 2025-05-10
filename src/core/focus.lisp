(uiop:define-package :elmtui.core.focus
  (:use :cl :alexandria)
  (:import-from :elmtui.state ;; For state-ref
   :state-ref :application-state :set-state! :set-state)
  (:import-from :elmtui.core.globals
   :*app-state*)
  (:export :handle-focus-message
   :get-current-focus
   ;; :set-current-focus ; Now internal, called by handle-focus-message
           :get-focusable-elements
           ;; :set-focusable-elements ; Now internal
           ;; :focus-next-element ; Now internal
           ;; :focus-previous-element ; Now internal
           ))

(in-package :elmtui.core.focus)

(defun get-current-focus (app-state)
  "Retrieves the ID of the currently focused widget from app-state."
  (state-ref app-state :current-focus-id))

(defun %set-current-focus-desc (app-state widget-id)
  "Internal helper. Returns a plist describing the change to set current focus."
  (declare (ignore app-state)) ; app-state might be used for validation in future
  (list :current-focus-id widget-id))

(defun get-focusable-elements (app-state)
  "Retrieves the list of focusable widget IDs from app-state."
  (state-ref app-state :focusable-elements))

(defun %set-focusable-elements-desc (app-state ids)
  "Internal helper. Returns a plist describing the change to set focusable elements."
  (declare (ignore app-state)) ; app-state might be used for validation in future
  (list :focusable-elements ids))

(defun %focus-next-element-desc (app-state)
  "Internal helper. Returns a plist describing the change to focus the next element,
   or NIL if no change."
  (let* ((current-focus (get-current-focus app-state))
         (focusable (get-focusable-elements app-state))
         (current-pos (position current-focus focusable :test #'equal)))
    (when focusable
      (let ((next-id (cond
                       ((null current-focus) (first focusable))
                       ((null current-pos) (first focusable)) ; Not in list, focus first
                       ((< current-pos (1- (length focusable)))
                        (nth (1+ current-pos) focusable))
                       (t (first focusable))))) ; Wrap around
        (when (and next-id (not (equal next-id current-focus)))
          (%set-current-focus-desc app-state next-id))))))

(defun %focus-previous-element-desc (app-state)
  "Internal helper. Returns a plist describing the change to focus the previous element,
   or NIL if no change."
  (let* ((current-focus (get-current-focus app-state))
         (focusable (get-focusable-elements app-state))
         (current-pos (position current-focus focusable :test #'equal)))
    (when focusable
      (let ((prev-id (cond
                       ((null current-focus) (alexandria:lastcar focusable))
                       ((null current-pos) (alexandria:lastcar focusable)) ; Not in list, focus last
                       ((> current-pos 0)
                        (nth (1- current-pos) focusable))
                       (t (alexandria:lastcar focusable))))) ; Wrap around
        (when (and prev-id (not (equal prev-id current-focus)))
          (%set-current-focus-desc app-state prev-id))))))

(defun handle-focus-message (app-state message)
  "Handles focus-related messages.
   Returns a plist describing the state changes to be made, or NIL if no changes.
   The caller (typically a `defupdate` function) is responsible for applying these
   changes using its transactional `set-state!`."
  (let ((msg-type (first message))
        (changes nil))
    (case msg-type
      (:request-focus
       (let ((widget-id (getf (rest message) :widget-id)))
         (when (and widget-id (not (equal widget-id (get-current-focus app-state))))
           ;; TODO: Validate widget-id is in focusable-elements?
           (setf changes (%set-current-focus-desc app-state widget-id)))))
      (:focus-next
       (setf changes (%focus-next-element-desc app-state)))
      (:focus-previous
       (setf changes (%focus-previous-element-desc app-state)))
      (:update-focusable-ids
       (let* ((new-ids (getf (rest message) :ids))
              (current-focusable (get-focusable-elements app-state))
              (current-focus (get-current-focus app-state))
              (focus-changes nil))
         ;; Update focusable elements if they've changed
         (unless (equal new-ids current-focusable)
           (setf changes (append (%set-focusable-elements-desc app-state new-ids) changes)))

         ;; If current focus is no longer valid or nil, set to first of new-ids
         (when (or (not (member current-focus new-ids :test #'equal))
                   (and (null current-focus) new-ids))
           (let ((new-focus-target (first new-ids)))
             (unless (equal new-focus-target current-focus) ; Avoid redundant change
               (setf focus-changes (%set-current-focus-desc app-state new-focus-target)))))
         (when focus-changes
           (setf changes (append focus-changes changes)))))
      ;; No 'otherwise' needed, if msg-type doesn't match, changes remains NIL
      )
    (if changes (nreverse changes) nil))) ; Ensure correct plist order if multiple changes were pushed
