/// Holds the currently signed-in officer for the whole app session.
///
/// This is a prototype demo session. Production must replace it with
/// server-backed authentication and never keep credentials in client memory.
class OfficerSession {
  static String? officerId;
  static String? role;

  static bool get isAdmin => role == 'ADMIN';
}
