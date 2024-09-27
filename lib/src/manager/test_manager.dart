#!/usr/bin/env dart

import 'dart:io' as io;

import 'package:adapters_flutter/src/enum/outcome_enum.dart';
import 'package:adapters_flutter/src/manager/api_manager_.dart';
import 'package:adapters_flutter/src/manager/config_manager.dart';
import 'package:adapters_flutter/src/manager/log_manager.dart';
import 'package:adapters_flutter/src/model/api/link_api_model.dart';
import 'package:adapters_flutter/src/model/test_result_model.dart';
import 'package:adapters_flutter/src/patrol/constants.dart' as constants;
import 'package:adapters_flutter/src/patrol/global_state.dart' as global_state;
import 'package:adapters_flutter/src/service/config/file_config_service.dart';
import 'package:adapters_flutter/src/service/validation_service.dart';
import 'package:adapters_flutter/src/storage/test_result_storage.dart';
import 'package:adapters_flutter/src/util/platform_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:patrol/patrol.dart';
import 'package:patrol_finders/patrol_finders.dart' as finders;
import 'package:patrol_finders/patrol_finders.dart';
import 'package:synchronized/synchronized.dart';
import 'package:test_api/src/backend/invoker.dart'; // ignore: depend_on_referenced_packages, implementation_imports
import 'package:universal_io/io.dart';

final Lock _lock = Lock();
final Logger _logger = getLogger();

bool _isWarningsLogged = false;

/// Run flutter test [body] with [description] and, optional, [externalId], [links], [onPlatform], [retry], [skip], [tags], [testOn], [timeout], [title] or [workItemsIds], then upload result to Test IT.
void tmsTest(final String description, final dynamic Function() body,
        {final String? externalId,
        final Set<Link>? links,
        final Map<String, dynamic>? onPlatform,
        final int? retry,
        final String? skip,
        final Set<String>? tags,
        final String? testOn,
        final Timeout? timeout,
        final String? title,
        final Set<String>? workItemsIds}) =>
    test(
        description,
        onPlatform: onPlatform,
        retry: retry,
        tags: tags,
        testOn: testOn,
        timeout: timeout,
        () async => await _testAsync(description, () async => await body.call(),
            externalId: externalId,
            links: links,
            skip: skip,
            tags: tags,
            title: title,
            workItemsIds: workItemsIds));

/// Run flutter testWidgets [callback] with [description] and, optional, [externalId], [links], [semanticsEnabled], [skip], [tags], [timeout], [title], [variant] or [workItemsIds], then upload result to Test IT.
Future<void> tmsTestWidgets(
        final String description, final WidgetTesterCallback callback,
        {final String? externalId,
        final Set<Link>? links,
        final bool semanticsEnabled = true,
        final String? skip,
        final Set<String>? tags,
        final Timeout? timeout,
        final String? title,
        final TestVariant<Object?> variant = const DefaultTestVariant(),
        final Set<String>? workItemsIds}) async =>
    testWidgets(
        description,
        semanticsEnabled: semanticsEnabled,
        skip: skip?.isNotEmpty,
        tags: tags,
        timeout: timeout,
        variant: variant,
        (tester) async => await tester.runAsync(() async => await _testAsync(
            description, () async => await callback(tester),
            externalId: externalId,
            links: links,
            skip: skip,
            tags: tags,
            title: title,
            workItemsIds: workItemsIds)));

