// ─────────────────────────────────────────────────────────────────────────────
// The person page.
//
// The screen that has to survive the question "why am I seeing this person?".
// Asymmetric: the person and the argument for them on the left, the score and
// the action in a well on the right, so the decision is never more than a glance
// away from the reasoning that produced it.
//
// Two decisions worth defending:
//
//   * The self-description is set in Spectral italic. It is a quotation — the
//     person talking about themselves — and it is the one place on an Operate
//     screen where the serif earns its keep.
//   * Neither button sends anything from this page. "Send request" and
//     "Message" both open the chat, because the whole transaction — the answer,
//     the booking, the confirmation — has to live in one place, and a
//     confirmation panel here would be a second place to check.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/main.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/availability_grid.dart';
import 'package:tutormatch/widgets/match_score_scale.dart';
import 'package:tutormatch/widgets/tm_button.dart';
import 'package:tutormatch/widgets/tm_icon.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class PersonScreen extends StatelessWidget {
  const PersonScreen({required this.result, super.key});

  final MatchResult result;

  void _openChat(BuildContext context, MatchResult result, {required bool asRequest}) {
    final AppState state = AppStateScope.read(context);
    final Conversation thread = state.openThread(
      result.candidate,
      score: result.score.total,
      asRequest: asRequest,
    );
    Navigator.of(context).pushNamed(Routes.chat, arguments: thread);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final bool wide = TMLayout.isWide(context);

    // Re-scored against the profile as it stands now, so a page opened before
    // an availability change is not showing last week's arithmetic.
    final MatchResult result = rank(state.pool, state.profile).firstWhere(
      (MatchResult r) => r.candidate.id == this.result.candidate.id,
      orElse: () => this.result,
    );
    final Candidate c = result.candidate;
    final String? when = describeOverlap(result.score.overlap);
    final Conversation? thread = state.conversationWith(c.id);
    final bool student = state.role == Role.student;

    final Widget person = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(c.name, style: AppType.pageTitle),
        const SizedBox(height: Space.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(c.headline, style: AppType.bodyLarge.quiet),
        ),
        const SizedBox(height: Space.lg),
        _FactLine(candidate: c),
        const SizedBox(height: Space.xxl),
        const TMRule(label: 'In their own words'),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text('“${c.bio}”', style: AppType.quote),
        ),
        const SizedBox(height: Space.xxl),
        _Credentials(candidate: c),
        const SizedBox(height: Space.xxl),
        const TMRule(label: 'Why you matched'),
        const SizedBox(height: Space.lg),
        for (int i = 0; i < result.reasons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Space.lg),
          _Reason(index: i + 1, note: result.reasons[i]),
        ],
        const SizedBox(height: Space.xxl),
        const TMRule(label: 'Where the hundred points come from'),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ScoreBreakdown(score: result.score),
        ),
        const SizedBox(height: Space.xxl),
        const TMRule(label: "When you're both free"),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AvailabilityGrid(
            overlap: result.score.overlap,
            you: state.profile.availability,
            them: c.availability,
            display: AvailabilityDisplay.comparison,
            cellHeight: 22,
          ),
        ),
        const SizedBox(height: Space.lg),
        const AvailabilityLegend(),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            when == null
                ? 'Your weeks do not cross at all. Sending a request is still '
                    'possible, but expect to move something on your side first.'
                : '${result.score.overlapSlots} blocks a week line up — $when. '
                    'That is what the 25-point time score is measuring, block by block.',
            style: AppType.body.quiet,
          ),
        ),
      ],
    );

    final Widget aside = _ActionPanel(
      result: result,
      thread: thread,
      student: student,
      profileSummary: state.profileSummary,
      onSendRequest: () => _openChat(context, result, asRequest: true),
      onMessage: () => _openChat(context, result, asRequest: false),
    );

    return TMPage(
      navTrailing: TMButton(
        label: 'Back to the results',
        variant: TMButtonVariant.quiet,
        icon: TMIconName.arrowLeft,
        iconLeading: true,
        minHeight: Hit.min,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: Space.xxl),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 7, child: person),
                const SizedBox(width: Space.huge),
                SizedBox(width: TMLayout.asideWidth, child: aside),
              ],
            )
          else ...<Widget>[
            person,
            SizedBox(height: Space.xxxl),
            aside,
          ],
          const SizedBox(height: Space.huge),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

class _FactLine extends StatelessWidget {
  const _FactLine({required this.candidate});
  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          candidate.role == Role.tutor ? 'Tutor' : 'Student',
          style: AppType.bodySmall.tone(AppColors.inkMuted),
        ),
        Text('·', style: AppType.bodySmall.quieter),
        for (final String subject in candidate.subjects)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 1),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.ruleStrong),
              borderRadius: BorderRadius.circular(Radii.sharp - 1),
            ),
            child: Text(subject, style: AppType.bodySmall.tone(AppColors.inkSecondary)),
          ),
        Text('·', style: AppType.bodySmall.quieter),
        Text(candidate.modeCopy, style: AppType.bodySmall.quieter),
        Text('·', style: AppType.bodySmall.quieter),
        Text(candidate.rateCopy, style: AppType.figure),
        Text('·', style: AppType.bodySmall.quieter),
        Text(candidate.location, style: AppType.bodySmall.quieter),
      ],
    );
  }
}

