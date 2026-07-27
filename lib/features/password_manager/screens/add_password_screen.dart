import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/cybe_widgets.dart';
import '../bloc/password_bloc.dart';

class AddPasswordScreen extends StatefulWidget {
  final String? editId;
  const AddPasswordScreen({super.key, this.editId});
  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'Other';
  bool _obscure = true;
  double _strength = 0;

  // Generator state
  int _genLength = 16;
  bool _genUpper = true, _genLower = true, _genNums = true, _genSyms = true;

  bool get isEditing => widget.editId != null;

  @override
  void dispose() {
    _siteCtrl.dispose();
    _userCtrl.dispose();
    _pwCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Password' : 'Add Password'),
        backgroundColor: AppTheme.background,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ResponsiveCenter(
          maxWidth: 600,
          child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field('Site / App Name', Icons.web_outlined, _siteCtrl, required: true),
              const SizedBox(height: 14),
              _field('Username / Email', Icons.person_outline, _userCtrl, required: true),
              const SizedBox(height: 14),
              // Password field with generator
              TextFormField(
                controller: _pwCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (v) => setState(() => _strength = CryptoUtils.passwordStrength(v)),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high_outlined, size: 18, color: AppTheme.primary),
                        onPressed: _showGenerator,
                        tooltip: 'Generate password',
                      ),
                    ],
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
              ),
              const SizedBox(height: 6),
              // Strength bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _strength,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation(
                    _strength < 0.4 ? AppTheme.danger : _strength < 0.7 ? AppTheme.warning : AppTheme.safe),
                  minHeight: 4,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  CryptoUtils.passwordStrengthLabel(_strength),
                  style: TextStyle(
                    fontSize: 11,
                    color: _strength < 0.4 ? AppTheme.danger : _strength < 0.7 ? AppTheme.warning : AppTheme.safe),
                ),
              ),
              const SizedBox(height: 14),
              // Category dropdown
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppTheme.surface,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Category',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                items: AppConstants.categories
                    .where((c) => c != 'All')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
              ),
              const SizedBox(height: 14),
              _field('Website URL (optional)', Icons.link_outlined, _urlCtrl),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_outlined),
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              BlocConsumer<PasswordBloc, PasswordState>(
                listener: (context, state) {
                  if (state is PasswordLoaded) context.pop();
                  if (state is PasswordError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.message), backgroundColor: AppTheme.danger),
                    );
                  }
                },
                builder: (context, state) => SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: state is PasswordLoading ? null : _save,
                    child: state is PasswordLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(isEditing ? 'SAVE CHANGES' : 'SAVE PASSWORD',
                            style: const TextStyle(letterSpacing: 1.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String hint, IconData icon, TextEditingController ctrl, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
      validator: required ? (v) => (v == null || v.isEmpty) ? '$hint is required' : null : null,
    );
  }

  void _showGenerator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password Generator', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              // Length slider
              Row(
                children: [
                  const Text('Length:', style: TextStyle(color: AppTheme.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: _genLength.toDouble(),
                      min: 8, max: 32, divisions: 24,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setModal(() => _genLength = v.toInt()),
                    ),
                  ),
                  Text('$_genLength', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              _toggleRow('Uppercase (A-Z)', _genUpper, (v) => setModal(() => _genUpper = v)),
              _toggleRow('Lowercase (a-z)', _genLower, (v) => setModal(() => _genLower = v)),
              _toggleRow('Numbers (0-9)', _genNums, (v) => setModal(() => _genNums = v)),
              _toggleRow('Symbols (!@#\$)', _genSyms, (v) => setModal(() => _genSyms = v)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final pwd = CryptoUtils.generatePassword(
                      length: _genLength,
                      uppercase: _genUpper,
                      lowercase: _genLower,
                      numbers: _genNums,
                      symbols: _genSyms,
                    );
                    setState(() {
                      _pwCtrl.text = pwd;
                      _strength = CryptoUtils.passwordStrength(pwd);
                    });
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Generate & Use'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        const Spacer(),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (isEditing) {
      context.read<PasswordBloc>().add(PasswordUpdate(
        id: widget.editId!,
        site: _siteCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _pwCtrl.text,
        category: _category,
        url: _urlCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
    } else {
      context.read<PasswordBloc>().add(PasswordAdd(
        site: _siteCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _pwCtrl.text,
        category: _category,
        url: _urlCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
    }
  }
}
