# ElmTUI View DSL Reference

This document describes the standardized View DSL (Domain-Specific Language) used in ElmTUI for creating user interfaces.

## DSL Syntax Overview

The ElmTUI DSL uses a Hiccup-like syntax, where UI elements are described using nested lists with keywords:

```lisp
(define-view my-view (app-state dispatch)
  (:div :id "container" :class "main-container"
    (:h1 :class "title" "Hello World")
    (:button :id "submit-btn" :on-click :submit-form "Submit")
    (when (show-more? app-state)
      (:p "Additional content"))))
```

## Core Concepts

### Elements

Elements are defined by a keyword that maps to either:

1. **UI Primitives**: Basic building blocks like `:div`, `:span`, `:p`, etc.
2. **Widget Components**: Higher-level components like `:button`, `:text-input`, `:list-box`

Elements can have:
- Properties (key-value pairs)
- Child elements (nested lists or strings)

### Properties

Properties are specified as alternating keywords and values:

```lisp
(:div :id "main" :class "container" :width 80 ...)
```

Property keys should be keywords (`:property-name`).

#### Standard Properties

All elements support these standard properties:

| Property | Description | Example |
|----------|-------------|---------|
| `:id` | Unique identifier | `:id "main-container"` |
| `:class` | Space-separated class names | `:class "main large"` |
| `:style` | Inline styles | `:style '(:color :red :width 10)` |
| `:width` | Width in columns | `:width 40` |
| `:height` | Height in rows | `:height 10` |
| `:focusable` | Whether element can be focused | `:focusable t` |
| `:display` | Layout mode | `:display :flex` |

#### Event Handlers

Event handlers are specified with the `:on-` prefix:

```lisp
(:button :on-click :submit-form "Submit")
```

Common event handlers:
- `:on-click` - Triggered when element is clicked
- `:on-change` - Triggered when element value changes
- `:on-focus` - Triggered when element receives focus
- `:on-blur` - Triggered when element loses focus
- `:on-keypress` - Triggered when a key is pressed while element has focus

### Child Elements

Child elements can be:

1. **Nested Elements**: Other DSL forms
2. **Strings**: For text content
3. **Lisp Forms**: Evaluated to produce elements or strings
   - `if`, `when`, `unless`, `cond` - Conditional rendering
   - `loop ... collect` - Iteration to generate multiple elements
   - `list` - Create a list of elements

## Widget Integration

Widgets are integrated into the DSL through the `*dsl-element-map*` table:

```lisp
(:button app-state :widget-id "submit-button" :label "Submit")
```

When a DSL element maps to a widget view function, the following happens:
1. The `:widget-id` becomes the unique identifier for the widget
2. The `app-state` is passed as the first argument to the widget view function
3. Other properties are passed as keyword arguments to the view function

## Layout System

The DSL supports three primary layout modes:

### 1. Block Layout (`:display :block`)

Default layout mode. Elements are stacked vertically:

```lisp
(:div :display :block
  (:p "First paragraph")
  (:p "Second paragraph"))
```

### 2. Flex Layout (`:display :flex`)

Flexible box layout allows alignment along a single axis:

```lisp
(:div :display :flex :flex-direction :row :justify-content :space-between
  (:span :flex-grow 1 "Left")
  (:span :flex-grow 2 "Center")
  (:span :flex-grow 1 "Right"))
```

Flex properties:
- `:flex-direction` - `:row` or `:column`
- `:flex-wrap` - `:wrap` or `:nowrap`
- `:justify-content` - `:flex-start`, `:flex-end`, `:center`, `:space-between`, `:space-around`
- `:align-items` - `:flex-start`, `:flex-end`, `:center`, `:stretch`
- `:align-self` - (On child items) `:flex-start`, `:flex-end`, `:center`, `:stretch`
- `:flex-grow`, `:flex-shrink`, `:flex-basis` - (On child items) Control sizing

### 3. Grid Layout (`:display :grid`)

Grid layout for two-dimensional positioning:

```lisp
(:div :display :grid
     :grid-template-columns '(:fr 1 :fr 2 :fr 1)
     :grid-template-rows '(:auto :auto :auto)
     :grid-template-areas '(("header" "header" "header")
                           ("main" "content" "sidebar")
                           ("footer" "footer" "footer"))
  (:div :grid-area "header" "Header")
  (:div :grid-area "main" "Main")
  (:div :grid-area "content" "Content")
  (:div :grid-area "sidebar" "Sidebar")
  (:div :grid-area "footer" "Footer"))
```

Grid properties:
- `:grid-template-columns`, `:grid-template-rows` - Define grid tracks
- `:grid-template-areas` - Define named areas
- `:grid-area` - (On child items) Place item in named area
- `:grid-column`, `:grid-row` - (On child items) Control item placement

## The Box Model

All elements follow the CSS box model:

```
┌───────────────────────────────────────────────────┐
│                     Margin                        │
│   ┌───────────────────────────────────────────┐   │
│   │               Border                      │   │
│   │   ┌───────────────────────────────────┐   │   │
│   │   │           Padding                 │   │   │
│   │   │   ┌───────────────────────────┐   │   │   │
│   │   │   │                           │   │   │   │
│   │   │   │         Content           │   │   │   │
│   │   │   │                           │   │   │   │
│   │   │   └───────────────────────────┘   │   │   │
│   │   │                                   │   │   │
│   │   └───────────────────────────────────┘   │   │
│   │                                           │   │
│   └───────────────────────────────────────────┘   │
│                                                   │
└───────────────────────────────────────────────────┘
```

Box model properties:
- `:margin`, `:margin-top`, `:margin-right`, `:margin-bottom`, `:margin-left`
- `:border-style`, `:border-color`, `:border-width`
- `:padding`, `:padding-top`, `:padding-right`, `:padding-bottom`, `:padding-left`
- `:width`, `:height` - Size of content area

## Best Practices

1. **Unique IDs**: Always provide unique IDs for elements that need to be referenced
2. **Use Classes**: Prefer classes over inline styles for consistent styling
3. **Component Composition**: Break complex UIs into smaller view functions
4. **Conditional Rendering**: Use standard Lisp conditionals (if, when, unless)
5. **List Rendering**: Use loop to generate lists of elements
6. **Focus Management**: Mark interactive elements with `:focusable t`
7. **Accessibility**: Include ARIA attributes for better accessibility
