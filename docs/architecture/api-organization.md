# API Organization in ElmTUI

This document explains the organization of API modules in ElmTUI and how dependencies are managed between them.

## API Design Principles

1. **Public Interface and Implementation Together**:
   - Each API file contains both interface declarations and implementation code
   - Clear section headers separate the interface from implementation
   - This approach avoids circular dependencies while providing clean API boundaries

2. **Type Declarations**:
   - All public functions and generics have explicit type declarations via `declaim ftype`
   - Required parameter types are declared in generic function definitions
   - This provides better static analysis and runtime type safety

3. **Error Handling**:
   - Public APIs include robust error handling with meaningful error messages
   - Type checks validate inputs (using `check-type` or specialized predicates)
   - This ensures API stability and easier debugging

## API Module Dependencies

The API modules are loaded in the following order in the ASDF system:

1. **elmtui.app.api**: Application definition and lifecycle
   - Imports from: `elmtui.core.globals`, `elmtui.core.event-channels`
   - Provides: `defapplication`, component instantiation, DSL registry
   
2. **elmtui.state.api**: State management and transactions
   - Imports from: `elmtui.core.globals`
   - Provides: Application state, models, messages, update framework
   
3. **elmtui.ui.api**: UI component system
   - Imports from: `elmtui.state.api`, `elmtui.utils`  
   - Provides: Component lifecycle (init, update, view), state integration
   
4. **elmtui.view.api**: View processing pipeline
   - Imports from: (only standard CL symbols - pure declarations)
   - Provides: View transformation, styling, layout, rendering
   
5. **elmtui.platform.api**: Platform abstraction
   - Imports from: `elmtui.utils`, `bordeaux-threads`
   - Provides: Terminal/backend abstractions, input/output, threading

## Platform Options Validation

Platform options used by applications are validated during initialization. Valid options include:

- `:initial-terminal-dimensions`: Terminal size (width, height)
- `:initial-cursor-position`: Starting cursor position (x, y)
- `:input-mode`: Input processing mode
- `:enable-mouse-support`: Whether to enable mouse events
- `:disable-mouse-support`: Whether to disable mouse events
- `:timeout`: Operation timeout value
- `:motion-events-p`: Whether to report motion events

The validation happens in `elmtui.app.api:validate-platform-options`, which is called from the application initialization process.

## Notes for Developers

When modifying the API files:

1. Keep interface declarations at the top of the file
2. Use proper section headers to separate interface from implementation
3. Ensure all public functions have proper type declarations and documentation
4. Add new platform options to the validation function if needed
5. Update this document if you change the dependency structure

API files are the most critical part of the system and should have the highest quality standards for documentation, type safety, and error handling.
