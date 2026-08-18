# GitHub Migration Status

Updated: 2026-08-18 13:24 +08:00

## Connectivity
- Repository: `showpei1203/cg-pet-battle-prototype`
- Read: PASS
- Contents write: PASS
- Default branch: `main`
- Development branch: `develop`

## Source Authority
- `main`: latest formal / sealed Source Authority = Scripts 0..276.
- `develop`: current v2.6.2b candidate; Candidate index277 and TEST-only index278 remain isolated from main.
- Complete independent text export 0..276 is published under `exported_scripts/`.
- `SCRIPT_MANIFEST.csv` preserves Script Index, Script ID, Script Name, original runtime source SHA256, and file mapping.
- Git may normalize CRLF to LF in tracked text. Runtime byte authority therefore remains Google Drive `Scripts.rvdata`; the manifest records the original runtime source SHA256.

## Full Source Audit
- Import branch commit: `b48d2ebb5923d3d19d26f75c6f93294b655dcbed`
- Audit PR #1 merged to main.
- Main full-source merge commit: `44edeaa5fdb3f6120f7a47bcbcd753e158c03504`
- Post-import main -> develop sync PR #2 merged.
- Develop sync commit: `049c63df051c1f14e037091e715ea9d937eb28e2`
- Import tree was not truncated and contains continuous Script indices 000..276.
- Formal source274/275 match the pre-import main copies exactly.
- Source276 pre-import Git blob differed only at text-normalization level: PR patch was null with 0 additions / 0 deletions; Runtime source SHA remained `98acacc7b99306d43b210e269d25f37212f55a208660c0bb791d4f8532f18aa2`.
- After sync, `develop` is behind main by 0 and differs only by Candidate277, `CURRENT_CANDIDATE.md`, and TEST278.

## Binary Boundary
No `.rvdata`, complete game ZIP, Graphics, Audio, executable build, or test logs were intentionally migrated to GitHub by this process. Those remain Google Drive Binary / Build / Asset / Log Authority.

## Migration Result
`GITHUB_SOURCE_MIGRATION=PASS`

Gameplay/runtime was not modified by infrastructure migration. Next development gate returns to v2.6.2b RPG Maker VX real-machine 2-round closure.