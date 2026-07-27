import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/cybe_widgets.dart';

class FileVaultScreen extends StatefulWidget {
  const FileVaultScreen({super.key});
  @override
  State<FileVaultScreen> createState() => _FileVaultScreenState();
}

class _FileVaultScreenState extends State<FileVaultScreen> {
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  List<_VaultFile> _files = [];
  bool _loading = false;
  String? _vaultDir;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _vaultDir = '${appDir.path}/cybe_vault';
    await Directory(_vaultDir!).create(recursive: true);
    _loadFiles();
  }

  Future<Uint8List> _getVaultKey() async {
    final keyStr = await _storage.read(key: AppConstants.vaultKeyKey);
    if (keyStr == null) throw Exception('Vault key not found');
    return Uint8List.fromList(base64.decode(keyStr));
  }

  void _loadFiles() {
    if (_vaultDir == null) return;
    final dir = Directory(_vaultDir!);
    setState(() {
      _files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.cybe'))
          .map((f) {
            final name = f.uri.pathSegments.last.replaceAll('.cybe', '');
            return _VaultFile(name: name, path: f.path, size: f.lengthSync(), modified: f.lastModifiedSync());
          })
          .toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
    });
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _loading = true);
    try {
      final key = await _getVaultKey();
      final plainBytes = await File(file.path!).readAsBytes();
      final encrypted = CryptoUtils.encryptBytes(plainBytes, key);
      final safeName = file.name.replaceAll(RegExp(r'[^\w\-.]'), '_');
      final outPath = '$_vaultDir/$safeName.cybe';
      await File(outPath).writeAsBytes(encrypted);
      _loadFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${file.name} encrypted and stored'), backgroundColor: AppTheme.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encryption failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _decryptAndShare(_VaultFile vf) async {
    setState(() => _loading = true);
    try {
      final key = await _getVaultKey();
      final encBytes = await File(vf.path).readAsBytes();
      final decBytes = CryptoUtils.decryptBytes(encBytes, key);
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/${vf.name}';
      await File(outPath).writeAsBytes(decBytes);
      await Share.shareXFiles([XFile(outPath)], text: 'Decrypted file from Cybe Vault');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decryption failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteFile(_VaultFile vf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete File?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Permanently delete "${vf.name}" from the vault?',
          style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirmed == true) {
      await File(vf.path).delete();
      _loadFiles();
    }
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image_outlined;
      case 'mp4': case 'mov': case 'avi': return Icons.video_file_outlined;
      case 'mp3': case 'wav': return Icons.audio_file_outlined;
      case 'doc': case 'docx': return Icons.description_outlined;
      case 'xls': case 'xlsx': return Icons.table_chart_outlined;
      case 'zip': case 'rar': return Icons.folder_zip_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Vault'),
        backgroundColor: AppTheme.background,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: Column(
            children: [
            // Header card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF4A148C)]),
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
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${_files.length} file${_files.length != 1 ? 's' : ''} stored securely',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _importFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4A148C),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Import', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
            // File list
            Expanded(
              child: _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          const Text('Your vault is empty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Import any file to encrypt it', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _importFile,
                            icon: const Icon(Icons.add),
                            label: const Text('Import File'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _files.length,
                      itemBuilder: (_, i) {
                        final vf = _files[i];
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
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9C27B0).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_fileIcon(vf.name), color: const Color(0xFF9C27B0), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(vf.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatSize(vf.size)}  •  ${DateFormat('MMM d, yyyy').format(vf.modified)}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.safe.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text('AES-256', style: TextStyle(color: AppTheme.safe, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                color: AppTheme.surface,
                                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                                onSelected: (v) {
                                  if (v == 'export') _decryptAndShare(vf);
                                  if (v == 'delete') _deleteFile(vf);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.share_outlined, size: 18), SizedBox(width: 8), Text('Decrypt & Share')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.danger))])),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _VaultFile {
  final String name, path;
  final int size;
  final DateTime modified;
  const _VaultFile({required this.name, required this.path, required this.size, required this.modified});
}
