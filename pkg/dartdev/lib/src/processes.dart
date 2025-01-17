// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

// TODO(devoncarew): Support windows.

/// A utility class to get information about the Dart related process running on
/// this machine.
class ProcessInfo {
  static final wsRegex = RegExp(r'\s+');

  final int memoryMb;
  final double cpuPercent;
  final String elapsedTime;
  final String command;
  final String commandLine;

  static ProcessInfo _parseMacos(String line, {bool elideFilePaths = true}) {
    // "33712   0.0 01-19:07:19 launchd ..."
    line = line.replaceAll(wsRegex, ' ');

    String nextWord() {
      var index = line.indexOf(' ');
      var word = line.substring(0, index);
      line = line.substring(index + 1);
      return word;
    }

    var mb = nextWord();
    var cpu = nextWord();
    var elapsedTime = nextWord();
    var commandLine = line.trim();

    if (elideFilePaths) {
      return ProcessInfo._(
        command: _getCommandFrom(commandLine),
        memoryMb: int.parse(mb) ~/ 1024,
        cpuPercent: double.parse(cpu),
        elapsedTime: elapsedTime,
        commandLine: _sanitizeCommandLine(commandLine, preferSnapshot: true),
      );
    } else {
      return ProcessInfo._(
        command: _getCommandFrom(commandLine),
        memoryMb: int.parse(mb) ~/ 1024,
        cpuPercent: double.parse(cpu),
        elapsedTime: elapsedTime,
        commandLine: commandLine,
      );
    }
  }

  static ProcessInfo? _parseLinux(String line, {bool elideFilePaths = true}) {
    // "33712   0.0 01-19:07:19 launchd ..."
    line = line.replaceAll(wsRegex, ' ');

    String nextWord() {
      var index = line.indexOf(' ');
      var word = line.substring(0, index);
      line = line.substring(index + 1);
      return word;
    }

    var mb = nextWord();
    var cpu = nextWord();
    var elapsedTime = nextWord();
    var commandLine = line.trim();

    if (commandLine.startsWith('[') && commandLine.endsWith(']')) {
      return null;
    }

    if (elideFilePaths) {
      return ProcessInfo._(
        command: _getCommandFrom(commandLine),
        memoryMb: int.parse(mb) ~/ 1024,
        cpuPercent: double.parse(cpu),
        elapsedTime: elapsedTime,
        commandLine: _sanitizeCommandLine(commandLine, preferSnapshot: true),
      );
    } else {
      return ProcessInfo._(
        command: _getCommandFrom(commandLine),
        memoryMb: int.parse(mb) ~/ 1024,
        cpuPercent: double.parse(cpu),
        elapsedTime: elapsedTime,
        commandLine: commandLine,
      );
    }
  }

  const ProcessInfo._({
    required this.memoryMb,
    required this.cpuPercent,
    required this.elapsedTime,
    required this.command,
    required this.commandLine,
  });

  /// Return the Dart related processes.
  ///
  /// This will try to exclude the process for the VM currently running
  /// 'dart bug'.
  ///
  /// This will return `null` if we don't support listing the process on the
  /// current platform.
  static List<ProcessInfo>? getProcessInfo({bool elideFilePaths = true}) {
    List<ProcessInfo>? processInfo;

    if (Platform.isMacOS) {
      processInfo = _getProcessInfoMacOS(elideFilePaths: elideFilePaths);
    } else if (Platform.isLinux) {
      processInfo = _getProcessInfoLinux(elideFilePaths: elideFilePaths);
    }

    if (processInfo != null) {
      // Remove the 'dart bug' entry.
      processInfo = processInfo
          .where((process) => process.commandLine != 'dart bug')
          .toList();

      // Sort.
      processInfo.sort((a, b) => a.commandLine.compareTo(b.commandLine));
    }

    return processInfo;
  }

  /// Return the given [commandLine] with path-like elements replaced with
  /// shorter placeholders.
  static String _sanitizeCommandLine(
    String commandLine, {
    bool preferSnapshot = true,
  }) {
    final sep = Platform.pathSeparator;

    var args = commandLine.split(' ');

    // If we're running 'dart foo.snapshot ...', and we're already adjusting
    // the command line, shorten the command line so it appears that the
    // snapshot is being run directly (some command lines can be very long
    // otherwise).
    var index = args.indexWhere((arg) => arg.endsWith('.snapshot'));
    if (index != -1) {
      args = args.skip(index).toList();
    }

    String sanitizeArg(String arg) {
      if (!arg.contains(sep)) return arg;

      int start = arg.indexOf(sep);
      int end = arg.lastIndexOf(sep);
      if (start == end) return arg;

      return '${arg.substring(0, start)}<path>${arg.substring(end)}';
    }

    return [
      args.first.split(sep).last,
      ...args.skip(1).map(sanitizeArg),
    ].join(' ');
  }

  @override
  String toString() =>
      'ProcessInfo(memoryMb: $memoryMb, cpuPercent: $cpuPercent, elapsedTime:'
      ' $elapsedTime, command: $command, commandLine: $commandLine)';
}

List<ProcessInfo> _getProcessInfoMacOS({bool elideFilePaths = true}) {
  var result = Process.runSync('ps', ['-eo', 'rss,pcpu,etime,args']);
  if (result.exitCode != 0) {
    return const [];
  }

  //    RSS  %CPU     ELAPSED ARGS
  //  33712   0.0 01-19:07:19 launchd
  //  52624   0.0 01-19:06:18 logd
  //   4848   0.0 01-19:06:18 smd

  var lines = (result.stdout as String).split('\n');
  return lines
      .skip(1)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) =>
          ProcessInfo._parseMacos(line, elideFilePaths: elideFilePaths))
      .where(_isProcessDartRelated)
      .toList();
}

List<ProcessInfo> _getProcessInfoLinux({bool elideFilePaths = true}) {
  var result = Process.runSync('ps', ['-eo', 'rss,pcpu,etime,args']);
  if (result.exitCode != 0) {
    return const [];
  }

  var lines = (result.stdout as String).split('\n');
  return lines
      .skip(1)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) =>
          ProcessInfo._parseLinux(line, elideFilePaths: elideFilePaths))
      .whereType<ProcessInfo>()
      .where(_isProcessDartRelated)
      .toList();
}

bool _isProcessDartRelated(ProcessInfo process) {
  return process.command == 'dart';
}

String _getCommandFrom(String commandLine) {
  var command = commandLine.split(' ').first;
  return command.split(Platform.pathSeparator).last;
}
