# Cherry-Pick Examples

This file helps Claude identify what's worth offering to cherry-pick upstream.
Don't rely only on commit message prefixes - use judgment based on file paths and content.


## High likelihood - offer to cherry-pick

These commits contain reusable process infrastructure:

**1. New agent definition**
```
Commit: Add docs-freshness-auditor agent
Files: .claude/agents/docs-freshness-auditor.md
Why: Agents are portable across projects. This auditor pattern is useful anywhere.
```

**2. MCP server configuration**
```
Commit: Add context7 MCP server with custom runner
Files: .mcp.json, tools/scripts/mcp/context7-runner.js
Why: MCP configs work across Claude Code and Cursor. Custom runners are reusable.
Note: Both .mcp.json (Claude Code) and .cursor/mcp.json (Cursor) are shareable.
```

**3. Skill with helper scripts**
```
Commit: Add playwright-debugging skill
Files: .claude/skills/playwright-debugging/SKILL.md, scripts/pw-helpers.sh
Why: Complete skill package. Scripts make it actionable, not just instructions.
```

**4. CLAUDE.md rule additions**
```
Commit: Add commit splitting rule to CLAUDE.md
Files: .claude/CLAUDE.md (specific section change)
Why: Rules improve agent behavior across all projects using this template.
```

**5. Cursor rules**
```
Commit: Add stack-specific rules for React 19
Files: .cursor/rules/stack/react19.mdc
Why: Cursor rules are IDE-agnostic process knowledge. Useful for teams using both tools.
```

**6. Claude hooks**
```
Commit: Add pre-push validation hook
Files: .claude/hooks/pre-push.sh
Why: Hooks automate quality gates. Generic validation patterns work across projects.
```

**7. Process documentation (look for custom team directories)**
```
Commit: Add agentic debugging workflow guide
Files: docs/agentic-processes/debugging-workflow.md
Why: Teams create custom directories for agentic workflows. Common patterns:
     - docs/agentic-processes/, docs/ai-workflows/, docs/process/
     - tools/ai-scripts/, scripts/claude-helpers/
     - prompts/, .claude/prompts/, prompt-templates/
     These capture reusable team patterns, not project-specific content.
```

**8. Prompts library**
```
Commit: Add code review prompt templates
Files: .claude/prompts/code-review.md, prompts/pr-description.md
Why: Prompts are portable. Well-crafted prompts improve agent behavior across all projects.
```

**9. Automation harnesses**
```
Commit: Add CI workflow for skill validation
Files: tools/ci/validate-skills.sh, scripts/automation/lint-agents.py
Why: Reusable automation that validates agentic tooling. Not project-specific business logic.
```


## Refinable - offer to generalize

These commits contain valuable agentic tooling but have hardcoded project-specific elements. **Claude should offer to pause cherry-picking, generalize the code, and resume after.**

**1. Scripts with project-specific output**
```
Commit: Add transcript parser for claude sessions
Files: tools/scripts/parse-transcripts.py
Blocker: Outputs to `/data/mars-project/transcripts`
Offer: "This parser is reusable but has a hardcoded output path. I can parameterize 
       it to use $OUTPUT_DIR or a CLI argument."
```

**2. Documentation referencing project services**
```
Commit: Update process docs with debugging workflow
Files: docs/process/debugging-guide.md
Blocker: References `mars-project.sentry.io` and `MARS_API_KEY`
Offer: "This debugging guide is valuable but mentions project-specific services. 
       I can replace them with placeholders like <YOUR_SENTRY_PROJECT>."
```

**3. MCP config with absolute paths**
```
Commit: Add context7 MCP server
Files: .mcp.json
Blocker: Uses `/Users/alex/mars-project/.env` for credentials
Offer: "This MCP config is portable but has an absolute path. I can change it to 
       use a relative path or $PROJECT_ROOT."
```

The key insight: Don't skip useful tooling just because it has minor hardcoding. Offer to pause, refine it, then resume cherry-picking.


## Maybe - ask operator

These need operator judgment (not just a simple find-replace fix):

**1. Tool choice assumptions (path triggers review)**
```
Commit: Add pre-commit hook for lint checks
Files: .claude/hooks/pre-commit.sh
Why MAYBE: A lint hook is "regular" dev tooling, not specifically agentic. BUT it's in 
           .claude/hooks/ — a high-signal path — so it gets flagged for review.
           The path matters: anything in .claude/ warrants inspection even if the 
           content seems like standard dev tooling.
Ask: "This hook runs biome lint. Does your template use biome, or should we adapt it?"
```

**2. Workflow assumptions**
```
Commit: Add PR review agent
Files: .claude/agents/pr-reviewer.md
Why MAYBE: PR Agent is well-structured but assumes GitHub. Template might use GitLab.
Ask: "This agent uses GitHub API. Is that compatible with your template's workflow?"
```

**3. Manifests, ie package.json changes (inspect the diff)**
```
Commit: Add MCP dependencies
Files: package.json
Why MAYBE: Could be project config OR agentic tooling. Inspect the actual diff.

If diff shows:
  + "@anthropic-ai/claude-code": "^1.0.0"
  + "@modelcontextprotocol/sdk": "^0.5.0"
→ READY: These are agentic packages, cherry-pick

If diff shows:
  - "name": "shared-template"
  + "name": "mars-project"
→ SKIP: Project-specific config change
```


## No - skip these

