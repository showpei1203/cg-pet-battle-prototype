# Current Development Candidate

- Formal Candidate: **v2.6.2b Human Phase 3C Batch B Closure**
- Inherits sealed/formal Scripts **0..276** from `main`.
- Formal candidate index277: `CG Human Rank2 Tactical Skills v2.6.2b`
- Index277 source SHA256: `d81a24c3875e952548ee71d27f38f1309919942c2db927a6b1e45e8be6f765d0`
- Candidate status: **STATIC PASS / NOT FORMAL PASS**.

## Latest test harness

- Current TEST build: **v2.6.2c TEST HARNESS FIX**.
- Formal Scripts 0..277 are byte-exact from v2.6.2b; only TEST-only index278 changed.
- v2.6.2b first real-machine attempt did not enter Scene_Battle because TEST preflight called nonexistent `RPG::Skill#cg_priority`.
- Sealed Priority Authority exposes `RPG::Skill#cg_action_priority_value`; v2.6.2c corrects only that TEST assertion.
- TEST index278 source SHA256: `7ec62bb2e113db4b0a7e5cb00328d79b186f2d09e7ce7600663c5c59e4b88aaa`.
- Previous v2.6.2b TEST harness remains under `tests/v2_6_2b/` as historical failed evidence.
- Current TEST harness is under `tests/v2_6_2c/`.

## Required release gate

Windows / RPG Maker VX real-machine 2-round closure:
- Hunter Mark ranged proxy = 1/1
- Brawler Interrupt surviving pending target = 1/1
- tactical_closure = 2/2
- failures = 0
- pending = 0

Do not merge index277 to `main` until that real-machine log is PASS.