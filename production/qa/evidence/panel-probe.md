# Panel probe evidence

Captured while testing the orchestrator panel with Playwright against this
deployment (port 3084):

- `panel-probe.png` — the panel opened behind the preview notice.
- `panel-probe-2.png` — the overview after dismissing it.
The accessibility snapshots taken during the probe were dropped: they captured
the local workspace's session list and host name, which does not belong in a
repository.

The probe paused and resumed processing through the panel's dialogs; the API
reported `paused: true` and then `paused: false`.
