import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../sources/remote/api_client.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiClient api;

  AuthRepository(this.api);

  Future<Map<String, dynamic>> _fetchProfileWithToken(User user) async {
    final token = await user.getIdToken();
    api.setToken(token!);
    final res = await api.dio.post("/auth/me");
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> loginWithCurrentUser(User user) async {
    return _fetchProfileWithToken(user);
  }

  /// 1) Login bằng Google
  Future<Map<String, dynamic>> loginGoogle() async {
    final googleSignIn = GoogleSignIn();

    // Ép hiện account picker (không auto dùng acc cũ)
    await googleSignIn.signOut();
    // Nếu vẫn auto chọn acc cũ thì đổi sang:
    // await googleSignIn.disconnect();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception("User cancelled login");
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;
    return _fetchProfileWithToken(user);
  }

  /// 2) Login bằng Email/Password (Firebase Auth)
  Future<Map<String, dynamic>> loginEmailPassword({
    required String email,
    required String password,
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = userCredential.user!;
    return _fetchProfileWithToken(user);
  }
}
