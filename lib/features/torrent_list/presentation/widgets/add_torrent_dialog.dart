import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/clipboard_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom-sheet dialog for adding a torrent via magnet link or .torrent file.
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
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialMagnetUri != null) {
      _magnetController.text = widget.initialMagnetUri!;
    }
    if (widget.initialTorrentFilePath != null) {
      _selectedFilePath = widget.initialTorrentFilePath;
      _tabController.index = 1; // Open .torrent file tab directly!
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safePad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ────────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ──────────────────────────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.downloading
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: AppColors.downloading, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Add Torrent',
                              style: GoogleFonts.shipporiMincho(
                                color: AppColors.text(context),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ── Tab bar ────────────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.downloading
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor:
                                AppColors.textSecondary(context),
                            labelStyle: GoogleFonts.shipporiMincho(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                            unselectedLabelStyle: GoogleFonts.shipporiMincho(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Magnet Link'),
                              Tab(text: '.torrent File'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Tab views ──────────────────────────────────────────
                        SizedBox(
                          height: 210,
                          child: TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _MagnetTab(
                                formKey: _magnetFormKey,
                                controller: _magnetController,
                                sequential: _sequential,
                                onSequentialChanged: (v) =>
                                    setState(() => _sequential = v),
                                onPasteFromClipboard: _pasteFromClipboard,
                              ),
                              _FileTab(
                                sequential: _sequential,
                                initialFilePath: _selectedFilePath,
                                onSequentialChanged: (v) =>
                                    setState(() => _sequential = v),
                                onFilePicked: (path) {
                                  setState(() => _selectedFilePath = path);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Action buttons ─────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) {
                      final isMagnet = _tabController.index == 0;
                      final canSubmit =
                          isMagnet ? true : (_selectedFilePath != null);

                      return Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, safePad + 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
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
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Add'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitFile() {
    if (_selectedFilePath == null) return;
    setState(() => _isLoading = true);
    widget.onFileAdded(_selectedFilePath!, null);
    Navigator.pop(context);
  }

  Future<void> _pasteFromClipboard() async {
    final magnet = await ClipboardService.instance.getMagnetFromClipboard();
    if (magnet != null) {
      _magnetController.text = magnet;
      _magnetFormKey.currentState?.validate();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid magnet link in clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _submitMagnet() {
    if (_magnetFormKey.currentState?.validate() != true) return;
    setState(() => _isLoading = true);
    widget.onMagnetAdded(_magnetController.text.trim(), null);
    Navigator.pop(context);
  }
}

// ─── Gradient Button ──────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppGradients.primary,
        color: onPressed == null ? AppColors.border(context) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: AppColors.downloading.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.shipporiMincho(
              fontWeight: FontWeight.w700, fontSize: 14),
        ),
        child: child,
      ),
    );
  }
}

// ─── Secondary Button ─────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary(context),
          side: BorderSide(color: AppColors.border(context)),
          padding: EdgeInsets.zero,
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.shipporiMincho(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        child: child,
      ),
    );
  }
}

// ─── Magnet Tab ───────────────────────────────────────────────────────────────

class _MagnetTab extends StatelessWidget {
  const _MagnetTab({
    required this.formKey,
    required this.controller,
    required this.sequential,
    required this.onSequentialChanged,
    required this.onPasteFromClipboard,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool sequential;
  final ValueChanged<bool> onSequentialChanged;
  final VoidCallback onPasteFromClipboard;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: TextFormField(
              controller: controller,
              maxLines: null,
              minLines: null,
              expands: true,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                  color: AppColors.text(context), fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Paste magnet link here',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary(context)
                        .withValues(alpha: 0.5)),
                prefixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_rounded,
                        color: AppColors.textSecondary(context), size: 20)
                  ],
                ),
                suffixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.content_paste_rounded,
                            color: AppColors.downloading, size: 20),
                        onPressed: onPasteFromClipboard,
                      ),
                    ),
                  ],
                ),
                filled: true,
                fillColor: AppColors.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                      color: AppColors.downloading, width: 1.5),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Paste a magnet link';
                return null;
              },
            ),
          ),
          const SizedBox(height: 16),
          _SequentialRow(value: sequential, onChanged: onSequentialChanged),
        ],
      ),
    );
  }
}

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

  String _getFileName(String path) {
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _picking ? null : _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.downloading.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.downloading
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.insert_drive_file_rounded,
                                color: AppColors.downloading,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getFileName(_selectedPath!),
                                    style: TextStyle(
                                      color: AppColors.text(context),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pre-loaded torrent file',
                                    style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.downloading),
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
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.downloading.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.downloading,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose .torrent file',
                            style: TextStyle(
                              color: AppColors.text(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Browse your internal storage',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 12),
        _SequentialRow(
            value: widget.sequential, onChanged: widget.onSequentialChanged),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
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

// ─── Sequential Row ───────────────────────────────────────────────────────────

class _SequentialRow extends StatelessWidget {
  const _SequentialRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.border(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_motion_rounded,
              size: 20, color: AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sequential download',
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
