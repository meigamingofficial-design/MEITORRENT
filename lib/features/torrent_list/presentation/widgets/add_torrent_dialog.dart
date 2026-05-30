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

  String? _clipboardMagnet;
  bool _showClipboardBanner = false;

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
        _clipboardMagnet = magnet;
        _showClipboardBanner = true;
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
        _showClipboardBanner = false;
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

                    if (_showClipboardBanner && _clipboardMagnet != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.downloading.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.downloading.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: AppColors.downloading,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Magnet link detected in clipboard',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _clipboardMagnet!.length > 35
                                        ? '${_clipboardMagnet!.substring(0, 32)}...'
                                        : _clipboardMagnet!,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 10,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  _magnetController.text = _clipboardMagnet!;
                                  _showClipboardBanner = false;
                                  _tabController.index = 0;
                                });
                              },
                              child: const Text(
                                'Paste',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.downloading,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _showClipboardBanner = false;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

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

class _GradientButton extends StatefulWidget {
  const _GradientButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => unawaited(_ctrl.forward()) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              unawaited(_ctrl.reverse());
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => unawaited(_ctrl.reverse()),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: widget.onPressed == null ? null : AppGradients.primary,
            color: widget.onPressed == null ? AppColors.border(context) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.downloading.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: null, // handled by GestureDetector
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
              padding: EdgeInsets.zero,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: 'ShipporiMincho',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary Button
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => unawaited(_ctrl.forward()) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              unawaited(_ctrl.reverse());
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => unawaited(_ctrl.reverse()),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: null, // handled by GestureDetector
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary(context),
              disabledForegroundColor: AppColors.textSecondary(context),
              side: BorderSide(color: AppColors.border(context)),
              padding: EdgeInsets.zero,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: 'ShipporiMincho',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            child: widget.child,
          ),
        ),
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
