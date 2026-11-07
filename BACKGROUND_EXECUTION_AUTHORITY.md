# CG Pet Battle Prototype — Background Execution Authority

> **P0 GLOBAL HARD RULES 001 (2026-11-07)**：先讀 [跨專案最高規則](https://docs.google.com/document/d/1NftePmIsggrhnfPcZTZS2G6YBka2yBy_fdw-NBT5D8Y/edit)。新素材、CG 專案完整母體、Patch ZIP、Scripts.rvdata 對照、真機 QA/LOG、截圖及 Handoff 全部永久保存到 Google Drive/GitHub，不再把使用者 PC 當正式執行/patch 交付目錄。必要 Windows RMVX 實機需要本機臨時複本，必須事先說明並取得使用者同意，雲端驗證完畢後清理；禁止默認已授權。**背景可執行**不等於可長期在 PC 保存。CG 原有 sealed baseline／patch 相對路徑技術契約不變，變更的是寫入／保管位置。

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
