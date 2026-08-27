Love this. Yes—split the styling into its own system and make the coupling a thin, explicit protocol. Below is a **succinct interface spec** you can lift into a new ASDF system (e.g. `cl-styles`) that integrates cleanly with your TEA loop and component DSLs.


# cl-styles — Interface & Boundaries

## Goals (quick)

* Encapsulate *CSS-like* matching, cascade, specificity, inheritance, shorthands, variables.
* Keep the app’s model pure: `(update state) => new-state`, `(view state) => dsl`.
* Let any UI object model “opt in” by implementing small **protocol generics**.
* Provide a minimal **DSL** for selectors, rules, and stylesheets.
* Offer a single **engine entrypoint** to compute/patch **computed styles** onto objects (purely, returning patches).

---

# Systems / Packages (proposed)

* `cl-styles.protocols` — generics clients implement.
* `cl-styles.selector` — selector AST + compiler (specificity, matching).
* `cl-styles.rule` — rules & declarations (+ shorthands expansion).
* `cl-styles.sheet` — stylesheet construction, variables, compilation.
* `cl-styles.engine` — matching + cascade + inheritance + computed-style cache.
* `cl-styles.tokens` — colors, lengths, enums, variables, themes.
* `cl-styles.api` — thin façade re-exporting the user-facing API.

(These mirror your `style-lib.*` modules but stand alone, so `elmtui` can depend on `cl-styles` without cycles.)

---

# What a client library must implement

Your objects don’t need to *be* a particular class; they only need to answer a handful of **protocol generics**. Think “Stylable Node Protocol”.

### Required read accessors

```lisp
(defgeneric stylable-id          (obj)    ;; keyword/string/nil
  (:documentation "Stable identifier used by #id selectors."))

(defgeneric stylable-classes     (obj)    ;; list of string/keyword
  (:documentation "Class names used by .class selectors."))

(defgeneric stylable-type        (obj)    ;; keyword/symbol (e.g., :container, :text)
  (:documentation "Type/tag used by type selectors."))

(defgeneric stylable-inline-style (obj)   ;; plist or NIL
  (:documentation "Inline style (highest priority, before !important)."))

(defgeneric stylable-attributes  (obj)    ;; plist/alist
  (:documentation "Arbitrary attributes for [attr=value] selectors."))

(defgeneric stylable-state       (obj)    ;; plist/keywords
  (:documentation "Pseudo-classes/state (e.g., :focus :disabled)."))
```

### Required tree navigation (for hierarchical selectors)

```lisp
(defgeneric stylable-parent   (obj)       ;; parent obj or NIL
  (:documentation "For ancestor/descendant and :first-child etc."))

(defgeneric stylable-children (obj)       ;; sequence of children
  (:documentation "To traverse the tree during matching."))

(defgeneric stylable-index    (obj)       ;; 0-based index among siblings
  (:documentation "For :nth-child, :first-child, :last-child."))
```

### Required write / result integration

You choose how style results attach—“patches” are TEA-friendly:

```lisp
(defgeneric set-computed-style (obj computed) ;; return NEW-OBJ (pure) or PATCH
  (:documentation "Attach computed style to obj or produce a patch."))

(defgeneric get-computed-style (obj)          ;; for incremental diff/caching
  (:documentation "Return previously computed style or NIL."))
```

> **Tip:** If you prefer pure updates, make `set-computed-style` return a **patch** in a canonical form, and let your app’s “apply-patches” layer commit it. The engine can then return only patches.

### Optional (but nice)

```lisp
(defgeneric stylable-namespace (obj))      ;; to scope stylesheets
(defgeneric stylable-theme     (obj))      ;; theme token source
(defgeneric stylable-key       (obj))      ;; stable cache key (hash seed)
```

---

# Exports from `cl-styles` (what you ship)

### Selectors (S-expr DSL)

```lisp
;; Combinators:
;;   (> a b)  descendant, (>! a b) direct-child
;;   (and a b), (or a b), (not a), (:has child-selector)
;; Simple selectors:
;;   (type> :container), (id> :main), (cls> "btn" "btn-primary")
;;   (attr> :role "dialog"), (state> :focus)
;; Pseudo:
;;   (nth-child 1), (first-child), (last-child)
```

### Rules & declarations

