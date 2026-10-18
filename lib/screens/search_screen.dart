// ─────────────────────────────────────────────────────────────────────────────
// Search.
//
// The one screen that shows the pool, and it shows nothing until it is asked.
// Before the first search there is an empty state and a row of subjects to
// start from; after it, the ranked list, best fit first, with the filters able
// to interrogate the order but never to produce it.
//
// Two things here are worth defending:
//
//   * The search word is a filter like any other, and when it removes everybody
//     the empty state names it and offers the one tap back — the same machinery
//     every other filter gets. See mock_data.dart, _explain.
//   * Rank order never changes when a filter changes, because the order is the
//     recommender's opinion and the filters are yours.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/main.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/match_card.dart';
import 'package:tutormatch/widgets/tm_button.dart';
import 'package:tutormatch/widgets/tm_empty_state.dart';
import 'package:tutormatch/widgets/tm_field.dart';
import 'package:tutormatch/widgets/tm_icon.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _query;

  /// The skeleton, held for a beat so the loading state is a state and not a
  /// flash. A real service round trip would land here.
  bool _searching = false;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: AppStateScope.read(context).filters.query);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final AppState state = AppStateScope.read(context);
    state.searched = true;
    setState(() => _searching = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _searching = false);
    });
  }

  /// The suggested-subject chips tick the subject filter and search, so the
  /// chips are a shortcut into the same machinery as the panel, not a separate
  /// way of searching.
  void _pickSubject(String subject) {
    final AppState state = AppStateScope.read(context);
    state.filters = state.filters.copyWith(
      subjects: <String>{...state.filters.subjects, subject},
    );
    _search();
  }

  /// All the ways filters can change from outside the field must keep the field
  /// honest, so every one of them passes through here.
  void _relax(MatchFilters relaxed) {
    _query.text = relaxed.query;
    AppStateScope.read(context).relaxFilters(relaxed);
  }

  void _clearEverything() {
    _query.clear();
    AppStateScope.read(context).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final bool student = state.role == Role.student;
    final String counterpart = student ? 'tutor' : 'student';
    final List<MatchResult> ranked = rank(state.pool, state.profile);
    final MatchOutcome outcome = applyFilters(ranked, state.filters, state.profile);
    final bool wide = TMLayout.isWide(context);

    final Widget panel = _FilterPanel(
      state: state,
      ranked: ranked,
      onClear: _clearEverything,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.xxl),
        Text(student ? 'Find a tutor' : 'Find a student', style: AppType.pageTitle),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Nothing is ranked until you search. ${state.pool.length} '
            '${counterpart}s are in this prototype: type a name or a subject, set '
            'whatever else matters, and the best fit comes first.',
            style: AppType.bodyLarge.quiet,
          ),
        ),
        const SizedBox(height: Space.xxl),
        _SearchBar(
          controller: _query,
          searched: state.searched,
          onChanged: (String value) =>
              state.filters = state.filters.copyWith(query: value),
          onSearch: _search,
        ),
        const SizedBox(height: Space.xl),

        if (!wide) ...<Widget>[
          TMButton(
            label: _filtersOpen ? 'Hide the filters' : 'Filters',
            variant: TMButtonVariant.secondary,
            icon: TMIconName.sliders,
            iconLeading: true,
            minHeight: Hit.min,
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
          const SizedBox(height: Space.lg),
        ],

        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: TMLayout.railWidth, child: panel),
              const SizedBox(width: Space.xxl),
              Expanded(child: _content(context, state, ranked, outcome, student)),
            ],
          )
        else ...<Widget>[
          // The panel sits above the list when it is open, and stays visible
          // while the results are read: no overlay, no trapped filters.
          if (_filtersOpen) ...<Widget>[
            panel,
            SizedBox(height: Space.xxl),
          ],
          _content(context, state, ranked, outcome, student),
        ],
        const SizedBox(height: Space.huge),
      ],
    );
  }

  // ── Results, or the state that stands in for them ──────────────────────────

  Widget _content(
    BuildContext context,
    AppState state,
    List<MatchResult> ranked,
    MatchOutcome outcome,
    bool student,
  ) {
    if (!state.searched) {
      return TMEmptyState(
        headline: 'Nothing is ranked yet.',
        body: student
            ? 'Matches appear only when you search. Type a subject above, or '
                'start from one of these — every result is ranked on your profile: '
                'subjects first, then the hours you are both free, then style, '
                'format and budget.'
            : 'Students appear only when you search. Type a subject above, or '
                'start from one of these — every result is ranked on your profile: '
                'subjects first, then the hours you are both free, then your style, '
                'your format and their budget.',
        extra: _Suggestions(
          subjects: _suggestedSubjects(ranked),
          onPick: _pickSubject,
        ),
      );
    }

    if (_searching) return const _SearchInProgress();

    if (outcome.empty != null) {
      final EmptyExplanation empty = outcome.empty!;
      return TMEmptyState(
        headline: empty.headline,
        body: empty.body,
        primaryLabel: empty.adjustLabel,
        onPrimary: () => _relax(empty.relaxed),
        secondaryLabel: state.filters.isNarrowed ? 'Clear every filter' : null,
        onSecondary: _clearEverything,
        filtersLabel: 'What is removing them',
        filters: <Widget>[
          if (state.filters.query.trim().isNotEmpty)
            TMFilterTag(
              label: 'Searching "${state.filters.query.trim()}"',
              onRemove: () {
                _query.clear();
                state.filters = state.filters.copyWith(query: '');
              },
            ),
          for (final int p in state.filters.requiredParts)
            TMFilterTag(
              label: 'Free on my ${Week.partLong[p]}',
              onRemove: () => state.filters = state.filters.copyWith(
                requiredParts: <int>{...state.filters.requiredParts}..remove(p),
              ),
            ),
          if (state.filters.mode != null)
            TMFilterTag(
              label: state.filters.mode!.label,
              onRemove: () => state.filters =
                  state.filters.copyWith(clearMode: true, mode: null),
            ),
          if (state.filters.maxRate < 80)
            TMFilterTag(
              label: 'Up to \$${state.filters.maxRate}/hr',
              onRemove: () => state.filters = state.filters.copyWith(maxRate: 80),
            ),
          for (final String s in state.filters.subjects)
            TMFilterTag(
              label: s,
              onRemove: () => state.filters = state.filters.copyWith(
                subjects: <String>{...state.filters.subjects}..remove(s),
              ),
            ),
        ],
      );
    }

    final List<MatchResult> results = outcome.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Basis(summary: state.profileSummary),
        const SizedBox(height: Space.xl),
        _ResultSummary(results: results, total: ranked.length),
        SizedBox(height: Space.xl),
        for (int i = 0; i < results.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: Space.xl),
          // After the fifth entry the reasons stop being about what you gain.
          // Say so, rather than letting a long list quietly dilute itself.
          if (i == 5 && results.length > 6) ...<Widget>[
            const SizedBox(height: Space.xxl),
            const Divider(height: 1),
            const SizedBox(height: Space.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                'Below this line the reasons start to be about what you would be '
                'giving up. They are still ranked honestly, and the reason is '
                'still stated — read the third line of each one first.',
                style: AppType.bodySmall.quieter,
              ),
            ),
            const SizedBox(height: Space.xl),
          ],
          _card(context, state, results[i], i, ranked.length),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, AppState state, MatchResult result, int i, int total) {
    final Conversation? thread = state.conversationWith(result.candidate.id);
    final bool asked = thread != null && thread.stage != ChatStage.declined;
    return MatchResultCard(
      result: result,
      rank: i + 1,
      total: total,
      lead: i == 0,
      fromProfile: i == 0,
      profileSummary: state.profileSummary,
      requested: asked,
      onOpen: () => Navigator.of(context).pushNamed(Routes.person, arguments: result),
      // The lead card's shortcut skips the profile: it opens the thread with
      // the request already written into it.
      onQuickRequest: asked
          ? null
          : () {
              final Conversation opened = state.openThread(
                result.candidate,
                score: result.score.total,
                asRequest: true,
              );
              Navigator.of(context).pushNamed(Routes.chat, arguments: opened);
            },
    );
  }

  /// The subjects worth offering as a way in: the ones most of the pool
  /// actually covers, in name order when the counts tie.
  static List<String> _suggestedSubjects(List<MatchResult> ranked) {
    final Map<String, int> count = <String, int>{};
    for (final MatchResult r in ranked) {
      for (final String s in r.candidate.subjects) {
        count[s] = (count[s] ?? 0) + 1;
      }
    }
    final List<String> all = count.keys.toList()
      ..sort((String a, String b) {
        final int byCount = count[b]!.compareTo(count[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return all.take(8).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searched,
    required this.onChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool searched;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final Widget field = TMTextField(
      label: 'Search',
      reason: 'Names, subjects and how they teach. Bios are not searched — '
          'prose matches by accident.',
      controller: controller,
      hint: 'Try "statistics", or a name',
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: (_) => onSearch(),
    );
    final Widget button = TMButton(
      label: searched ? 'Search again' : 'Search',
      icon: TMIconName.search,
      onPressed: onSearch,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              field,
              const SizedBox(height: Space.lg),
              button,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: field),
            const SizedBox(width: Space.lg),
            button,
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The pre-search state's way in
// ─────────────────────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.subjects, required this.onPick});

  final List<String> subjects;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TMMicroLabelText('Start from a subject'),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: <Widget>[
            for (final String subject in subjects)
              _SuggestionChip(label: subject, onTap: () => onPick(subject)),
          ],
        ),
      ],
    );
  }
}

