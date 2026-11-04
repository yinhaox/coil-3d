# Panel probe evidence

Captured while testing the orchestrator panel with Playwright against this
deployment (port 3084):

- `panel-probe.png` — the panel opened behind the preview notice.
- `panel-probe-2.png` — the overview after dismissing it.
- `panel-exec.yaml` / `panel-exec2.yaml` — the executor tab and the pause
  confirmation dialog.
- `panel-resume.yaml` — the resume confirmation dialog.

The probe paused and resumed processing through the panel's dialogs; the API
reported `paused: true` and then `paused: false`.
