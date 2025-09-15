Info.plist Keys (copy/paste)
============================

Add these keys into `sekretar/Info.plist` under the top-level dictionary. Replace the API key with yours.

<key>REMOTE_LLM_BASE_URL</key>
<string>https://openrouter.ai/api</string>
<key>REMOTE_LLM_MODEL</key>
<string>openai/gpt-oss-120b:free</string>
<key>REMOTE_LLM_API_KEY</key>
<string>REPLACE_WITH_YOUR_KEY</string>

<!-- optional limits -->
<key>REMOTE_LLM_MAX_TOKENS</key>
<string>256</string>
<key>REMOTE_LLM_TEMPERATURE</key>
<string>0.6</string>

<!-- optional etiquette for OpenRouter -->
<key>REMOTE_LLM_HTTP_REFERER</key>
<string>https://example.com</string>
<key>REMOTE_LLM_HTTP_TITLE</key>
<string>Sekretar</string>

Alternative (local plist)
------------------------
- Create `sekretar/RemoteLLM.plist` (use `sekretar/RemoteLLM.plist.openrouter.sample` as a template) with the same keys above.
- It is ignored by git and now auto-loaded by the app if present.