```lisp
;; A declaration plist uses kebab-case CSS-ish keys:
;; :display :flex, :flex-direction :row, :width :fill, :padding 1,
;; :bg-color (rgb 255 0 0), :border 1 :solid :gray, etc.

(defstruct style-value) ;; internal normalized value, hidden behind API

(defmacro defrule (selector &body declarations)
  "Create a rule object. Selector is the DSL above, declarations is a plist.")

(make-rule selector declarations)
(rule-selector rule)
(rule-declarations rule)
```

### Stylesheets

```lisp
(defstruct stylesheet
  rules           ;; vector/list of rules
  variables       ;; plist of --tokens => values
  namespace       ;; optional scope
  compiled-index) ;; internal cache/index

(defmacro defstylesheet (&body body)
  "Body: (defrule ...) forms and (defvars ...). Produces a stylesheet object.")

(make-stylesheet :rules rules :variables vars :namespace ns)
(compile-stylesheet stylesheet)      ;; precompute selector index & specificity
(merge-stylesheets &rest sheets)     ;; cascade multiple sheets (e.g., theme + app)
(with-variables sheet vars)          ;; overlay/override variables
```

### Tokens / Values helpers

```lisp
(rgb r g b) (rgba r g b a) (hsl h s l)
(px n) (em n) (rem n) (percent n) (ch n)
(len n unit) ;; fallback

;; theme/var lookup
(var "--accent")           ;; reference a variable
(resolve-variables plist vars) ;; apply variable substitution
```

### Engine (the thing you call)

```lisp
;; Core: produce patches or new objects
(apply-stylesheet-to-tree root stylesheet &key return :patches|:objects
                                        cache previous-signature)
;; Convenience when you already have a sequence:
(apply-stylesheet stylesheet objects &key return)

;; Lower-level:
(match-rules obj stylesheet)       ;; returns list of (rule specificity)
(compute-style obj rules &key inherit-from) ;; returns normalized computed-style plist
(expand-shorthands plist)          ;; border/padding/margin shorthands -> longhands
(inherit-properties parent child)  ;; apply CSS-like inheritance
(specificity selector)             ;; (a b c) tuple for ordering
```

### Contracts / errors (optional, if you like your current contracts layer)

```lisp
(define-condition style-contract-violation (error)
  ((expected :initarg :expected) (got :initarg :got) (where :initarg :where)))
```

---

# Data flow (how it plugs into TEA)

1. **view** returns your **raw tree** (no computed styles).
2. **cl-styles.engine** runs:

   * traverses tree via `stylable-*` generics,
   * matches selectors,
   * cascades + resolves variables + expands shorthands + inherits,
   * builds a **computed-style** plist per node,
   * generates **patches** via `set-computed-style` (pure).
3. Your **update/apply-patches** commits those patches into the app state.
4. Layout/render uses `get-computed-style`.

This keeps style computation purely functional and memoizable. Provide a `(style-signature root)` helper so you can short-circuit when `id/classes/inline-style/theme/vars` didn’t change.

---

# Minimal example

### Client implements protocol for its node type

```lisp
(defclass ui-node () ((id :initarg :id) (classes :initarg :classes)
                      (type :initarg :type) (inline :initarg :style)
                      (parent :accessor parent) (kids :initarg :children)
                      (computed :accessor computed-style)))

(defmethod stylable-id          ((n ui-node)) (slot-value n 'id))
(defmethod stylable-classes     ((n ui-node)) (slot-value n 'classes))
(defmethod stylable-type        ((n ui-node)) (slot-value n 'type))
(defmethod stylable-inline-style((n ui-node)) (slot-value n 'inline))
(defmethod stylable-attributes  ((n ui-node)) nil)
(defmethod stylable-state       ((n ui-node)) nil)
(defmethod stylable-parent      ((n ui-node)) (parent n))
(defmethod stylable-children    ((n ui-node)) (slot-value n 'kids))
(defmethod stylable-index       ((n ui-node))
  (let* ((p (parent n)) (sibs (and p (stylable-children p))))
    (position n sibs :test #'eq)))

;; Pure patch model (TEA friendly):
(defstruct style-patch path computed)

(defmethod set-computed-style ((n ui-node) computed)
  (make-style-patch :path (list :by-id (stylable-id n))
                    :computed computed))

(defmethod get-computed-style ((n ui-node)) (computed-style n))
```

