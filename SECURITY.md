# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in AIOS, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include the following information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

## Security Model

AIOS is designed with a **privacy-first** architecture:

- **On-device inference** — All LLM inference runs locally via llama.cpp. No data is sent to external servers.
- **No network calls** — The app does not make network requests during normal operation (except for future model downloads).
- **Agent sandbox** — Agent tools operate within Android's standard permission model. The agent cannot perform actions beyond what the user has granted permissions for.

## Permissions

AIOS requires the following sensitive permissions:

| Permission | Risk Level | Mitigation |
|-----------|-----------|------------|
| Accessibility Service | **High** | User must explicitly enable; only reads/acts on screen content when agent is active |
| Notification Listener | **Medium** | User must explicitly enable; only reads notification text for agent context |
| System Alert Window | **Medium** | Used only for floating AI button overlay |
| Foreground Service | **Low** | Required for LLM inference while app is backgrounded |

## Agent Safety

- The ReAct agent loop has a configurable maximum iteration limit (default: 5)
- Agent tools are explicitly registered — only whitelisted tools can be invoked
- Sensitive actions (calling, SMS) are planned to require explicit user confirmation
- A security sandbox for agent actions is on the roadmap

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.3.x   | ✅ Active development |
| < 0.3   | ❌ Pre-release, not supported |
