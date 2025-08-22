import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Project Imports ---
import '../../models/job.dart';
import '../../models/worker.dart';
import '../../models/user.dart'; // Needed for AppUser
import '../../services/firebase_service.dart';
import '../../services/app_string.dart'; // For localization
import '../payment/payment_screen.dart';
import '../chat_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  _JobDetailScreenState createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Stream<DocumentSnapshot> _jobStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _firebaseService.getCurrentUser()?.uid;
    _jobStream = FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.job.id)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final appStrings = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _jobStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _JobDetailShimmer(jobTitle: widget.job.title);
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message:
                  appStrings?.jobDetailErrorLoading ??
                  "Error loading job details.",
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _ErrorState(
              message:
                  appStrings?.emptyStateJobs ??
                  "This job is no longer available.",
            );
          }

          final jobData = snapshot.data!.data() as Map<String, dynamic>;
          jobData['id'] = snapshot.data!.id;
          final currentJob = Job.fromJson(jobData);

          return _JobDetailContent(
            job: currentJob,
            firebaseService: _firebaseService,
            currentUserId: _currentUserId,
          );
        },
      ),
    );
  }
}

// --- Main Content Widget ---
class _JobDetailContent extends StatelessWidget {
  final Job job;
  final FirebaseService firebaseService;
  final String? currentUserId;

  const _JobDetailContent({
    required this.job,
    required this.firebaseService,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStrings = AppLocalizations.of(context);

    final isJobOwner = job.seekerId == currentUserId;

    String? headerImageUrl = job.attachments.isNotEmpty
        ? job.attachments.first
        : null;
    const placeholderImageUrl =
        'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1740&q=80';

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(
          headerImageUrl,
          placeholderImageUrl,
          theme,
          isJobOwner,
          context,
          appStrings,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoChips(theme, appStrings),
                const SizedBox(height: 24),
                _buildDetailRows(theme, appStrings),
                const Divider(height: 40, thickness: 0.5),

                // NEW: Client Info Section
                _buildClientInfoSection(theme, appStrings),

                _buildSection(
                  title: appStrings?.jobDetailDescriptionLabel ?? 'Description',
                  content: Text(
                    job.description.isEmpty
                        ? (appStrings?.jobNoDescription ??
                              'No description provided.')
                        : job.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  theme: theme,
                ),
                if (job.attachments.isNotEmpty)
                  _buildSection(
                    title:
                        appStrings?.jobDetailAttachmentsLabel ?? 'Attachments',
                    content: _buildAttachmentsGrid(theme, context, appStrings),
                    theme: theme,
                  ),

                _buildAssignedWorkerSection(theme, appStrings),
                _buildApplicantsSection(theme, isJobOwner, appStrings),

                const SizedBox(height: 32),

                _ActionButtons(
                  job: job,
                  currentUserId: currentUserId,
                  firebaseService: firebaseService,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW WIDGET: Fetches and displays the client's information
  Widget _buildClientInfoSection(ThemeData theme, AppStrings? appStrings) {
    return _buildSection(
      title: appStrings?.jobDetailAboutTheClient ?? 'About the Client',
      content: FutureBuilder<AppUser?>(
        future: firebaseService.getUser(job.seekerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Text(
              appStrings?.profileDataUnavailable ?? 'Client data unavailable.',
            );
          }
          final client = snapshot.data!;
          return _ClientInfoCard(client: client);
        },
      ),
      theme: theme,
    );
  }

  SliverAppBar _buildSliverAppBar(
    String? imageUrl,
    String placeholder,
    ThemeData theme,
    bool isJobOwner,
    BuildContext context,
    AppStrings? appStrings,
  ) {
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surfaceContainer,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 2,
      actions: [
        if (isJobOwner && job.status != 'completed')
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) =>
                _handleMenuSelection(value, context, appStrings),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(
                    Icons.edit_note_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(appStrings?.profileEditButton ?? 'Edit Job'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    appStrings?.jobDetailDeleteConfirmDelete ?? 'Delete Job',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'job_image_${job.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl ?? placeholder,
                fit: BoxFit.cover,
                placeholder: (c, u) =>
                    Container(color: theme.colorScheme.surfaceContainer),
                errorWidget: (c, u, e) =>
                    Image.network(placeholder, fit: BoxFit.cover),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.surface.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.7],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 60, right: 60, bottom: 16),
        centerTitle: true,
        title: Text(
          job.title,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 6),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
      ),
    );
  }

  void _handleMenuSelection(
    String value,
    BuildContext context,
    AppStrings? appStrings,
  ) {
    if (value == 'edit') {
      _showSnackbar(
        context,
        appStrings?.jobDetailFeatureComingSoon ?? 'Edit feature coming soon!',
        isError: false,
      );
    } else if (value == 'delete') {
      _showDeleteConfirmation(context, appStrings);
    }
  }

  void _showDeleteConfirmation(BuildContext context, AppStrings? appStrings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(appStrings?.jobDetailDeleteConfirmTitle ?? 'Delete Job?'),
        content: Text(
          appStrings?.jobDetailDeleteConfirmContent ??
              'This action is permanent and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(appStrings?.generalCancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await firebaseService.deleteJob(job.id);
                if (context.mounted) {
                  _showSnackbar(
                    context,
                    appStrings?.jobDetailSuccessDeleted ??
                        'Job deleted successfully.',
                    isError: false,
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  _showSnackbar(
                    context,
                    appStrings?.jobDetailErrorDeleting ??
                        'Failed to delete job.',
                    isError: true,
                  );
                }
              }
            },
            child: Text(
              appStrings?.jobDetailDeleteConfirmDelete ?? 'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget content,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(delay: const Duration(milliseconds: 200), child: content),
        ],
      ),
    );
  }