### Author a stylesheet

```lisp
(cl-styles.sheet:defstylesheet
  (defrule (type> :container) :display :flex :flex-direction :row)
  (defrule (cls> "danger")    :bg-color (rgb 255 0 0)))
```

### Apply styles

```lisp
(let ((patches (cl-styles.engine:apply-stylesheet-to-tree root my-sheet :return :patches)))
  (apply-patches app-state patches))
```

---

# Notes on “borders / contracts” (where to encapsulate)

* **Selector boundary**: `cl-styles.selector` owns parsing/compiling, specificity, and matching *predicates*. No app awareness leaks in.
* **Rule boundary**: `cl-styles.rule` knows declarations and shorthands expansion; it never touches your nodes.
* **Engine boundary**: `cl-styles.engine` consumes only:

  * the **protocol generics**,
  * a **compiled stylesheet**,
  * and returns **computed styles** (or patches).
* **Protocol boundary**: the **only** cross-dependency. App implements `stylable-*` and `set/get-computed-style`. That’s it.

---

# Optional extensions (when you want them)

* **Theming**: `(with-variables sheet '((--accent . ,(rgb 50 120 255))))`.
* **Media-ish queries**: add an environment arg to engine, and a selector `(env> :cols >= 120)`.
* **Pseudo-classes**: extend `stylable-state` to include things like `:focus`, `:selected`, `:expanded`.
* **Namespacing**: `stylable-namespace` + sheet namespace to sandbox component libraries.

---

If you want, I can scaffold the ASDF system and drop in the package stubs with all the `defgeneric` and exported API names pre-wired—then you just fill in the matching engine or we port what you already have.




# 📦 `cl-styles.asd`

```lisp
;;; cl-styles.asd
(asdf:defsystem "cl-styles"
  :description "CSS-like styling engine for arbitrary object trees (TEA friendly)."
  :author "you"
  :license "MIT"
  :version "0.1.0"
  :depends-on (#:alexandria #:trivial-types #:uiop)
  :components
  ((:file "src/packages")          ; central package decls (optional style)
   (:file "src/protocols")
   (:file "src/tokens")
   (:file "src/selector")
   (:file "src/rule")
   (:file "src/sheet")
   (:file "src/engine")
   (:file "src/api"))
  :in-order-to ((test-op (test-op "cl-styles/tests"))))

(asdf:defsystem "cl-styles/tests"
  :depends-on (#:cl-styles #:fiveam)
  :components ((:file "tests/smoke"))
  :perform (test-op (o c)
             (uiop:symbol-call '#:fiveam '#:run!
                                (find-symbol* "SUITE" "CL-STYLES/TESTS"))))
```

---

# 🧭 `src/packages.lisp`

```lisp
(uiop:define-package :cl-styles.protocols
  (:use :cl :alexandria)
  (:export
   ;; required read + tree
   #:stylable-id #:stylable-classes #:stylable-type #:stylable-inline-style
   #:stylable-attributes #:stylable-state
   #:stylable-parent #:stylable-children #:stylable-index
   ;; required write/back-integration
   #:set-computed-style #:get-computed-style
   ;; optional extras
   #:stylable-namespace #:stylable-theme #:stylable-key))

(uiop:define-package :cl-styles.tokens
  (:use :cl :alexandria)
  (:export
   ;; color constructors
   #:rgb #:rgba #:hsl
   ;; length/size
   #:px #:percent #:em #:rem #:ch #:len
   ;; variables
   #:var
   ;; predicates (handy for consumers)
   #:color-p #:length-p #:variable-ref-p))

(uiop:define-package :cl-styles.selector
  (:use :cl :alexandria :cl-styles.protocols)
  (:export
   ;; selector AST builders
   #:type> #:id> #:cls> #:attr> #:state>
   #:first-child #:last-child #:nth-child
   #:and #:or #:not
   #:descendant> #:child> #:has
   ;; compiled selector
   #:compile-selector #:selector-specificity #:match-selector-p))

(uiop:define-package :cl-styles.rule
  (:use :cl :alexandria :cl-styles.selector :cl-styles.tokens)
  (:export
   #:rule #:make-rule #:rule-selector #:rule-declarations #:rule-specificity
   #:defrule #:expand-shorthands))

(uiop:define-package :cl-styles.sheet
  (:use :cl :alexandria :cl-styles.rule :cl-styles.selector :cl-styles.tokens)
  (:export
   #:stylesheet #:make-stylesheet #:stylesheet-rules #:stylesheet-variables
   #:stylesheet-namespace
   #:defstylesheet #:compile-stylesheet #:merge-stylesheets #:with-variables))

(uiop:define-package :cl-styles.engine
  (:use :cl :alexandria :cl-styles.protocols :cl-styles.sheet :cl-styles.rule
        :cl-styles.selector :cl-styles.tokens)
  (:export
   #:style-patch #:style-patch-path #:style-patch-computed
   #:match-rules #:compute-style #:inherit-properties
   #:apply-stylesheet #:apply-stylesheet-to-tree))

(uiop:define-package :cl-styles.api
  (:use :cl)
  (:reexport :cl-styles.protocols :cl-styles.tokens :cl-styles.selector
             :cl-styles.rule :cl-styles.sheet :cl-styles.engine))
```

