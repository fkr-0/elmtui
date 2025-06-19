# Elmtui Changelog

All notable changes to the Elmtui project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (hopefully, or aims to).

## [Unreleased]

### Added
*   Initial structure for AI-Optimized Documentation Management System.
    *   Created `docs/ai-index/` with `overview.md`, `navigation-guide.md`, `documentation-guide.md`.
    *   Created `docs/architecture/` with `system-overview.md`, `tech-stack.md`, `core-concepts.md`, `module-dependencies.md`.
    *   Created `docs/dev-guides/` with `setup.md`, `troubleshooting.md`, `contribution-guide.md`, `coding-standards.md`, `creating-widgets.md`.
    *   Created `docs/tasks/current-task-plan.md`.
    *   Created `docs/maintenance/changelog.md`.
*   Renamed original `docs` directory to `docs_old`.
*   Created `ai_documentation_plan.md` in project root.

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