  Widget _buildInfoChips(ThemeData theme, AppStrings? appStrings) {
    return FadeInUp(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatusChip(status: job.status),
          _InfoChip(
            icon: Icons.attach_money_rounded,
            text:
                appStrings?.jobBudgetETB(job.budget.toStringAsFixed(0)) ??
                'ETB ${job.budget.toStringAsFixed(0)}',
            color: theme.colorScheme.tertiary,
          ),
          if (job.isUrgent)
            _InfoChip(
              icon: Icons.flash_on_rounded,
              text: appStrings?.createJobUrgentLabel ?? 'Urgent',
              color: Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRows(ThemeData theme, AppStrings? appStrings) {
    return Column(
      children: [
        _DetailRow(
          icon: Icons.category_outlined,
          label: appStrings?.createJobCategoryLabel ?? 'Category',
          value: '${job.category} / ${job.skill}',
          delay: 50,
        ),
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: appStrings?.jobDetailLocationLabel ?? 'Location',
          value: job.location,
          delay: 100,
        ),
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: appStrings?.jobDetailPostedDateLabel ?? 'Posted',
          value: DateFormat.yMMMd().format(job.createdAt),
          delay: 150,
        ),
        if (job.scheduledDate != null)
          _DetailRow(
            icon: Icons.event_available_outlined,
            label: appStrings?.jobDetailScheduledDateLabel ?? 'Scheduled For',
            value: DateFormat.yMMMEd().format(job.scheduledDate!),
            delay: 200,
          ),
      ],
    );
  }

  Widget _buildAttachmentsGrid(
    ThemeData theme,
    BuildContext context,
    AppStrings? appStrings,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: job.attachments.length,
      itemBuilder: (context, index) {
        final url = job.attachments[index];
        bool isImage = [
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
        ].any((ext) => url.toLowerCase().contains(ext));

        return InkWell(
          onTap: () => _launchUrl(url, context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: isImage
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (c, u, e) => Icon(
                        Icons.broken_image_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            appStrings?.viewButton ?? "View File",
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignedWorkerSection(ThemeData theme, AppStrings? appStrings) {
    if (job.workerId == null || job.workerId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Worker?>(
      future: firebaseService.getWorkerById(job.workerId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final worker = snapshot.data!;
        return _buildSection(
          title: appStrings?.jobDetailAssignedWorkerLabel ?? 'Assigned Worker',
          content: _WorkerCard(
            worker: worker,
            action: TextButton(
              onPressed: () {}, // TODO: Implement navigation to worker profile
              child: Text(
                appStrings?.jobDetailViewWorkerProfile ?? 'View Profile',
              ),
            ),
          ),
          theme: theme,
        );
      },
    );
  }

  Widget _buildApplicantsSection(
    ThemeData theme,
    bool isJobOwner,
    AppStrings? appStrings,
  ) {
    if (!isJobOwner || job.status != 'open') return const SizedBox.shrink();
    return FutureBuilder<List<Worker>>(
      key: ValueKey(job.applications.join(',')),
      future: firebaseService
          .getJobApplicants(job.id)
          .then((data) => data.map((d) => Worker.fromJson(d)).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData)
          return Text(
            appStrings?.applicantLoadError ?? 'Could not load applicants.',
          );
        final applicants = snapshot.data!;
        return _buildSection(
          title:
              '${appStrings?.jobDetailApplicantsLabel ?? 'Applicants'} (${applicants.length})',
          content: applicants.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      appStrings?.jobDetailNoApplicantsYet ??
                          'No applications received yet.',
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: applicants.length,
                  itemBuilder: (context, index) => _WorkerCard(
                    worker: applicants[index],
                    action: ElevatedButton(
                      onPressed: () => _assignWorker(
                        context,
                        applicants[index].id,
                        appStrings,
                      ),
                      child: Text(
                        appStrings?.jobDetailApplicantHireButton ?? 'Hire',
                      ),
                    ),
                  ),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                ),
          theme: theme,
        );
      },
    );
  }

  void _showSnackbar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onTertiaryContainer,
          ),
        ),
        backgroundColor: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final appStrings = AppLocalizations.of(context);
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (context.mounted) {
        _showSnackbar(
          context,
          appStrings?.errorCouldNotLaunchUrl ?? 'Could not launch URL',
          isError: true,
        );
      }
    }
  }

  Future<void> _assignWorker(
    BuildContext context,
    String workerId,
    AppStrings? appStrings,
  ) async {
    try {
      await firebaseService.assignJob(job.id, workerId);
      if (context.mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailSuccessWorkerAssigned ??
              'Worker has been assigned!',
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailErrorAssigningWorker ??
              'Failed to assign worker.',
          isError: true,
        );
      }
    }
  }
}