---

# 🔌 `src/protocols.lisp` — **client contracts**

```lisp
(in-package :cl-styles.protocols)

;;; Minimal protocol an object must implement to be "stylable".
;;; Keep these tiny: they’re your decoupling seam.

(defgeneric stylable-id          (obj)
  (:documentation "Stable identifier for #id selectors. Return keyword/string or NIL."))

(defgeneric stylable-classes     (obj)
  (:documentation "List of classes for .class selectors. Return list of keyword/string."))

(defgeneric stylable-type        (obj)
  (:documentation "Node/tag type for type selectors. Return keyword/symbol (e.g., :container)."))

(defgeneric stylable-inline-style (obj)
  (:documentation "Inline style plist (highest priority before !important)."))

(defgeneric stylable-attributes  (obj)
  (:documentation "Arbitrary attributes for [attr=value] selectors. Return plist/alist."))

(defgeneric stylable-state       (obj)
  (:documentation "State flags for pseudo-classes (e.g., :focus :disabled). Return plist/list."))

(defgeneric stylable-parent      (obj)
  (:documentation "Return parent or NIL."))

(defgeneric stylable-children    (obj)
  (:documentation "Return sequence of children (list/vector)."))

(defgeneric stylable-index       (obj)
  (:documentation "0-based index among siblings (for nth/first/last)."))

(defgeneric set-computed-style   (obj computed-style)
  (:documentation "Attach computed style. MUST be pure in TEA: return a PATCH or a NEW-OBJ."))

(defgeneric get-computed-style   (obj)
  (:documentation "Return previously computed style plist or NIL."))

;;; Optional sugar – default NIL
(defgeneric stylable-namespace (obj))
(defgeneric stylable-theme     (obj))
(defgeneric stylable-key       (obj))

(defmethod stylable-classes ((obj t))      nil)
(defmethod stylable-inline-style ((obj t)) nil)
(defmethod stylable-attributes ((obj t))   nil)
(defmethod stylable-state ((obj t))        nil)
(defmethod stylable-namespace ((obj t))    nil)
(defmethod stylable-theme ((obj t))        nil)
(defmethod stylable-key ((obj t))          (or (stylable-id obj) (cons (stylable-type obj) (stylable-attributes obj))))
```

---

# 🎨 `src/tokens.lisp` — **values + helpers**

```lisp
(in-package :cl-styles.tokens)

;;; Colors (just plists for simplicity; swap to deftype/struct if you want)
(defun rgb  (r g b)  (list :rgb r g b))
(defun rgba (r g b a) (list :rgba r g b a))
(defun hsl  (h s l)  (list :hsl h s l))

(defun color-p (x) (and (consp x) (member (first x) '(:rgb :rgba :hsl))))

;;; Lengths
(defun px (n)       (list :px n))
(defun percent (n)  (list :percent n))
(defun em (n)       (list :em n))
(defun rem (n)      (list :rem n))
(defun ch (n)       (list :ch n))
(defun len (n unit) (list unit n))

(defun length-p (x) (and (consp x) (member (first x) '(:px :percent :em :rem :ch))))

;;; Variables (CSS custom properties)
(defun var (name) (list :var name))
(defun variable-ref-p (x) (and (consp x) (eql (first x) :var)))
```

---

