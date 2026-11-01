#!/usr/bin/env python3
"""Fail-closed SB-COVER expression ratchet for the primary ElmTUI system.

Only the source paths emitted by the ASDF inventory are in scope.  The SB-COVER
HTML report must contain an expression count for *every* one of those paths.
"""
import argparse
import csv
import hashlib
import json
import math
from html.parser import HTMLParser
from pathlib import Path
import re
import sys


class ReportParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.directory = None
        self.rows = {}
        self.in_row = False
        self.in_cell = False
        self.cells = []
        self.cell = ""
        self.link = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.in_row = True
            self.cells = []
            self.link = None
        elif tag == "td" and self.in_row:
            self.in_cell = True
            self.cell = ""
        elif tag == "a" and self.in_cell:
            self.link = dict(attrs).get("href")

    def handle_data(self, data):
        if self.in_cell:
            self.cell += data

    def handle_endtag(self, tag):
        if tag == "td" and self.in_cell:
            self.cells.append(self.cell.strip())
            self.in_cell = False
        elif tag == "tr" and self.in_row:
            if len(self.cells) == 1 and self.cells[0].startswith("/"):
                self.directory = Path(self.cells[0])
            elif len(self.cells) == 7 and self.link and self.directory:
                if not all(re.fullmatch(r"[0-9]+", x) for x in self.cells[1:3]):
                    raise ValueError("Malformed expression counts: " + repr(self.cells))
                path = (self.directory / self.cells[0]).resolve()
                if path in self.rows:
                    raise ValueError(f"Duplicate source row: {path}")
                self.rows[path] = (int(self.cells[1]), int(self.cells[2]))
            self.in_row = False


def check(report, inventory, root, minimum, output, expected_total=None, baseline=None):
    # Invalidate previously generated success evidence before parsing anything.
    if output:
        for name in ('coverage-summary.csv', 'coverage-summary.txt', 'coverage-summary.json', 'coverage-badge.svg'):
            (output / name).unlink(missing_ok=True)
    if not report.is_file() or not inventory.is_file():
        raise ValueError("Missing coverage HTML index or ASDF inventory")
    parser = ReportParser()
    parser.feed(report.read_text(encoding="utf-8"))
    names = [x.strip() for x in inventory.read_text().splitlines() if x.strip()]
    if not names or len(set(names)) != len(names):
        raise ValueError("Missing or duplicate ASDF source inventory")
    if baseline is not None:
        if not baseline.is_file():
            raise ValueError(f'Missing reviewed source baseline: {baseline}')
        baseline_names = [x.strip() for x in baseline.read_text().splitlines() if x.strip()]
        if names != baseline_names:
            raise ValueError('Primary ASDF inventory drift from reviewed baseline; update baseline only after source review')
    included = {}
    for name in names:
        source = (root / name).resolve()
        if not source.is_relative_to(root.resolve()) or not source.is_file():
            raise ValueError(f"Invalid inventory path: {name}")
        if source not in parser.rows:
            raise ValueError(f"Source absent from instrumented report: {name}")
        covered, total = parser.rows[source]
        if total <= 0 or covered > total:
            raise ValueError(f"Invalid expression denominator for {name}: {covered}/{total}")
        included[name] = (covered, total)
    covered = sum(v[0] for v in included.values())
    total = sum(v[1] for v in included.values())
    if expected_total is not None and total != expected_total:
        raise ValueError(f"Expression denominator drift: {total} != {expected_total}")
    percent = covered * 100 / total
    if not math.isfinite(minimum) or not 0 <= minimum <= 100:
        raise ValueError('Invalid finite coverage minimum')
    if percent < minimum:
        raise ValueError(f'Coverage ratchet regression: {percent:.2f}% < {minimum:.2f}%')
    if output:
        output.mkdir(parents=True, exist_ok=True)
        with (output / "coverage-summary.csv").open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["source", "covered_expressions", "total_expressions"])
            for name, (a, b) in sorted(included.items()):
                writer.writerow([name, a, b])
        provenance = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sorted(included)}
        payload = {'schema': 'elmtui.primary-sb-cover.v1', 'covered_expressions': covered,
                   'total_expressions': total, 'percent': round(percent, 4),
                   'minimum_percent': minimum, 'source_count': len(included),
                   'inventory_sha256': hashlib.sha256(inventory.read_bytes()).hexdigest(),
                   'source_sha256': provenance}
        (output / 'coverage-summary.json').write_text(json.dumps(payload, sort_keys=True, indent=2) + '\n')
        # The badge is generated only after validation and contains no fixed percentage.
        label = f'{percent:.2f}%'
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="246" height="20" role="img" '
               'aria-label="SB-COVER primary expressions: ' + label + '">'
               '<rect width="176" height="20" fill="#555"/>'
               '<rect x="176" width="70" height="20" fill="#1676a5"/>'
               '<g fill="#fff" font-family="DejaVu Sans,Verdana,sans-serif" font-size="11" '
               'text-anchor="middle"><text x="88" y="14">SB-COVER expressions</text>'
               '<text x="211" y="14">' + label + '</text></g></svg>\n')
        (output / 'coverage-badge.svg').write_text(svg)
        (output / "coverage-summary.txt").write_text(
            f"SB-COVER expressions: {covered}/{total} ({percent:.2f}%)\n"
            f"Sources: {len(included)}\nMinimum: {minimum:.2f}%\n"
        )
    print(f"SB-COVER primary expressions: {covered}/{total} ({percent:.2f}%), {len(included)} files")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", type=Path, default=Path("coverage/cover-index.html"))
    ap.add_argument("--inventory", type=Path, default=Path("coverage/primary-sources.txt"))
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    ap.add_argument("--minimum", type=float, default=55.0)
    ap.add_argument("--expected-total", type=int, default=None)
    ap.add_argument('--baseline', type=Path, default=Path('docs/assets/coverage-primary-sources.txt'))
    ap.add_argument("--output", type=Path, default=Path("coverage"))
    args = ap.parse_args()
    if not math.isfinite(args.minimum) or not (0 <= args.minimum <= 100):
        ap.error("minimum must be in [0,100]")
    try:
        check(args.report, args.inventory, args.root, args.minimum, args.output,
              args.expected_total, args.baseline)
    except (ValueError, OSError) as exc:
        print(f"coverage gate: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
