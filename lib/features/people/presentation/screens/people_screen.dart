import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../domain/person.dart';
import '../widgets/person_card.dart';
import 'add_person_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  static const List<String> _defaultGroupNames = <String>[
    'Family',
    'Friend',
    'Coworker',
  ];

  final SupabaseClient _supabase = Supabase.instance.client;

  List<Person> _people = <Person>[];
  List<_PeopleGroup> _groups = _defaultGroups();
  int _selectedGroupIndex = 0;
  bool _isLoading = true;
  bool _isSeeding = false;
  bool _groupsTableReady = true;

  static List<_PeopleGroup> _defaultGroups() {
    return _defaultGroupNames
        .map((String name) => _PeopleGroup(id: '', name: name))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    try {
      final String userId = requireCurrentUserId();
      final List<_PeopleGroup> groups = await _loadGroups(userId);
      final List<dynamic> response = await _supabase
          .from('people')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      final List<Person> people = response
          .map(
            (dynamic row) =>
                Person.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .where((Person person) => person.id.isNotEmpty)
          .toList();
      setState(() {
        _replaceGroups(_mergeGroupsWithPeople(groups, people));
        _people = people;
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to load people.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<_PeopleGroup>> _loadGroups(String userId) async {
    try {
      final List<dynamic> rows = await _supabase
          .from('people_groups')
          .select('id, name')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      _groupsTableReady = true;
      if (rows.isEmpty) {
        return _seedDefaultGroups(userId);
      }

      return rows
          .map(
            (dynamic row) =>
                _PeopleGroup.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } catch (_) {
      _groupsTableReady = false;
      return _defaultGroups();
    }
  }

  Future<List<_PeopleGroup>> _seedDefaultGroups(String userId) async {
    final List<dynamic> rows = await _supabase
        .from('people_groups')
        .insert(
          _defaultGroupNames
              .map(
                (String name) => <String, dynamic>{
                  'user_id': userId,
                  'name': name,
                },
              )
              .toList(),
        )
        .select('id, name');

    return rows
        .map(
          (dynamic row) =>
              _PeopleGroup.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  void _replaceGroups(List<_PeopleGroup> groups, {int? selectedIndex}) {
    final List<_PeopleGroup> nextGroups = groups.isEmpty
        ? _defaultGroups()
        : groups;
    final int nextIndex = (selectedIndex ?? _selectedGroupIndex)
        .clamp(0, nextGroups.length - 1)
        .toInt();

    _groups = nextGroups;
    _selectedGroupIndex = nextIndex;
  }

  List<_PeopleGroup> _mergeGroupsWithPeople(
    List<_PeopleGroup> groups,
    List<Person> people,
  ) {
    final List<_PeopleGroup> merged = <_PeopleGroup>[...groups];
    for (final Person person in people) {
      final String? role = person.role?.trim();
      if (role == null || role.isEmpty) {
        if (!merged.any((_PeopleGroup group) {
          return _normalize(group.name) == 'ungrouped';
        })) {
          merged.add(const _PeopleGroup(id: '', name: 'Ungrouped'));
        }
        continue;
      }
      if (merged.any((_PeopleGroup group) {
        return _normalize(group.name) == _normalize(role);
      })) {
        continue;
      }
      merged.add(_PeopleGroup(id: '', name: role));
    }
    return merged;
  }

  Future<void> _goToAddPerson() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddPersonScreen(initialRole: _selectedGroup?.name),
      ),
    );
    if (result == true) _loadPeople();
  }

  Future<void> _createGroup() async {
    final bool groupsReady = await _ensureGroupsTableReady();
    if (!groupsReady) return;
    if (!mounted) return;

    final String? name = await _showGroupNameDialog(title: 'Create Group');
    if (name == null) return;
    if (_groupNameExists(name)) {
      _showMessage('That group already exists.');
      return;
    }

    try {
      final String userId = requireCurrentUserId();
      final Map<String, dynamic> row = await _supabase
          .from('people_groups')
          .insert(<String, dynamic>{'user_id': userId, 'name': name})
          .select('id, name')
          .single();
      final _PeopleGroup group = _PeopleGroup.fromMap(row);
      if (!mounted) return;
      setState(() {
        _replaceGroups(<_PeopleGroup>[
          ..._groups,
          group,
        ], selectedIndex: _groups.length);
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to create group.');
    }
  }

  Future<void> _renameSelectedGroup() async {
    final bool groupsReady = await _ensureGroupsTableReady();
    if (!groupsReady) return;
    if (!mounted) return;
    final _PeopleGroup? group = _selectedGroup;
    if (group == null) return;
    if (_normalize(group.name) == 'ungrouped') {
      _showMessage('Ungrouped cannot be renamed.');
      return;
    }

    final String? newName = await _showGroupNameDialog(
      title: 'Rename Group',
      initialName: group.name,
    );
    if (newName == null || newName == group.name) return;
    if (_groupNameExists(
      newName,
      exceptId: group.id.isEmpty ? null : group.id,
    )) {
      _showMessage('That group already exists.');
      return;
    }

    try {
      final String userId = requireCurrentUserId();
      if (group.id.isNotEmpty) {
        await _supabase
            .from('people_groups')
            .update(<String, dynamic>{'name': newName})
            .eq('id', group.id)
            .eq('user_id', userId);
      }
      await _supabase
          .from('people')
          .update(<String, dynamic>{'role': newName})
          .eq('user_id', userId)
          .eq('role', group.name);
      await _loadPeople();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to rename group.');
    }
  }

  Future<void> _deleteSelectedGroup() async {
    final bool groupsReady = await _ensureGroupsTableReady();
    if (!groupsReady) return;
    if (!mounted) return;
    final _PeopleGroup? group = _selectedGroup;
    if (group == null) return;
    if (_normalize(group.name) == 'ungrouped') {
      _showMessage('Ungrouped cannot be deleted.');
      return;
    }
    if (_groups.length <= 1) {
      _showMessage('Keep at least one group.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Delete "${group.name}"? People in this group will move to Ungrouped.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final String userId = requireCurrentUserId();
      await _supabase
          .from('people')
          .update(<String, dynamic>{'role': 'Ungrouped'})
          .eq('user_id', userId)
          .eq('role', group.name);
      if (group.id.isNotEmpty) {
        await _supabase
            .from('people_groups')
            .delete()
            .eq('id', group.id)
            .eq('user_id', userId);
      }
      await _loadPeople();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to delete group.');
    }
  }

  Future<String?> _showGroupNameDialog({
    required String title,
    String initialName = '',
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialName,
    );
    String? errorText;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Group name',
                  errorText: errorText,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(
                        () => errorText = 'Group name is required.',
                      );
                      return;
                    }
                    Navigator.pop(ctx, value);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> _ensureGroupsTableReady() async {
    if (_groupsTableReady) return true;
    try {
      final String userId = requireCurrentUserId();
      final List<_PeopleGroup> groups = await _loadGroups(userId);
      if (!mounted) return false;
      setState(() {
        _replaceGroups(_mergeGroupsWithPeople(groups, _people));
      });
      if (_groupsTableReady) return true;
    } catch (_) {}
    _showMessage('Run the people groups SQL first.');
    return false;
  }

  bool _groupNameExists(String name, {String? exceptId}) {
    final String normalizedName = _normalize(name);
    return _groups.any((_PeopleGroup group) {
      if (exceptId != null && group.id == exceptId) return false;
      return _normalize(group.name) == normalizedName;
    });
  }

  List<Person> _peopleForGroup(_PeopleGroup group) {
    final String groupName = _normalize(group.name);
    return _people.where((Person person) {
      final String role = _normalize(person.role ?? '');
      if (groupName == 'ungrouped') return role.isEmpty || role == groupName;
      return role == groupName;
    }).toList();
  }

  _PeopleGroup? get _selectedGroup {
    if (_groups.isEmpty) return null;
    final int index = _selectedGroupIndex.clamp(0, _groups.length - 1).toInt();
    return _groups[index];
  }

  String _normalize(String value) => value.trim().toLowerCase();

  Future<void> _addSamplePeople() async {
    setState(() => _isSeeding = true);
    try {
      final String userId = requireCurrentUserId();
      await _supabase.from('people').insert(<Map<String, dynamic>>[
        <String, dynamic>{
          'user_id': userId,
          'name': 'Juan Dela Cruz',
          'role': 'Family',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Maria Santos',
          'role': 'Family',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Jose Reyes',
          'role': 'Friend',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Ana Garcia',
          'role': 'Friend',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Pedro Ramos',
          'role': 'Coworker',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Liza Cruz',
          'role': 'Coworker',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Carlo Mendoza',
          'role': 'Family',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Nina Lopez',
          'role': 'Family',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Mark Flores',
          'role': 'Coworker',
        },
        <String, dynamic>{
          'user_id': userId,
          'name': 'Grace Aquino',
          'role': 'Coworker',
        },
      ]);

      if (!mounted) return;
      _showMessage('10 people added to Supabase.');
      await _loadPeople();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to add sample people.');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildGroupTab(_PeopleGroup group) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int count = _peopleForGroup(group).length;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(group.name),
          if (count > 0) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupPeople(_PeopleGroup group) {
    final List<Person> people = _peopleForGroup(group);

    if (people.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPeople,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 88, 32, 96),
          children: <Widget>[
            _EmptyPeopleState(
              groupName: group.name,
              hasAnyPeople: _people.isNotEmpty,
              isSeeding: _isSeeding,
              onAddSamplePeople: _addSamplePeople,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPeople,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        itemCount: people.length,
        itemBuilder: (BuildContext context, int index) {
          return PersonCard(person: people[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _selectedGroupIndex
        .clamp(0, _groups.length - 1)
        .toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Create group',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createGroup,
          ),
          PopupMenuButton<_GroupAction>(
            tooltip: 'Manage group',
            onSelected: (_GroupAction action) {
              switch (action) {
                case _GroupAction.rename:
                  _renameSelectedGroup();
                  break;
                case _GroupAction.delete:
                  _deleteSelectedGroup();
                  break;
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_GroupAction>>[
                  const PopupMenuItem<_GroupAction>(
                    value: _GroupAction.rename,
                    child: Text('Rename group'),
                  ),
                  const PopupMenuItem<_GroupAction>(
                    value: _GroupAction.delete,
                    child: Text('Delete group'),
                  ),
                ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddPerson,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              key: ValueKey<String>(
                _groups.map((_PeopleGroup group) => group.name).join('|'),
              ),
              length: _groups.length,
              initialIndex: selectedIndex,
              child: Column(
                children: <Widget>[
                  TabBar(
                    isScrollable: true,
                    onTap: (int index) {
                      setState(() => _selectedGroupIndex = index);
                    },
                    tabs: _groups.map(_buildGroupTab).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: _groups.map(_buildGroupPeople).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

enum _GroupAction { rename, delete }

class _PeopleGroup {
  const _PeopleGroup({required this.id, required this.name});

  final String id;
  final String name;

  factory _PeopleGroup.fromMap(Map<String, dynamic> map) {
    return _PeopleGroup(id: map['id'].toString(), name: map['name'].toString());
  }
}

class _EmptyPeopleState extends StatelessWidget {
  const _EmptyPeopleState({
    required this.groupName,
    required this.hasAnyPeople,
    required this.isSeeding,
    required this.onAddSamplePeople,
  });

  final String groupName;
  final bool hasAnyPeople;
  final bool isSeeding;
  final VoidCallback onAddSamplePeople;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.people_outline, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text(
            hasAnyPeople ? 'No people in $groupName' : 'No people yet',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyPeople
                ? 'Add a person while this group is selected.'
                : 'Add people to assign bills, payments, and responsibilities.',
            style: TextStyle(color: colors.outline),
            textAlign: TextAlign.center,
          ),
          if (!hasAnyPeople) ...<Widget>[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: isSeeding ? null : onAddSamplePeople,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(isSeeding ? 'Adding...' : 'Add 10 sample people'),
            ),
          ],
        ],
      ),
    );
  }
}