# 🔎 `src/selector.lisp` — **selector AST + compiler**

```lisp
(in-package :cl-styles.selector)

;;; A tiny S-expr DSL -> predicate compiler
;;; We compile to a lambda (obj) -> boolean. Specificity is tracked alongside.

;; Builders (AST nodes; they are plain lists with tags)
(defun type>  (type)        (list :type type))
(defun id>    (id)          (list :id id))
(defun cls>   (&rest names) (list* :class names))
(defun attr>  (key &optional value) (list :attr key value))
(defun state> (&rest flags) (list* :state flags))

(defun first-child () (list :pseudo :first-child))
(defun last-child  () (list :pseudo :last-child))
(defun nth-child   (n) (list :pseudo :nth-child n))

(defun and (&rest xs)       (list* :and xs))
(defun or  (&rest xs)       (list* :or xs))
(defun not (x)              (list :not x))
(defun descendant> (a b)    (list :desc a b))
(defun child>      (a b)    (list :child a b))
(defun has         (x)      (list :has x))

;;; Specificity as a 3-tuple (a id-count, b class/attr/pseudo, c type)
(defun %add-spec (a b) (list (+ (first a) (first b))
                             (+ (second a) (second b))
                             (+ (third a) (third b))))

(defun selector-specificity (sel)
  (labels ((spec (s)
             (etypecase s
               (cons
                (case (first s)
                  (:id        '(1 0 0))
                  ((:class :attr :state :has :pseudo) '(0 1 0))
                  (:type      '(0 0 1))
                  (:and       (reduce #'%add-spec (rest s) :initial-value '(0 0 0)
                                      :key #'spec))
                  (:or        (reduce #'alexandria:maxf (mapcar #'spec (rest s))))
                  (:not       '(0 1 0))
                  ((:child :desc) (let ((a (second s)) (b (third s)))
                                    (%add-spec (spec a) (spec b))))
                  (t '(0 0 0))))
               (t '(0 0 0)))))
    (spec sel)))

;;; Matching compiler
(defun compile-selector (sel)
  "Return a predicate (lambda (obj) ...) that uses the stylable-* protocol."
  (labels
      ((pred (s)
         (case (first s)
           (:type (let ((tgt (second s)))
                    (lambda (o) (eql (stylable-type o) tgt))))
           (:id   (let ((id (second s)))
                    (lambda (o) (and (stylable-id o) (string= (string (stylable-id o))
                                                              (string id))))))
           (:class (let ((want (mapcar #'string (rest s))))
                     (lambda (o)
                       (let ((have (mapcar #'string (stylable-classes o))))
                         (every (lambda (c) (member c have :test #'string=)) want)))))
           (:attr (let ((k (second s)) (v (third s)))
                    (lambda (o)
                      (let ((attrs (stylable-attributes o)))
                        (if v (equal (getf attrs k) v)
                              (getf attrs k))))))
           (:state (let ((need (rest s)))
                    (lambda (o)
                      (let ((st (stylable-state o)))
                        (every (lambda (flag) (find flag st :test #'eql)) need)))))
           (:pseudo
            (let ((which (second s)))
              (ecase which
                (:first-child (lambda (o) (eql (stylable-index o) 0)))
                (:last-child  (lambda (o)
                                (let* ((p (stylable-parent o))
                                       (kids (and p (stylable-children p))))
                                  (and kids (eql (stylable-index o) (1- (length kids)))))))
                (:nth-child   (let ((n (third s)))
                                (lambda (o) (eql (stylable-index o) n)))))))
           (:and (let ((ps (mapcar #'pred (rest s))))
                   (lambda (o) (every (lambda (p) (funcall p o)) ps))))
           (:or  (let ((ps (mapcar #'pred (rest s))))
                   (lambda (o) (some (lambda (p) (funcall p o)) ps))))
           (:not (let ((p (pred (second s))))
                   (lambda (o) (not (funcall p o)))))
           (:child
            (let* ((a (second s)) (b (third s))
                   (pa (pred a)) (pb (pred b)))
              (lambda (o)
                (and (funcall pb o)
                     (let ((p (stylable-parent o)))
                       (and p (funcall pa p)))))))
           (:desc
            (let* ((a (second s)) (b (third s))
                   (pa (pred a)) (pb (pred b)))
              (lambda (o)
                (and (funcall pb o)
                     (loop for p = (stylable-parent o) then (and p (stylable-parent p))
                           while p
                           thereis (funcall pa p))))))
           (:has
            (let ((pchild (pred (second s))))
              (lambda (o)
                (loop for c in (stylable-children o) thereis (funcall pchild c)))))
           (t (error "Unknown selector node: ~S" s)))))
    (pred sel)))

(defun match-selector-p (selector obj)
  (funcall (compile-selector selector) obj))
```

