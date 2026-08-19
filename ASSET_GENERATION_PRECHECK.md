# CG Pet Battle Prototype — Asset Generation Precheck

**Mandatory before every image generation or image edit.**

1. Read Google Drive shared `SHARED_GAME_ASSET_GENERATION_AUTHORITY`.
2. Read Drive `CG_Pet_Battle_Prototype/00_Project_Authority/ASSET_GENERATION_PRECHECK_CG`.
3. Apply latest CG visual/runtime authority.
4. For layered map/parallax/environment work, read `MAP_DUAL_OUTPUT_AUTHORITY_V2_5.md`.

## Current layered-map mode — v2.5
`GROUND-FIRST + PLACEMENT ANCHORS + SOURCE-ASSET/EXTRACTION + DETERMINISTIC ASSEMBLY + PAR PURITY + PIXEL-CRISP`

- Ground = base terrain/floor/road/plaza tiles + grass + flowers + water surfaces.
- PAR = everything else.
- Occlusion is not PAR membership authority.
- Ground is accepted first; major structures then receive unique anchor/footprint contracts.
- Image generation is source-art authority only, not final canvas / exact workcell / coordinate authority.
- Prefer extraction from existing approved/reference art when exact source pixels already exist.
- Final placement uses deterministic integer coordinates on the unchanged Ground canvas.
- Default source-to-target viability profile is `0.75–1.25`; outside is Source Scale FAIL unless explicitly approved.
- Pixel-art resizing uses Nearest Neighbor only.
- Structural alpha normally prefers `0/255`; broad feather/partial-alpha/AA haze is DRAFT/FAIL evidence.
- Validate each object/group before advancing.
- Primary map completeness authority remains `MASTER ≈ GROUND + COMPLETE PAR`.

## CG inheritance
- 32×32 is human/map world-scale reference, not total environment-canvas limit.
- Monsters are not limited to 32×32; size follows species/evolution/battle role and framing.
- Large monster production must preserve approved silhouette/perspective authority.

## SAM2
SAM2 / Guided SAM2 is QA/omission evidence only; never raw art/layer/anatomy/frame/runtime authority. Do not use a universal whole-mask overlap percentage as a formal Gate.

## Required read order
`Shared Authority -> CG Drive Precheck -> MAP_DUAL_OUTPUT_AUTHORITY_V2_5 -> latest CG visual/asset benchmark -> Ground -> Ground QA -> anchors -> source/extraction -> deterministic assembly -> per-object QA -> recomposition/witness QA`

Version: 2026-08-20 v2.5