class _Credentials extends StatelessWidget {
  const _Credentials({required this.candidate});
  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.xxxl,
      runSpacing: Space.xl,
      children: <Widget>[
        _Column(
          label: candidate.role == Role.tutor ? 'Works this way' : 'Wants this',
          value: '${candidate.styleLabel}\n${candidate.styleTags.join(' · ')}',
        ),
        _Column(
          label: candidate.role == Role.tutor ? 'Background' : 'Where they are',
          value: candidate.credentials.join('\n'),
        ),
        _Column(
          label: 'Speaks',
          value: candidate.languages.join(' · '),
        ),
        _Column(
          label: 'Reviews',
          value: candidate.reviews > 0
              ? '${candidate.rating} from ${candidate.reviews}'
              : 'No reviews yet — newer to the platform',
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 1, child: ColoredBox(color: AppColors.rule)),
          const SizedBox(height: Space.md),
          TMMicroLabelText(label),
          const SizedBox(height: Space.sm),
          Text(value, style: AppType.bodySmall.tone(AppColors.inkSecondary)),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.index, required this.note});
  final int index;
  final FitNote note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('$index', style: AppType.micro.tone(AppColors.accent)),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(note.signal, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Space.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(note.detail, style: AppType.bodySmall.quieter),
              ),
              const SizedBox(height: Space.xs),
              Text(note.dimension.label.toUpperCase(), style: AppType.micro.tone(AppColors.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The action panel
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.result,
    required this.thread,
    required this.student,
    required this.profileSummary,
    required this.onSendRequest,
    required this.onMessage,
  });

  final MatchResult result;
  final Conversation? thread;
  final bool student;
  final String profileSummary;
  final VoidCallback onSendRequest;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final String first = result.candidate.name.split(' ').first;
    // A local copy, because promotion does not reach into a widget's fields.
    final Conversation? open = thread;

    return TMEntry(
      floating: true,
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MatchScorePanel(
            score: result.score.total,
            trailing: TMStatusPill(tone: result.tier.tone, label: result.tier.label, dense: true),
          ),
          const SizedBox(height: Space.sm),
          Text(result.tier.meaning, style: AppType.bodySmall.quieter),
          const SizedBox(height: Space.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1, right: Space.sm),
                child: TMIcon(TMIconName.sliders, size: 13, color: AppColors.accent),
              ),
              Expanded(
                child: Text(
                  'Based on your profile: $profileSummary',
                  style: AppType.bodySmall.tone(AppColors.inkSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          const Divider(height: 1),
          const SizedBox(height: Space.xl),
          if (open == null)
            _ContactForm(
              student: student,
              first: first,
              onSendRequest: onSendRequest,
              onMessage: onMessage,
            )
          else
            TMInlineNote(
              tone: open.stage.tone,
              title: _threadTitle(open, student, first),
              body: _threadBody(open, student, first),
              actions: <Widget>[
                TMButton(
                  label: 'Open the conversation',
                  variant: TMButtonVariant.secondary,
                  icon: TMIconName.arrowRight,
                  minHeight: Hit.min,
                  onPressed: onMessage,
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _threadTitle(Conversation thread, bool student, String first) =>
      switch (thread.stage) {
        ChatStage.requestSent =>
          student ? 'You have asked $first for lessons.' : 'You have offered $first a lesson.',
        ChatStage.accepted => 'You and $first have an open conversation.',
        ChatStage.booked => 'Booked: ${thread.bookingCopy}.',
        ChatStage.completed => 'Your last session with $first is done.',
        ChatStage.declined => '$first turned the request down.',
      };

  static String _threadBody(Conversation thread, bool student, String first) =>
      switch (thread.stage) {
        ChatStage.requestSent =>
          'The whole transaction lives in the chat from here: the answer, the booking and the confirmation all arrive in that thread.',
        ChatStage.accepted => student
            ? '$first said yes. Pick a day, a time and a rate in the chat.'
            : 'Waiting for $first to pick a day and a time — it all happens in the chat.',
        ChatStage.booked => thread.confirmed
            ? 'Confirmed. Anything else about this lesson goes in the chat.'
            : student
                ? 'Waiting for $first to confirm the slot. That happens in the chat.'
                : 'Confirm the slot in the chat when you are ready.',
        ChatStage.completed => 'The thread stays so both sides can read how it went.',
        ChatStage.declined =>
          'Their answer is in the chat — read it there before asking somebody else.',
      };
}

class _ContactForm extends StatelessWidget {
  const _ContactForm({
    required this.student,
    required this.first,
    required this.onSendRequest,
    required this.onMessage,
  });

  final bool student;
  final String first;
  final VoidCallback onSendRequest;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TMMicroLabelText(student ? 'Ask for a lesson' : 'Offer a lesson'),
        const SizedBox(height: Space.md),
        Text(
          student
              ? 'Send a request and the conversation opens with it. Everything '
                  'after that — $first\'s answer, the booking, the confirmation — '
                  'happens in one thread, so there is one place to look.'
              : 'Send a request for a lesson and the conversation opens with it. '
                  'The answer, the booking and the confirmation all happen in one '
                  'thread, so there is one place to look.',
          style: AppType.bodySmall.quieter,
        ),
        const SizedBox(height: Space.lg),
        TMButton(
          label: 'Send request',
          expand: true,
          icon: TMIconName.arrowRight,
          onPressed: onSendRequest,
        ),
        const SizedBox(height: Space.md),
        TMButton(
          label: 'Message',
          variant: TMButtonVariant.secondary,
          expand: true,
          onPressed: onMessage,
        ),
        const SizedBox(height: Space.md),
        Text(
          'Nothing is emailed in this prototype — both buttons open a thread in '
          'Messages and stop there.',
          style: AppType.bodySmall.quieter,
        ),
      ],
    );
  }
}
