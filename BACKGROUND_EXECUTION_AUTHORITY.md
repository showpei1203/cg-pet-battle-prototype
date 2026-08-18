# CG Pet Battle Prototype — Background Execution Authority

Version: 2026-08-19

This repository inherits the shared Google Drive authority `SHARED_BACKGROUND_EXECUTION_AUTHORITY` (Drive file ID `1OMLXIcw9MU0Vi3RW4THN0nHQ7ZiDt16LjpODMjq5V7M`).

## Permanent rule
- Runtime, AutoRegression, battle simulations, AI/gamebit tests, catalog validators, asset-production tooling and other long-running jobs must be background-capable: losing foreground focus must not unnecessarily stop progression.
- Automated runs should proceed autonomously after launch and emit machine-readable status / LOG evidence.
- Foreground-only work is allowed only for explicitly visual/manual acceptance; non-visual setup/assertions/cleanup/logging should remain automated where practical.
- Background execution does **not** authorize unsafe thread-based mutation of RMVX game-state/UI.
- Prefer normal-loop state machines, staged jobs, detached/offline validators and external tooling.
- Scripts already SEALED are not reopened merely by this policy; new/touched infrastructure must comply without regression.

## Acceptance
A new infrastructure/harness path is not acceptance-complete if it unnecessarily stops just because another application becomes active.
