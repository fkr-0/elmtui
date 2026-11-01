@projmgrauth
Set repo: elmtui-clpm
Exact repository: /home/user/code/lisp/elmtui.lisp
CANONICAL WORK: ELMTUI-ARCH-API-CONTRACT-R1-20261023. Priority 93.
Autonomous API implementer, exact OCP task, governed ws-bridge packet/leases/claims, respect dirty checkout and other active agents. DO NOT create next.md.
MISSION: Establish public API tiers (application/extension/backend/internal) without breaking existing application behavior. Audit elmtui root facade reexports, DEFAPPLICATION/DEFTEA-APP and make-runtime-app-spec hierarchy, exported runtime knobs (notably start-loop ignored fps/wait), and view memo invalidation (function-local cache vs global cache). Fix concrete broken contracts with precise regression tests; preserve legitimate strict-elm/transactional semantics. Favor documentation/deprecation for unproven breaking removals, keep qualified advanced APIs and backward compatibility where tests demand it. Never change renderer, terminal capture/parser, tmux behavior, CL submodules, style keyword handling, src/ui/defcomponent.lisp or src/ui/dsl-resolution.lisp. Claim small exact files, do not collide with core-slim or release QA.
Deliver: stable API matrix, focused FiveAM for corrected semantics, warning-clean smoke, documented compatibility status and independent review/checkpoint. No push/release.
