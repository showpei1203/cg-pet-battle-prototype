# CG Pet Battle Prototype — Asset Generation Precheck

**Mandatory before every image generation or image edit.**

1. Read the shared Google Drive authority: `SHARED_GAME_ASSET_GENERATION_AUTHORITY` (Drive file ID `1TF4wGLqwiALO-IJ_1R-5m9J7fGS-47tKmNi5yH_LMdc`).
2. Read the CG Drive authority file `ASSET_GENERATION_PRECHECK_CG` in `CG_Pet_Battle_Prototype/00_Project_Authority`.
3. Identify asset mode: character/monster/battle-motion/icon/environment/reusable prop.
4. Apply the latest CG visual/runtime authority before generating.

## Inherited rules
- Runtime isolated assets: prefer chroma-key `#FF00FF` or `#00FF00`.
- Runtime pixel assets: `flat colors`, `no anti-aliasing`, `crisp edges`, approved limited palette.
- **32x32 is the human/map WORLD-SCALE player/tile reference, not a total environment canvas limit.** `544x416` is only a viewport reference.
- **MONSTERS ARE NOT LIMITED TO 32x32 PIXELS.** Size may vary by species, evolution stage, silhouette, battle role, boss scale and composition.
- Large-scale monster production must preserve silhouette/perspective consistency across batches; size is metadata-driven, not normalized to one square.
- When producing large map/parallax/environment scenes, preserve `Master + Ground-Only + exhaustive All Non-Ground Objects` at identical canvas registration.
- All Non-Ground Objects must include every building, wall, gate, tree, statue/fountain, landmark and environmental prop even when it is not expected to cover the actor.
- Occlusion/Par is derived later by human/tool authority and must not replace the complete Non-Ground layer.
- Map split delivery must pass the shared Layer-Split Quality Gate: exact registration, coherent Ground, exhaustive Non-Ground coverage, clean alpha/edges, no residue/broken holes, and recomposition against Master.

## Required read order
`Shared Authority -> CG Precheck -> latest CG visual/asset benchmark -> confirm scale/canvas/layer mode -> generate/edit -> Layer-Split Quality Gate when mapping`

Version: 2026-08-19
