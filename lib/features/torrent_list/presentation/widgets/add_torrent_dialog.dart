import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/clipboard_service.dart';
import '../../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add Torrent Dialog
// ─────────────────────────────────────────────────────────────────────────────

class AddTorrentDialog extends StatefulWidget {
  const AddTorrentDialog({
    super.key,
    required this.onMagnetAdded,
    required this.onFileAdded,
    this.initialMagnetUri,
    this.initialTorrentFilePath,
  });

  final void Function(String uri, String? savePath) onMagnetAdded;
  final void Function(String filePath, String? savePath) onFileAdded;
  final String? initialMagnetUri;
  final String? initialTorrentFilePath;

  @override
  State<AddTorrentDialog> createState() => _AddTorrentDialogState();
}

class _AddTorrentDialogState extends State<AddTorrentDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _magnetController = TextEditingController();
  final _magnetFormKey = GlobalKey<FormState>();
  bool _sequential = false;
  bool _isLoading = false;
  bool _magnetError = false;
  String? _selectedFilePath;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    if (widget.initialMagnetUri != null) {
      _magnetController.text = widget.initialMagnetUri!;
    } else {
      unawaited(_autoDetectClipboard());
    }

    // Rebuild whenever magnet text changes (clears filled/empty state instantly)
    _magnetController.addListener(() {
      setState(() {
        // Also clear error flag once user has typed something
        if (_magnetError && _magnetController.text.trim().isNotEmpty) {
          _magnetError = false;
        }
      });
    });

    if (widget.initialTorrentFilePath != null) {
      _selectedFilePath = widget.initialTorrentFilePath;
      _tabController.index = 1;
    }
  }

  Future<void> _autoDetectClipboard() async {
    final magnet = await ClipboardService.instance.getMagnetFromClipboard();
    if (magnet != null && mounted) {
      setState(() {
        _magnetController.text = magnet;
        _tabController.index = 0;
        _infoMessage = 'Detected magnet in clipboard';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _infoMessage = null);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  void _submitFile() {
    if (_selectedFilePath == null) return;
    setState(() => _isLoading = true);
    widget.onFileAdded(_selectedFilePath!, null);
    Navigator.pop(context);
  }

  Future<void> _pasteFromClipboard() async {
    // Force paste even if it was the last handled magnet
    final magnet = await ClipboardService.instance.getMagnetFromClipboard(
      force: true,
    );
    if (magnet != null) {
      setState(() {
        _magnetController.text = magnet;
        _infoMessage = 'Pasted from clipboard';
      });
      _magnetFormKey.currentState?.validate();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _infoMessage = null);
      });
    } else {
      // Check if there is ANY text in clipboard to give better feedback
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();

      if (!mounted) return;
      setState(() {
        if (text == null || text.isEmpty) {
          _infoMessage = 'Clipboard is empty';
        } else {
          _infoMessage = 'No valid magnet found in clipboard';
        }
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _infoMessage = null);
      });
    }
  }

  void _submitMagnet() {
    final text = _magnetController.text.trim();
    if (text.isEmpty) {
      setState(() => _magnetError = true);
      return;
    }
    setState(() {
      _isLoading = true;
      _magnetError = false;
    });

    // 🛡️ FIX: Removed Clipboard.setData(const ClipboardData(text: ''))
    // Clearing the system clipboard here was a "destructive" side effect.
    // If the user wanted to re-add the same link or add it to another app,
    // we just deleted their data. We'll let the user manage their clipboard.

    widget.onMagnetAdded(text, null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardPad = mq.viewInsets.bottom;
    final navBarPad = mq.padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardPad),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  navBarPad > 0 ? navBarPad : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Drag handle ──────────────────────────────────────────
                    const _DragHandle(),

                    const SizedBox(height: 12),

                    // ── Header ───────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.downloading.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.downloading,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Add Torrent',
                          style: TextStyle(
                            fontFamily: 'ShipporiMincho',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Segmented tab ─────────────────────────────────────────
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.downloading.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.text(
                          context,
                        ).withValues(alpha: 0.5),
                        labelStyle: const TextStyle(
                          fontFamily: 'ShipporiMincho',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'ShipporiMincho',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: 'Magnet Link'),
                          Tab(text: '.torrent File'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Tab content ───────────────────────────────────────────
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        if (_tabController.index == 0) {
                          return _MagnetTab(
                            formKey: _magnetFormKey,
                            controller: _magnetController,
                            sequential: _sequential,
                            infoMessage: _magnetError
                                ? 'Please paste a magnet link'
                                : _infoMessage,
                            isError: _magnetError,
                            onSequentialChanged: (v) =>
                                setState(() => _sequential = v),
                            onPasteFromClipboard: _pasteFromClipboard,
                          );
                        }
                        return _FileTab(
                          sequential: _sequential,
                          initialFilePath: _selectedFilePath,
                          onSequentialChanged: (v) =>
                              setState(() => _sequential = v),
                          onFilePicked: (path) =>
                              setState(() => _selectedFilePath = path),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Action buttons ────────────────────────────────────────
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (ctx, _) {
                        final isMagnet = _tabController.index == 0;
                        final canSubmit = isMagnet
                            ? true
                            : (_selectedFilePath != null);

                        return Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GradientButton(
                                onPressed: _isLoading
                                    ? null
                                    : (canSubmit
                                          ? (isMagnet
                                                ? _submitMagnet
                                                : _submitFile)
                                          : null),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Add'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Magnet Tab
// ─────────────────────────────────────────────────────────────────────────────

class _MagnetTab extends StatelessWidget {
  const _MagnetTab({
    required this.formKey,
    required this.controller,
    required this.sequential,
    required this.infoMessage,
    required this.isError,
    required this.onSequentialChanged,
    required this.onPasteFromClipboard,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool sequential;
  final String? infoMessage;
  final bool isError;
  final ValueChanged<bool> onSequentialChanged;
  final VoidCallback onPasteFromClipboard;

  String _getDisplayName(String magnet) {
    final uri = Uri.tryParse(magnet);
    if (uri == null) return magnet;
    final name = uri.queryParameters['dn'];
    if (name != null) return name;
    if (magnet.length > 40) return '${magnet.substring(0, 37)}...';
    return magnet;
  }

  String _getHashPreview(String magnet) {
    if (!magnet.contains('xt=urn:btih:')) return 'Invalid magnet format';
    final parts = magnet.split('xt=urn:btih:');
    if (parts.length < 2) return 'Invalid hash';
    final hash = parts[1].split('&').first;
    if (hash.length > 12) {
      return '${hash.substring(0, 6)}…${hash.substring(hash.length - 6)}';
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = controller.text.trim().isNotEmpty;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magnet input
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isError
                    ? Colors.red.shade400
                    : hasContent
                    ? AppColors.downloading
                    : AppColors.border(context),
                width: (isError || hasContent) ? 1.5 : 1,
              ),
            ),
            child: hasContent
                ? InkWell(
                    onTap: () => controller.clear(),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: AppColors.downloading,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getDisplayName(controller.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _getHashPreview(controller.text),
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 10.5,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary(context),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  )
                : TextFormField(
                    controller: controller,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste magnet link here',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(
                          context,
                        ).withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.link_rounded,
                        color: AppColors.textSecondary(context),
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          color: AppColors.downloading,
                          size: 18,
                        ),
                        onPressed: onPasteFromClipboard,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '';
                      return null;
                    },
                  ),
          ),

          // Status message
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: infoMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 13,
                          color: isError
                              ? Colors.red.shade400
                              : AppColors.seeding,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          infoMessage!,
                          style: TextStyle(
                            color: isError
                                ? Colors.red.shade400
                                : AppColors.seeding,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 10),

          // Sequential row
          _SequentialRow(value: sequential, onChanged: onSequentialChanged),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File Tab
// ─────────────────────────────────────────────────────────────────────────────

class _FileTab extends StatefulWidget {
  const _FileTab({
    required this.sequential,
    required this.onSequentialChanged,
    required this.onFilePicked,
    this.initialFilePath,
  });

  final bool sequential;
  final ValueChanged<bool> onSequentialChanged;
  final ValueChanged<String?> onFilePicked;
  final String? initialFilePath;

  @override
  State<_FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<_FileTab> {
  bool _picking = false;
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _selectedPath = widget.initialFilePath;
  }

  @override
  void didUpdateWidget(covariant _FileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilePath != oldWidget.initialFilePath) {
      _selectedPath = widget.initialFilePath;
    }
  }

  String _getFileName(String path) => path.split('/').last;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File picker card
        GestureDetector(
          onTap: _picking ? null : _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.downloading.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _picking
                    ? AppColors.downloading
                    : AppColors.border(context),
                width: 1.5,
              ),
            ),
            child: _picking
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.downloading,
                      strokeWidth: 2,
                    ),
                  )
                : _selectedPath != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.downloading.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.insert_drive_file_rounded,
                            color: AppColors.downloading,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getFileName(_selectedPath!),
                                style: TextStyle(
                                  color: AppColors.text(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Tap to change file',
                                style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary(context),
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() => _selectedPath = null);
                            widget.onFilePicked(null);
                          },
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.downloading.withValues(alpha: 0.5),
                        size: 22,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose .torrent file',
                        style: TextStyle(
                          color: AppColors.text(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Browse internal storage',
                        style: TextStyle(
                          color: AppColors.textSecondary(
                            context,
                          ).withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 10),

        // Sequential row
        _SequentialRow(
          value: widget.sequential,
          onChanged: widget.onSequentialChanged,
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
      );
      if (result?.files.single.path != null) {
        final path = result!.files.single.path!;
        setState(() => _selectedPath = path);
        widget.onFilePicked(path);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sequential Row
// ─────────────────────────────────────────────────────────────────────────────

class _SequentialRow extends StatelessWidget {
  const _SequentialRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_motion_rounded,
            size: 18,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sequential download',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.downloading,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient Button
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppGradients.primary,
        color: onPressed == null ? AppColors.border(context) : null,
        borderRadius: BorderRadius.circular(13),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: AppColors.downloading.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: 'ShipporiMincho',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary Button
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary(context),
          side: BorderSide(color: AppColors.border(context)),
          padding: EdgeInsets.zero,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontFamily: 'ShipporiMincho',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drag Handle
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatefulWidget {
  const _DragHandle();

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    unawaited(_controller.repeat(reverse: true));
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border(
                context,
              ).withValues(alpha: _animation.value),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
