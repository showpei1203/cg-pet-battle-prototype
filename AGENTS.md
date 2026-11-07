# Repository Agent Rules

## GLOBAL HARD RULES 001 · 2026-11-07 · 優先於所有舊專案 SOP
在任何會產生／保存檔案的任務前，**先讀** [00_GLOBAL_HARD_RULES_跨對話最高優先規範](https://docs.google.com/document/d/1NftePmIsggrhnfPcZTZS2G6YBka2yBy_fdw-NBT5D8Y/edit)。所有新開發成果、原始碼、圖片、工程／ZIP、研究、QA／LOG、截圖及 Handoff，永久保存目的地只能是 **Google Drive 或 GitHub**；私人／敏感資料只進有適當權限的 Drive 或私人儲存庫，嚴禁推送公開 GitHub。使用者 PC **不得**作為新的工作目錄／Git clone／成果庫／備份庫。必要安裝及其不可避免的 Runtime 環境檔例外。確實必須在 PC 建立臨時工作檔時，必須**事前說明原因、範圍、清除方法並取得使用者授權**，不是自動允許；完成雲端 WRITE→READBACK→VERIFY 後清除臨時檔。不要擅自刪除／遷移舊 PC 檔案。
若舊腳本硬編碼輸出到 `C:\`／`D:\`／`E:\`／PC 同步磁碟 `G:\`，未改成真正的雲端路徑、或未取得上述臨時執行授權，不得直接執行。歷史 QA、封版、來源 SHA、專案技術規格仍有效；本規則只更新開發**工作檔案的持久儲存與驗收方式**，不變更正式功能、使用者裝置/App 自己的資料持久化需求。

For any image generation, image editing, game-art asset production, monster/character/battle-motion generation, icon generation, or visual-asset prompt work in this repository, **read `ASSET_GENERATION_PRECHECK.md` before generating or editing any image**. Follow its required read order and the linked shared Google Drive authority.

For any runtime, AutoRegression, battle simulation, AI/gamebit test, catalog validator, asset-production tooling, automation, or other long-running test/tool design/change, **read `BACKGROUND_EXECUTION_AUTHORITY.md` before implementation**. Background-capable execution is a permanent project requirement; losing foreground focus must not unnecessarily stop automated progress. Do not use unsafe thread-based game-state/UI mutation as a shortcut, and preserve existing SEALED runtime authorities.

Pure documentation work that changes neither visual assets nor executable/runtime/test/tool behavior does not add extra preflight beyond the existing project authority.
