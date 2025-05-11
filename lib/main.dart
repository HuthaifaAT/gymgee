import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'models/workout.dart';
import 'models/exercise.dart';
import 'models/workout_set.dart';
import 'models/user_profile.dart';
import 'services/storage_service.dart';
import 'services/timer_service.dart';
import 'services/progress_service.dart';
import 'services/sharing_service.dart';
import 'services/auth_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize secure storage for sensitive data
  final secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Initialize Hive for local persistence
  await Hive.initFlutter();

  // Register adapters for custom classes
  Hive.registerAdapter(WorkoutAdapter());
  Hive.registerAdapter(ExerciseAdapter());
  Hive.registerAdapter(WorkoutSetAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(ExerciseTypeAdapter());
  Hive.registerAdapter(SetStatusAdapter());

  // Open Hive boxes
  final workoutsBox = await Hive.openBox<Workout>('workouts');
  final exercisesBox = await Hive.openBox<Exercise>('exercises');
  final userProfileBox = await Hive.openBox<UserProfile>('userProfile');
  final settingsBox = await Hive.openBox('settings');

  // Initialize shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Get application documents directory
  final appDocDir = await getApplicationDocumentsDirectory();

  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        // Services
        Provider<FlutterSecureStorage>.value(value: secureStorage),
        Provider<SharedPreferences>.value(value: sharedPreferences),
        Provider<Box<Workout>>.value(value: workoutsBox),
        Provider<Box<Exercise>>.value(value: exercisesBox),
        Provider<Box<UserProfile>>.value(value: userProfileBox),
        Provider<Box>.value(value: settingsBox),

        // Storage service (needs to be initialized early as other services depend on it)
        Provider<StorageService>(
          create: (_) => StorageService(
            workoutsBox: workoutsBox,
            exercisesBox: exercisesBox,
            userProfileBox: userProfileBox,
            settingsBox: settingsBox,
            secureStorage: secureStorage,
            appDocDir: appDocDir,
          ),
        ),

        // Auth service
        Provider<AuthService>(
          create: (context) => AuthService(
            secureStorage: secureStorage,
            storageService: Provider.of<StorageService>(context, listen: false),
          ),
        ),

        // Timer service with ChangeNotifier for reactivity
        ChangeNotifierProvider<TimerService>(
          create: (_) => TimerService(),
        ),

        // Progress service
        Provider<ProgressService>(
          create: (context) => ProgressService(
            storageService: Provider.of<StorageService>(context, listen: false),
          ),
        ),

        // Sharing service
        Provider<SharingService>(
          create: (context) => SharingService(
            storageService: Provider.of<StorageService>(context, listen: false),
            appDocDir: appDocDir,
          ),
        ),
      ],
      child: GymTrackerApp(),
    ),
  );
}

class GymTrackerApp extends StatefulWidget {
  @override
  _GymTrackerAppState createState() => _GymTrackerAppState();
}

class _GymTrackerAppState extends State<GymTrackerApp> {
  // Theme mode (light/dark)
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Get storage service
    final storageService = Provider.of<StorageService>(context, listen: false);

    // Load theme mode from settings
    final isDarkMode = await storageService.getSetting('isDarkMode', false);

    // Update theme mode
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });

    // Initialize app with sample data if first launch
    final isFirstLaunch = await storageService.getSetting('isFirstLaunch', true);
    if (isFirstLaunch) {
      await storageService.createSampleData();
      await storageService.saveSetting('isFirstLaunch', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppRoutes.home,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''), // English
        const Locale('es', ''), // Spanish
        const Locale('fr', ''), // French
        // Add more locales as needed
      ],
      home: HomeScreen(),
    );
  }
}