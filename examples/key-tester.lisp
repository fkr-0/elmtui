;;; examples/key-tester.lisp
;;; A thorough example demonstrating how to integrate a legacy, functional
;;; component with the modern defapplication framework, including keymaps
;;; and focus management, following the recommended "Central Gateway" architecture.
(uiop:define-package :elmtui-examples.key-tester
  (:use :cl )

  (:import-from #:log4cl
                #:log-info)
  ;; Import the legacy widget and its keymap definitions
  (:import-from :example.key-tester
                #:make-key-tester
                #:key-tester-input
                #:key-tester-echo
                #:key-tester-on-key-event)
  (:import-from :example.key-tester.keymap
                #:kt-handle-delete-last
                #:kt-handle-clear-input)
  ;; Import from elmtui systems
  (:import-from :elmtui.app #:defapplication)
  (:import-from :elmtui.state
                #:make-update-result
                #:state-ref)


  (:import-from :elmtui.keymaps #:key-event-p
                #:define-keymap
                #:define-keymap-context
                #:register-keymap
                #:activate-context
                #:deactivate-context
                #:current-context

                #:key-event-key
                #:key-event-modifiers
                #:key-event->normalized-key
                #:normalized-key->string)

  (:import-from :elmtui.core.event-types #:key-event)
  (:import-from :elmtui.ui.widgets.layout #:layout) ; Import the layout component
  (:export
   #:run-key-tester-app
   #:%fake-key-event
   #:run))

(in-package :elmtui-examples.key-tester)

;;; ----------------------------------------------------------------------
;;; Keymap Integration Layer (Strategy A: Central Gateway)
;;; ----------------------------------------------------------------------

;; Actions dispatch high-level semantic messages.
(defun action-delete-char (app-state)
  (declare (ignore app-state))
  '(:delete-last-char))

(defun action-clear-buffer (app-state)
  (declare (ignore app-state))
  '(:clear-input))

;; The keymap binds keys to these message-dispatching actions.
(define-keymap *key-tester-example-keymap*
  ("backspace" :type :action :target 'action-delete-char
               :description "Delete last character")
  ("escape"    :type :action :target 'action-clear-buffer
               :description "Clear the input buffer"))

;; The context makes the keymap active when the component is focused.
(define-keymap-context :key-tester-example-context :parent nil
  :keymaps (list *key-tester-example-keymap*))


;;; ----------------------------------------------------------------------
;;; Application Definition
;;; ----------------------------------------------------------------------

(defun key-tester-update (message app-state)
  "Handles updates for the key tester application.
   This function reacts to high-level messages from the keymap,
   or raw key events for text input."
  (log-info "Key Tester App received message: ~S" message)
  (log-info "Key Tester App received state: ~S" app-state)
  (let ((component (state-ref app-state :component)))
    (cond
      ;; --- Global Quit Command ---
      ((and (typep message 'key-event) (eq (key-event-key message) #\q))
       (make-update-result :patches '((:should-quit t))))

      ;; --- Messages from our Keymap Actions ---
      ((equal message '(:delete-last-char))
       (let ((new-comp (kt-handle-delete-last (copy-structure component))))
         (make-update-result :patches `((:component ,new-comp)))))

      ((equal message '(:clear-input))
       (let ((new-comp (kt-handle-clear-input (copy-structure component))))
         (make-update-result :patches `((:component ,new-comp)))))

      ;; --- Raw Key Events for Echo and Input ---
      ;; This handles printable characters. The keymap above handles Backspace/Escape.
      ((or (typep message 'key-event)
           (eql (car message) :keyevent))

       (let ((new-comp (key-tester-on-key-event (copy-structure component) message)))
         (log-info "Key Tester App received key event: ~S" message)
         (make-update-result :patches `((:component ,new-comp)))))

      ;; --- Default Case ---
      (t
       (log-info "Key Tester App received unhandled message: ~S" message)
       (make-update-result)))))

;; (ELMTUI.VIEW.DSL:RENDER-DSL-TO-RESOLVED-TREE
;;  (:ROOT-VIEWPORT :ID :KEY-TESTER-ROOT :INITIAL-TERMINAL-DIMENSIONS #1=(1 1) :INITIAL-CURSOR-POS #1# :CHILDREN
;;                  (:CONTAINER :ID :KEY-TESTER-WIDGET :KEYMAP-ID :KEY-TESTER-EXAMPLE-CONTEXT :FOCUSABLE T :STYLE (:BORDER T :DIRECTION :COLUMN :WIDTH :AUTO :HEIGHT :AUTO :MIN-WIDTH 40 :MIN-HEIGHT 8 ...) :CHILDREN ((:TEXT :CONTENT "Elm TUI Key Tester") (:TEXT :CONTENT "Input: j") (:TEXT :CONTENT "Echo:  (:|j|)") (:TEXT :CONTENT "Press 'q' to quit. Try Backspace and Escape.")))
;;                  )
;;  #S(ELMTUI.CONTRACTS:APP-CONTEXT :VIEW-FN #<FUNCTION ELMTUI.EXAMPLES.KEY-TESTER::WRAPPED-VIEW-KEY-TESTER-APP>
;;                                  :STATE #<ELMTUI.TEA-STATE.API:APPLICATION-STATE data: 2, history: 2>
;;                                  :STYLESHEET NIL
;;                                  :VIEWPORT-RECT #<ELMTUI.VIEW.GEO:RECTANGLE Pos:#<POS X:0 Y:0> Size:#<SIZE W:95 H:41>> :DSL-TREE NIL :RAW-TREE NIL :STYLED-TREE NIL :ATOMIC-TREE NIL
;;                                  :LAID-OUT-TREE NIL :
;;                                  ))
(defun key-tester-view (app-state &key root-id)
  "Renders the application's UI based on the current state."
  (log-info "Rendering Key Tester App with state: ~S ~A"
            app-state root-id)
  (let ((component
          (state-ref app-state :component)))
    `(:container
      :id :key-tester-widget
      :keymap-id :key-tester-example-context ; Link to our keymap context
      :focusable t
      :style (:border t :flex-direction :column :width :auto :height 8
              :display :flex
              :align-items :flex-start
              :justify-content :flex-start
              :min-width 40 :min-height 8
              :margin 0
              :border-style :solid :border-width 1
              :fg-color (128 128 128))
      :children ((:text :style (:width :fill)
                        :content "Elm TUI Key Tester")
                 (:text :style (:width :fill) :content
                        ,(format nil "Input: ~A" (key-tester-input component)))
                 (:text :style (:width :fill) :content
                        ,(format nil "Echo:  ~A" (key-tester-echo component)))
                 (:text :style (:width :fill) :content
                        "Press 'q' to quit. Try Backspace and Escape.")))))

;; Define the application using the modern `defapplication` macro.
(defapplication key-tester-app
  :root-viewport-id :key-tester-root
  :initial-state-plist `(:component ,(make-key-tester))
  ;; The root component DSL must define the component that the view function renders.
  :root-component-dsl '(:layout :id :key-tester-widget)
  :update-fn 'key-tester-update
  :view-fn 'key-tester-view)

;; Export a runner function.
;; (defun run ()
;;   "Run the key tester example application."
;;   (run-key-tester-app))
;; (defun initialize-app-state-key-tester-app
;;         (
;;          &key (elmtui.app::initial-terminal-dimensions '(80 24))
;;          (elmtui.app::initial-cursor-position '(0 0)) &allow-other-keys)
;;    (declare
;;     (ignorable elmtui.app::initial-terminal-dimensions
;;      elmtui.app::initial-cursor-position))
;;    (let* ((elmtui.app::app-state
;;            (elmtui.state.api:make-state
;;             (alexandria:plist-hash-table `(:component ,(make-key-tester))))))
;;      (multiple-value-bind (elmtui.app::patches elmtui.app::commands)
;;          (elmtui.ui.api:initialize-components-from-dsl
;;           '(:root-viewport :id :key-tester-root :initial-terminal-dimensions
;;             (1 1) :initial-cursor-pos (1 1) :children
;;             (:layout :id :key-tester-widget)))
;;        (elmtui.state.transactions:apply-patches elmtui.app::app-state
;;                                                     elmtui.app::patches)
;;        (values elmtui.app::app-state elmtui.app::commands))))
;; (let* ((tutu (elmtui.contracts:make-app-context
;;               :view-fn 'wrapped-view-key-tester-app
;;               :state (elmtui.state.api:make-state
;;                       `(:component ,(make-key-tester)))
;;               :stylesheet nil
;;               ;; :root-rect (elmtui.view.geo:make-rectangle
;;               ;;                 :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;               ;;                 :size (elmtui.view.geo:make-size :w 95 :h 41))
;;               :viewport-rect (elmtui.view.geo:make-rectangle
;;                               :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                               :size (elmtui.view.geo:make-size :w 95 :h 41))
;;               :dsl-tree nil
;;               :raw-tree nil
;;               :styled-tree nil
;;               :atomic-tree nil
;;               :laid-out-tree nil
;;               :front-buffer (elmtui.platform.backend.common.virtual-buffer:make-virtual-buffer
;;                              95 41)
;;               :backend nil ;; (elmtui.platform.backend.terminal:make-terminal-instance)
;;               ))
;;        (t2 (elmtui.pipeline:full-view-pipeline tutu)))

;;   (log-info (str:trim (elmtui.platform.backend.common.virtual-buffer:print-buffer-to-string
;;                        (elmtui.contracts:ctx-front-buffer t2))))
;;   (log-info (str:trim (elmtui.platform.backend.common.virtual-buffer:print-buffer-to-string
;;                        (elmtui.contracts:ctx-back-buffer t2))))
;;   t2)

;; (let ((dsl '(:ROOT-VIEWPORT :ID :KEY-TESTER-ROOT :INITIAL-TERMINAL-DIMENSIONS (1 1)
;;              :INITIAL-CURSOR-POS (1 1) :CHILDREN
;;              (:CONTAINER :ID :KEY-TESTER-WIDGET :KEYMAP-ID :KEY-TESTER-EXAMPLE-CONTEXT
;;                          :FOCUSABLE T :STYLE
;;               (:BORDER T :FLEX-DIRECTION :COLUMN :WIDTH :AUTO :HEIGHT :AUTO :MIN-WIDTH 40
;;                :MIN-HEIGHT 8 :DISPLAY :FLEX :MARGIN 1 :BORDER-STYLE :SOLID :BORDER-WIDTH 1
;;                :FG-COLOR (128 128 128))
;;               :CHILDREN
;;               ((:TEXT :CONTENT "Elm TUI Key Tester") (:TEXT :CONTENT "Input: ")
;;                (:TEXT :CONTENT "Echo:  ")
;;                (:TEXT :CONTENT "Press 'q' to quit. Try Backspace and Escape."))))))
;;   (elmtui.view.dsl:render-dsl-to-resolved-tree
;;    dsl (elmtui.state.api:make-state
;;         `(:component ,(make-key-tester)))))
;; ==>
;; (:ROOT-VIEWPORT :ID :KEY-TESTER-ROOT :INITIAL-TERMINAL-DIMENSIONS (1 1)
;;  :INITIAL-CURSOR-POS (1 1) :RESOLVED-VIEW
;;  (:VIEWPORT :ID :ROOT-VIEWPORT-KEY-TESTER-ROOT :STYLE
;;   (:WIDTH NIL :HEIGHT NIL :OFFSET-X 0 :OFFSET-Y 0 :SCROLL-X 0 :SCROLL-Y 0)
;;   :RESOLVED-VIEW
;;   (:CONTAINER :ID #:VIEWPORT-CONTAINER-862 :STYLE
;;    (:WIDTH 80 :HEIGHT 24 :OFFSET-X 0 :OFFSET-Y 0) :CHILDREN
;;    (:CONTAINER :ID :KEY-TESTER-WIDGET :KEYMAP-ID :KEY-TESTER-EXAMPLE-CONTEXT
;;     :FOCUSABLE T :STYLE
;;     (:BORDER :CHILDREN
;;      (T :FLEX-DIRECTION :COLUMN :WIDTH :AUTO :HEIGHT :AUTO :MIN-WIDTH 40
;;       :MIN-HEIGHT 8 :DISPLAY :FLEX :MARGIN 1 :BORDER-STYLE :SOLID :BORDER-WIDTH
;;       1 :FG-COLOR (128 128 128)))
;;     :CHILDREN
;;     ((:TEXT :CONTENT "Elm TUI Key Tester") (:TEXT :CONTENT "Input: ")
;;      (:TEXT :CONTENT "Echo:  ")
;;      (:TEXT :CONTENT "Press 'q' to quit. Try Backspace and Escape."))))))
;;   (elmtui.view.tree-transforms:process-tree
;;    (elmtui.view.dsl:render-dsl-to-resolved-tree
;;     (key-tester-view (initialize-app-state-key-tester-app)
;;                      :root-id :key-tester-root)
;;     (initialize-app-state-key-tester-app))
;;    :ctx tutu :root-rect (elmtui.view.geo:make-rectangle
;;                          :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;                          :size (elmtui.view.geo:make-size :w 95 :h 41))))

;; (key-tester-view )
;; (elmtui.state:make-application-state)
;; == tests/flex-smoke.lisp ==
;; expected x positions: content-x, content-x+10+gap, content-x+10+gap+5+gap
;; expected y position: content-y (align-items defaults to :stretch, but heights fixed)
;; == end/flex-smoke.lisp ==
;;; == elmtui/tests/flex-smoke.lisp ==
;;; quick smoke test exercising the API from your files (no DSL macros needed)
;; (in-package :cl-user)

(defun make-box (&key id w h)
  (make-instance 'elmtui.view.base-elements:container-element
                 :id id
                 :style (list :width w :height h)))

;; (defun flex-smoke-run ()
;;   "Return list of (id x y w h) for child rectangles."
;; (let* ((root (make-instance 'elmtui.view.base-elements:container-element
;;                             :id :root
;;                             :style '(:display :flex :flex-direction :row
;;                                      :padding-top 1 :padding-left 1
;;                                      :gap 2)))
;;        (c1 (make-box :id :a :w 10 :h 3))
;;        (c2 (make-box :id :b :w 5  :h 3))
;;        (c3 (make-box :id :c :w 7  :h 3))
;;        (_  (setf (elmtui.view.element:el/children root) (list c1 c2 c3)))
;;        (parent (elmtui.view.geo:make-rectangle
;;                 :pos  (elmtui.view.geo:make-pos :x 0 :y 0)
;;                 :size (elmtui.view.geo:make-size :w 40 :h 10)))
;;        (laid (elmtui.view.base-elements:compute-layout root parent)))
;;   (declare (ignore _))
;;   (mapcar (lambda (n)
;;             (let* ((r (elmtui.view.element:el/layout-rect n)))
;;               (list (elmtui.view.element:el/id n)
;;                     (elmtui.view.geo:x r)
;;                     (elmtui.view.geo:y r)
;;                     (elmtui.view.geo:w r)
;;                     (elmtui.view.geo:h r))))
;;           (elmtui.view.element:el/children laid)))

;; expected (with padding-left=1, gap=2):
;;   :a at x=content-x=1
;;   :b at x=1 + 10 + 2 = 13
;;   :c at x=13 + 5 + 2 = 20
;; y for all should be content-y=1
;;; == end/flex-smoke.lisp ==
                                        ; == tests/tree-transforms-smoke.lisp ==
;; (let* ((root (make-instance 'elmtui.view.base-elements:container-element
;;                             :id :root
;;                             :style '(:display :flex :flex-direction :row
;;                                      :padding-left 1 :gap 2
;;                                      )))
;;        (a (make-instance 'elmtui.view.base-elements:container-element
;;                          :id :a :style '(:width 4 :height 2)))
;;        (b (make-instance 'elmtui.view.base-elements:container-element
;;                          :id :b :style '(:width 5 :height 2))))
;;   (setf (elmtui.view.element:el/children root) (list a b))
;;   (let* ((vp (elmtui.view.geo:make-rectangle
;;               :pos (elmtui.view.geo:make-pos :x 0 :y 0)
;;               :size (elmtui.view.geo:make-size :w 20 :h 6)))
;;          (laid (elmtui.view.tree-transforms:process-tree
;;                 root
;;                 :ctx (elmtui.contracts:make-app-context :viewport-rect vp)
;;                 :root-rect vp)))
;;     (list (elmtui.view.geo:x (elmtui.view.element:el/layout-rect a))
;;           (elmtui.view.geo:y (elmtui.view.element:el/layout-rect a))
;;           (elmtui.view.geo:w (elmtui.view.element:el/layout-rect a))
;;           (elmtui.view.geo:h (elmtui.view.element:el/layout-rect a))
;;           (elmtui.view.geo:x (elmtui.view.element:el/layout-rect b))
;;           (elmtui.view.geo:y (elmtui.view.element:el/layout-rect b))
;;           (elmtui.view.geo:w (elmtui.view.element:el/layout-rect b))
;;           (elmtui.view.geo:h (elmtui.view.element:el/layout-rect b))
;;           (elmtui.view.element:el/styles laid))))
;; expected => (1 7)   ; 1 padding-left, then 4 width + 2 gap
;; == end/tree-transforms-smoke.lisp ==
