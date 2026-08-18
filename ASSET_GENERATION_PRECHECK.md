# CG Pet Battle Prototype — Asset Generation Precheck

**Mandatory before every image generation or image edit.**

1. Read the shared Google Drive authority: `SHARED_GAME_ASSET_GENERATION_AUTHORITY` (Drive file ID `1TF4wGLqwiALO-IJ_1R-5m9J7fGS-47tKmNi5yH_LMdc`).
2. Read the CG Drive authority file `ASSET_GENERATION_PRECHECK_CG` in `CG_Pet_Battle_Prototype/00_Project_Authority`.
3. Identify asset mode: character/monster/battle-motion/icon/environment/reusable prop.
4. Apply the latest CG visual/runtime authority before generating.

## Inherited rules
- Runtime isolated assets: prefer chroma-key `#FF00FF` or `#00FF00`.
- Runtime pixel assets: `flat colors`, `no anti-aliasing`, `crisp edges`, approved limited palette.
- Human/map environment readability uses a 32x32 player/tile reference.
- **MONSTERS ARE NOT LIMITED TO 32x32 PIXELS.** Size may vary by species, evolution stage, silhouette, battle role, boss scale and composition.
- Large-scale monster production must preserve silhouette/perspective consistency across batches; size is metadata-driven, not normalized to one square.

## Required read order
`Shared Authority -> CG Precheck -> latest CG visual/asset benchmark -> generate/edit image`

Version: 2026-08-19
