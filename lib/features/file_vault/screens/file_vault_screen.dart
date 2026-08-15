import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/file_vault_bloc.dart';
import '../models/vault_file_entry.dart';

/// Root screen — creates its own scoped [FileVaultBloc].
class FileVaultScreen extends StatelessWidget {
  const FileVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FileVaultBloc()..add(FileVaultLoad()),
      child: const _FileVaultView(),
    );
  }
}

class _FileVaultView extends StatelessWidget {
  const _FileVaultView();

  Future<void> _pickAndImport(BuildContext context) async {
    final file = await FilePicker.pickFile();
    if (file == null || file.path == null) return;
    if (!context.mounted) return;
    context.read<FileVaultBloc>().add(
          FileVaultImport(filePath: file.path!, fileName: file.name));
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Delete File?',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Permanently delete "$name" from the vault?',
              style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppTheme.danger))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileVaultBloc, FileVaultState>(
      listener: (context, state) {
        if (state is FileVaultLoaded) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: AppTheme.danger));
          } else if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppTheme.safe));
          }
        }
        if (state is FileVaultError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.danger));
        }
      },
      builder: (context, state) {
        final bool isLoading = state is FileVaultLoading ||
            (state is FileVaultLoaded && state.operationInProgress);
        final List<VaultFileEntry> files =
            state is FileVaultLoaded ? state.files : [];

        return Scaffold(
          appBar: AppBar(
            title: const Text('File Vault'),
            backgroundColor: AppTheme.background,
            actions: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                ),
            ],
          ),
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: ResponsiveCenter(
              maxWidth: 1000,
              child: Column(
                children: [
                  // ── Header card ──────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF4A148C)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.white, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AES-256-GCM Encrypted Vault',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text(
                                '${files.length} file${files.length != 1 ? 's' : ''} stored securely',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              isLoading ? null : () => _pickAndImport(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4A148C),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Import',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                  // ── File list ────────────────────────────────────────────
                  Expanded(
                    child: state is FileVaultLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary))
                        : files.isEmpty
                            ? _buildEmpty(context, isLoading)
                            : _buildFileList(context, files, isLoading),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool isLoading) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 64,
                color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('Your vault is empty',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Import any file to encrypt it',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () => _pickAndImport(context),
              icon: const Icon(Icons.add),
              label: const Text('Import File'),
            ),
          ],
        ),
      );

  Widget _buildFileList(
      BuildContext context, List<VaultFileEntry> files, bool isLoading) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: files.length,
      itemBuilder: (_, i) {
        final vf = files[i];
        return _VaultFileCard(
          entry: vf,
          isLoading: isLoading,
          onRestore: () =>
              context.read<FileVaultBloc>().add(FileVaultRestore(vf)),
          onExport: () =>
              context.read<FileVaultBloc>().add(FileVaultDecrypt(vf)),
          onDelete: () async {
            final confirmed = await _confirmDelete(context, vf.name);
            if (confirmed == true && context.mounted) {
              context.read<FileVaultBloc>().add(FileVaultDelete(vf));
            }
          },
        );
      },
    );
  }
}

// ─── File card widget ─────────────────────────────────────────────────────────
class _VaultFileCard extends StatelessWidget {
  final VaultFileEntry entry;
  final bool isLoading;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _VaultFileCard({
    required this.entry,
    required this.isLoading,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Icons.video_file_outlined;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audio_file_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon(entry.originalExtension),
                color: const Color(0xFF9C27B0), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${_formatSize(entry.sizeBytes)}  •  ${DateFormat('MMM d, yyyy').format(entry.encryptedAt)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          // Decrypt & Restore button
          IconButton(
            icon: const Icon(Icons.lock_open_rounded,
                color: AppTheme.safe, size: 20),
            tooltip: 'Decrypt & Restore',
            onPressed: isLoading ? null : onRestore,
          ),
          PopupMenuButton<String>(
            color: AppTheme.surface,
            icon: const Icon(Icons.more_vert,
                color: AppTheme.textSecondary, size: 20),
            enabled: !isLoading,
            onSelected: (v) {
              if (v == 'restore') onRestore();
              if (v == 'export') onExport();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'restore',
                child: Row(children: [
                  Icon(Icons.lock_open_rounded, size: 18, color: AppTheme.safe),
                  SizedBox(width: 8),
                  Text('Decrypt & Restore', style: TextStyle(color: AppTheme.safe)),
                ]),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.share_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Decrypt & Share'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.danger),
                  SizedBox(width: 8),
                  Text('Delete from Vault',
                      style: TextStyle(color: AppTheme.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
