import 'dart:async';

import 'package:flutter/material.dart';

import '../models/messenger_group_create_request.dart';
import '../models/messenger_user.dart';
import '../theme/messenger_theme.dart';
import 'messenger_avatar.dart';
import 'messenger_group_name_text_field.dart';
import 'messenger_list_search_chrome.dart';
import 'messenger_list_search_field.dart';

/// Self-contained panel that lists tenant users to start a brand new
/// direct chat with — explicitly **not** a conversations list.
///
/// Defaults render a "Suggested people" title, a helper line and a
/// vertical list of user rows. Every visual region can be overridden
/// via the optional builder / widget slots without losing tap behavior.
///
/// Typical wiring (host-composed or via [MessengerChatShell]'s
/// `suggestedPeopleBuilder` slot — use the third callback argument as
/// [onUserSelected] on mobile so the shell can open the full-screen thread):
///
/// ```dart
/// MessengerSuggestedPeoplePanel(
///   users: tenantUsers,
///   openingUserId: currentlyOpeningUserId,
///   onUserSelected: openDirectChat,
/// )
/// ```
class MessengerSuggestedPeoplePanel extends StatefulWidget {
  const MessengerSuggestedPeoplePanel({
    super.key,
    required this.users,
    required this.onUserSelected,
    this.openingUserId = '',
    this.titleText = 'Suggested people',
    this.helperText =
        "You don't have any conversations yet. Choose someone to start messaging.",
    this.titleWidget,
    this.helperWidget,
    this.headerBuilder,
    this.itemBuilder,
    this.separatorBuilder,
    this.footerWidget,
    this.emptyText = 'No people available right now.',
    this.emptyBuilder,
    this.isLoading = false,
    this.loadingBuilder,
    this.showSearchField = false,
    this.searchQuery = '',
    this.onSearchQueryChanged,
    this.searchHintText = 'Search people...',
    this.noSearchResultsText = 'No people match your search.',
    this.searchFieldBackgroundColor,
    this.searchIconColor,
    this.searchHintTextStyle,
    this.searchFieldContentPadding,
    this.searchFieldBorderRadius,
    this.searchInputTextStyle,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.itemSpacing = 8,
    this.titleTextStyle,
    this.helperTextStyle,
    this.physics,
    this.shrinkWrap = false,
    this.semanticsLabel = 'Suggested people',
    this.onPullToRefresh,
    this.onCreateGroupSelected,
    this.onCreateGroupRequested,
    this.isCreatingGroup = false,
    this.groupSelectionButtonText = 'New group',
    this.groupSelectionActiveButtonText = 'Group mode',
    this.groupCreateButtonText = 'Create group',
    this.groupCreateButtonBusyText = 'Creating…',
    this.groupCancelButtonText = 'Cancel',
    this.groupSelectionHelperText =
        'Select people below to create a group conversation.',
    this.selectedUsersTitleText = 'Selected people',
    this.selectedUsersEmptyText = 'No people selected yet.',
    this.groupEmptyText = 'No more people available to add right now.',
    this.groupMinSelectionCount = 2,
    this.groupNameInputBehavior = MessengerGroupNameInputBehavior.hidden,
    this.groupNameLabelText = 'Group name',
    this.groupNameHintText = 'Enter a group name',
    this.groupNameRequiredErrorText = 'Enter a group name to continue.',
  })  : assert(
          !showSearchField || onSearchQueryChanged != null,
          'onSearchQueryChanged is required when showSearchField is true.',
        ),
        assert(
          groupMinSelectionCount > 0,
          'groupMinSelectionCount must be greater than zero.',
        );

  /// Users to suggest starting a chat with.
  final List<MessengerUser> users;

  /// Invoked when a user row is tapped (default rows or your custom
  /// [itemBuilder] rows can call it).
  final FutureOr<void> Function(MessengerUser user) onUserSelected;

  /// User id whose row should currently appear busy (e.g. spinner) while
  /// the host is creating the underlying conversation.
  final String openingUserId;

  /// Default header title — ignored when [titleWidget] or [headerBuilder]
  /// is provided.
  final String titleText;

