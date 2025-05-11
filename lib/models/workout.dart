import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'exercise.dart';
import 'workout_set.dart';

part 'workout.g.dart';

/// A data model representing a workout with exercises.
@HiveType(typeId: 1)
class Workout extends Equatable {
  /// Unique identifier for the workout.
  @HiveField(0)
  final String id;

  /// The name of the workout.
  @HiveField(1)
  final String name;

  /// Optional description of the workout.
  @HiveField(2)
  final String? description;

  /// List of exercises included in this workout.
  @HiveField(3)
  final List<Exercise> exercises;

  /// When this workout was last performed, if ever.
  @HiveField(4)
  final DateTime? lastPerformed;

  /// Estimated duration of the workout in minutes.
  @HiveField(5)
  final int? estimatedDuration;

  /// Tags for categorizing and filtering workouts.
  @HiveField(6)
  final List<String> tags;

  /// History of previous completions of this workout.
  @HiveField(7)
  final List<WorkoutLog> history;

  /// Whether this workout is marked as a favorite.
  @HiveField(8)
  final bool isFavorite;

  /// When this workout was created.
  @HiveField(9)
  final DateTime createdAt;

  /// When this workout was last modified.
  @HiveField(10)
  final DateTime? lastModified;

  /// Creates a new workout.
  Workout({
    String? id,
    required this.name,
    this.description,
    required this.exercises,
    this.lastPerformed,
    this.estimatedDuration,
    List<String>? tags,
    List<WorkoutLog>? history,
    this.isFavorite = false,
    DateTime? createdAt,
    this.lastModified,
  })  : id = id ?? const Uuid().v4(),
        tags = tags ?? [],
        history = history ?? [],
        createdAt = createdAt ?? DateTime.now();

  /// Calculate the total volume (weight × reps) of this workout.
  double calculateTotalVolume() {
    double totalVolume = 0;

    for (final exercise in exercises) {
      if (exercise.type == ExerciseType.weightReps) {
        for (final set in exercise.sets) {
          if (set.status == SetStatus.completed &&
              set.completedReps != null &&
              set.weight != null) {
            totalVolume += set.completedReps! * set.weight!;
          }
        }
      }
    }

    return totalVolume;
  }

