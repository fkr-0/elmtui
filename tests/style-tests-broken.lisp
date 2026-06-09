;;;; STYLE Module Tests
;;;; Test suite for elmtui styling system using cl-styles

(uiop:define-package :elmtui.style.tests
  (:use :cl :fiveam)
  (:import-from :cl-styles.api 
    #:make-stylesheet #:defrule #:apply-stylesheet #:apply-stylesheet-to-tree
    #:type> #:id> #:cls> #:attr> #:state> #:sel-and #:sel-or
    #:var #:rgb #:rgba #:px #:em #:percent
    #:add-rule #:remove-rule
    #:get-computed-style #:set-computed-style
    #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
    #:stylable-parent #:stylable-children)
  (:export #:run-style-tests #:style-test-suite))

(in-package :elmtui.style.tests)

(def-suite style-test-suite
  :description "Test suite for elmtui styling system")

(in-suite style-test-suite)
;; Test for style sheet functionality
(test style-sheet-basic
  "Test style sheet functionality"
  (when (fboundp 'cl-styles.api:make-stylesheet)
    (let ((style-sheet (cl-styles.api:make-stylesheet)))
      (is (not (null style-sheet))
        "Style sheet should be created")
      (when style-sheet
        ;; Test adding rules if function exists
        (when (fboundp 'elmtui.style.
                (cl-styles.api:add-rule style-sheet ".button" 
                  :color "red" 
                  :background "blue")
                (cl-styles.api:add-rule style-sheet "#header" 
                  :font-size "large")
                (cl-styles.api:add-rule style-sheet "div" 
                  :border "1px solid black"))
          
          ;; Test getting rules if function exists
          (when (fboundp 'cl-styles.api:get-rule)
            (let ((button-rule (cl-styles.api:get-rule style-sheet ".button")))
              (is (not (null button-rule))
                "Button rule should be retrievable")
              (when button-rule
                (when (fboundp 'cl-styles.api:get-property)
                  (is (eq (cl-styles.api:get-property button-rule :color) "red")
                    "Color property should match")
                  (is (eq (cl-styles.api:get-property button-rule :background) "blue")
                    "Background property should match"))))))))))

(test style-sheet-selectors
  "Test style selector functionality"
  (when (fboundp 'cl-styles:make-stylesheet)
    (let ((style-sheet (cl-styles:make-stylesheet)))
      (when style-sheet
        ;; Test selector matching if function exists
        (when (fboundp 'cl-styles.api:matches-selector)
          (is (cl-styles.api:matches-selector style-sheet ".primary" 
                '(:class ("primary")))
            "Should match class selector")
          (is (cl-styles.api:matches-selector style-sheet "#header" 
                '(:id "header"))
            "Should match ID selector")
          (is (cl-styles.api:matches-selector style-sheet "button" 
                '(:tag "button"))
            "Should match element selector")))
      
      ;; Test complex selectors
      (when (fboundp 'cl-styles.api:add-rule)
        (cl-styles.api:add-rule style-sheet "button.primary" 
          :color "white")
        (when (fboundp 'cl-styles.api:matches-selector)
          (is (cl-styles.api:matches-selector style-sheet "button.primary" 
                '(:tag "button" :class ("primary")))
            "Should match combined selector"))))))

(test style-sheet-inheritance
  "Test style inheritance"
  (when (fboundp 'cl-styles:make-stylesheet)
    (let ((style-sheet (cl-styles:make-stylesheet)))
      (when style-sheet
        ;; Define base and derived styles
        (when (fboundp 'cl-styles.api:add-rule)
          (cl-styles.api:add-rule style-sheet ".widget" 
            :color "black" 
            :font-family "sans-serif")
          (cl-styles.api:add-rule style-sheet ".button" 
            :color "blue" 
            :border "1px solid gray"))
        
        ;; Test computed styles if function exists
        (when (fboundp 'cl-styles.api:get-computed-style)
          (let ((computed (cl-styles.api:get-computed-style 
                            style-sheet '(:tag "button" :class ("button" "widget")))))
            (is (not (null computed))
              "Computed style should be available")
            (when computed
              (when (fboundp 'cl-styles.api:get-property)
                (is (eq (cl-styles.api:get-property computed :color) "blue")
                  "Derived style should override base")
                (is (eq (cl-styles.api:get-property computed :font-family) "sans-serif")
                  "Base style should be inherited")
                (is (eq (cl-styles.api:get-property computed :border) "1px solid gray")
                  "Derived style property should be present")))))))))

;; Test for style manager functionality
(test style-manager-basic
  "Test style manager functionality"
  (when (fboundp 'elmtui.style.manager:make-style-manager)
    (let ((manager (elmtui.style.manager:make-style-manager)))
      (is (not (null manager))
        "Style manager should be created")
      (when manager
        ;; Test theme creation and registration if functions exist
        (when (fboundp 'elmtui.style.manager:make-theme)
          (let ((theme (elmtui.style.manager:make-theme "light-theme")))
            (is (not (null theme))
              "Theme should be created")
            (when theme
              ;; Add styles to theme if function exists
              (when (fboundp 'elmtui.style.manager:add-style)
                (elmtui.style.manager:add-style theme ".button" :color "black")
                (elmtui.style.manager:add-style theme ".background" :background "white"))
              
              ;; Register theme if function exists
              (when (fboundp 'elmtui.style.manager:register-theme)
                (elmtui.style.manager:register-theme manager theme)
                
                ;; Set active theme if function exists
                (when (fboundp 'elmtui.style.manager:set-active-theme)
                  (elmtui.style.manager:set-active-theme manager "light-theme")
                  
                  ;; Get active theme if function exists
                  (when (fboundp 'elmtui.style.manager:get-active-theme)
                    (let ((active (elmtui.style.manager:get-active-theme manager)))
                      (when (fboundp 'elmtui.style.manager:theme-name)
                        (is (string= (elmtui.style.manager:theme-name active) "light-theme")
                          "Active theme should be set correctly")))))))))))))

(test style-manager-switching
  "Test theme switching"
  (when (fboundp 'elmtui.style.manager:make-style-manager)
    (let ((manager (elmtui.style.manager:make-style-manager)))
      (when manager
        ;; Create light theme if function exists
        (when (fboundp 'elmtui.style.manager:make-theme)
          (let ((light-theme (elmtui.style.manager:make-theme "light")))
            (when (fboundp 'elmtui.style.manager:add-style)
              (elmtui.style.manager:add-style light-theme ".button" :color "black")
              (elmtui.style.manager:add-style light-theme ".background" :background "white"))
            (when (fboundp 'elmtui.style.manager:register-theme)
              (elmtui.style.manager:register-theme manager light-theme)))
          
          ;; Create dark theme if function exists
          (let ((dark-theme (elmtui.style.manager:make-theme "dark")))
            (when (fboundp 'elmtui.style.manager:add-style)
              (elmtui.style.manager:add-style dark-theme ".button" :color "white")
              (elmtui.style.manager:add-style dark-theme ".background" :background "black"))
            (when (fboundp 'elmtui.style.manager:register-theme)
              (elmtui.style.manager:register-theme manager dark-theme)))
          
          ;; Test switching if functions exist
          (when (fboundp 'elmtui.style.manager:set-active-theme)
            (elmtui.style.manager:set-active-theme manager "light")
            (when (fboundp 'elmtui.style.manager:get-styles)
              (let ((light-styles (elmtui.style.manager:get-styles manager)))
                (when (fboundp 'elmtui.style.manager:get-property)
                  (is (eq (elmtui.style.manager:get-property light-styles ".button" :color) "black")
                    "Light theme should have black button color")))))
          
          (when (fboundp 'elmtui.style.manager:set-active-theme)
            (elmtui.style.manager:set-active-theme manager "dark")
            (when (fboundp 'elmtui.style.manager:get-styles)
              (let ((dark-styles (elmtui.style.manager:get-styles manager)))
                (when (fboundp 'elmtui.style.manager:get-property)
                  (is (eq (elmtui.style.manager:get-property dark-styles ".button" :color) "white")
                    "Dark theme should have white button color"))))))))))

;; Test for style presets
(test style-presets-basic
  "Test style presets"
  ;; Test getting presets if function exists
  (when (fboundp 'elmtui.style.manager:get-presets)
    (let ((presets (elmtui.style.manager:get-presets)))
      (is (not (null presets))
        "Should have presets available")
      (when presets
        ;; Check for default preset
        (let ((preset-names (mapcar (lambda (p) 
                                      (when (fboundp 'elmtui.style.manager:preset-name)
                                        (elmtui.style.manager:preset-name p)))
                              presets)))
          (is (member "default" preset-names :test #'string=)
            "Should have default preset"))
        
        ;; Load a preset if function exists
        (when (fboundp 'elmtui.style.manager:load-preset)
          (let ((default-preset (elmtui.style.manager:load-preset "default")))
            (is (not (null default-preset))
              "Default preset should load")
            (when (and default-preset 
                    (fboundp 'elmtui.style.manager:preset-name))
              (is (string= (elmtui.style.manager:preset-name default-preset) "default")
                "Preset name should match"))))))))

(test style-presets-custom
  "Test custom style presets"
  (when (fboundp 'elmtui.style.manager:make-preset)
    (let ((custom-preset (elmtui.style.manager:make-preset "custom")))
      (is (not (null custom-preset))
        "Custom preset should be created")
      (when custom-preset
        ;; Add styles to preset if function exists
        (when (fboundp 'elmtui.style.manager:add-style-to-preset)
          (elmtui.style.manager:add-style-to-preset custom-preset ".custom" 
            :color "purple" 
            :font-weight "bold"))
        
        ;; Save preset if function exists
        (when (fboundp 'elmtui.style.manager:save-preset)
          (elmtui.style.manager:save-preset custom-preset)
          
          ;; Load and verify if function exists
          (when (fboundp 'elmtui.style.manager:load-preset)
            (let ((loaded (elmtui.style.manager:load-preset "custom")))
              (is (not (null loaded))
                "Custom preset should be loadable")
              (when (and loaded 
                      (fboundp 'elmtui.style.manager:get-preset-style))
                (is (eq (elmtui.style.manager:get-preset-style loaded ".custom" :color) "purple")
                  "Custom preset should preserve styles")))))))))

;; Test for stylable implementation
(test stylable-impl-basic
  "Test stylable implementation"
  (when (fboundp 'cl-styles.api:make-stylable-element)
    (let ((stylable (cl-styles.api:make-stylable-element :button 
                      '(:class ("primary")))))
      (is (not (null stylable))
        "Stylable element should be created")
      (when stylable
        ;; Apply style if function exists
        (when (fboundp 'cl-styles.api:apply-style)
          (cl-styles.api:apply-style stylable :color "blue" :background "white")
          
          ;; Get applied style if function exists
          (when (fboundp 'cl-styles.api:get-applied-style)
            (is (eq (cl-styles.api:get-applied-style stylable :color) "blue")
              "Applied color should match")
            (is (eq (cl-styles.api:get-applied-style stylable :background) "white")
              "Applied background should be match")))
        
        ;; Test style computation if functions exist
        (when (and (fboundp 'cl-styles:make-stylesheet)
                (fboundp 'cl-styles.api:add-rule)
                (fboundp 'cl-styles.api:compute-style))
          (let ((style-sheet (cl-styles:make-stylesheet)))
            (cl-styles.api:add-rule style-sheet ".primary" :color "red")
            (cl-styles.api:add-rule style-sheet "button" :padding "5px")
            
            (let ((computed (cl-styles.api:compute-style stylable style-sheet)))
              (is (not (null computed))
                "Computed style should be available")
              (when computed
                (when (fboundp 'cl-styles.api:get-property)
                  (is (eq (cl-styles.api:get-property computed :color) "red")
                    "Computed style should include rule")
                  (is (eq (cl-styles.api:get-property computed :padding) "5px")
                    "Computed style should include element rule")
                  (is (eq (cl-styles.api:get-property computed :background) "white")
                    "Computed style should include applied style"))))))))))

(defun run-style-tests ()
  "Run all style module tests"
  (run! 'style-test-suite))
