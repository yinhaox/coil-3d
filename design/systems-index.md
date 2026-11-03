# Systems index

One row per system. Add the row in the same pull request that adds the design doc. The vision lives in [vision.md](vision.md); every row should serve one of its pillars.

| System | Owner | Status | Doc | Summary | Depends on |
|---|---|---|---|---|---|
| Core rules | game-designer | in review | design/core-rules.md | Grid movement, snake queue, turning, food, collision, scoring and speed | — (rules only) |
| Game modes and arena data | game-designer | in review | design/game-modes.md | Classic/Maze/Time Attack and the `assets/data/arenas/*.json` schema | Core rules |
| Camera and presentation | technical-artist | in review | design/camera-and-presentation.md | Isometric camera, procedural meshes, palette and tween timing | Core rules, Game modes and arena data |
| UX and persistence | game-designer | in review | design/ux-and-persistence.md | Menu-to-end flow, HUD, settings and `user://save.json` | Core rules, Game modes and arena data |
| Audio | technical-artist | in review | design/audio.md | Runtime-synthesized cue table, mixing and failure fallback | Core rules |
| Accessibility | game-designer | in review | design/accessibility.md | Shape/color separation, input parity, font scale and reduced motion | Camera and presentation, UX and persistence, Audio |
| Architecture | tech-director | in review | design/architecture.md | Pure logic layer, scene split, runtime input and performance budget | — (cross-cutting constraints) |
| Release | release-manager | in review | design/release.md | Versioning, three-platform export, license, credits and known limits | Architecture, UX and persistence |

Status values:

- draft: being written, not yet a commitment.
- in review: waiting on a human decision.
- approved: implementable, and stories may cite it.
- shipped: implemented and covered by evidence.
- outdated: kept for history, do not implement from it.

Rules:

- Every design doc under design/ has exactly one row here.
- The Doc cell uses forward slashes and starts with design/.
- Owner is a role from .dsh/agents/, not a person's name.
- Depends on lists system names from this table; keep it free of cycle claims that the docs do not support.
- Moving a row to shipped requires an evidence index under production/qa/evidence/ that reports Run result: OBSERVED.
