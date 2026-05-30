import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/size_formatter.dart';
import '../../../../core/services/torrent_engine_service.dart';
import '../../../../core/native/models.dart' as lt;
import '../../../../domain/entities/torrent_status.dart';
import '../controllers/torrent_notifier.dart';

class TorrentDetailBottomSheet extends ConsumerStatefulWidget {
  const TorrentDetailBottomSheet({super.key, required this.torrentId});
  final String torrentId;

  @override
  ConsumerState<TorrentDetailBottomSheet> createState() => _TorrentDetailBottomSheetState();
}

class _TorrentDetailBottomSheetState extends ConsumerState<TorrentDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isTitleExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch specific torrent details utilizing Riverpod select.
    // Rebuilds only when the states or speeds change, isolating rebuild storms.
    final torrent = ref.watch(torrentProvider.select(
      (s) => s.value?.firstWhere((t) => t.id == widget.torrentId, orElse: () => _placeholder(widget.torrentId)),
    ));

    if (torrent == null || torrent.state == TorrentState.unknown) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeBg = isDark ? const Color(0xFF161719) : const Color(0xFFFAF6EE);
    final themeSurface = isDark ? const Color(0xFF1E2023) : const Color(0xFFFFFDF9);
    final themeOutline = isDark ? const Color(0xFF2C2D33) : const Color(0xFFE5DDD0);
    final primaryColor = isDark ? const Color(0xFFE53935) : const Color(0xFFC82127);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: themeOutline, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Drag Handle ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: themeOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header Information ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
                          borderRadius: BorderRadius.circular(4),
                          child: Text(
                            torrent.name,
                            style: const TextStyle(
                              fontFamily: 'ShipporiMincho',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: _isTitleExpanded ? null : 2,
                            overflow: _isTitleExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          torrent.state.displayName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // ── Tab Bar Navigation (Segmented M3 Styling - Flat Washi Layout) ────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: themeSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: themeOutline, width: 1.2),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? const Color(0xFFA39F97) : const Color(0xFF5C5850),
                labelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
                tabs: const [
                  Tab(text: 'INFO'),
                  Tab(text: 'FILES'),
                  Tab(text: 'TRACKERS'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Scrollable Tab Contents (Preserves Scroll States via PageStorageKey) ─
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InfoTab(
                    key: const PageStorageKey('detail_info_tab'),
                    torrent: torrent,
                  ),
                  _FilesTab(
                    key: const PageStorageKey('detail_files_tab'),
                    torrentId: torrent.id,
                    savePath: torrent.savePath,
                    torrentName: torrent.name,
                    isTorrentFinished: torrent.progress >= 1.0,
                  ),
                  _TrackersTab(
                    key: const PageStorageKey('detail_trackers_tab'),
                    magnetUri: torrent.magnetUri,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TorrentStatus _placeholder(String id) => TorrentStatus(
    id: id,
    name: '…',
    progress: 0,
    downloadSpeed: 0,
    uploadSpeed: 0,
    peers: 0,
    seeds: 0,
    state: TorrentState.unknown,
    totalSize: 0,
    downloadedBytes: 0,
    uploadedBytes: 0,
    savePath: '',
    addedAt: DateTime.now(),
    lastActivityAt: DateTime.now(),
    ratio: 0,
  );
}
// ─── INFO TAB ────────────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  const _InfoTab({super.key, required this.torrent});
  final TorrentStatus torrent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final labelStyle = TextStyle(
      fontFamily: 'Outfit',
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: isDark ? const Color(0xFFA39F97) : const Color(0xFF5C5850),
    );
    final valueStyle = TextStyle(
      fontFamily: 'Outfit',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFFECE9E2) : const Color(0xFF1C1C1C),
    );

    return RepaintBoundary(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _buildInfoRow('TORRENT NAME', torrent.name, labelStyle, valueStyle, isDark),
          _buildInfoRow('TOTAL SIZE', SizeFormatter.format(torrent.totalSize), labelStyle, valueStyle, isDark),
          _buildInfoRow('DOWNLOADED', SizeFormatter.format(torrent.downloadedBytes), labelStyle, valueStyle, isDark),
          _buildInfoRow('UPLOADED', SizeFormatter.format(torrent.uploadedBytes), labelStyle, valueStyle, isDark),
          _buildInfoRow('SHARE RATIO', torrent.ratio.toStringAsFixed(2), labelStyle, valueStyle, isDark),
          _buildInfoRow('HASH KEY', torrent.id.toUpperCase(), labelStyle, valueStyle, isDark),
          _buildInfoRow('CREATION DATE', torrent.addedAt.toLocal().toString().split('.').first, labelStyle, valueStyle, isDark),
          _buildInfoRow('STATE', torrent.state.displayName, labelStyle, valueStyle, isDark),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    TextStyle lStyle,
    TextStyle vStyle,
    bool isDark, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final rowContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: lStyle),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: vStyle,
                softWrap: true,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E2023) : const Color(0xFFF5EDE0),
            width: 1,
          ),
        ),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: rowContent,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: rowContent,
            ),
    );
  }
}

