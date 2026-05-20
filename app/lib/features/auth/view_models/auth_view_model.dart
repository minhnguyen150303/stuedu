import 'package:flutter/material.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository repo;

  bool loading = false;
  Map<String, dynamic>? user;

  AuthViewModel(this.repo);

  Future<Map<String, dynamic>> loginGoogle() async {
    loading = true;
    notifyListeners();

    try {
      user = await repo.loginGoogle();
      return user!;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> loginEmailPassword({
    required String email,
    required String password,
  }) async {
    loading = true;
    notifyListeners();

    try {
      user = await repo.loginEmailPassword(email: email, password: password);
      return user!;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
