;;; Exhaustive contract matrix for registry -> TUI adapter -> ElmTUI object
;;; and terminal renderer. This file is part of elmtui-tests, not a script.
(uiop:define-package :elmtui.tests.style-contract-matrix
  (:use :cl :fiveam)
  (:import-from :cl-styles.properties
                #:property-definition #:ensure-declarations
                #:style-contract-violation)
  (:import-from :cl-styles.adapters #:normalize-tui-declarations)
  (:import-from :elmtui.platform.backend.common.ansi-styling
                #:style-to-terminal-style #:terminal-style-fg-color
                #:terminal-style-bg-color #:terminal-color-simple
                #:terminal-style-bold #:terminal-style-italic
                #:terminal-style-underline)
  (:export #:style-contract-matrix-suite))
(in-package :elmtui.tests.style-contract-matrix)

(def-suite style-contract-matrix-suite :in elmtui.tests:elmtui-test
  :description "Styling contract: all registered properties, aliases, values, and terminal cells")
(in-suite style-contract-matrix-suite)

(defparameter *structured-style-samples*
  '((:flex . (1 2))
    (:flex-flow . (:row :nowrap))
    (:grid-template-columns . (8 12))
    (:grid-template-rows . (1 2))
    (:grid-template-areas . ("header" "body"))
    (:grid-auto-columns . (1 2))
    (:grid-auto-rows . (2 3))
    (:padding . 2)
    (:margin . 3)
    (:border . 1)
    (:color . :cyan)
    (:background-color . :black)
    (:border-color . :red)
    (:border-top-color . :green)
    (:border-right-color . :green)
    (:border-bottom-color . :green)
    (:border-left-color . :green)
    (:text-background-color . :yellow)
    (:attributes . (:bold :underline))
    (:opacity . 0.5)
    (:aspect-ratio . 1.5)
    (:width . "50%")
    (:height . :fill)
    (:flex-basis . "25%")))

(defun %sample-for-property (key definition)
  (let* ((special (assoc key *structured-style-samples*))
         (type (getf definition :type))
         (enum (getf definition :enum)))
    (cond (special (cdr special))
          (enum (first enum))
          ((eq type :boolean) t)
          ((eq type :number) 3)
          ((eq type :string) "Mono")
          ((eq type :keyword) :start)
          ((eq type :length) '(:px 3))
          (t (error "No representative style fixture for ~S (type ~S)"
                    key type)))))

(defun %registered-properties ()
  (sort (loop for key being the hash-keys
               of cl-styles.properties::*property-registry* collect key)
        #'string< :key #'symbol-name))

(test every-registered-property-accepts-its-declared-type
  "Iterate every registered property: valid representative and invalid object."
  (let ((keys (%registered-properties)))
    (is (>= (length keys) 65))
    (dolist (key keys)
      (let* ((definition (property-definition key))
             (sample (%sample-for-property key definition)))
        (is (equal (getf (ensure-declarations (list key sample)) key)
                   (getf (cl-styles.properties:normalize-declarations
                          (list key sample)) key))
            "Valid ~A with ~S" key sample)
        (signals style-contract-violation
          (ensure-declarations (list key (make-instance 'standard-object))))))))

(test all-enumeration-cases-and-invalid-values
  "Every advertised enum value is valid, every unknown enum value is rejected."
  (dolist (key (%registered-properties))
    (let ((values (getf (property-definition key) :enum)))
      (when values
        (dolist (value values)
          (finishes (ensure-declarations (list key value))))
        (signals style-contract-violation
          (ensure-declarations (list key :not-a-real-enumeration-value)))))))

(test representative-style-types-and-boundaries
  (dolist (sample '((:width "50%") (:height :auto) (:height :fill)
                    (:flex-basis "25%") (:opacity 0) (:opacity 1)
                    (:grid-auto-flow :row-dense) (:white-space :nowrap)
                    (:overflow :hidden) (:visibility :visible)
                    (:bold t) (:bold nil) (:underline t) (:italic nil)
                    (:grid-template-columns nil) (:attributes nil)
                    (:color (:rgb 1 2 3))
                    (:color (:hsl 120 100 50))
                    (:color (:256 123)) (:color 202)
                    (:background-color "#00FF80")
                    (:background-color (10 20 30))
                    (:background-color (:rgba 5 6 7 1))))
    (finishes (ensure-declarations sample)))
  (dolist (sample '((:width "broken") (:width "5.5%")
                    (:height :broken) (:flex-basis "35px")
                    (:opacity -0.1) (:opacity 1.1)
                    (:color (:rgb 256 0 0))
                    (:color (:rgb 1 2))
                    (:color (:rgba 0 0 0 2))
                    (:color (:hsl 20 120 70))
                    (:color (:256 -1))
                    (:color 256)
                    (:color "#GGGGGG")
                    (:white-space :bogus) (:overflow :bogus)
                    (:visibility :bogus) (:bold :bogus)
                    (:font-family 3) (:font-size "twelve")))
    (signals style-contract-violation (ensure-declarations sample)))
  (signals style-contract-violation (ensure-declarations '(:not-a-property 3)))
  (signals style-contract-violation (ensure-declarations '(:color))))

(test all-elm-tui-layout-and-renderer-style-keys-are-recognized
  "Assert the maintained public/consumer key boundary stays registered."
  (dolist (key '(:display :width :height :min-width :max-width
                 :min-height :max-height :aspect-ratio :offset-x :offset-y
                 :scroll-x :scroll-y :flex :flex-direction :flex-flow
                 :flex-wrap :flex-basis :flex-grow :flex-shrink
                 :justify-content :align-items :align-self :align-content
                 :justify-items :grid-template-columns :grid-template-rows
                 :grid-template-areas :grid-auto-flow :grid-auto-columns
                 :grid-auto-rows :gap :row-gap :column-gap :order
                 :padding :padding-top :padding-right :padding-bottom
                 :padding-left :margin :margin-top :margin-right
                 :margin-bottom :margin-left :border :border-width
                 :border-top-width :border-right-width :border-bottom-width
                 :border-left-width :border-style :border-color
                 :border-top-style :border-right-style :border-bottom-style
                 :border-left-style :border-top-color :border-right-color
                 :border-bottom-color :border-left-color
                 :color :background-color :text-background-color
                 :white-space :overflow :visibility :z-index
                 :position :border-radius
                 :opacity :font-family :font-size :font-weight :font-style
                 :attributes :bold :italic :underline :inverse
                 :faint :blink :strike :invisible))
    (is (property-definition key) "Style keyword ~S is registered" key)))

(test aliases-and-enumeration-canonicalize-at-style-ingress
  (dolist (entry '(((:fg-color :cyan) :color :cyan)
                   ((:foreground-color :red) :color :red)
                   ((:text-color :red) :color :red)
                   ((:bg :blue) :background-color :blue)
                   ((:attrs (:bold)) :attributes (:bold))
                   ((:direction :column) :flex-direction :column)
                   ((:justify :center) :justify-content :center)
                   ((:align :center) :align-items :center)
                   ((:spacing 2) :gap 2)
                   ((:grid-gap 3) :gap 3)))
    (destructuring-bind (declaration canonical expected) entry
      (let ((result (ensure-declarations declaration)))
        (is (equal expected (getf result canonical))
            "Alias ~S should canonically resolve to ~A" declaration canonical))))
  (is (eq :flex-start
          (getf (ensure-declarations '(:justify-content :start))
                :justify-content))))

(test explicit-false-flags-override-existing-attributes
  (dolist (normalizer '(cl-styles.adapters:normalize-tui-declarations
                        cl-styles.adapters:normalize-tui-style-plist))
    (let* ((result (funcall normalizer
                            '(:attributes (:bold :italic :underline)
                              :bold nil :italic t :underline nil)))
           (attrs (or (getf result :attributes) (getf result :attrs))))
      (is (member :italic attrs))
      (is (not (member :bold attrs)))
      (is (not (member :underline attrs))))))

(test tui-adapter-and-dsl-carry-style-types-without-corruption
  (let* ((normalized (normalize-tui-declarations
                      '(:fg :cyan :bg :black :bold t :italic nil
                        :direction :row :width "50%" :height 2
                        :overflow :hidden :white-space :nowrap)))
         (node (elmtui.view.base-elements:dsl->objects
                (list :text :content "Hello" :style normalized)))
         (style (elmtui.view.element:el/styles node)))
    (is (eq :cyan (getf normalized :color)))
    (is (eq :black (getf normalized :background-color)))
    (is (member :bold (getf normalized :attributes)))
    (is (not (member :italic (getf normalized :attributes))))
    (is (eq :row (getf normalized :flex-direction)))
    (is (equal "50%" (getf normalized :width)))
    (is (eq :nowrap (getf style :white-space)))
    (is (eq :hidden (getf style :overflow)))))

(test terminal-aliases-boolean-attributes-and-rgb
  (let* ((style (style-to-terminal-style
                 '(:fg-color :cyan :background-color (:rgb 11 22 33)
                   :bold t :underline t :italic nil)))
         (bg (terminal-style-bg-color style))
         (fg (terminal-style-fg-color style)))
    (is (eq :cyan (terminal-color-simple fg)))
    (is (= 11 (elmtui.platform.backend.common.ansi-styling::terminal-color-red bg)))
    (is (= 22 (elmtui.platform.backend.common.ansi-styling::terminal-color-green bg)))
    (is (= 33 (elmtui.platform.backend.common.ansi-styling::terminal-color-blue bg)))
    (is (terminal-style-bold style))
    (is (terminal-style-underline style))
    (is (not (terminal-style-italic style)))))

(test both-terminal-converters-agree-on-colors-and-all-attributes
  "Test the legacy terminal backend and canonical cell renderer with identical data."
  (dolist (declarations
           '((:fg-color :cyan :bg-color :black :bold t :italic t)
             (:color (:rgb 17 34 51) :background-color (:rgb 4 5 6)
              :attrs (:underline :inverse :faint :blink :strike :invisible))
             (:fg (:256 123) :bg (:256 45)
              :attributes (:bold :italic :underline :inverse))
             (:fg (:hsl 120 100 50) :bg "#123456")
             (:fg 135 :bg 42)
             (:fg (100 110 120) :bg (10 20 30))
             (:attributes (:bold :inverse) :bold nil :inverse nil)))
    (let* ((a (style-to-terminal-style declarations))
           (b (elmtui.platform.backend.terminal:style-to-terminal-style
               declarations))
           (reader (lambda (s)
                     (list (elmtui.platform.backend.common.ansi-styling:terminal-style-fg-color s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-bg-color s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-bold s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-italic s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-underline s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-inverse s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-faint s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-blink s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-strike s)
                           (elmtui.platform.backend.common.ansi-styling:terminal-style-invisible s)))))
      (is (equalp (funcall reader a) (funcall reader b))
          "Converters disagree on ~S" declarations))))

(test canonical-hsl-hex-and-256-colors-survive-terminal-conversion
  "Colors validated by cl-styles must produce the same terminal representation."
  (flet ((rgb (color)
           (list
            (elmtui.platform.backend.common.ansi-styling::terminal-color-red color)
            (elmtui.platform.backend.common.ansi-styling::terminal-color-green color)
            (elmtui.platform.backend.common.ansi-styling::terminal-color-blue color))))
    (dolist (case '(((:hsl 0 100 50) (255 0 0))
                    ((:hsl 120 100 50) (0 255 0))
                    ((:hsl 240 100 50) (0 0 255))
                    ("#123456" (18 52 86))))
      (destructuring-bind (token expected) case
        (let* ((canonical (getf (ensure-declarations (list :color token)) :color))
               (style (style-to-terminal-style (list :fg-color canonical))))
          (is (equal expected (rgb (terminal-style-fg-color style)))))))
    (let* ((canonical (getf (ensure-declarations '(:color (:256 77))) :color))
           (color (terminal-style-fg-color
                   (style-to-terminal-style (list :color canonical)))))
      (is (= 77 (elmtui.platform.backend.common.ansi-styling::terminal-color-color-256
                 color))))))
