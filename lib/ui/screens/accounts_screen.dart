import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../providers/accounts_provider.dart';
import '../../ui/theme/app_theme.dart';

/// Manage accounts — add, delete, enable/disable, reorder.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon:      const Icon(Icons.add),
            tooltip:   'Add account',
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline,
                      size: 48, color: AppTheme.onSurfaceFaint),
                  const SizedBox(height: 12),
                  const Text('No accounts',
                      style: TextStyle(
                          color: AppTheme.onSurfaceDim, fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context, ref),
                    icon:      const Icon(Icons.add, size: 18),
                    label:     const Text('Add account'),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding:      const EdgeInsets.all(12),
            itemCount:    accounts.length,
            onReorder:    (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx--;
              final reordered = List<Account>.from(accounts);
              reordered.insert(newIdx, reordered.removeAt(oldIdx));
              ref.read(accountsProvider.notifier).reorder(reordered);
            },
            itemBuilder:  (context, index) {
              final account = accounts[index];
              return _AccountCard(
                key:     ValueKey(account.email),
                account: account,
                onToggle: (enabled) => ref
                    .read(accountsProvider.notifier)
                    .setEnabled(account.email, enabled: enabled),
                onDelete: () => _confirmDelete(context, ref, account),
                onRename: () => _showRenameDialog(context, ref, account),
              );
            },
          );
        },
      ),
    );
  }

  // ─── Dialogs ────────────────────────────────────────────

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AddAccountDialog(
        onAdd: (email, password, nickname) async {
          await ref.read(accountsProvider.notifier).addAccount(
            email:    email,
            password: password,
            nickname: nickname,
          );
        },
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Account account) {
    final ctrl = TextEditingController(text: account.nickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename account'),
        content: TextField(
          controller:  ctrl,
          autofocus:   true,
          decoration:  const InputDecoration(labelText: 'Nickname'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:     const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref
                    .read(accountsProvider.notifier)
                    .renameAccount(account.email, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Remove account?'),
        content: Text(
          'This will permanently remove "${account.nickname}" '
          'and delete all stored cookies and credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:     const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child:     const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(accountsProvider.notifier)
          .deleteAccount(account.email);
    }
  }
}

// ─── Account card ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Account      account;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _AccountCard({
    super.key,
    required this.account,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final initials = account.nickname.length >= 2
        ? account.nickname.substring(0, 2).toUpperCase()
        : account.nickname.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width:  40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: account.enabled
                ? AppTheme.primary.withOpacity(0.18)
                : AppTheme.onSurfaceFaint.withOpacity(0.3),
          ),
          child: Text(
            initials,
            style: TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color: account.enabled
                  ? AppTheme.primary
                  : AppTheme.onSurfaceDim,
            ),
          ),
        ),
        title: Text(
          account.nickname,
          style: TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
            color: account.enabled
                ? AppTheme.onSurface
                : AppTheme.onSurfaceDim,
          ),
        ),
        subtitle: Text(
          account.email,
          style: const TextStyle(
              fontSize: 11, color: AppTheme.onSurfaceDim),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enable toggle
            Switch(
              value:      account.enabled,
              onChanged:  onToggle,
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            // Menu
            PopupMenuButton<String>(
              color:    AppTheme.surfaceRaised,
              icon:     const Icon(Icons.more_vert,
                  color: AppTheme.onSurfaceDim, size: 18),
              onSelected: (value) {
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ),
            // Drag handle
            const Icon(Icons.drag_handle,
                color: AppTheme.onSurfaceFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Add account dialog ───────────────────────────────────────────────────────

class _AddAccountDialog extends StatefulWidget {
  final Future<void> Function(String email, String password, String nickname)
      onAdd;

  const _AddAccountDialog({required this.onAdd});

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool   _loading      = false;
  bool   _obscure      = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await widget.onAdd(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _nicknameCtrl.text.trim().isEmpty
            ? _emailCtrl.text.trim().split('@').first
            : _nicknameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller:   _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration:   const InputDecoration(labelText: 'Email'),
              validator:    (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller:     _passwordCtrl,
              obscureText:    _obscure,
              decoration:     InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                      size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller:  _nicknameCtrl,
              decoration:  const InputDecoration(
                labelText: 'Nickname (optional)',
                hintText:  'e.g. Main, Alt1',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child:     const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child:     _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Add'),
        ),
      ],
    );
  }
}
