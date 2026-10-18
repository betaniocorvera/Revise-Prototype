// ─────────────────────────────────────────────────────────────────────────────
// The profile.
//
// Two modes and one toggle. Read mode states the answers the ranking reads, in
// the order they weigh. Edit mode is a form with the same blocks, in the same
// order, each one editable where it is stated — a person who wonders "why am I
// seeing this tutor?" should be able to answer it from this screen without
// reading any help text, because these blocks are the whole of the
// recommender's input.
//
// Two decisions worth defending:
//
//   * Editing is a mode, not a page of always-open inputs. A profile is read
//     ten times for every time it is changed, and signed-out text beats live
//     carets for the reading.
//   * Save confirms in place and says what it did, including the part this
//     prototype cannot do: nothing left the browser. The alternative — a modal
//     or a silent return — would claim more than happened.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/availability_grid.dart';
import 'package:tutormatch/widgets/tm_avatar.dart';
import 'package:tutormatch/widgets/tm_button.dart';
import 'package:tutormatch/widgets/tm_field.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _preview = false;
  bool _saved = false;
  String? _nameError;
  Profile? _draft;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _startEdit(AppState state) {
    setState(() {
      _editing = true;
      _preview = false;
      _saved = false;
      _nameError = null;
      _draft = state.profile;
      _name.text = state.profile.name;
      _bio.text = state.profile.bio;
    });
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _draft = null;
      _nameError = null;
    });
  }

  void _save(AppState state) {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError =
          'A name is needed — it is what the other side sees on the request.');
      return;
    }
    state.profile = (_draft ?? state.profile).copyWith(
      name: name,
      bio: _bio.text.trim(),
    );
    setState(() {
      _editing = false;
      _draft = null;
      _nameError = null;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final Profile p = _editing ? _draft! : state.profile;
    final bool student = p.role == Role.student;
    final String counterpart = student ? 'tutor' : 'student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.xxl),
        Text('Your profile', style: AppType.pageTitle),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'These are the answers the ranking reads, in the order they count. '
            'Edit any of them — the order of your results changes as soon as you '
            'save, and nothing you do here leaves the browser.',
            style: AppType.bodyLarge.quiet,
          ),
        ),
        const SizedBox(height: Space.xl),

        if (!_editing)
          _Completeness(
            percent: state.profileCompleteness,
            missing: state.profileMissing,
          ),

        const SizedBox(height: Space.xl),

        if (_editing)
          _form(state)
        else ...<Widget>[
          _controls(state, counterpart),
          if (_saved) ...<Widget>[
            const SizedBox(height: Space.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const TMInlineNote(
                tone: StatusTone.accepted,
                title: 'Saved.',
                body: 'The ranking has the new answers already — your next search '
                    'is ranked on them. In this prototype nothing was written to a '
                    'server, so reloading the page brings the demo profile back.',
              ),
            ),
          ],
          const SizedBox(height: Space.xxl),
          if (_preview)
            _previewCard(p, counterpart)
          else
            _view(p, student),
        ],

        const SizedBox(height: Space.huge),
      ],
    );
  }

  // ── Read mode ──────────────────────────────────────────────────────────────

  Widget _view(Profile p, bool student) {
    final String? when = describeOverlap(p.availability);
    final int free = p.availability.where((bool c) => c).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TMAvatar(name: p.name, size: 56),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(p.name, style: AppType.titleLarge),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${student ? 'Student' : 'Tutor'} · '
                    '${student ? 'looking for a tutor' : 'offering tutoring'}',
                    style: AppType.bodySmall.quieter,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            p.bio.trim().isEmpty
                ? 'No bio yet — the one answer a stranger reads first. It is '
                    'also what the completeness figure above is missing.'
                : '“${p.bio}”',
            style: p.bio.trim().isEmpty ? AppType.body.quiet : AppType.quote,
          ),
        ),
        const SizedBox(height: Space.xxl),

        _Block(
          label: 'Subjects',
          note: '${MatchDimension.subjects.max} of the 100 points. A shared '
              'subject is what makes a person appear in your results at all.',
          child: _Body(p.subjects.isEmpty ? 'None chosen yet.' : p.subjects.join(' · ')),
        ),
        _Block(
          label: student ? 'What you can spend' : 'Your rate',
          note: student
              ? '${MatchDimension.budget.max} points. Tutors above this are '
                  'filtered out of your results.'
              : '${MatchDimension.budget.max} points. Students whose ceiling is '
                  'below this are filtered out of theirs.',
          child: _Body(p.budget >= 80
              ? 'No ceiling — any price.'
              : '\$${p.budget}/hr'),
        ),
        _Block(
          label: 'Online or in person',
          note: '${MatchDimension.format.max} points. "Both" is a real answer, '
              'not a cop-out — it widens what matches.',
          child: _Body(p.mode.label),
        ),
        _Block(
          label: 'Weekly availability',
          note: '${MatchDimension.time.max} of the 100 points, and the dimension '
              'that decides most close calls. The filled cells are the hours you '
              'keep free.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Body(when == null
                  ? 'No hours set. Every result will read as a time mismatch '
                      'until this is filled in.'
                  : 'Free on $when. '
                      '$free of 21 half-day blocks are yours.'),
              const SizedBox(height: Space.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AvailabilityGrid(
                  overlap: p.availability,
                  cellHeight: 20,
                  semanticLabel:
                      '$free of 21 half-day blocks are free on your profile',
                ),
              ),
            ],
          ),
        ),
        _Block(
          label: 'What you are aiming at',
          note: 'Not scored. This is the one answer that is for you, not for the '
              'ranking.',
          child: _Body(p.goal),
        ),
        _Block(
          label: 'How you like to work',
          note: '${MatchDimension.style.max} points: how you like to work, not '
              'what you know.',
          child: _Body(p.style),
        ),
      ],
    );
  }

  // ── Controls: edit, and the preview switch ─────────────────────────────────

  Widget _controls(AppState state, String counterpart) {
    return Wrap(
      spacing: Space.xxl,
      runSpacing: Space.lg,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: <Widget>[
        TMButton(
          label: 'Edit profile',
          minHeight: Hit.min,
          onPressed: () => _startEdit(state),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const TMMicroLabelText('Preview how others see you'),
            const SizedBox(height: Space.sm),
            SizedBox(
              width: 168,
              child: TMSegmented<bool>(
                options: const <bool>[false, true],
                selected: _preview,
                onSelect: (bool v) => setState(() => _preview = v),
                labelOf: (bool v) => v ? 'On' : 'Off',
              ),
            ),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                _preview
                    ? 'Showing the profile exactly as a $counterpart reads it '
                        'before answering. Switch it off to get the editing '
                        'controls back.'
                    : 'Check the wording the way it will be read before a '
                        '$counterpart answers you.',
                style: AppType.bodySmall.quieter,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Edit mode ──────────────────────────────────────────────────────────────

  Widget _form(AppState state) {
    final Profile d = _draft!;
    final bool student = d.role == Role.student;
    final List<String> styles =
        student ? ProfileOptions.studentStyles : ProfileOptions.tutorStyles;
    final List<String> goals =
        student ? ProfileOptions.studentGoals : ProfileOptions.tutorGoals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TMAvatar(name: d.name.isEmpty ? '?' : d.name, size: 56),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Editing.', style: AppType.titleLarge),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Nothing is written down until you press Save — and even then '
                    'it only lives until the page is reloaded.',
                    style: AppType.bodySmall.quieter,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),

        TMTextField(
          label: 'Name',
          controller: _name,
          reason: 'It goes on every request you send.',
          error: _nameError,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
        const SizedBox(height: Space.xxl),

        TMTextField(
          label: 'A short bio',
          controller: _bio,
          maxLines: 4,
          hint: student
              ? 'Yr 12, working towards a mock in eleven weeks. I would rather '
                  'understand the hard questions than memorise the easy ones.'
              : 'Nine years teaching calculus and statistics, ex-exam marker. One '
                  'worked example, then you do the next one while I watch where '
                  'it goes wrong.',
          helper: 'Two sentences in your own voice beat a list of adjectives. '
              'This is what someone reads before answering your request — and '
              'the answer the completeness figure is usually missing.',
        ),
        const SizedBox(height: Space.xxl),

        _Block(
          label: 'Subjects',
          note: 'Everything you would happily teach or learn. '
              '${MatchDimension.subjects.max} of the 100 points, and the one '
              'thing both sides must share before a match exists at all.',
          child: TMTagPicker(
            options: ProfileOptions.subjects,
            selected: d.subjects.toSet(),
            onToggle: (String s) {
              final Set<String> next = d.subjects.toSet();
              if (!next.remove(s)) next.add(s);
              setState(() => _draft = d.copyWith(subjects: next.toList()));
            },
          ),
        ),

        _Block(
          label: 'Weekly availability',
          note: 'Tap the blocks you are free. ${MatchDimension.time.max} of the '
              '100 points, and the dimension people most often forget — an '
              'empty week matches nobody.',
          child: AvailabilityEditor(
            value: d.availability,
            onChanged: (List<bool> v) =>
                setState(() => _draft = d.copyWith(availability: v)),
          ),
        ),

        _Block(
          label: 'Online or in person',
          note: '${MatchDimension.format.max} points. "Both" widens your pool '
              'rather than narrowing anybody else\'s.',
          child: TMSegmented<SessionMode>(
            options: const <SessionMode>[
              SessionMode.online,
              SessionMode.inPerson,
              SessionMode.both,
            ],
            selected: d.mode,
            onSelect: (SessionMode m) => setState(() => _draft = d.copyWith(mode: m)),
            labelOf: (SessionMode m) => m.label,
          ),
        ),

        _Block(
          label: student ? 'What you can spend' : 'Your rate',
          note: '${MatchDimension.budget.max} points, measured as one budget '
              'against one price. "Any price" is a real answer.',
          child: TMBudgetScale(
            value: d.budget,
            onChanged: (int v) => setState(() => _draft = d.copyWith(budget: v)),
          ),
        ),

        _Block(
          label: student ? 'What you are aiming at' : 'What you want out of it',
          note: 'Not scored, and kept outside the numbered answers above. '
              'It is the one thing here that is for you rather than for the '
              'ranking.',
          child: TMChoiceList<String>(
            options: goals,
            selected: d.goal,
            onSelect: (String g) => setState(() => _draft = d.copyWith(goal: g)),
            labelOf: (String g) => g,
          ),
        ),

        _Block(
          label: 'How you like to work',
          note: '${MatchDimension.style.max} points: how you like to work, not '
              'what you know.',
          child: TMChoiceList<String>(
            options: styles,
            selected: d.style,
            onSelect: (String s) => setState(() => _draft = d.copyWith(style: s)),
            labelOf: (String s) => s,
          ),
        ),

        const SizedBox(height: Space.xxl),
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            TMButton(
              label: 'Save changes',
              minHeight: Hit.min,
              onPressed: () => _save(state),
            ),
            TMTextLink(
              label: 'Cancel',
              style: AppType.bodySmall,
              onTap: _cancel,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Save keeps this for the session and the ranking picks it up '
            'straight away. Reloading the page brings the demo profile back — '
            'there is nowhere else for it to go.',
            style: AppType.bodySmall.quieter,
          ),
        ),
      ],
    );
  }

  // ── The preview ────────────────────────────────────────────────────────────

  Widget _previewCard(Profile p, String counterpart) {
    final int free = p.availability.where((bool c) => c).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TMEntry(
          floating: true,
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TMAvatar(name: p.name, size: 52),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(p.name, style: AppType.titleLarge),
                        const SizedBox(height: Space.xs),
                        Text(
                          p.role == Role.student ? 'Student' : 'Tutor',
                          style: AppType.bodySmall.quieter,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: <Widget>[
                  for (final String s in p.subjects) _Chip(label: s),
                  _Chip(label: p.mode.label),
                  _Chip(
                    label: p.budget >= 80
                        ? 'Any price'
                        : p.role == Role.student
                            ? 'up to \$${p.budget}/hr'
                            : '\$${p.budget}/hr',
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  p.bio.trim().isEmpty
                      ? 'No bio written yet. Most people will read this line '
                          'before anything else you say.'
                      : '“${p.bio}”',
                  style: p.bio.trim().isEmpty
                      ? AppType.body.quiet
                      : AppType.quote,
                ),
              ),
              const SizedBox(height: Space.xxl),
              const TMRule(label: 'When they are free'),
              const SizedBox(height: Space.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AvailabilityGrid(
                  overlap: p.availability,
                  cellHeight: 22,
                  semanticLabel:
                      '$free of 21 half-day blocks are free on this profile',
                ),
              ),
              const SizedBox(height: Space.xxl),
              const TMRule(label: 'What they say about their goal'),
              const SizedBox(height: Space.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text('“${p.goal}”', style: AppType.quote),
              ),
              const SizedBox(height: Space.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(p.style, style: AppType.body.quiet),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'How a $counterpart sees you: name, subjects, hours, format and '
          'price, in the order they are read on the person page.',
          style: AppType.bodySmall.quieter,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pieces
// ─────────────────────────────────────────────────────────────────────────────

/// One answer, in the order the ranking weighs it. The rule above each block is
/// the only structure used on this page.
class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child, this.note = ''});

  final String label;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 1, child: ColoredBox(color: AppColors.rule)),
        const SizedBox(height: Space.lg),
        TMMicroLabelText(label),
        const SizedBox(height: Space.lg),
        child,
        if (note.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(note, style: AppType.bodySmall.quieter),
          ),
        ],
        const SizedBox(height: Space.xl),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.bodyLarge);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 1),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.ruleStrong),
        borderRadius: BorderRadius.circular(Radii.sharp - 1),
      ),
      child: Text(label, style: AppType.bodySmall.tone(AppColors.inkSecondary)),
    );
  }
}

/// The completeness figure: a number, what is missing by name, and a rule that
/// fills as the answers do. Deliberately quiet — it is an invitation, not a
/// gate, and the dashboard banner already made the point once.
class _Completeness extends StatelessWidget {
  const _Completeness({required this.percent, required this.missing});

  final int percent;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text('$percent%', style: AppType.figureLarge),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                missing.isEmpty
                    ? 'complete — every answer the ranking reads is filled in.'
                    : 'complete — missing ${_andList(missing)}.',
                style: AppType.bodySmall.quieter,
              ),
            ),
          ],
        ),
        if (missing.isNotEmpty) ...<Widget>[
          const SizedBox(height: Space.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SizedBox(
              height: 3,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: percent,
                    child: const ColoredBox(color: AppColors.accent),
                  ),
                  Expanded(
                    flex: 100 - percent,
                    child: const ColoredBox(color: AppColors.rule),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _andList(List<String> items) => switch (items.length) {
      1 => items.first,
      2 => '${items[0]} and ${items[1]}',
      _ => '${items.take(items.length - 1).join(', ')} and ${items.last}',
    };
