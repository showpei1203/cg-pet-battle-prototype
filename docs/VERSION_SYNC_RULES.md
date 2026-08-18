# Version Sync Rules

1. Start from the current formal baseline/source state.
2. Modify source on `develop` or a scoped branch.
3. Export/update `Scripts.rvdata` without changing script order unintentionally.
4. Build complete Windows/RPG Maker VX test ZIP.
5. Store test build in Drive `03_Test_Builds`.
6. Update the Linear issue.
7. Run real-machine test.
8. Store AutoRegression/Trace/Validation evidence in Drive `04_Test_Logs`.
9. FAIL: classify and continue on candidate branch.
10. PASS: merge source to `main`.
11. Promote executable to Drive `01_Current_Baseline`; move replaced baseline to `09_Archive`.
12. Update Linear to Done/PASS state.
13. Update MASTER_PROJECT_STATE and CURRENT_HANDOFF.
