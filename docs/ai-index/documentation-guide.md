---
# AI Metadata Tags
ai_keywords: [Documentation Standards, AI Optimization, Metadata Tags, Content Markers, Document Lifecycle, Quality Assurance, AI Index, Documentation Guide]
ai_contexts: [meta, development, process]
ai_relations: [
  "./overview.md",
  "./navigation-guide.md",
  "../architecture/system-overview.md",
  "../dev-guides/coding-standards.md",
  "../dev-guides/contribution-guide.md"
]
---
# Elmtui Documentation Standards Guide

This guide outlines the standards and processes for creating, maintaining, and using the AI-optimized documentation for the Elmtui project. Adherence to these standards is crucial for effective collaboration with AI assistants and for maintaining a high-quality, understandable knowledge base.

## 1. Document Lifecycle Process

(Detailed lifecycle: Create -> Update -> Split -> Deprecate -> Archive will be described here. This section will cover when and how to perform these actions, including versioning considerations if applicable, and the role of the `docs_old/archive/` directory.)

## 2. Standards for Document Creation and Updates

### 2.1. Creating New Documents
- Follow the defined directory structure (e.g., `docs/modules/`, `docs/architecture/`, `docs/dev-guides/`).
- Use Markdown format (`.md` extension).
- Include AI metadata tags (see section 3.1) at the beginning of all key documentation files, especially module overviews, implementation details, architectural documents, and AI index files.
- Apply AI content markers (see section 4) where appropriate to highlight critical information or specific contexts.
- Ensure new documents are linked from relevant existing documents (e.g., from `ai-relations` in other files, or from navigation guides).

### 2.2. Updating Existing Documents
- Ensure content accurately reflects the latest code implementation and project understanding.
- Update `ai_keywords`, `ai_contexts`, and especially `ai_relations` if document content or relationships change.
- If significant changes are made, consider noting them in the [Changelog](../maintenance/changelog.md) or a document-specific history if one exists.
- Verify that all links within the document and to the document remain valid.

### 2.3. Splitting Documents
- If a document becomes too large (e.g., significantly exceeding 150-200 lines without good reason) or covers too many distinct topics, consider splitting it into more focused documents.
- Ensure `ai_relations` are updated in all affected documents (the original, now potentially a parent/summary, and the new child documents).
- Update navigation guides if necessary.

## 3. Document Metadata and Structural Specifications

### 3.1. AI Metadata Tags (Frontmatter)
All key `.md` files in the `docs/` directory should start with a YAML frontmatter block containing AI metadata tags.
```yaml
---
# AI Metadata Tags
ai_keywords: [keyword1, keyword2, relevant_function_names, relevant_macro_names]
ai_contexts: [architecture|development|implementation|usage|meta|process|guide] # Choose one or more applicable
ai_relations: ["path/to/related/doc1.md", "path/to/related/doc2.md", ...]
---
```
- **`ai_keywords`**: A list of 5-15 specific keywords relevant to the document's content. Include names of key functions, macros, or concepts discussed. This aids precise AI search.
- **`ai_contexts`**: Classifies the document's primary purpose(s). Multiple contexts can be listed. Examples:
    - `architecture`: High-level design, system structure.
    - `development`: Guides for developers, coding practices.
    - `implementation`: Detailed explanation of how a module/feature is built.
    - `usage`: How to use a feature or module.
    - `meta`: Documents about the documentation system itself (like this one).
    - `process`: Documents describing development or contribution processes.
    - `guide`: Tutorial-style or step-by-step instructions.
- **`ai_relations`**: A list of relative paths to other documents that are directly related or provide essential context. This helps AI understand the interconnectedness of information.

### 3.2. Document Structure
- Use clear, descriptive headings (`#`, `##`, `###`) to organize content logically.
- Employ lists (bulleted or numbered), code blocks (with language identifiers), and tables for readability and structure.
- Ensure consistent formatting throughout the documentation.
- Write concisely and clearly.

## 4. AI Marker Usage Guide

These HTML-style comments help AI assistants prioritize and contextualize information within a document.

### 4.1. Importance Markers
Place these directly above a section or paragraph.
```markdown
<!-- AI-IMPORTANCE:level=critical -->
<!-- AI-IMPORTANCE:level=high -->
<!-- AI-IMPORTANCE:level=normal --> <!-- (Default, usually not needed explicitly) -->
```
- `critical`: Information vital for understanding the core functionality or for avoiding major issues.
- `high`: Important details that significantly aid understanding or development.

### 4.2. Contextual Information Blocks
Wrap specific sections with these markers to denote their primary context, especially if a document serves multiple contexts declared in its frontmatter.
```markdown
<!-- AI-CONTEXT-START:type=architecture -->
... content primarily related to architecture ...
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
... content primarily for developers (how-to, best practices) ...
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
... content detailing internal workings ...
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
... content explaining how to use a feature/API ...
<!-- AI-CONTEXT-END -->
```

## 5. Document Review Checklist and Quality Assurance

(A detailed checklist for reviewing documents will be provided here, covering:
- **Accuracy:** Content matches current codebase and project decisions.
- **Completeness:** All relevant aspects are covered for the document's scope.
- **Clarity:** Easy to understand, unambiguous language.
- **Metadata:** Frontmatter tags are present, correct, and comprehensive.
- **Markers:** Importance and context markers are used appropriately.
- **Links:** All internal and external links are valid and relevant.
- **Formatting:** Consistent and readable Markdown.)

## 6. Summary Mode and Document Maintenance
The **Summary Mode** AI assistant is primarily responsible for maintaining this documentation system after code changes, following these standards. Key tasks include:
- **Change Detection:** Identifying code changes that necessitate documentation updates.
- **Impact Analysis:** Determining which documents are affected.
- **Document Updates:** Modifying existing documents or flagging the need for new ones.
- **Relationship Maintenance:** Updating `ai_relations` and other links.
- **Quality Assurance:** Ensuring updates adhere to these standards.
- **Key File Updates:** Updating the [Changelog](../maintenance/changelog.md), `ai_documentation_plan.md` (if major changes), and the AI Index documents ([`overview.md`](./overview.md), [`navigation-guide.md`](./navigation-guide.md)).

## Related Resources

- [AI Index Overview](./overview.md)
- [AI Navigation Guide](./navigation-guide.md)
- [System Architecture Overview](../architecture/system-overview.md)
- [Elmtui Coding Standards](../dev-guides/coding-standards.md)
- [Contribution Guide](../dev-guides/contribution-guide.md)