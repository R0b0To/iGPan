import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/ui_provider.dart';
import '../../providers/game_provider.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/account_pill.dart';
import '../../ui/widgets/action_panel.dart';
import '../../ui/widgets/batch_bar.dart';
import '../screens/accounts_screen.dart';

// Adjusted breakpoints
const double _kMobileMaxWidth = 400.0;
const double _kDesktopColumnWidth = 400.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  
  double _currentItemWidth = 0.0;
  bool _isCentered = false;
  bool _isScrollingProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController.addListener(_onMainScroll);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Updates the "selected" pill when the user manually scrolls left/right
  void _onMainScroll() {
    if (_isScrollingProgrammatically || _currentItemWidth == 0 || _isCentered) return;

    final isBatchMode = ref.read(batchSelectionProvider).isNotEmpty;
    if (isBatchMode) return;

    final offset = _horizontalScrollController.offset;
    final index = (offset / _currentItemWidth).round(); 

    final accounts = ref.read(accountsProvider).valueOrNull?.where((a) => a.enabled).toList() ?? [];
    if (index >= 0 && index < accounts.length) {
      final email = accounts[index].email;
      if (ref.read(selectedAccountProvider) != email) {
        Future.microtask(() {
          ref.read(selectedAccountProvider.notifier).select(email);
        });
      }
    }
  }

  // Smooth scrolls the view when user taps a pill
  void _scrollToIndex(int index) async {
    if (_isCentered || !_horizontalScrollController.hasClients) return;
    _isScrollingProgrammatically = true;
    
    await _horizontalScrollController.animateTo(
      index * _currentItemWidth,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    
    _isScrollingProgrammatically = false;
  }

  void _claimAll(WidgetRef ref, List<String> emails) {
    ref.read(batchActionProvider.notifier).claimDailyRewardAll(emails);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final selected      = ref.watch(selectedAccountProvider);
    final batchSelected = ref.watch(batchSelectionProvider);
    final isBatchMode   = batchSelected.isNotEmpty;
    final batchState    = ref.watch(batchActionProvider);

    ref.listen<String?>(selectedAccountProvider, (previous, next) {
      if (next != null && next != previous && !_isScrollingProgrammatically) {
        final enabled = ref.read(accountsProvider).valueOrNull?.where((a) => a.enabled).toList() ?? [];
        final index = enabled.indexWhere((a) => a.email == next);
        if (index != -1) {
          _scrollToIndex(index);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('iGPan'),
        actions: [
          IconButton(
            icon:    const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Manage accounts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (accounts) {
          final enabled = accounts.where((a) => a.enabled).toList();

          if (enabled.isEmpty) {
            return _EmptyState(
              onAddAccount: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            );
          }

          if (selected == null && enabled.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedAccountProvider.notifier).select(enabled.first.email);
            });
          }

          return Column(
            children: [
              const Divider(height: 0),
              _AccountPillRail(
                enabledAccounts: enabled,
                selectedEmail:   selected,
                batchSelected:   batchSelected,
                isBatchMode:     isBatchMode,
              ),
              const Divider(height: 0),

              if (isBatchMode)
                BatchBar(
                  selectedCount: batchSelected.length,
                  isRunning:     batchState.isRunning,
                  onClaimAll:    () => _claimAll(ref, batchSelected.toList()),
                  onRepairAll:   () {}, 
                  onClear:       () => ref.read(batchSelectionProvider.notifier).clear(),
                ),

              if (batchState.hasResults && !batchState.isRunning)
                _BatchResultsPanel(results: batchState.results),

              // ── Dynamic Responsive Multi-Column Layout ────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final bool isDesktop = availableWidth > _kMobileMaxWidth;
                    
                    _currentItemWidth = isDesktop ? _kDesktopColumnWidth : availableWidth;
                    
                    // 1. Calculate how many whole columns can fit exactly
                    int fitCount = (availableWidth / _currentItemWidth).floor();
                    if (fitCount < 1) fitCount = 1;
                    
                    // 2. Clamp it so we don't reserve space for cards that don't exist
                    final int displayCount = math.min(fitCount, enabled.length);
                    
                    // 3. This strict container width guarantees you NEVER see "half" a card resting at the edges
                    final double containerWidth = displayCount * _currentItemWidth;
                    
                    _isCentered = isDesktop && (enabled.length <= fitCount);

                    Widget contentRow = Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: enabled.map((account) {
                        return SizedBox(
                          width: _currentItemWidth,
                          child: isDesktop 
                              ? _DesktopAccountCard(accountEmail: account.email)
                              : ActionPanel(accountEmail: account.email),
                        );
                      }).toList(),
                    );

                    Widget scrollableArea = ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
                      ),
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        // Bouncing on desktop, swiping on mobile
                        physics: isDesktop ? const BouncingScrollPhysics() : const PageScrollPhysics(),
                        child: contentRow,
                      ),
                    );

                    // 4. Wrap the scroll view in a centered SizedBox using our exact calculated width
                    return Center(
                      child: SizedBox(
                        width: containerWidth,
                        child: scrollableArea,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Desktop Card Wrapper ────────────────────────────────────────────────────

class _DesktopAccountCard extends StatelessWidget {
  final String accountEmail;
  const _DesktopAccountCard({required this.accountEmail});

  @override
  Widget build(BuildContext context) {
    return Container(
      // The margins provide the visual spacing, while the wrapper guarantees it takes exactly 400 width
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface, 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, 
      child: ActionPanel(accountEmail: accountEmail),
    );
  }
}

// ─── Account Pill Rail ───────────────────────────────────────────────────────

class _AccountPillRail extends ConsumerStatefulWidget {
  final List<Account> enabledAccounts;
  final String? selectedEmail;
  final Set<String> batchSelected;
  final bool isBatchMode;

  const _AccountPillRail({
    required this.enabledAccounts,
    this.selectedEmail,
    required this.batchSelected,
    required this.isBatchMode,
  });

  @override
  ConsumerState<_AccountPillRail> createState() => _AccountPillRailState();
}

class _AccountPillRailState extends ConsumerState<_AccountPillRail> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  void _updateArrows() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    setState(() {
      _canScrollLeft = pos.pixels > 10;
      _canScrollRight = pos.pixels < (pos.maxScrollExtent - 10);
    });
  }

  @override
  void didUpdateWidget(_AccountPillRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedEmail != oldWidget.selectedEmail && widget.selectedEmail != null) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[widget.selectedEmail];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          alignment: 0.5,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _scrollBy(double offset) {
    _scrollController.animateTo(
      _scrollController.offset + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: AppTheme.surfaceCard,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                for (final kind in PointerDeviceKind.values) kind,
              },
            ),
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.black, Colors.transparent, Colors.transparent, Colors.black],
                  stops: [0.0, 0.06, 0.94, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstOut,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(), 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: widget.enabledAccounts.length + 1,
                itemBuilder: (context, index) {
                  if (index == widget.enabledAccounts.length) {
                    return AddAccountPill(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountsScreen()),
                      ),
                    );
                  }

                  final account = widget.enabledAccounts[index];
                  final sessionState = ref.watch(sessionStateProvider(account.email)).valueOrNull;
                  final itemKey = _itemKeys.putIfAbsent(account.email, () => GlobalKey());

                  return Padding(
                    key: itemKey,
                    padding: const EdgeInsets.only(right: 8),
                    child: AccountPill(
                      label: account.nickname,
                      isSelected: widget.selectedEmail == account.email,
                      isBatchSelected: widget.batchSelected.contains(account.email),
                      isSessionActive: sessionState?.isValid ?? false,
                      isBatchMode: widget.isBatchMode,
                      onTap: () {
                        if (widget.isBatchMode) {
                          ref.read(batchSelectionProvider.notifier).toggle(account.email);
                        } else {
                          ref.read(selectedAccountProvider.notifier).select(account.email);
                        }
                      },
                      onLongPress: () => ref.read(batchSelectionProvider.notifier).toggle(account.email),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_canScrollLeft)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: _ScrollArrow(icon: Icons.chevron_left, onTap: () => _scrollBy(-150)),
            ),
          if (_canScrollRight)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _ScrollArrow(icon: Icons.chevron_right, onTap: () => _scrollBy(150)),
            ),
        ],
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScrollArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: icon == Icons.chevron_left ? Alignment.centerLeft : Alignment.centerRight,
            end: icon == Icons.chevron_left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              AppTheme.surfaceCard,
              AppTheme.surfaceCard.withOpacity(0.0),
            ],
          ),
        ),
        child: Icon(icon, size: 20, color: AppTheme.onSurfaceDim.withOpacity(0.7)),
      ),
    );
  }
}

