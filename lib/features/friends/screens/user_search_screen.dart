import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/friend.dart';
import '../../../core/models/friendship_status.dart';
import '../../../core/providers/friends_provider.dart';
import '../../../core/providers/user_search_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(userSearchProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.col.ink0),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          onChanged: (v) => ref.read(userSearchProvider.notifier).search(v),
          decoration: InputDecoration(
            hintText: context.tr('ابحث عن اسم المستخدم...', 'Search username...'),
            hintStyle: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink3, fontSize: 14),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      ref.read(userSearchProvider.notifier).clear();
                    },
                  )
                : null,
          ),
          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink0, fontSize: 15),
        ),
      ),
      body: searchState.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : searchState.results.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search, size: 56, color: context.col.ink3),
                    const SizedBox(height: 12),
                    Text(context.tr('ابحث عن صديق بالاسم المستخدم', 'Search by username'),
                      style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], color: context.col.ink2, fontSize: 14)),
                  ]),
                )
              : ListView.builder(
                  itemCount: searchState.results.length,
                  itemBuilder: (_, i) => _SearchResultTile(friend: searchState.results[i]),
                ),
    );
  }
}

class _SearchResultTile extends ConsumerStatefulWidget {
  final Friend friend;
  const _SearchResultTile({required this.friend});

  @override
  ConsumerState<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends ConsumerState<_SearchResultTile> {
  bool _loading = false;
  FriendshipStatus _status = FriendshipStatus.none;

  @override
  void initState() {
    super.initState();
    _status = widget.friend.friendshipStatus;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => safePush(context, '/friends/${widget.friend.username}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _avatar(),
      title: Text(widget.friend.name,
        style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700, fontSize: 15)),
      subtitle: widget.friend.username != null
          ? Text('@${widget.friend.username}', style: TextStyle(fontSize: 12, color: context.col.ink3))
          : null,
      trailing: _actionButton(context),
    );
  }

  Widget _avatar() {
    if (widget.friend.avatar != null && widget.friend.avatar!.isNotEmpty) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(widget.friend.avatar!));
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        widget.friend.name.isNotEmpty ? widget.friend.name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionButton(BuildContext context) {
    if (_loading) return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    return switch (_status) {
      FriendshipStatus.accepted => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Text(context.tr('أصدقاء', 'Friends'),
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
        ),
      FriendshipStatus.pendingSent => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.col.border),
          ),
          child: Text(context.tr('معلق', 'Pending'),
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: context.col.ink2)),
        ),
      _ => GestureDetector(
          onTap: _sendRequest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(context.tr('إضافة', 'Add'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
    };
  }

  Future<void> _sendRequest() async {
    final username = widget.friend.username;
    if (username == null) return;
    setState(() => _loading = true);
    final ok = await ref.read(friendsProvider.notifier).sendRequest(username);
    setState(() {
      _loading = false;
      if (ok) _status = FriendshipStatus.pendingSent;
    });
  }
}
