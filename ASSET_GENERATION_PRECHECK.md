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
- For map/parallax/environment authoring, preserve `Master + Ground + complete PAR` at identical canvas registration.
- **Ground** contains only true ground/terrain surfaces, floor/terrain tiles, flowers and grass.
- **PAR = everything else.** Buildings, walls, gates, towers, roofs, trees/trunks/canopies, bushes, rocks, statues/fountains, fences, signs, stalls, bridges, structural stairs/steps and every environment prop belong in PAR.
- Occlusion is not the criterion for PAR membership. Actor-covering regions may be derived later by human/tool authority.
- Map split delivery must pass the shared Layer-Split Quality Gate, with `MASTER ≈ GROUND + COMPLETE PAR` as the completeness test.

## Grounded SAM2 semantic audit authority
- Grounded SAM2 is a **semantic QA / missing-object / candidate-mask assistant**, not final art, sprite-anatomy, frame-boundary, environment-layer or runtime authority.
- For environment maps/scenes, prefer category batches and alias fallback instead of one large mixed prompt, and apply oversized-bbox sanity filtering before unioning masks.
- Use class-specific threshold profiles; normally localized classes with implausibly large canvas coverage must be flagged/excluded unless human review accepts them.
- Compare SAM2 evidence against the Master Scene and complete PAR to find probable omissions/false positives.
- For monster/character production, SAM2 may assist silhouette/region QA only. It must not redefine approved anatomy, sprite size metadata, frame anchors, animation boundaries, or battle perspective.
- A SAM2 miss does not authorize deleting an asset/region; a SAM2 hit does not bypass CG visual/runtime QA.
- SAM2-assisted outputs remain **DRAFT** until normal CG validation passes.
- SAM2 workers must comply with Background Execution Authority and should release VRAM after each job on constrained local GPUs.
- **Dense-map refinement:** add post-SAM mask-canvas coverage sanity checks in addition to bbox filtering. For local environment concepts that are too small in a full scene, use overlapping tiled detection, remap boxes to master coordinates, and de-duplicate with concept-level NMS before SAM2.

## Binary split override
This supersedes older wording that treated PAR as only actor-occluding material:
`GROUND = true ground/terrain surfaces + floor/terrain tiles + flowers + grass`
`PAR = EVERYTHING ELSE`
No non-Ground object may be omitted from PAR because of height, collision, occlusion, importance, or SAM2 classification.

## Required read order
`Shared Authority -> CG Precheck -> latest CG visual/asset benchmark -> confirm scale/canvas/layer mode -> generate/edit -> optional SAM2 semantic audit -> Layer-Split Quality Gate when mapping`

Version: 2026-08-19
