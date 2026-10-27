# Strict documentation-site release closure — 2026-10-27

**OCP task:** `ELMTUI-CLPM-E1-DOCS-SITE-20261027-DA2564`
**Project:** `elmtui-clpm`; root `/home/user/code/lisp/elmtui.lisp`
**Lane:** `e1-docs-site`; **priority:** 96
**Pre-edit HEAD:** `a6be0e79e7a954eb77b4b299038984ad7170cb41`
**Status:** Local documentation gate **PASS**, independent workflow review **pending**. **Do not infer overall release readiness.**

## Failure, attribution and changes

The 2026-10-26 independent release review documented five strict MkDocs link warnings: copied `examples/README.md` retained `../docs/` links and the copied Workbench technical guide linked to an unstaged review. At pickup, `scripts/prepare-site.py` already contained uncommitted preliminary link rewriting and `tests/test_prepare_site.py` was already untracked with four green tests. Neither was discarded. Local staging plus a cached MkDocs environment reproduced **a passing strict build**, so the P1 defect had already been partially repaired in the dirty working tree; no false claim of reproducing the old failure is made.

The current implementation:

- Resolves Markdown links **from their original source document**, then targets copies under `website/guide/`. Cross-section links stay inside the generated site; unstaged existing repository documents link to `https://github.com/fkr-0/elmtui/blob/main/...`.
- Copies locally referenced Markdown image assets under `website/guide/media/<repository path>` and preserves URL-encoded filenames, query strings and fragments. Images are **not** sent to GitHub's HTML blob viewer. Remote URLs, fragment-only links, root-relative URLs and missing targets are preserved.
- Fails closed when the required Workbench technical guide is missing. The older `website/workbench.md` fallback was removed: publishing a surrogate could mask missing required source content.
- Keeps the staging map, generated API copy and MkDocs navigation source unchanged. The generator produces identical staged Markdown on repeated invocation.

The tests now include a disposable fixture repository with actual source Markdown, cross-page links, a real SVG asset with a space in its filename, source-only reference links, absence cases and a second idempotent stage. An opt-in integration test traverses generated HTML `href`/`src` paths and verifies local files. The separate MkDocs fixture verification exercised the asset at its compiled HTML URL, **and** injected a broken link to prove strict mode fails.

## Commands and results

Run from repository root, with no push/deployment:

| Command | Exit code | Evidence |
| --- | ---: | --- |
| `python3 -m unittest discover -s tests -p 'test_prepare_site.py' -v` | 0 | **8 tests**; 7 passed, 1 intentionally skipped until built-site opt-in |
| `python3 scripts/prepare-site.py` | 0 | Five curated document sources and checked-in generated API reference staged |
| `NO_MKDOCS_2_WARNING=1 uvx --offline --from mkdocs --with mkdocs-material mkdocs build --strict` | 0 | Builds **15 HTML / 63 total site files**; no MkDocs WARNING/ERROR emitted |
| `ELMTUI_SITE_BUILT=1 python3 -m unittest discover -s tests -p 'test_prepare_site.py' -v` | 0 | **8/8 pass**, including built HTML local link and asset audit |
| `git diff --check -- scripts/prepare-site.py tests/test_prepare_site.py` | 0 | No whitespace/diff errors |
| Isolated temporary repo with valid Workbench anchor and SVG; `uvx --offline --from mkdocs --with mkdocs-material mkdocs build --strict` | 0 | HTML `img` points to `../media/docs/assets/photo%20one.svg`; decoded file exists in built output |
| Same temporary repo, with deliberately missing `../docs/not-there.md` | 1 | MkDocs emits a broken-target WARNING: strict-mode guard is effective |

The system `mkdocs` executable was **not installed** (`mkdocs build --strict`: exit **127**). A separate `uv run --with 'mkdocs-material>=9.5,<10' ...` attempt failed offline due to uncached `certifi==2026.6.17` (exit **1**). The final build deliberately uses a previously cached, offline `uvx` tool environment with MkDocs **1.6.1** and Material **9.8.0**. This proves the local renderer, not fresh-network dependency resolution.

The MkDocs output contains an **INFO-only** notice that `website/assets/README.md` is not in `nav`; it is not a strict warning and the build returned 0.

## Output references

- `dist/site/guide/examples-catalog/index.html` SHA-256: `27f3fcb24719bc247ca0911a73aa8bf517aabceeefe2c79faeef1a0a0240d107`
- `dist/site/guide/workbench-user-guide/index.html` SHA-256: `347e21e0d72a0425d1b28cf7f1cdfe44163ef75c74eace94a586af6715ac6c0d`
- `dist/site/assets/theme.css` SHA-256: `c5a8eabbf4e3a5c18ace48db5726bc6adcf32c19edd02fbf2510883cac3e9b74`

The staged `website/guide/` pages and `dist/site/` site are **generated and ignored**, not source-controlled output files. The canonical source inputs remain the checked-in source Markdown and site preparation script.

## Scope, review handoff and remaining risk

Changed source paths: `scripts/prepare-site.py`, `tests/test_prepare_site.py`, and this report. No changes were made to Lisp, PTY suites, packaging, dependency gitlinks, `mkdocs.yml`, release versions or Git tags. The pre-existing dirty working tree was preserved; `v0.2.0` was not moved. There was **no push, release publication or Pages deployment**.

**Independent reviewer checklist:** evaluate link parser limits (inline Markdown vs. reference-style links, HTML `<img>`, paths with parentheses or titles), asset copy safety, the fail-closed missing-guide path, and whether the generated HTML audit should validate fragment IDs as well as files. Re-run staging, strict MkDocs and opt-in HTML audit at the **final pinned and publicly resolvable source revision**.

**Limits:** No browser/real Pages URL was queried; no claim is made about external GitHub blob URLs resolving on public `main` for uncommitted candidate documents. External hosting, rendered appearance, repository provenance, exact dependency lock of the site-tool environment and the complete release acceptance matrix remain outside this lane. An independent OpenCode reviewer invocation was attempted but the configured provider was unavailable; native workflow independent review is still required. No optimistic reviewer PASS is fabricated.

**Suggested continuation only if needed after independent review:** qualify the committed/pinned documentation site on the public Pages deployment, including actual cross-section links, images and external GitHub source references. Gate on independently reproducible public revision/pinned dependency manifests, built-site audit, and real deployed URL checks. Do not spawn duplicate work without operator promotion.
