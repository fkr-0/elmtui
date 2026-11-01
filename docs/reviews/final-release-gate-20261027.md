# ElmTUI E5 release-engineering gate — 2026-10-27

**Outcome: release HOLD; release-engineering lane implemented and partially qualified locally.** The current working tree is NOT the release candidate, and no tag, push, deployment, package publication, or submodule mutation has been performed.

## Authority and snapshot

- OCP identity: ELMTUI-CLPM-E5-RELEASE-ENGINEERING-20261027-132344.
- Repository: /home/user/code/lisp/elmtui.lisp.
- Existing local annotated v0.2.0 tag points to 511edb2bf066bdd80343cc82e49d2ec2d0773814; unchanged.
- Root HEAD at E5 verification: 533c97d6d7c9c0ac6045efc0aa19f6e4f1d88bb7; main, heavily dirty (117 status paths at observation). The source snapshot below reflects committed HEAD, **not** E1–E4's working-tree edits. This is a helper/integration exercise, NOT a full candidate qualification.
- Gitlinks at that HEAD: cl-events 1664d9a694fdcf4520df85ca869a994fcf0cc7d5; cl-inputs 6a9b1842db2f0a311b1ce44a2ba8b6e923fdd329; cl-state 8b293004dc03c89ade9eef02cb14aa94b1a81a66; cl-styles 5052188b7afe8ecc82687ef85922bc9d44565428.

## E5 changes and semantics

- scripts/release-matrix-test.py implements a static version/CI contract, immutable Git-object source archive that **contains** the exact four gitlink trees, checksum and frozen revision-vector sidecars; validates path-safety and required ASDF/license/CLPM files; probes exact SHA fetchability from the public remotes with read-only temporary bare repositories; and tests a truly fresh CLPM/SBCL install from the archive.
- scripts/release-check.sh retains original topology and required-file checks, adds per-gate logs, exit code, duration, frozen HEAD vector and terminal result receipts under an isolated /tmp directory by default. Each mandatory check fails closed. Its expanded matrix includes Workbench, Neon PTY, maintained tmux and urxvt terminal sweeps, coverage, strict docs, packaged PTY, archive/cold install and public pins.
- tests/test_release_engineering.py adds real temporary Git commit/gitlink archive fixtures and negative tests for stale working-tree leakage, archive overwrite, missing vendored content, unsafe tar entries, inconsistent versions and absent CI gates.
- The version conflict is intentional RELEASE BLOCK: ASDF 0.2.0 versus website/release.md advertised 0.1.0. Existing v0.2.0 tag cannot be moved.
- CI parity is not silently assumed. The mandatory contract rejects currently absent Neon PTY, terminal sweep, archive, cold install and public pin checks in .github/workflows/ci.yml. Site strict checks in pages.yml do not substitute for a PR's complete release matrix.

## Exact verification receipts

| Command | Exit | Observed result |
|---|---:|---|
| python3 -m unittest discover -s tests -p test_release_engineering.py -v | 0 | 7/7 tests PASS, including actual four-gitlink archive fixture |
| python3 -m py_compile scripts/release-matrix-test.py tests/test_release_engineering.py | 0 | Python syntax PASS |
| bash -n scripts/release-check.sh | 0 | Bash syntax PASS |
| python3 scripts/release-matrix-test.py archive /tmp/elmtui-e5-source-20261027.tar.gz | 0 | Archive created from committed HEAD; all dependency source trees included |
| python3 scripts/release-matrix-test.py cold /tmp/elmtui-e5-source-20261027.tar.gz | 0 | SBCL/CLPM load passed, COLD_ARCHIVE_LOAD_OK; isolated HOME plus XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME; 0 global source-cache references in log |
| python3 scripts/release-matrix-test.py pins /tmp/elmtui-e5-public-pins-20261027.json | 1 | cl-events, cl-inputs, cl-state REACHABLE; cl-styles and root UNRESOLVED |
| python3 scripts/release-matrix-test.py contract | 1 | Website version mismatch, CI missing mandatory release entries; before new gate wiring also reported missing local entries |
| scripts/release-check.sh | 1 | Fail closed on cl-events working checkout SHA differing from HEAD gitlink, before release suite; receipt path /tmp/elmtui-release-check.z3VLyCuu |

Concrete artifact paths on the repository machine: /tmp/elmtui-e5-source-20261027.tar.gz; its .sha256 and .vector.json; /tmp/elmtui-e5-cold-isolated-20261027.log; /tmp/elmtui-e5-public-pins-20261027.json. Archive SHA256: **3ecaa0782d887cee5cf143256f987f1f1441668b213461abad87bc01adb6ef0e**. Temporary /tmp artifacts are not durable publication artifacts.

### Public exact-SHA probe

