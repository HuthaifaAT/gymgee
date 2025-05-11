import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:gymgee/models/workout.dart';
import 'package:gymgee/models/exercise.dart';
import 'package:gymgee/models/workout_set.dart';

class StorageService {
  static const String _workoutsKey = 'workouts';
  static const String _userSettingsKey = 'user_settings';

  late Directory _appDocDir;
  late SharedPreferences _prefs;

  // Initialize storage
  Future<void> init() async {
    _appDocDir = await getApplicationDocumentsDirectory();
    _prefs = await SharedPreferences.getInstance();
  }

  // Workout Management

  // Get all workouts
  Future<List<Workout>> getAllWorkouts() async {
    try {
      final workoutsJson = await _readWorkoutsFile();
      if (workoutsJson == null) return [];

      final List<dynamic> decoded = jsonDecode(workoutsJson);
      return decoded.map((w) => Workout.fromJson(w)).toList();
    } catch (e) {
      print('Error getting workouts: $e');
      return [];
    }
  }

  // Save a workout
  Future<bool> saveWorkout(Workout workout) async {
    try {
      final workouts = await getAllWorkouts();

      // Check if workout already exists (update) or is new (add)
      final existingIndex = workouts.indexWhere((w) => w.id == workout.id);

      if (existingIndex >= 0) {
        workouts[existingIndex] = workout;
      } else {
        workouts.add(workout);
      }

      await _saveWorkoutsFile(workouts);
      return true;
    } catch (e) {
      print('Error saving workout: $e');
      return false;
    }
  }

  // Delete a workout
  Future<bool> deleteWorkout(String workoutId) async {
    try {
      final workouts = await getAllWorkouts();
      workouts.removeWhere((w) => w.id == workoutId);
      await _saveWorkoutsFile(workouts);
      return true;
    } catch (e) {
      print('Error deleting workout: $e');
      return false;
    }
  }

  // Get a specific workout by ID
  Future<Workout?> getWorkout(String workoutId) async {
    try {
      final workouts = await getAllWorkouts();
      return workouts.firstWhere((w) => w.id == workoutId);
    } catch (e) {
      print('Error getting workout: $e');
      return null;
    }
  }

  // Exercise Management

  // Get all exercises across all workouts
  Future<List<Exercise>> getAllExercises() async {
    try {
      final workouts = await getAllWorkouts();
      final allExercises = <Exercise>[];

      for (final workout in workouts) {
        allExercises.addAll(workout.exercises);
      }

      // Remove duplicates based on exercise ID
      final uniqueExercises = <Exercise>[];
      final exerciseIds = <String>{};

      for (final exercise in allExercises) {
        if (!exerciseIds.contains(exercise.id)) {
          exerciseIds.add(exercise.id);
          uniqueExercises.add(exercise);
        }
      }

      return uniqueExercises;
    } catch (e) {
      print('Error getting all exercises: $e');
      return [];
    }
  }

  // Get exercises by type
  Future<List<Exercise>> getExercisesByType(ExerciseType type) async {
    try {
      final allExercises = await getAllExercises();
      return allExercises.where((e) => e.type == type).toList();
    } catch (e) {
      print('Error getting exercises by type: $e');
      return [];
    }
  }

