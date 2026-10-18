// ─────────────────────────────────────────────────────────────────────────────
// Every screen, rendered at three widths.
//
// This is not a behaviour test. It is the check that no screen overflows the
// frame at the sizes the product claims to support: a small Android phone
// (360), a mid-size phone (390) where the week grid is at its tightest, and a
// laptop (1440) where the two-column shells and the dashboard rail engage.
//
// An overflow is a hard failure here, because a RenderFlex overflow stripe is
// the one visual defect that a screenshot review reliably misses on the machine
// it was taken on and never misses on somebody else's.
//
// Fonts: the two faces are bundled and declared in pubspec.yaml, so a test
// measures the same text the browser will draw. (Before they were bundled, a
// test environment measured with a one-em-per-glyph fallback — roughly twice as
// wide as any real face — and reported overflows on layouts that are in fact
// comfortable.)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/screens/chat_screen.dart';
import 'package:tutormatch/screens/dashboard_screen.dart';
import 'package:tutormatch/screens/landing_screen.dart';
import 'package:tutormatch/screens/login_screen.dart';
import 'package:tutormatch/screens/messages_screen.dart';
import 'package:tutormatch/screens/person_screen.dart';
import 'package:tutormatch/screens/profile_screen.dart';
import 'package:tutormatch/screens/register_screen.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';

const List<Size> _sizes = <Size>[
  Size(360, 780), // the narrow phone the week grid has to survive
  Size(390, 844), // the common phone
  Size(1440, 900), // a laptop, where the two-column shells engage
];

