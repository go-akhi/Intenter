import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';

class IntentPromptScreen extends StatefulWidget {
  const IntentPromptScreen({super.key});

  @override
  State<IntentPromptScreen> createState() => _IntentPromptScreenState();
}

class _IntentPromptScreenState extends State<IntentPromptScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _canSubmit = false;
  // static const platform = MethodChannel('com.example.intenter/launch_context');

  @override
  void initState() {
    super.initState();
    // _startLock();
    _controller.addListener(() {
      setState(() {
        _canSubmit = _controller.text.trim().isNotEmpty;
      });
    });
  }

  // Future<void> _startLock() async {
  //   try {
  //     await platform.invokeMethod('startLockTask');
  //   } on PlatformException catch (e) {
  //     debugPrint("Failed to start lock task: '${e.message}'.");
  //   }
  // }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitIntent() async {
    if (!_canSubmit) return;

    final intent = _controller.text.trim();
    final startTime = DateTime.now().millisecondsSinceEpoch;

    // Save session start
    await _dbHelper.insertSession(intent, startTime);

    // Minimize app / Go to Home
    // This effectively "starts" the session by letting the user into the phone
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents back button
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '> What do you need your phone for?',
                style: GoogleFonts.firaCode(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                autofocus: true,
                style: GoogleFonts.firaCode(
                  color: Colors.greenAccent,
                  fontSize: 20,
                ),
                cursorColor: Colors.greenAccent,
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: GoogleFonts.firaCode(
                    color: Colors.greenAccent,
                    fontSize: 20,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.greenAccent),
                  ),
                ),
                onSubmitted: (_) => _submitIntent(),
              ),
              const SizedBox(height: 48),
              if (_canSubmit)
                Center(
                  child: OutlinedButton(
                    onPressed: _submitIntent,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape:
                          const RoundedRectangleBorder(), // Rectangular border
                    ),
                    child: Text(
                      'GO',
                      style: GoogleFonts.firaCode(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
