# GitHub Migration Status

Updated: 2026-08-18 12:36 +08:00

## Connectivity
- Repository: `showpei1203/cg-pet-battle-prototype`
- Read: PASS
- Contents write: PASS
- Default branch: `main`
- Development branch: `develop`

## Current branch model
- `main`: formal/sealed source authority. Current sealed state is Scripts 0..276.
- `develop`: current v2.6.2b candidate. Index277 is candidate runtime; TEST-only index278 lives under `tests/v2_6_2b/`.

## Directly published high-value source
- index274 PMD Multi-Hit Ownership Bridge v2.5.53
- index275 Human Six-Class Authority v2.6.0
- index276 Human Trait + Skill Tree Authority v2.6.1
- develop-only index277 Human Rank2 Tactical Skills v2.6.2b
- develop-only TEST index278 Human Phase3C Batch B Closure v2.6.2b

## Remaining migration item
The connector now supports text writes but has no direct local-file/bulk-upload transport. The exact full formal export for indices 0..276 is already materialized locally and in the migration package. Indices 0..273 still require one bulk import pass before GitHub Source Authority is considered fully migrated.

A safe import package has been prepared to push **only** a new branch `migration/full-source-import`, never force-push or overwrite `main`/`develop`. After that branch appears, it must be audited against `SCRIPT_MANIFEST.csv` and merged to `main` only on exact-match evidence.

Runtime/gameplay was not changed by this infrastructure work.
