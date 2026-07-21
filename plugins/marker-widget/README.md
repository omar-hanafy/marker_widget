# marker-widget agent plugin

Installable AI coding-assistant support for the
[marker_widget](https://pub.dev/packages/marker_widget) Flutter package, for both
**Claude Code** and **OpenAI Codex**. One plugin directory serves both products:
`.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` share the same
`skills/` tree.

This is tooling for coding agents. It is not part of the Dart package API and is not
shipped in the pub.dev archive; it is installed from this Git repository.

## What is included

| Component | Type | When it activates |
|---|---|---|
| `using-marker-widget` | skill | Adding widget-rendered markers, advanced pins, or ground overlays; choosing among the to* methods; sizing with MarkerRenderOptions vs MapBitmapOptions; declaring imageDependencies; advanced-marker wiring (mapId, markerType, web marker library) |
| `optimizing-marker-widget` | skill | Jank, memory growth, repeated renders, or stale icons after theme/locale/selection changes; MarkerCacheKey design, invalidation, cache bounds, preloading |
| `troubleshooting-marker-widget` | skill | Blank markers, missing network images, MarkerImageLoadException, MarkerRenderException, wrong size or blurry output, invisible advanced markers, StateError/ArgumentError messages, hanging widget tests |
| `reviewing-marker-widget` | skill | Read-only audit of a codebase for marker_widget misuse; the canonical 12-item checklist workflow and report format used by every review surface |
| `marker-widget-reviewer` | agent (Claude Code only) | Delegable wrapper that runs the `reviewing-marker-widget` skill with read-only tools |
| `references/` | shared docs | v3 API quick reference and the 12-item review checklist used by the skills and the agent |
| `evals/` + `graders/` | eval suite | Regression tests for skill triggering and answer quality (`claude plugin eval`) |

There are no hooks, no MCP servers, no network access, and no executable scripts in
this plugin; every component is instructions and reference text. The reviewer agent is
restricted to read-only tools (Read, Grep, Glob).

## Install: Claude Code

```bash
claude plugin marketplace add omar-hanafy/marker_widget
claude plugin install marker-widget@marker-widget
```

Or interactively inside a session: `/plugin marketplace add omar-hanafy/marker_widget`,
then `/plugin install marker-widget@marker-widget`.

Skills auto-trigger from context; invoke explicitly as
`/marker-widget:using-marker-widget`, `/marker-widget:optimizing-marker-widget`,
`/marker-widget:troubleshooting-marker-widget`, or
`/marker-widget:reviewing-marker-widget`. The reviewer agent is available as
`marker-widget:marker-widget-reviewer` (Claude delegates to it automatically for
marker_widget audit requests, or @-mention it); it follows the
`reviewing-marker-widget` skill, so both paths produce the same report.

Update with `claude plugin update marker-widget`; remove with
`claude plugin uninstall marker-widget` and
`claude plugin marketplace remove marker-widget`.

## Install: OpenAI Codex

```bash
codex plugin marketplace add omar-hanafy/marker_widget
codex plugin add marker-widget@marker-widget
```

Then start a new Codex session (required before bundled skills are available). Or use
the interactive `/plugins` browser inside Codex. Skills auto-trigger from context;
mention one explicitly with `$using-marker-widget` etc., or browse `/skills`.

Update with `codex plugin marketplace upgrade marker-widget`; remove with
`codex plugin remove marker-widget@marker-widget` and
`codex plugin marketplace remove marker-widget`.

For codebase audits in Codex, invoke the bundled skill directly:
`$reviewing-marker-widget` (it contains the full checklist workflow and report
format).

Codex plugins cannot bundle custom subagents. To run the audit as a dedicated Codex
subagent, create `.codex/agents/marker-widget-reviewer.toml` in your project
(optional, manual; requires the marker-widget plugin to be installed so the skill
is available):

```toml
name = "marker-widget-reviewer"
description = "Read-only auditor for marker_widget usage: caching, sizing, async images, advanced-marker prerequisites."
sandbox_mode = "read-only"
developer_instructions = """
Invoke the reviewing-marker-widget skill from the installed marker-widget
plugin and follow it exactly: its scope check, its 12-item checklist, and its
four-section report (Summary, Findings, Clean, Not assessed). Do not edit
anything. If the skill is not available, report that the marker-widget plugin
must be installed first instead of improvising an audit.
"""
```

## Example prompts

- "Show each driver on the map as a rounded avatar badge rendered from a widget."
- "Markers re-render every time the camera moves and the map janks. Fix it."
- "My marker avatars from Image.network are blank white circles."
- "Review this codebase for marker_widget problems." (Claude Code delegates to the
  reviewer agent; Codex runs the `reviewing-marker-widget` skill)

## Supported versions

- Package coverage: marker_widget 3.x APIs.
- Verified against Claude Code 2.1.x and codex-cli 0.144.x. Skills use the shared
  SKILL.md format (agentskills.io); frontmatter is restricted to fields both products
  accept.
- Plugin `version` in both manifests tracks the marker_widget package version it was
  released with.

## Troubleshooting the plugin itself

- Skills not appearing in Codex: start a new session after `codex plugin add`.
- Stale content after a repo update: `claude plugin update marker-widget` /
  `codex plugin marketplace upgrade marker-widget`.
- Claude marketplace name collision: this marketplace registers as `marker-widget`;
  a previously added marketplace with the same name is replaced.

## Maintainer guide

- One canonical copy: skills, references, and evals live only in this directory. Both
  plugin manifests point at the same `skills/` tree. Do not fork per-product copies.
- Version rule: on every package release, set `version` in BOTH
  `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` to the new pubspec
  version. `dart run tool/validate_agent_plugin.dart` (repo root) enforces this and
  the structural rules, and runs in CI.
- Keep the plugin focused on the current package API. Add only current names,
  current instructions, and current-source fixtures.
- New skill checklist: kebab-case directory == frontmatter `name`; `description`
  states trigger conditions only; essentials inline, depth in `references/`; add a
  positive eval case named `<stem>-positive` for a skill named
  `<stem>-marker-widget` (the validator enforces one per skill) and keep the
  negative cases passing. Every eval case references a grader whose frontmatter
  `name` matches its filename; graders without a case are errors.
- Validate locally: `claude plugin validate . --strict` (plugin) and
  `claude plugin validate ../..` (marketplace, from this directory), then
  `claude --plugin-dir plugins/marker-widget` from the repo root for a live session.
  Evals: `claude plugin eval plugins/marker-widget --ablation none --runs 1`.
