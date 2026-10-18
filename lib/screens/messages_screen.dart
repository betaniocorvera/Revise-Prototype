// ─────────────────────────────────────────────────────────────────────────────
// The inbox.
//
// One row per transaction: who, about what, the last thing said, when, and the
// figure when something in it is unread. The stage of the transaction is left
// to the chat, where the status bar states it in full — a one-word pill here
// would be a second, quieter vocabulary for the same fact.
//
// The empty state is the only place the screen explains itself, and it is
// written for whichever way the reader is facing: a student has to search
// before a tutor can answer; a tutor never receives anything that was not
// asked for.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:tutormatch/data/mock_data.dart';
import 'package:tutormatch/main.dart';
import 'package:tutormatch/state/app_state.dart';
import 'package:tutormatch/theme/app_theme.dart';
import 'package:tutormatch/widgets/tm_avatar.dart';
import 'package:tutormatch/widgets/tm_empty_state.dart';
import 'package:tutormatch/widgets/tm_layout.dart';
import 'package:tutormatch/widgets/tm_status.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({required this.onGoToSearch, super.key});

  /// The empty state's one button goes back to the search section, which lives
  /// in the dashboard above this screen — so the screen asks rather than
  /// reaching.
  final VoidCallback onGoToSearch;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppStateScope.of(context);
    final bool student = state.role == Role.student;
    final List<Conversation> threads = state.conversations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Space.xxl),
        Text('Messages', style: AppType.pageTitle),
        const SizedBox(height: Space.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            student
                ? 'Every request and every lesson lives in one thread. The stage '
                    'is written at the top of each chat, so nothing here is a '
                    'surprise and nothing needs a second screen.'
                : 'The students who have asked you for lessons, and the lessons '
                    'you have taken on. Each chat says where it has got to across '
                    'the top.',
            style: AppType.bodyLarge.quiet,
          ),
        ),
        const SizedBox(height: Space.xxl),
        if (threads.isEmpty)
          TMEmptyState(
            headline: 'No conversations yet.',
            body: student
                ? 'Search for a tutor and send a request. The answer comes back '
                    'here as a thread with the stage written on it — nothing '
                    'arrives on its own.'
                : 'Search for a student, or wait for a request. If somebody asks '
                    'you for lessons, the thread appears here with their hours '
                    'and their reasons already in it.',
            primaryLabel: student ? 'Search for a tutor' : 'Search for a student',
            onPrimary: onGoToSearch,
          )
        else
          for (int i = 0; i < threads.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Space.md),
            _ThreadRow(thread: threads[i]),
          ],
        const SizedBox(height: Space.huge),
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});

  final Conversation thread;

  @override
  Widget build(BuildContext context) {
    final ChatMessage? last = thread.messages.isEmpty ? null : thread.messages.last;
    final String preview = last == null
        ? 'Nothing said yet — write the first message.'
        : '${last.mine && !last.system ? 'You — ' : ''}${last.text}';
    final bool unread = thread.unread > 0;

    return TMEntry(
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg),
      onTap: () => Navigator.of(context).pushNamed(Routes.chat, arguments: thread),
      semanticLabel: '${thread.counterpartName}, '
          '${thread.subject}, ${thread.stage.label}'
          '${unread ? ', ${thread.unread} unread' : ''}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TMAvatar(name: thread.counterpartName, size: 42),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(thread.counterpartName, style: AppType.sectionTitle),
                const SizedBox(height: Space.xs),
                Text(
                  '${thread.subject} · matched ${thread.score}/100 · '
                  '${thread.stage.label}',
                  style: AppType.bodySmall.quieter,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  preview,
                  style: AppType.bodySmall.tone(
                    unread ? AppColors.ink : AppColors.inkSecondary,
                  ).copyWith(fontWeight: unread ? FontWeight.w600 : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(thread.lastTime, style: AppType.bodySmall.quieter),
              if (unread) ...<Widget>[
                const SizedBox(height: Space.sm),
                TMUnreadFigure(count: thread.unread),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