---

# 📐 `src/rule.lisp` — **rules + shorthands**

```lisp
(in-package :cl-styles.rule)

(defstruct rule
  selector          ;; AST (from cl-styles.selector)
  predicate         ;; compiled predicate (obj -> boolean)
  declarations      ;; plist of style declarations (normalized)
  specificity)      ;; 3-tuple used for cascade sort

(defun make-rule (selector declarations)
  (let* ((norm (expand-shorthands declarations)))
    (make-rule :selector selector
               :predicate (cl-styles.selector:compile-selector selector)
               :declarations norm
               :specificity (cl-styles.selector:selector-specificity selector))))

(defmacro defrule (selector &body decls)
  "S-expr selector + plist body."
  `(make-rule ',selector ',decls))

;;; Super small shorthand expansion (extend as you like)
(defun %expand-4 (v)
  ;; CSS 1 / 2 / 3 value expansion for padding/margin etc.
  (etypecase v
    (null (list nil nil nil nil))
    (number (list v v v v))
    (cons
     (let* ((xs v) (n (length xs)))
       (ecase n
         (1 (make-list 4 :initial-element (first xs)))
         (2 (destructuring-bind (y x) xs (list y x y x)))
         (3 (destructuring-bind (a b c) xs (list a b c b)))
         (4 xs))))))

