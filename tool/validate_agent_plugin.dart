// Validates the repo-distributed agent plugin (plugins/marker-widget) and its
// marketplace catalogs for both Claude Code and OpenAI Codex.
//
// Checks: required files, JSON validity, version sync with pubspec.yaml and
// CHANGELOG.md, kebab-case names, catalog source paths, SKILL.md frontmatter
// (shared allowlist for both products), referenced files, eval/grader wiring,
// absolute-path and secret-like leaks, and .pubignore coverage.
//
// Usage: dart run tool/validate_agent_plugin.dart   (from the repo root)
// Exits non-zero with one line per problem; prints OK summary otherwise.
import 'dart:convert';
import 'dart:io';

final List<String> _errors = <String>[];

void _err(String message) => _errors.add(message);

final RegExp _kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

const String _pluginDir = 'plugins/marker-widget';
const Set<String> _skillFrontmatterAllowlist = <String>{
  // Shared allowlist: Claude Code accepts these and the Codex CLI restricts
  // frontmatter to exactly this set (plus disable-model-invocation).
  'name',
  'description',
  'license',
  'allowed-tools',
  'metadata',
  'disable-model-invocation',
};

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run from the repository root (pubspec.yaml not found).');
    exit(2);
  }

  final String? pubspecVersion = _pubspecVersion();
  if (pubspecVersion == null) {
    _err('pubspec.yaml: could not read version');
  }

  final Map<String, Object?>? claudeManifest = _readJson(
    '$_pluginDir/.claude-plugin/plugin.json',
  );
  final Map<String, Object?>? codexManifest = _readJson(
    '$_pluginDir/.codex-plugin/plugin.json',
  );
  final Map<String, Object?>? claudeMarketplace = _readJson(
    '.claude-plugin/marketplace.json',
  );
  final Map<String, Object?>? codexMarketplace = _readJson(
    '.agents/plugins/marketplace.json',
  );

  _checkManifest(claudeManifest, 'claude', pubspecVersion);
  _checkManifest(codexManifest, 'codex', pubspecVersion);
  _checkClaudeMarketplace(claudeMarketplace, pubspecVersion);
  _checkCodexMarketplace(codexMarketplace);
  _checkSkills();
  _checkAgents();
  _checkEvals();
  _checkChangelog(pubspecVersion);
  _checkPubignore();
  _checkLeaks();

  if (_errors.isEmpty) {
    stdout.writeln(
      'agent plugin validation OK '
      '(version $pubspecVersion, ${_skillNames().length} skills)',
    );
    return;
  }
  for (final String e in _errors) {
    stderr.writeln('ERROR: $e');
  }
  stderr.writeln('${_errors.length} problem(s) found.');
  exit(1);
}

String? _pubspecVersion() {
  final RegExpMatch? m = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return m?.group(1);
}

Map<String, Object?>? _readJson(String path) {
  final File f = File(path);
  if (!f.existsSync()) {
    _err('$path: missing');
    return null;
  }
  try {
    final Object? decoded = jsonDecode(f.readAsStringSync());
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    _err('$path: top-level JSON value is not an object');
  } on FormatException catch (e) {
    _err('$path: invalid JSON (${e.message})');
  }
  return null;
}

void _checkManifest(
  Map<String, Object?>? manifest,
  String flavor,
  String? pubspecVersion,
) {
  if (manifest == null) {
    return;
  }
  final String path = '$_pluginDir/.$flavor-plugin/plugin.json';
  final Object? name = manifest['name'];
  if (name != 'marker-widget') {
    _err('$path: name must be "marker-widget", got "$name"');
  }
  final Object? version = manifest['version'];
  if (version is! String || version != pubspecVersion) {
    _err(
      '$path: version "$version" does not match pubspec version '
      '"$pubspecVersion"',
    );
  }
  if (version is String &&
      !RegExp(r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.+-]+)?$').hasMatch(version)) {
    _err('$path: version "$version" is not semver');
  }
  if (manifest['description'] is! String ||
      (manifest['description']! as String).isEmpty) {
    _err('$path: description missing or empty');
  }
  final Object? keywords = manifest['keywords'];
  if (keywords != null && keywords is! List) {
    _err('$path: keywords must be an array');
  }
  if (flavor == 'codex') {
    final Object? skills = manifest['skills'];
    if (skills is String) {
      if (!skills.startsWith('./')) {
        _err('$path: skills path must be ./-relative, got "$skills"');
      }
      final String resolved = '$_pluginDir/${skills.substring(2)}';
      if (!Directory(resolved).existsSync()) {
        _err('$path: skills path "$skills" does not exist');
      }
    }
  }
  for (final String key in manifest.keys) {
    final Object? value = manifest[key];
    if (value is String && _looksAbsolute(value)) {
      _err('$path: field "$key" contains an absolute path: $value');
    }
  }
}

