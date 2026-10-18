// ─────────────────────────────────────────────────────────────────────────────
// TutorMatch A.I. — entry point.
//
// Interface only. There is no backend, no database, no network call and no real
// K-nearest-neighbours pass; every tutor, student, score and review comes from
// lib/data/mock_data.dart. Google sign-in and email/password both simply move to
// the dashboard, which is the entire behaviour they are asked to have.
//
// Routing is one switch in [onGenerateRoute]. No router package: the six screens
// take plain arguments, and the two that need one take the exact object the
// previous screen was already showing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/screens/chat_screen.dart';
import 'package:tutormatch/screens/dashboard_screen.dart';
import 'package:tutormatch/screens/landing_screen.dart';
import 'package:tutormatch/screens/login_screen.dart';
import 'package:tutormatch/screens/person_screen.dart';
import 'package:tutormatch/screens/register_screen.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';

void main() => runApp(const TutorMatchApp());

/// Route names, in one place so a typo is a compile error rather than a blank
/// screen. Arguments are the only state passed between pages.
abstract final class Routes {
  static const String landing = '/';
  static const String register = '/register';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String person = '/person';
  static const String chat = '/chat';
}

class TutorMatchApp extends StatefulWidget {
  const TutorMatchApp({super.key});

  @override
  State<TutorMatchApp> createState() => _TutorMatchAppState();
}

class _TutorMatchAppState extends State<TutorMatchApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: MaterialApp(
        title: 'TutorMatch A.I.',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: Routes.landing,
        onGenerateRoute: _route,
        // Keyboard order follows reading order, which matters most in the
        // profile's edit form and the booking form inside a chat.
        builder: (BuildContext context, Widget? child) => FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Route<void> _route(RouteSettings settings) {
    final Object? args = settings.arguments;

    Route<void> build(Widget child) =>
        TMTransitions.page<void>(child, name: settings.name);

    switch (settings.name) {
      case Routes.register:
        final Role role = args is Role ? args : Role.student;
        return build(RegisterScreen(initialRole: role));
      case Routes.login:
        final Role role = args is Role ? args : Role.student;
        return build(LoginScreen(initialRole: role));
      case Routes.dashboard:
        return build(const DashboardScreen());
      case Routes.person:
        if (args is MatchResult) return build(PersonScreen(result: args));
        return build(const DashboardScreen());
      case Routes.chat:
        if (args is Conversation) return build(ChatScreen(thread: args));
        return build(const DashboardScreen());
      case Routes.landing:
      default:
        return build(const LandingScreen());
    }
  }
}