// ─── FILES TAB ───────────────────────────────────────────────────────────────

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({
    super.key,
    required this.torrentId,
    required this.savePath,
    required this.torrentName,
    required this.isTorrentFinished,
  });
  final String torrentId;
  final String savePath;
  final String torrentName;
  final bool isTorrentFinished;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> with AutomaticKeepAliveClientMixin {
  List<lt.FileInfo> _files = [];
  bool _loading = true;
  final Set<int> _selectedIndices = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFiles());
  }

  bool _doesFileExist(lt.FileInfo file) {
    if (file.path.isNotEmpty) {
      final fAbs = File(file.path);
      if (fAbs.isAbsolute && fAbs.existsSync()) return true;
      final fRel = File('${widget.savePath}/${file.path}');
      if (fRel.existsSync()) return true;
    }
    final fName = File('${widget.savePath}/${file.name}');
    return fName.existsSync();
  }

  /// Load files from the libtorrent engine.
  /// For finished torrents, falls back to scanning the savePath/torrentName directory on
  /// disk if the engine returns an empty list (handle may be unloaded).
  Future<void> _loadFiles() async {
    final intId = int.tryParse(widget.torrentId);
    if (intId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // ── Attempt 1: engine FFI call ──────────────────────────────────────────
    List<lt.FileInfo> fileList = [];
    try {
      fileList = TorrentEngineService.instance.getFiles(intId);
    } catch (_) {}

    // ── Attempt 2: retry after 600ms (metadata may still be loading) ────────
    if (fileList.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        fileList = TorrentEngineService.instance.getFiles(intId);
      } catch (_) {}
    }

    // ── Attempt 3: disk-scan fallback for finished torrents ──────────────────
    // When a finished torrent's engine handle is unloaded, getFiles() returns []
    // We can reconstruct the file list by walking savePath/torrentName on disk.
    if (fileList.isEmpty && widget.savePath.isNotEmpty) {
      try {
        final subDir = Directory('${widget.savePath}/${widget.torrentName}');
        if (subDir.existsSync()) {
          final entities = subDir.listSync(recursive: true)
            .whereType<File>()
            .toList();
          fileList = entities.asMap().entries.map((entry) {
            final file = entry.value;
            final relativeName = file.path
                .replaceFirst('${widget.savePath}/', '');
            return lt.FileInfo(
              index: entry.key,
              name: relativeName,
              path: file.path,
              size: file.lengthSync(),
              isStreamable: false,
            );
          }).toList();
        } else {
          final file = File('${widget.savePath}/${widget.torrentName}');
          if (file.existsSync()) {
            fileList = [
              lt.FileInfo(
                index: 0,
                name: widget.torrentName,
                path: file.path,
                size: file.lengthSync(),
                isStreamable: false,
              ),
            ];
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _files = fileList;
        _selectedIndices.clear();
        _loading = false;
      });
    }
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for (final f in _files) {
        _selectedIndices.add(f.index);
      }
    });
  }

  void _selectNone() {
    setState(() => _selectedIndices.clear());
  }

  void _toggleFileSelection(int index, bool selected) {
    setState(() {
      if (selected) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
    });
  }

  /// Physically deletes the selected files from disk and sets priority in engine to 0.
  Future<void> _deleteSelectedFiles(BuildContext context) async {
    final selected = _files
        .where((f) => _selectedIndices.contains(f.index))
        .toList();
    if (selected.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFFE53935) : const Color(0xFFC82127);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2023) : const Color(0xFFFFFDF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF2C2D33) : const Color(0xFFE5DDD0),
            width: 1.2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Delete Files',
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Permanently delete ${selected.length} selected '
          'file${selected.length == 1 ? '' : 's'} from storage?\n\nThe torrent will remain in the client.',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            height: 1.5,
            color: isDark ? const Color(0xFFECE9E2) : const Color(0xFF1C1C1C),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFA39F97) : const Color(0xFF5C5850),
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int deleted = 0;

    // Build list of all file priorities to send to the engine FFI
    // Files that are being deleted should have priority 0.
    final intId = int.tryParse(widget.torrentId);
    if (intId != null) {
      try {
        final priorities = List<int>.generate(
          _files.length,
          (i) => _selectedIndices.contains(i) ? 0 : 1,
        );
        await ref
            .read(torrentProvider.notifier)
            .setFilePriorities(widget.torrentId, priorities);
      } catch (_) {}
    }

    for (final file in selected) {
      try {
        final filePath = file.path.isNotEmpty && File(file.path).existsSync()
            ? file.path
            : '${widget.savePath}/${file.name}';
        final f = File(filePath);
        if (f.existsSync()) {
          await f.delete();
          deleted++;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    // Remove deleted entries from our local list
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      final deletedIndices = selected.map((f) => f.index).toSet();
      _files = _files.where((f) => !deletedIndices.contains(f.index)).toList();
      _selectedIndices.clear();
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$deleted file${deleted == 1 ? '' : 's'} deleted from disk',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? const Color(0xFFE53935) : const Color(0xFFC82127);

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: isDark ? const Color(0xFF3A3B42) : const Color(0xFFCCC5B8),
            ),
            const SizedBox(height: 12),
            Text(
              'No files found',
              style: TextStyle(
                fontFamily: 'ShipporiMincho',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFA39F97) : const Color(0xFF5C5850),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Metadata may still be loading,\nor files were removed from disk.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: isDark ? const Color(0xFF6B6862) : const Color(0xFF9E9588),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                unawaited(_loadFiles());
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Retry',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final hasSelected = _selectedIndices.isNotEmpty;

    return RepaintBoundary(
      child: Column(
        children: [
          // ── Toolbar ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                // Delete selected files button
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: hasSelected
                      ? TextButton.icon(
                          icon: Icon(
                            Icons.delete_sweep_rounded,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFCF6679)
                                : const Color(0xFFB00020),
                          ),
                          label: Text(
                            'DELETE SELECTED',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFCF6679)
                                  : const Color(0xFFB00020),
                            ),
                          ),
                          onPressed: () => _deleteSelectedFiles(context),
                        )
                      : const SizedBox.shrink(),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(
                    Icons.select_all_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  label: Text(
                    'ALL',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFECE9E2)
                          : const Color(0xFF1C1C1C),
                    ),
                  ),
                  onPressed: _selectAll,
                ),
                TextButton.icon(
                  icon: Icon(
                    Icons.deselect_rounded,
                    size: 16,
                    color: isDark
                        ? const Color(0xFFA39F97)
                        : const Color(0xFF5C5850),
                  ),
                  label: Text(
                    'NONE',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFA39F97)
                          : const Color(0xFF5C5850),
                    ),
                  ),
                  onPressed: _selectNone,
                ),
              ],
            ),
          ),
          // ── File list ──────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                final isSelected = _selectedIndices.contains(file.index);
                final exists = _doesFileExist(file);

                final Color bgColor;
                final Color borderColor;

                if (isSelected) {
                  bgColor = isDark
                      ? const Color(0xFF2D1F21) // Subtle dark red
                      : const Color(0xFFFFF2F2); // Subtle light red
                  borderColor = isDark
                      ? const Color(0xFFE53935).withValues(alpha: 0.5)
                      : const Color(0xFFC82127).withValues(alpha: 0.3);
                } else if (!exists) {
                  bgColor = isDark
                      ? const Color(0xFF141517) // Darker/faded surface
                      : const Color(0xFFF2EAE0); // Lighter faded surface
                  borderColor = isDark
                      ? const Color(0xFF25262B)
                      : const Color(0xFFE5DDD0).withValues(alpha: 0.6);
                } else {
                  bgColor = isDark
                      ? const Color(0xFF1E2023) // Standard surface
                      : const Color(0xFFFFFDF9); // Standard parchment
                  borderColor = isDark
                      ? const Color(0xFF2C2D33)
                      : const Color(0xFFE5DDD0);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                  child: CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: primaryColor,
                    value: isSelected,
                    onChanged: (val) =>
                        _toggleFileSelection(file.index, val ?? false),
                    title: Text(
                      file.name,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: exists
                            ? (isDark
                                ? const Color(0xFFECE9E2)
                                : const Color(0xFF1C1C1C))
                            : (isDark
                                ? const Color(0xFF6B6862)
                                : const Color(0xFF9E9588)),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          SizeFormatter.format(file.size),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFA39F97)
                                : const Color(0xFF5C5850),
                          ),
                        ),
                        if (!exists)
                          Text(
                            'EXCLUDED',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFCF6679)
                                  : const Color(0xFFB00020),
                            ),
                          )
                        else if (widget.isTorrentFinished || exists)
                          Text(
                            '✓ COMPLETE',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF387F50)
                                  : const Color(0xFF275E3B),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TRACKERS TAB ────────────────────────────────────────────────────────────

