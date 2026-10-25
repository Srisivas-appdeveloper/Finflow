import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Central error handling.
///
/// FinFlow sends no data off the device, so errors are not uploaded to a
/// crash service. They are logged in debug builds and kept in a small
/// in-memory ring buffer that a future "send feedback" screen can show the
/// user before they choose to share it.
abstract final class ErrorReporting {
  static const _capacity = 20;
  static final _recent = ListQueue<String>();

  /// The most recent errors, newest last.
  static List<String> get recent => List.unmodifiable(_recent);

  static void install() {
    FlutterError.onError = (details) {
      record(details.exception, details.stack);
      if (kDebugMode) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      // Handled: keep the app running rather than crashing on an async
      // error that escaped a feature.
      return true;
    };
    if (kReleaseMode) {
      // Instead of the red error screen, a broken widget shows a calm
      // placeholder and the rest of the screen keeps working.
      ErrorWidget.builder = (details) => const _BrokenWidgetPlaceholder();
    }
  }

  static void record(Object error, StackTrace? stack, {bool fatal = false}) {
    final entry =
        '${DateTime.now().toIso8601String()} ${fatal ? 'FATAL ' : ''}'
        '$error\n${stack ?? ''}';
    _recent.addLast(entry);
    while (_recent.length > _capacity) {
      _recent.removeFirst();
    }
    if (kDebugMode) debugPrint(entry);
  }
}

class _BrokenWidgetPlaceholder extends StatelessWidget {
  const _BrokenWidgetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Icon(Icons.error_outline_rounded, color: Color(0xFF8A90B6)),
      ),
    );
  }
}
