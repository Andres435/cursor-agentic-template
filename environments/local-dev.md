---
name: local-dev
description: Local development environment — ports, commands, and gotchas. Customize for your project.
keywords: local dev, ports, start command, environment, setup
---

# Local Development Environment

**Stub — `/start-new-project` replaces this file.** Hand-edit only if you skip that command.

## Start command

`/start-stack <ticket>` starts `profile.json` `stacks.services`. Update the profile, not this file.

## Services

<!-- gen:ports:start -->
| Service | Port | URL | Starts after |
|---|---|---|---|
| _none_ | | | |
<!-- gen:ports:end -->

## Prerequisites

- Node.js ≥ 20 (or your runtime version)
- `npm install` (or your package manager)
- Copy `.env.example` → `.env.local` and fill required values

## Common gotchas

> Add project-specific setup issues here (auth tokens, certs, missing env vars, etc.)

## Verify

After starting: open http://localhost:3000 and confirm the home page loads.
