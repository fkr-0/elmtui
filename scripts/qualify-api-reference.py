#!/usr/bin/env python3
"""Independently cross-check ElmTUI API docs against an actual SBCL image."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PREFIXES = ("ELMTUI", "CL-EVENTS", "CL-STATE", "CL-INPUTS", "CL-STYLES")


@dataclass(frozen=True)
class Entry:
    qualified: str
    kinds: str
    documented: bool


class APIHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.headings: list[str] = []
        self.pretexts: list[str] = []
        self.sections = 0
        self._capture = ""

    def handle_starttag(self, tag, attrs):
        if tag == "section":
            self.sections += 1
        if tag in {"h2", "pre"}:
            self._capture = tag
            if tag == "h2":
                self.headings.append("")
            else:
                self.pretexts.append("")

    def handle_endtag(self, tag):
        if self._capture == tag:
            self._capture = ""

    def handle_data(self, data):
        if self._capture == "h2":
            self.headings[-1] += data
        if self._capture == "pre":
            self.pretexts[-1] += data


def live_entries() -> list[Entry]:
    with tempfile.TemporaryDirectory(prefix="elmtui-api-qualify-") as folder:
        listing = Path(folder) / "bindings.tsv"
        program = Path(folder) / "symbols.lisp"
        # All names are emitted by the running Lisp process. We refuse control
        # characters in a public display name instead of silently truncating it.
        code = r'''
(require :asdf)
(asdf:load-system :elmtui-docs)
(with-open-file (out "OUTPUT_PATH" :direction :output :if-exists :supersede)
  (dolist (entry (elmtui.docs:public-api-bindings))
    (let* ((symbol (getf entry :symbol))
           (package-name (getf entry :package))
           (package (find-package package-name))
           (name (symbol-name symbol))
           (qualified (format nil "~A:~A" package-name name))
           (status (nth-value 1 (find-symbol name package)))
           (kinds (format nil "~{~(~A~)~^, ~}" (getf entry :kinds))))
      (unless (eq status :external)
        (error "Documented name is not public: ~A" qualified))
      (dolist (ch '(#\Newline #\Return #\Tab))
        (when (find ch qualified)
          (error "Unrepresentable qualified name: ~S" qualified)))
      (format out "~A~C~A~C~A~%" qualified #\Tab kinds #\Tab
              (if (getf entry :documentation) "1" "0")))))
'''.replace("OUTPUT_PATH", str(listing).replace("\\", "\\\\").replace('"', '\\"'))
        program.write_text(code)
        proc = subprocess.run(
            ["clpm", "bundle", "exec", "--with-client", "sbcl", "--",
             "--noinform", "--script", str(program)],
            cwd=ROOT, capture_output=True, text=True, timeout=120,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                "Runtime introspection failed:\n"
                + (proc.stdout + "\n" + proc.stderr)[-6500:]
            )
        result: list[Entry] = []
        for line in listing.read_text().splitlines():
            columns = line.split("\t")
            if len(columns) != 3 or columns[2] not in {"0", "1"}:
                raise AssertionError(f"Invalid live symbol row: {line[:180]!r}")
            result.append(Entry(columns[0], columns[1], columns[2] == "1"))
        return result


def markdown_entries(markdown: str) -> tuple[list[Entry], list[str]]:
    expected_header = "# ElmTUI API Reference"
    if not markdown.startswith(expected_header + "\n"):
        raise AssertionError("Missing top-level reference title")
    result: list[Entry] = []
    docs: list[str] = []
    names: list[str] = []
    lines = markdown.splitlines()
    current_name = None
    current_kinds = None
    current_doc = []
    fence = None
    for line in lines:
        if fence is not None:
            if line == fence:
                fence = None
            else:
                current_doc.append(line)
            continue
        if line.startswith(chr(96) * 3) and line.endswith("text"):
            fence = line[:-4]   # a variable-length backtick fence
            if len(fence) < 3 or set(fence) != {chr(96)}:
                raise AssertionError(f"Invalid documentation fence: {line!r}")
            continue
        if line.startswith("## "):
            if current_name is not None:
                if current_kinds is None:
                    raise AssertionError(f"Missing kinds for {current_name}")
                text = "\n".join(current_doc).strip()
                docs.append(text)
                result.append(Entry(current_name, current_kinds,
                                    text != "_No documentation metadata._"))
            current_name = line[3:]
            if not current_name:
                raise AssertionError("Empty API entry heading")
            names.append(current_name)
            current_kinds = None
            current_doc = []
        elif current_name is not None:
            if line.startswith("Kinds: "):
                if current_kinds is not None:
                    raise AssertionError(f"Duplicate kinds for {current_name}")
                current_kinds = line[len("Kinds: "):]
            elif line.strip():
                current_doc.append(line)
    if fence:
        raise AssertionError(f"Unclosed documentation fence: {fence!r}")
    if current_name is not None:
        if current_kinds is None:
            raise AssertionError(f"Missing kinds for {current_name}")
        text = "\n".join(current_doc).strip()
        docs.append(text)
        result.append(Entry(current_name, current_kinds,
                            text != "_No documentation metadata._"))
    if len(names) != len(set(names)):
        raise AssertionError("Duplicate API headings")
    return result, docs


def qualify(*, markdown: Path, html: Path, strict_coverage: bool) -> None:
    live = live_entries()
    actual, docs = markdown_entries(markdown.read_text())
    if actual != live:
        mismatch = next(
            ((index, a, b) for index, (a, b) in enumerate(zip(actual, live))
             if a != b), None
        )
        raise AssertionError(
            f"API reference is stale or incorrectly qualified; "
            f"reference={len(actual)} live={len(live)} first mismatch={mismatch!r}"
        )
    parser = APIHTML()
    parser.feed(html.read_text())
    target_names = [entry.qualified for entry in live]
    if parser.sections != len(live) or parser.headings != target_names:
        raise AssertionError(
            f"HTML mismatch sections={parser.sections}, "
            f"headings={len(parser.headings)}, expected={len(live)}"
        )
    if len(parser.pretexts) != len(live):
        raise AssertionError("HTML must have one escaped documentation block per binding")
    for entry, markdown_doc, html_doc in zip(live, docs, parser.pretexts):
        if entry.documented:
            if markdown_doc != html_doc.strip():
                raise AssertionError(f"Markdown/HTML documentation mismatch: {entry.qualified}")
        elif html_doc != "No documentation metadata.":
            raise AssertionError(f"HTML missing-documentation marker incorrect: {entry.qualified}")
    for item in live:
        namespace = item.qualified.split(":", 1)[0]
        if not namespace.startswith(PREFIXES):
            raise AssertionError(f"Unexpected package in public API: {namespace}")
    md = markdown.read_text()
    missing = sum(not item.documented for item in live)
    documented = len(live) - missing
    coverage = round(100 * documented / len(live), 1) if live else 100.0
    if (f"**Coverage:** {documented} of {len(live)} bindings documented; "
            f"{missing} have no metadata" not in md):
        raise AssertionError("Published coverage is inconsistent with live symbols")
    if not (ROOT / "website/reference.md").is_file():
        raise AssertionError("Public API landing page missing")
    print(f"REFERENCE-STRUCTURE-PASS entries={len(live)} documented={documented}"
          f" missing={missing} coverage={coverage:.1f}% html_sections={parser.sections}")
    if strict_coverage and missing:
        raise AssertionError(
            f"REFERENCE-DOCSTRING-DEBT {missing} public bindings lack documentation. "
            "No missing-public-API-docstrings gate is waived."
        )


def main() -> int:
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--structure-only", action="store_true",
                      help="Check live identity and cross-format fidelity, report debt but do not fail on it")
    args.add_argument("--markdown", type=Path, default=ROOT / "docs/api/generated/api.md")
    args.add_argument("--html", type=Path, default=ROOT / "docs/api/generated/api.html")
    values = args.parse_args()
    try:
        qualify(markdown=values.markdown, html=values.html,
                strict_coverage=not values.structure_only)
    except (AssertionError, OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"REFERENCE-QUALIFICATION-FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
