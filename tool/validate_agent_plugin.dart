// Validates the repo-distributed agent plugin (plugins/marker-widget) and its
// marketplace catalogs for both Claude Code and OpenAI Codex.
//
// Checks: required files, JSON validity, version sync with pubspec.yaml and
// CHANGELOG.md, the runtime dependency allowlist, kebab-case names, catalog
// source paths and required Codex policy fields, SKILL.md frontmatter (shared
// allowlist for both products), referenced files, agent read-only tooling,
// eval/grader wiring (one positive case per skill, no orphan graders),
// removed v2 API names in current-only content, absolute-path and secret-like
// leaks, and .pubignore coverage.
//
// Usage: dart run tool/validate_agent_plugin.dart   (from the repo root)
// Exits non-zero with one line per problem; prints OK summary otherwise.
import 'dart:convert';
import 'dart:io';

final List<String> _errors = <String>[];

void _err(String message) => _errors.add(message);

final RegExp _kebab = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

const String _pluginDir = 'plugins/marker-widget';

/// The complete allowed runtime dependency set. The package is facade-only:
/// platform implementations arrive through google_maps_flutter itself, and
/// the changelog promises exactly this set. Anything else here is drift.
const Set<String> _allowedRuntimeDeps = <String>{
  'flutter',
  'google_maps_flutter',
};

/// Public API names removed in v3. Current-only skills, references, and
/// agents must not mention them; migration history lives in CHANGELOG.md and
/// the README migration section only.
const List<String> _removedV2Names = <String>[
  'WidgetBitmapRenderOptions',
  'defaultMarkerIconRenderer',
  'buildMarkerCacheKey',
  'buildClusterCacheKey',
  'waitForImages',
  'initialImageDelay',
  'imageRepaintDelay',
  'MarkerIconScalingMode',
  'toMarkerBitmap',
  'widgetToMarkerBitmap',
];

/// The only tools the plugin's agents may declare; the plugin promises a
/// read-only reviewer with no execution surface.
const Set<String> _allowedAgentTools = <String>{'Read', 'Grep', 'Glob'};
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

  _checkRuntimeDependencies();
  _checkManifest(claudeManifest, 'claude', pubspecVersion);
  _checkManifest(codexManifest, 'codex', pubspecVersion);
  _checkClaudeMarketplace(claudeMarketplace, pubspecVersion);
  _checkCodexMarketplace(codexMarketplace);
  _checkSkills();
  _checkAgents();
  _checkEvals();
  _checkRemovedNames();
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

