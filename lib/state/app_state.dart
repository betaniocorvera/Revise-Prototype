// ─────────────────────────────────────────────────────────────────────────────
// In-memory application state.
//
// This is the ONLY place the UI keeps anything. There is no persistence, no
// session, no token and no network: reload the page and you are back to the
// demo profiles at the bottom of mock_data.dart. That is deliberate — it keeps
// the interface honest about being an interface.
//
// Everything here is a plain ChangeNotifier behind an InheritedNotifier. No
// state-management package, because the whole surface is one object.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/theme/app_theme.dart';

class AppState extends ChangeNotifier {
  /// Which side of the marketplace you are standing on. Set by register and
  /// sign-in; it decides whose pool you search and whose inbox you read. The
  /// profile's role travels with it, because the two disagreeing is exactly the
  /// kind of bug that shows up on somebody else's screen and not yours.
  Role _role = Role.student;
  Role get role => _role;
  set role(Role value) {
    if (value == _role) return;
    _role = value;
    _profile = _profile.copyWith(role: value);
    notifyListeners();
  }

  Profile _profile = demoStudentProfile;
  Profile get profile => _profile;
  set profile(Profile value) {
    _profile = value;
    notifyListeners();
  }

  MatchFilters _filters = const MatchFilters();
  MatchFilters get filters => _filters;
  set filters(MatchFilters value) {
    _filters = value;
    notifyListeners();
  }

  /// False until somebody actually runs a search. The product's one promise
  /// about the pool is that it is shown only when asked for — nothing is
  /// ranked behind the person's back, and the dashboard opens on an empty state.
  bool _searched = false;
  bool get searched => _searched;
  set searched(bool value) {
    if (value == _searched) return;
    _searched = value;
    notifyListeners();
  }

  // ── The pool ───────────────────────────────────────────────────────────────

  /// The pool the current role searches. A student searches tutors.
  List<Candidate> get pool =>
      _role == Role.student ? sampleTutors : sampleStudents;

  /// A one-line description of the answers the ranking actually used. Shown on
  /// the results, so the label is never a vague assurance.
  String get profileSummary {
    final List<bool> a = _profile.availability;
    bool anyDayAt(int part) {
      for (int day = 0; day < Week.days.length; day++) {
        if (a[Week.index(day, part)]) return true;
      }
      return false;
    }

    final List<String> parts = <String>[
      for (int p = 0; p < Week.partLong.length; p++)
        if (anyDayAt(p)) Week.partLong[p],
    ];
    final String where = parts.isEmpty ? 'no set hours' : parts.join(' and ');
    final String money = _role == Role.student
        ? 'up to \$${_profile.budget}/hr'
        : '\$${_profile.budget}/hr';
    return '$where, ${_profile.mode.label.toLowerCase()}, $money';
  }

  /// Resets the filters to "show me everything ranked". Used by the results
  /// footer and by the empty state.
  void clearFilters() => filters = const MatchFilters();

  /// Applies the adjustment the empty state suggested.
  void relaxFilters(MatchFilters relaxed) => filters = relaxed;

  // ── Profile completeness ───────────────────────────────────────────────────

  /// The eight answers a stranger can read on the profile. The photo is the
  /// ninth and is stubbed in this prototype, so it is not counted; format and
  /// price always have a value, because the controls cannot be left empty.
  static const int profileAnswerCount = 8;

  /// The missing answers in the words of the controls, in reading order. Empty
  /// means the profile is complete.
  List<String> get profileMissing => <String>[
        if (_profile.name.trim().isEmpty) 'your name',
        if (_profile.bio.trim().isEmpty) 'a short bio',
        if (_profile.subjects.isEmpty) 'the subjects',
        if (!_profile.availability.contains(true)) 'your weekly hours',
        if (_profile.style.trim().isEmpty) 'how you work',
        if (_profile.goal.trim().isEmpty) 'what you are aiming at',
      ];

  /// 0-100. Complete is 100 and nothing on the dashboard asks for anything.
  int get profileCompleteness =>
      ((profileAnswerCount - profileMissing.length) / profileAnswerCount * 100)
          .round();

  // ── Conversations ──────────────────────────────────────────────────────────

  final List<Conversation> _studentThreads = studentConversations();
  final List<Conversation> _tutorThreads = tutorConversations();

