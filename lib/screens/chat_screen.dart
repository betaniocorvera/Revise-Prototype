// ─────────────────────────────────────────────────────────────────────────────
// The chat.
//
// Every transaction in this product — request, answer, booking, confirmation,
// completion — happens in one thread, and the four-step status bar across the
// top is the only place a stage is ever stated. That is the whole reason the
// Requests screen could be deleted: a request does not need its own page when
// it has a conversation.
//
// The screen is a fixed column — header, status, the action the stage is due,
// the messages, the composer — so the one control that is currently live can
// never scroll out of view. Bubbles are the one soft-cornered thing in the
// product besides the floating panel: two people talking above the page.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/tm_avatar.dart';
import 'package:tutormatch/widgets/tm_button.dart';
import 'package:tutormatch/widgets/tm_field.dart';
import 'package:tutormatch/widgets/tm_icon.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.thread, super.key});

  final Conversation thread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _booking = false;
  String? _day;
  String? _time;
  int? _rate;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    // Opening a thread is reading it. After the frame, because state is read
    // through the tree and changes it while it is being built otherwise.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppStateScope.read(context).markRead(widget.thread);
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (_message.text.trim().isEmpty) return;
    AppStateScope.read(context).sendMessage(widget.thread, _message.text);
    _message.clear();
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.base,
        curve: Motion.ease,
      );
    });
  }

  void _confirmBooking() {
    if (_day == null || _time == null || _rate == null) {
      setState(() => _bookingError =
          'Pick a day, a time and a rate — all three decide what gets booked.');
      return;
    }
    AppStateScope.read(context).bookSession(
      widget.thread,
      day: _day!,
      time: _time!,
      rate: _rate!,
    );
    setState(() {
      _booking = false;
      _bookingError = null;
      _day = null;
      _time = null;
      _rate = null;
    });
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final Conversation thread = widget.thread;
    final bool student = state.role == Role.student;
    final bool narrow = TMLayout.isNarrow(context);
    final String first = thread.firstCounterpartName;
    final List<ChatMessage> messages = thread.messages;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: <Widget>[
                _Header(
                  thread: thread,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                _StageBar(stage: thread.stage),
                _stageZone(context, state, thread, student: student, first: first),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: Space.lg),
                      itemCount: messages.isEmpty ? 1 : messages.length,
                      itemBuilder: (BuildContext context, int i) => messages.isEmpty
                          ? _EmptyThread(first: first, student: student)
                          : _MessageLine(message: messages[i]),
                    ),
                  ),
                ),
                _Composer(
                  controller: _message,
                  narrow: narrow,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── The stage, and whatever it is waiting on ───────────────────────────────

  Widget _zoneNote(StatusTone tone, String title, String body) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
      child: TMInlineNote(tone: tone, title: title, body: body),
    );
  }

  Widget _stageZone(
    BuildContext context,
    AppState state,
    Conversation thread, {
    required bool student,
    required String first,
  }) {
    switch (thread.stage) {
      case ChatStage.requestSent:
        if (student) {
          return _zoneNote(
            StatusTone.pending,
            'Waiting on $first.',
            'They have seen the request. Their answer arrives here first — the '
                'status above moves when it does.',
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
          child: Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            children: <Widget>[
              TMButton(
                label: 'Accept the request',
                icon: TMIconName.check,
                minHeight: Hit.min,
                onPressed: () {
                  state.acceptRequest(thread);
                  _toBottom();
                },
              ),
              TMButton(
                label: 'Decline',
                variant: TMButtonVariant.secondary,
                minHeight: Hit.min,
                onPressed: () {
                  state.declineRequest(thread);
                  _toBottom();
                },
              ),
            ],
          ),
        );

      case ChatStage.accepted:
        if (!student) {
          return _zoneNote(
            StatusTone.accepted,
            'Accepted — waiting on $first.',
            'They can pick a date and a time now. The booking appears here, with '
                'their rate, the moment they choose.',
          );
        }
        if (!_booking) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TMButton(
                  label: 'Book a session',
                  icon: TMIconName.arrowRight,
                  minHeight: Hit.min,
                  onPressed: () => setState(() => _booking = true),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Pick a date, a time and a rate — $first confirms afterwards.',
                  style: AppType.bodySmall.quieter,
                ),
              ],
            ),
          );
        }
        return _bookingForm(state, thread, first);

      case ChatStage.booked:
        if (student) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TMInlineNote(
                  tone: StatusTone.accepted,
                  title: 'Session booked.',
                  body: '${thread.bookingCopy}. ${thread.confirmed ? '$first confirmed it — nothing left to do before the lesson.' : '$first still has to confirm the slot; that will show here.'}',
                ),
                const SizedBox(height: Space.md),
                TMButton(
                  label: 'Mark as completed',
                  variant: thread.confirmed
                      ? TMButtonVariant.primary
                      : TMButtonVariant.secondary,
                  minHeight: Hit.min,
                  onPressed: () {
                    state.completeSession(thread);
                    _toBottom();
                  },
                ),
              ],
            ),
          );
        }
        if (!thread.confirmed) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TMButton(
                  label: 'Confirm session',
                  icon: TMIconName.check,
                  minHeight: Hit.min,
                  onPressed: () {
                    state.confirmSession(thread);
                    _toBottom();
                  },
                ),
                const SizedBox(height: Space.sm),
                Text(
                  '${thread.bookingCopy} — confirming tells $first the slot is '
                  'locked in.',
                  style: AppType.bodySmall.quieter,
                ),
              ],
            ),
          );
        }
        return _zoneNote(
          StatusTone.accepted,
          'Confirmed.',
          '$first marks the lesson complete afterwards — in this thread, so both '
              'sides see the same end.',
        );

      case ChatStage.completed:
        return _zoneNote(
          StatusTone.accepted,
          'Session completed.',
          'The thread stays so both sides can read how it went.',
        );

      case ChatStage.declined:
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TMInlineNote(
                tone: StatusTone.declined,
                title: student ? 'Request declined.' : 'You declined this request.',
                body: student
                    ? 'Nothing more happens on this thread. If you still want '
                        'lessons, go back and search — the pool is where you left it.'
                    : 'Their request is closed and they have been told. The thread '
                        'stays so the exchange is on the record.',
              ),
              if (student) ...<Widget>[
                const SizedBox(height: Space.md),
                TMButton(
                  label: 'Back to the inbox',
                  variant: TMButtonVariant.secondary,
                  minHeight: Hit.min,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ],
          ),
        );
    }
  }

  Widget _bookingForm(AppState state, Conversation thread, String first) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
      child: TMEntry(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TMMicroLabelText('Day'),
            const SizedBox(height: Space.md),
            TMTagRow<String?>(
              options: bookingDays,
              selected: _day,
              onSelect: (String? v) => setState(() {
                _day = v;
                _bookingError = null;
              }),
              labelOf: (String? v) => v ?? '',
            ),
            const SizedBox(height: Space.xl),
            const TMMicroLabelText('Time'),
            const SizedBox(height: Space.md),
            TMTagRow<String?>(
              options: bookingTimes,
              selected: _time,
              onSelect: (String? v) => setState(() {
                _time = v;
                _bookingError = null;
              }),
              labelOf: (String? v) => v ?? '',
            ),
            const SizedBox(height: Space.xl),
            const TMMicroLabelText('Rate'),
            const SizedBox(height: Space.md),
            TMTagRow<int?>(
              options: bookingRates,
              selected: _rate,
              onSelect: (int? v) => setState(() {
                _rate = v;
                _bookingError = null;
              }),
              labelOf: (int? v) => '\$${v ?? ''}/hr',
            ),
            if (_bookingError != null) ...<Widget>[
              const SizedBox(height: Space.md),
              Text(
                _bookingError!,
                style: AppType.bodySmall.tone(AppColors.alert),
              ),
            ],
            const SizedBox(height: Space.xl),
            Wrap(
              spacing: Space.md,
              runSpacing: Space.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                TMButton(
                  label: 'Confirm the booking',
                  minHeight: Hit.min,
                  onPressed: _confirmBooking,
                ),
                TMTextLink(
                  label: 'Cancel',
                  style: AppType.bodySmall,
                  onTap: () => setState(() {
                    _booking = false;
                    _bookingError = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Nothing is charged in this prototype — confirming writes the '
              'booking into this thread and stops there. $first confirms it next.',
              style: AppType.bodySmall.quieter,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header and status
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.thread, required this.onBack});

  final Conversation thread;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(
          children: <Widget>[
            TMButton(
              label: 'Back',
              variant: TMButtonVariant.quiet,
              icon: TMIconName.arrowLeft,
              iconLeading: true,
              minHeight: Hit.min,
              onPressed: onBack,
            ),
            const SizedBox(width: Space.md),
            TMAvatar(name: thread.counterpartName, size: 42),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    thread.counterpartName,
                    style: AppType.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    '${thread.subject} · matched ${thread.score}/100',
                    style: AppType.bodySmall.quieter,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four steps, as four rules. Done and current are accent; the rest are
/// hairline. A declined thread has no current step, and the bar says so by
/// showing nothing filled.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage});

  final ChatStage stage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Status: ${stage.label}. '
          'Steps: ${ChatStageCopy.steps.join(', ')}.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < ChatStageCopy.steps.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i < ChatStageCopy.steps.length - 1 ? Space.sm : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        height: 3,
                        child: ColoredBox(
                          color: i <= stage.step ? AppColors.accent : AppColors.rule,
                        ),
                      ),
                      const SizedBox(height: Space.xs + 1),
                      Text(
                        ChatStageCopy.steps[i],
                        style: AppType.micro.copyWith(fontSize: 10).tone(
                              i == stage.step
                                  ? AppColors.ink
                                  : i < stage.step
                                      ? AppColors.inkSecondary
                                      : AppColors.inkMuted,
                            ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The thread
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.first, required this.student});

  final String first;
  final bool student;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Nothing said yet.', style: AppType.sectionTitle),
          const SizedBox(height: Space.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              student
                  ? 'Write the first message to $first. A day and a goal in it — '
                      '"Thursday after six, the mechanics questions" — gets an '
                      'answer faster than "hi".'
                  : 'Write the first message to $first. Naming the hour that '
                      'suits you gets an answer faster than "hi".',
              style: AppType.bodySmall.quieter,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.lg),
        child: Row(
          children: <Widget>[
            const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: AppColors.rule))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Text(
                message.text,
                style: AppType.bodySmall.quieter,
                textAlign: TextAlign.center,
              ),
            ),
            const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: AppColors.rule))),
          ],
        ),
      );
    }

    final bool mine = message.mine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs, horizontal: Space.lg),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              decoration: BoxDecoration(
                color: mine ? AppColors.accent : AppColors.paperRaised,
                border: Border.all(
                  color: mine ? AppColors.accent : AppColors.rule,
                ),
                borderRadius: Radii.softAll,
              ),
              child: Text(
                message.text,
                style: AppType.body.tone(
                  mine ? AppColors.onAccent : AppColors.inkSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xxs + 1),
          Text(message.time, style: AppType.micro.copyWith(fontSize: 10).tone(AppColors.inkMuted)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The composer
// ─────────────────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.narrow,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool narrow;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final Widget field = TMTextField(
      label: 'Message',
      controller: controller,
      hint: 'Say which of the shared hours you want and what the first lesson '
          'should cover.',
      maxLines: 3,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => onSend(),
    );
    final Widget button = TMButton(
      label: 'Send',
      icon: TMIconName.arrowRight,
      onPressed: onSend,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  field,
                  const SizedBox(height: Space.md),
                  button,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(child: field),
                  const SizedBox(width: Space.lg),
                  button,
                ],
              ),
      ),
    );
  }
}
