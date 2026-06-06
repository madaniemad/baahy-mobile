import 'friendship_status.dart';

class Friend {
  final int id;
  final String? username;
  final String name;
  final String? avatar;
  final String? currentTier;
  final FriendshipStatus friendshipStatus;
  final int? friendshipId;

  const Friend({
    required this.id,
    this.username,
    required this.name,
    this.avatar,
    this.currentTier,
    this.friendshipStatus = FriendshipStatus.none,
    this.friendshipId,
  });

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
    id:               (j['id'] as num?)?.toInt() ?? 0,
    username:         j['username'] as String?,
    name:             j['name'] as String? ?? '',
    avatar:           j['avatar'] as String?,
    currentTier:      j['current_tier'] as String?,
    friendshipStatus: FriendshipStatus.fromString(j['friendship_status'] as String?),
    friendshipId:     (j['friendship_id'] as num?)?.toInt(),
  );
}