These are fundamentally project-specific and shouldn't go upstream:

**1. Feature code**
```
Commit: Add user authentication flow
Files: src/auth/login.ts, src/auth/session.ts
Why NO: Business logic specific to this project. No amount of modification makes this generic.
```

**2. Project configs with names/IDs**
```
Commit: Update package.json for mars-project
Files: package.json, workspace file
Why NO: Contains project name, specific deps, and repo URLs. These define the project itself.
```

**3. PRDs and project docs**
```
Commit: PRD v2 - user onboarding redesign
Files: docs/prd/user-onboarding-v2.md
Why NO: Product requirements are project-specific by definition.
```

**4. Environment files**
```
Commit: Add shared env example
Files: .env.shared.example, .env.example
Why NO: Even examples often leak project-specific service names and keys.
```

**5. General IDE settings (NOT agentic process configs)**
```
Commit: Update editor preferences
Files: .vscode/settings.json, .cursor/settings.json, .idea/workspace.xml
Why NO: These are personal/project preferences (themes, font sizes, syntax highlighting).
        Contrast with .cursor/rules/*.mdc which ARE agentic process configs.
```


## IDE Configs: Agentic vs General

**Critical distinction**: Not all IDE configs are shareable. Cherry-pick configs that define **how AI agents behave** (rules, prompts, MCP servers), not general editor preferences.

| Path | Type | Cherry-pick? |
|------|------|--------------|
| `.cursor/rules/*.mdc` | Cursor's AI behavior rules | ✅ YES |
- `.claude/agents/*.md` - Claude Code's Agent definitions | ✅ YES |
- `.claude/hooks/*.sh` - Claude Code's Automation hooks | ✅ YES |
- `.claude/skills/*/SKILL.md` - Claude Code's Skills | ✅ YES |
| `.cursor/mcp.json` | MCP server config | ✅ YES |
| `.cursor/settings.json` | Editor preferences | ❌ NO |
| `.vscode/settings.json` | Editor preferences | ❌ NO |
| `.vscode/extensions.json` | Extension recommendations | ❌ NO |
| `.idea/*` | IntelliJ settings | ❌ NO |

**Example - YES (agentic process):**
```
Files: .cursor/rules/commit-hygiene.mdc
Content: Rules for how AI should format commits, split changes, write messages
Why YES: Governs AI agent behavior, portable across projects
```

**Example - NO (general IDE):**
```
Files: .cursor/settings.json
Content: {"editor.fontSize": 14, "workbench.colorTheme": "Dracula"}
Why NO: Personal preferences, not agentic process knowledge
```


## Cross-Tool + Platform Patterns

The agentic tooling ecosystem is wide, spanning many categories. Don't assume a specific tool. Look for broad patterns that work across the ecosystem:

**IDEs & Code Editors**: Cursor (with Cursor AI), VS Code (with Claude Code), Visual Studio (with GitHub Copilot), JetBrains IDEs (with JetBrains AI Assistant), Zed (with Zed AI), Windsurf (with Codeium), Neovim (with Codeium/Copilot plugins), Emacs (with gptel/Copilot).

**AI Coding Assistants**: Anthropic Claude Code, GitHub Copilot, AWS Amazon Q Developer (Rufus), Cline, Augment Code, Kilo Code, Roo Code, Amp, Qodo Gen (formerly CodiumAI), Zencoder, Tabnine, Sourcegraph Cody.

**CLI Tools**: iTerm with AI assistant, Anthropic Claude Code CLI, Google Gemini CLI, Alibaba Qwen Coder, OpenAI Codex CLI, AWS Amazon Q CLI, Microsoft Copilot CLI, Atlassian Rovo Dev CLI, Opencode.

**Desktop Apps**: Anthropic Claude Desktop, Perplexity Desktop, Ollama, LM Studio (local models), BoltAI, Crush, Emdash, Microsoft Copilot.

**Browser Extensions**: Anthropic Claude Chrome extension, Google Gemini extension, Microsoft Copilot extension, Perplexity extension, Comet (Claude integration).

**DevOps & CI/CD**: GitHub Copilot (for Actions), GitLab Duo, Azure DevOps (with Microsoft Copilot).

**Container & Runtime Formats**: Docker (for MCP servers), Bun, Deno, containerized agent runners.

**Chat & Collaboration**: Anthropic Claude in Slack, Microsoft Teams (with Copilot), Discord bots (various).

**MCP Ecosystem**: Anthropic MCP Inspector, Smithery (MCP registry), Context7, any third-party MCP providers and directories.

- `.mcp.json` / `.cursor/mcp.json` - MCP server configs

**Hosted & Cloud**: Anthropic Claude on web, AWS Bedrock, Google Vertex AI, Azure OpenAI, remote MCP servers.

**Repos & Registries**: Awesome-MCP-Servers, Awesome-Claude-Code, Awesome-AI-Agents, official Claude Skill directory, Smithery registry, npm/PyPI packages for MCP servers, GitHub template repos.

**Prompt Libraries**: Anthropic's official Claude Prompt Library, OpenAI Cookbook, LangChain Hub, PromptBase, custom team prompt repos (`prompts/`, `.claude/prompts/`).

**Custom Team Directories**: Look for team-specific conventions like `docs/agentic-processes/`, `tools/ai-scripts/`, `prompts/templates/`, `.claude/workflows/`. These often contain the most valuable reusable patterns.