import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/workout.dart';
import '../../services/storage_service.dart';
import '../../config/routes.dart';
import '../widgets/workout_card.dart';
import '../common/loading_indicator.dart';
import '../common/app_bar.dart';

class WorkoutListScreen extends StatefulWidget {
  final bool isTemplateSelection;

  const WorkoutListScreen({
    Key? key,
    this.isTemplateSelection = false,
  }) : super(key: key);

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  late StorageService _storageService;

  List<Workout> _workouts = [];
  List<Workout> _filteredWorkouts = [];
  Set<String> _allTags = {};
  Set<String> _allMuscleGroups = {};

  bool _isLoading = true;
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  Set<String> _selectedMuscleGroups = {};
  bool _showFavorites = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storageService = Provider.of<StorageService>(context, listen: false);
    _loadWorkouts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);

    try {
      // Load all workouts
      final workouts = await _storageService.getAllWorkouts();

      // Extract all tags and muscle groups
      final allTags = <String>{};
      final allMuscleGroups = <String>{};

      for (final workout in workouts) {
        allTags.addAll(workout.tags);

        for (final exercise in workout.exercises) {
          if (exercise.muscleGroup != null && exercise.muscleGroup!.isNotEmpty) {
            allMuscleGroups.add(exercise.muscleGroup!);
          }
        }
      }

      setState(() {
        _workouts = workouts;
        _filteredWorkouts = List.from(workouts);
        _allTags = allTags;
        _allMuscleGroups = allMuscleGroups;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('Error loading workouts: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading workouts: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredWorkouts = _workouts.where((workout) {
        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final nameMatch = workout.name.toLowerCase().contains(query);
          final descMatch = workout.description?.toLowerCase().contains(query) ?? false;
          final tagMatch = workout.tags.any((tag) => tag.toLowerCase().contains(query));

          if (!(nameMatch || descMatch || tagMatch)) {
            return false;
          }
        }

        // Filter by selected tags
        if (_selectedTags.isNotEmpty) {
          if (!workout.tags.any((tag) => _selectedTags.contains(tag))) {
            return false;
          }
        }

        // Filter by selected muscle groups
        if (_selectedMuscleGroups.isNotEmpty) {
          final workoutMuscleGroups = workout.exercises
              .map((e) => e.muscleGroup)
              .whereNotNull()
              .toSet();

          if (!workoutMuscleGroups.any((mg) => _selectedMuscleGroups.contains(mg))) {
            return false;
          }
        }

        // Filter by favorites
        if (_showFavorites) {
          return workout.isFavorite;
        }

        return true;
      }).toList();

      // Sort by last performed date (most recent first)
      _filteredWorkouts.sort((a, b) {
        if (a.lastPerformed == null && b.lastPerformed == null) {
          return a.name.compareTo(b.name);
        } else if (a.lastPerformed == null) {
          return 1; // a comes after b
        } else if (b.lastPerformed == null) {
          return -1; // a comes before b
        } else {
          return b.lastPerformed!.compareTo(a.lastPerformed!);
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    _applyFilters();
  }

  void _toggleMuscleGroup(String muscleGroup) {
    setState(() {
      if (_selectedMuscleGroups.contains(muscleGroup)) {
        _selectedMuscleGroups.remove(muscleGroup);
      } else {
        _selectedMuscleGroups.add(muscleGroup);
      }
    });
    _applyFilters();
  }

  void _toggleFavorites() {
    setState(() {
      _showFavorites = !_showFavorites;
    });
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedTags.clear();
      _selectedMuscleGroups.clear();
      _showFavorites = false;
    });
    _applyFilters();
  }

  void _createWorkoutFromTemplate(Workout template) {
    // Create a copy of the template with a new name
    final newWorkout = template.copyWith(
      id: null, // Will generate a new ID
      name: '${template.name} (Copy)',
      lastPerformed: null,
      history: [],
      createdAt: DateTime.now(),
      isFavorite: false,
    );

    // Navigate to the detail screen with the new workout
    AppRoutes.navigateToWorkoutDetail(
      context,
      workout: newWorkout,
      isNew: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isTemplateSelection ? 'Select Template' : 'Workouts',
        bottom: widget.isTemplateSelection
            ? null
            : _buildSearchBar(colorScheme),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _buildContent(textTheme, colorScheme),
      floatingActionButton: widget.isTemplateSelection
          ? null
          : FloatingActionButton(
        onPressed: _showAddWorkoutOptions,
        tooltip: 'Add Workout',
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildSearchBar(ColorScheme colorScheme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search workouts',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _showFavorites ? Icons.favorite : Icons.favorite_border,
                color: _showFavorites ? Colors.red : null,
              ),
              onPressed: _toggleFavorites,
              tooltip: 'Show Favorites',
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(TextTheme textTheme, ColorScheme colorScheme) {
    if (_workouts.isEmpty) {
      return _buildEmptyState(textTheme, colorScheme);
    }

    if (_filteredWorkouts.isEmpty) {
      return _buildNoResultsMessage(textTheme, colorScheme);
    }

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredWorkouts.length,
        itemBuilder: (context, index) {
          final workout = _filteredWorkouts[index];
          return WorkoutCard(
            workout: workout,
            onTap: widget.isTemplateSelection
                ? () => _createWorkoutFromTemplate(workout)
                : () => AppRoutes.navigateToWorkoutDetail(context, workout: workout),
            onStart: widget.isTemplateSelection
                ? null
                : () => AppRoutes.navigateToActiveWorkout(context, workout: workout),
            showStartButton: !widget.isTemplateSelection,
            onToggleFavorite: widget.isTemplateSelection
                ? null
                : () => _toggleWorkoutFavorite(workout),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts found',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new workout to get started',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Workout'),
            onPressed: () => AppRoutes.navigateToWorkoutDetail(
              context,
              workout: Workout(
                name: 'New Workout',
                exercises: [],
                createdAt: DateTime.now(),
              ),
              isNew: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsMessage(TextTheme textTheme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No matching workouts found',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
            onPressed: _clearFilters,
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Workouts',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedTags = {};
                                  _selectedMuscleGroups = {};
                                });
                              },
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (_allTags.isNotEmpty) ...[
                          Text(
                            'Tags',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedTags.add(tag);
                                    } else {
                                      _selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const Divider(),
                        ],
                        if (_allMuscleGroups.isNotEmpty) ...[
                          Text(
                            'Muscle Groups',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allMuscleGroups.map((muscleGroup) {
                              final isSelected = _selectedMuscleGroups.contains(muscleGroup);
                              return FilterChip(
                                label: Text(muscleGroup),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedMuscleGroups.add(muscleGroup);
                                    } else {
                                      _selectedMuscleGroups.remove(muscleGroup);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddWorkoutOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Workout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: const Text('Create from Scratch'),
                onTap: () {
                  Navigator.pop(context);
                  AppRoutes.navigateToWorkoutDetail(
                    context,
                    workout: Workout(
                      name: 'New Workout',
                      exercises: [],
                      createdAt: DateTime.now(),
                    ),
                    isNew: true,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Use Template'),
                onTap: () {
                  Navigator.pop(context);
                  AppRoutes.navigateToWorkouts(
                    context,
                    isTemplateSelection: true,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleWorkoutFavorite(Workout workout) async {
    final updatedWorkout = workout.copyWith(
      isFavorite: !workout.isFavorite,
    );

    try {
      await _storageService.saveWorkout(updatedWorkout);

      // Update local lists
      setState(() {
        final index = _workouts.indexWhere((w) => w.id == workout.id);
        if (index != -1) {
          _workouts[index] = updatedWorkout;
        }

        final filteredIndex = _filteredWorkouts.indexWhere((w) => w.id == workout.id);
        if (filteredIndex != -1) {
          _filteredWorkouts[filteredIndex] = updatedWorkout;
        }
      });
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update workout'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
