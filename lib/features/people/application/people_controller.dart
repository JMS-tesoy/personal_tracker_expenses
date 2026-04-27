// lib/features/people/application/people_controller.dart

import 'package:flutter/foundation.dart';

import '../data/people_repository.dart';
import '../domain/person.dart';

class PeopleController extends ChangeNotifier {
  PeopleController() {
    load();
  }

  final PeopleRepository _repo = PeopleRepository.instance;

  List<PersonModel> people = <PersonModel>[];
  bool isLoading = false;
  String? error;

  // ── Load all people ─────────────────────────────────────────────────────────

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      people = await _repo.fetchAll();
    } catch (e) {
      error = 'Failed to load people.';
      debugPrint('PeopleController.load error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<bool> addPerson(PersonModel person) async {
    final PersonModel? saved = await _repo.create(person);
    if (saved == null) return false;
    people = <PersonModel>[...people, saved]
      ..sort((PersonModel a, PersonModel b) => a.name.compareTo(b.name));
    notifyListeners();
    return true;
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<bool> updatePerson(PersonModel person) async {
    final PersonModel? updated = await _repo.update(person);
    if (updated == null) return false;
    people = people
        .map((PersonModel p) => p.id == updated.id ? updated : p)
        .toList();
    notifyListeners();
    return true;
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<bool> deletePerson(String personId) async {
    final bool ok = await _repo.delete(personId);
    if (!ok) return false;
    people = people.where((PersonModel p) => p.id != personId).toList();
    notifyListeners();
    return true;
  }
}
