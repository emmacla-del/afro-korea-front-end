/// MVP-only auth source.
///
/// The backend currently uses `x-user-id` as a stand-in for authentication.
/// For Step 4 we keep this intentionally minimal and hard-coded.
class MvpAuth {
  /// Hard-coded MVP user id (must be a UUID).
  static const String userId = '00000000-0000-0000-0000-000000000001';
}