/// Asserts the pubspec `dependencies:` block contains exactly
/// [_allowedRuntimeDeps]. This would have caught the working-tree drift that
/// both external 3.0.0 reviews flagged as their top finding.
void _checkRuntimeDependencies() {
  final List<String> lines = const LineSplitter().convert(
    File('pubspec.yaml').readAsStringSync(),
  );
  final Set<String> declared = <String>{};
  bool inDependencies = false;
  for (final String line in lines) {
    if (RegExp(r'^dependencies:\s*$').hasMatch(line)) {
      inDependencies = true;
      continue;
    }
    if (inDependencies) {
      if (line.trim().isEmpty) {
        continue;
      }
      if (!line.startsWith(' ')) {
        break; // next top-level key ends the block
      }
      final RegExpMatch? dep = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (dep != null) {
        declared.add(dep.group(1)!);
      }
    }
  }
  for (final String dep in declared) {
    if (!_allowedRuntimeDeps.contains(dep)) {
      _err(
        'pubspec.yaml: runtime dependency "$dep" is outside the allowed set '
        '$_allowedRuntimeDeps (facade-only policy; see AGENTS.md)',
      );
    }
  }
  for (final String dep in _allowedRuntimeDeps) {
    if (!declared.contains(dep)) {
      _err('pubspec.yaml: expected runtime dependency "$dep" is missing');
    }
  }
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
    if (skills is! String) {
      _err(
        '$path: a "skills" path is required for the Codex manifest '
        '(this plugin ships its content as skills)',
      );
    } else {
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
  final Object? interface = marketplace['interface'];
  if (interface is! Map ||
      interface['displayName'] is! String ||
      (interface['displayName']! as String).isEmpty) {
    _err('$path: interface.displayName is required (shown in the Codex UI)');
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
    final Object? policy = entry['policy'];
    if (policy is! Map ||
        policy['installation'] is! String ||
        policy['authentication'] is! String) {
      _err(
        '$path: policy.installation and policy.authentication are required '
        'for "$pluginName" (Codex marketplace schema)',
      );
    }
    if (entry['category'] is! String) {
      _err('$path: category is required for "$pluginName"');
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
    final String fileStem = f.uri.pathSegments.last.replaceAll(
      RegExp(r'\.md$'),
      '',
    );
    if (front['name'] != null && front['name'] != fileStem) {
      _err(
        '${f.path}: frontmatter name "${front['name']}" must equal the '
        'filename "$fileStem"',
      );
    }
    final String? tools = front['tools'];
    if (tools == null) {
      _err(
        '${f.path}: agent must declare an explicit read-only tools list '
        '(subset of $_allowedAgentTools)',
      );
    } else {
      for (final RegExpMatch m in RegExp(r'"([^"]+)"').allMatches(tools)) {
        final String tool = m.group(1)!;
        if (!_allowedAgentTools.contains(tool)) {
          _err(
            '${f.path}: tool "$tool" is outside the read-only allowlist '
            '$_allowedAgentTools; the plugin promises read-only agents',
          );
        }
      }
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
  final Set<String> referencedGraders = <String>{};
  final Set<String> caseNames = <String>{};
  for (final Directory caseDir in evals.listSync().whereType<Directory>()) {
    final String dirName =
        caseDir.uri.pathSegments[caseDir.uri.pathSegments.length - 2];
    if (dirName == 'fixtures' || dirName == 'results') {
      continue;
    }
    caseNames.add(dirName);
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
    if (graderRef == null) {
      _err('${caseFile.path}: every eval case must reference a grader');
    } else {
      final String grader = graderRef.group(1)!;
      referencedGraders.add(grader);
      final File graderFile = File('$_pluginDir/graders/$grader.md');
      if (!graderFile.existsSync()) {
        _err('${caseFile.path}: grader "$grader" has no file in graders/');
      } else {
        final Map<String, String>? front = _frontmatter(
          graderFile.readAsStringSync(),
        );
        if (front == null || front['name'] != grader) {
          _err(
            '${graderFile.path}: grader frontmatter name '
            '"${front?['name']}" must equal the filename "$grader"',
          );
        }
      }
    }
  }

  // One positive eval per skill: <stem>-marker-widget -> <stem>-positive.
  for (final String skill in _skillNames()) {
    final RegExpMatch? stem = RegExp(r'^(.+)-marker-widget$').firstMatch(skill);
    if (stem == null) {
      continue;
    }
    final String expected = '${stem.group(1)!}-positive';
    if (!caseNames.contains(expected)) {
      _err(
        '$_pluginDir/evals: skill "$skill" has no positive eval case '
        '"$expected" (one positive case per skill is required)',
      );
    }
  }

  // No orphan graders.
  final Directory graders = Directory('$_pluginDir/graders');
  if (graders.existsSync()) {
    for (final File f in graders.listSync().whereType<File>()) {
      if (!f.path.endsWith('.md')) {
        continue;
      }
      final String stem = f.uri.pathSegments.last.replaceAll(
        RegExp(r'\.md$'),
        '',
      );
      if (!referencedGraders.contains(stem)) {
        _err('${f.path}: grader is not referenced by any eval case');
      }
    }
  }
}

/// Current-only content must not mention APIs removed in v3; migration
/// history belongs in CHANGELOG.md and the README migration section.
void _checkRemovedNames() {
  for (final String sub in <String>['skills', 'references', 'agents']) {
    final Directory dir = Directory('$_pluginDir/$sub');
    if (!dir.existsSync()) {
      continue;
    }
    for (final File f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.md')) {
        continue;
      }
      final String content = f.readAsStringSync();
      for (final String name in _removedV2Names) {
        if (content.contains(name)) {
          _err(
            '${f.path}: mentions removed v2 API "$name"; current-only '
            'content must use current names (migration history lives in '
            'CHANGELOG.md)',
          );
        }
      }
    }
  }
}

void _checkChangelog(String? pubspecVersion) {
  if (pubspecVersion == null) {
    return;
  }
  final String changelog = File('CHANGELOG.md').readAsStringSync();
  final RegExp heading = RegExp(
    '^## \\[${RegExp.escape(pubspecVersion)}\\]',
    multiLine: true,
  );
  if (!heading.hasMatch(changelog)) {
    _err(
      'CHANGELOG.md: no "## [$pubspecVersion]" release heading '
      '(a substring mention elsewhere does not count)',
    );
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
    File('README.md'),
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
