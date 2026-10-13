import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/messenger_group_create_request.dart';
import '../models/messenger_start_new_chat.dart';
import '../models/messenger_user.dart';
import '../models/messenger_user_directory.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_conversation_list_item.dart';
import 'messenger_default_inline_loading.dart';
import 'messenger_group_name_text_field.dart';
import 'messenger_list_search_field.dart';

/// Live snapshot for [MessengerStartNewChatPicker] while it is open.
class MessengerStartNewChatSheetLiveData {
  const MessengerStartNewChatSheetLiveData({
    required this.sortedUsers,
    required this.isUsersLoading,
    required this.openingDirectUserId,
    required this.isCreatingGroup,
    required this.directoryHasMore,
    required this.directoryLoadingMore,
  });

  final List<MessengerUser> sortedUsers;
  final bool isUsersLoading;
  final String openingDirectUserId;
  final bool isCreatingGroup;
  final bool directoryHasMore;
  final bool directoryLoadingMore;
}

/// Avoid treating every row as "opening" when both ids are empty (`'' == ''`).
bool messengerStartNewChatIsDirectOpenBusy(
  String openingDirectUserId,
  String userId,
) {
  final open = openingDirectUserId.trim();
  final uid = userId.trim();
  if (open.isEmpty || uid.isEmpty) {
    return false;
  }
  return open == uid;
}

/// Presents [MessengerStartNewChatPicker] using the package default bottom sheet.
Future<void> presentDefaultStartNewChatBottomSheet({
  required BuildContext context,
  required MessengerStartNewChatOpenRequest request,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => request.buildPicker(),
  );
}

/// Presents the start-new-chat picker via [presenter] or the default bottom sheet.
Future<void> presentMessengerStartNewChat({
  required BuildContext context,
  required MessengerStartNewChatMode mode,
  required Widget Function() buildPicker,
  required Future<void> Function(MessengerUser user) onOpenDirectChat,
  Future<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested,
  Future<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected,
  MessengerStartNewChatPresenter? presenter,
  double? topSafeInset,
}) {
  final request = MessengerStartNewChatOpenRequest(
    mode: mode,
    buildPicker: buildPicker,
    onOpenDirectChat: onOpenDirectChat,
    onCreateGroupRequested: onCreateGroupRequested,
    onCreateGroupSelected: onCreateGroupSelected,
  );
  if (presenter != null) {
    return presenter(context, request);
  }
  return presentDefaultStartNewChatBottomSheet(
    context: context,
    request: request,
  );
}

/// User picker for starting a direct chat or creating a group conversation.
class MessengerStartNewChatPicker extends StatefulWidget {
  const MessengerStartNewChatPicker({
    super.key,
    required this.sheetLive,
    required this.topSafeInset,
    required this.searchBackgroundColor,
    required this.searchIconColor,
    required this.searchHintStyle,
    required this.searchContentPadding,
    required this.searchBorderRadius,
    required this.searchInputTextStyle,
    required this.searchHintText,
    required this.emptyUsersBuilder,
    required this.emptyUsersMessage,
    required this.onOpenDirectChat,
    this.onCreateGroupSelected,
    this.onCreateGroupRequested,
    this.groupNameInputBehavior = MessengerGroupNameInputBehavior.hidden,
    this.groupNameFieldLabelText = 'Group name',
    this.groupNameFieldHintText = 'Enter a group name',
    this.groupNameRequiredErrorText = 'Enter a group name to continue.',
    this.defaultGroupNameWhenEmpty = 'Group',
    this.groupMinSelectionCount = 1,
    this.startNewChatDirectory,
    this.initialMode = MessengerStartNewChatMode.direct,
    this.groupSelectionListMode =
        MessengerGroupSelectionListMode.separateSelectedSection,
    this.userItemBuilder,
    this.selectedUsersSectionBuilder,
  }) : assert(
          groupMinSelectionCount > 0,
          'groupMinSelectionCount must be greater than zero.',
        );

