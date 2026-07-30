import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain code never imports a feature data implementation', () {
    for (final file in _dartFiles('lib/features')) {
      if (!_normalizedPath(file).contains('/domain/')) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains('/data/')),
        reason: '${file.path} must depend on domain contracts only',
      );
    }
  });

  test('application code depends on contracts, never data or presentation', () {
    for (final file in _dartFiles('lib/features')) {
      if (!_normalizedPath(file).contains('/application/')) continue;
      final source = file.readAsStringSync();
      expect(source, isNot(contains('/data/')),
          reason:
              '${file.path} must receive data implementations by injection');
      expect(source, isNot(contains('/presentation/')),
          reason: '${file.path} cannot depend on UI state');
    }
  });

  test('presentation code never imports a data implementation', () {
    for (final file in _dartFiles('lib/features')) {
      if (!_normalizedPath(file).contains('/presentation/')) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains('/data/')),
        reason: '${file.path} must call a controller or repository port',
      );
    }
  });

  test('presentation reads semantic theme instead of accepting night flags',
      () {
    final nightFlagField = RegExp(r'final\s+bool\s+nightMode\b');
    final nightFlagArgument = RegExp(r'\bnightMode\s*:');
    for (final file in _dartFiles('lib/features')) {
      if (!_normalizedPath(file).contains('/presentation/')) continue;
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(matches(nightFlagField)),
        reason: '${file.path} must read NightTheme from BuildContext',
      );
      expect(
        source,
        isNot(matches(nightFlagArgument)),
        reason: '${file.path} cannot pass night mode through widget props',
      );
    }
  });

  test('presentation never invokes repository providers directly', () {
    final repositoryCall = RegExp(
      r'ref\.(?:read|watch)\([^\n]*RepositoryProvider',
    );
    for (final file in _dartFiles('lib/features')) {
      if (!_normalizedPath(file).contains('/presentation/')) continue;
      expect(
        file.readAsStringSync(),
        isNot(matches(repositoryCall)),
        reason:
            '${file.path} must watch application state or invoke a controller',
      );
    }
  });

  test('shared UI never imports a feature data implementation', () {
    for (final file in _dartFiles('lib/ui')) {
      expect(
        file.readAsStringSync(),
        isNot(contains('/data/')),
        reason: '${file.path} must depend on application or domain APIs',
      );
    }
  });

  test('app providers is a composition root, not a feature-provider barrel',
      () {
    final source = File('lib/app/providers.dart').readAsStringSync();
    expect(source, isNot(contains('presentation/providers')));
    expect(source, isNot(contains('export ')));
  });

  test('fragment has one entity and application controllers', () {
    final source = Directory('lib/features/fragment')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(source, isNot(contains('LightFragmentModel')));
    for (final path in [
      'lib/features/fragment/application/capture_controller.dart',
      'lib/features/fragment/application/fragment_detail_controller.dart',
      'lib/features/fragment/application/fragment_list_controller.dart',
      'lib/features/fragment/data/fragment_repository_impl.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path is required');
    }
  });

  test('oversized pages must declare their extraction plan', () {
    for (final file in _dartFiles('lib/features')) {
      if (!file.path.contains('/presentation/pages/')) continue;
      final source = file.readAsStringSync();
      final lineCount = '\n'.allMatches(source).length + 1;
      if (lineCount <= 300) continue;
      expect(
        source,
        contains('PAGE_SIZE_EXEMPT:'),
        reason: '${file.path} has $lineCount lines without an extraction plan',
      );
    }
  });

  test('raw colors are confined to the color token catalog', () {
    for (final file in _dartFiles('lib')) {
      if (_normalizedPath(file).endsWith('/design/tokens/colors.dart')) {
        continue;
      }
      expect(
        file.readAsStringSync(),
        isNot(matches(RegExp(r'Color\(0x[0-9A-Fa-f]+\)'))),
        reason: '${file.path} must use AppColors or theme semantic colors',
      );
    }
  });

  test('raw durations are confined to the timing token catalog', () {
    for (final file in _dartFiles('lib')) {
      if (_normalizedPath(file).endsWith('/design/tokens/motion.dart')) {
        continue;
      }
      expect(
        file.readAsStringSync(),
        isNot(contains('Duration(')),
        reason: '${file.path} must use AppMotion or AppTiming',
      );
    }
  });

  test('EdgeInsets never contains a naked non-zero numeric literal', () {
    final edgeInsets = RegExp(
      r'EdgeInsets\.(?:all|only|symmetric|fromLTRB)\((.*?)\)',
      dotAll: true,
    );
    final nakedNumber = RegExp(r'(?<![A-Za-z0-9_.])[1-9][0-9]*(?:\.[0-9]+)?');
    for (final file in _dartFiles('lib')) {
      final source = file.readAsStringSync();
      for (final match in edgeInsets.allMatches(source)) {
        final arguments = match.group(1)!;
        expect(
          arguments,
          isNot(matches(nakedNumber)),
          reason: '${file.path} must use AppSpacing inside EdgeInsets',
        );
      }
    }
  });

  test('the fixed Xiguang component system is complete and theme-driven', () {
    for (final component in [
      'page',
      'card',
      'section',
      'button',
      'input',
      'chip',
      'bottom_sheet',
      'empty_state',
    ]) {
      final file = File('lib/ui/composites/xiguang_$component.dart');
      expect(file.existsSync(), isTrue, reason: '$component component missing');
      expect(
        file.readAsStringSync(),
        isNot(contains('nightMode')),
        reason: '${file.path} must read semantic colors from Theme',
      );
    }
  });
}

Iterable<File> _dartFiles(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

String _normalizedPath(File file) => file.path.replaceAll('\\', '/');
