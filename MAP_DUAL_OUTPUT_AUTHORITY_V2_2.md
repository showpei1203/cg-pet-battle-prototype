# Shared Map Coupled Dual-Output Authority v2.2

Effective: 2026-08-19
Scope: Forest Symphony / PMD AutoChess Proto / CG Pet Battle Prototype

This is a GitHub mirror of the shared Google Drive `SHARED_GAME_ASSET_GENERATION_AUTHORITY` Section 18. For conflicts, the latest shared Drive authority wins.

## Mandatory pre-generation rule
Before any AI-generated map/parallax/environment intended for layered runtime authoring, read the shared Drive authority, the target project's `ASSET_GENERATION_PRECHECK.md`, and this coupled dual-output rule.

## Coupled dual-output generation
Do not generate a complete Master Scene first and then ask an image-generation model to independently redraw/extract PAR as a separate creative interpretation. Independent generative redraw can shift buildings, bridges, trees, walls, props, landmarks, or other geometry.

For a new layered map, define one shared layout/composition/geometry authority and one shared object-ownership plan first, then produce two sibling outputs as a coupled pair:

- `GROUND`
- `COMPLETE PAR`

A Master composite may be generated or derived for preview/acceptance, but both outputs must inherit the same canvas, world geometry, anchors, scale and composition authority.

## Object Ownership Exclusivity
Every discrete environmental structure/object has exactly one semantic owner for its visible structure: Ground-class or PAR-class.

A PAR-owned object must not also be visibly redrawn/baked as the same object inside Ground.

This is **object/content exclusivity, not raw alpha-coordinate exclusivity**. Ground may legitimately contain reconstructed base terrain, water, or floor beneath a PAR object at the same x/y coordinates.

## Ground ownership
`GROUND = true ground/terrain surfaces + floor/road/plaza/terrain tiles + flowers + grass + water surfaces.`

Ground may reconstruct continuous base material beneath removed PAR objects but must not preserve the visible PAR structure itself.

## PAR ownership
`PAR = EVERYTHING ELSE.`

PAR owns buildings, walls, gates, towers, roofs, trees/trunks/canopies, bushes/shrubs, rocks as placed objects, statues/pedestals, fountain stone structures/rims/basins, fences, flowerbed borders/structural planters, signs, stalls, furniture, bridges, structural stairs/steps, lamps, crates, barrels, windmills, and every other non-Ground object.

## Atomic object / ambiguous-case rules
- Discrete structures default to whole-object PAR ownership unless a formal split exception exists.
- **Bridge:** entire visible bridge structure (deck, rails, parapets, supports, bridge-head structure) = PAR. Under-bridge water/terrain/bank = Ground. The bridge structure must not be visibly duplicated in Ground.
- **Fountain:** stone structure/rim/pedestal/basin = PAR; fountain water = Ground.
- If an element is a placed/discrete object rather than continuous base material, default to PAR.

## Shared ownership manifest
Before paired output, identify ambiguous/high-risk objects and lock their owners. At minimum consider bridges, fountains, statues/pedestals, structural stairs, walls/gates, trees/rocks, flowerbed borders, peripheral/detached objects, and anything spanning water/terrain.

## Acceptance gates
A candidate remains DRAFT until all applicable checks pass:
1. Ground and Complete PAR use identical canvas dimensions and registration authority.
2. PAR-owned structures are not visibly duplicated in Ground.
3. Object anchors/geometry align when Ground + PAR are composited.
4. `MASTER ≈ GROUND + COMPLETE PAR` passes visual/recomposition QA.
5. Witness-Point/Core-Structure QA confirms important PAR objects where applicable.
6. SAM2 remains QA evidence only; no universal whole-mask overlap percentage is a formal gate.
7. If the generation model cannot maintain sufficient registration, the pair remains Working Benchmark/DRAFT and is not Runtime Approved.