  final ValueNotifier<MessengerStartNewChatSheetLiveData> sheetLive;
  final double topSafeInset;
  final Color searchBackgroundColor;
  final Color searchIconColor;
  final TextStyle searchHintStyle;
  final EdgeInsetsGeometry? searchContentPadding;
  final double searchBorderRadius;
  final TextStyle? searchInputTextStyle;
  final String searchHintText;
  final WidgetBuilder? emptyUsersBuilder;
  final String emptyUsersMessage;
  final FutureOr<void> Function(MessengerUser user) onOpenDirectChat;
  final FutureOr<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;
  final FutureOr<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;
  final MessengerGroupNameInputBehavior groupNameInputBehavior;
  final String groupNameFieldLabelText;
  final String groupNameFieldHintText;
  final String groupNameRequiredErrorText;
  final String defaultGroupNameWhenEmpty;
  final int groupMinSelectionCount;
  final MessengerStartNewChatDirectory? startNewChatDirectory;
  final MessengerStartNewChatMode initialMode;
  final MessengerGroupSelectionListMode groupSelectionListMode;
  final MessengerStartNewChatUserItemBuilder? userItemBuilder;
  final MessengerStartNewChatSelectedUsersSectionBuilder?
      selectedUsersSectionBuilder;

  @override
  State<MessengerStartNewChatPicker> createState() =>
      _MessengerStartNewChatPickerState();
}

class _MessengerStartNewChatPickerState extends State<MessengerStartNewChatPicker> {
  late final TextEditingController _searchController;
  late final TextEditingController _groupNameController;
  late final ScrollController _listScrollController;
  String _query = '';
  late bool _isGroupSelectionMode;
  List<String> _selectedUserIds = const <String>[];
  final Map<String, MessengerUser> _selectedUsersById = {};
  String? _groupNameErrorText;
  Timer? _searchDebounceTimer;
  bool _nearEndConsumed = false;
  int _trackedSortedLen = -1;
  bool _lastSheetDirectoryLoadingMore = false;

  bool get _serverSearchMode =>
      widget.startNewChatDirectory?.onSearchQueryDebounced != null;

  bool get _canCreateGroup =>
      widget.onCreateGroupSelected != null ||
      widget.onCreateGroupRequested != null;

  bool get _showGroupNameField =>
      widget.groupNameInputBehavior != MessengerGroupNameInputBehavior.hidden;

  bool get _groupNameIsRequired =>
      widget.groupNameInputBehavior == MessengerGroupNameInputBehavior.required;

  bool get _inlineCheckmarkMode =>
      widget.groupSelectionListMode ==
      MessengerGroupSelectionListMode.inlineCheckmark;