Future<void> tmsPatrolTest(
  final String description,
  final PatrolTesterCallback callback, {
  final String? externalId,
  final Set<Link>? links,
  final String? title,
  final Set<String>? workItemsIds,

  /// Common test parameters
  bool semanticsEnabled = true,
  String? skip,
  Set<String>? tags,
  Timeout? timeout,
  TestVariant<Object?> variant = const DefaultTestVariant(),

  /// Patrol-specific configuration
  finders.PatrolTesterConfig config = const finders.PatrolTesterConfig(),
  NativeAutomatorConfig nativeAutomatorConfig = const NativeAutomatorConfig(),
  LiveTestWidgetsFlutterBindingFramePolicy framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fadePointers,
}) {
  final automator = NativeAutomator(config: nativeAutomatorConfig);
  final automator2 = NativeAutomator2(config: nativeAutomatorConfig);
  final patrolBinding = PatrolBinding.ensureInitialized(nativeAutomatorConfig)
    ..framePolicy = framePolicy;
  return tmsTestWidgets(
    description,
    (widgetTester) async {
      if (!constants.hotRestartEnabled) {
        // If Patrol's native automation feature is enabled, then this test will
        // be executed only if the native side requested it to be executed.
        // Otherwise, it returns early.

        final requestedToExecute = await patrolBinding.patrolAppService
            .waitForExecutionRequest(global_state.currentTestFullName);

        if (!requestedToExecute) {
          return;
        }
      }
      if (io.Platform.isIOS) {
        widgetTester.binding.platformDispatcher.onSemanticsEnabledChanged = () {
          // This callback is empty on purpose. It's a workaround for tests
          // failing on iOS.
          //
          // See https://github.com/leancodepl/patrol/issues/1474
        };
      }
      await automator.configure();
      // We don't have to call this line because automator.configure() does the same.
      // await automator2.configure();

      final patrolTester = PatrolIntegrationTester(
        tester: widgetTester,
        nativeAutomator: automator,
        nativeAutomator2: automator2,
        config: config,
      );
      await callback(patrolTester);

      // ignore: prefer_const_declarations
      final waitSeconds = const int.fromEnvironment('PATROL_WAIT');
      final waitDuration = Duration(seconds: waitSeconds);

      if (debugDefaultTargetPlatformOverride !=
          patrolBinding.workaroundDebugDefaultTargetPlatformOverride) {
        debugDefaultTargetPlatformOverride =
            patrolBinding.workaroundDebugDefaultTargetPlatformOverride;
      }

      if (waitDuration > Duration.zero) {
        final stopwatch = Stopwatch()..start();
        await Future.doWhile(() async {
          await widgetTester.pump();
          if (stopwatch.elapsed > waitDuration) {
            stopwatch.stop();
            return false;
          }

          return true;
        });
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    externalId: externalId,
    title: title,
    workItemsIds: workItemsIds,
    links: links,
  );
}

Future<void> tmsPatrolWidgetTest(
  final String description,
  final PatrolWidgetTestCallback callback, {
  final String? externalId,
  final Set<Link>? links,
  final String? title,
  final Set<String>? workItemsIds,

  /// Common test parameters
  bool semanticsEnabled = true,
  String? skip,
  Set<String>? tags,
  Timeout? timeout,
  TestVariant<Object?> variant = const DefaultTestVariant(),

  /// Patrol-specific configuration
  PatrolTesterConfig config = const PatrolTesterConfig(),
}) =>
    tmsTestWidgets(
      description,
      (widgetTester) => callback(
        PatrolTester(
          tester: widgetTester,
          config: config,
        ),
      ),
      skip: skip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: variant,
      tags: tags,
      externalId: externalId,
      title: title,
      workItemsIds: workItemsIds,
      links: links,
    );

String? _getSafeExternalId(final String? externalId, final String? testName) {
  var output =
      (externalId == null || externalId.isEmpty) ? testName : externalId;

  if (output == null || output.isEmpty) {
    return output;
  }

  final buffer = StringBuffer();
  final expression = RegExp(r'^[a-zA-Z0-9]+$');

  for (final rune in output.runes) {
    final char = String.fromCharCode(rune);

    if (expression.hasMatch(char)) {
      buffer.write(char);
    }
  }

  output = buffer.toString().toLowerCase();

  return output;
}

String? _getGroupName() {
  final liveTest = Invoker.current?.liveTest;

  var className = liveTest?.groups
          .where((final group) => group.name.isNotEmpty)
          .lastOrNull
          ?.name ??
      liveTest?.suite.group.name;

  if (className?.isEmpty ?? false) {
    className = null;
  }

  return className;
}

Future<void> _testAsync(
    final String description, final Future<void> Function() body,
    {final String? externalId,
    final Set<Link>? links,
    final String? skip,
    final Set<String>? tags,
    final String? title,
    final Set<String>? workItemsIds}) async {
  HttpOverrides.global = null;
  final config = await createConfigOnceAsync();
  await _tryLogWarningsOnceAsync();

  if (config.testIt ?? true) {
    final liveTest = Invoker.current?.liveTest;
    final safeExternalId = _getSafeExternalId(externalId, liveTest?.test.name);

    if (!await isTestNeedsToBeRunAsync(config, safeExternalId)) {
      await tryCompleteTestRunAsync(config);
      await excludeTestIdFromProcessingAsync();

      return;
    }

    validateStringArgument('Description', description);
    links?.forEach((final link) => validateUriArgument('Link url', link.url));
    tags?.forEach((final tag) => validateStringArgument('Tag', tag));
    await validateWorkItemsIdsAsync(config, workItemsIds);

    await tryCreateTestRunOnceAsync(config);
    await createEmptyTestResultAsync();

    final localResult = TestResultModel();
    final startedOn = DateTime.now();

    localResult.classname = _getGroupName();
    localResult.description = description;
    localResult.externalId = safeExternalId;
    localResult.labels = liveTest?.test.metadata.tags ?? {};
    localResult.links = links ?? {};
    localResult.methodName = liveTest?.test.name ?? '';
    localResult.name = (liveTest?.test.name ?? '')
        .replaceAll(_getGroupName() ?? '', '')
        .trim();
    localResult.namespace =
        basenameWithoutExtension(liveTest?.suite.path ?? 'test_tms');
    localResult.startedOn = startedOn;
    localResult.title = title ?? liveTest?.test.name ?? '';
    localResult.workItemIds = workItemsIds ?? {};

    Exception? exception;
    StackTrace? stacktrace;

    try {
      if (skip != null && skip.isNotEmpty) {
        localResult.message = skip;
        localResult.outcome = Outcome.skipped;
      } else {
        await body.call();
        localResult.outcome = Outcome.passed;
      }
    } on Exception catch (e, s) {
      localResult.message = e.toString();
      localResult.outcome = Outcome.failed;
      localResult.traces = s.toString();

      exception = e;
      stacktrace = s;
    } finally {
      final completedOn = DateTime.now();
      localResult.completedOn = completedOn;
      localResult.duration = completedOn.difference(startedOn).inMilliseconds;

      await updateTestResultAsync(localResult);
      final testId = getTestIdForProcessing();

      if (testId != null) {
        await addSetupAllsToTestResultAsync(testId);
        await addTeardownAllsToTestResultAsync(testId);
        final testResult = await removeTestResultByTestIdAsync(testId);
        await processTestResultAsync(config, testResult);
      }
    }

    if (exception != null) {
      _logger.e('$exception$lineSeparator$stacktrace.');
      throw exception;
    }
  } else {
    await body.call();
  }
}

Future<void> _tryLogWarningsOnceAsync() async {
  await _lock.synchronized(() async {
    if (!_isWarningsLogged) {
      for (final warning in getConfigFileWarnings()) {
        _logger.w(warning);
      }

      _isWarningsLogged = true;
    }
  });
}
