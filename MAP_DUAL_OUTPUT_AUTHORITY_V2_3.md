# Shared Map Dual-Output Authority v2.3

Effective: 2026-08-19
Applies to: Forest Symphony / PMD AutoChess Proto / CG Pet Battle Prototype

This supersedes v2.2 for layered AI-generated map/parallax/environment production.

## 1. Ground-first sequential generation
- Do **not** generate Ground and PAR simultaneously when precise registration matters.
- Generate `GROUND` first.
- Validate Ground geometry/layout anchors before PAR generation.
- Treat accepted Ground as the geometry authority for roads, plazas, pools, rivers, entries, open lots and structural footprints.
- Only after Ground is accepted, generate `COMPLETE PAR` using both the original Master/style authority and the accepted Ground as references.
- PAR must fit the accepted Ground geometry. It must not independently reinterpret the scene.

## 2. Object ownership
- Ground = true terrain/base surfaces + floor/road/plaza tiles + flowers + grass + water.
- PAR = everything else.
- Object ownership is exclusive by visible structure, not by raw alpha coordinates.
- Ground may contain reconstructed terrain/water/floor beneath a PAR object at the same x/y position, but must not visibly duplicate the PAR structure.
- Bridge structure = PAR-only; under-bridge water/terrain/bank = Ground-only.
- Fountain stone structure/rim/basin/pedestal = PAR; fountain water = Ground.
- Ambiguous placed/discrete objects default to PAR.

## 3. Pixel-crisp runtime rule
Pixel-art runtime map layers and overlays must target:
- hard pixel edges;
- crisp 1px/2px silhouette details where present in the approved style;
- no anti-aliasing on structural pixel-art edges;
- no blur, painterly smoothing, soft edge blending or fuzzy reconstruction;
- no feathered halos around cutout objects;
- avoid semi-transparent edge pixels unless explicitly part of an approved visual effect; normal structure silhouettes should prefer alpha 0/255;
- no sub-pixel shifts, fractional alignment or resampling drift between Ground and PAR;
- no soft gradients invented to hide generation/extraction defects;
- Nearest Neighbor only for pixel-art resize/downsample.

## 4. Pixel-crisp visual gate
A candidate remains DRAFT if, at 100% or integer zoom (200%/400%):
- structural edges are materially softer than the approved Master/style authority;
- small pixel details are smeared or blurry;
- PAR shows broad partial-alpha feathering;
- edge halos/fringes are visible;
- sharp source pixels have been replaced by smooth reconstructed edges.

Non-integer editor zoom such as 66.7% may look softer and is not itself proof of a bad file. Formal QA must include 100% and integer zoom.

Registration quality and pixel-crisp quality are separate gates. A perfectly aligned but blurry layer still FAILS visual/runtime acceptance.

## 5. Required layered-map order
`Shared Authority -> Project Precheck -> ownership/anchor lock -> generate Ground only -> Ground geometry QA -> generate PAR from Master + accepted Ground -> pixel-crisp QA -> registration/recomposition/witness QA -> Runtime approval`

## 6. Formal acceptance
`MASTER ≈ GROUND + COMPLETE PAR` remains the primary completeness/recomposition authority. SAM2 remains QA evidence only; no universal full-mask overlap percentage is a formal gate.
