import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/password_bloc.dart';
import '../models/password_entry.dart';

import '../widgets/password_generator_sheet.dart';

class PasswordManagerScreen extends StatefulWidget {
  const PasswordManagerScreen({super.key});
  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    context.read<PasswordBloc>().add(PasswordLoad());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Manager'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.primary),
            onPressed: () => PasswordGeneratorSheet.show(context),
            tooltip: 'Password Generator',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
            onPressed: () => context.push('/passwords/add'),
            tooltip: 'Add Password',
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: Column(
            children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search passwords...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => context.read<PasswordBloc>().add(PasswordSearch(v)),
              ),
            ),
            // Category Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.categories.map((cat) {
                    final selected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                          context.read<PasswordBloc>().add(PasswordFilterCategory(cat));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primary : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? AppTheme.primary : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: selected ? AppTheme.background : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Password List
            Expanded(
              child: BlocBuilder<PasswordBloc, PasswordState>(
                builder: (context, state) {
                  if (state is PasswordLoading) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  }
                  if (state is PasswordError) {
                    return Center(child: Text(state.message, style: const TextStyle(color: AppTheme.danger)));
                  }
                  if (state is PasswordLoaded) {
                    final entries = state.filtered;
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.key_off_rounded, size: 60, color: AppTheme.textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text('No passwords found', style: TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => context.push('/passwords/add'),
                              child: const Text('Add your first password'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (_, i) => _PasswordCard(entry: entries[i]),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/passwords/add'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.add),
        label: const Text('Add Password'),
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  final PasswordEntry entry;
  const _PasswordCard({required this.entry});
  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  bool _showPassword = false;

  Color get _strengthColor {
    final s = widget.entry.strength;
    if (s < 0.4) return AppTheme.danger;
    if (s < 0.7) return AppTheme.warning;
    return AppTheme.safe;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    widget.entry.site.isNotEmpty ? widget.entry.site[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.entry.site,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(widget.entry.username,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.entry.category,
                  style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Password row
          Row(
            children: [
              Expanded(
                child: Text(
                  _showPassword ? widget.entry.password : '•' * 12,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontFamily: _showPassword ? 'monospace' : null,
                    fontSize: 14,
                    letterSpacing: _showPassword ? 0 : 2,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _showPassword = !_showPassword),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18, color: AppTheme.textSecondary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.entry.password));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password copied! Will clear in 30s')),
                  );
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                onPressed: () => context.push('/passwords/edit/${widget.entry.id}'),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                onPressed: () => _confirmDelete(context),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Strength bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widget.entry.strength,
                    backgroundColor: AppTheme.divider,
                    valueColor: AlwaysStoppedAnimation(_strengthColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.entry.strengthLabel,
                style: TextStyle(color: _strengthColor, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Password?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove "${widget.entry.site}" from your vault?',
          style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PasswordBloc>().add(PasswordDelete(widget.entry.id));
    }
  }
}
