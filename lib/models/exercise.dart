import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:gymgee/models/workout_set.dart';

enum ExerciseType {
  weightReps,  // Track weight and reps (e.g., bench press)
  timedHold,   // Track duration (e.g., plank)
  cardio,      // Track distance, time, etc.
  bodyweight,  // Reps only (e.g., push-ups)
  custom       // User-defined tracking
}

class Exercise {
  final String id;
  String name;
  ExerciseType type;
  String? muscleGroup;
  String? description;
  List<WorkoutSet> sets;

  // For timed exercises
  Duration? plannedDuration;
  Duration? restBetweenSets;

  // For progression logic
  Duration? autoIncreaseDuration;
  int daysBeforeIncrease;
  double? autoIncreaseWeight;

  // Tracking history of the exercise
  List<ExerciseLog> history;

  Exercise({
    String? id,
    required this.name,
    required this.type,
    this.muscleGroup,
    this.description,
    List<WorkoutSet>? sets,
    this.plannedDuration,
    this.restBetweenSets,
    this.autoIncreaseDuration,
    this.daysBeforeIncrease = 4, // Default to 4 days as specified
    this.autoIncreaseWeight,
    List<ExerciseLog>? history,
  }) :
        id = id ?? const Uuid().v4(),
        sets = sets ?? [],
        history = history ?? [];

  // Add a set to this exercise
  void addSet(WorkoutSet set) {
    sets.add(set);
  }

  // Log a completed exercise to history
  void logCompletion(DateTime date, List<WorkoutSet> completedSets) {
    history.add(
        ExerciseLog(
          date: date,
          exerciseId: id,
          sets: List.from(completedSets),
        )
    );
  }

  // Calculate the next planned duration based on progression logic
  Duration calculateNextPlannedDuration() {
    if (type != ExerciseType.timedHold ||
        autoIncreaseDuration == null ||
        plannedDuration == null) {
      return plannedDuration ?? Duration.zero;
    }

    // Count successful completions in the last X days
    final now = DateTime.now();
    final successfulCompletions = history
        .where((log) => log.date.isAfter(now.subtract(Duration(days: daysBeforeIncrease))))
        .where((log) => log.wasCompleted)
        .length;

    if (successfulCompletions >= daysBeforeIncrease) {
      return plannedDuration! + autoIncreaseDuration!;
    }

    return plannedDuration!;
  }

  // Check if it's time to increase weight based on history
  bool shouldIncreaseWeight() {
    if (type != ExerciseType.weightReps || autoIncreaseWeight == null) {
      return false;
    }

    // Count successful completions in the last X days
    final now = DateTime.now();
    final successfulCompletions = history
        .where((log) => log.date.isAfter(now.subtract(Duration(days: daysBeforeIncrease))))
        .where((log) => log.wasCompleted)
        .length;

    return successfulCompletions >= daysBeforeIncrease;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'muscleGroup': muscleGroup,
      'description': description,
      'sets': sets.map((s) => s.toJson()).toList(),
      'plannedDuration': plannedDuration?.inSeconds,
      'restBetweenSets': restBetweenSets?.inSeconds,
      'autoIncreaseDuration': autoIncreaseDuration?.inSeconds,
      'daysBeforeIncrease': daysBeforeIncrease,
      'autoIncreaseWeight': autoIncreaseWeight,
      'history': history.map((h) => h.toJson()).toList(),
    };
  }

  // Create from JSON
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      type: ExerciseType.values[json['type']],
      muscleGroup: json['muscleGroup'],
      description: json['description'],
      sets: (json['sets'] as List?)
          ?.map((s) => WorkoutSet.fromJson(s))
          .toList() ?? [],
      plannedDuration: json['plannedDuration'] != null
          ? Duration(seconds: json['plannedDuration'])
          : null,
      restBetweenSets: json['restBetweenSets'] != null
          ? Duration(seconds: json['restBetweenSets'])
          : null,
      autoIncreaseDuration: json['autoIncreaseDuration'] != null
          ? Duration(seconds: json['autoIncreaseDuration'])
          : null,
      daysBeforeIncrease: json['daysBeforeIncrease'] ?? 4,
      autoIncreaseWeight: json['autoIncreaseWeight'],
      history: (json['history'] as List?)
          ?.map((h) => ExerciseLog.fromJson(h))
          .toList() ?? [],
    );
  }
}

class ExerciseLog {
  final String id;
  final DateTime date;
  final String exerciseId;
  final List<WorkoutSet> sets;
  final bool wasCompleted;

  ExerciseLog({
    String? id,
    required this.date,
    required this.exerciseId,
    required this.sets,
    this.wasCompleted = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'exerciseId': exerciseId,
      'sets': sets.map((s) => s.toJson()).toList(),
      'wasCompleted': wasCompleted,
    };
  }

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      id: json['id'],
      date: DateTime.parse(json['date']),
      exerciseId: json['exerciseId'],
      sets: (json['sets'] as List)
          .map((s) => WorkoutSet.fromJson(s))
          .toList(),
      wasCompleted: json['wasCompleted'] ?? true,
    );
  }
}