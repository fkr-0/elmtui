# Elmtui Changelog

All notable changes to the Elmtui project will be documented in this file.

### Fixed
- Fixed several issues in the `defcomponent` macro, including accessor function generation, default view generation, and state management for test environments.
- Improved the pass rate of the test suite from 87% to 89%.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (hopefully, or aims to).

## [Unreleased]
### Fixed
- Added defensive method for [`stylable-id`](../../src/view/api.lisp) on `ui-node` to prevent method errors.
- Normalized `styled-tree` in [`render-frame`](../../src/platform/driver.lisp) to always be a list, preventing type errors when the view root is a single node.
- The render pipeline now distinguishes between an empty UI tree (treated as a valid "no-op" and logged as such, with frame rendering skipped) and all other cases where the rendered canvas is NIL (treated as errors, logged, and the application is halted). This aligns with Elm/TEA and Elmtui philosophy: empty UI is not an error, but unexpected NIL from rendering is a bug and must be surfaced.

### Known Issues
- If the event channel is closed (e.g., after shutdown or error), the event consumer loop will signal `Channel is closed.` This is a runtime condition, not a bug in the render pipeline. Ensure all event producers/consumers are correctly synchronized and channels are not used after closure.


### Added
*   **Comprehensive Documentation Review (2025-06-27):**
    *   Systematically reviewed all module overview and implementation documents for accuracy, metadata, and AI marker compliance.
    *   Validated consistency across architecture, module, and navigation docs.
    *   Ensured changelog and task plan reflect the current documentation state.
*   Initial structure for AI-Optimized Documentation Management System.
    *   Created `docs/ai-index/` with `overview.md`, `navigation-guide.md`, `documentation-guide.md`.
    *   Created `docs/architecture/` with `system-overview.md`, `tech-stack.md`, `core-concepts.md`, `module-dependencies.md`.
    *   Created `docs/dev-guides/` with `setup.md`, `troubleshooting.md`, `contribution-guide.md`, `coding-standards.md`, `creating-widgets.md`.
    *   Created `docs/tasks/current-task-plan.md`.
    *   Created `docs/maintenance/changelog.md`.
*   Renamed original `docs` directory to `docs_old`.
*   Created `ai_documentation_plan.md` in project root.
*   **Comprehensive Module Documentation Update (2025-06-19):**
    *   Created complete module overview documentation for all core modules:
        *   [`docs/modules/app/overview.md`](../modules/app/overview.md) - Application lifecycle and orchestration
        *   [`docs/modules/core/overview.md`](../modules/core/overview.md) - Event loop, focus management, and message bus
        *   [`docs/modules/state/overview.md`](../modules/state/overview.md) - TEA implementation and state management
        *   [`docs/modules/ui/overview.md`](../modules/ui/overview.md) - Component system and widget library
        *   [`docs/modules/clevelib/overview.md`](../modules/clevelib/overview.md) - Low-level CFFI bindings and system interface
        *   [`docs/modules/utils/overview.md`](../modules/utils/overview.md) - General utility functions and helpers
        *   [`docs/modules/dev/overview.md`](../modules/dev/overview.md) - Development and debugging tools
    *   All module documentation follows AI-optimized standards with proper metadata, context markers, and cross-references.
    *   Updated existing module overviews ([`platform`](../modules/platform/overview.md), [`view`](../modules/view/overview.md), [`style`](../modules/style/overview.md)) for consistency.
*   **Comprehensive Dependency Analysis and API Refactoring Plan (2025-06-19):**
    *   Created [`docs/architecture/dependency-analysis.md`](../architecture/dependency-analysis.md) with thorough analysis of current module dependencies
    *   Identified circular dependencies and tight coupling issues in current architecture
    *   Designed comprehensive 5-phase refactoring plan to establish clean API boundaries
    *   Proposed API-driven architecture with clear interface segregation and dependency inversion
    *   Included risk mitigation strategies and success metrics for architectural refactoring

### Changed
*   Updated `docs/modules/app/implementation.md` to document the correct `run-application` API signature and usage.
*   Improved documentation consistency for application startup and example usage.

### Fixed
*   Added missing method for `elmtui.app.api:run-application` specializing on `(app-spec list)`, resolving "no applicable method" error for example apps using `defapplication`.
*   Rainbow example now runs as intended.

### Added
*   Created `docs/examples/rainbow-app.md` with metadata, usage, and implementation notes for the Rainbow example application.
*   All components now store their originating DSL form in their state under the `:dsl` key by default, handled by the base `component` class's `init` method.

### Deprecated
*   (For future changes)

### Removed
*   (For future changes)

### Fixed
*   (For future changes)

### Security
*   (For future changes)

## [Version X.Y.Z] - YYYY-MM-DD

### Added
*   ...

### Changed
*   ...

### Fixed
*   ...

---
*Older changelog entries might be found in commit history or previous release notes if this file is new.*