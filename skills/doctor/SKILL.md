---
name: doctor
description: Health check. Verify the workspace is set up for the agentic workflow — profile, hooks, artifact gate, stack start command, optional lane probe, and workflow epoch.
keywords: doctor, health check, workspace, profile, hooks, validate, lane probe
disable-model-invocation: true
icon: stethoscope
color: cyan
---

# Doctor

Full instructions: [playbooks/doctor.md](playbooks/doctor.md).

Read and execute that playbook now. Do not ask for confirmation before reading it.

```text
/doctor                          core checks
/doctor --lanes                  plus the lane probe (inline-only tiers are skipped, never dispatched)
/doctor --lanes --retest-inline  also re-test an inline-only tier once, e.g. after a plan change
```
