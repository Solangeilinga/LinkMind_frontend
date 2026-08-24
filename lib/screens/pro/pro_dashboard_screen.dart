import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

class ProDashboardScreen extends StatefulWidget {
  const ProDashboardScreen({super.key});

  @override
  State<ProDashboardScreen> createState() => _ProDashboardScreenState();
}

class _ProDashboardScreenState extends State<ProDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _bookings = [];
  String? _statusFilter; // null = tous
  Map<String, dynamic>? _me;

  static const _statusLabels = {
    'pending': 'En attente',
    'confirmed': 'Confirmé',
    'completed': 'Terminé',
    'cancelled': 'Annulé',
  };

  static const _statusColors = {
    'pending': AppColors.accentOrange,
    'confirmed': AppColors.primary,
    'completed': AppColors.secondary,
    'cancelled': AppColors.onSurfaceMuted,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!await ProApiService().isLoggedIn()) {
      if (mounted) context.go('/pro/login');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        ProApiService().getMe(),
        ProApiService().getBookings(status: _statusFilter),
      ]);
      setState(() {
        _me = (results[0] as Map<String, dynamic>)['professional'] as Map<String, dynamic>?;
        _bookings = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      // Session expirée en cours d'usage : ProApiService a déjà nettoyé le
      // jeton (voir _handle -> logout() sur 401) — on redirige proprement
      // au lieu d'afficher une erreur technique brute.
      if (!await ProApiService().isLoggedIn() && mounted) {
        context.go('/pro/login');
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ProApiService().logout();
    if (mounted) context.go('/pro/login');
  }

  Future<void> _cancelBooking(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text('Le testeur sera informé de l\'annulation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer l\'annulation')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ProApiService().cancelBooking(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _completeBooking(String id) async {
    try {
      await ProApiService().completeBooking(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mes rendez-vous', style: AppTextStyles.h2),
                            if (_me != null)
                              Text(
                                '${_me!['firstName'] ?? ''} ${_me!['lastName'] ?? ''}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forum_outlined, color: AppColors.primary),
                        onPressed: () => context.push('/pro/community'),
                        tooltip: 'Communauté',
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.onSurfaceMuted),
                        onPressed: _logout,
                        tooltip: 'Se déconnecter',
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filtres de statut ──────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        isSelected: _statusFilter == null,
                        onTap: () { setState(() => _statusFilter = null); _load(); },
                      ),
                      ..._statusLabels.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label: e.value,
                              isSelected: _statusFilter == e.key,
                              onTap: () { setState(() => _statusFilter = e.key); _load(); },
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                    ),
                  ),
                )
              else if (_bookings.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Aucun rendez-vous pour l\'instant.',
                      style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BookingCard(
                        booking: _bookings[index] as Map<String, dynamic>,
                        statusLabels: _statusLabels,
                        statusColors: _statusColors,
                        onCancel: () => _cancelBooking(_bookings[index]['id'] ?? _bookings[index]['_id']),
                        onComplete: () => _completeBooking(_bookings[index]['id'] ?? _bookings[index]['_id']),
                      ),
                      childCount: _bookings.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pro/slots'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
        label: const Text('Mes créneaux', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: AppRadius.full,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, String> statusLabels;
  final Map<String, Color> statusColors;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  const _BookingCard({
    required this.booking,
    required this.statusLabels,
    required this.statusColors,
    required this.onCancel,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = (booking['status'] as String?) ?? 'pending';
    final alias = (booking['userAlias'] as String?) ?? 'Utilisateur anonyme';
    final message = booking['message'] as String?;
    final scheduledAt = booking['scheduledAt'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(alias, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (statusColors[status] ?? AppColors.onSurfaceMuted).withValues(alpha: 0.12),
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  statusLabels[status] ?? status,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColors[status] ?? AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (scheduledAt != null) ...[
            const SizedBox(height: 6),
            Text(scheduledAt, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          ],
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(message, style: AppTextStyles.body),
          ],
          if (status == 'pending' || status == 'confirmed') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'confirmed')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onComplete,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('Marquer terminé'),
                    ),
                  ),
                if (status == 'confirmed') const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
