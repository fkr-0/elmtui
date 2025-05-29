(uiop:define-package :elmtui.dev.transaction-viewer
  (:use :cl :alexandria)
  (:import-from :elmtui.state.statelib.transaction
                #:get-transaction-history #:transaction-id #:transaction-name
                #:transaction-description #:transaction-timestamp #:transaction-changes
                #:transaction-categories #:format-transaction-summary #:format-universal-time)
  (:import-from :elmtui.view.core #:make-node)
  (:import-from :elmtui.ui.widgets.label #:make-label)
  (:import-from :elmtui.ui.widgets.listbox #:make-listbox) ; Assuming a listbox widget
  (:import-from :elmtui.ui.transaction-controls #:msg-selective-undo) ; For dispatching undo
  (:export #:view-transaction-history-interactive
           #:msg-select-transaction-for-view))
(in-package :elmtui.dev.transaction-viewer)

(defparameter msg-select-transaction-for-view :select-transaction-for-view) ; Payload: (:id <tx-id>)

(defun view-transaction-history-interactive (id app-state &key selected-transaction-id focused-list-item-id)
  "Renders a basic interactive TUI for browsing transaction history.
   ID: Base ID for the viewer components.
   APP-STATE: The application state.
   SELECTED-TRANSACTION-ID: The ID of the transaction currently selected for detail view.
   FOCUSED-LIST-ITEM-ID: The ID of the listbox item that should have focus.

   Returns a UI node tree."
  (let* ((history (get-transaction-history app-state))
         (items (loop for tx in history
                      collect (list :id (transaction-id tx)
                                    :label (format-transaction-summary tx))))
         (selected-tx (when selected-transaction-id
                        (find selected-transaction-id history :key #'transaction-id))))
    (make-node :column :id id :properties '(:gap 1) :children
               (list
                (make-label :id (symbolicate id '-title) :text "Transaction History Viewer")
                (make-node :row :id (symbolicate id '-main-panel) :properties '(:gap 2) :children
                           (list
                            ;; Transaction List
                            (make-listbox :id (symbolicate id '-history-list)
                                          :items items
                                          :selected-item-id selected-transaction-id
                                          :focused-item-id focused-list-item-id
                                          :on-select msg-select-transaction-for-view ; Sends (:id <tx-id>)
                                          :width 50) ; Arbitrary width
                            ;; Transaction Detail View
                            (if selected-tx
                                (view-transaction-detail (symbolicate id '-detail) selected-tx)
                                (make-label :id (symbolicate id '-detail-placeholder)
                                            :text "Select a transaction to view details."))))))))

(defun view-transaction-detail (id transaction)
  "Renders details for a single transaction."
  (make-node :column :id id :properties '(:gap 0) :children
             (list
              (make-label :text (format nil "ID: ~A" (transaction-id transaction)))
              (make-label :text (format nil "Name: ~A" (or (transaction-name transaction) "N/A")))
              (make-label :text (format nil "Timestamp: ~A" (format-universal-time (transaction-timestamp transaction))))
              (make-label :text (format nil "Description: ~A" (or (transaction-description transaction) "N/A")))
              (make-label :text (format nil "Categories: ~{~S~^, ~}" (transaction-categories transaction)))
              (make-label :text (format nil "Changes (~D):" (length (transaction-changes transaction))))
              (make-node :column :id (symbolicate id '-changes) :children
                         (loop for change in (transaction-changes transaction)
                               for i from 0 below 10 ; Limit displayed changes for simplicity
                               collect (destructuring-bind (key old-value new-value) change
                                         (make-label :text (format nil "  - ~S: ~S => ~S" key old-value new-value)))))
              (when (> (length (transaction-changes transaction)) 10)
                (make-label :text (format nil "  ...and ~D more changes." (- (length (transaction-changes transaction)) 10))))
              ;; Placeholder for a button to selectively undo this transaction
              ;; (make-button :label "Undo This Transaction"
              ;;              :on-click `(,msg-selective-undo (:id ,(transaction-id transaction))))
              )))

;; This viewer is basic. A more advanced one would:
