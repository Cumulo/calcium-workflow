# 2026-08-22 18:00 — Pin alerts to a published release

- Replaced the unavailable temporary `Respo/alerts.calcit` branch with the published `0.10.19` release.
- This keeps CI and local dependency resolution reproducible and avoids depending on a contributor branch.
- The change is limited to the dependency manifest; Calcit snapshot behavior is unchanged.
