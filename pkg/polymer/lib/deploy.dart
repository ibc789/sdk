// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * **Note**: If you already have a `build.dart` in your application, we
 * recommend to use the `package:polymer/builder.dart` library instead.

 * Temporary deploy command used to create a version of the app that can be
 * compiled with dart2js and deployed. Following pub layout conventions, this
 * script will treat any HTML file under a package 'web/' and 'test/'
 * directories as entry points.
 *
 * From an application package you can run deploy by creating a small program
 * as follows:
 *
 *    import "package:polymer/deploy.dart" as deploy;
 *    main() => deploy.main();
 *
 * This library should go away once `pub deploy` can be configured to run
 * barback transformers.
 */
library polymer.deploy;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:polymer/src/barback_runner.dart';
import 'package:polymer/src/transform.dart';

main() {
  var args = _parseArgs(new Options().arguments);
  if (args == null) exit(1);

  var test = args['test'];
  var outDir = args['out'];
  var options = (test == null)
    ? new BarbackOptions(createDeployPhases(new TransformOptions()), outDir)
    : _createTestOptions(test, outDir);
  if (options == null) exit(1);

  print('polymer/deploy.dart: creating a deploy target for '
      '"${options.currentPackage}"');

  runBarback(options)
      .then((_) => print('Done! All files written to "$outDir"'))
      .catchError(_reportErrorAndExit);
}

BarbackOptions _createTestOptions(String testFile, String outDir) {
  var testDir = path.normalize(path.dirname(testFile));

  // A test must be allowed to import things in the package.
  // So we must find its package root, given the entry point. We can do this
  // by walking up to find pubspec.yaml.
  var pubspecDir = _findDirWithFile(path.absolute(testDir), 'pubspec.yaml');
  if (pubspecDir == null) {
    print('error: pubspec.yaml file not found, please run this script from '
        'your package root directory or a subdirectory.');
    return null;
  }

  var phases = createDeployPhases(new TransformOptions(
        '_test', [path.relative(testFile, from: pubspecDir)]));
  return new BarbackOptions(phases, outDir,
      currentPackage: '_test',
      packageDirs: {'_test' : pubspecDir},
      transformTests: true);
}

String _findDirWithFile(String dir, String filename) {
  while (!new File(path.join(dir, filename)).existsSync()) {
    var parentDir = path.dirname(dir);
    // If we reached root and failed to find it, bail.
    if (parentDir == dir) return null;
    dir = parentDir;
  }
  return dir;
}

void _reportErrorAndExit(e) {
  var trace = getAttachedStackTrace(e);
  print('Uncaught error: $e');
  if (trace != null) print(trace);
  exit(1);
}

ArgResults _parseArgs(arguments) {
  var parser = new ArgParser()
      ..addFlag('help', abbr: 'h', help: 'Displays this help message.',
          defaultsTo: false, negatable: false)
      ..addOption('out', abbr: 'o', help: 'Directory to generate files into.',
          defaultsTo: 'out')
      ..addOption('test', help: 'Deploy the test at the given path.\n'
          'Note: currently this will deploy all tests in its directory,\n'
          'but it will eventually deploy only the specified test.');
  try {
    var results = parser.parse(arguments);
    if (results['help']) {
      _showUsage(parser);
      return null;
    }
    return results;
  } on FormatException catch (e) {
    print(e.message);
    _showUsage(parser);
    return null;
  }
}

_showUsage(parser) {
  print('Usage: dart --package-root=packages/ '
      'package:polymer/deploy.dart [options]');
  print(parser.getUsage());
}
