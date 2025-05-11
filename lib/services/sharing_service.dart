import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymgee/models/workout_set.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_share_me/flutter_share_me.dart';
import 'dart:convert';

import 'package:gymgee/models/workout.dart';
import 'package:gymgee/models/exercise.dart';

class SharingService {
  final FlutterShareMe _flutterShareMe = FlutterShareMe();

  // Generate a weekly report
  Future<String> generateWeeklyReport(List<Workout> workouts, DateTime startDate) {
    final endDate = startDate.add(Duration(days: 7));

    // Create a buffer for the report text
    final StringBuffer report = StringBuffer();

    // Add report header
    report.writeln('🏋️‍♂️ Weekly Workout Report 🏋️‍♂️');
    report.writeln('${_formatDate(startDate)} - ${_formatDate(endDate)}\n');

    // Add workout summary
    final completedWorkouts = workouts
        .where((w) => w.lastPerformed != null &&
        w.lastPerformed!.isAfter(startDate) &&
        w.lastPerformed!.isBefore(endDate))
        .toList();

    report.writeln('Workouts Completed: ${completedWorkouts.length}');

    if (completedWorkouts.isEmpty) {
      report.writeln('\nNo workouts completed this week.');
    } else {
      // Calculate total workout time
      final totalDuration = completedWorkouts.fold<Duration>(
          Duration.zero,
              (sum, workout) => sum + (workout.calculateTotalWorkoutTime())
      );

      report.writeln('Total Workout Time: ${_formatDuration(totalDuration)}');

      // Calculate total volume (for weight exercises)
      final totalVolume = completedWorkouts.fold<double>(
          0,
              (sum, workout) => sum + workout.calculateTotalVolume()
      );

      report.writeln('Total Volume Lifted: ${totalVolume.toStringAsFixed(1)} kg');

      // Add individual workout details
      report.writeln('\n📝 Workout Details:');

      for (final workout in completedWorkouts) {
        report.writeln('\n${workout.name} - ${_formatDate(workout.lastPerformed!)}');
        report.writeln('Duration: ${_formatDuration(workout.calculateTotalWorkoutTime())}');

        // Add exercise details
        for (final exercise in workout.exercises) {
          report.writeln('  - ${exercise.name}:');

          for (final set in exercise.sets.where((s) => s.status == SetStatus.completed)) {
            if (exercise.type == ExerciseType.weightReps) {
              report.writeln('    • ${set.completedReps ?? 0} reps at ${set.weight ?? 0} kg${set.notes != null ? ' (${set.notes})' : ''}');
            } else if (exercise.type == ExerciseType.timedHold) {
              report.writeln('    • ${_formatDuration(set.completedDuration ?? Duration.zero)}${set.notes != null ? ' (${set.notes})' : ''}');
            } else {
              report.writeln('    • Completed${set.notes != null ? ' (${set.notes})' : ''}');
            }
          }
        }
      }
    }

    report.writeln('\n💪 Keep up the good work! 💪');

    return Future.value(report.toString());
  }

  // Share report via WhatsApp
  Future<bool> shareViaWhatsApp(String report, {String? phoneNumber}) async {
    try {
      // Create a temporary file for the report
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/weekly_workout_report.txt');
      await file.writeAsString(report);

      // If a phone number is provided, use it
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        return await _flutterShareMe.shareToWhatsApp(
          msg: 'Weekly Workout Report',
          fileType: FileType.any,
        ) == 'success';
      } else {
        // Just share the report to WhatsApp
        return await _flutterShareMe.shareToWhatsApp(
          msg: report,
        ) == 'success';
      }
    } catch (e) {
      debugPrint('Error sharing via WhatsApp: $e');
      return false;
    }
  }

  // Share report via Discord
  Future<bool> shareViaDiscord(String report) async {
    try {
      // Create a temporary file for the report
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/weekly_workout_report.txt');
      await file.writeAsString(report);

      // Share the file - Discord will pick it up through the system share dialog
      await Share.shareFiles(
        [file.path],
        text: 'Weekly Workout Report',
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing via Discord: $e');
      return false;
    }
  }

  // Share report via any available app
  Future<bool> shareViaAny(String report) async {
    try {
      // Create a temporary file for the report
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/weekly_workout_report.txt');
      await file.writeAsString(report);

      // Share using the system share dialog
      await Share.shareFiles(
        [file.path],
        text: 'Weekly Workout Report',
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing: $e');
      return false;
    }
  }

  // Export detailed workout data as JSON
  Future<bool> exportWorkoutsAsJson(List<Workout> workouts) async {
    try {
      // Create a temporary file for the JSON data
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/workout_data.json');

      // Convert workouts to JSON and save to file
      final jsonData = jsonEncode({
        'exportDate': DateTime.now().toIso8601String(),
        'workouts': workouts.map((w) => w.toJson()).toList(),
      });

      await file.writeAsString(jsonData);

      // Share the file
      await Share.shareFiles(
        [file.path],
        mimeTypes: ['application/json'],
        subject: 'Workout Data Export',
      );

      return true;
    } catch (e) {
      debugPrint('Error exporting workouts: $e');
      return false;
    }
  }

  // Helper function to format dates
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper function to format durations
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}