  /// Default helper line under the title — ignored when [helperWidget] or
  /// [headerBuilder] is provided.
  final String helperText;

  /// Replaces the default [titleText] widget when non-null. Ignored when
  /// [headerBuilder] is provided.
  final Widget? titleWidget;

  /// Replaces the default [helperText] widget when non-null. Ignored when
  /// [headerBuilder] is provided.
  final Widget? helperWidget;

  /// Replaces the entire header block (title + helper). Receives the
  /// current users so the host can show counts or contextual hints.
  final Widget Function(BuildContext context, List<MessengerUser> users)?
      headerBuilder;

  /// Builds an individual user row. When null, a built-in compact row is
  /// rendered (avatar + username + role + online dot).
  final Widget Function(BuildContext context, MessengerUser user, int index)?
      itemBuilder;

  /// Optional custom separator between rows. When null, a [SizedBox] of
  /// height [itemSpacing] is used.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Optional widget rendered below the user list (e.g. a privacy note).
  final Widget? footerWidget;

  /// Default empty-state copy when [users] is empty.
  final String emptyText;

  /// Custom builder for the empty state. Replaces [emptyText] when set.
  final WidgetBuilder? emptyBuilder;

  /// When true, the loading branch is rendered instead of the list.
  final bool isLoading;

  /// Custom loading builder. Defaults to a centered [CircularProgressIndicator].
  final WidgetBuilder? loadingBuilder;

  /// Enables the built-in search input shown above the people list.
  final bool showSearchField;

  /// Controlled query value used for local filtering when [showSearchField]
  /// is true.
  final String searchQuery;

  /// Called whenever the search input changes.
  final ValueChanged<String>? onSearchQueryChanged;

  /// Search input placeholder text.
  final String searchHintText;

  /// Copy shown when [searchQuery] has text but no users match.
  final String noSearchResultsText;

  /// Optional overrides — same semantics as [MessengerConversationList].
  ///
  /// When this panel is built under [MessengerChatShell], resolved values are
  /// also supplied via [MessengerListSearchChrome]; explicit non-null fields
  /// here take precedence over inherited chrome.
  final Color? searchFieldBackgroundColor;

  final Color? searchIconColor;

  final TextStyle? searchHintTextStyle;

  final EdgeInsetsGeometry? searchFieldContentPadding;

  final double? searchFieldBorderRadius;

  final TextStyle? searchInputTextStyle;

  /// Outer padding around the whole panel.
  final EdgeInsetsGeometry padding;

  /// Vertical gap between default rows when [separatorBuilder] is null.
  final double itemSpacing;

  /// Style override for the default title.
  final TextStyle? titleTextStyle;

  /// Style override for the default helper line.
  final TextStyle? helperTextStyle;

  /// Optional [ScrollPhysics] forwarded to the internal list.
  final ScrollPhysics? physics;

  /// Forwarded to the internal list. Set to true when nesting inside
  /// another scrollable.
  final bool shrinkWrap;

  /// Accessibility label wrapped around the panel.
  final String semanticsLabel;

  /// When non-null, the panel body is wrapped in [RefreshIndicator] and this
  /// callback is awaited on overscroll (same contract as [RefreshIndicator.onRefresh]).
  final Future<void> Function()? onPullToRefresh;

  /// Enables inline group-selection mode and receives the selected users when
  /// the host confirms creation.
  final FutureOr<void> Function(List<MessengerUser> selectedUsers)?
      onCreateGroupSelected;

  /// Preferred richer callback for group creation that also carries the
  /// requested group name when [groupNameInputBehavior] shows the input.
  final FutureOr<void> Function(MessengerGroupCreateRequest request)?
      onCreateGroupRequested;

  /// When true, the create-group CTA shows a busy state and selection changes
  /// are disabled.
  final bool isCreatingGroup;

  /// Trailing action text while group mode is inactive.
  final String groupSelectionButtonText;

  /// Trailing action text while group mode is active.
  final String groupSelectionActiveButtonText;

  /// Primary CTA text rendered while group mode is active.
  final String groupCreateButtonText;

