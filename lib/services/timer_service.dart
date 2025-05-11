import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gymgee/models/workout_set.dart';

enum TimerState {
  idle,
  running,
  paused,
  finished
}

class TimerService extends ChangeNotifier {
  // Timer controller
  Timer? _timer;

  // Timer state
  TimerState _state = TimerState.idle;
  Duration _elapsed = Duration.zero;
  Duration _target = Duration.zero;
  WorkoutSet? _currentSet;

  // Rest timer
  Timer? _restTimer;
  Duration _restElapsed = Duration.zero;
  Duration _restTarget = Duration.zero;
  bool _isInRest = false;

  // Getters
  TimerState get state => _state;
  Duration get elapsed => _elapsed;
  Duration get remaining => _target - _elapsed;
  double get progress => _target.inMilliseconds > 0
      ? _elapsed.inMilliseconds / _target.inMilliseconds
      : 0;
  bool get isRunning => _state == TimerState.running;
  bool get isPaused => _state == TimerState.paused;
  bool get isFinished => _state == TimerState.finished;
  bool get isIdle => _state == TimerState.idle;

  // Rest timer getters
  Duration get restElapsed => _restElapsed;
  Duration get restRemaining => _restTarget - _restElapsed;
  double get restProgress => _restTarget.inMilliseconds > 0
      ? _restElapsed.inMilliseconds / _restTarget.inMilliseconds
      : 0;
  bool get isInRest => _isInRest;

  // Public methods

  // Start a timed exercise
  void startTimer(WorkoutSet set) {
    if (set.plannedDuration == null) {
      throw ArgumentError('Cannot start timer for non-timed set');
    }

    // Reset timer state
    _state = TimerState.running;
    _elapsed = Duration.zero;
    _target = set.plannedDuration!;
    _currentSet = set;

    // Start the workout set
    set.start();

    // Start timer that ticks every 10ms for smooth UI updates
    _timer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      _elapsed += Duration(milliseconds: 10);
      notifyListeners();

      // Check if we've reached the target
      if (_elapsed >= _target) {
        _completeTimer();
      }
    });

    notifyListeners();
  }

  // Pause the timer
  void pauseTimer() {
    if (_state != TimerState.running) return;

    _timer?.cancel();
    _timer = null;
    _state = TimerState.paused;

    // Record the pause in the set
    _currentSet?.recordPause();

    notifyListeners();
  }

  // Resume the timer
  void resumeTimer() {
    if (_state != TimerState.paused) return;

    _state = TimerState.running;

    // Record the resume in the set
    _currentSet?.recordResume();

    // Restart the timer
    _timer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      _elapsed += Duration(milliseconds: 10);
      notifyListeners();

      // Check if we've reached the target
      if (_elapsed >= _target) {
        _completeTimer();
      }
    });

    notifyListeners();
  }

  // Stop the timer
  void stopTimer({bool markAsCompleted = false}) {
    _timer?.cancel();
    _timer = null;

    if (_currentSet != null) {
      if (markAsCompleted) {
        _currentSet!.completeWithDuration(_elapsed);
        _state = TimerState.finished;
      } else {
        // If not completed, record the effective duration
        final effectiveDuration = _currentSet!.getEffectiveDuration();
        _currentSet!.completeWithDuration(
            effectiveDuration,
            notes: "Stopped at ${effectiveDuration.inSeconds}s"
        );
        _state = TimerState.idle;
      }
    } else {
      _state = TimerState.idle;
    }

    notifyListeners();
  }

  // Reset the timer
  void resetTimer() {
    _timer?.cancel();
    _timer = null;
    _state = TimerState.idle;
    _elapsed = Duration.zero;
    _currentSet = null;

    notifyListeners();
  }

  // Start the rest timer
  void startRestTimer(Duration duration) {
    _restTimer?.cancel();

    _isInRest = true;
    _restElapsed = Duration.zero;
    _restTarget = duration;

    _restTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
      _restElapsed += Duration(milliseconds: 10);
      notifyListeners();

      // Check if rest is complete
      if (_restElapsed >= _restTarget) {
        _completeRestTimer();
      }
    });

    notifyListeners();
  }

  // Skip the rest period
  void skipRest() {
    _restTimer?.cancel();
    _restTimer = null;
    _isInRest = false;

    notifyListeners();
  }

  // Private methods

  // Handle timer completion
  void _completeTimer() {
    _timer?.cancel();
    _timer = null;
    _state = TimerState.finished;

    // Mark the set as completed
    _currentSet?.completeWithDuration(_target);

    // If there's a rest period configured, start it
    if (_currentSet?.restTime != null) {
      startRestTimer(_currentSet!.restTime!);
    }

    notifyListeners();
  }

  // Handle rest timer completion
  void _completeRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _isInRest = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}