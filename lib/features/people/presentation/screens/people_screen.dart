import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/person.dart';
import '../widgets/person_card.dart';
import 'add_person_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Person> _people = <Person>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> response = await _supabase
          .from('people')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _people = response
            .map((dynamic e) => Person.fromMap(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to load people.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToAddPerson() async {
    final bool? result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AddPersonScreen()),
    );
    if (result == true) _loadPeople();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddPerson,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _people.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.people_outline, size: 64, color: colors.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No people yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add people to assign bills, payments, and responsibilities.',
                      style: TextStyle(color: colors.outline),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPeople,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                itemCount: _people.length,
                itemBuilder: (BuildContext context, int index) {
                  return PersonCard(person: _people[index]);
                },
              ),
            ),
    );
  }
}