/// A tag that does something. The same geometry as the tag picker's chips, so
/// the two read as one control family.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TMFocusable(
      onTap: onTap,
      semanticButton: false,
      semanticLabel: 'Search $label',
      builder: (BuildContext context, TMState s) {
        return TMFocusRing(
          focused: s.focused,
          radius: Radii.sharp - 1,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.ease,
            constraints: const BoxConstraints(minHeight: Hit.min),
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.hovered ? AppColors.paperSunken : AppColors.paperRaised,
              border: Border.all(
                color: s.engaged ? AppColors.ruleStrong : AppColors.rule,
              ),
              borderRadius: BorderRadius.circular(Radii.sharp - 1),
            ),
            child: Text(
              label,
              style: AppType.labelSmall.tone(
                s.engaged ? AppColors.ink : AppColors.inkSecondary,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// States between the bar and the list
// ─────────────────────────────────────────────────────────────────────────────

class _SearchInProgress extends StatelessWidget {
  const _SearchInProgress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: TMProgressRule(width: 320)),
          ],
        ),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Searching the pool: subjects first, then the hours you are both '
            'free, then style, format and budget. About a second.',
            style: AppType.body.quiet,
          ),
        ),
        const SizedBox(height: Space.xxl),
        for (int i = 0; i < 2; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Space.xl),
          MatchCardSkeleton(rank: i + 1),
        ],
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.results, required this.total});

  final List<MatchResult> results;
  final int total;

  @override
  Widget build(BuildContext context) {
    int band(MatchTier t) => results.where((MatchResult r) => r.tier == t).length;

    final int strong = band(MatchTier.strong);
    final int good = band(MatchTier.good);
    final int rest = results.length - strong - good;

    final List<String> parts = <String>[
      if (strong > 0) '$strong strong',
      if (good > 0) '$good good',
      if (rest > 0) '$rest worth a look',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text('${results.length}', style: AppType.figureLarge),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                results.length == total
                    ? 'of $total showing'
                    : 'of $total after filtering',
                style: AppType.bodySmall.quieter,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        Text(
          parts.isEmpty ? 'Nothing above the threshold you set.' : parts.join(' · '),
          style: AppType.bodySmall.quieter,
        ),
      ],
    );
  }
}

