# Shared Map Layered Generation Authority v2.5

Effective: 2026-08-19
Scope: Forest Symphony / PMD AutoChess Proto / CG Pet Battle Prototype

This extends v2.4 and is mandatory when exact PAR placement / runtime registration matters.

## 1. Generative placement boundary
Image generation is not final coordinate/canvas authority. Tests showed that even explicit workcell-size requests can return unrelated dimensions and broad partial-alpha output. After Ground + Placement Anchor Contract are locked, the generator may create source-object appearance but must not control final global PAR position, final canvas size, or final registration.

## 2. Source-asset role
Generated building/bridge/tower/prop art is SOURCE ASSET only until deterministic placement QA passes. Generate one object or tightly related object group at a time whenever precise placement matters. Source generation must not reinterpret Ground geometry, roads, water, plot boundaries, neighboring accepted objects, or the full scene layout.

## 3. Deterministic assembly
The final PAR canvas is created at the exact approved Ground dimensions. Each accepted source asset is trimmed to its true alpha bounds, checked against its declared target bbox, and placed at integer x/y coordinates from the Placement Anchor Contract / deterministic assembly plan. No sub-pixel placement or model-controlled full-scene layout is permitted after anchors are locked.

## 4. Scale viability gate
Calculate source-to-target fit before placement. Default viable scale band: `0.75–1.25` unless a project-specific benchmark overrides it. Larger changes mean the source asset is at the wrong production scale and must be regenerated/re-authored, not forced into place. Nearest Neighbor only for allowed pixel-art resize. Large reductions such as ~15% of source size are automatic FAIL evidence for runtime pixel fidelity.

## 5. Alpha / pixel integrity gate
Source assets must have real transparency and meaningful opaque structure. Broad partial-alpha is not acceptable for normal pixel-art structures unless an approved effect requires it. Default warning/fail profile: partial-alpha coverage `>=20%`, zero meaningful opaque structure, blurred/feathered silhouette, or halo contamination.

## 6. Per-object progression gate
Each object/group must pass alpha, scale, bbox containment, entrance/path/water relationship, and pixel-crisp QA before the next object/group proceeds. A failed object does not authorize moving its Ground anchor or altering accepted neighbors.

## 7. Required production order v2.5
`Shared Authority -> Project Precheck -> Ground -> Ground QA -> Placement Anchor Contract -> per-object source generation -> source alpha/scale QA -> deterministic integer-coordinate assembly -> per-object placement QA -> regional PAR QA -> final recomposition/witness QA -> Runtime approval`

If the current image generator cannot produce viable runtime-scale source assets, switch to extraction/pixel-authoring/approved asset-generation tooling instead of repeatedly forcing unsuitable generative output.
