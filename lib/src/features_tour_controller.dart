part of 'features_tour.dart';

class FeaturesTourController {
  /// Internal preferences.
  static SharedPreferences? _prefs;

  /// Create a controller for FeaturesTour with unique [pageName]. This value is
  /// used to store the state of the current page, so please do not change it
  /// if you don't want to re-show the instructions.
  FeaturesTourController(this.pageName) {
    FeaturesTour._controllers.add(this);
  }

  /// Get auto increment index number.
  double get _getAutoIndex => _index++;
  double _index = 0;

  /// Name of this page.
  final String pageName;

  /// The internal list of the states.
  final SplayTreeMap<double, FeaturesTour> _states =
      SplayTreeMap.from({}, (a, b) => a.compareTo(b));

  final _globalKeys = <double, GlobalKey>{};

  /// The internal list of the introduced states.
  final Set<double> _introducedIndexes = {};

  /// Register the current FeaturesTour state.
  void _register(FeaturesTour state) {
    if (!_states.containsKey(state.index)) {
      printDebug(
          '`$pageName`: register index ${state.index} => total: ${_states.length + 1}');
    }
    _states[state.index] = state;
    _globalKeys[state.index] = state.key as GlobalKey;
  }

  /// Unregister the current FeaturesTour state.
  void _unregister(FeaturesTour state) {
    if (_states.containsKey(state.index)) {
      printDebug(
          '`$pageName`: unregister index ${state.index} => total: ${_states.length - 1}');
    }
    _states.remove(state.index);
    _introducedIndexes.add(state.index);
  }

