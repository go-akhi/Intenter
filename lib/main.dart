import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'database/database_helper.dart'; // Ensure DB is init
import 'screens/dashboard_screen.dart';
import 'screens/intent_prompt_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize DB early
  await DatabaseHelper().database;
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _hasPermissions = false;
  bool _isFromUnlock = false;
  bool _isLoading = true; // Added loading state
  static const platform = MethodChannel('com.example.intenter/launch_context');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  Future<void> _initApp() async {
    await _checkLaunchContext();
    await _checkPermissions();
    await _checkSessionEnd(); // Check if we need to close a session
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkLaunchContext() async {
    try {
      final bool result = await platform.invokeMethod('isFromUnlock');
      setState(() {
        _isFromUnlock = result;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get launch context: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _checkSessionEnd();
    }
  }

  Future<void> _checkSessionEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final int? lastLockTime = prefs.getInt('last_lock_timestamp');

    if (lastLockTime != null) {
      final db = DatabaseHelper();
      final openSessions = await db.returnOpenSessions();

      for (var session in openSessions) {
        int id = session['id'] as int;
        int startTime = session['start_time'] as int;

        if (lastLockTime > startTime) {
          try {
            // Check for Usage Stats Permission again just in case
            bool usageGranted =
                await UsageStats.checkUsagePermission() ?? false;
            if (usageGranted) {
              List<UsageInfo> usageStats = await UsageStats.queryUsageStats(
                DateTime.fromMillisecondsSinceEpoch(startTime),
                DateTime.fromMillisecondsSinceEpoch(lastLockTime),
              );

              for (var info in usageStats) {
                // Convert string duration (if any) or assume milliseconds?
                // The plugin usually returns totalTimeInForeground as string or int depending on version
                // Let's check the source or assume int/string.
                // UsageInfo from 'usage_stats' package: totalTimeInForeground is String?

                int totalTime = 0;
                if (info.totalTimeInForeground != null) {
                  try {
                    totalTime = int.parse(info.totalTimeInForeground!);
                  } catch (e) {
                    debugPrint("Error parsing time: $e");
                  }
                }

                if (totalTime > 0) {
                  await db.insertAppUsage(
                    id,
                    info.packageName ?? 'unknown',
                    totalTime,
                    int.tryParse(info.lastTimeUsed ?? '0') ?? 0,
                  );
                }
              }
            }
          } catch (e) {
            debugPrint("Error collecting stats: $e");
          }
        }
      }

      await db.closeOngoingSession(lastLockTime);
      await prefs.remove('last_lock_timestamp');
    }
  }

  Future<void> _checkPermissions() async {
    bool usageStats = await UsageStats.checkUsagePermission() ?? false;
    bool overlay = await Permission.systemAlertWindow.isGranted;

    if (usageStats && overlay) {
      if (!_hasPermissions) {
        setState(() {
          _hasPermissions = true;
        });
      }
    }
  }

  Future<void> _grantUsagePermission() async {
    await UsageStats.grantUsagePermission();
  }

  Future<void> _grantOverlayPermission() async {
    await Permission.systemAlertWindow.request();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // If we have permissions:
    // Check if launched from unlock -> Show Prompt
    // Otherwise -> Show Dashboard
    Widget homeWidget;
    if (_hasPermissions) {
      if (_isFromUnlock) {
        homeWidget = const IntentPromptScreen();
      } else {
        homeWidget = const DashboardScreen();
      }
    } else {
      homeWidget = Scaffold(
        appBar: AppBar(title: const Text("Setup Intenter")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Permissions Required"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _grantUsagePermission,
                child: const Text("Grant Usage Stats Permission"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _grantOverlayPermission,
                child: const Text("Grant Overlay Permission"),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Overlay permission is needed to show the prompt when you unlock your phone.",
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: homeWidget,
      routes: {
        '/prompt': (context) => const IntentPromptScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