  // Get exercises by muscle group
  Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
    try {
      final allExercises = await getAllExercises();
      return allExercises
          .where((e) => e.muscleGroup == muscleGroup)
          .toList();
    } catch (e) {
      print('Error getting exercises by muscle group: $e');
      return [];
    }
  }

  // User Settings Management

  // Save user settings
  Future<bool> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      await _prefs.setString(_userSettingsKey, jsonEncode(settings));
      return true;
    } catch (e) {
      print('Error saving user settings: $e');
      return false;
    }
  }

  // Get user settings
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final settingsJson = _prefs.getString(_userSettingsKey);
      if (settingsJson == null) return {};

      return jsonDecode(settingsJson);
    } catch (e) {
      print('Error getting user settings: $e');
      return {};
    }
  }

  // Get a specific setting
  Future<dynamic> getSetting(String key, [dynamic defaultValue]) async {
    try {
      final settings = await getUserSettings();
      return settings[key] ?? defaultValue;
    } catch (e) {
      print('Error getting setting: $e');
      return defaultValue;
    }
  }

  // Save a specific setting
  Future<bool> saveSetting(String key, dynamic value) async {
    try {
      final settings = await getUserSettings();
      settings[key] = value;
      return await saveUserSettings(settings);
    } catch (e) {
      print('Error saving setting: $e');
      return false;
    }
  }

  // Stats and Analysis

  // Get workout frequency per week
  Future<Map<String, int>> getWorkoutFrequencyByWeek(int weeks) async {
    try {
      final workouts = await getAllWorkouts();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: weeks * 7));

      final Map<String, int> frequency = {};

      for (int i = 0; i < weeks; i++) {
        final weekStart = startDate.add(Duration(days: i * 7));
        final weekEnd = weekStart.add(Duration(days: 6));
        final weekKey = '${weekStart.month}/${weekStart.day}-${weekEnd.month}/${weekEnd.day}';

        final workoutsInWeek = workouts.where((w) =>
        w.lastPerformed != null &&
            w.lastPerformed!.isAfter(weekStart) &&
            w.lastPerformed!.isBefore(weekEnd.add(Duration(days: 1)))
        ).length;

        frequency[weekKey] = workoutsInWeek;
      }

      return frequency;
    } catch (e) {
      print('Error getting workout frequency: $e');
      return {};
    }
  }

  // Get total volume lifted over time (for weight exercises)
  Future<Map<String, double>> getTotalVolumeByDate(int days) async {
    try {
      final workouts = await getAllWorkouts();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final Map<String, double> volumeByDate = {};

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = '${date.month}/${date.day}';

        double dailyVolume = 0;

        for (final workout in workouts) {
          if (workout.lastPerformed == null) continue;

          // Check if workout was done on this date
          if (workout.lastPerformed!.year == date.year &&
              workout.lastPerformed!.month == date.month &&
              workout.lastPerformed!.day == date.day) {

            dailyVolume += workout.calculateTotalVolume();
          }
        }

        volumeByDate[dateStr] = dailyVolume;
      }

      return volumeByDate;
    } catch (e) {
      print('Error getting volume data: $e');
      return {};
    }
  }

  // Get progression for a specific exercise over time
  Future<Map<String, dynamic>> getExerciseProgression(String exerciseId, int limit) async {
    try {
      final workouts = await getAllWorkouts();
      final progression = <String, dynamic>{};

      // Find all instances of this exercise in workout logs
      final exerciseLogs = <Map<String, dynamic>>[];

      for (final workout in workouts) {
        for (final exercise in workout.exercises) {
          if (exercise.id == exerciseId) {
            for (final log in exercise.history) {
              exerciseLogs.add({
                'date': log.date,
                'sets': log.sets,
                'wasCompleted': log.wasCompleted,
              });
            }
          }
        }
      }

      // Sort logs by date (newest first)
      exerciseLogs.sort((a, b) =>
          (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Limit results
      final limitedLogs = exerciseLogs.take(limit).toList();

      // Extract progression data
      final weightProgression = <String, double>{};
      final repsProgression = <String, int>{};
      final durationProgression = <String, int>{};

      for (final log in limitedLogs) {
        final dateStr = '${log['date'].month}/${log['date'].day}';
        final sets = log['sets'] as List<WorkoutSet>;

        // Find the highest weight and reps in any set
        double maxWeight = 0;
        int maxReps = 0;
        Duration maxDuration = Duration.zero;

        for (final set in sets) {
          if (set.weight != null && set.weight! > maxWeight) {
            maxWeight = set.weight!;
          }

          if (set.completedReps != null && set.completedReps! > maxReps) {
            maxReps = set.completedReps!;
          }

          if (set.completedDuration != null &&
              set.completedDuration!.inSeconds > maxDuration.inSeconds) {
            maxDuration = set.completedDuration!;
          }
        }

        if (maxWeight > 0) {
          weightProgression[dateStr] = maxWeight;
        }

        if (maxReps > 0) {
          repsProgression[dateStr] = maxReps;
        }

        if (maxDuration.inSeconds > 0) {
          durationProgression[dateStr] = maxDuration.inSeconds;
        }
      }

      progression['weight'] = weightProgression;
      progression['reps'] = repsProgression;
      progression['duration'] = durationProgression;

      return progression;
    } catch (e) {
      print('Error getting exercise progression: $e');
      return {};
    }
  }

  // Private helper methods

  // Read workouts from file
  Future<String?> _readWorkoutsFile() async {
    final file = File('${_appDocDir.path}/$_workoutsKey.json');

    if (await file.exists()) {
      return await file.readAsString();
    }

    return null;
  }

  // Save workouts to file
  Future<void> _saveWorkoutsFile(List<Workout> workouts) async {
    final file = File('${_appDocDir.path}/$_workoutsKey.json');
    final encodedWorkouts = jsonEncode(workouts.map((w) => w.toJson()).toList());
    await file.writeAsString(encodedWorkouts);
  }

  // Import and Export

  // Export all data as JSON
  Future<String> exportAllData() async {
    try {
      final workouts = await getAllWorkouts();
      final settings = await getUserSettings();

      final exportData = {
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'settings': settings,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      return jsonEncode(exportData);
    } catch (e) {
      print('Error exporting data: $e');
      throw Exception('Failed to export data: $e');
    }
  }

  // Import data from JSON
  Future<bool> importData(String jsonData) async {
    try {
      final decodedData = jsonDecode(jsonData);

      // Import workouts
      if (decodedData['workouts'] != null) {
        final List<dynamic> workoutsJson = decodedData['workouts'];
        final workouts = workoutsJson.map((w) => Workout.fromJson(w)).toList();
        await _saveWorkoutsFile(workouts);
      }

      // Import settings
      if (decodedData['settings'] != null) {
        await saveUserSettings(decodedData['settings']);
      }

      return true;
    } catch (e) {
      print('Error importing data: $e');
      return false;
    }
  }

  // Create sample workouts for first launch
  Future<void> createSampleWorkouts() async {
    final workouts = await getAllWorkouts();

    // Only create samples if no workouts exist
    if (workouts.isNotEmpty) return;

    // Sample 1: Strength Training
    final strengthWorkout = Workout(
      name: 'Upper Body Strength',
      description: 'Focus on building upper body strength',
      tags: ['strength', 'upper body'],
    );

    // Add bench press
    final benchPress = Exercise(
      name: 'Bench Press',
      type: ExerciseType.weightReps,
      muscleGroup: 'Chest',
      description: 'Lie on a bench and press the barbell upward',
      autoIncreaseWeight: 2.5,
      daysBeforeIncrease: 3,
    );

    // Add sets
    benchPress.addSet(WorkoutSet(
      orderIndex: 0,
      plannedReps: 10,
      weight: 60.0,
      restTime: Duration(minutes: 1, seconds: 30),
    ));

    benchPress.addSet(WorkoutSet(
      orderIndex: 1,
      plannedReps: 8,
      weight: 70.0,
      restTime: Duration(minutes: 2),
    ));

    benchPress.addSet(WorkoutSet(
      orderIndex: 2,
      plannedReps: 6,
      weight: 80.0,
      restTime: Duration(minutes: 2, seconds: 30),
    ));

    strengthWorkout.addExercise(benchPress);

    // Add pull-ups
    final pullUps = Exercise(
      name: 'Pull-ups',
      type: ExerciseType.bodyweight,
      muscleGroup: 'Back',
      description: 'Hang from a bar and pull yourself up',
    );

    // Add sets
    pullUps.addSet(WorkoutSet(
      orderIndex: 0,
      plannedReps: 8,
      restTime: Duration(minutes: 1, seconds: 30),
    ));

    pullUps.addSet(WorkoutSet(
      orderIndex: 1,
      plannedReps: 8,
      restTime: Duration(minutes: 1, seconds: 30),
    ));

    pullUps.addSet(WorkoutSet(
      orderIndex: 2,
      plannedReps: 8,
      restTime: Duration(minutes: 1, seconds: 30),
    ));

    strengthWorkout.addExercise(pullUps);

    // Sample 2: Core Workout
    final coreWorkout = Workout(
      name: 'Core Strength',
      description: 'Build a strong foundation with these core exercises',
      tags: ['core', 'abs', 'plank'],
    );

    // Add plank
    final plank = Exercise(
      name: 'Plank',
      type: ExerciseType.timedHold,
      muscleGroup: 'Core',
      description: 'Hold a straight body position supported by your forearms and toes',
      plannedDuration: Duration(seconds: 60),
      autoIncreaseDuration: Duration(seconds: 30),
      daysBeforeIncrease: 4,
    );

    // Add sets
    plank.addSet(WorkoutSet(
      orderIndex: 0,
      plannedDuration: Duration(seconds: 60),
      restTime: Duration(seconds: 45),
    ));

    plank.addSet(WorkoutSet(
      orderIndex: 1,
      plannedDuration: Duration(seconds: 60),
      restTime: Duration(seconds: 45),
    ));

    plank.addSet(WorkoutSet(
      orderIndex: 2,
      plannedDuration: Duration(seconds: 60),
      restTime: Duration(seconds: 45),
    ));

    coreWorkout.addExercise(plank);

    // Add crunches
    final crunches = Exercise(
      name: 'Crunches',
      type: ExerciseType.weightReps,
      muscleGroup: 'Core',
      description: 'Lie on your back and curl your upper body toward your knees',
    );

    // Add sets
    crunches.addSet(WorkoutSet(
      orderIndex: 0,
      plannedReps: 15,
      restTime: Duration(seconds: 45),
    ));

    crunches.addSet(WorkoutSet(
      orderIndex: 1,
      plannedReps: 15,
      restTime: Duration(seconds: 45),
    ));

    crunches.addSet(WorkoutSet(
      orderIndex: 2,
      plannedReps: 15,
      restTime: Duration(seconds: 45),
    ));

    coreWorkout.addExercise(crunches);

    // Save sample workouts
    await saveWorkout(strengthWorkout);
    await saveWorkout(coreWorkout);
  }
}
