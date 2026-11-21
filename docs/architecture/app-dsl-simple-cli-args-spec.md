# App DSL Simple CLI Args Spec

## Status

Proposed

## Problem

`defapplication` already supports low-level `:cli-options` specs and `:configure-fn`, but authoring simple app arguments is still verbose and platform-option-centric. Most apps need a smaller, declarative way to define:

- typed arguments,
- defaults/env overrides,
- help text,
- app-level access to parsed values without manual glue.

## Goals

- add a concise DSL for common CLI arguments in `defapplication`,
- preserve existing `:cli-options` compatibility,
- expose parsed args to app initialization/update in a canonical way,
- keep implementation deterministic and testable.

## Non-goals

- replacing the existing packager CLI,
- adding subcommands,
- adding arbitrary shell parser behavior (short clusters, GNU edge cases).

## Proposed API

Add a new optional keyword to `defapplication`:

- `:args`

` :args` accepts a list of simple arg specs:

```lisp
(:name :fps
 :long "--fps"
 :short "-f"         ; optional
 :type integer       ; string|integer|keyword|boolean
 :default 60         ; optional
 :env "APP_FPS"      ; optional
 :doc "Target frames per second")
```

Example:

```lisp
(defapplication demo-app
  :root-component-dsl '(:layout :id :main)
  :root-viewport-id :demo-root
  :args '((:name :fps :long "--fps" :type integer :default 60 :doc "Frame rate")
          (:name :debug :long "--debug" :type boolean :default nil :doc "Enable debug mode")))
```

## Semantics

### Parse precedence

For each arg:
1. explicit CLI value,
2. environment value (`:env`),
3. `:default`,
4. absent.

### Boolean behavior

- presence-only flag sets `t` (`--debug`),
- optional explicit `true/false/1/0/yes/no` values still accepted when provided via env or value form.

### Unknown args

Default behavior:
- ignore unknown args (for compatibility with outer runners).

Optional strict mode (future):
- `:args-mode :strict` signals on unknown arguments.

## Runtime integration

In generated `RUN-<APP>`:

1. parse args from `argv` into `parsed-args` plist,
2. store in app spec under `:cli-args`,
3. merge platform-related args into `platform-options` only when explicitly marked.

In generated init path:

- pass `:cli-args` as a keyword argument to `INITIALIZE-APP-STATE-<APP>`,
- also store `:cli` subtree in initial app state for update/view access:
  - `(:cli :fps)`, `(:cli :debug)`, etc.

This avoids hidden global reads and keeps data in model/state.

## Backward compatibility

- existing `:cli-options` remains supported,
- if both `:args` and `:cli-options` are provided:
  - compile-time normalize both into one validated spec list,
  - fail on duplicate `:name`/`:long`/`:short`.

Migration guidance:
- simple apps should prefer `:args`,
- advanced apps can continue to use raw `:cli-options`.

## Validation rules

Each spec must include:

- `:name`, `:long`, `:type`.

Optional keys:

- `:short`, `:default`, `:env`, `:doc`.

Validation checks:

- unique `:name`, `:long`, `:short`,
- supported type,
- default type compatibility,
- `:long` begins with `--`,
- `:short` is `-x` form.

## Implementation plan

### Phase A: Normalization layer

- add `normalize-simple-args-specs` in `src/app/application-extension.lisp`,
- map `:args` to existing internal option spec format.

### Phase B: Macro wiring

- extend `defapplication` known keys with `:args`,
- merge normalized `:args` + existing `:cli-options`,
- keep existing `parse-cli-options` path.

### Phase C: App-state exposure

- pass parsed args through run/init and store in initial state at `:cli`,
- add helper `elmtui.app.api:get-cli-arg` (optional convenience).

### Phase D: Tests

Add tests for:

- parse precedence (cli > env > default),
- boolean flags,
- duplicate/conflicting specs,
- mixed `:args` + `:cli-options`,
- state exposure in generated app init.

## Acceptance criteria

- app author can declare simple args with `:args` only,
- parsed args are available in app state without custom glue,
- existing `:cli-options` apps continue to pass unchanged,
- test suite includes coverage for validation, parsing, and runtime integration.
