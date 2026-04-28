import 'package:flutter/material.dart';

import '../../../people/data/people_repository.dart';
import '../../../people/domain/person.dart';
import '../../data/bill_comments_repository.dart';
import '../../domain/bill_comment.dart';

class BillDiscussionSection extends StatefulWidget {
  const BillDiscussionSection({
    super.key,
    required this.billId,
    required this.billName,
    this.defaultPersonId,
  });

  final String billId;
  final String billName;
  final String? defaultPersonId;

  @override
  State<BillDiscussionSection> createState() => _BillDiscussionSectionState();
}

class _BillDiscussionSectionState extends State<BillDiscussionSection> {
  final BillCommentsRepository _repo = BillCommentsRepository.instance;
  final TextEditingController _messageController = TextEditingController();

  List<BillCommentModel> _comments = <BillCommentModel>[];
  List<PersonModel> _people = <PersonModel>[];
  String? _selectedPersonId;

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedPersonId = _emptyToNull(widget.defaultPersonId);
    _messageController.addListener(_onMessageChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant BillDiscussionSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.billId != widget.billId) {
      _comments = <BillCommentModel>[];
      _selectedPersonId = _emptyToNull(widget.defaultPersonId);
      _load();
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<PersonModel> people = await PeopleRepository.instance.fetchAll();
      final List<BillCommentModel> comments =
          await _repo.fetchForBill(widget.billId);

      if (!mounted) return;

      final bool selectedPersonExists = _selectedPersonId == null ||
          people.any((PersonModel p) => p.id == _selectedPersonId);

      setState(() {
        _people = people;
        _comments = comments;
        if (!selectedPersonExists) _selectedPersonId = null;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('BillDiscussionSection._load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load discussion.';
      });
    }
  }

  Future<void> _send() async {
    final String message = _messageController.text.trim();

    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final BillCommentModel? comment = await _repo.addComment(
        billId: widget.billId,
        billName: widget.billName,
        message: message,
        personId: _selectedPersonId,
      );

      if (!mounted) return;

      if (comment == null) {
        setState(() {
          _errorMessage = 'Failed to send comment.';
          _isSending = false;
        });
        return;
      }

      _messageController.clear();

      final List<BillCommentModel> comments =
          await _repo.fetchForBill(widget.billId);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment added.')),
      );
    } catch (error, stackTrace) {
      debugPrint('BillDiscussionSection._send error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to send comment.';
        _isSending = false;
      });
    }
  }

  bool get _canSend =>
      !_isSending && _messageController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Discussion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh discussion',
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(16),
            color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
          ),
          child: Column(
            children: <Widget>[
              if (_errorMessage != null)
                _DiscussionError(message: _errorMessage!),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_comments.isEmpty)
                const _EmptyDiscussion()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Column(
                    children: _comments
                        .map(
                          (BillCommentModel comment) =>
                              _CommentTile(comment: comment),
                        )
                        .toList(),
                  ),
                ),
              const Divider(height: 1),
              _Composer(
                people: _people,
                selectedPersonId: _selectedPersonId,
                controller: _messageController,
                isSending: _isSending,
                canSend: _canSend,
                onPersonChanged: (String? value) {
                  setState(() => _selectedPersonId = _emptyToNull(value));
                },
                onSend: _send,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _emptyToNull(String? value) {
    if (value == null) return null;

    final String text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return text;
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.people,
    required this.selectedPersonId,
    required this.controller,
    required this.isSending,
    required this.canSend,
    required this.onPersonChanged,
    required this.onSend,
  });

  final List<PersonModel> people;
  final String? selectedPersonId;
  final TextEditingController controller;
  final bool isSending;
  final bool canSend;
  final ValueChanged<String?> onPersonChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? dropdownValue =
        selectedPersonId != null &&
            people.any((PersonModel person) => person.id == selectedPersonId)
        ? selectedPersonId
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: <Widget>[
          DropdownButtonFormField<String?>(
            initialValue: dropdownValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Link comment to person',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No person / General comment'),
              ),
              ...people.map(
                (PersonModel person) => DropdownMenuItem<String?>(
                  value: person.id,
                  child: Text(_personDisplayName(person)),
                ),
              ),
            ],
            onChanged: isSending ? null : onPersonChanged,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            enabled: !isSending,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Write a bill comment...',
              border: const OutlineInputBorder(),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Send comment',
                        onPressed: canSend ? onSend : null,
                        icon: Icon(
                          Icons.send_outlined,
                          color: canSend ? colors.primary : colors.outline,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _personDisplayName(PersonModel person) {
    final String nickname = person.nickname?.trim() ?? '';

    if (nickname.isNotEmpty) {
      return '${person.name} ($nickname)';
    }

    return person.name;
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final BillCommentModel comment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String personName = comment.personName?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 15,
            backgroundColor: personName.isEmpty
                ? colors.surfaceContainerHighest
                : colors.primaryContainer,
            child: Icon(
              personName.isEmpty
                  ? Icons.chat_bubble_outline
                  : Icons.person_outline,
              size: 16,
              color: personName.isEmpty
                  ? colors.onSurfaceVariant
                  : colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.75),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          personName.isEmpty ? 'General comment' : personName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        _formatDateTime(comment.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.message,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final int hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';

    return '${dt.month}/${dt.day} $hour:$minute $ampm';
  }
}

class _EmptyDiscussion extends StatelessWidget {
  const _EmptyDiscussion();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.forum_outlined,
            size: 36,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'No discussion yet',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add notes, payment updates, or responsibility comments for this bill.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussionError extends StatelessWidget {
  const _DiscussionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: colors.onErrorContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