  /// Start the tour. This packaga automatically save the state of the widget,
  /// so it will skip the showed widget.
  ///
  /// All of this parameters will be applied to this controller (this page only)
  /// if it is set. Otherwise, it will depends on the global configurations.
  ///
  /// The [context] will be used to wait for the page transition animation to complete.
  /// After that, delay for [delay] duration before starting the tour, it makes
  /// sure that all the widgets are rendered correctly. To enable/disable all the tours,
  /// just need to set the [force] to `true` or `false`, it will aslo force to show
  /// all the pre-dialogs, **you have to set this value to `null` before releasing to
  /// make the [FeaturesTour] works as expected**
  ///
  /// You can set the first index by setting [waitForFirstIndex] with timeout by
  /// setting [waitForFirstTimeout]. If the timeout is exceeded, the smallest available
  /// index will be used.
  ///
  /// You can also configure the predialog by using [predialogConfig], this dialog
  /// will show to ask the user want to start the tour or not.
  ///
  /// Ex:
  /// ``` dart
  /// tourController.start(context: context, force: true);
  /// ```
  Future<void> start(
    BuildContext context, {
    double? waitForFirstIndex,
    Duration waitForFirstTimeout = const Duration(seconds: 3),
    Duration delay = const Duration(milliseconds: 500),
    bool? force,
    PredialogConfig? predialogConfig,
  }) async {
    // Wait until the next frame of the application's UI has been drawn.
    await null;

    final addBlank = ' $pageName ';
    printDebug(''.padLeft(50, '='));
    printDebug('${addBlank.padLeft(25 + (addBlank.length / 2).round(), '=')}'
        '${''.padRight(25 - (addBlank.length / 2).round(), '=')}');
    printDebug(''.padLeft(50, '='));

    if (_states.isEmpty) {
      printDebug('The page $pageName has no state');
      return;
    }

    // ignore: use_build_context_synchronously
    if (!context.mounted) {
      printDebug('The page $pageName context is not mounted');
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();

    // ignore: use_build_context_synchronously
    await _waitForTransition(context); // Main page transition

    // Wait for `delay` duration before starting the tours.
    await Future.delayed(delay);

    // Get default value from global `force`.
    force ??= FeaturesTour._force;

    // Ignore all the tours
    if (force == null && await SharedPrefs.getDismissAllTours() == true) {
      printDebug('All tours have been dismissed');
      _removePage(markAsShowed: true);
      return;
    }

    if (!_shouldShowIntroduction() && force != true) {
      printDebug('There is no new `FeaturesTour` -> Completed');
      return;
    }

    // ignore: use_build_context_synchronously
    final result = await _showPredialog(context, force, predialogConfig);

    // User pressed dismiss button.
    if (result == null) {
      _removePage(markAsShowed: true);
      return;
    }

    // User pressed later button.
    if (result == false) {
      return;
    }

    // Watching for the `waitForIndex` value.
    FeaturesTour? waitForIndexState;

    // Waiting for the first index.
    if (waitForFirstIndex != null) {
      waitForIndexState =
          await _waitForIndex(waitForFirstIndex, waitForFirstTimeout);
    }

    printDebug('Start the tour');
    while (_states.isNotEmpty) {
      final FeaturesTour state;

      if (waitForIndexState == null) {
        state = _popState();
      } else {
        state = waitForIndexState;
      }

      final waitForIndex = state.waitForIndex;
      final waitForTimeout = state.waitForTimeout;
      final key = FeaturesTour._getPrefKey(pageName, state);
      printDebug('Start widget with key $key:');

      // ignore: use_build_context_synchronously
      if (!context.mounted) {
        printDebug('   -> The parent widget was unmounted');
        break;
      }

      bool shouldShowIntroduce;
      if (force != null) {
        printDebug('`force` is $force, so the introduction must respect it.');
        shouldShowIntroduce = force;
      } else {
        printDebug('`force` is null, so the introduce will act like normal.');
        final isShown = _prefs!.getBool(key);
        shouldShowIntroduce = isShown != true;
      }

      if (_introducedIndexes.contains(state.index)) {
        shouldShowIntroduce = false;
      }

      if (!shouldShowIntroduce) {
        printDebug(
            '   -> This widget has been introduced -> move to the next widget.');
        await _removeState(state, false);
        continue;
      }

      // Wait for the child widget transition to complete.
      // ignore: use_build_context_synchronously
      await _waitForTransition(state._context);

      final result = await state.showIntroduce(_states.isEmpty);

      switch (result) {
        case IntroduceResult.disabled:
        case IntroduceResult.notMounted:
          printDebug(
            '   -> This widget has been cancelled with result: ${result.name}',
          );
          await _removeState(state, false);
          break;
        case IntroduceResult.done:
        case IntroduceResult.next:
          printDebug('   -> Move to next widget');
          await _removeState(state, true);
          break;
        case IntroduceResult.skip:
          printDebug('   -> Skip this tour');
          await _removeState(state, true);
          await _removePage(markAsShowed: true);
          break;
      }

      // Wait for the next state to appear if `waitForIndex` is non-null.
      if (waitForIndex != null) {
        printDebug(
            'The `waitForIndex` is non-null => Waiting for the next index: $waitForIndex ...');

        // Show the cover to avoid user tapping the screen.
        // ignore: use_build_context_synchronously
        showCover(context);

        waitForIndexState = await _waitForIndex(waitForIndex, waitForTimeout);

        // Hide the cover.
        // ignore: use_build_context_synchronously
        hideCover(context);

        if (waitForIndexState == null) {
          printDebug(
              '   -> Cannot not wait for next index because timeout is reached. Use orderd values instead.');
        } else {
          printDebug('   -> Next index is available with state: $state');
        }
      } else {
        waitForIndexState = null;
      }
    }

    printDebug('This tour has been completed');
  }

  /// Show the predialog if possible.
  Future<bool?> _showPredialog(
    BuildContext context,
    bool? force,
    PredialogConfig? config,
  ) async {
    // Should show the predialog or not.
    bool shouldShowPredialog = true;

    // Respect `force`.
    if (force != null) {
      printDebug('`force` is $force, so the dialog must respect it.');
      shouldShowPredialog = force;
    }

    if (shouldShowPredialog) {
      printDebug('Should show predialog return true');
      config ??= PredialogConfig.global;

      if (config.enabled) {
        printDebug('Predialog is enabled');

        final bool? predialogResult;
        if (config.modifiedDialogResult != null) {
          Completer<bool> completer = Completer();
          // ignore: use_build_context_synchronously
          completer.complete(config.modifiedDialogResult!(context));
          predialogResult = await completer.future;
        } else {
          // ignore: use_build_context_synchronously
          predialogResult = await predialog(
            context,
            config,
          );
        }

        if (predialogResult == null) {
          printDebug('User dismissed to show the introduction');
          return null;
        }

        if (predialogResult == false) {
          printDebug('User cancelled to show the introduction');
          return false;
        }
      } else {
        printDebug('Predialog is not enabled');
      }
    } else {
      printDebug('Should show predialog return false');
    }

    return true;
  }

  /// Wait for the next index to be available.
  Future<FeaturesTour?> _waitForIndex(
    double index,
    Duration timeout,
  ) async {
    Stopwatch stopwatch = Stopwatch()..start();
    while (true) {
      for (final MapEntry(key: i, value: state) in _states.entries) {
        if (i == index) return state;
      }

      // Timeout is reached.
      if (stopwatch.elapsed >= timeout) return null;

      // Delay for 100 milliseconds.
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Wait until the page transition animation is complete.
  Future<void> _waitForTransition(BuildContext context) async {
    if (!context.mounted) return;

    printDebug('Waiting for the page transition to complete...');
    final modalRoute = ModalRoute.of(context)?.animation;

    if (modalRoute != null &&
        !modalRoute.isCompleted &&
        !modalRoute.isDismissed) {
      Completer completer = Completer();
      modalRoute.addStatusListener((status) {
        switch (status) {
          case AnimationStatus.forward:
          case AnimationStatus.reverse:
            break;
          case AnimationStatus.dismissed:
          case AnimationStatus.completed:
            if (!completer.isCompleted) completer.complete();
        }
      });
      await completer.future;
    }
    printDebug('The page transition completed');
  }

  /// Removes all controllers for specific `pageName`.
  Future<void> _removePage({bool markAsShowed = true}) async {
    if (_states.isEmpty) {
      printDebug('Page $pageName has already been removed');
      return;
    }

    _prefs ??= await SharedPreferences.getInstance();

    while (_states.isNotEmpty) {
      final state = _states.values.first;
      await _removeState(state, markAsShowed);
    }

    printDebug('Remove page: $pageName');
  }

  FeaturesTour _popState() {
    return _states.remove(_states.firstKey())!;
  }

  /// Removes specific state of this page.
  Future<void> _removeState(
    FeaturesTour state,
    bool markAsIntroduced,
  ) async {
    if (markAsIntroduced) {
      final key = FeaturesTour._getPrefKey(pageName, state);
      await _prefs!.setBool(key, true);
    }
    _unregister(state);
  }

  /// Checks whether there is any new features available to show predialog.
  bool _shouldShowIntroduction() {
    for (final state in _states.values) {
      final key = FeaturesTour._getPrefKey(pageName, state);
      if (!_prefs!.containsKey(key) && state._context.mounted) {
        return true;
      }
    }

    return false;
  }
}
