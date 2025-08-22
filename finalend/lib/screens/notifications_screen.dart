// lib/screens/notifications_screen.dart

import 'dart:async';
import 'dart:math'; // For picking a random placeholder
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' as ui;
import 'package:another_flushbar/flushbar.dart';

import '../services/firebase_service.dart';
import '../models/job.dart';
import '../models/worker.dart';
import 'jobs/job_detail_screen.dart';

// --- ENUMS for Filtering and Sorting ---
enum NotificationFilter { all, unread }

enum NotificationSort { dateDesc, dateAsc, priority }

enum NotificationTypeFilter { all, applications, updates, payments }

// =======================================================================
// === HELPER FUNCTION & CLASS
// =======================================================================
bool _safeReadBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

class IconInfo {
  final IconData icon;
  final Color color;
  IconInfo({required this.icon, required this.color});
}

// =======================================================================
// === MAIN NOTIFICATION SCREEN WIDGET
// =======================================================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;

  NotificationFilter _currentFilter = NotificationFilter.all;
  NotificationSort _currentSort = NotificationSort.dateDesc;
  NotificationTypeFilter _currentTypeFilter = NotificationTypeFilter.all;

  bool _isMultiSelectMode = false;
  final Set<String> _selectedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _markAllAsRead(List<Map<String, dynamic>> notifications) {
    if (!mounted) return;

    final unreadIds = notifications
        .where((n) => _safeReadBool(n['isRead']) == false)
        .map((n) => n['id'] as String)
        .toList();

    if (unreadIds.isNotEmpty) {
      _firebaseService
          .batchUpdateNotifications(unreadIds, {'isRead': true})
          .catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Couldn't mark all as read.")),
              );
            }
          });
    }
  }

  void _toggleMultiSelectMode({String? initialSelectionId}) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_isMultiSelectMode) {
        _selectedNotificationIds.clear();
        _isMultiSelectMode = false;
      } else {
        _isMultiSelectMode = true;
        if (initialSelectionId != null) {
          _selectedNotificationIds.add(initialSelectionId);
        }
      }
    });
  }

  void _onNotificationSelected(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedNotificationIds.contains(id)) {
        _selectedNotificationIds.remove(id);
        if (_selectedNotificationIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedNotificationIds.add(id);
      }
    });
  }

  Future<void> _performBatchAction(
    Future<void> Function(List<String>) action,
    String successMessage,
    String failureMessage,
  ) async {
    final ids = List<String>.from(_selectedNotificationIds);
    if (ids.isEmpty) return;

    try {
      await action(ids);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failureMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedNotificationIds.clear();
          _isMultiSelectMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                _isMultiSelectMode
                    ? "${_selectedNotificationIds.length} Selected"
                    : "Notifications Inbox",
              ),
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              leading: _isMultiSelectMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _toggleMultiSelectMode(),
                    )
                  : null,
              actions: _isMultiSelectMode
                  ? _buildMultiSelectActions()
                  : [
                      IconButton(
                        icon: const Icon(Icons.select_all_outlined),
                        tooltip: "Select Mode",
                        onPressed: () => _toggleMultiSelectMode(),
                      ),
                    ],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.inbox_outlined), text: "Inbox"),
                  Tab(icon: Icon(Icons.archive_outlined), text: "Archived"),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _FilterBarDelegate(child: _buildFilterBar(theme)),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Inbox Tab
            _NotificationListView(
              key: const PageStorageKey('inbox'),
              // This is the key part: it fetches notifications for the currently
              // logged-in user, whether they are a client or a worker.
              streamFuture: _firebaseService.getNotificationsStream(
                isArchived: false,
              ),
              isMultiSelectMode: _isMultiSelectMode,
              selectedIds: _selectedNotificationIds,
              onLongPress: (id) =>
                  _toggleMultiSelectMode(initialSelectionId: id),
              onSelected: _onNotificationSelected,
              processNotifications: _processNotifications,
              onNotificationsLoaded: _markAllAsRead,
            ),
            // Archived Tab
            _NotificationListView(
              key: const PageStorageKey('archived'),
              streamFuture: _firebaseService.getNotificationsStream(
                isArchived: true,
              ),
              isMultiSelectMode: _isMultiSelectMode,
              selectedIds: _selectedNotificationIds,
              onLongPress: (id) =>
                  _toggleMultiSelectMode(initialSelectionId: id),
              onSelected: _onNotificationSelected,
              processNotifications: _processNotifications,
              onNotificationsLoaded: (notifications) {}, // No action needed
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isMultiSelectMode
          ? _buildMultiSelectActionBar(theme)
          : null,
    );
  }

  List<Widget> _buildMultiSelectActions() {
    return [
      IconButton(
        icon: const Icon(Icons.mark_email_read_outlined),
        tooltip: "Mark as Read",
        onPressed: () => _performBatchAction(
          (ids) =>
              _firebaseService.batchUpdateNotifications(ids, {'isRead': true}),
          "${_selectedNotificationIds.length} notifications marked as read.",
          "Failed to mark as read.",
        ),
      ),
      IconButton(
        icon: const Icon(Icons.mark_email_unread_outlined),
        tooltip: "Mark as Unread",
        onPressed: () => _performBatchAction(
          (ids) =>
              _firebaseService.batchUpdateNotifications(ids, {'isRead': false}),
          "${_selectedNotificationIds.length} notifications marked as unread.",
          "Failed to mark as unread.",
        ),
      ),
    ];
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Material(
      elevation: 1,
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 110.0,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: NotificationTypeFilter.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(toBeginningOfSentenceCase(type.name)!),
                      selected: _currentTypeFilter == type,
                      onSelected: (val) {
                        if (val) setState(() => _currentTypeFilter = type);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<NotificationFilter>(
                    value: _currentFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: NotificationFilter.all,
                        child: Text("All Statuses"),
                      ),
                      DropdownMenuItem(
                        value: NotificationFilter.unread,
                        child: Text("Unread Only"),
                      ),
                    ],
                    onChanged: (val) => setState(() => _currentFilter = val!),
                  ),
                  DropdownButton<NotificationSort>(
                    value: _currentSort,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: NotificationSort.dateDesc,
                        child: Text("Newest First"),
                      ),
                      DropdownMenuItem(
                        value: NotificationSort.dateAsc,
                        child: Text("Oldest First"),
                      ),
                      DropdownMenuItem(
                        value: NotificationSort.priority,
                        child: Text("By Priority"),
                      ),
                    ],
                    onChanged: (val) => setState(() => _currentSort = val!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectActionBar(ThemeData theme) {
    bool isArchivedView = _tabController.index == 1;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            icon: Icon(
              isArchivedView
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            label: Text(isArchivedView ? "Unarchive" : "Archive"),
            onPressed: () => _performBatchAction(
              (ids) => _firebaseService.batchUpdateNotifications(ids, {
                'isArchived': !isArchivedView,
              }),
              "${_selectedNotificationIds.length} notifications ${isArchivedView ? 'unarchived' : 'archived'}.",
              "Failed to ${isArchivedView ? 'unarchive' : 'archive'}.",
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text("Delete (${_selectedNotificationIds.length})"),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => _performBatchAction(
              _firebaseService.batchDeleteNotifications,
              "${_selectedNotificationIds.length} notifications deleted.",
              "Failed to delete.",
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _processNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    List<Map<String, dynamic>> filtered = List.from(notifications);
    if (_currentTypeFilter != NotificationTypeFilter.all) {
      filtered = filtered.where((n) {
        String type = n['type'] ?? '';
        switch (_currentTypeFilter) {
          case NotificationTypeFilter.applications:
            return type == 'job_application';
          case NotificationTypeFilter.updates:
            return type.contains('update') ||
                type.contains('accepted') ||
                type.contains('completed') ||
                type.contains('rejected');
          case NotificationTypeFilter.payments:
            return type.contains('payment');
          default:
            return true;
        }
      }).toList();
    }
    if (_currentFilter == NotificationFilter.unread) {
      filtered = filtered.where((n) => !_safeReadBool(n['isRead'])).toList();
    }
    filtered.sort((a, b) {
      final aCreatedAt = a['createdAt'] as Timestamp?;
      final bCreatedAt = b['createdAt'] as Timestamp?;
      if (aCreatedAt == null || bCreatedAt == null) return 0;
      switch (_currentSort) {
        case NotificationSort.dateAsc:
          return aCreatedAt.compareTo(bCreatedAt);
        case NotificationSort.priority:
          final priorityA = a['priority'] as int? ?? 1;
          final priorityB = b['priority'] as int? ?? 1;
          int priorityCompare = priorityB.compareTo(priorityA);
          return priorityCompare != 0
              ? priorityCompare
              : bCreatedAt.compareTo(aCreatedAt);
        case NotificationSort.dateDesc:
        default:
          return bCreatedAt.compareTo(aCreatedAt);
      }
    });
    return filtered;
  }
}

// =======================================================================
// === NOTIFICATION LIST VIEW (WITH IN-APP NOTIFICATIONS)
// =======================================================================
class _NotificationListView extends StatefulWidget {
  final Future<Stream<List<Map<String, dynamic>>>> streamFuture;
  final Function(List<Map<String, dynamic>>) processNotifications;
  final bool isMultiSelectMode;
  final Set<String> selectedIds;
  final Function(String) onSelected;
  final Function(String) onLongPress;
  final void Function(List<Map<String, dynamic>>) onNotificationsLoaded;

  const _NotificationListView({
    super.key,
    required this.streamFuture,
    required this.processNotifications,
    required this.isMultiSelectMode,
    required this.selectedIds,
    required this.onSelected,
    required this.onLongPress,
    required this.onNotificationsLoaded,
  });

  @override
  State<_NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<_NotificationListView> {
  Set<String> _currentNotificationIds = {};
  bool _isInitialLoad = true;

  void _showInAppNotification(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);

    String? imageUrl;
    if (notification['type'] == 'job_application') {
      imageUrl = data['workerImageUrl'] as String?;
    } else if (notification['type'] == 'job_accepted') {
      imageUrl = data['clientImageUrl'] as String?;
    }

    Flushbar(
      titleText: Text(
        notification['title'] ?? 'New Notification',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      messageText: Text(
        notification['body'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
        ),
      ),
      icon: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
            ? CachedNetworkImageProvider(imageUrl)
            : null,
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Icon(
                Icons.notifications,
                color: theme.colorScheme.onPrimaryContainer,
              )
            : null,
      ),
      onTap: (_) {
        final jobId = data['jobId'];
        if (jobId != null) {
          FirebaseService().getJobById(jobId).then((job) {
            if (job != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobDetailScreen(job: job),
                ),
              );
            }
          });
        }
      },
      duration: const Duration(seconds: 4),
      flushbarPosition: FlushbarPosition.TOP,
      backgroundColor: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(12),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stream<List<Map<String, dynamic>>>>(
      future: widget.streamFuture,
      builder: (context, futureSnapshot) {
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return const _ShimmerList();
        }

        if (futureSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${futureSnapshot.error}'),
            ),
          );
        }

        if (!futureSnapshot.hasData) {
          // This can happen briefly before the stream is available
          return const _ShimmerList();
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: futureSnapshot.data!,
          builder: (context, streamSnapshot) {
            if (streamSnapshot.connectionState == ConnectionState.waiting &&
                !streamSnapshot.hasData) {
              return const _ShimmerList();
            }
            if (streamSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${streamSnapshot.error}'),
                ),
              );
            }
            if (!streamSnapshot.hasData || streamSnapshot.data!.isEmpty) {
              return _buildEmptyState(context);
            }

            final allNotifications = streamSnapshot.data!;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onNotificationsLoaded(allNotifications);
                final newIds = allNotifications
                    .map((n) => n['id'] as String)
                    .toSet();
                if (_isInitialLoad) {
                  _currentNotificationIds = newIds;
                  _isInitialLoad = false;
                } else {
                  final newlyAdded = newIds.difference(_currentNotificationIds);
                  if (newlyAdded.isNotEmpty) {
                    for (final newId in newlyAdded) {
                      final newNotification = allNotifications.firstWhere(
                        (n) => n['id'] == newId,
                      );
                      _showInAppNotification(context, newNotification);
                    }
                  }
                  _currentNotificationIds = newIds;
                }
              }
            });

            List<Map<String, dynamic>> processedNotifications = widget
                .processNotifications(allNotifications);

            if (processedNotifications.isEmpty) {
              return _buildEmptyState(context, isFiltered: true);
            }

            return AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                itemCount: processedNotifications.length,
                itemBuilder: (context, index) {
                  final notification = processedNotifications[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 450),
                    child: SlideAnimation(
                      verticalOffset: 70.0,
                      child: FadeInAnimation(
                        child: _NotificationCardRouter(
                          notification: notification,
                          isMultiSelectMode: widget.isMultiSelectMode,
                          isSelected: widget.selectedIds.contains(
                            notification['id'],
                          ),
                          onLongPress: () =>
                              widget.onLongPress(notification['id']),
                          onSelected: () =>
                              widget.onSelected(notification['id']),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isFiltered = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered
                  ? Icons.filter_alt_off_outlined
                  : Icons.notifications_none,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No Matches Found' : 'This Folder is Empty',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered
                  ? 'Try adjusting your filters to see more notifications.'
                  : 'You have no notifications here.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// === CARD ROUTER & CONCRETE CARD IMPLEMENTATIONS
// =======================================================================
class _NotificationCardRouter extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback onLongPress;

  const _NotificationCardRouter({
    required this.notification,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onSelected,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String? ?? '';
    Widget card;
    switch (type) {
      case 'job_application':
        card = _JobApplicationCard(notification: notification);
        break;
      case 'job_posted':
      case 'job_posted_self':
        card = _NewJobPostedCard(notification: notification);
        break;
      case 'job_accepted':
      case 'job_status_update':
      case 'job_completed':
      case 'payment_required':
        card = _JobStatusUpdateCard(notification: notification);
        break;
      default:
        card = _GenericInfoCard(notification: notification);
    }
    return GestureDetector(
      onTap: () {
        if (isMultiSelectMode) {
          onSelected();
        } else {
          // Default tap action: Mark as read and navigate
          final data = notification['data'] as Map<String, dynamic>? ?? {};
          final jobId = data['jobId'];
          FirebaseService().markNotificationAsRead(notification['id']);
          if (jobId != null) {
            FirebaseService().getJobById(jobId).then((job) {
              if (job != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobDetailScreen(job: job),
                  ),
                );
              }
            });
          }
        }
      },
      onLongPress: () => !isMultiSelectMode ? onLongPress() : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(left: isMultiSelectMode ? 40 : 0),
            child: card,
          ),
          if (isMultiSelectMode)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: 40,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =======================================================================
// === JOB APPLICATION CARD
// =======================================================================
class _JobApplicationCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  const _JobApplicationCard({required this.notification});

  @override
  State<_JobApplicationCard> createState() => _JobApplicationCardState();
}

class _JobApplicationCardState extends State<_JobApplicationCard> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isActionLoading = false;

  Future<void> _handleAction(bool accept) async {
    if (!mounted) return;
    setState(() => _isActionLoading = true);
    final data = widget.notification['data'] as Map<String, dynamic>? ?? {};
    final workerId = data['workerId'] as String?;
    final jobId = data['jobId'] as String?;
    final currentUser = _firebaseService.getCurrentUser();
    if (currentUser == null || workerId == null || jobId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Missing required data.")),
        );
      }
      setState(() => _isActionLoading = false);
      return;
    }

    try {
      if (accept) {
        await _firebaseService.acceptJobApplication(
          jobId,
          workerId,
          currentUser.uid,
        );
      } else {
        await _firebaseService.declineJobApplication(
          jobId,
          workerId,
          currentUser.uid,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Action failed: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final isRead = _safeReadBool(notification['isRead']);
    final theme = Theme.of(context);
    final jobId = data['jobId'] as String?;
    final workerId = data['workerId'] as String?;

    if (jobId == null || workerId == null) {
      return _GenericInfoCard(notification: notification);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 5,
      shape: RoundedRectangleBorder(
        side: isRead
            ? BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)
            : BorderSide(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Worker?>(
        future: _firebaseService.getWorkerById(workerId),
        builder: (context, workerSnapshot) {
          if (!workerSnapshot.hasData) {
            return const _ShimmerApplicationCard();
          }
          final worker = workerSnapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: CachedNetworkImageProvider(
                            worker.profileImage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['title'] ?? 'Job Application',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                notification['body'] ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip(
                          context,
                          Icons.star_outline_rounded,
                          "${worker.rating.toStringAsFixed(1)} Rating",
                        ),
                        _buildStatChip(
                          context,
                          Icons.military_tech_outlined,
                          "${worker.experience} Yrs Exp",
                        ),
                        _buildStatChip(
                          context,
                          Icons.work_history_outlined,
                          "${worker.completedJobs} Jobs",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FutureBuilder<Job?>(
                future: _firebaseService.getJobById(jobId),
                builder: (context, jobSnapshot) {
                  if (jobSnapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 52,
                      color: theme.colorScheme.surfaceContainerLow,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final job = jobSnapshot.data;
                  final isJobOpen =
                      job != null &&
                      ['open', 'pending'].contains(job.status.toLowerCase());
                  final isAssignedToThisWorker =
                      job != null && job.workerId == workerId;

                  return Container(
                    color: theme.colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _isActionLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : isJobOpen
                        ? _buildActionButtons()
                        : _buildStatusChip(
                            job?.status ?? 'Unknown',
                            isAssignedToThisWorker,
                          ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => _handleAction(false),
          child: const Text("Decline"),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _handleAction(true),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text("Accept"),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status, bool isAssignedToThisWorker) {
    final theme = Theme.of(context);
    final String text;
    final Color color;

    if (status.toLowerCase() == 'assigned' && isAssignedToThisWorker) {
      text = 'ACCEPTED';
      color = Colors.green.shade700;
    } else if (status.toLowerCase() == 'assigned' && !isAssignedToThisWorker) {
      text = 'FILLED BY ANOTHER';
      color = Colors.grey.shade600;
    } else {
      text = status.toUpperCase();
      color = Colors.blueGrey.shade600;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Chip(
          label: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ],
    );
  }
}

// =======================================================================
// === NEW JOB POSTED CARD
// =======================================================================
class _NewJobPostedCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NewJobPostedCard({required this.notification});

  String _getFallbackImageUrl() {
    final List<String> fallbackImages = [
      'https://images.unsplash.com/photo-1581092921462-2b2241d9a489?w=500',
      'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=500',
      'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=500',
      'https://images.unsplash.com/photo-1552664730-d307ca884978?w=500',
    ];
    return fallbackImages[Random().nextInt(fallbackImages.length)];
  }

  @override
  Widget build(BuildContext context) {
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final isRead = _safeReadBool(notification['isRead']);
    final jobId = data['jobId'] as String?;

    if (jobId == null) {
      return _GenericInfoCard(notification: notification);
    }

    return FutureBuilder<Job?>(
      future: FirebaseService().getJobById(jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerCard(context);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildBasicCard(
            context,
            notification,
            isRead,
            jobDeleted: true,
          );
        }
        final job = snapshot.data!;
        final String effectiveImageUrl =
            (job.attachments.isNotEmpty && job.attachments.first.isNotEmpty)
            ? job.attachments.first
            : data['jobImageUrl'] as String? ?? _getFallbackImageUrl();

        return _buildDetailedCard(
          context,
          notification,
          job,
          isRead,
          effectiveImageUrl,
        );
      },
    );
  }

  Widget _buildDetailedCard(
    BuildContext context,
    Map<String, dynamic> notification,
    Job job,
    bool isRead,
    String jobImageUrl,
  ) {
    final theme = Theme.of(context);
    final type = notification['type'] as String? ?? '';
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final clientImageUrl = data['clientImageUrl'] as String?;
    final clientName = data['clientName'] as String? ?? 'A Client';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 4,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isRead
              ? theme.colorScheme.outlineVariant.withOpacity(0.5)
              : theme.colorScheme.primary,
          width: isRead ? 0.5 : 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  backgroundImage:
                      (clientImageUrl != null && clientImageUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(clientImageUrl)
                      : null,
                  child: (clientImageUrl == null || clientImageUrl.isEmpty)
                      ? Icon(
                          type == 'job_posted_self'
                              ? Icons.person_outline
                              : Icons.work_outline,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type == 'job_posted_self'
                        ? "You posted a new job"
                        : "$clientName posted a new job",
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CachedNetworkImage(
              imageUrl: jobImageUrl,
              fit: BoxFit.cover,
              placeholder: (c, u) =>
                  Container(color: theme.colorScheme.surfaceContainerLow),
              errorWidget: (c, u, e) => Icon(
                Icons.image_not_supported,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip(
                      context,
                      Icons.attach_money,
                      "${job.budget.toStringAsFixed(0)} Birr",
                    ),
                    Flexible(
                      child: _buildStatChip(
                        context,
                        Icons.location_on_outlined,
                        job.location.isEmpty ? 'Not specified' : job.location,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // This onTap is handled by the parent GestureDetector
                      },
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicCard(
    BuildContext context,
    Map<String, dynamic> notification,
    bool isRead, {
    bool jobDeleted = false,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['title'] ?? 'Notification',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notification['body'] ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (jobDeleted) ...[
              const SizedBox(height: 12),
              Text(
                'This job may have been deleted.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 20, backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Container(width: 150, height: 14, color: Colors.white),
                ],
              ),
              const SizedBox(height: 16),
              Container(width: 200, height: 16, color: Colors.white),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 12,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Container(width: 220, height: 12, color: Colors.white),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 80, height: 14, color: Colors.white),
                  Container(width: 100, height: 14, color: Colors.white),
                  Container(width: 70, height: 20, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================================
// === JOB STATUS UPDATE CARD
// =======================================================================
class _JobStatusUpdateCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _JobStatusUpdateCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = notification['data'] as Map<String, dynamic>? ?? {};
    final isRead = _safeReadBool(notification['isRead']);
    final jobImageUrl = data['jobImageUrl'] as String?;
    final status = _getStatusFromType(notification['type'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (jobImageUrl != null && jobImageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: jobImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: theme.colorScheme.surfaceContainer),
                    errorWidget: (c, u, e) => Container(
                      color: theme.colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.work_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Text(
                    data['jobTitle'] ?? 'Job Update',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['title'] ?? 'Update',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification['body'] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _JobProgressTimeline(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusFromType(String type) {
    if (type.contains('accepted')) return 'assigned';
    if (type.contains('completed')) return 'completed';
    if (type.contains('payment')) return 'completed';
    return 'in_progress';
  }
}

// =======================================================================
// === GENERIC INFO CARD
// =======================================================================
class _GenericInfoCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _GenericInfoCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = _safeReadBool(notification['isRead']);
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate();
    final type = notification['type'] as String? ?? '';
    final iconInfo = _getIconForType(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 0.5 : 3,
      shape: RoundedRectangleBorder(
        side: isRead
            ? BorderSide(color: Colors.grey.shade300, width: 0.5)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconInfo.color.withOpacity(0.15),
              child: Icon(iconInfo.icon, color: iconInfo.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'] ?? 'Notification',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (createdAt != null)
                    Text(
                      DateFormat.yMMMd().add_jm().format(createdAt.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================================
// === HELPER WIDGETS & FUNCTIONS
// =======================================================================
Widget _buildStatChip(BuildContext context, IconData icon, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

IconInfo _getIconForType(String type) {
  switch (type) {
    case 'job_request':
      return IconInfo(icon: Icons.work_outline, color: Colors.blue);
    case 'job_application':
      return IconInfo(
        icon: Icons.person_add_alt_1_outlined,
        color: Colors.cyan.shade700,
      );
    case 'job_accepted':
      return IconInfo(
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
      );
    case 'job_rejected':
    case 'application_declined':
      return IconInfo(
        icon: Icons.cancel_outlined,
        color: Colors.redAccent.shade400,
      );
    case 'job_completed':
      return IconInfo(icon: Icons.task_alt, color: Colors.purple.shade400);
    case 'job_status_update':
      return IconInfo(icon: Icons.sync_alt, color: Colors.orange.shade700);
    case 'message':
      return IconInfo(
        icon: Icons.message_outlined,
        color: Colors.teal.shade500,
      );
    case 'payment_required':
      return IconInfo(
        icon: Icons.payment_outlined,
        color: Colors.lightGreen.shade700,
      );
    default:
      return IconInfo(
        icon: Icons.notifications,
        color: Colors.blueGrey.shade500,
      );
  }
}

class _JobProgressTimeline extends StatelessWidget {
  final String status;
  const _JobProgressTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    int currentIndex = 0;
    switch (status.toLowerCase()) {
      case 'assigned':
        currentIndex = 1;
        break;
      case 'in_progress':
        currentIndex = 2;
        break;
      case 'completed':
        currentIndex = 3;
        break;
      default:
        currentIndex = 0;
    }

    return SizedBox(
      height: 60,
      child: CustomPaint(
        painter: _TimelinePainter(
          currentIndex: currentIndex,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          textColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;
  final Color textColor;
  _TimelinePainter({
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..strokeWidth = 2;
    final paintCircle = Paint();
    final labels = ['Pending', 'Assigned', 'In Progress', 'Completed'];

    final double stepWidth = size.width / (labels.length - 1);
    final double y = size.height / 3;

    for (int i = 0; i < labels.length - 1; i++) {
      paintLine.color = i < currentIndex ? activeColor : inactiveColor;
      canvas.drawLine(
        Offset(i * stepWidth, y),
        Offset((i + 1) * stepWidth, y),
        paintLine,
      );
    }

    for (int i = 0; i < labels.length; i++) {
      paintCircle.color = i <= currentIndex ? activeColor : inactiveColor;
      canvas.drawCircle(Offset(i * stepWidth, y), 8, paintCircle);

      if (i <= currentIndex) {
        final icon = Icons.check;
        TextPainter textPainter = TextPainter(
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 12,
            fontFamily: icon.fontFamily,
            color: Colors.white,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            i * stepWidth - textPainter.width / 2,
            y - textPainter.height / 2,
          ),
        );
      }

      TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      labelPainter.layout(minWidth: 0, maxWidth: stepWidth * 1.2);
      labelPainter.paint(
        canvas,
        Offset(i * stepWidth - labelPainter.width / 2, y + 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- SHIMMER PLACEHOLDERS ---
class _ShimmerList extends StatelessWidget {
  const _ShimmerList();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainer,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: 4,
        itemBuilder: (_, __) => const Column(
          children: [
            _ShimmerApplicationCard(),
            SizedBox(height: 12),
            _ShimmerStatusCard(),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ShimmerApplicationCard extends StatelessWidget {
  const _ShimmerApplicationCard();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 28, backgroundColor: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 150, height: 14.0, color: color),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            height: 12.0,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(width: 80, height: 10, color: color),
                    Container(width: 80, height: 10, color: color),
                    Container(width: 80, height: 10, color: color),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 52, color: color),
        ],
      ),
    );
  }
}

class _ShimmerStatusCard extends StatelessWidget {
  const _ShimmerStatusCard();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 120, width: double.infinity, color: color),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 14.0, color: color),
                const SizedBox(height: 6),
                Container(width: double.infinity, height: 12.0, color: color),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 40, color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterBarDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 110.0;

  @override
  double get minExtent => 110.0;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}