  /// Calculate the total workout time, including rest periods.
  Duration calculateTotalWorkoutTime() {
    Duration totalTime = Duration.zero;

    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        // Add exercise time
        if (set.startTime != null && set.endTime != null) {
          totalTime += set.endTime!.difference(set.startTime!);
        }

        // Add rest time if specified
        if (set.restTime != null) {
          totalTime += set.restTime!;
        }
      }
    }

    return totalTime;
  }

  /// Create a copy of this workout as a template.
  Workout createTemplateFromThis() {
    return copyWith(
      id: null, // Will generate a new ID
      lastPerformed: null,
      history: [],
      createdAt: DateTime.now(),
      lastModified: null,
      isFavorite: false,
    );
  }

  /// Log a completed workout session.
  WorkoutLog logCompletion(
      DateTime date,
      Duration duration, {
        String? notes,
        double? totalVolume,
      }) {
    final log = WorkoutLog(
      workoutId: id,
      date: date,
      duration: duration,
      notes: notes,
      totalVolume: totalVolume ?? calculateTotalVolume(),
      exerciseLogs: exercises.map((exercise) {
        return ExerciseLogSummary(
          exerciseId: exercise.id,
          name: exercise.name,
          type: exercise.type,
          sets: exercise.sets.length,
          completedSets: exercise.sets
              .where((set) => set.status == SetStatus.completed)
              .length,
        );
      }).toList(),
    );

    return log;
  }

  /// Creates a copy of this workout with updated fields.
  Workout copyWith({
    String? id,
    String? name,
    String? Function()? description,
    List<Exercise>? exercises,
    DateTime? Function()? lastPerformed,
    int? Function()? estimatedDuration,
    List<String>? tags,
    List<WorkoutLog>? history,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? Function()? lastModified,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      exercises: exercises ?? this.exercises,
      lastPerformed: lastPerformed != null ? lastPerformed() : this.lastPerformed,
      estimatedDuration: estimatedDuration != null
          ? estimatedDuration()
          : this.estimatedDuration,
      tags: tags ?? this.tags,
      history: history ?? this.history,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified != null ? lastModified() : this.lastModified,
    );
  }

  /// Gets the workout logs for a specific date range.
  List<WorkoutLog> getLogsForDateRange(DateTime start, DateTime end) {
    return history
        .where((log) => log.date.isAfter(start) && log.date.isBefore(end))
        .toList();
  }

  /// Returns a map representation of this workout.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'lastPerformed': lastPerformed?.toIso8601String(),
      'estimatedDuration': estimatedDuration,
      'tags': tags,
      'history': history.map((h) => h.toMap()).toList(),
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  /// Creates a workout from a map.
  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      exercises: (map['exercises'] as List?)
          ?.map((e) => Exercise.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
      lastPerformed: map['lastPerformed'] != null
          ? DateTime.parse(map['lastPerformed'])
          : null,
      estimatedDuration: map['estimatedDuration'],
      tags: (map['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      history: (map['history'] as List?)
          ?.map((h) => WorkoutLog.fromMap(h as Map<String, dynamic>))
          .toList() ??
          [],
      isFavorite: map['isFavorite'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    exercises,
    lastPerformed,
    estimatedDuration,
    tags,
    history,
    isFavorite,
    createdAt,
    lastModified,
  ];
}

/// A log of a completed workout session.
@HiveType(typeId: 2)
class WorkoutLog extends Equatable {
  /// Unique identifier for the log.
  @HiveField(0)
  final String id;

  /// ID of the workout this log corresponds to.
  @HiveField(1)
  final String workoutId;

  /// Date when the workout was performed.
  @HiveField(2)
  final DateTime date;

  /// How long the workout took.
  @HiveField(3)
  final Duration duration;

  /// Optional notes about this workout session.
  @HiveField(4)
  final String? notes;

  /// Summaries of the exercises performed during this workout.
  @HiveField(5)
  final List<ExerciseLogSummary> exerciseLogs;

  /// Total volume (weight × reps) of this workout session.
  @HiveField(6)
  final double totalVolume;

  /// Creates a new workout log.
  WorkoutLog({
    String? id,
    required this.workoutId,
    required this.date,
    required this.duration,
    this.notes,
    required this.exerciseLogs,
    this.totalVolume = 0,
  }) : id = id ?? const Uuid().v4();

  /// Creates a map representation of this workout log.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workoutId': workoutId,
      'date': date.toIso8601String(),
      'duration': duration.inSeconds,
      'notes': notes,
      'exerciseLogs': exerciseLogs.map((e) => e.toMap()).toList(),
      'totalVolume': totalVolume,
    };
  }

  /// Creates a workout log from a map.
  factory WorkoutLog.fromMap(Map<String, dynamic> map) {
    return WorkoutLog(
      id: map['id'],
      workoutId: map['workoutId'],
      date: DateTime.parse(map['date']),
      duration: Duration(seconds: map['duration']),
      notes: map['notes'],
      exerciseLogs: (map['exerciseLogs'] as List?)
          ?.map((e) => ExerciseLogSummary.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalVolume: map['totalVolume'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    workoutId,
    date,
    duration,
    notes,
    exerciseLogs,
    totalVolume,
  ];
}

/// A summary of an exercise performed during a workout.
@HiveType(typeId: 3)
class ExerciseLogSummary extends Equatable {
  /// ID of the exercise this summary corresponds to.
  @HiveField(0)
  final String exerciseId;

  /// Name of the exercise.
  @HiveField(1)
  final String name;

  /// Type of exercise.
  @HiveField(2)
  final ExerciseType type;

  /// Total number of sets.
  @HiveField(3)
  final int sets;

  /// Number of sets that were completed.
  @HiveField(4)
  final int completedSets;

  /// Creates a new exercise log summary.
  ExerciseLogSummary({
    required this.exerciseId,
    required this.name,
    required this.type,
    required this.sets,
    required this.completedSets,
  });

  /// Creates a map representation of this exercise log summary.
  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'name': name,
      'type': type.index,
      'sets': sets,
      'completedSets': completedSets,
    };
  }

  /// Creates an exercise log summary from a map.
  factory ExerciseLogSummary.fromMap(Map<String, dynamic> map) {
    return ExerciseLogSummary(
      exerciseId: map['exerciseId'],
      name: map['name'],
      type: ExerciseType.values[map['type']],
      sets: map['sets'],
      completedSets: map['completedSets'],
    );
  }

  @override
  List<Object?> get props => [
    exerciseId,
    name,
    type,
    sets,
    completedSets,
  ];
}

/// This adapter handles conversion between the Workout class and Hive storage.
class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 1;

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Workout(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      exercises: (fields[3] as List).cast<Exercise>(),
      lastPerformed: fields[4] as DateTime?,
      estimatedDuration: fields[5] as int?,
      tags: (fields[6] as List).cast<String>(),
      history: (fields[7] as List).cast<WorkoutLog>(),
      isFavorite: fields[8] as bool,
      createdAt: fields[9] as DateTime,
      lastModified: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.exercises)
      ..writeByte(4)
      ..write(obj.lastPerformed)
      ..writeByte(5)
      ..write(obj.estimatedDuration)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.history)
      ..writeByte(8)
      ..write(obj.isFavorite)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastModified);
  }
}
