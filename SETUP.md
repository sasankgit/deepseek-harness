# Local DeepSeek Harness setup

Run `./Start-Harness.ps1` from PowerShell or click the Desktop shortcut. It loads the Firecrawl key from `firecrawl.env`, exposes the local Nuclei binary on `PATH`, and starts the Web UI at `http://127.0.0.1:3081`, opening it in your browser. Clicking again while it is running reopens the current UI instead of starting a duplicate server. Start LM Studio's API with `lms server start` before using the local model.

The Web profile registers Playwright MCP over stdio and Firecrawl MCP over Streamable HTTP. It defaults to the loaded LM Studio model `gohumanize-open-humanizer` with a 40,960-token context. LM Studio serves its OpenAI-compatible API on port 1234. Additional downloaded models can be added through Settings → Models → Fetch available models.

The ngrok route is configured for `qwen3.8-27b`, a 90,000-token context window, streaming, a five-minute request timeout, and the ngrok warning header. Supply `NGROK_API_KEY` in the launching shell or in an untracked `ngrok.env` file as `NGROK_API_KEY=...`, then save/select the provider in Settings → Models.

Nuclei is available as `nuclei` in shells launched by the harness. Its executable is `tools/nuclei.exe`.
