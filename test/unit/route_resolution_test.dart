import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the class of bug where the app navigates to a route name that the
/// route table does not define.
///
/// `Navigator.pushNamed` to an unknown name throws inside the navigation
/// machinery; before `onUnknownRoute` existed that surfaced as a crash or a
/// dead tap. The global search screen was the worst offender: most of its
/// catalog pointed at routes (`/contributions`, `/transfer`, `/loan-repayments`
/// and others) that were never registered, so a search result either crashed or
/// silently did nothing.
///
/// This test reads the real `main.dart` route table and the real call sites —
/// there is nothing to mock — and fails if any literal route is missing.
void main() {
  // Any route name may contain letters, digits, dashes and slashes.
  final definedRoute = RegExp(r"'(\/[A-Za-z0-9_\/-]+)'\s*:");
  final namedPush = RegExp(r"push(?:Replacement)?Named\(\s*'(\/[A-Za-z0-9_\/-]+)'");
  final searchRoute = RegExp(r"route:\s*'(\/[A-Za-z0-9_\/-]+)'");

  late Set<String> defined;

  setUpAll(() {
    final mainSource = File('lib/main.dart').readAsStringSync();
    defined = definedRoute
        .allMatches(mainSource)
        .map((m) => m.group(1)!)
        .toSet();
  });

  /// Strip `//` comments so a commented-out call does not count as a call.
  String stripComments(String line) {
    final idx = line.indexOf('//');
    return idx == -1 ? line : line.substring(0, idx);
  }

  test('the route table defines the routes the app is known to need', () {
    // A canary: if route extraction silently returns nothing, the checks below
    // would pass vacuously. These are load-bearing routes.
    expect(defined, containsAll(['/home', '/login', '/wallet', '/contributions']));
  });

  test('every literal pushNamed target is a defined route', () {
    final missing = <String, String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (final raw in lines) {
        final line = stripComments(raw);
        for (final match in namedPush.allMatches(line)) {
          final route = match.group(1)!;
          if (!defined.contains(route)) {
            missing[route] = entity.path;
          }
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'These routes are pushed by name but not defined in main.dart: '
          '$missing',
    );
  });

  test('every global-search result points at a defined route', () {
    final source =
        File('lib/presentation/screens/search/global_search_screen.dart')
            .readAsStringSync();

    final routes = searchRoute.allMatches(source).map((m) => m.group(1)!).toSet();

    expect(routes, isNotEmpty, reason: 'no search routes were extracted');
    expect(
      routes.difference(defined),
      isEmpty,
      reason: 'search results point at routes that are not defined in main.dart',
    );
  });
}
