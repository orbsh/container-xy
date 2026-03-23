# OpenClaw

The `ghcr.io/fj0r/xy:openclaw` image is regularly updated to the latest version

- Configuration files are automatically generated from environment variables, no onboarding process required
- Mount `/app/data` to persist data
- Service port: 18789
- Pre-installed SKILLS can be specified
- Custom SKILLS can be specified via links
  - `SKILL_PACKAGE_URLS`: Skill package URLs
  - `SKILL_PACKAGE_AUTH`: Username and password
  - `SKILL` is packaged as a tar.zst compressed archive
    - No wrapper directory
    - Contains a `config.json` file, which is the configuration for this SKILL in OpenClaw, plus a `name` field
- Set the `QWEN_API_KEY` or `GLM_API_KEY` environment variable at startup to configure the model provider
  - Other providers require additionally specifying `XXX_BASE_URL` and `XXX_MODEL`
  - Must be an OpenAI-compatible API
