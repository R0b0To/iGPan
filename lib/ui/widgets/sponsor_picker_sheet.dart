import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finance_data.dart';
import '../../providers/providers.dart';
import '../../ui/theme/app_theme.dart';

/// Bottom sheet for selecting a new primary or secondary sponsor.
///
/// Fetches available options on open, shows them in a 2-column grid,
/// and signs the chosen contract after confirmation.
///
/// The parent is responsible for refreshing finance + session data
/// after this sheet is dismissed (use `.then((_) { ... })` on the
/// `showModalBottomSheet` call).
class SponsorPickerSheet extends ConsumerStatefulWidget {
  final String accountEmail;
  /// true → location=1 (primary), false → location=2 (secondary).
  final bool isPrimary;

  const SponsorPickerSheet({
    super.key,
    required this.accountEmail,
    required this.isPrimary,
  });

  @override
  ConsumerState<SponsorPickerSheet> createState() =>
      _SponsorPickerSheetState();
}

class _SponsorPickerSheetState extends ConsumerState<SponsorPickerSheet> {
  List<SponsorOption>? _options;
  bool    _loading  = true;
  String? _error;
  int?    _signingId; // eId currently awaiting a sign response

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  // ─── Fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetch() async {
    try {
      final opts = await ref.read(financeServiceProvider).fetchSponsorOptions(
        widget.accountEmail,
        location: widget.isPrimary ? 1 : 2,
      );
      if (mounted) setState(() { _options = opts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─── Sign ──────────────────────────────────────────────────────────────

  Future<void> _sign(SponsorOption option) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign sponsor?'),
        content: Text(
          "Sign ${widget.isPrimary ? 'primary' : 'secondary'} sponsor "
          'for ${option.cashBonus}/race'
          '${widget.isPrimary && option.tokens > 0 ? ' + ${option.tokens} token${option.tokens == 1 ? '' : 's'}' : ''}?\n\n'
          "Your choice can't be changed once confirmed.",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingId = option.eId);
    try {
      await ref.read(financeServiceProvider).signSponsor(
        widget.accountEmail,
        eId:      option.eId,
        location: widget.isPrimary ? 1 : 2,
      );
      if (mounted) Navigator.pop(context); // dismiss → parent refreshes
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign failed: $e')));
        setState(() => _signingId = null);
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.45,
      maxChildSize:     0.95,
      expand:           false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          )),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(children: [
              const Icon(Icons.handshake_outlined,
                  size: 17, color: AppTheme.onSurface),
              const SizedBox(width: 8),
              Text(
                widget.isPrimary
                    ? 'Primary Sponsor'
                    : 'Secondary Sponsor',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface),
              ),
              if (widget.isPrimary) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:        AppTheme.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.5),
                        width: 0.6),
                  ),
                  child: const Text('Tokens per race',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent)),
                ),
              ],
            ]),
          ),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),

          // Grid
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 12)),
                        ))
                    : (_options?.isEmpty ?? true)
                        ? const Center(
                            child: Text('No sponsors available.',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceDim,
                                    fontSize: 13)))
                        : GridView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                12, 10, 12, 32),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:   2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing:  10,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: _options!.length,
                            itemBuilder: (_, i) {
                              final opt = _options![i];
                              return _SponsorCard(
                                option:    opt,
                                isPrimary: widget.isPrimary,
                                isSigning: _signingId == opt.eId,
                                onSign:    () => _sign(opt),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Sponsor card ─────────────────────────────────────────────────────────────

class _SponsorCard extends StatelessWidget {
  final SponsorOption option;
  final bool          isPrimary;
  final bool          isSigning;
  final VoidCallback  onSign;

  const _SponsorCard({
    required this.option,
    required this.isPrimary,
    required this.isSigning,
    required this.onSign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          // ── Logo ───────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Image.network(
                    option.logoUrl,
                    fit:          BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_outlined,
                        size:  36,
                        color: AppTheme.onSurfaceFaint),
                  ),
                ),
              ),
            ),
          ),

          // ── Income row ─────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cash bonus
                    const Icon(Icons.monetization_on_outlined,
                        size: 11, color: AppTheme.success),
                    const SizedBox(width: 3),
                    Text(option.cashBonus,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success)),
                    // Token income (primary only)
                    if (isPrimary && option.tokens > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.bolt,
                          size: 11, color: AppTheme.accent),
                      const SizedBox(width: 2),
                      Text('${option.tokens}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // ── Sign button ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: isSigning ? null : onSign,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:        AppTheme.primary.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(7),
                        border:       Border.all(
                            color: AppTheme.primary, width: 0.8),
                      ),
                      child: isSigning
                          ? const Center(
                              child: SizedBox(
                                width:  12,
                                height: 12,
                                child:  CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: AppTheme.primary),
                              ))
                          : const Text('Sign',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize:   11,
                                  fontWeight: FontWeight.w700,
                                  color:      AppTheme.primary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
