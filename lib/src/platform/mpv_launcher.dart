import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class mpvLauncher {
  /// Returns the name of the preferred media player for the current platform.
  static String get playerName {
    if (kIsWeb) return 'پلیر';
    if (Platform.isMacOS) return 'Samavar Lite';
    if (Platform.isWindows) return 'PotPlayer';
    return 'mpv';
  }

  /// Button label in Persian for launching the media player.
  static String get playButtonText => 'پخش با $playerName';

  /// Error message in Persian if the player cannot be launched.
  static String get playErrorMessage => 'نمی‌توان لینک را در $playerName باز کرد';

  /// Launches the given media [url] in the platform's preferred media player.
  /// - macOS: /Applications/Samavar Lite.app (with mpv and system fallback)
  /// - Windows: PotPlayer (with mpv and system fallback)
  /// - Linux: Samavar Lite or mpv (with system fallback)
  static Future<bool> launchPlayer(String url) async {
    try {
      if (kIsWeb) {
        final Uri uri = Uri.parse(url);
        return await launchUrl(uri);
      } else if (Platform.isMacOS) {
        return await _launchOnMacOS(url);
      } else if (Platform.isWindows) {
        return await _launchOnWindows(url);
      } else if (Platform.isLinux) {
        return await _launchOnLinux(url);
      } else {
        final Uri uri = Uri.parse(url);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching media player: $e');
      return false;
    }
  }

  /// Backward-compatible alias for [launchPlayer].
  static Future<bool> launchInmpv(String url) => launchPlayer(url);

  static Future<bool> _launchOnMacOS(String url) async {
    try {
      const samavarAppPath = '/Applications/Samavar Lite.app';
      final samavarExists = await Directory(samavarAppPath).exists();

      if (samavarExists) {
        // 1. Launch with open -a (LaunchServices passes the URL to the app via QFileOpenEvent or IPC)
        final openResult = await Process.run('open', [
          '-a',
          samavarAppPath,
          url,
        ]);
        if (openResult.exitCode == 0) return true;

        // 2. Try with --args (passes URL directly to argv)
        final argsResult = await Process.run('open', [
          '-a',
          samavarAppPath,
          '--args',
          url,
        ]);
        if (argsResult.exitCode == 0) return true;

        // 3. Fallback with -n (new instance forwarding)
        final newResult = await Process.run('open', [
          '-n',
          '-a',
          samavarAppPath,
          '--args',
          url,
        ]);
        if (newResult.exitCode == 0) return true;

        // 4. Fallback directly executing the binary detached
        const binPath = '$samavarAppPath/Contents/MacOS/Samavar Lite';
        if (await File(binPath).exists()) {
          try {
            await Process.start(
              binPath,
              [url],
              mode: ProcessStartMode.detached,
            );
            return true;
          } catch (_) {}
        }
      }

      // Check if Samavar Lite is registered under application name in LaunchServices
      final appNameResult = await Process.run('open', [
        '-a',
        'Samavar Lite',
        url,
      ]);
      if (appNameResult.exitCode == 0) return true;

      // Fallback: check if mpv is installed on macOS
      final mpvResult = await Process.run('open', ['-a', 'mpv', url]);
      if (mpvResult.exitCode == 0) return true;

      // Fallback to default external application
      final Uri uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching media player on macOS: $e');
      return false;
    }
  }

  static Future<bool> _launchOnWindows(String url) async {
    try {
      final List<String> candidatePaths = [];

      final programFiles = Platform.environment['ProgramFiles'];
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
      final programW6432 = Platform.environment['ProgramW6432'];
      final localAppData = Platform.environment['LOCALAPPDATA'];

      final baseDirs = <String>{
        if (programFiles != null && programFiles.isNotEmpty) programFiles,
        if (programFilesX86 != null && programFilesX86.isNotEmpty)
          programFilesX86,
        if (programW6432 != null && programW6432.isNotEmpty) programW6432,
        'C:\\Program Files',
        'C:\\Program Files (x86)',
      };

      for (final dir in baseDirs) {
        candidatePaths.add('$dir\\DAUM\\PotPlayer\\PotPlayer64.exe');
        candidatePaths.add('$dir\\DAUM\\PotPlayer\\PotPlayer.exe');
        candidatePaths.add('$dir\\PotPlayer\\PotPlayer64.exe');
        candidatePaths.add('$dir\\PotPlayer\\PotPlayer.exe');
      }

      if (localAppData != null && localAppData.isNotEmpty) {
        candidatePaths.add('$localAppData\\DAUM\\PotPlayer\\PotPlayer64.exe');
        candidatePaths.add('$localAppData\\DAUM\\PotPlayer\\PotPlayer.exe');
        candidatePaths.add('$localAppData\\PotPlayer\\PotPlayer64.exe');
        candidatePaths.add('$localAppData\\Programs\\PotPlayer\\PotPlayer64.exe');
      }

      // 1. Try launching from explicit candidate paths
      for (final path in candidatePaths) {
        final File exeFile = File(path);
        if (await exeFile.exists()) {
          try {
            await Process.start(
              path,
              [url],
              mode: ProcessStartMode.detached,
            );
            return true;
          } catch (e) {
            debugPrint('Failed to start PotPlayer at $path: $e');
          }
        }
      }

      // 2. Try finding PotPlayer in system PATH via `where`
      for (final exeName in [
        'PotPlayer64.exe',
        'PotPlayer.exe',
        'potplayer.exe',
      ]) {
        try {
          final whichResult = await Process.run('where', [exeName]);
          if (whichResult.exitCode == 0) {
            final output = (whichResult.stdout as String).trim();
            if (output.isNotEmpty) {
              final exePath = output.split(RegExp(r'[\r\n]+')).first.trim();
              if (exePath.isNotEmpty && await File(exePath).exists()) {
                await Process.start(
                  exePath,
                  [url],
                  mode: ProcessStartMode.detached,
                );
                return true;
              }
            }
          }
        } catch (_) {}
      }

      // 3. Try PotPlayer custom URL protocol (potplayer://)
      try {
        final potUri = Uri.tryParse('potplayer://$url');
        if (potUri != null && await canLaunchUrl(potUri)) {
          final launched = await launchUrl(potUri);
          if (launched) return true;
        }
      } catch (_) {}

      // 4. Try cmd start with potplayer://
      try {
        final result = await Process.run('cmd', [
          '/c',
          'start',
          '',
          'potplayer://$url',
        ]);
        if (result.exitCode == 0) return true;
      } catch (_) {}

      // 5. Fallback to mpv on Windows if PotPlayer is not found
      final mpvPaths = <String>[
        for (final dir in baseDirs) '$dir\\VideoLAN\\mpv\\mpv.exe',
      ];
      for (final path in mpvPaths) {
        final File mpvExecutable = File(path);
        if (await mpvExecutable.exists()) {
          try {
            await Process.start(
              path,
              [url],
              mode: ProcessStartMode.detached,
            );
            return true;
          } catch (_) {}
        }
      }

      // 6. Final fallback: default external application
      final Uri uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching player on Windows: $e');
      return false;
    }
  }

  static Future<bool> _launchOnLinux(String url) async {
    try {
      // 1. Try samavar-lite if installed
      try {
        final whichSamavar = await Process.run('which', ['samavar-lite']);
        if (whichSamavar.exitCode == 0 &&
            (whichSamavar.stdout as String).trim().isNotEmpty) {
          await Process.start(
            'samavar-lite',
            [url],
            mode: ProcessStartMode.detached,
          );
          return true;
        }
      } catch (_) {}

      // 2. Try mpv in PATH
      try {
        final whichResult = await Process.run('which', ['mpv']);
        if (whichResult.exitCode == 0 &&
            (whichResult.stdout as String).trim().isNotEmpty) {
          await Process.start(
            'mpv',
            [url],
            mode: ProcessStartMode.detached,
          );
          return true;
        }
      } catch (_) {}

      // 3. Try standard mpv path
      const mpvPath = '/usr/bin/mpv';
      final File mpvExecutable = File(mpvPath);
      if (await mpvExecutable.exists()) {
        await Process.start(
          mpvPath,
          [url],
          mode: ProcessStartMode.detached,
        );
        return true;
      }

      // 4. Fallback to default external application
      final Uri uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching media player on Linux: $e');
      return false;
    }
  }
}

/// Type alias so code can use either [MediaPlayerLauncher] or [mpvLauncher].
typedef MediaPlayerLauncher = mpvLauncher;

