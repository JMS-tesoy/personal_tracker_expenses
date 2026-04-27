import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
import '../../../people/data/people_repository.dart';
import '../../../people/domain/person.dart';
import '../../domain/bill.dart';
import '../widgets/bill_card.dart';
import 'add_bill_screen.dart';
import 'bill_details_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  late final StreamSubscription<List<Map<String, dynamic>>> _subscription;
  late final TabController _tabController;

  bool isLoading = true;
  BillModel? _selectedBill;
  List<BillModel> _unpaid = <BillModel>[];
  List<BillModel> _overdue = <BillModel>[];
  List<BillModel> _paid = <BillModel>[];

  Map<String, String> _peopleNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPeopleAndSubscribe();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPeopleAndSubscribe() async {
    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> people = await supabase
          .from('people')
          .select('id, name')
          .eq('user_id', userId);
      _peopleNames = <String, String>{
        for (final dynamic p in people)
          (p as Map<String, dynamic>)['id'].toString(): p['name'].toString(),
      };
    } catch (_) {}
    _subscribe();
  }

  void _subscribe() {
    final String userId = requireCurrentUserId();
    _subscription = supabase
        .from('bills')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', userId)
        .order('due_day', ascending: true)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (!mounted) return;
            final List<BillModel> all = data.map((Map<String, dynamic> row) {
              final Map<String, dynamic> enriched =
                  Map<String, dynamic>.from(row);
              enriched['assigned_person_name'] =
                  _peopleNames[row['assigned_person_id']?.toString()];
              enriched['paid_by_person_name'] =
                  _peopleNames[row['paid_by_person_id']?.toString()];
              final List<String> paidByPersonIds =
                  _stringList(row['paid_by_person_ids']);
              final List<String> displayPaidByPersonIds =
                  paidByPersonIds.isNotEmpty
                      ? paidByPersonIds
                      : <String>[
                          if (row['paid_by_person_id'] != null)
                            row['paid_by_person_id'].toString(),
                        ];
              enriched['paid_by_person_names'] = displayPaidByPersonIds
                  .map((String id) => _peopleNames[id])
                  .whereType<String>()
                  .toList();
              return BillModel.fromMap(enriched);
            }).toList();

            setState(() {
              _unpaid =
                  all.where((BillModel b) => !b.isPaid && !b.isOverdue).toList();
              _overdue =
                  all.where((BillModel b) => !b.isPaid && b.isOverdue).toList();
              _paid = all.where((BillModel b) => b.isPaid).toList();
              isLoading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => isLoading = false);
            _showMessage('Failed to load bills.');
          },
        );
  }

  /// Shows a dialog to pick the person who paid, then marks the bill paid.
  Future<void> _markPaid(BillModel bill) async {
    // Load people list
    final List<PersonModel> people = await PeopleRepository.instance.fetchAll();

    if (!mounted) return;

    final Set<String> selectedPersonIds = <String>{};

    // A payer is required because the unknown payer option was removed.
    if (people.isEmpty) {
      _showMessage('Add a person before marking this bill paid.');
      return;
    }

    final List<String>? chosen = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setLocal) {
            return AlertDialog(
              title: const Text('Who paid this bill?'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      ...people.map(
                        (PersonModel p) => CheckboxListTile(
                          value: selectedPersonIds.contains(p.id),
                          title: Text(p.name),
                          subtitle: p.role != null ? Text(p.role!) : null,
                          onChanged: (bool? checked) {
                            setLocal(() {
                              if (checked == true) {
                                selectedPersonIds.add(p.id);
                              } else {
                                selectedPersonIds.remove(p.id);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedPersonIds.isEmpty
                      ? null
                      : () => Navigator.pop(
                            ctx,
                            selectedPersonIds.toList(),
                          ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosen == null || chosen.isEmpty) return; // cancelled
    await _doMarkPaid(bill, chosen);
  }

  Future<void> _doMarkPaid(BillModel bill, List<String> payerIds) async {
    final String today = _toDbDate(DateTime.now());
    try {
      final String userId = requireCurrentUserId();
      final List<String> selectedPayerIds = payerIds.toSet().toList();
      final Map<String, dynamic> updateData = <String, dynamic>{
        'status': 'paid',
        'paid_on': today,
        'paid_by_person_id': selectedPayerIds.first,
        'paid_by_person_ids': selectedPayerIds,
      };

      await _updateBillWithMultiplePayerFallback(
        billId: bill.id,
        userId: userId,
        updateData: updateData,
        selectedPayerIds: selectedPayerIds,
      );

      await ActivityLogRepository.instance.createLog(
        targetType: 'bill',
        action: 'marked_paid',
        title: 'Bill marked as paid',
        targetId: bill.id,
        personId: selectedPayerIds.first,
        description: '${bill.name} was marked as paid.',
        metadata: <String, dynamic>{
          'bill_name': bill.name,
          'paid_by_person_id': selectedPayerIds.first,
          'paid_by_person_ids': selectedPayerIds,
        },
      );
    } on StateError catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Failed to mark bill as paid.');
    }
  }

  Future<void> _markUnpaid(BillModel bill) async {
    try {
      final String userId = requireCurrentUserId();
      await _updateBillWithMultiplePayerFallback(
        billId: bill.id,
        userId: userId,
        updateData: <String, dynamic>{
          'status': 'active',
          'paid_on': null,
          'paid_by_person_id': null,
          'paid_by_person_ids': <String>[],
        },
        selectedPayerIds: const <String>[],
      );

      await ActivityLogRepository.instance.createLog(
        targetType: 'bill',
        action: 'marked_unpaid',
        title: 'Bill marked as unpaid',
        targetId: bill.id,
        personId: bill.assignedPersonId,
        description: '${bill.name} was marked as unpaid.',
        metadata: <String, dynamic>{'bill_name': bill.name},
      );
    } catch (_) {
      _showMessage('Failed to mark bill as active.');
    }
  }


  Future<void> _updateBillWithMultiplePayerFallback({
    required String billId,
    required String userId,
    required Map<String, dynamic> updateData,
    required List<String> selectedPayerIds,
  }) async {
    try {
      await supabase
          .from('bills')
          .update(updateData)
          .eq('id', billId)
          .eq('user_id', userId);
    } on PostgrestException catch (error) {
      if (!_isMissingMultiplePayersColumn(error)) rethrow;

      if (selectedPayerIds.length > 1) {
        throw StateError(
          'Multiple bill payers need the paid_by_person_ids Supabase column.',
        );
      }

      final Map<String, dynamic> legacyUpdateData =
          Map<String, dynamic>.from(updateData)..remove('paid_by_person_ids');

      await supabase
          .from('bills')
          .update(legacyUpdateData)
          .eq('id', billId)
          .eq('user_id', userId);
    }
  }

  bool _isMissingMultiplePayersColumn(PostgrestException error) {
    return error.code == '42703' ||
        error.message.contains('paid_by_person_ids');
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _toDbDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Widget _buildSection(String title, List<BillModel> bills, Color titleColor) {
    if (bills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: titleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${bills.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...bills.map(
          (BillModel bill) => BillCard(
            bill: bill,
            onOpen: () => setState(() => _selectedBill = bill),
            onMarkPaid: () => _markPaid(bill),
            onMarkUnpaid: () => _markUnpaid(bill),
          ),
        ),
      ],
    );
  }

  Widget _buildUnpaidTab() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool empty = _unpaid.isEmpty && _overdue.isEmpty;

    if (empty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.check_circle_outline,
                size: 56, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No active bills',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "You're all caught up!",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        _buildSection('Overdue', _overdue, colors.error),
        _buildSection('Active', _unpaid, colors.primary),
      ],
    );
  }

  Widget _buildPaidTab() {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (_paid.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.receipt_long_outlined,
                size: 56, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No paid bills yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        _buildSection('Paid', _paid, const Color(0xFFA7D7B5)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final BillModel? selectedBill = _selectedBill;
    if (selectedBill != null) {
      return BillDetailsScreen(
        bill: selectedBill,
        onBack: () => setState(() => _selectedBill = null),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bills',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track and manage your monthly bills',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    tabs: <Tab>[
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('Active'),
                            if (_unpaid.isNotEmpty ||
                                _overdue.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.error
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_unpaid.length + _overdue.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('Paid'),
                            if (_paid.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_paid.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildUnpaidTab(),
                        _buildPaidTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(builder: (_) => const AddBillScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}