// ─── Batch results list ──────────────────────────────────────────────────────

class _BatchResultsPanel extends ConsumerStatefulWidget {
  final Map<String, BatchResult> results;
  const _BatchResultsPanel({required this.results});

  @override
  ConsumerState<_BatchResultsPanel> createState() => _BatchResultsPanelState();
}

class _BatchResultsPanelState extends ConsumerState<_BatchResultsPanel> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        ref.read(batchActionProvider.notifier).clear();
        ref.read(batchSelectionProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
            child: Row(children: [
              const Expanded(child: Text('Batch results',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceDim))),
              GestureDetector(
                onTap: () {
                  ref.read(batchActionProvider.notifier).clear();
                  ref.read(batchSelectionProvider.notifier).clear();
                },
                child: const Icon(Icons.close, size: 16, color: AppTheme.onSurfaceDim)),
            ]),
          ),
          const SizedBox(height: 6),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
          ...widget.results.entries.map((entry) {
            final email    = entry.key;
            final result   = entry.value;
            final success  = result.success;
            final account  = accounts.firstWhere(
              (a) => a.email == email, orElse: () => accounts.first);
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5))),
              child: Row(children: [
                Expanded(child: Text(account.nickname,
                  style: const TextStyle(fontSize: 13, color: AppTheme.onSurface))),
                Icon(success ? Icons.check : Icons.close,
                    size: 14, color: success ? AppTheme.success : AppTheme.error),
                const SizedBox(width: 4),
                Text(success ? 'Done' : 'Failed',
                    style: TextStyle(fontSize: 12, color: success ? AppTheme.success : AppTheme.error)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;
  const _EmptyState({required this.onAddAccount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_add_alt_1_rounded, size: 56, color: AppTheme.onSurfaceFaint),
          const SizedBox(height: 16),
          const Text('No accounts yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddAccount,
            icon:      const Icon(Icons.add, size: 18),
            label:     const Text('Add account'),
          ),
        ],
      ),
    );
  }
}