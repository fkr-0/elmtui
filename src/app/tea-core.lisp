;;; == elmtui/app/tea-core.lisp ==

(uiop:define-package :elmtui.app.tea-core
  (:use :cl)
  (:import-from :elmtui.core.event-channels
    #:make-message-channel)
  (:import-from :elmtui.app.api
    #:run-application
    #:make-runtime-app-spec)
  (:export
    #:deftea-app))

(in-package :elmtui.app.tea-core)

(defun %ensure-root-keyword (id)
  "Internal helper.

ID may be:
  - a keyword (returned as-is),
  - a symbol (its name is INTERNed in the KEYWORD package),
  - a string (INTERNed in the KEYWORD package).

Signals an error for all other types."
  (etypecase id
    (keyword id)
    (symbol  (intern (string id) :keyword))
    (string  (intern id :keyword))))

(defmacro deftea-app (name
                       &key
                       init
                       transition
                       update
                       view
                       subscriptions
                       command-processor
                       (root-viewport-id :root-viewport))
  "Define a supported minimal direct-transition TEA application and RUN-NAME.

DEFTEA-APP is intentionally the small/pedagogical constructor, not the normative
full application constructor for the next stable major version. Use
ELMTUI.APP:DEFAPPLICATION for production application composition, component and
root-viewport initialization, CL-STATE patch/context updates, CLI/binary
configuration, keymaps, and selectable transaction semantics. DEFTEA-APP remains
compatible for direct model-replacement programs and lowers through the same
MAKE-RUNTIME-APP-SPEC INIT/TRANSITION/VIEW/SUBSCRIPTIONS vocabulary.

Syntax:

  (deftea-app NAME
    :init       INIT-FN
    :transition TRANSITION-FN
    :view       VIEW-FN
    &key
      :subscriptions      SUBS-FN
      :command-processor  CMD-FN
      :root-viewport-id   ROOT-ID)

Required arguments:

  NAME
    A non-keyword symbol naming the application. This is used to derive:

      * *NAME-APP-SPEC* — a DEFparameter holding the app spec plist
      * RUN-NAME        — a function that hands the spec to RUN-APPLICATION

  :INIT
    A function designator (symbol or lambda) called with no arguments:

      INIT-FN :: () -> (values MODEL COMMANDS)

    MODEL
      Arbitrary application model object (often a plist or hash table).
    COMMANDS
      A list of \"commands\" understood by the command processor,
      or NIL if there are no startup side-effects.

  :TRANSITION
    The canonical direct transition function designator called for each message:

      TRANSITION-FN :: (MSG MODEL) -> (values NEXT-MODEL COMMANDS)

    :UPDATE is retained as a legacy compatibility alias for :TRANSITION. Do not
    specify both; new code should use :TRANSITION.

    MSG
      An arbitrary message object (often a keyword or small list).
    MODEL / NEXT-MODEL
      The current / next model. NEXT-MODEL must be suitable for
      subsequent calls to TRANSITION and VIEW.
    COMMANDS
      A list of commands to execute after the update, or NIL.

  :VIEW
    A function designator that renders the current model into a DSL tree:

      VIEW-FN :: MODEL -> DSL-TREE

    DSL-TREE
      A tree of view nodes understood by the rendering pipeline.
      In a typical setup the root node is a ROOT-VIEWPORT widget,
      often of the form:

        (:root-viewport :id ROOT-ID ...)

    where ROOT-ID matches the :ROOT-VIEWPORT-ID argument below.

Optional keywords:

  :SUBSCRIPTIONS
    A function designator

      SUBS-FN :: MODEL -> LIST-OF-SUBSCRIPTIONS

    or NIL.  If NIL, it is replaced with a function that always
    returns NIL.  This function is passed to the driver in the
    :SUBSCRIPTIONS-FN slot of the app spec and may be used by the
    event loop to (re-)establish subscriptions after each update.

  :COMMAND-PROCESSOR
    A function designator

      CMD-FN :: (CMD QUEUE MODEL APP-CONFIG) -> *

    or NIL.  If non-NIL, the driver calls it for each command
    produced by TRANSITION, passing:

      CMD        — the command object
      QUEUE      — the app's message queue (for enqueuing new MSGs)
      MODEL      — the current model *after* the update
      APP-CONFIG — optional configuration object (may be NIL)

    For a minimal TEA app you can omit this entirely.

  :ROOT-VIEWPORT-ID
    A symbol, keyword, or string naming the logical root viewport.
    It is converted to a keyword via a small helper and passed as
    :ROOT-VIEWPORT-ID in the app spec.  The platform driver uses this
    to compute the root component path.

    If omitted, defaults to :ROOT-VIEWPORT.

Expansion / side effects:

  (deftea-app NAME ...) expands to:

    - A DEFparameter

        *NAME-APP-SPEC*

      containing a plist with at least:

        :name                NAME
        :init-fn             INIT-FN
        :update-fn           TRANSITION-FN  ; legacy internal runtime key
        :view-fn             VIEW-FN
        :subscriptions-fn    SUBS-FN-OR-DEFAULT
        :command-processor-fn COMMAND-PROCESSOR
        :message-queue       (MAKE-MESSAGE-CHANNEL :CAPACITY 20)
        :root-viewport-id    ROOT-ID-KEYWORD

    - A function

        (defun RUN-NAME (&key (platform :terminal) platform-options &allow-other-keys)
          ...)

      which simply calls ELMTUI.APP.API:RUN-APPLICATION with the
      constructed spec and the given backend options.

Contracts / validation:

  * NAME must be a non-keyword symbol.
  * :INIT, :VIEW, and one of canonical :TRANSITION or legacy :UPDATE must be
    non-NIL and suitable as FUNCALL arguments (symbol or lambda).
  * :ROOT-VIEWPORT-ID must resolve to a keyword; an error is signaled
    at macro-expansion time for unsupported types.

  If the ELMTUI.CONTRACTS package is loaded and provides the function
  VALIDATE-ELM-APPLICATION, a sanity check is run once at load-time:

    (validate-elm-application UPDATE-FN VIEW-FN SUBS-FN)

  using a synthetic test model.  If this check fails, an error is
  signaled during load, so application contracts fail fast."
  ;; --- basic macro-time validation ------------------------------------
  (unless (and (symbolp name) (not (keywordp name)))
    (error "DEFTEA-APP: NAME must be a non-keyword symbol, got: ~S" name))

  (when (null init)
    (error "DEFTEA-APP ~S: :INIT is required." name))
  (when (and transition update)
    (error "DEFTEA-APP ~S: specify :TRANSITION or legacy :UPDATE, not both." name))
  (when (and (null transition) (null update))
    (error "DEFTEA-APP ~S: :TRANSITION is required (legacy :UPDATE is accepted)." name))
  (setf update (or transition update))
  (when (null view)
    (error "DEFTEA-APP ~S: :VIEW is required." name))

  (let* ((root-key (%ensure-root-keyword root-viewport-id))
          (app-spec-var (intern (format nil "*~A-APP-SPEC*" name)
                          (symbol-package name)))
          (run-fn-name (intern (format nil "RUN-~A" name)
                         (symbol-package name)))
          ;; default subscriptions fn if none was provided
          (subs-expr (or subscriptions
                       '(lambda (model)
                          (declare (ignore model))
                          nil))))
    `(progn
       ;; --------------------------------------------------------------
       ;; 1. Define the application specification plist
       ;; --------------------------------------------------------------
       (defparameter ,app-spec-var
         (make-runtime-app-spec
           :name ',name
           :init ,init
           :transition ,update
           :view ,view
           :subscriptions ,subs-expr
           :state-semantics :strict-elm
           :command-processor ,command-processor
           :message-queue (make-message-channel :capacity 20)
           :root-viewport-id ',root-key)
         ,(format nil
            "Application spec for ~S.

This plist is consumed by ELMTUI.APP.API:RUN-APPLICATION and the
platform driver.  It is generated by DEFTEA-APP and normally not
modified directly at runtime." name))

       ;; --------------------------------------------------------------
       ;; 2. Optional contract validation (if elmtui.contracts is around)
       ;; --------------------------------------------------------------
       (when (fboundp 'elmtui.contracts:validate-elm-application)
         (elmtui.contracts:validate-elm-application
           ,update
           ,view
           ,subs-expr))

       ;; --------------------------------------------------------------
       ;; 3. Public entry point: RUN-<NAME>
       ;; --------------------------------------------------------------
       (defun ,run-fn-name (&key (platform :tty) platform-options
                             &allow-other-keys)
         "Run the TEA application defined by DEFTEA-APP.

Arguments:

  :PLATFORM
    Backend selector keyword understood by RUN-APPLICATION
    (e.g. :TERMINAL).

  :PLATFORM-OPTIONS
    Implementation-specific plist passed through to the backend.

Side effects:

  Delegates to ELMTUI.APP.API:RUN-APPLICATION with the app spec
  stored in *NAME-APP-SPEC*."
         (run-application
           ,app-spec-var
           :backend-type platform
           :platform-options platform-options))

       ',name)))

;;; == end/tea-core.lisp ==
