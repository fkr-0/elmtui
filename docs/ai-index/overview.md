---
# AI Metadata Tags
ai_keywords: [AI Index, Elmtui Project, Documentation System, Core Modules, Technology Stack, Project Overview, Navigation]
ai_contexts: [meta, navigation]
ai_relations: [
  "./navigation-guide.md",
  "./documentation-guide.md",
  "../architecture/system-overview.md",
  "../architecture/core-concepts.md",
  "../architecture/module-dependencies.md",
  "../architecture/tech-stack.md",
  "../modules/app/overview.md",
  "../modules/clevelib/overview.md",
  "../modules/core/overview.md",
  "../modules/dev/overview.md",
  "../modules/platform/overview.md",
  "../modules/state/overview.md",
  "../modules/ui/overview.md",
  "../modules/utils/overview.md",
  "../modules/view/overview.md"
]
---
# Elmtui Project Overview (AI-Index)

This document provides a high-level overview of the Elmtui project, its core modules, technology stack, and the structure of this AI-optimized documentation system. It serves as the primary entry point for AI assistants to understand the project.

## Project Introduction

Elmtui is a Common Lisp library for building Terminal User Interfaces (TUIs). It is inspired by The Elm Architecture (TEA) and aims to provide a declarative and component-based approach to TUI development.

## Core Functional Modules

The core modules of Elmtui include:
- [`app`](../modules/app/overview.md): Application lifecycle management and top-level orchestration.
- [`clevelib`](../modules/clevelib/overview.md): Low-level CFFI bindings and system interactions (e.g., termios).
- [`core`](../modules/core/overview.md): Event loop, message bus, input handling, and focus management.
- [`dev`](../modules/dev/overview.md): Development utilities, debugging tools, and introspection.
- [`platform`](../modules/platform/overview.md): Platform-specific backend drivers for terminal I/O and rendering.
- [`state`](../modules/state/overview.md): State management based on TEA principles (model, update).
- [`ui`](../modules/ui/overview.md): UI component definition (`defcomponent`), standard widgets, and component lifecycle.
- [`utils`](../modules/utils/overview.md): General utility functions and macros.
- [`view`](../modules/view/overview.md): Declarative view DSL, layout engine, styling, and view tree rendering.

*(Note: The `style` module mentioned previously has been integrated into the `view` and `platform` modules conceptually. Styling is handled by the `view` DSL and applied by the `platform` renderer.)*

## Technology Stack

- **Primary Language:** Common Lisp
- **Key Libraries/Concepts:** (To be detailed in [Technology Stack](../architecture/tech-stack.md))
  - CLOS (Common Lisp Object System) for components.
  - Potentially libraries for threading, FFI, etc.

## Documentation System Explanation

This documentation system is designed to be AI-optimized, providing structured information for AI coding assistants to understand and work with the Elmtui project effectively. Key features include metadata tags (`ai_keywords`, `ai_contexts`, `ai_relations`), importance markers (`AI-IMPORTANCE`), and contextual information blocks (`AI-CONTEXT-START`/`END`).

Refer to the [AI Documentation Guide](./documentation-guide.md) for detailed standards and usage.
Use the [AI Navigation Guide](./navigation-guide.md) to find specific information within the documentation.

## Related Resources

- **Architecture:**
  - [System Architecture Overview](../architecture/system-overview.md)
  - [Core Architectural Concepts](../architecture/core-concepts.md)
  - [Module Dependencies](../architecture/module-dependencies.md)
  - [Technology Stack](../architecture/tech-stack.md)
- **AI Documentation System:**
  - [AI Navigation Guide](./navigation-guide.md)
  - [AI Documentation Guide](./documentation-guide.md)
- **Module Overviews:**
  - [App Module](../modules/app/overview.md)
  - [Clevelib Module](../modules/clevelib/overview.md)
  - [Core Module](../modules/core/overview.md)
  - [Dev Module](../modules/dev/overview.md)
  - [Platform Module](../modules/platform/overview.md)
  - [State Module](../modules/state/overview.md)
  - [UI Module](../modules/ui/overview.md)
  - [Utils Module](../modules/utils/overview.md)
  - [View Module](../modules/view/overview.md)