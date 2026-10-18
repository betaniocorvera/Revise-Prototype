// ─────────────────────────────────────────────────────────────────────────────
// The dashboard shell.
//
// Three sections — search, messages, profile — behind one frame. On a phone
// they are a bottom bar; from 900 px they are a contents rail down the left,
// because a laptop has the room for the section list to stand beside the work
// instead of under it. The bar and the rail mark the current section with a
// 2 px accent rule, in the same place the eye already looks.
//
// The one thing that ever appears above a section is the completeness banner:
// a profile missing an answer, next to the search it improves. There is no
// onboarding behind this door, so completeness is asked for here — once,
// quietly, with one button to the field that is missing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/screens/messages_screen.dart';
import 'package:tutormatch/screens/profile_screen.dart';
import 'package:tutormatch/screens/search_screen.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/tm_button.dart';
import 'package:tutormatch/widgets/tm_icon.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// 0 search, 1 messages, 2 profile.
  int _section = 0;

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int section) {
    if (_section == section) return;
    setState(() => _section = section);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final bool wide = TMLayout.isWide(context);
    final int unread = state.unreadMessages;

    final Widget section = switch (_section) {
      1 => MessagesScreen(onGoToSearch: () => _go(0)),
      2 => const ProfileScreen(),
      _ => const SearchScreen(),
    };

    final Widget frame = Scrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContent),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: TMLayout.gutter(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_section == 0 && state.profileMissing.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xl),
                      child: _ProfileBanner(
                        completeness: state.profileCompleteness,
                        missing: state.profileMissing,
                        onComplete: () => _go(2),
                      ),
                    ),
                  section,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            TMTopBar(
              trailing: _AccountTrailing(name: state.profile.name, role: state.role),
            ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _SideRail(
                          current: _section,
                          unread: unread,
                          onSelect: _go,
                        ),
                        Expanded(child: frame),
                      ],
                    )
                  : frame,
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : _BottomBar(current: _section, unread: unread, onSelect: _go),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation, two renditions
// ─────────────────────────────────────────────────────────────────────────────

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.current,
    required this.unread,
    required this.onSelect,
  });

  final int current;
  final int unread;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TMLayout.railWidth,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.rule)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const TMMicroLabelText('Your dashboard'),
              const SizedBox(height: Space.md),
              const SizedBox(height: 1, child: ColoredBox(color: AppColors.rule)),
              const SizedBox(height: Space.md),
              _RailItem(
                icon: TMIconName.search,
                label: 'Search',
                selected: current == 0,
                onSelect: () => onSelect(0),
              ),
              _RailItem(
                icon: TMIconName.message,
                label: 'Messages',
                badge: unread,
                selected: current == 1,
                onSelect: () => onSelect(1),
              ),
              _RailItem(
                icon: TMIconName.person,
                label: 'Profile',
                selected: current == 2,
                onSelect: () => onSelect(2),
              ),
              const SizedBox(height: Space.xxl),
              Text(
                'Nothing is saved. Reloading the page puts the demo back the way '
                'it was found.',
                style: AppType.bodySmall.quieter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.badge = 0,
  });

  final TMIconName icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return TMFocusable(
      onTap: onSelect,
      semanticButton: false,
      semanticSelected: selected,
      semanticLabel: badge > 0 ? '$label, $badge unread' : label,
      builder: (BuildContext context, TMState s) {
        final Color ink = selected
            ? AppColors.accent
            : s.hovered || s.focused
                ? AppColors.ink
                : AppColors.inkSecondary;
        return TMFocusRing(
          focused: s.focused,
          radius: Radii.sharp,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.ease,
            constraints: const BoxConstraints(minHeight: Hit.min),
            margin: const EdgeInsets.only(bottom: Space.xs),
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentWash
                  : s.engaged
                      ? AppColors.paperSunken
                      : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                TMIcon(icon, size: 17, color: ink),
                const SizedBox(width: Space.md),
                Expanded(child: Text(label, style: AppType.label.tone(ink))),
                if (badge > 0) TMUnreadFigure(count: badge),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.unread,
    required this.onSelect,
  });

  final int current;
  final int unread;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.rule)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              Expanded(
                child: _BottomItem(
                  icon: <TMIconName>[
                    TMIconName.search,
                    TMIconName.message,
                    TMIconName.person,
                  ][i],
                  label: <String>['Search', 'Messages', 'Profile'][i],
                  badge: i == 1 ? unread : 0,
                  selected: current == i,
                  onSelect: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.badge = 0,
  });

  final TMIconName icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return TMFocusable(
      onTap: onSelect,
      semanticButton: false,
      semanticSelected: selected,
      semanticLabel: badge > 0 ? '$label, $badge unread' : label,
      builder: (BuildContext context, TMState s) {
        final Color ink = selected
            ? AppColors.accent
            : s.hovered || s.focused
                ? AppColors.ink
                : AppColors.inkSecondary;
        return TMFocusRing(
          focused: s.focused,
          radius: Radii.sharp,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TMIcon(icon, size: 19, color: ink),
                    if (badge > 0) ...<Widget>[
                      const SizedBox(width: Space.xs + 1),
                      TMUnreadFigure(count: badge),
                    ],
                  ],
                ),
                const SizedBox(height: Space.xs + 1),
                Text(label, style: AppType.micro.tone(ink), maxLines: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The completeness banner
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({
    required this.completeness,
    required this.missing,
    required this.onComplete,
  });

  final int completeness;
  final List<String> missing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return TMInlineNote(
      tone: StatusTone.pending,
      title: 'Your profile is $completeness% complete.',
      body: 'Missing: ${_andList(missing)}. '
          '${missing.length == 1 ? 'That answer is what' : 'Those answers are what'} '
          'the ranking has the least to go on — filling '
          '${missing.length == 1 ? 'it' : 'them'} in makes every result sharper.',
      actions: <Widget>[
        TMButton(
          label: 'Complete your profile',
          variant: TMButtonVariant.secondary,
          minHeight: Hit.min,
          onPressed: onComplete,
        ),
      ],
    );
  }
}

String _andList(List<String> items) => switch (items.length) {
      1 => items.first,
      2 => '${items[0]} and ${items[1]}',
      _ => '${items.take(items.length - 1).join(', ')} and ${items.last}',
    };

// ─────────────────────────────────────────────────────────────────────────────
// The account corner
// ─────────────────────────────────────────────────────────────────────────────

class _AccountTrailing extends StatelessWidget {
  const _AccountTrailing({required this.name, required this.role});

  final String name;
  final Role role;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // A name is the one unbounded piece of user text in this bar, so it gets
        // a cap and an ellipsis: a forty-character name shortens itself instead
        // of pushing the navigation off the edge.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              '$name · ${role == Role.student ? 'Student' : 'Tutor'}',
              style: AppType.bodySmall.quieter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        TMButton(
          label: 'Sign out',
          variant: TMButtonVariant.quiet,
          minHeight: Hit.min,
          onPressed: () => Navigator.of(context)
              .popUntil((Route<void> route) => route.isFirst),
        ),
      ],
    );
  }
}
