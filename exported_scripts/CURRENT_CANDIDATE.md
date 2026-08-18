# Current Development Candidate

- Current Binary Baseline: **v2.6.2b FINAL FORMAL PASS**.
- Sealed/formal source range on `main`: **Scripts 0..277**.
- Current Formal Candidate: **v2.6.3 Human Phase 3C Rank-3 Tactical Skills**, index278.
- Index278 source SHA256: `63803cdb5699bc0af76175be699c8789f62aea31f5bd260141307219ae858fa1`.
- Current candidate status: **STATIC PASS / NOT FORMAL PASS**.

## Current TEST build

- TEST build: **v2.6.3a Human Phase 3C Rank-3 Tactical Skills 6R**.
- TEST-only index279 source SHA256: `bc76e8c173e778f3a0b90747b46314d707aad4fbb8802713819392b96ce94942`.
- Scripts 0..277 remain entry-exact to the v2.6.2b FORMAL PASS baseline.
- New DB Skills: 119..124, one Rank-3 tactical skill for each canonical Human class.
- Test plan: one actual Scene_Battle / six rounds, one class per round.

## Required release gate

Windows / RPG Maker VX real-machine closure:
- `RESULT=PASS`
- rounds=6
- failures=0
- rank3_skills=6/6
- tactical_checks=6/6
- ability_catalog=373/373
- formal_move=937/937
- pending=0

Do not merge index278 to `main` or begin Rank-4 formal implementation until this gate is satisfied.