void main() {
  // The two faces are bundled, but `flutter test` does not load font assets on
  // its own: without this the whole suite measures a fallback in which every
  // glyph is exactly one em wide, and reports overflows on layouts that are in
  // fact comfortable. Loading them here means the numbers below are the numbers
  // the browser will lay out.
  setUpAll(_loadBundledFonts);

  /// Renders one screen at one width in the app's real theme and state scope.
  ///
  /// Every layout error is captured with its full diagnostic, not just the first
  /// one: a screen can overflow in three places and reporting only the first
  /// turns one fix-and-rerun into three.
  Future<void> render(
    WidgetTester tester,
    Widget screen,
    Size size, {
    AppState? state,
    String? label,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        AppStateScope(
          notifier: state ?? AppState(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: screen,
          ),
        ),
      );
      // Long enough for the searched state's skeleton delay and every short
      // state transition to have finished.
      await tester.pump(const Duration(milliseconds: 1200));
    } finally {
      FlutterError.onError = previous;
    }

    final String where = '${label ?? screen.runtimeType} at ${size.width.toInt()}px';
    for (final FlutterErrorDetails details in errors) {
      // ignore: avoid_print
      print('LAYOUT FAILURE — $where\n${details.toString()}\n');
    }
    expect(
      errors.map((FlutterErrorDetails d) => d.exceptionAsString()).toList(),
      isEmpty,
      reason: where,
    );
  }

  /// A tab screen (search, messages, profile) is a column that normally lives
  /// inside the dashboard's scroll view. Hosting it the same way here means the
  /// test measures the width it gets in the product, not the full window.
  Widget tab(Widget child) => Scaffold(
        backgroundColor: AppColors.paper,
        body: SingleChildScrollView(child: child),
      );

  for (final Size size in _sizes) {
    final String at = '@${size.width.toInt()}px';

    testWidgets('landing renders $at', (WidgetTester tester) async {
      await render(tester, const LandingScreen(), size, label: 'Landing');
    });

    testWidgets('register renders for both roles $at', (WidgetTester tester) async {
      await render(tester, const RegisterScreen(initialRole: Role.student), size,
          label: 'Register (student)');
      await render(tester, const RegisterScreen(initialRole: Role.tutor), size,
          label: 'Register (tutor)');
    });

    testWidgets('sign in renders $at', (WidgetTester tester) async {
      await render(tester, const LoginScreen(initialRole: Role.student), size,
          label: 'Login');
    });

    testWidgets('the dashboard renders in every state $at', (WidgetTester tester) async {
      await render(tester, const DashboardScreen(), size,
          label: 'Dashboard, nothing searched yet');

      final AppState tutor = AppState()..role = Role.tutor;
      await render(tester, const DashboardScreen(), size,
          state: tutor, label: 'Dashboard, tutor side');

      final AppState searched = AppState()..searched = true;
      await render(tester, const DashboardScreen(), size,
          state: searched, label: 'Dashboard, after a search');

      final AppState impossible = AppState()
        ..searched = true
        ..filters = const MatchFilters(maxRate: 25);
      await render(tester, const DashboardScreen(), size,
          state: impossible, label: 'Dashboard, a filter that removes everybody');

      final AppState asked = AppState()
        ..searched = true
        ..openThread(sampleTutors.first, score: 71, asRequest: true);
      await render(tester, const DashboardScreen(), size,
          state: asked, label: 'Dashboard, one request already sent');
    });

    testWidgets('a person page renders, including with no shared hours $at',
        (WidgetTester tester) async {
      await render(
        tester,
        PersonScreen(result: landingSpecimen()),
        size,
        label: 'Person, best match',
      );

      final List<MatchResult> students = rank(sampleStudents, demoTutorProfile);
      final AppState tutor = AppState()..role = Role.tutor;
      await render(
        tester,
        PersonScreen(result: students.first),
        size,
        state: tutor,
        label: 'Person, tutor side',
      );
      await render(
        tester,
        PersonScreen(
          result: students.firstWhere((MatchResult r) => r.score.overlapSlots == 0),
        ),
        size,
        state: tutor,
        label: 'Person, no shared hours',
      );
    });

    testWidgets('the inbox renders on both sides, and empty $at',
        (WidgetTester tester) async {
      await render(tester, tab(MessagesScreen(onGoToSearch: () {})), size,
          label: 'Messages (student)');

      final AppState tutor = AppState()..role = Role.tutor;
      await render(tester, tab(MessagesScreen(onGoToSearch: () {})), size,
          state: tutor, label: 'Messages (tutor)');

      final AppState quiet = AppState()..conversations.clear();
      await render(tester, tab(MessagesScreen(onGoToSearch: () {})), size,
          state: quiet, label: 'Messages, no conversations yet');
    });

    testWidgets('every chat stage renders, on both sides $at',
        (WidgetTester tester) async {
      for (final Conversation thread in studentConversations()) {
        await render(
          tester,
          ChatScreen(thread: thread),
          size,
          label: 'Chat, student side, ${thread.stage.label}',
        );
      }

      final AppState tutor = AppState()..role = Role.tutor;
      for (final Conversation thread in tutorConversations()) {
        await render(
          tester,
          ChatScreen(thread: thread),
          size,
          state: tutor,
          label: 'Chat, tutor side, ${thread.stage.label}',
        );
      }

      final Conversation declined = studentConversations()[1]
        ..stage = ChatStage.declined;
      await render(tester, ChatScreen(thread: declined), size,
          label: 'Chat, declined');

      final Conversation blank =
          AppState().openThread(sampleTutors.first, score: 82);
      await render(tester, ChatScreen(thread: blank), size,
          label: 'Chat, nothing said yet');
    });

    testWidgets('the profile renders on both sides $at', (WidgetTester tester) async {
      await render(tester, tab(const ProfileScreen()), size,
          label: 'Profile (student)');

      final AppState tutor = AppState()..role = Role.tutor;
      await render(tester, tab(const ProfileScreen()), size,
          state: tutor, label: 'Profile (tutor)');
    });
  }
}

/// Registers the two bundled families under the names the theme asks for, at
/// every weight the type scale uses.
Future<void> _loadBundledFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final FontLoader loader = FontLoader(name);
    for (final String asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family('Spectral', <String>[
    'assets/fonts/Spectral-Regular.ttf',
    'assets/fonts/Spectral-Italic.ttf',
    'assets/fonts/Spectral-SemiBold.ttf',
    'assets/fonts/Spectral-Bold.ttf',
  ]);
  await family('Public Sans', <String>['assets/fonts/PublicSans-Variable.ttf']);
}