void _checkClaudeMarketplace(
  Map<String, Object?>? marketplace,
  String? pubspecVersion,
) {
  if (marketplace == null) {
    return;
  }
  const String path = '.claude-plugin/marketplace.json';
  final Object? name = marketplace['name'];
  if (name is! String || !_kebab.hasMatch(name)) {
    _err('$path: marketplace name must be kebab-case, got "$name"');
  }
  final Object? owner = marketplace['owner'];
  if (owner is! Map || owner['name'] is! String) {
    _err('$path: owner.name is required');
  }
  final Object? plugins = marketplace['plugins'];
  if (plugins is! List || plugins.isEmpty) {
    _err('$path: plugins array is required and must not be empty');
    return;
  }
  final Set<String> seen = <String>{};
  for (final Object? entry in plugins) {
    if (entry is! Map) {
      _err('$path: plugin entry is not an object');
      continue;
    }
    final Object? pluginName = entry['name'];
    if (pluginName is! String || !_kebab.hasMatch(pluginName)) {
      _err('$path: plugin name must be kebab-case, got "$pluginName"');
      continue;
    }
    if (!seen.add(pluginName)) {
      _err('$path: duplicate plugin name "$pluginName"');
    }
    final Object? source = entry['source'];
    if (source is String) {
      if (!source.startsWith('./') || source.contains('..')) {
        _err(
          '$path: source for "$pluginName" must be ./-relative without '
          '"..", got "$source"',
        );
      } else if (!File(
        '${source.substring(2)}/.claude-plugin/plugin.json',
      ).existsSync()) {
        _err('$path: source "$source" has no .claude-plugin/plugin.json');
      }
    } else {
      _err('$path: source for "$pluginName" must be a relative path string');
    }
    final Object? entryVersion = entry['version'];
    if (entryVersion != null && entryVersion != pubspecVersion) {
      _err(
        '$path: entry version "$entryVersion" drifts from pubspec '
        '"$pubspecVersion" (omit it or keep it in sync)',
      );
    }
  }
}

void _checkCodexMarketplace(Map<String, Object?>? marketplace) {
  if (marketplace == null) {
    return;
  }
  const String path = '.agents/plugins/marketplace.json';
  final Object? name = marketplace['name'];
  if (name is! String || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(name)) {
    _err('$path: marketplace name must match [A-Za-z0-9_-]+, got "$name"');
  }
  final Object? plugins = marketplace['plugins'];
  if (plugins is! List || plugins.isEmpty) {
    _err('$path: plugins array is required and must not be empty');
    return;
  }
  for (final Object? entry in plugins) {
    if (entry is! Map) {
      _err('$path: plugin entry is not an object');
      continue;
    }
    final Object? pluginName = entry['name'];
    if (pluginName is! String || !_kebab.hasMatch(pluginName)) {
      _err('$path: plugin name must be kebab-case, got "$pluginName"');
    }
    final Object? source = entry['source'];
    if (source is! Map || source['source'] != 'local') {
      _err('$path: source.source must be "local" for repo-hosted plugins');
      continue;
    }
    final Object? sourcePath = source['path'];
    if (sourcePath is! String ||
        !sourcePath.startsWith('./') ||
        sourcePath.contains('..')) {
      _err(
        '$path: source.path must be ./-relative without "..", got '
        '"$sourcePath"',
      );
    } else if (!File(
      '${sourcePath.substring(2)}/.codex-plugin/plugin.json',
    ).existsSync()) {
      _err('$path: source.path "$sourcePath" has no .codex-plugin/plugin.json');
    }
  }
}

