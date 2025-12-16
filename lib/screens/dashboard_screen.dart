import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final rawSessions = await _dbHelper.getSessions();
    List<Map<String, dynamic>> sessionsWithUsage = [];

    for (var session in rawSessions) {
      final Map<String, dynamic> sessionMap = Map.from(session);
      // Fetch usage for this session
      final int sessionId = session['id'] as int;
      final usage = await _dbHelper.getAppUsage(sessionId);
      sessionMap['usage'] = usage;
      sessionsWithUsage.add(sessionMap);
    }
    setState(() {
      _sessions = sessionsWithUsage;
      _isLoading = false;
    });
  }

  String _formatDuration(int? durationMs) {
    if (durationMs == null) return "Ongoing / Unknown";
    final Duration duration = Duration(milliseconds: durationMs);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    return "${duration.inHours}h ${twoDigitMinutes}m";
  }

  String _formatUsageDuration(int durationMs) {
    if (durationMs < 1000) return "< 1s";
    final Duration duration = Duration(milliseconds: durationMs);
    if (duration.inMinutes < 1) return "${duration.inSeconds}s";
    return "${duration.inMinutes}m ${(duration.inSeconds % 60)}s";
  }

  String _cleanPackageName(String packageName) {
    // Determine a readable name from package name if possible, else return last segment
    // simple heuristic: last part of package
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      String name = parts.last;
      // capitalize
      if (name.isNotEmpty) {
        return "${name[0].toUpperCase()}${name.substring(1)}";
      }
      return name;
    }
    return packageName;
  }

  String _formatDate(int timestamp) {
    return DateFormat(
      'MMM d, h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Future<void> _exportData() async {
    // Show loading indicator usually, but strictly we can just do async work
    // Since we are setting isLoading in build, let's wrap logic
    // But setting _isLoading = true replaces body with spinner, which is fine
    setState(() {
      _isLoading = true;
    });

    try {
      final String jsonString = await _dbHelper.getAllDataAsJson();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/intenter_data.json');
      await file.writeAsString(jsonString);

      // Check if mounted before using context or sharing?
      // Share plugin handles context internally or platform channel.
      if (!mounted) return;

      // Share.shareXFiles is the modern way
      await Share.shareXFiles([XFile(file.path)], text: 'Intenter Data Export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Export failed: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intenter Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export JSON',
            onPressed: _exportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? const Center(child: Text("No sessions logged yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final List<Map<String, dynamic>> usage =
                    session['usage'] as List<Map<String, dynamic>>? ?? [];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session['intent'] ?? 'No Intent',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDuration(session['duration']),
                              style: GoogleFonts.firaCode(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(session['start_time']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (usage.isNotEmpty) ...[
                          const Divider(),
                          const Text(
                            "Apps Used:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: usage.map((u) {
                              return Chip(
                                label: Text(
                                  "${_cleanPackageName(u['package_name'])} (${_formatUsageDuration(u['total_time_visible'])})",
                                  style: const TextStyle(fontSize: 10),
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ] else if (session['duration'] != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "No tracked app usage.",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
