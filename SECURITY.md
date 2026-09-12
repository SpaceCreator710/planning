# Security Policy

## Reporting a vulnerability

Please do not publish exploitable security details in a public issue. Use GitHub's private vulnerability reporting feature when it is enabled for this repository, or contact the maintainer privately through the repository profile.

Include the affected component, reproduction conditions, expected impact, and the smallest safe proof of concept needed to understand the issue.

## Secret handling

- AI provider keys belong only in server-side environment variables.
- Supabase publishable client configuration may be stored in local app configuration, but privileged service-role credentials must never be committed or bundled.
- `Config.xcconfig` in the repository contains placeholders only.
- Never commit signing certificates, provisioning profiles, tokens, `.env` files, or private user exports.

## Supported code

Security fixes target the current `main` branch unless a release branch is explicitly documented as supported.