| Repository | HEAD gitlink / candidate SHA | Remote result |
|---|---|---|
| cl-events | 1664d9a694fdcf4520df85ca869a994fcf0cc7d5 | reachable |
| cl-inputs | 6a9b1842db2f0a311b1ce44a2ba8b6e923fdd329 | reachable |
| cl-state | 8b293004dc03c89ade9eef02cb14aa94b1a81a66 | reachable |
| cl-styles | 5052188b7afe8ecc82687ef85922bc9d44565428 | **unresolved** |
| ElmTUI root | 533c97d6d7c9c0ac6045efc0aa19f6e4f1d88bb7 | **unresolved** |

A bare temporary Git fetch by exact object SHA was attempted against the configured public HTTPS remotes; no upload was attempted. A fetched object being reachable is distinct from a checked-out release artifact being functionally qualified.

### Worktree HEAD proposals (NOT a frozen release vector)

At this observation the dependency working HEAD commits were cl-events 57f1bc8504d61f9b1c49a41bed96eae2b736bd47, cl-inputs f12c564e1cb5e4e367608c878b312ae2658bb218, cl-state 8f116e7191a545719b9d4500f0d87880861e776e, cl-styles e4d64c5baf483d16440459574366b935f2d2448d. These are proposed *inspection targets*, not adopted gitlinks: several dependency trees remain dirty and their HEADs alone omit local changes. E1–E4 must finalize their files and commits, then an owner-approved release commit must pin and publish the chosen exact public dependency vector. Do not silently use these HEADs for a tag.

## E1–E4 integration status

- E1 docs/site: workflow approved, but the resulting exact source and CI integration require re-verification on a frozen candidate.
- E2 terminal PTY: baseline qualification awaiting review; an additional startup-error unwind repair packet remains ready, not proven integrated.
- E3 Workbench: revision_required; small-geometry/resize and remote Slynk behavior not closed.
- E4 coverage: revision_required; final coverage source vector and threshold must be remeasured after remediation.
- Thus E5 cannot truthfully report a green frozen release matrix even with the archive-install helper working.

## Release/acceptance gate and handoff

1. Resolve E2–E4 reviews and E1–E4 integration, freeze exact root + four dependency commits; do not overwrite active agents' changes.
2. Decide one consistent version and new immutable tag policy; existing v0.2.0 is off limits. Update site/release references only under owning scope.
3. Prepare publicly reachable dependency SHAs and final superproject commit; external uploads/push require explicit owner authorization.
4. Amend CI to invoke the canonical scripts/release-check.sh or every explicitly enumerated lane, including both terminal backends, strict docs, source archive and independent cold install, then pass on the frozen clean candidate with root/dependency trees clean.
5. Rerun archive, fresh CLPM install, SHA fetchability and all PTY/Neon/Workbench/coverage/doc checks on that exact candidate, retaining per-gate path/exit/hash receipts. Independently review before any publication gate.

The E5 helper implementation does not itself constitute release approval. No synthetic successes, tag operations, pushes or deployments were performed.


## Follow-up independent E5 review and corrective qualification (later evidence)

Independent reviewer verdict: REQUEST_CHANGES on the previous E5 archive verification. An adversary could rewrite an archived LICENSE while preserving the embedded vector, or forge the embedded root SHA, and the earlier validator accepted both. The previous integrity claim was therefore invalid.

Revised verification now compares embedded and sidecar revision vectors with local pinned Git HEAD/gitlinks, verifies a required SHA256 sidecar, and independently enumerates all file bytes, file executable bits, directory and file inventory against git archive output for all five pinned objects. Sidecars alone cannot act as an independent trust anchor. This is local Git-object content verification, not signed provenance or public reachability.

| Re-executed scope | Exit | Evidence |
| --- | ---: | --- |
| Release engineering unit tests | **0** | **12/12 PASS**, including four adversarial regressions: tampered LICENSE with recomputed checksum, forged vector with rewritten sidecars, forged executable bit, missing checksum sidecar |
| Rebuild frozen root/archive | **0** | Root ffef736c89f428614d568504ced6dae2a1e7d507; archive /tmp/elmtui-e5-verified-source-current-20261027.tar.gz; SHA256 66edf028eeb77a8836efb3837fe42108323f62c1654422053c05a87473530c9b |
| Independently verify rebuilt archive | **0** | Exact committed source bytes/modes and all four dependency Git trees verified |
| Verify older historical root archive | **1** | Correctly rejected because its root SHA differs from current trusted HEAD |
| Current version and CI contract | **1** | Remaining mismatch: website release 0.1.0 versus ASDF 0.2.0 |

Working-tree CI now calls the canonical scripts/release-check.sh and retains gate receipts; historical earlier claims of missing CI matrix coverage refer to the previous snapshot, not the current script. This is not equivalent to a committed clean release candidate.

E2 source child ed53baa3-b5cb-4982-9917-ddd15c79fa2b subsequently independently approved after 13/13 tmux and 12/12 urxvt. E3 dynamic resize remains RED (blocked after review limit); E4 coverage revision pending. Disk free was approximately 1.9 GiB; no large cold-install rerun. Release status remains HOLD. E5 requires new independent review; no commits, tags, push, publication or deployment.
