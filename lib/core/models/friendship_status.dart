enum FriendshipStatus {
  none,
  pendingSent,
  pendingReceived,
  accepted;

  static FriendshipStatus fromString(String? s) => switch (s) {
    'pending_sent'     => FriendshipStatus.pendingSent,
    'pending_received' => FriendshipStatus.pendingReceived,
    'accepted'         => FriendshipStatus.accepted,
    _                  => FriendshipStatus.none,
  };
}
