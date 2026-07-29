import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../services/backup_service.dart';

class BackupDialogs {
  static void showExportDialog(BuildContext context) {
    final pwCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_outlined, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Export Encrypted Vault', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter master password to encrypt your `.cybe` backup file.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Master Password', hintText: 'Enter password...'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (pwCtrl.text.isEmpty) return;
                      setDialogState(() => loading = true);
                      try {
                        final path = await BackupService.exportBackup(pwCtrl.text);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        await Share.shareXFiles([XFile(path)], text: 'Cybe Vault Encrypted Backup (.cybe)');
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger));
                        }
                      }
                    },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background)) : const Text('Export Backup'),
            ),
          ],
        ),
      ),
    );
  }

  static void showImportDialog(BuildContext context) {
    final pwCtrl = TextEditingController();
    String? selectedPath;
    bool loading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_download_outlined, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Restore Encrypted Vault', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(type: FileType.any);
                  if (res != null && res.files.single.path != null) {
                    setDialogState(() => selectedPath = res.files.single.path);
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: Text(selectedPath == null ? 'Select .cybe File' : 'File Selected', style: const TextStyle(fontSize: 13)),
              ),
              if (selectedPath != null) ...[
                const SizedBox(height: 10),
                Text(selectedPath!.split('/').last, style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Master Password', hintText: 'Enter password...'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (selectedPath == null || loading)
                  ? null
                  : () async {
                      if (pwCtrl.text.isEmpty) return;
                      setDialogState(() => loading = true);
                      try {
                        await BackupService.restoreBackup(selectedPath!, pwCtrl.text);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault restored successfully!'), backgroundColor: AppTheme.safe));
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore failed: Invalid password or corrupted file'), backgroundColor: AppTheme.danger));
                        }
                      }
                    },
              child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.background)) : const Text('Restore Vault'),
            ),
          ],
        ),
      ),
    );
  }
}
