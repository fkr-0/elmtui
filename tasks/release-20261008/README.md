# ElmTUI repair and standalone release preparation

Dispatched 2026-10-08. Delivery is verified; implementation, archive qualification and independent review remain pending. Existing dirty work and release tags are preserved.

| Project | OCP task | State | Conversation |
| --- | --- | --- | --- |
| cl-events | `CL-EVENTS-RELEASE-20261008` | running | [Open](https://chatgpt.com/c/6ac7f5b8-b9e8-83ed-8ddf-b7045ade3d34) |
| cl-inputs | `CL-INPUTS-RELEASE-20261008` | running | [Open](https://chatgpt.com/c/6ac7f5c2-1ba4-83eb-97a6-732df362d294) |
| cl-state | `CL-STATE-RELEASE-20261008` | running | [Open](https://chatgpt.com/c/6ac7f5cf-6bbc-83eb-8885-5ef6292e8f28) |
| cl-styles | `CL-STYLES-RELEASE-20261008` | running | [Open](https://chatgpt.com/c/6ac7f63c-1a2c-83ed-a30d-787301a6516f) |
| elmtui.lisp | `ELMTUI-RELEASE-20261008` | running | [Open](https://chatgpt.com/c/6ac7f60a-b938-83eb-8ba2-a71e6cfe48cb) |

Each library owns only its standalone repository. ElmTUI owns consumer integration and release gates, and must integrate reviewed immutable library results. Prompts require structural Lisp editing, ASDF/CLPM testing, warning-clean compilation, fresh archive validation and typed phase results.

Inspect progress with `chatgpt-ops task show TASK_ID` and `chatgpt-ops task events TASK_ID`; do not resend an already delivered task. No push, publication or tag replacement is authorized by this release-preparation dispatch.