  bool get _showSelectedUsersSection =>
      _isGroupSelectionMode &&
      !_inlineCheckmarkMode &&
      _canCreateGroup;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _groupNameController = TextEditingController();
    _listScrollController = ScrollController();
    _isGroupSelectionMode =
        widget.initialMode == MessengerStartNewChatMode.group &&
            _canCreateGroup;
    _lastSheetDirectoryLoadingMore =
        widget.sheetLive.value.directoryLoadingMore;
    widget.sheetLive.addListener(_onSheetLiveChanged);
    _attachDirectoryScrollListener();
  }

  void _onSheetLiveChanged() {
    final data = widget.sheetLive.value;
    if (_lastSheetDirectoryLoadingMore && !data.directoryLoadingMore) {
      _nearEndConsumed = false;
    }
    _lastSheetDirectoryLoadingMore = data.directoryLoadingMore;
  }

  void _attachDirectoryScrollListener() {
    _listScrollController.removeListener(_onDirectoryScroll);
    if (widget.startNewChatDirectory?.onNearEndOfList != null) {
      _listScrollController.addListener(_onDirectoryScroll);
    }
  }

  void _onDirectoryScroll() {
    final d = widget.startNewChatDirectory;
    final live = widget.sheetLive.value;
    if (d == null ||
        d.onNearEndOfList == null ||
        !live.directoryHasMore ||
        live.directoryLoadingMore) {
      return;
    }
    if (!_listScrollController.hasClients) {
      return;
    }
    final pos = _listScrollController.position;
    if (pos.maxScrollExtent <= 0) {
      return;
    }
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      if (_nearEndConsumed) {
        return;
      }
      _nearEndConsumed = true;
      d.onNearEndOfList!();
    } else if (pos.pixels < pos.maxScrollExtent - 120) {
      _nearEndConsumed = false;
    }
  }

  void _handleSearchChanged(String raw) {
    setState(() {
      _query = raw.trim().toLowerCase();
    });
    final debounced = widget.startNewChatDirectory?.onSearchQueryDebounced;
    if (debounced == null) {
      return;
    }
    _searchDebounceTimer?.cancel();
    final delay = widget.startNewChatDirectory!.searchDebounce;
    void emit() {
      if (!mounted) {
        return;
      }
      debounced(_searchController.text.trim());
    }

    if (delay == Duration.zero) {
      emit();
    } else {
      _searchDebounceTimer = Timer(delay, emit);
    }
  }

  @override
  void dispose() {
    widget.sheetLive.removeListener(_onSheetLiveChanged);
    widget.sheetLive.dispose();
    _searchDebounceTimer?.cancel();
    _listScrollController.removeListener(_onDirectoryScroll);
    _listScrollController.dispose();
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessengerStartNewChatPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLive = oldWidget.sheetLive.value;
    final newLive = widget.sheetLive.value;
    if (oldLive.directoryLoadingMore == true &&
        newLive.directoryLoadingMore != true) {
      _nearEndConsumed = false;
    }
    _attachDirectoryScrollListener();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MessengerStartNewChatSheetLiveData>(
      valueListenable: widget.sheetLive,
      builder: (context, data, _) => _buildSheet(context, data),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    MessengerStartNewChatSheetLiveData data,
  ) {
    final len = data.sortedUsers.length;
    if (len != _trackedSortedLen) {
      _trackedSortedLen = len;
      _nearEndConsumed = false;
    }

    final q = _query;
    final List<MessengerUser> filteredUsers;
    if (_serverSearchMode || q.isEmpty) {
      filteredUsers = data.sortedUsers;
    } else {
      filteredUsers = data.sortedUsers
          .where(
            (user) =>
                user.username.toLowerCase().contains(q) ||
                user.roleLabel.toLowerCase().contains(q) ||
                user.email.toLowerCase().contains(q) ||
                user.id.toLowerCase().contains(q),
          )
          .toList(growable: false);
    }
    if (_serverSearchMode) {
      _refreshSelectedUsersCacheFrom(data.sortedUsers);
    }
    final selectedUsers = _resolveSelectedUsersFrom(data.sortedUsers);
    final visibleUsers = _isGroupSelectionMode && !_inlineCheckmarkMode
        ? filteredUsers
            .where((user) => !_selectedUserIds.contains(user.id.trim()))
            .toList(growable: false)
        : filteredUsers;

    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final screenH = mediaQuery.size.height;
    final safeTop = widget.topSafeInset;
    final maxSheetHeight = math.max(
      0.0,
      math.min(
        screenH * 0.88,
        screenH - safeTop - keyboardInset,
      ),
    );
    final theme = MessengerTheme.of(context);
    final groupBusy = data.isCreatingGroup;
    final minGroupModeUsersSectionHeight = math.min(
      260.0,
      maxSheetHeight * 0.45,
    );

    final usersSection = data.isUsersLoading && visibleUsers.isEmpty
        ? const MessengerDefaultInlineLoading()
        : visibleUsers.isEmpty
            ? _buildEmptyBody(context, theme)
            : _buildUserList(
                context,
                data,
                theme,
                visibleUsers,
                controller:
                    _isGroupSelectionMode ? null : _listScrollController,
                physics: _isGroupSelectionMode
                    ? const NeverScrollableScrollPhysics()
                    : null,
                shrinkWrap: _isGroupSelectionMode,
              );

    final headerAndControls = <Widget>[
      _buildHeader(theme, selectedUsers, groupBusy),
      const SizedBox(height: 4),
      Text(
        _isGroupSelectionMode
            ? 'Select people below to create a group conversation.'
            : "You don't have any conversations yet. Choose someone to start messaging.",
        textAlign: _isGroupSelectionMode ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: theme.subtleText,
          fontSize: 13,
          height: 1.35,
        ),
      ),
      if (_isGroupSelectionMode && _showGroupNameField) ...[
        const SizedBox(height: 12),
        MessengerGroupNameTextField(
          controller: _groupNameController,
          enabled: !groupBusy,
          labelText: widget.groupNameFieldLabelText,
          hintText: widget.groupNameFieldHintText,
          backgroundColor: widget.searchBackgroundColor,
          borderRadius: widget.searchBorderRadius,
          contentPadding: widget.searchContentPadding,
          iconColor: widget.searchIconColor,
          hintStyle: widget.searchHintStyle,
          inputTextStyle: widget.searchInputTextStyle,
          errorText: _groupNameErrorText,
          onChanged: (_) {
            if (_groupNameErrorText == null || !mounted) {
              return;
            }
            setState(() => _groupNameErrorText = null);
          },
        ),
      ],
      if (_showSelectedUsersSection) ...[
        const SizedBox(height: 12),
        _buildSelectedUsersSection(theme, selectedUsers, groupBusy),
      ],
      const SizedBox(height: 10),
      MessengerListSearchField(
        controller: _searchController,
        hintText: widget.searchHintText,
        hintStyle: widget.searchHintStyle,
        inputTextStyle: widget.searchInputTextStyle,
        backgroundColor: widget.searchBackgroundColor,
        iconColor: widget.searchIconColor,
        borderRadius: widget.searchBorderRadius,
        contentPadding: widget.searchContentPadding,
        onChanged: _handleSearchChanged,
        onClear: () {
          _searchController.clear();
          _handleSearchChanged('');
        },
      ),
      const SizedBox(height: 10),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            child: _isGroupSelectionMode
                ? SingleChildScrollView(
                    controller: _listScrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...headerAndControls,
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: minGroupModeUsersSectionHeight,
                          ),
                          child: usersSection,
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...headerAndControls,
                      Expanded(child: usersSection),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBody(BuildContext context, MessengerThemeData theme) {
    final isSearchActive = _searchController.text.trim().isNotEmpty;
    final emptyStyle = TextStyle(color: theme.subtleText);
    if (_isGroupSelectionMode) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _query.isEmpty
                ? 'No more people available to add right now.'
                : 'No people match your search.',
            style: emptyStyle,
          ),
        ),
      );
    }
    if (isSearchActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            'No users found',
            textAlign: TextAlign.center,
            style: emptyStyle,
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: widget.emptyUsersBuilder?.call(context) ??
            Text(
              widget.emptyUsersMessage,
              style: emptyStyle,
            ),
      ),
    );
  }

  Widget _buildUserList(
    BuildContext context,
    MessengerStartNewChatSheetLiveData data,
    MessengerThemeData theme,
    List<MessengerUser> visibleUsers, {
    ScrollController? controller,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
  }) {
    final dir = widget.startNewChatDirectory;
    final loadingFooter =
        dir != null && data.directoryLoadingMore && dir.onNearEndOfList != null;
    final extra = loadingFooter ? 1 : 0;
    final itemCount = visibleUsers.length + extra;

    return ListView.separated(
      controller: controller ?? _listScrollController,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, index) {
        if (index < visibleUsers.length - 1) {
          return const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFDADADA),
          );
        }
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        if (loadingFooter && index == visibleUsers.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.primary,
                ),
              ),
            ),
          );
        }
        final user = visibleUsers[index];
        final userId = user.id.trim();
        final isSelected = _selectedUserIds.contains(userId);
        final isSelectable = _isGroupSelectionMode;
        final isOpening = !_isGroupSelectionMode &&
            messengerStartNewChatIsDirectOpenBusy(
              data.openingDirectUserId,
              user.id,
            );
        final onTap = _isGroupSelectionMode
            ? () => _handleGroupUserTap(user)
            : () {
                final open = widget.onOpenDirectChat;
                final u = user;
                Navigator.of(context).pop();
                open(u);
              };

        final itemBuilder = widget.userItemBuilder;
        if (itemBuilder != null) {
          return itemBuilder(
            context,
            MessengerUserPickerItemData(
              user: user,
              isSelected: isSelected,
              isSelectable: isSelectable,
              isOpening: isOpening,
              onTap: onTap,
            ),
          );
        }

        return MessengerStartNewChatUserRow(
          user: user,
          isOpening: isOpening,
          isSelectable: isSelectable,
          isSelected: isSelected,
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildHeader(
    MessengerThemeData theme,
    List<MessengerUser> selectedUsers,
    bool groupBusy,
  ) {
    if (!_canCreateGroup) {
      return Center(
        child: _buildTitle(centered: true),
      );
    }
    if (!_isGroupSelectionMode) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildTitle()),
          TextButton(
            onPressed: groupBusy ? null : _toggleGroupMode,
            style: TextButton.styleFrom(
              foregroundColor: theme.primary,
              backgroundColor: theme.primary.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '+ New group',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    final canSubmit =
        !groupBusy && selectedUsers.length >= widget.groupMinSelectionCount;
    return Row(
      children: [
        TextButton(
          onPressed: groupBusy ? null : _resetGroupMode,
          style: TextButton.styleFrom(
            foregroundColor: theme.subtleText,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: _buildTitle(centered: true)),
        FilledButton(
          onPressed:
              canSubmit ? () => _submitGroupSelection(selectedUsers) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: groupBusy ? theme.primary : theme.border,
            disabledForegroundColor:
                groupBusy ? Colors.white : theme.subtleText,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: groupBusy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.1,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                )
              : const Text(
                  'Create',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }

  Widget _buildTitle({bool centered = false}) {
    return Text(
      'Start New Chat',
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _toggleGroupMode() {
    if (_isGroupSelectionMode) {
      _resetGroupMode();
      return;
    }
    setState(() {
      _isGroupSelectionMode = true;
      _selectedUserIds = const <String>[];
      _selectedUsersById.clear();
      _groupNameErrorText = null;
    });
  }

  void _resetGroupMode() {
    setState(() {
      _isGroupSelectionMode = false;
      _selectedUserIds = const <String>[];
      _selectedUsersById.clear();
      _groupNameErrorText = null;
    });
    _groupNameController.clear();
  }

  void _handleGroupUserTap(MessengerUser user) {
    final id = user.id.trim();
    if (id.isEmpty) {
      return;
    }
    if (_inlineCheckmarkMode) {
      setState(() {
        if (_selectedUserIds.contains(id)) {
          _selectedUserIds = _selectedUserIds
              .where((selectedId) => selectedId.trim() != id)
              .toList(growable: false);
          _selectedUsersById.remove(id);
        } else {
          _selectedUserIds = [id, ..._selectedUserIds];
          _selectedUsersById[id] = user;
        }
      });
      return;
    }
    _addSelectedUser(user);
  }

  void _addSelectedUser(MessengerUser user) {
    final id = user.id.trim();
    if (id.isEmpty || _selectedUserIds.contains(id)) {
      return;
    }
    setState(() {
      _selectedUserIds = [id, ..._selectedUserIds];
      _selectedUsersById[id] = user;
    });
  }

  void _removeSelectedUser(String userId) {
    final trimmed = userId.trim();
    setState(() {
      _selectedUserIds = _selectedUserIds
          .where((id) => id.trim() != trimmed)
          .toList(growable: false);
      _selectedUsersById.remove(trimmed);
    });
  }

  void _refreshSelectedUsersCacheFrom(List<MessengerUser> source) {
    if (_selectedUserIds.isEmpty) {
      return;
    }
    final byId = <String, MessengerUser>{
      for (final user in source) user.id.trim(): user,
    };
    for (final id in _selectedUserIds) {
      final fresh = byId[id.trim()];
      if (fresh != null) {
        _selectedUsersById[id] = fresh;
      }
    }
  }

  List<MessengerUser> _resolveSelectedUsersFrom(
    List<MessengerUser> sortedUsers,
  ) {
    final byId = <String, MessengerUser>{
      for (final user in sortedUsers) user.id.trim(): user,
    };
    return _selectedUserIds
        .map((id) {
          final trimmed = id.trim();
          return byId[trimmed] ?? _selectedUsersById[trimmed];
        })
        .whereType<MessengerUser>()
        .toList(growable: false);
  }

  String _groupNameForCreateRequest(String trimmedInput) {
    if (trimmedInput.isNotEmpty) {
      return trimmedInput;
    }
    if (_groupNameIsRequired) {
      return trimmedInput;
    }
    final fallback = widget.defaultGroupNameWhenEmpty.trim();
    return fallback.isEmpty ? 'Group' : fallback;
  }

  Future<void> _submitGroupSelection(List<MessengerUser> selectedUsers) async {
    final requestCallback = widget.onCreateGroupRequested;
    final callback = widget.onCreateGroupSelected;
    if ((requestCallback == null && callback == null) ||
        selectedUsers.length < widget.groupMinSelectionCount ||
        widget.sheetLive.value.isCreatingGroup) {
      return;
    }
    final trimmedGroupName = _groupNameController.text.trim();
    if (_groupNameIsRequired && trimmedGroupName.isEmpty) {
      setState(() => _groupNameErrorText = widget.groupNameRequiredErrorText);
      return;
    }
    try {
      if (requestCallback != null) {
        await requestCallback(
          MessengerGroupCreateRequest(
            selectedUsers: selectedUsers,
            groupName: _groupNameForCreateRequest(trimmedGroupName),
          ),
        );
      } else if (callback != null) {
        await callback(selectedUsers);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      // Host surfaces the failure; keep the sheet open so selection stays intact.
    }
  }

  Widget _buildSelectedUsersSection(
    MessengerThemeData theme,
    List<MessengerUser> selectedUsers,
    bool isCreatingGroup,
  ) {
    final custom = widget.selectedUsersSectionBuilder;
    if (custom != null) {
      return custom(
        context,
        selectedUsers,
        isCreatingGroup ? (_) {} : _removeSelectedUser,
      );
    }
    return _DefaultSelectedUsersSection(
      theme: theme,
      selectedUsers: selectedUsers,
      isCreatingGroup: isCreatingGroup,
      onRemove: _removeSelectedUser,
    );
  }
}

class _DefaultSelectedUsersSection extends StatelessWidget {
  const _DefaultSelectedUsersSection({
    required this.theme,
    required this.selectedUsers,
    required this.isCreatingGroup,
    required this.onRemove,
  });

  final MessengerThemeData theme;
  final List<MessengerUser> selectedUsers;
  final bool isCreatingGroup;
  final void Function(String userId) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected people (${selectedUsers.length})',
            style: TextStyle(
              color: theme.bubbleOtherText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (selectedUsers.isEmpty)
            Text(
              'No people selected yet.',
              style: TextStyle(
                color: theme.subtleText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            SizedBox(
              height: 40,
              child: ListView.separated(
                primary: false,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: selectedUsers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final user = selectedUsers[index];
                  return _SelectedUserChip(
                    user: user,
                    onRemove: isCreatingGroup
                        ? null
                        : () => onRemove(user.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({
    required this.user,
    required this.onRemove,
  });

  final MessengerUser user;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              conversationListItemDisplayName(user.username),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.bubbleOtherText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: onRemove == null ? theme.mutedText : theme.subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Default user row for [MessengerStartNewChatPicker].
class MessengerStartNewChatUserRow extends StatelessWidget {
  const MessengerStartNewChatUserRow({
    super.key,
    required this.user,
    required this.isOpening,
    required this.onTap,
    this.isSelectable = false,
    this.isSelected = false,
  });

  final MessengerUser user;
  final bool isOpening;
  final VoidCallback onTap;
  final bool isSelectable;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final role = user.roleLabel.trim();
    final email = user.email.trim();

    return InkWell(
      onTap: isOpening ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            MessengerAvatar(
              label: conversationListItemInitials(user.username),
              imageUrl: user.avatarUrl,
              compact: true,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversationListItemDisplayName(user.username),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: theme.bubbleOtherText,
                          ),
                        ),
                      ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        MessengerConversationListRoleChip(
                          label: role,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.subtleText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOpening)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (isSelectable)
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 22,
                color: isSelected ? theme.primary : theme.mutedText,
              ),
          ],
        ),
      ),
    );
  }
}