  /// Label next to the spinner on the primary CTA while [isCreatingGroup] is true.
  final String groupCreateButtonBusyText;

  /// Secondary CTA text rendered while group mode is active.
  final String groupCancelButtonText;

  /// Helper copy shown while group mode is active.
  final String groupSelectionHelperText;

  /// Section label above the selected-user chips.
  final String selectedUsersTitleText;

  /// Placeholder shown when no users are selected yet.
  final String selectedUsersEmptyText;

  /// Empty copy shown when every visible person is already selected in group mode.
  final String groupEmptyText;

  /// Minimum required selected users before the create-group action is enabled.
  final int groupMinSelectionCount;

  /// Controls whether a group name field is hidden, optional, or required.
  final MessengerGroupNameInputBehavior groupNameInputBehavior;

  /// Label for the group name input when shown.
  final String groupNameLabelText;

  /// Placeholder text for the group name input when shown.
  final String groupNameHintText;

  /// Validation copy shown when the required group name is missing.
  final String groupNameRequiredErrorText;

  @override
  State<MessengerSuggestedPeoplePanel> createState() =>
      _MessengerSuggestedPeoplePanelState();
}

class _MessengerSuggestedPeoplePanelState
    extends State<MessengerSuggestedPeoplePanel> {
  bool _isGroupSelectionMode = false;
  List<String> _selectedUserIds = const <String>[];
  late final TextEditingController _groupNameController;
  late final TextEditingController _searchFieldController;
  late final FocusNode _searchFocusNode;
  String? _groupNameErrorText;

  bool get _canCreateGroup =>
      widget.onCreateGroupSelected != null ||
      widget.onCreateGroupRequested != null;
  bool get _showGroupNameField =>
      widget.groupNameInputBehavior != MessengerGroupNameInputBehavior.hidden;
  bool get _groupNameIsRequired =>
      widget.groupNameInputBehavior == MessengerGroupNameInputBehavior.required;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _searchFieldController = TextEditingController(text: widget.searchQuery);
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchFieldController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessengerSuggestedPeoplePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSearchFieldWithWidget(oldWidget);
    if (!_canCreateGroup && _isGroupSelectionMode) {
      _resetGroupSelection();
      return;
    }

    final validIds = widget.users.map((user) => user.id.trim()).toSet();
    final filtered = _selectedUserIds
        .where((id) => validIds.contains(id.trim()))
        .toList(growable: false);
    if (filtered.length != _selectedUserIds.length) {
      setState(() {
        _selectedUserIds = filtered;
      });
    }
  }

  void _syncSearchFieldWithWidget(MessengerSuggestedPeoplePanel oldWidget) {
    if (!widget.showSearchField) {
      return;
    }
    if (_searchFocusNode.hasFocus) {
      return;
    }
    if (!oldWidget.showSearchField) {
      _searchFieldController.text = widget.searchQuery;
      return;
    }
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchFieldController.text) {
      _searchFieldController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final searchChrome = _resolveSearchChrome(context, theme);
    final normalizedSearchQuery = widget.showSearchField
        ? _searchFieldController.text.trim()
        : widget.searchQuery.trim();
    final filteredUsers = _filterUsers(widget.users, normalizedSearchQuery);
    final selectedUsers = _selectedUsers(widget.users);
    final visibleUsers = _isGroupSelectionMode
        ? filteredUsers
            .where((user) => !_selectedUserIds.contains(user.id.trim()))
            .toList(growable: false)
        : filteredUsers;

    final header = widget.headerBuilder?.call(context, widget.users) ??
        _buildDefaultHeader(context, theme);

    Widget body;
    if (widget.isLoading) {
      body = widget.loadingBuilder?.call(context) ?? _buildDefaultLoading();
    } else if (widget.users.isEmpty) {
      body = widget.emptyBuilder?.call(context) ?? _buildDefaultEmpty(theme);
    } else if (visibleUsers.isEmpty && normalizedSearchQuery.isNotEmpty) {
      body = _buildNoSearchResults(theme);
    } else if (_isGroupSelectionMode && visibleUsers.isEmpty) {
      body = _buildGroupSelectionEmpty(theme);
    } else {
      body = _buildList(context, visibleUsers);
    }

    body = _wrapWithPullToRefresh(
      context,
      body,
      scrollableList: !widget.isLoading && visibleUsers.isNotEmpty,
    );

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (_isGroupSelectionMode) ...[
              if (_showGroupNameField) ...[
                const SizedBox(height: 12),
                MessengerGroupNameTextField(
                  controller: _groupNameController,
                  enabled: !widget.isCreatingGroup,
                  labelText: widget.groupNameLabelText,
                  hintText: widget.groupNameHintText,
                  backgroundColor: searchChrome.backgroundColor,
                  borderRadius: searchChrome.borderRadius,
                  contentPadding: searchChrome.contentPadding,
                  iconColor: searchChrome.iconColor,
                  hintStyle: searchChrome.hintStyle,
                  inputTextStyle: searchChrome.typingStyle(theme),
                  errorText: _groupNameErrorText,
                  onChanged: (_) {
                    if (_groupNameErrorText == null || !mounted) {
                      return;
                    }
                    setState(() => _groupNameErrorText = null);
                  },
                ),
              ],
              const SizedBox(height: 12),
              _buildSelectedUsersSection(theme, selectedUsers),
              const SizedBox(height: 10),
              _buildGroupActions(theme, selectedUsers),
            ],
            if (widget.showSearchField) ...[
              const SizedBox(height: 10),
              _buildSearchField(theme, searchChrome),
            ],
            const SizedBox(height: 12),
            Flexible(child: body),
            if (widget.footerWidget != null) ...[
              const SizedBox(height: 12),
              widget.footerWidget!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _wrapWithPullToRefresh(
    BuildContext context,
    Widget body, {
    required bool scrollableList,
  }) {
    final refresh = widget.onPullToRefresh;
    if (refresh == null) {
      return body;
    }
    if (scrollableList) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: body,
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultHeader(BuildContext context, MessengerThemeData theme) {
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final defaultTitleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: titleColor,
    ).merge(widget.titleTextStyle);
    final defaultHelperStyle = TextStyle(
      fontSize: 13,
      color: theme.subtleText,
      height: 1.35,
    ).merge(widget.helperTextStyle);

    final helper = _isGroupSelectionMode
        ? widget.groupSelectionHelperText
        : widget.helperText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: widget.titleWidget ??
                  Text(widget.titleText, style: defaultTitleStyle),
            ),
            if (_canCreateGroup) ...[
              const SizedBox(width: 12),
              _buildGroupModeToggleButton(theme),
            ],
          ],
        ),
        const SizedBox(height: 4),
        widget.helperWidget ?? Text(helper, style: defaultHelperStyle),
      ],
    );
  }

  Widget _buildGroupModeToggleButton(MessengerThemeData theme) {
    final isActive = _isGroupSelectionMode;
    return TextButton(
      onPressed: widget.isCreatingGroup ? null : _toggleGroupSelectionMode,
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.white : theme.primary,
        backgroundColor:
            isActive ? theme.primary : theme.primary.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(
        isActive
            ? widget.groupSelectionActiveButtonText
            : widget.groupSelectionButtonText,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSelectedUsersSection(
    MessengerThemeData theme,
    List<MessengerUser> selectedUsers,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.searchBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.selectedUsersTitleText} (${selectedUsers.length})',
            style: TextStyle(
              color: theme.bubbleOtherText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (selectedUsers.isEmpty)
            Text(
              widget.selectedUsersEmptyText,
              style: TextStyle(
                color: theme.subtleText,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedUsers
                  .map(
                    (user) => _SelectedUserChip(
                      user: user,
                      onRemove: widget.isCreatingGroup
                          ? null
                          : () => _removeSelectedUser(user.id),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupActions(
    MessengerThemeData theme,
    List<MessengerUser> selectedUsers,
  ) {
    final busy = widget.isCreatingGroup;
    final canSubmit = !busy &&
        selectedUsers.length >= widget.groupMinSelectionCount;

    return Row(
      children: [
        TextButton(
          onPressed: busy ? null : _resetGroupSelection,
          style: TextButton.styleFrom(
            foregroundColor: theme.subtleText,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          ),
          child: Text(
            widget.groupCancelButtonText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed:
              canSubmit ? () => _submitGroupSelection(selectedUsers) : null,
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: busy ? theme.primary : theme.border,
            disabledForegroundColor: busy ? Colors.white : theme.subtleText,
          ),
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.groupCreateButtonBusyText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              : Text(
                  widget.groupCreateButtonText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }

  Widget _buildDefaultLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty(MessengerThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          widget.emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(MessengerThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          widget.noSearchResultsText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelectionEmpty(MessengerThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          widget.groupEmptyText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(
    MessengerThemeData theme,
    _MessengerSearchFieldChrome chrome,
  ) {
    return MessengerListSearchField(
      controller: _searchFieldController,
      focusNode: _searchFocusNode,
      hintText: widget.searchHintText,
      hintStyle: chrome.hintStyle,
      inputTextStyle: chrome.typingStyle(theme),
      backgroundColor: chrome.backgroundColor,
      iconColor: chrome.iconColor,
      borderRadius: chrome.borderRadius,
      contentPadding: chrome.contentPadding,
      onChanged: widget.onSearchQueryChanged,
      onClear: widget.onSearchQueryChanged == null
          ? null
          : () {
              _searchFieldController.clear();
              widget.onSearchQueryChanged!.call('');
            },
    );
  }

  _MessengerSearchFieldChrome _resolveSearchChrome(
    BuildContext context,
    MessengerThemeData theme,
  ) {
    final inherited = MessengerListSearchChrome.maybeOf(context);
    return _MessengerSearchFieldChrome(
      backgroundColor: widget.searchFieldBackgroundColor ??
          inherited?.backgroundColor ??
          theme.searchBackground,
      iconColor: widget.searchIconColor ??
          inherited?.iconColor ??
          theme.mutedText,
      hintStyle: widget.searchHintTextStyle ??
          inherited?.hintStyle ??
          TextStyle(color: theme.mutedText),
      contentPadding:
          widget.searchFieldContentPadding ?? inherited?.contentPadding,
      borderRadius: widget.searchFieldBorderRadius ??
          inherited?.borderRadius ??
          12,
      inputTextStyle:
          widget.searchInputTextStyle ?? inherited?.inputTextStyle,
    );
  }

  Widget _buildList(BuildContext context, List<MessengerUser> visibleUsers) {
    final listPhysics = widget.onPullToRefresh != null
        ? AlwaysScrollableScrollPhysics(
            parent: widget.physics ?? const ClampingScrollPhysics(),
          )
        : widget.physics;

    return ListView.separated(
      primary: false,
      physics: listPhysics,
      shrinkWrap: widget.shrinkWrap,
      padding: EdgeInsets.zero,
      itemCount: visibleUsers.length,
      separatorBuilder: widget.separatorBuilder ??
          (_, __) => SizedBox(height: widget.itemSpacing),
      itemBuilder: (context, index) {
        final user = visibleUsers[index];
        if (!_isGroupSelectionMode && widget.itemBuilder != null) {
          return widget.itemBuilder!(context, user, index);
        }
        return _SuggestedUserRow(
          user: user,
          isOpening: !_isGroupSelectionMode && _isOpening(user.id),
          isSelectable: _isGroupSelectionMode,
          onTap: () => _handleUserTap(user),
        );
      },
    );
  }

  bool _isOpening(String userId) {
    final opening = widget.openingUserId.trim();
    if (opening.isEmpty) {
      return false;
    }
    return opening == userId.trim();
  }

  void _toggleGroupSelectionMode() {
    if (_isGroupSelectionMode) {
      _resetGroupSelection();
      return;
    }
    setState(() {
      _isGroupSelectionMode = true;
      _selectedUserIds = const <String>[];
      _groupNameErrorText = null;
    });
  }

  void _resetGroupSelection() {
    setState(() {
      _isGroupSelectionMode = false;
      _selectedUserIds = const <String>[];
      _groupNameErrorText = null;
    });
    _groupNameController.clear();
  }

  Future<void> _submitGroupSelection(List<MessengerUser> selectedUsers) async {
    final requestCallback = widget.onCreateGroupRequested;
    final callback = widget.onCreateGroupSelected;
    if ((requestCallback == null && callback == null) ||
        widget.isCreatingGroup ||
        selectedUsers.length < widget.groupMinSelectionCount) {
      return;
    }
    final trimmedGroupName = _groupNameController.text.trim();
    if (_groupNameIsRequired && trimmedGroupName.isEmpty) {
      setState(() => _groupNameErrorText = widget.groupNameRequiredErrorText);
      return;
    }
    if (requestCallback != null) {
      await requestCallback(
        MessengerGroupCreateRequest(
          selectedUsers: selectedUsers,
          groupName: trimmedGroupName,
        ),
      );
    } else if (callback != null) {
      await callback(selectedUsers);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isGroupSelectionMode = false;
      _selectedUserIds = const <String>[];
    });
  }

  Future<void> _handleUserTap(MessengerUser user) async {
    if (_isGroupSelectionMode) {
      final id = user.id.trim();
      if (id.isEmpty || _selectedUserIds.contains(id)) {
        return;
      }
      setState(() {
        _selectedUserIds = [..._selectedUserIds, id];
      });
      return;
    }
    await widget.onUserSelected(user);
  }

  void _removeSelectedUser(String userId) {
    setState(() {
      _selectedUserIds = _selectedUserIds
          .where((id) => id.trim() != userId.trim())
          .toList(growable: false);
    });
  }

  List<MessengerUser> _selectedUsers(List<MessengerUser> source) {
    final byId = <String, MessengerUser>{
      for (final user in source) user.id.trim(): user,
    };
    return _selectedUserIds
        .map((id) => byId[id.trim()])
        .whereType<MessengerUser>()
        .toList(growable: false);
  }

  List<MessengerUser> _filterUsers(
    List<MessengerUser> source,
    String query,
  ) {
    final q = query.toLowerCase();
    if (q.isEmpty) {
      return source;
    }
    return source.where((user) {
      return user.username.toLowerCase().contains(q) ||
          user.roleLabel.toLowerCase().contains(q) ||
          user.id.toLowerCase().contains(q);
    }).toList(growable: false);
  }
}

class _MessengerSearchFieldChrome {
  const _MessengerSearchFieldChrome({
    required this.backgroundColor,
    required this.iconColor,
    required this.hintStyle,
    required this.borderRadius,
    this.contentPadding,
    this.inputTextStyle,
  });

  final Color backgroundColor;
  final Color iconColor;
  final TextStyle hintStyle;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? inputTextStyle;

  TextStyle typingStyle(MessengerThemeData theme) =>
      inputTextStyle ??
      TextStyle(
        color: theme.bubbleOtherText,
        fontSize: 14,
      );
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
        color: theme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              user.username,
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

class _SuggestedUserRow extends StatelessWidget {
  const _SuggestedUserRow({
    required this.user,
    required this.isOpening,
    required this.isSelectable,
    required this.onTap,
  });

  final MessengerUser user;
  final bool isOpening;
  final bool isSelectable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = MessengerTheme.of(context);
    final subtitleParts = <String>[
      if (user.roleLabel.trim().isNotEmpty) user.roleLabel.trim(),
      user.isOnline ? 'Online' : 'Offline',
    ];
    final subtitle = subtitleParts.join(' • ');

    return InkWell(
      onTap: isOpening ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            MessengerAvatar(
              label: _initials(user.username),
              imageUrl: user.avatarUrl,
              compact: true,
              size: 36,
              showOnlineIndicator: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: theme.bubbleOtherText,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
            else
              Icon(
                isSelectable
                    ? Icons.add_circle_outline_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: theme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'CH';
    }
    if (parts.length == 1) {
      final part = parts.first;
      return part.substring(0, part.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}
