# Shared Map Layered Generation Authority v2.4

Effective: 2026-08-19
Scope: Forest Symphony / PMD AutoChess Proto / CG Pet Battle Prototype

This document extends v2.3 and is mandatory for AI-generated layered maps/parallax environments intended for runtime authoring.

## 1. Ground-first remains mandatory
Generate `GROUND` first. Validate its road/path/water/plaza/plot geometry before PAR generation. Ground is the base geometry authority.

## 2. Ground-first alone is NOT enough
A PAR object being in the correct quadrant or approximately near the intended area is not acceptable. Major structures must be bound to explicit Ground anchors before PAR generation.

## 3. Placement Anchor Contract is mandatory
After Ground is accepted and before generating PAR, define a Placement Anchor Contract / footprint manifest for every major PAR structure. Each anchor should include a unique ID, target footprint/region, path/road relation, water/crossing relation where relevant, and acceptance note. Similar plots require unique IDs so objects cannot silently exchange positions.

## 4. Footprint / relationship rules
- A building must materially occupy its assigned Ground plot/clearing and must not jump to another plot.
- A building entrance should connect/face the intended adjacent path where the layout implies one.
- A bridge must span its declared crossing corridor.
- Fountain/shrine stone structure must register to its declared Ground water/pad anchor.
- Central structures must preserve their declared plaza/axis relationship.

## 5. PAR generation contract
Generate `COMPLETE PAR` only after Ground + Placement Anchor Contract are accepted. Use both as explicit references/constraints. Do not rely on “align closely” as the only placement instruction. If full-scene generation drifts, use regional/object-group generation tied to locked anchors and assemble without moving Ground.

## 6. Placement QA Gate
Composite `GROUND + PAR` and inspect every declared anchor. A major object on the wrong plot/path/crossing is FAIL even if the overall scene is attractive.

## 7. Object ownership
`GROUND = true base terrain + floor/road/plaza tiles + grass + flowers + water.`
`PAR = EVERYTHING ELSE.`
Ground may reconstruct base material under PAR objects but must not duplicate the visible structure. Bridge structure = PAR-only; under-bridge water/terrain/bank = Ground-only. Fountain stone structure = PAR; fountain water = Ground.

## 8. PAR Purity / Alpha Integrity
PAR may contain only PAR-owned objects/structures. Do not include broad semi-transparent copies of Ground grass, roads, flowers, banks or water to hide mismatch. Normal pixel-art structural alpha should normally be 0/255; broad partial-alpha haze, feather halo, antialias blur and sub-pixel drift are DRAFT/FAIL evidence unless a real effect is explicitly approved.

## 9. Pixel-crisp gate
Hard pixel edges, no blur/soft smoothing/painterly reconstruction. Nearest Neighbor only for pixel-art resizing/downsampling. Inspect at 100%, 200% or 400%.

## 10. Required workflow v2.4
`Shared Authority -> Project Precheck -> generate Ground only -> Ground geometry QA -> create Placement Anchor Contract / unique plot IDs -> generate PAR from accepted Ground + anchor contract -> per-anchor placement QA -> PAR purity + pixel-crisp QA -> recomposition/witness QA -> Runtime approval`

## 11. Promotion rule
A candidate remains DRAFT if any major anchor is wrong. Placement, ownership, alpha purity and pixel crispness are independent gates.