# Repository Agent Rules

For any image generation, image editing, game-art asset production, monster/character/battle-motion generation, icon generation, or visual-asset prompt work in this repository, **read `ASSET_GENERATION_PRECHECK.md` before generating or editing any image**. Follow its required read order and the linked shared Google Drive authority.

For any runtime, AutoRegression, battle simulation, AI/gamebit test, catalog validator, asset-production tooling, automation, or other long-running test/tool design/change, **read `BACKGROUND_EXECUTION_AUTHORITY.md` before implementation**. Background-capable execution is a permanent project requirement; losing foreground focus must not unnecessarily stop automated progress. Do not use unsafe thread-based game-state/UI mutation as a shortcut, and preserve existing SEALED runtime authorities.

Pure documentation work that changes neither visual assets nor executable/runtime/test/tool behavior does not add extra preflight beyond the existing project authority.
