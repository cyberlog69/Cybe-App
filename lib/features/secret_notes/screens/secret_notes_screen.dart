import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/secret_notes_bloc.dart';
import '../models/secret_note.dart';

class SecretNotesScreen extends StatelessWidget {
  const SecretNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SecretNotesBloc()..add(SecretNotesLoad()),
      child: const _SecretNotesView(),
    );
  }
}

class _SecretNotesView extends StatefulWidget {
  const _SecretNotesView();

  @override
  State<_SecretNotesView> createState() => _SecretNotesViewState();
}

class _SecretNotesViewState extends State<_SecretNotesView> {
  String _selectedCategory = 'All';

  void _showNoteDialog(BuildContext context, {SecretNote? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    String category = existing?.category ?? 'Personal';
    bool isPinned = existing?.isPinned ?? false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(existing == null ? 'New Secret Note' : 'Edit Secret Note', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'Recovery Seed / Secret Note'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const ['Personal', 'Financial', 'Recovery Keys', 'Work', 'Confidential']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Personal'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                  decoration: const InputDecoration(labelText: 'Content', hintText: 'Enter secret text...'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Pin to top', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                  value: isPinned,
                  onChanged: (v) => setDialogState(() => isPinned = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final note = SecretNote.create(
                  title: titleCtrl.text.trim(),
                  content: contentCtrl.text,
                  category: category,
                  isPinned: isPinned,
                  existingId: existing?.id,
                );
                context.read<SecretNotesBloc>().add(SecretNotesSave(note));
                Navigator.pop(dialogCtx);
              },
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Notes'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showNoteDialog(context),
            tooltip: 'Add Secret Note',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 900,
          child: BlocBuilder<SecretNotesBloc, SecretNotesState>(
            builder: (context, state) {
              if (state is SecretNotesLoading || state is SecretNotesInitial) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              if (state is SecretNotesLoaded) {
                var notes = state.notes;
                if (_selectedCategory != 'All') {
                  notes = notes.where((n) => n.category == _selectedCategory).toList();
                }

                return Column(
                  children: [
                    // Category Bar
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        children: ['All', 'Personal', 'Financial', 'Recovery Keys', 'Work', 'Confidential'].map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(color: isSelected ? AppTheme.background : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                              backgroundColor: AppTheme.surfaceVariant,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: notes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sticky_note_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  const Text('No Secret Notes Found', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text('All notes are encrypted with AES-256-CBC', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () => _showNoteDialog(context),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create Secret Note'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: notes.length,
                              itemBuilder: (ctx, i) {
                                final note = notes[i];
                                return _NoteCard(
                                  note: note,
                                  onTap: () => _showNoteDialog(context, existing: note),
                                  onDelete: () => context.read<SecretNotesBloc>().add(SecretNotesDelete(note.id)),
                                );
                              },
                            ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final SecretNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: note.isPinned ? AppTheme.primary.withOpacity(0.4) : const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
                ),
              Expanded(
                child: Text(note.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(6)),
                child: Text(note.category, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM d, yyyy \u2022 HH:mm').format(note.updatedAt), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                    tooltip: 'Copy Note',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: note.content));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note content copied to clipboard')));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                    onPressed: onTap,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
