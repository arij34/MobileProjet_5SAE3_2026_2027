import '../../features/users/models/user.dart';

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  User? currentUser;

  bool get isLoggedIn => currentUser != null;

  void logout() => currentUser = null;
}