  /// The inbox for the current role. Mutated in place by the chat screen —
  /// this is the sample data and the app's only "server".
  List<Conversation> get conversations =>
      _role == Role.student ? _studentThreads : _tutorThreads;

  int get unreadMessages =>
      conversations.fold(0, (int sum, Conversation c) => sum + c.unread);

  /// The thread with somebody, if there is one. A person has at most one open
  /// transaction with you in this prototype, so the counterpart is the key.
  Conversation? conversationWith(String counterpartId) {
    for (final Conversation thread in conversations) {
      if (thread.counterpartId == counterpartId) return thread;
    }
    return null;
  }

  /// Starts the thread with somebody in the pool, or returns the one that is
  /// already open. [asRequest] writes the request line that makes the first
  /// step of the status bar literally true; "Message" opens the same thread
  /// without it, and the empty chat says what to do next.
  Conversation openThread(
    Candidate counterpart, {
    required int score,
    bool asRequest = false,
  }) {
    final Conversation? existing = conversationWith(counterpart.id);
    if (existing != null) return existing;

    final Conversation thread = Conversation(
      id: 'c-${counterpart.id}',
      counterpartId: counterpart.id,
      counterpartName: counterpart.name,
      counterpartRole: counterpart.role,
      subject: counterpart.subjects.isEmpty ? 'Lessons' : counterpart.subjects.first,
      score: score,
      stage: ChatStage.requestSent,
      messages: <ChatMessage>[
        if (asRequest)
          ChatMessage.system(
            'Request sent · ${counterpart.subjects.take(2).join(' and ')}',
            time: 'Now',
          ),
      ],
    );
    conversations.add(thread);
    notifyListeners();
    return thread;
  }

  void markRead(Conversation thread) {
    if (thread.unread == 0) return;
    thread.unread = 0;
    notifyListeners();
  }

  void sendMessage(Conversation thread, String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    thread.messages.add(ChatMessage(trimmed, mine: true, time: 'Now'));
    thread.lastTime = 'Now';
    notifyListeners();
  }

  void acceptRequest(Conversation thread) {
    if (thread.stage != ChatStage.requestSent) return;
    thread.stage = ChatStage.accepted;
    thread.lastTime = 'Now';
    thread.messages.add(
      ChatMessage.system(
        'Request accepted · ${thread.firstCounterpartName} can book a time now',
        time: 'Now',
      ),
    );
    notifyListeners();
  }

  void declineRequest(Conversation thread) {
    if (thread.stage != ChatStage.requestSent) return;
    thread.stage = ChatStage.declined;
    thread.lastTime = 'Now';
    thread.messages.add(
      ChatMessage.system(
        'Request declined · nothing more happens on this thread',
        time: 'Now',
      ),
    );
    notifyListeners();
  }

  void bookSession(
    Conversation thread, {
    required String day,
    required String time,
    required int rate,
  }) {
    if (thread.stage != ChatStage.accepted) return;
    thread.stage = ChatStage.booked;
    thread.bookingDay = day;
    thread.bookingTime = time;
    thread.bookingRate = rate;
    thread.lastTime = 'Now';
    thread.messages.add(
      ChatMessage.system('Session booked · $day, $time, \$$rate/hr', time: 'Now'),
    );
    notifyListeners();
  }

  void confirmSession(Conversation thread) {
    if (thread.stage != ChatStage.booked || thread.confirmed) return;
    thread.confirmed = true;
    thread.messages.add(
      ChatMessage.system('You confirmed the session', time: 'Now'),
    );
    notifyListeners();
  }

  void completeSession(Conversation thread) {
    if (thread.stage != ChatStage.booked) return;
    thread.stage = ChatStage.completed;
    thread.lastTime = 'Now';
    thread.messages.add(ChatMessage.system('Session completed', time: 'Now'));
    notifyListeners();
  }
}

/// Reads [AppState] from the tree and rebuilds the caller when it changes.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final AppStateScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope above this widget.');
    return scope!.notifier!;
  }

  /// For widgets that only need to call a method, never to rebuild.
  static AppState read(BuildContext context) {
    final AppStateScope? scope =
        context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope above this widget.');
    return scope!.notifier!;
  }
}