(defun expand-shorthands (plist)
  (labels ((putf (acc k v) (setf (getf acc k) v) acc))
    (let ((acc (copy-list plist)))
      ;; padding / margin
      (dolist (kw '(:padding :margin))
        (when (getf acc kw)
          (destructuring-bind (t r b l) (%expand-4 (getf acc kw))
            (remf acc kw)
            (setf acc (putf acc (intern (format nil "~A-TOP" kw)) t))
            (setf acc (putf acc (intern (format nil "~A-RIGHT" kw)) r))
            (setf acc (putf acc (intern (format nil "~A-BOTTOM" kw)) b))
            (setf acc (putf acc (intern (format nil "~A-LEFT" kw)) l)))))
      ;; border (toy)
      (when (getf acc :border)
        (destructuring-bind (w style color) (getf acc :border)
          (remf acc :border)
          (dolist (side '(:top :right :bottom :left))
            (setf acc (putf acc (intern (format nil "BORDER-~A-WIDTH" side)) w))
            (setf acc (putf acc (intern (format nil "BORDER-~A-STYLE" side)) style))
            (setf acc (putf acc (intern (format nil "BORDER-~A-COLOR" side)) color)))))
      acc)))
```

---

# 📚 `src/sheet.lisp` — **stylesheets**

```lisp
(in-package :cl-styles.sheet)

(defstruct stylesheet
  rules            ;; list of RULE
  variables        ;; plist of --var => value
  namespace)       ;; optional scope marker

(defun make-stylesheet (&key rules variables namespace)
  (make-stylesheet :rules rules :variables variables :namespace namespace))

(defmacro defstylesheet (&body forms)
  "Body contains (defrule ...) and optionally (:vars plist) and (:namespace x)"
  (let ((rules '()) (vars nil) (ns nil))
    (dolist (f forms)
      (cond
        ((and (consp f) (eq (car f) 'defrule))
         (push (eval f) rules))
        ((and (consp f) (eq (car f) :vars))
         (setf vars (cadr f)))
        ((and (consp f) (eq (car f) :namespace))
         (setf ns (cadr f)))
        (t (error "Unknown form in stylesheet: ~S" f))))
    `(make-stylesheet :rules (list ,@(nreverse rules))
                      :variables ',vars :namespace ',ns)))

(defun compile-stylesheet (sheet)
  "Currently a no-op placeholder – you could build selector indexes here."
  sheet)

(defun merge-stylesheets (&rest sheets)
  (make-stylesheet
   :rules (alexandria:mappend #'stylesheet-rules sheets)
   :variables (apply #'append (mapcar #'stylesheet-variables sheets))
   :namespace (or (stylesheet-namespace (car (last sheets)))
                  (and sheets (stylesheet-namespace (car sheets))))))

(defun with-variables (sheet vars)
  (make-stylesheet :rules (stylesheet-rules sheet)
                   :variables (append vars (stylesheet-variables sheet))
                   :namespace (stylesheet-namespace sheet)))
```

---

# 🧠 `src/engine.lisp` — **matching, cascade, inheritance, patches**

```lisp
(in-package :cl-styles.engine)

;;;; Patch object (TEA-friendly)
(defstruct style-patch
  path       ;; up to you; consumers often use (:by-id <id>) or full zippers
  computed)  ;; final computed style plist

;;;; Utilities

(defun %object-key (o)
  ;; Stable cache key default
  (or (cl-styles.protocols:stylable-key o)
      (list (cl-styles.protocols:stylable-type o)
            (cl-styles.protocols:stylable-id o))))

(defun %resolve-variables (plist variables)
  (labels ((res (v)
             (cond
               ((cl-styles.tokens:variable-ref-p v)
                (or (getf variables (second v)) v))
               ((consp v) (mapcar #'res v))
               (t v))))
    (loop for (k v) on plist by #'cddr
          append (list k (res v)))))

(defun %inline-style-rule (obj)
  (let ((inline (cl-styles.protocols:stylable-inline-style obj)))
    (when inline
      ;; inline wins vs author rules (but before !important if you add it later)
      (cl-styles.rule:make-rule (cl-styles.selector:and) inline))))

(defun %sorted-rules-for (obj sheet)
  "Collect rules that match OBJ, plus inline, sort by specificity and source order."
  (let* ((matches
           (loop for r in (cl-styles.sheet:stylesheet-rules sheet)
                 when (funcall (cl-styles.rule:rule-predicate r) obj)
                 collect r))
         (inline (%inline-style-rule obj)))
    (when inline (push inline matches))
    ;; stable-sort by specificity; earlier rules win on tie (CSS is stable)
    (stable-sort matches
                 (lambda (a b)
                   (let ((sa (cl-styles.rule:rule-specificity a))
                         (sb (cl-styles.rule:rule-specificity b)))
                     (cond
                       ((> (first sa) (first sb)) t)
                       ((< (first sa) (first sb)) nil)
                       ((> (second sa) (second sb)) t)
                       ((< (second sa) (second sb)) nil)
                       ((> (third sa) (third sb)) t)
                       (t nil)))))))

(defun match-rules (obj sheet)
  (%sorted-rules-for obj sheet))

(defun inherit-properties (parent-style child-plist)
  "Minimal CSS-like inheritance. Extend with your property matrix."
  (let ((inheritable '(:font-family :font-size :color :text-align :text-wrap)))
    (loop for k in inheritable
          for v = (getf child-plist k)
          unless v
            do (setf (getf child-plist k) (getf parent-style k)))
    child-plist))

(defun compute-style (obj rules &key inherit-from variables)
  (let* ((merged (loop for r in rules
                       nconc (copy-list (cl-styles.rule:rule-declarations r))))
         (with-vars (%resolve-variables merged variables))
         (inherited (if inherit-from
                        (inherit-properties inherit-from with-vars)
                        with-vars)))
    inherited))

;;;; Traversal + application

(defun %walk (root fn-acc)
  "Depth-first traversal calling (fn-acc obj parent-acc) -> acc"
  (labels ((rec (node parent-acc)
             (let ((acc (funcall fn-acc node parent-acc)))
               (dolist (c (cl-styles.protocols:stylable-children node))
                 (rec c acc)))))
    (rec root nil)))

(defun apply-stylesheet-to-tree (root sheet &key (return :patches))
  "Traverse ROOT via protocol, compute styles from SHEET, return patches or objects."
  (let ((vars (cl-styles.sheet:stylesheet-variables sheet))
        (patches '()))
    (%walk root
           (lambda (obj parent-style)
             (let* ((rules (match-rules obj sheet))
                    (cur (compute-style obj rules
                                        :inherit-from parent-style
                                        :variables vars))
                    (patch (cl-styles.protocols:set-computed-style obj cur)))
               ;; Expect PATCH (pure); your consumer decides its shape
               (when (typep patch 'style-patch) (push patch patches))
               cur)))
    (ecase return
      (:patches (nreverse patches))
      (:objects root))))

(defun apply-stylesheet (sheet objects &key (return :patches))
  "Apply to a flat sequence (no inheritance other than inline/vars)."
  (let ((vars (cl-styles.sheet:stylesheet-variables sheet))
        (patches '()))
    (dolist (obj objects)
      (let* ((rules (match-rules obj sheet))
             (cur (compute-style obj rules :variables vars))
             (patch (cl-styles.protocols:set-computed-style obj cur)))
        (when (typep patch 'style-patch) (push patch patches))))
    (ecase return
      (:patches (nreverse patches))
      (:objects objects))))
```

---

# 🧰 `src/api.lisp` — **single import point**

```lisp
(in-package :cl-styles.api)
;; nothing here; we reexport everything in :cl-styles.api package definition
```

---

# 🧪 `tests/smoke.lisp` — tiny consumer + smoke test

```lisp
(uiop:define-package :cl-styles/tests
  (:use :cl :fiveam :alexandria :cl-styles.api))

(in-package :cl-styles/tests)

(def-suite suite)
(in-suite suite)

;;; A toy consumer node (you'll replace with your own)
(defclass node ()
  ((id       :initarg :id :reader stylable-id)
   (type     :initarg :type :reader stylable-type)
   (classes  :initarg :classes :initform nil)
   (attrs    :initarg :attrs :initform nil)
   (state    :initarg :state :initform nil)
   (style    :accessor computed-style :initform nil)
   (parent   :accessor stylable-parent)
   (kids     :initarg :children :initform nil :accessor stylable-children)))

(defmethod stylable-classes ((n node)) (slot-value n 'classes))
(defmethod stylable-attributes ((n node)) (slot-value n 'attrs))
(defmethod stylable-state ((n node)) (slot-value n 'state))
(defmethod stylable-index ((n node))
  (let* ((p (stylable-parent n))
         (sibs (and p (stylable-children p))))
    (position n sibs :test #'eq)))
(defmethod stylable-inline-style ((n node)) nil)

;;; Build parent links for the test tree.
(defun link! (parent)
  (dolist (c (stylable-children parent))
    (setf (stylable-parent c) parent)
    (link! c))
  parent)

;;; TEA-friendly patch shape
(defmethod set-computed-style ((n node) computed)
  (make-style-patch :path (list :by-id (stylable-id n))
                    :computed computed))
(defmethod get-computed-style ((n node)) (computed-style n))

(test simple-cascade
  (let* ((root (link! (make-instance 'node :id :root :type :container
                                     :children (list
                                                (make-instance 'node :id :a :type :text :classes '("danger"))
                                                (make-instance 'node :id :b :type :text)))))

         (sheet (defstylesheet
                  (defrule (type> :container) :color (rgb 200 200 200))
                  (defrule (cls> "danger")    :color (rgb 255 0 0))
                  (defrule (child> (type> :container) (type> :text)) :font-size 14)))

         (patches (apply-stylesheet-to-tree root sheet :return :patches)))
    (is (= 3 (length patches)))
    ;; Inspect one patch for fun
    (let ((p (find :a patches :key #'style-patch-path :test (lambda (k pth)
                                                              (equal pth (list :by-id k))))))
      (is (equal (getf (style-patch-computed p) :color) (rgb 255 0 0))))
    t))
```

---

# 🧩 What you implement in **your** app (summary)

You only need to implement the **protocol** on your node type(s):

* `stylable-id`, `stylable-classes`, `stylable-type`, `stylable-inline-style`
* `stylable-attributes`, `stylable-state`
* `stylable-parent`, `stylable-children`, `stylable-index`
* `set-computed-style` → return a **patch** (pure)
* `get-computed-style` (optional, for caching/incremental diff)

Then you author sheets with:

```lisp
(defparameter *base-sheet*
  (defstylesheet
    :vars ((--accent . ,(rgb 64 120 255)))
    (defrule (type> :container) :display :flex :flex-direction :row)
    (defrule (cls> "primary")   :bg-color (var --accent))))
```

…and run:

```lisp
(cl-styles.api:apply-stylesheet-to-tree root *base-sheet* :return :patches)
```
