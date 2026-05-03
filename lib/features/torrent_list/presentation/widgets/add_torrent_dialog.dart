import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/clipboard_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom-sheet dialog for adding a torrent via magnet link or .torrent file.
///
/// Pass [initialMagnetUri] to pre-fill the field when opened from a deep link.
class AddTorrentDialog extends StatefulWidget {
  const AddTorrentDialog({
    super.key,
    required this.onMagnetAdded,
    required this.onFileAdded,
    this.initialMagnetUri,
  });

  final void Function(String uri, String? savePath) onMagnetAdded;
  final void Function(String filePath, String? savePath) onFileAdded;

  /// Pre-fill the magnet tab with this URI (from deep link / clipboard).
  final String? initialMagnetUri;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialMagnetUri != null) {
      _magnetController.text = widget.initialMagnetUri!;
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
          color: const Color(0xFF16162A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ────────────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppGradients.primary.createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Add Torrent',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Tab bar ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white38,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          tabs: const [
                            Tab(text: 'Magnet Link'),
                            Tab(text: '.torrent File'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Tab views ────────────────────────────────────────────
                      SizedBox(
                        height: 200,
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
                              onSequentialChanged: (v) =>
                                  setState(() => _sequential = v),
                              onFilePicked: (path) {
                                widget.onFileAdded(path, null);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Action buttons (magnet tab only) ─────────────────────────
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (_, __) {
                    if (_tabController.index != 0) {
                      return SizedBox(height: safePad + 16);
                    }
                    return Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, safePad + 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SecondaryButton(
                              onPressed: _isLoading ? null : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _GradientButton(
                              onPressed: _isLoading ? null : _submitMagnet,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Add Torrent'),
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
    );
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

// ─── Buttons ──────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppGradients.primary,
        color: onPressed == null ? Colors.white10 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed == null ? null : [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        child: child,
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
          TextFormField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: 'magnet:?xt=urn:btih:…',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.link_rounded, color: Colors.white38, size: 20),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, color: Color(0xFF6C63FF), size: 20),
                  onPressed: onPasteFromClipboard,
                ),
              ),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Paste a magnet link';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _SequentialRow(value: sequential, onChanged: onSequentialChanged),
        ],
      ),
    );
  }
}

// ─── File Tab ────────────────────────────────────────────────────────────────

class _FileTab extends StatefulWidget {
  const _FileTab({
    required this.sequential,
    required this.onSequentialChanged,
    required this.onFilePicked,
  });

  final bool sequential;
  final ValueChanged<bool> onSequentialChanged;
  final ValueChanged<String> onFilePicked;

  @override
  State<_FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<_FileTab> {
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _picking ? null : _pickFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _picking ? const Color(0xFF6C63FF) : Colors.white.withValues(alpha: 0.08),
                width: 1.5,
              ),
            ),
            child: _picking
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6C63FF), size: 32),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose .torrent file',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Browse your internal storage',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _SequentialRow(value: widget.sequential, onChanged: widget.onSequentialChanged),
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
        widget.onFilePicked(result!.files.single.path!);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}

class _SequentialRow extends StatelessWidget {
  const _SequentialRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_motion_rounded, size: 20, color: Colors.white38),
          const SizedBox(width: 12),
          const Text('Sequential download', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6C63FF),
            activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
