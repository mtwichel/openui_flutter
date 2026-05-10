// Layer-boundary enforcer for the OpenUI Flutter monorepo.
//
// Reads each package's pubspec.yaml and asserts the declared `dependencies:`
// set against the allow-list defined here. Exits non-zero on any violation.
// Wired into per-package CI via Phase 0 decision D13.
//
// Run from the workspace root:
//   dart run tool/check_deps.dart
//
// To allow a new dependency, edit the `_rules` table below.

import 'dart:io';

const _rules = <String, _PackageRule>{
  'openui_core': _PackageRule(
    type: _PackageType.dart,
    allowed: {'meta', 'json_schema_builder'},
  ),
  'openui': _PackageRule(
    type: _PackageType.flutter,
    allowed: {'flutter', 'meta', 'openui_core'},
  ),
  'openui_chat': _PackageRule(
    type: _PackageType.dart,
    allowed: {'openui_core'},
  ),
  'openui_components': _PackageRule(
    type: _PackageType.flutter,
    allowed: {'flutter', 'openui', 'openui_core'},
  ),
  'openui_mcp': _PackageRule(
    type: _PackageType.dart,
    allowed: {'openui_core'},
  ),
  'openui_test_helpers': _PackageRule(
    type: _PackageType.dart,
    allowed: {},
  ),
};

void main(List<String> args) {
  final root = Directory.current;
  final packages = Directory(
    '${root.path}/packages',
  ).listSync().whereType<Directory>().toList();

  final violations = <String>[];
  for (final dir in packages) {
    final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final rule = _rules[name];
    if (rule == null) {
      violations.add('$name: no rule registered in tool/check_deps.dart');
      continue;
    }
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (!pubspec.existsSync()) {
      violations.add('$name: pubspec.yaml missing');
      continue;
    }
    final deps = _parseDeps(pubspec.readAsStringSync());
    for (final dep in deps) {
      if (!rule.allowed.contains(dep)) {
        violations.add(
          '$name: depends on $dep which is not in the allow-list. '
          'Update tool/check_deps.dart if this is intentional.',
        );
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('check_deps: ${packages.length} packages OK');
    return;
  }
  stderr.writeln('check_deps: ${violations.length} violation(s):');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  exit(1);
}

enum _PackageType { dart, flutter }

class _PackageRule {
  const _PackageRule({required this.type, required this.allowed});
  final _PackageType type;
  final Set<String> allowed;
}

/// Minimal `dependencies:` parser. We deliberately avoid pulling in
/// `package:yaml` so this script can run with no transitive deps in CI.
Set<String> _parseDeps(String pubspec) {
  final lines = pubspec.split('\n');
  final result = <String>{};
  var inDependencies = false;
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (!line.startsWith(' ') && !line.startsWith('\t')) {
      // Top-level key. Re-evaluate whether we're in `dependencies:`.
      inDependencies = line == 'dependencies:';
      continue;
    }
    if (!inDependencies) continue;
    final match = _depEntry.firstMatch(line);
    if (match != null) result.add(match.group(1)!);
  }
  return result;
}

final _depEntry = RegExp('^  ([a-z_][a-z0-9_]*):');