class _TrackersTab extends StatelessWidget {
  const _TrackersTab({super.key, required this.magnetUri});
  final String? magnetUri;

  List<String> _extractTrackers(String? uri) {
    if (uri == null || uri.isEmpty) return [];
    try {
      final parsed = Uri.tryParse(uri);
      if (parsed == null) return [];
      final trackers = parsed.queryParametersAll['tr'] ?? [];
      return trackers.map((t) => Uri.decodeComponent(t)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackers = _extractTrackers(magnetUri);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clear disclaimer labeling it strictly as Basic Extracted Information
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2023) : const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2D33) : const Color(0xFFFFD591),
                width: 1,
              ),
            ),
            child: Text(
              'BASIC TRACKER INFORMATION\nNote: Live tracker health and real-time announce statuses are not currently exposed by the native libtorrent wrapper. The addresses below represent the static trackers extracted from the magnet URI.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFDDA531) : const Color(0xFFC48E19),
                height: 1.45,
              ),
            ),
          ),

          Expanded(
            child: trackers.isEmpty
                ? const Center(
                    child: Text(
                      'No tracker announcements found in magnet link.',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: trackers.length,
                    itemBuilder: (context, index) {
                      final url = trackers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2023) : const Color(0xFFFFFDF9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2D33) : const Color(0xFFE5DDD0),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              url,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