// --- (All other widgets like _ActionButtons, _JobDetailShimmer, etc. go here) ---
// ... (Paste the rest of the widgets from your previous prompt here) ...
class _ActionButtons extends StatefulWidget {
  final Job job;
  final String? currentUserId;
  final FirebaseService firebaseService;

  const _ActionButtons({
    required this.job,
    this.currentUserId,
    required this.firebaseService,
  });

  @override
  __ActionButtonsState createState() => __ActionButtonsState();
}

class __ActionButtonsState extends State<_ActionButtons> {
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_isActionLoading) {
      return const Center(heightFactor: 2, child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final appStrings = AppLocalizations.of(context);

    return FutureBuilder<AppUser?>(
      future: widget.firebaseService.getCurrentUserProfile(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 50);
        }

        final isJobOwner = widget.job.seekerId == widget.currentUserId;
        final isWorkerUser = userSnapshot.data?.role == 'worker';
        final hasApplied = widget.job.applications.contains(
          widget.currentUserId,
        );

        // --- Worker Actions ---
        if (isWorkerUser) {
          if (widget.job.status == 'open' && !hasApplied) {
            return _ActionButton(
              label: appStrings?.jobDetailActionApply ?? 'Apply Now',
              icon: Icons.send_rounded,
              onPressed: _applyForJob,
            );
          }
          if (widget.job.status == 'open' && hasApplied) {
            return _ConfirmationBox(
              text:
                  appStrings?.jobDetailActionApplied ??
                  'You have applied for this job.',
              icon: Icons.check_circle_outline_rounded,
              color: theme.colorScheme.tertiary,
            );
          }
          if (widget.job.workerId == widget.currentUserId &&
              [
                'assigned',
                'in_progress',
                'started working',
              ].contains(widget.job.status.toLowerCase())) {
            return Column(
              children: [
                _ActionButton(
                  label:
                      appStrings?.jobDetailActionContactClient ??
                      'Message Client',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () =>
                      _navigateToChat(context, widget.job.seekerId),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label:
                      appStrings?.jobDetailActionMarkComplete ??
                      'Mark as Completed',
                  icon: Icons.task_alt_rounded,
                  onPressed: _markJobAsCompleted,
                  backgroundColor: Colors.green.shade700,
                ),
              ],
            );
          }
        }
        // --- Job Owner Actions ---
        else if (isJobOwner) {
          if (widget.job.status == 'assigned' && widget.job.workerId != null) {
            return Column(
              children: [
                _ActionButton(
                  label:
                      appStrings?.jobDetailActionMessageWorker ??
                      'Message Worker',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () =>
                      _navigateToChat(context, widget.job.workerId!),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label:
                      appStrings?.jobDetailActionPayNow ?? 'Proceed to Payment',
                  icon: Icons.payment_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentScreen(job: widget.job),
                    ),
                  ),
                ),
              ],
            );
          }
          if (widget.job.status == 'completed') {
            return _ActionButton(
              label: appStrings?.jobDetailActionLeaveReview ?? 'Leave a Review',
              icon: Icons.rate_review_outlined,
              onPressed: () => _showSnackbar(
                context,
                appStrings?.jobDetailFeatureComingSoon ??
                    'Review feature coming soon!',
                isError: false,
              ),
            );
          }
        }
        return const SizedBox.shrink(); // Default
      },
    );
  }

  void _showSnackbar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    if (!context.mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onTertiaryContainer,
          ),
        ),
        backgroundColor: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String otherUserId) {
    if (widget.currentUserId == null) {
      final appStrings = AppLocalizations.of(context);
      _showSnackbar(
        context,
        appStrings?.snackPleaseLogin ?? 'You must be logged in to chat.',
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUserId: widget.currentUserId!,
          otherUserId: otherUserId,
          jobId: widget.job.id,
        ),
      ),
    );
  }

  Future<void> _applyForJob() async {
    if (widget.currentUserId == null) return;
    final appStrings = AppLocalizations.of(context);
    setState(() => _isActionLoading = true);
    try {
      await widget.firebaseService.applyForJob(
        widget.job.id,
        widget.currentUserId!,
      );
      if (mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailSuccessApplied ?? 'Application sent!',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailErrorApplying ?? 'Failed to apply.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _markJobAsCompleted() async {
    final appStrings = AppLocalizations.of(context);
    setState(() => _isActionLoading = true);
    try {
      await widget.firebaseService.updateJobStatus(
        widget.job.id,
        widget.job.workerId,
        widget.job.seekerId,
        'completed',
      );
      if (mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailSuccessMarkedComplete ??
              'Job marked as completed!',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          context,
          appStrings?.jobDetailErrorMarkingComplete ??
              'Could not mark job as complete.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }
}

// --- Reusable, Stylized UI Components ---
class _JobDetailShimmer extends StatelessWidget {
  final String jobTitle;
  const _JobDetailShimmer({required this.jobTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surfaceContainer,
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.white),
              centerTitle: true,
              title: Text(
                jobTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _shimmerBox(120, 36),
                      const SizedBox(width: 12),
                      _shimmerBox(150, 36),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _shimmerBox(double.infinity, 20),
                  const SizedBox(height: 12),
                  _shimmerBox(double.infinity, 20),
                  const Divider(height: 40),
                  _shimmerBox(150, 24),
                  const SizedBox(height: 16),
                  _shimmerBox(double.infinity, 20),
                  const SizedBox(height: 12),
                  _shimmerBox(double.infinity, 20),
                  const SizedBox(height: 12),
                  _shimmerBox(200, 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)?.back ?? 'Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStrings = AppLocalizations.of(context);
    final Color color;
    final String label;

    switch (status.toLowerCase()) {
      case 'open':
        color = theme.colorScheme.primary;
        label = appStrings?.jobStatusOpen ?? 'OPEN';
        break;
      case 'assigned':
        color = Colors.orange.shade700;
        label = appStrings?.jobStatusAssigned ?? 'ASSIGNED';
        break;
      case 'in_progress':
      case 'started working':
        color = Colors.blue.shade700;
        label = appStrings?.jobStatusInProgress ?? 'IN PROGRESS';
        break;
      case 'completed':
        color = Colors.green.shade700;
        label = appStrings?.jobStatusCompleted ?? 'COMPLETED';
        break;
      default:
        color = Colors.grey.shade600;
        label = (appStrings?.getStatusName(status) ?? status).toUpperCase();
    }
    return Chip(
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      side: BorderSide.none,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.white70),
      label: Text(text),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide.none,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int delay;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
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

class _WorkerCard extends StatelessWidget {
  final Worker worker;
  final Widget action;
  const _WorkerCard({required this.worker, required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStrings = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.secondaryContainer,
            backgroundImage: worker.profileImage.isNotEmpty
                ? CachedNetworkImageProvider(worker.profileImage)
                : null,
            child: worker.profileImage.isEmpty
                ? Icon(
                    Icons.person,
                    size: 30,
                    color: theme.colorScheme.onSecondaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  worker.profession,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${worker.rating.toStringAsFixed(1)} (${appStrings?.jobsCount(worker.completedJobs) ?? '${worker.completedJobs} jobs'})',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontSize: 16),
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _ConfirmationBox({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// In lib/screens/jobs/job_detail_screen.dart

// NEW WIDGET - CORRECTED
class _ClientInfoCard extends StatelessWidget {
  final AppUser client;

  const _ClientInfoCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStrings = AppLocalizations.of(context);

    // Safely check if the profile image exists and is not empty
    final bool hasImage =
        client.profileImage != null && client.profileImage!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.secondaryContainer,
            backgroundImage: hasImage
                ? CachedNetworkImageProvider(client.profileImage!)
                : null,
            child: !hasImage
                ? Icon(
                    Icons.person,
                    size: 30,
                    color: theme.colorScheme.onSecondaryContainer,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // FIX: This row now shows the number of jobs posted
         
              ],
            ),
          ),
        ],
      ),
    );
  }
}
