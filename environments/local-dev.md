---
name: local-dev
description: Local development environment — ports, commands, and gotchas. Customize for your project.
keywords: local dev, ports, start command, environment, setup
---

# Local Development Environment

**Stub — fill in your project's actual values.**

## Start command

```bash
# From profile.json stacks.startCommand — update that field, not this file
npm run dev
```

## Ports

| Service | URL | Notes |
|---|---|---|
| App | http://localhost:3000 | Update if your port differs |

## Prerequisites

- Node.js ≥ 20 (or your runtime version)
- `npm install` (or your package manager)
- Copy `.env.example` → `.env.local` and fill required values

## Common gotchas

> Add project-specific setup issues here (auth tokens, certs, missing env vars, etc.)

## Verify

After starting: open http://localhost:3000 and confirm the home page loads.
