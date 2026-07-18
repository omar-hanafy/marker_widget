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
| `using-marker-widget` | skill | Adding widget-rendered markers, advanced pins, or ground overlays; choosing among the to* methods; sizing with WidgetBitmapRenderOptions vs MapBitmapOptions; advanced-marker wiring (mapId, markerType, web marker library) |
| `optimizing-marker-widget` | skill | Jank, memory growth, repeated renders, or stale icons after theme/locale/selection changes; cacheKey design, invalidation, cache bounds, preloading |
| `troubleshooting-marker-widget` | skill | Blank markers, missing network images, wrong size or blurry output, invisible advanced markers, StateError/ArgumentError messages, hanging widget tests |
| `migrating-marker-widget-v1-to-v2` | skill | Upgrading 1.x to 2.x; compile errors mentioning toMarkerBitmap, widgetToMarkerBitmap, MarkerIconScalingMode, scalingMode, renderedDpr |
| `marker-widget-reviewer` | agent (Claude Code only) | Read-only audit of a codebase for marker_widget misuse (uncached hot-path renders, incomplete cache keys, async-image blanks, missing advanced-marker prerequisites) |
| `references/` | shared docs | v2 API quick reference and the 12-item review checklist used by the skills and the agent |
| `evals/` + `graders/` | eval suite | Regression tests for skill triggering and migration quality (`claude plugin eval`) |

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
`/marker-widget:migrating-marker-widget-v1-to-v2`. The reviewer agent is available as
`marker-widget:marker-widget-reviewer` (Claude delegates to it automatically for
marker_widget audit requests, or @-mention it).

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

Codex plugins cannot bundle custom subagents. To get the reviewer as a Codex subagent,
create `.codex/agents/marker-widget-reviewer.toml` in your project (optional, manual):

```toml
name = "marker-widget-reviewer"
description = "Read-only auditor for marker_widget usage: caching, sizing, async images, advanced-marker prerequisites."
sandbox_mode = "read-only"
developer_instructions = """
Audit the project's marker_widget usage against the checklist in the installed
marker-widget plugin (references/review-checklist.md, items 1-12). Report findings as
file:line, checklist item, severity, problem, fix. End with a severity-sorted summary
and the items found clean. Do not edit anything.
"""
```

## Example prompts

- "Show each driver on the map as a rounded avatar badge rendered from a widget."
- "Markers re-render every time the camera moves and the map janks. Fix it."
- "My marker avatars from Image.network are blank white circles."
- "Upgrade this app from marker_widget 1.1.0 to 2.0.0."
- Claude Code: "Review this codebase for marker_widget problems." (delegates to the
  reviewer agent)

## Compatibility

- Package coverage: marker_widget 2.x APIs; the migration skill covers 1.0.0/1.1.0 to
  2.x (the only breaking hop released so far).
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
- New breaking package version: add a dedicated `migrating-marker-widget-vX-to-vY`
  skill (keep the old ones), extract the exact old API from the previous release tag,
  and add a fixture pair under `evals/fixtures/` plus an eval case.
- New skill checklist: kebab-case directory == frontmatter `name`; `description`
  states trigger conditions only; essentials inline, depth in `references/`; add a
  positive eval case and keep the negative-control case passing.
- Validate locally: `claude plugin validate . --strict` (plugin) and
  `claude plugin validate ../..` (marketplace, from this directory), then
  `claude --plugin-dir plugins/marker-widget` from the repo root for a live session.
  Evals: `claude plugin eval plugins/marker-widget --ablation none --runs 1`.