class _Basis extends StatelessWidget {
  const _Basis({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              color: AppColors.accentWash,
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const TMIcon(TMIconName.sliders, size: 13, color: AppColors.accent),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Text(
                    'Ranked on your profile: $summary',
                    style: AppType.micro.tone(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The filter panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.state,
    required this.ranked,
    required this.onClear,
  });

  final AppState state;
  final List<MatchResult> ranked;

  /// Clearing has to clear the search field too, and the field lives in the
  /// screen above this panel — so the panel asks rather than reaching.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final MatchFilters f = state.filters;

    // Only subjects that somebody in the pool actually teaches are offered.
    // A filter that can only ever return nothing is not a filter, it is a trap.
    final List<String> available = <String>{
      for (final MatchResult r in ranked) ...r.candidate.subjects,
    }.toList()
      ..sort();

    final Set<String> partNames = <String>{
      for (final int p in f.requiredParts) Week.partLong[p],
    };

    const String anyFormat = 'Any format';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const TMMicroLabelText('Filters'),
        const SizedBox(height: Space.md),
        const SizedBox(height: 1, child: ColoredBox(color: AppColors.rule)),
        const SizedBox(height: Space.xl),

        const TMMicroLabelText('Free on my'),
        const SizedBox(height: Space.md),
        TMTagPicker(
          options: Week.partLong,
          selected: partNames,
          onToggle: (String name) {
            final int index = Week.partLong.indexOf(name);
            final Set<int> next = <int>{...f.requiredParts};
            if (!next.remove(index)) next.add(index);
            state.filters = f.copyWith(requiredParts: next);
          },
        ),
        const SizedBox(height: Space.xl),

        const TMMicroLabelText('Format'),
        const SizedBox(height: Space.md),
        TMTagRow<SessionMode?>(
          options: const <SessionMode?>[
            null,
            SessionMode.online,
            SessionMode.inPerson,
            SessionMode.both,
          ],
          selected: f.mode,
          onSelect: (SessionMode? m) => state.filters = m == null
              ? f.copyWith(clearMode: true, mode: null)
              : f.copyWith(mode: m),
          labelOf: (SessionMode? m) => m == null ? anyFormat : m.label,
        ),
        const SizedBox(height: Space.xl),

        const TMMicroLabelText('Ceiling'),
        const SizedBox(height: Space.md),
        TMBudgetScale(
          value: f.maxRate,
          onChanged: (int v) => state.filters = f.copyWith(maxRate: v),
        ),
        const SizedBox(height: Space.xl),

        const TMMicroLabelText('Subjects'),
        const SizedBox(height: Space.md),
        TMTagPicker(
          options: available,
          selected: f.subjects,
          onToggle: (String s) {
            final Set<String> next = <String>{...f.subjects};
            if (!next.remove(s)) next.add(s);
            state.filters = f.copyWith(subjects: next);
          },
        ),
        const SizedBox(height: Space.xl),
        const SizedBox(height: 1, child: ColoredBox(color: AppColors.rule)),
        const SizedBox(height: Space.lg),
        if (f.isNarrowed)
          TMTextLink(
            label: 'Clear every filter',
            style: AppType.bodySmall,
            onTap: onClear,
          )
        else
          Text(
            'Every filter is wide open — the whole pool is showing, best fit first.',
            style: AppType.bodySmall.quieter,
          ),
      ],
    );
  }
}
