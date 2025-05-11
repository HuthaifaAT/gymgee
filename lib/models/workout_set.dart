import 'package:uuid/uuid.dart';

enum SetStatus {
  planned,    // Set is planned but not started
  inProgress, // Set is currently in progress
  completed,  // Set was completed successfully
  failed,     // Failed to complete the set
  skipped     // Set was skipped
}

class WorkoutSet {
  final String id;
  int orderIndex; // Position of this set in the exercise

  // For reps-based exercises
  int? plannedReps;
  int? completedReps;
  double? weight; // In kg or lbs based on user preference

  // For timed exercises
  Duration? plannedDuration;
  Duration? completedDuration;
  Duration? restTime;

  // Status tracking
  SetStatus status;
  DateTime? startTime;
  DateTime? endTime;

  // Notes and feedback
  String? notes; // For example: "reached failure", "weights too heavy", etc.
  List<String> tags = []; // Custom tags for filtering

  // Tracking pause information for timed exercises
  List<PauseInfo> pauseHistory = [];

  WorkoutSet({
    String? id,
    this.orderIndex = 0,
    this.plannedReps,
    this.completedReps,
    this.weight,
    this.plannedDuration,
    this.completedDuration,
    this.restTime,
    this.status = SetStatus.planned,
    this.startTime,
    this.endTime,
    this.notes,
    List<String>? tags,
    List<PauseInfo>? pauseHistory,
  }) :
        id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        pauseHistory = pauseHistory ?? [];

  // Start this set
  void start() {
    startTime = DateTime.now();
    status = SetStatus.inProgress;
  }

  // Complete this set with reps
  void completeWithReps(int reps, {String? notes, double? weight}) {
    endTime = DateTime.now();
    completedReps = reps;
    status = SetStatus.completed;

    if (notes != null) {
      this.notes = notes;
    }

    if (weight != null) {
      this.weight = weight;
    }
  }

  // Complete this set with duration (for timed exercises)
  void completeWithDuration(Duration duration, {String? notes}) {
    endTime = DateTime.now();
    completedDuration = duration;
    status = SetStatus.completed;

    if (notes != null) {
      this.notes = notes;
    }
  }

  // Mark set as failed with a reason
  void fail(String reason) {
    endTime = DateTime.now();
    status = SetStatus.failed;
    notes = reason;
  }

  // Skip this set
  void skip(String? reason) {
    status = SetStatus.skipped;
    notes = reason;
  }

  // Record a pause during a timed exercise
  void recordPause() {
    pauseHistory.add(PauseInfo(
      startTime: DateTime.now(),
    ));
  }

  // Record resuming from a pause
  void recordResume() {
    if (pauseHistory.isNotEmpty &&
        pauseHistory.last.endTime == null) {
      pauseHistory.last.endTime = DateTime.now();
    }
  }

  // Get total pause duration
  Duration getTotalPauseDuration() {
    Duration total = Duration.zero;

    for (var pause in pauseHistory) {
      if (pause.endTime != null) {
        total += pause.endTime!.difference(pause.startTime);
      } else if (pause.startTime != null) {
        // For active pauses, calculate up to now
        total += DateTime.now().difference(pause.startTime);
      }
    }

    return total;
  }

  // Get real (effective) duration excluding pauses
  Duration getEffectiveDuration() {
    if (startTime == null) return Duration.zero;

    final end = endTime ?? DateTime.now();
    final totalDuration = end.difference(startTime!);
    final pauseDuration = getTotalPauseDuration();

    return totalDuration - pauseDuration;
  }

  // Add a tag to this set
  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
    }
  }

  // Create a copy of this set with default values for a new workout
  WorkoutSet createTemplateFromThis() {
    return WorkoutSet(
      orderIndex: orderIndex,
      plannedReps: plannedReps,
      weight: weight,
      plannedDuration: plannedDuration,
      restTime: restTime,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderIndex': orderIndex,
      'plannedReps': plannedReps,
      'completedReps': completedReps,
      'weight': weight,
      'plannedDuration': plannedDuration?.inSeconds,
      'completedDuration': completedDuration?.inSeconds,
      'restTime': restTime?.inSeconds,
      'status': status.index,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'notes': notes,
      'tags': tags,
      'pauseHistory': pauseHistory.map((p) => p.toJson()).toList(),
    };
  }

  // Create from JSON
  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'],
      orderIndex: json['orderIndex'] ?? 0,
      plannedReps: json['plannedReps'],
      completedReps: json['completedReps'],
      weight: json['weight'],
      plannedDuration: json['plannedDuration'] != null
          ? Duration(seconds: json['plannedDuration'])
          : null,
      completedDuration: json['completedDuration'] != null
          ? Duration(seconds: json['completedDuration'])
          : null,
      restTime: json['restTime'] != null
          ? Duration(seconds: json['restTime'])
          : null,
      status: SetStatus.values[json['status'] ?? 0],
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : null,
      notes: json['notes'],
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : [],
      pauseHistory: json['pauseHistory'] != null
          ? (json['pauseHistory'] as List)
          .map((p) => PauseInfo.fromJson(p))
          .toList()
          : [],
    );
  }
}

// Class to track pause information for timed exercises
class PauseInfo {
  final String id;
  final DateTime startTime;
  DateTime? endTime;

  PauseInfo({
    String? id,
    required this.startTime,
    this.endTime,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  factory PauseInfo.fromJson(Map<String, dynamic> json) {
    return PauseInfo(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'])
          : null,
    );
  }
}