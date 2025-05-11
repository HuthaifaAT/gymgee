import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/workout.dart';
import '../../services/storage_service.dart';
import '../../config/routes.dart';
import '../widgets/workout_card.dart';
import '../common/loading_indicator.dart';
import '../common/app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StorageService _storageService;
  List<Workout> _recentWorkouts = [];
  List<Workout> _recommendedWorkouts = [];
  bool _isLoading = true;
  late String _greeting;

  @override
  void initState() {
    super.initState();
    _storageService = Provider.of<StorageService>(context, listen: false);
    _setGreeting();
    _loadWorkouts();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 18) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);

    try {
      // Get user profile
      final userProfile = await _storageService.getUserProfile();

      // Load recent workouts (last 7 days)
      final allWorkouts = await _storageService.getAllWorkouts();
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      // Sort by most recent
      _recentWorkouts = allWorkouts
          .where((w) => w.lastPerformed != null && w.lastPerformed!.isAfter(sevenDaysAgo))
          .toList()
        ..sort((a, b) => b.lastPerformed!.compareTo(a.lastPerformed!));

      // Limit to 5 most recent
      if (_recentWorkouts.length > 5) {
        _recentWorkouts = _recentWorkouts.sublist(0, 5);
      }

      // Generate recommendations based on user's workout history
      // Simple algorithm: Recommend workouts not done in last 7 days
      // In a real app, this would use machine learning or more advanced algorithms
      _recommendedWorkouts = allWorkouts
          .where((w) => w.lastPerformed == null ||
          w.lastPerformed!.isBefore(sevenDaysAgo))
          .toList();

      // Prioritize recommendation based on user's preferences
      if (userProfile != null && userProfile.favoriteMuscleGroups.isNotEmpty) {
        _recommendedWorkouts.sort((a, b) {
          // Prioritize workouts that target user's favorite muscle groups
          final aScore = a.exercises.where((e) =>
              userProfile.favoriteMuscleGroups.contains(e.muscleGroup)).length;
          final bScore = b.exercises.where((e) =>
              userProfile.favoriteMuscleGroups.contains(e.muscleGroup)).length;
          return bScore.compareTo(aScore);
        });
      }

      // Take top 3 recommendations
      if (_recommendedWorkouts.length > 3) {
        _recommendedWorkouts = _recommendedWorkouts.sublist(0, 3);
      }
    } catch (e) {
      debugPrint('Error loading workouts: $e');

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workouts: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getDaysSinceLastWorkout() {
    if (_recentWorkouts.isEmpty || _recentWorkouts.first.lastPerformed == null) {
      return -1; // No workouts yet
    }

    final now = DateTime.now();
    final lastWorkout = _recentWorkouts.first.lastPerformed!;
    return now.difference(lastWorkout).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Gym Tracker',
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => AppRoutes.navigateToShareProgress(context),
            tooltip: 'Share Progress',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
        onRefresh: _loadWorkouts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(textTheme, colorScheme),
                const SizedBox(height: 24),
                _buildQuickStartSection(textTheme, colorScheme),
                const SizedBox(height: 24),
                _buildRecentWorkoutsSection(textTheme),
                const SizedBox(height: 24),
                _buildRecommendedWorkoutsSection(textTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(TextTheme textTheme, ColorScheme colorScheme) {
    final daysSinceLastWorkout = _getDaysSinceLastWorkout();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_greeting!',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (daysSinceLastWorkout >= 0)
              Text(
                daysSinceLastWorkout == 0
                    ? 'You worked out today. Great job!'
                    : daysSinceLastWorkout == 1
                    ? 'Your last workout was yesterday.'
                    : 'Your last workout was $daysSinceLastWorkout days ago.',
                style: textTheme.bodyLarge,
              )
            else
              Text(
                'Ready to start your fitness journey?',
                style: textTheme.bodyLarge,
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.fitness_center),
              label: const Text('Start Workout'),
              onPressed: () => AppRoutes.navigateToWorkouts(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickStartCard(
                icon: Icons.timer,
                title: 'Timed Workout',
                color: colorScheme.primary,
                onTap: () => AppRoutes.navigateToTimer(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickStartCard(
                icon: Icons.fitness_center,
                title: 'Empty Workout',
                color: colorScheme.secondary,
                onTap: () async {
                  // Create an empty workout
                  final emptyWorkout = Workout(
                    name: 'Quick Workout',
                    exercises: [],
                    createdAt: DateTime.now(),
                  );

                  // Start the workout
                  AppRoutes.navigateToActiveWorkout(
                    context,
                    workout: emptyWorkout,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStartCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentWorkoutsSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Workouts',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _recentWorkouts.isEmpty
            ? Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No recent workouts',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentWorkouts.length,
          itemBuilder: (context, index) {
            final workout = _recentWorkouts[index];
            return WorkoutCard(
              workout: workout,
              onTap: () => AppRoutes.navigateToWorkoutDetail(
                context,
                workout: workout,
              ),
              onStart: () => AppRoutes.navigateToActiveWorkout(
                context,
                workout: workout,
              ),
              showStartButton: true,
            );
          },
        ),
        if (_recentWorkouts.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                child: const Text('View All'),
                onPressed: () => AppRoutes.navigateToWorkouts(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendedWorkoutsSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Workouts',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _recommendedWorkouts.isEmpty
            ? Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No recommended workouts',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recommendedWorkouts.length,
          itemBuilder: (context, index) {
            final workout = _recommendedWorkouts[index];
            return WorkoutCard(
              workout: workout,
              onTap: () => AppRoutes.navigateToWorkoutDetail(
                context,
                workout: workout,
              ),
              onStart: () => AppRoutes.navigateToActiveWorkout(
                context,
                workout: workout,
              ),
              showStartButton: true,
              isRecommendation: true,
            );
          },
        ),
      ],
    );
  }
}