List<String> _skillNames() {
  final Directory dir = Directory('$_pluginDir/skills');
  if (!dir.existsSync()) {
    return const <String>[];
  }
  return dir
      .listSync()
      .whereType<Directory>()
      .map((Directory d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
      .toList()
    ..sort();
}

void _checkSkills() {
  final List<String> names = _skillNames();
  if (names.isEmpty) {
    _err('$_pluginDir/skills: no skill directories found');
    return;
  }
  if (names.toSet().length != names.length) {
    _err('$_pluginDir/skills: duplicate skill names');
  }
  for (final String name in names) {
    final String skillPath = '$_pluginDir/skills/$name/SKILL.md';
    final File f = File(skillPath);
    if (!f.existsSync()) {
      _err('$skillPath: missing');
      continue;
    }
    if (!_kebab.hasMatch(name)) {
      _err('$skillPath: directory name must be kebab-case');
    }
    final Map<String, String>? front = _frontmatter(f.readAsStringSync());
    if (front == null) {
      _err('$skillPath: missing or unterminated YAML frontmatter');
      continue;
    }
    for (final String key in front.keys) {
      if (!_skillFrontmatterAllowlist.contains(key)) {
        _err(
          '$skillPath: frontmatter key "$key" is outside the shared '
          'Claude/Codex allowlist $_skillFrontmatterAllowlist',
        );
      }
    }
    final String? skillName = front['name'];
    if (skillName != name) {
      _err(
        '$skillPath: frontmatter name "$skillName" must equal directory '
        'name "$name"',
      );
    }
    final String? description = front['description'];
    if (description == null || description.trim().isEmpty) {
      _err('$skillPath: frontmatter description is required');
    } else if (description.length > 1024) {
      _err(
        '$skillPath: description is ${description.length} chars '
        '(keep <= 1024)',
      );
    }
    _checkReferencedFiles(skillPath, f.readAsStringSync());
  }
}

Map<String, String>? _frontmatter(String content) {
  final List<String> lines = const LineSplitter().convert(content);
  if (lines.isEmpty || lines.first.trim() != '---') {
    return null;
  }
  final Map<String, String> result = <String, String>{};
  String? currentKey;
  final StringBuffer currentValue = StringBuffer();
  for (int i = 1; i < lines.length; i++) {
    final String line = lines[i];
    if (line.trim() == '---') {
      if (currentKey != null) {
        result[currentKey] = currentValue.toString().trim();
      }
      return result;
    }
    final RegExpMatch? kv = RegExp(
      r'^([A-Za-z0-9_-]+):\s*(.*)$',
    ).firstMatch(line);
    if (kv != null) {
      if (currentKey != null) {
        result[currentKey] = currentValue.toString().trim();
      }
      currentKey = kv.group(1);
      currentValue
        ..clear()
        ..write(kv.group(2) ?? '');
    } else if (currentKey != null) {
      currentValue
        ..write(' ')
        ..write(line.trim());
    }
  }
  return null; // unterminated
}

void _checkReferencedFiles(String sourcePath, String content) {
  // Any path-like token ending in .md or .dart mentioned in skill/agent text
  // must resolve relative to the file's directory or the plugin root.
  final String sourceDir = (File(sourcePath).parent.path).replaceAll('\\', '/');
  for (final RegExpMatch m in RegExp(
    r'(?:package:)?[A-Za-z0-9_./-]+\.(?:md|dart)\b',
  ).allMatches(content)) {
    final String token = m.group(0)!;
    if (!token.contains('/')) {
      continue; // bare names like SKILL.md in prose
    }
    if (token.startsWith('package:') || token.contains('://')) {
      continue;
    }
    // Skip repo-level paths quoted for consumers (lib/, example/, tool/).
    if (token.startsWith('lib/') ||
        token.startsWith('example/') ||
        token.startsWith('test/') ||
        token.startsWith('tool/')) {
      continue;
    }
    final List<String> candidates = <String>[
      '$sourceDir/$token',
      '$_pluginDir/$token',
    ];
    final bool exists = candidates.any(
      (String c) => File(Uri.parse(c).normalizePath().path).existsSync(),
    );
    if (!exists) {
      _err('$sourcePath: referenced file "$token" not found');
    }
  }
}

void _checkAgents() {
  final Directory dir = Directory('$_pluginDir/agents');
  if (!dir.existsSync()) {
    _err('$_pluginDir/agents: missing');
    return;
  }
  for (final File f in dir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.md')) {
      continue;
    }
    final Map<String, String>? front = _frontmatter(f.readAsStringSync());
    if (front == null) {
      _err('${f.path}: missing or unterminated YAML frontmatter');
      continue;
    }
    if (front['name'] == null || front['description'] == null) {
      _err('${f.path}: agent frontmatter needs name and description');
    }
    _checkReferencedFiles(f.path, f.readAsStringSync());
  }
}

void _checkEvals() {
  final Directory evals = Directory('$_pluginDir/evals');
  if (!evals.existsSync()) {
    _err('$_pluginDir/evals: missing');
    return;
  }
  for (final Directory caseDir in evals.listSync().whereType<Directory>()) {
    final String dirName =
        caseDir.uri.pathSegments[caseDir.uri.pathSegments.length - 2];
    if (dirName == 'fixtures' || dirName == 'results') {
      continue;
    }
    final File caseFile = File('${caseDir.path}/case.yaml');
    if (!caseFile.existsSync()) {
      _err('${caseDir.path}: missing case.yaml');
      continue;
    }
    final String content = caseFile.readAsStringSync();
    if (!content.contains(RegExp(r'^name:', multiLine: true)) ||
        !content.contains(RegExp(r'^prompt:', multiLine: true))) {
      _err('${caseFile.path}: case.yaml needs name and prompt');
    }
    final RegExpMatch? graderRef = RegExp(
      r'^grader:\s*"?([A-Za-z0-9_-]+)"?\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (graderRef != null &&
        !File('$_pluginDir/graders/${graderRef.group(1)}.md').existsSync()) {
      _err(
        '${caseFile.path}: grader "${graderRef.group(1)}" has no file in '
        'graders/',
      );
    }
  }
}

void _checkChangelog(String? pubspecVersion) {
  if (pubspecVersion == null) {
    return;
  }
  final String changelog = File('CHANGELOG.md').readAsStringSync();
  if (!changelog.contains('[$pubspecVersion]')) {
    _err('CHANGELOG.md: no entry for version $pubspecVersion');
  }
}

void _checkPubignore() {
  final File f = File('.pubignore');
  if (!f.existsSync()) {
    _err(
      '.pubignore: missing (the plugin tree must not reach the pub.dev '
      'archive)',
    );
    return;
  }
  final List<String> lines = const LineSplitter()
      .convert(f.readAsStringSync())
      .map((String l) => l.trim())
      .toList();
  for (final String required in <String>['plugins/', 'tool/', 'AGENTS.md']) {
    if (!lines.contains(required)) {
      _err('.pubignore: must contain a "$required" entry');
    }
  }
}

void _looksLikeSecretScan(File f) {
  final String content = f.readAsStringSync();
  final List<RegExp> patterns = <RegExp>[
    RegExp('AIza[0-9A-Za-z_-]{20,}'),
    RegExp('sk-[A-Za-z0-9]{20,}'),
    RegExp('ghp_[A-Za-z0-9]{20,}'),
    RegExp('AKIA[0-9A-Z]{16}'),
  ];
  for (final RegExp p in patterns) {
    if (p.hasMatch(content)) {
      _err('${f.path}: contains a secret-like token matching ${p.pattern}');
    }
  }
  if (_looksAbsolute(content)) {
    _err('${f.path}: contains an absolute local path (/Users/, /home/, C:\\)');
  }
}

bool _looksAbsolute(String value) {
  return value.contains('/Users/') ||
      value.contains('/home/') ||
      value.contains(r'C:\');
}

void _checkLeaks() {
  final List<FileSystemEntity> roots = <FileSystemEntity>[
    Directory(_pluginDir),
    File('.claude-plugin/marketplace.json'),
    File('.agents/plugins/marketplace.json'),
    File('AGENTS.md'),
  ];
  for (final FileSystemEntity root in roots) {
    if (root is File) {
      _looksLikeSecretScan(root);
    } else if (root is Directory && root.existsSync()) {
      for (final File f
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (File f) =>
                    f.path.endsWith('.md') ||
                    f.path.endsWith('.json') ||
                    f.path.endsWith('.yaml') ||
                    f.path.endsWith('.dart'),
              )) {
        _looksLikeSecretScan(f);
      }
    }
  }
}
