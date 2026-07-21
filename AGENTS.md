# marker_widget repository guide (for coding agents)

Publishable Flutter package: renders widgets into google_maps_flutter bitmaps and
markers. Public API is a single library: `lib/marker_widget.dart` (exports) +
`lib/src/marker_widget.dart` (entire implementation). Keep it that way; do not split
into new files or add dependencies without explicit approval. Everything under `lib/`
is public API surface: any behavior or signature change is a semver event.

## Validation (run before claiming any change works)

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart pub publish --dry-run
dart run tool/validate_agent_plugin.dart
```

CI additionally requires a FULL pana score. Never weaken analysis_options.yaml, skip
tests, or add lint ignores to pass gates. Test renders must run inside
`tester.runAsync(...)`.

## Release lane (automated; do not publish manually)

- `main` = stable versions only; `dev` = prerelease suffixes only (CI enforces).
- `main` is protected: changes land via PR; required checks are `CI / Test on stable`
  and `pub-dry-run / dry-run`.
- Merging a pubspec `version:` change to main auto-tags `marker_widget-v<version>`,
  which triggers the OIDC publish workflow to pub.dev. Never create or move release
  tags by hand, never re-push a failed tag, never run `dart pub publish` directly.
- Every release updates together: `pubspec.yaml` version, `CHANGELOG.md` entry, and
  `version` in `plugins/marker-widget/.claude-plugin/plugin.json` AND
  `plugins/marker-widget/.codex-plugin/plugin.json` (the validator enforces sync).

## Agent plugin tree (AI-assistant support shipped from this repo)

`plugins/marker-widget/` is a dual-target Claude Code + Codex plugin (catalogs:
`.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`). It is
repo-distributed only and MUST stay out of the pub.dev archive (`.pubignore` covers
it; the dry-run file list must never contain `plugins/`). Skill content lives once
under `plugins/marker-widget/skills/`; maintainer rules are in
`plugins/marker-widget/README.md`. When package behavior, defaults, or error strings
change, update the affected skill/reference files in the same PR.

## Conventions

- CHANGELOG follows Keep a Changelog; document the net public delta only.
- Keep v3 clean: ship only current APIs, current instructions, and current-source
  fixtures. Do not preserve prior-version names or code paths.
- Do not commit `pubspec.lock`, `.DS_Store`, `build/`, or IDE folders (gitignored).
- Docs: every public member has a Dartdoc (`public_member_api_docs` is an error).
