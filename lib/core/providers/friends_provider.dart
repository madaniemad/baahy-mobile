import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/friend.dart';

class FriendsState {
  final List<Friend> friends;
  final List<Friend> incomingRequests;
  final bool loading;

  const FriendsState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.loading = false,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    List<Friend>? incomingRequests,
    bool? loading,
  }) => FriendsState(
    friends:          friends          ?? this.friends,
    incomingRequests: incomingRequests ?? this.incomingRequests,
    loading:          loading          ?? this.loading,
  );
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier() : super(const FriendsState());

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get('/friends'),
        ApiClient.instance.dio.get('/friends/requests/incoming'),
      ]);
      final friends = (results[0].data['data'] as List? ?? [])
          .map((j) => Friend.fromJson(j as Map<String, dynamic>))
          .toList();
      final incoming = (results[1].data['data'] as List? ?? [])
          .map((j) => Friend.fromJson(j as Map<String, dynamic>))
          .toList();
      state = FriendsState(friends: friends, incomingRequests: incoming);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      state = state.copyWith(loading: false);
    }
  }

  Future<bool> sendRequest(String username) async {
    try {
      await ApiClient.instance.dio.post('/friends/request', data: {'username': username});
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  Future<bool> acceptRequest(int friendshipId) async {
    try {
      await ApiClient.instance.dio.post('/friends/$friendshipId/accept');
      await load();
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  Future<bool> declineRequest(int friendshipId) async {
    try {
      await ApiClient.instance.dio.post('/friends/$friendshipId/decline');
      state = state.copyWith(
        incomingRequests: state.incomingRequests.where((f) => f.friendshipId != friendshipId).toList(),
      );
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }

  Future<bool> removeFriend(int friendshipId) async {
    try {
      await ApiClient.instance.dio.delete('/friends/$friendshipId');
      state = state.copyWith(
        friends: state.friends.where((f) => f.friendshipId != friendshipId).toList(),
      );
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return false;
    }
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  return FriendsNotifier();
});
