import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/theme.dart';
import '../../services/api.service.dart';
import '../../providers/professionals_provider.dart';
import '../../widgets/skeleton_widget.dart'; // ✅ Ton nouveau provider
import '../../widgets/report_button.dart';

// ─── Types ────────────────────────────────────────────────────────────────────
const _typeConfigDefault = {
  'all':          (label: 'Tous',         labelPlural: 'Tous',          emoji: '👥', color: AppColors.primary),
  'psychologist': (label: 'Psychologue',  labelPlural: 'Psychologues',  emoji: '🧠', color: AppColors.primary),
  'coach':        (label: 'Coach',        labelPlural: 'Coachs',        emoji: '🌱', color: AppColors.accentOrange),
  'doctor':       (label: 'Médecin',      labelPlural: 'Médecins',      emoji: '🩺', color: AppColors.accent),
};

const _statusConfig = {
  'pending':   (label: 'En attente',  color: AppColors.secondary),
  'confirmed': (label: 'Confirmée',   color: Color(0xFF2ECC71)),
  'cancelled': (label: 'Annulée',     color: AppColors.accent),
  'completed': (label: 'Terminée',    color: AppColors.onSurfaceMuted),
};

class ProfessionalsScreen extends ConsumerStatefulWidget {
  const ProfessionalsScreen({super.key});
  @override
  ConsumerState<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends ConsumerState<ProfessionalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController(); // ✅ Pour la pagination
  
  Timer? _debounce; // ✅ Anti-spam pour la recherche
  String _activeType = 'all';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    
    // ✅ Écouteur pour la pagination (Infinite Scroll)
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        ref.read(professionalsProvider.notifier).loadMoreProfessionals();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(professionalsProvider.notifier).loadProfessionals(search: val);
    });
  }

  void _onTypeChanged(String type) {
    setState(() => _activeType = type);
    ref.read(professionalsProvider.notifier).loadProfessionals(type: type);
  }

  Future<void> _updateBooking(Map<String, dynamic> booking, {
    String? consultationType, String? preferredDate, String? message,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (consultationType != null) data['consultationType'] = consultationType;
      if (preferredDate != null) data['preferredDate'] = preferredDate;
      if (message != null) data['message'] = message;
      
      await ApiService().put('/professionals/bookings/${booking['_id']}', data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande modifiée avec succès'), backgroundColor: AppColors.secondary),
        );
        ref.read(professionalsProvider.notifier).loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('attente') 
              ? 'Seules les demandes en attente peuvent être modifiées'
              : 'Erreur lors de la modification'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande'),
        content: const Text('Es-tu sûr de vouloir annuler cette demande ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/professionals/bookings/${booking['_id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Demande annulée avec succès'), backgroundColor: AppColors.secondary),
          );
          ref.read(professionalsProvider.notifier).loadBookings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().contains('attente')
                ? 'Seules les demandes en attente peuvent être annulées'
                : 'Erreur lors de l\'annulation'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      }
    }
  }

  void _showEditBookingSheet(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBookingSheet(
        booking: booking,
        onUpdate: (consultationType, preferredDate, message) {
          _updateBooking(booking, consultationType: consultationType, preferredDate: preferredDate, message: message);
        },
      ),
    );
  }

  void _showBookingSheet(Map<String, dynamic> pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(
        professional: pro,
        onBooked: () {
          ref.read(professionalsProvider.notifier).loadBookings(forceRefresh: true);
          _tabCtrl.animateTo(1);
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh au retour sur cet écran via navigation
    ref.read(professionalsProvider.notifier).loadProfessionals();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(professionalsProvider);

    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Professionnels 🩺', style: AppTextStyles.h2),
            Text('Psychologues, coachs et médecins partenaires',
                style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 14),

            Container(
              height: 38,
              decoration: const BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.full),
              child: TabBar(
                controller: _tabCtrl,
                indicator: const BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.full),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.onSurfaceMuted,
                labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(text: 'Trouver un pro'),
                  Tab(text: 'Mes demandes${state.bookings.isNotEmpty ? " (${state.bookings.length})" : ""}'),
                ],
              ),
            ),
          ]),
        ),

        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            // ─── ONGLET 1 : LISTE ───
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged, // ✅ Utilise le debounce
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, ville, spécialité...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () { 
                              _searchCtrl.clear(); 
                              _onSearchChanged(''); 
                            })
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _typeConfigDefault.entries.map((e) {
                    final sel = _activeType == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _onTypeChanged(e.key), // ✅ Filtre serveur
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? e.value.color.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                            borderRadius: AppRadius.full,
                            border: Border.all(color: sel ? e.value.color : Colors.transparent, width: 1.5)),
                          child: Text('${e.value.emoji} ${e.value.label}',
                              style: AppTextStyles.caption.copyWith(
                                color: sel ? e.value.color : AppColors.onSurfaceMuted,
                                fontWeight: sel ? FontWeight.w900 : FontWeight.w600)),
                        ),
                      ),
                    );
                  }).toList()),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(child: state.isLoadingPros
                ? SkeletonList(itemBuilder: () => const SkeletonProCard(), count: 4)
                : state.error != null
                  ? Center(child: Text(state.error!, style: AppTextStyles.body.copyWith(color: AppColors.accent)))
                  : state.professionals.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🔍', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text('Aucun professionnel trouvé', style: AppTextStyles.h4.copyWith(color: AppColors.onSurfaceMuted)),
                      ]))
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref.read(professionalsProvider.notifier).loadProfessionals(),
                        child: ListView.builder(
                          controller: _scrollCtrl, // ✅ Pagination attachée
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: state.professionals.length + (state.isPaginating ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == state.professionals.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ProfessionalCard(
                                pro: state.professionals[i],
                                onBook: () => _showBookingSheet(state.professionals[i]),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),

            // ─── ONGLET 2 : MES DEMANDES ───
            state.isLoadingBookings
                ? SkeletonList(itemBuilder: () => const SkeletonBookingCard(), count: 3)
                : state.bookings.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('📋', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          const Text('Aucune demande pour l\'instant', style: AppTextStyles.h3, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('Trouve un professionnel et envoie ta première demande.',
                              style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted, height: 1.5),
                              textAlign: TextAlign.center),
                        ]),
                      ))
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref.read(professionalsProvider.notifier).loadBookings(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: state.bookings.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BookingCard(
                              booking: state.bookings[i],
                              onEdit: () => _showEditBookingSheet(state.bookings[i]),
                              onCancel: () => _cancelBooking(state.bookings[i]),
                            ),
                          ),
                        ),
                      ),
          ],
        )),
      ])),
    );
  }
}

// ─── Les Widgets Visuels (Intacts) ───────────────────────────────────────────

class _ProfessionalCard extends StatelessWidget {
  final Map<String, dynamic> pro;
  final VoidCallback onBook;
  const _ProfessionalCard({required this.pro, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final typeConf = _typeConfigDefault[pro['type']] ?? _typeConfigDefault['psychologist']!;
    final specs = (pro['specialties'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: typeConf.color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Center(child: Text('👤', style: TextStyle(fontSize: 26)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(pro['fullName'] ?? '', style: AppTextStyles.h4, overflow: TextOverflow.ellipsis)),
                if (pro['isVerified'] == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: AppColors.secondary, size: 16),
                ],
              ]),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: typeConf.color.withValues(alpha: 0.1), borderRadius: AppRadius.full),
                child: Text(typeConf.label, style: AppTextStyles.caption.copyWith(color: typeConf.color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              if (pro['city'] != null)
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 3),
                  Flexible(child: Text(
                    pro['address'] != null
                        ? '${pro['city']} — ${pro['address']}'
                        : pro['city'],
                    style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
            ])),
          ]),

          if (pro['bio'] != null) ...[
            const SizedBox(height: 10),
            Text(pro['bio'], style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],



          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (pro['sessionPrice'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: AppRadius.full),
                  child: Text('${pro['sessionPrice']} ${pro['currency'] ?? 'FCFA'}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w800)),
                ),
              if (pro['isOnline'] == true)  const _ModeChip('🌐 En ligne'),
              if (pro['isInPerson'] == true) const _ModeChip('📍 Présentiel'),
            ])),
            const SizedBox(width: 8),
            ReportButton(targetType: 'professional', targetId: pro['id'], isSmall: true),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: const Text('Demander'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  const _ModeChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: const BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.full),
    child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
  );
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  
  const _BookingCard({required this.booking, required this.onEdit, required this.onCancel});

  String _fmtDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const days   = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '${days[d.weekday % 7]} ${d.day} ${months[d.month - 1]} à ${hh}h${mm}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'pending';
    final statusConf = _statusConfig[status] ?? _statusConfig['pending']!;
    final pro = booking['professional'] as Map<String, dynamic>?;
    final typeConf = _typeConfigDefault[pro?['type']] ?? _typeConfigDefault['psychologist']!;
    final isPending = status == 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: statusConf.color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('👤', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pro?['fullName'] ?? 'Professionnel', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800)),
            Text(typeConf.label, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusConf.color.withValues(alpha: 0.12), borderRadius: AppRadius.full),
            child: Text(statusConf.label, style: AppTextStyles.caption.copyWith(color: statusConf.color, fontWeight: FontWeight.w800)),
          ),
        ]),

        if (booking['preferredDate'] != null && booking['preferredDate'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 4),
            Text(booking['preferredDate'].toString(), style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          ]),
        ],

        if (booking['consultationType'] != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.meeting_room_outlined, size: 13, color: AppColors.onSurfaceMuted),
            const SizedBox(width: 4),
            Text(booking['consultationType'] == 'online' ? '🌐 En ligne' : '📍 Présentiel',
              style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
          ]),
        ],

        if (booking['message'] != null && booking['message'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.md),
            child: Text(booking['message'], style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted, fontSize: 12),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],

        // Créneau confirmé (scheduledAt)
        if (booking['scheduledAt'] != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.access_time, size: 13, color: AppColors.secondary),
            const SizedBox(width: 4),
            Text(_fmtDateTime(booking['scheduledAt'].toString()),
              style: AppTextStyles.caption.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600)),
          ]),
        ],

        // Lien visio (si confirmé et online)
        if (booking['status'] == 'confirmed' && booking['meetingLink'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: AppRadius.md,
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.videocam_outlined, size: 15, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Lien de visioconférence', style: AppTextStyles.caption.copyWith(color: const Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                Text(booking['meetingLink'], style: AppTextStyles.caption.copyWith(color: const Color(0xFF2563EB)), overflow: TextOverflow.ellipsis, maxLines: 1),
              ])),
            ]),
          ),
        ],

        if (booking['adminNote'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: AppRadius.md),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(child: Text(booking['adminNote'], style: AppTextStyles.caption.copyWith(color: AppColors.secondary))),
            ]),
          ),
        ],

        if (isPending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Modifier'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), side: const BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCancel, icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), side: const BorderSide(color: AppColors.accent), foregroundColor: AppColors.accent),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}


// ─── Booking Sheet — avec sélection de créneaux ───────────────────────────────
class _BookingSheet extends StatefulWidget {
  final Map<String, dynamic> professional;
  final VoidCallback onBooked;
  const _BookingSheet({required this.professional, required this.onBooked});
  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _messageCtrl = TextEditingController();
  String _consultationType = 'online';
  bool   _sending        = false;
  bool   _loadingSlots   = false;
  String? _error;

  // Créneaux
  List<Map<String, dynamic>> _slots     = [];
  String? _selectedSlotId;
  String? _selectedSlotLabel;

  // Affichage par date
  Map<String, List<Map<String, dynamic>>> _slotsByDate = {};
  String? _selectedDate;

  // Rafraîchissement auto toutes les 30s — slot peut être pris par un autre user
  Timer? _refreshTimer;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    final pro = widget.professional;
    if (pro['isOnline'] == true)   _consultationType = 'online';
    if (pro['isInPerson'] == true && pro['isOnline'] != true) _consultationType = 'in_person';
    _loadSlots();
    // Rafraîchir silencieusement toutes les 30 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshSlots());
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() { _loadingSlots = true; _error = null; });
    try {
      final proId = widget.professional['id'] ?? widget.professional['_id'];
      final data  = await ApiService().get('/professionals/$proId/slots');
      final raw   = List<Map<String, dynamic>>.from(data['slots'] ?? []);
      final byDate = <String, List<Map<String, dynamic>>>{};
      for (final s in raw) {
        final d = s['date']?.toString() ?? '';
        byDate.putIfAbsent(d, () => []).add(s);
      }
      if (!mounted) return;
      setState(() {
        _slots       = raw;
        _slotsByDate = byDate;
        _loadingSlots = false;
        _lastRefresh = DateTime.now();
        if (byDate.isNotEmpty && _selectedDate == null) _selectedDate = byDate.keys.first;
        // Si le créneau sélectionné a disparu → le déselectionner
        if (_selectedSlotId != null && !raw.any((s) => s['_id'] == _selectedSlotId)) {
          _selectedSlotId    = null;
          _selectedSlotLabel = null;
          _error = 'Ce créneau vient d\'être pris. Choisis-en un autre.';
        }
      });
    } catch (_) {
      if (mounted) setState(() { _loadingSlots = false; });
    }
  }

  // Rafraîchissement silencieux (sans spinner) — vérifie si slot toujours dispo
  Future<void> _refreshSlots() async {
    if (!mounted || _sending) return;
    try {
      final proId = widget.professional['id'] ?? widget.professional['_id'];
      final data  = await ApiService().get('/professionals/$proId/slots');
      final raw   = List<Map<String, dynamic>>.from(data['slots'] ?? []);
      final byDate = <String, List<Map<String, dynamic>>>{};
      for (final s in raw) {
        final d = s['date']?.toString() ?? '';
        byDate.putIfAbsent(d, () => []).add(s);
      }
      if (!mounted) return;
      setState(() {
        _slots       = raw;
        _slotsByDate = byDate;
        _lastRefresh = DateTime.now();
        // Slot sélectionné pris entre-temps → alerte immédiate
        if (_selectedSlotId != null && !raw.any((s) => s['_id'] == _selectedSlotId)) {
          _selectedSlotId    = null;
          _selectedSlotLabel = null;
          _error = 'Le créneau sélectionné vient d\'être pris par un autre utilisateur. Choisis-en un autre.';
        }
      });
    } catch (_) { /* silencieux */ }
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const days   = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin', 'juil', 'aoû', 'sep', 'oct', 'nov', 'déc'];
      return '${days[d.weekday % 7]} ${d.day} ${months[d.month - 1]}';
    } catch (_) { return iso; }
  }

  Future<void> _submit() async {
    if (_selectedSlotId == null) {
      setState(() => _error = 'Sélectionne un créneau pour continuer.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      final proId = widget.professional['id'] ?? widget.professional['_id'];
      final body  = <String, dynamic>{
        'consultationType': _consultationType,
        'message': _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      };
      if (_selectedSlotId != null) body['slotId'] = _selectedSlotId;

      await ApiService().post('/professionals/$proId/book', body);
      if (mounted) {
        _refreshTimer?.cancel(); // plus besoin de rafraîchir
        Navigator.pop(context);
        widget.onBooked();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Demande envoyée ! Tu recevras un email de confirmation. ✅'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      // Créneau pris entre-temps → rafraîchir immédiatement + déselectionner
      if (e.message.contains('créneau') || e.message.contains('SLOT_CONFLICT') || e.message.contains('disponible')) {
        setState(() {
          _sending           = false;
          _selectedSlotId    = null;
          _selectedSlotLabel = null;
          _error = e.message;
        });
        await _loadSlots(); // recharger la liste fraîche
      } else {
        setState(() { _sending = false; _error = e.message; });
      }
    } catch (_) {
      setState(() { _sending = false; _error = 'Une erreur est survenue'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro      = widget.professional;
    final typeConf = _typeConfigDefault[pro['type']] ?? _typeConfigDefault['psychologist']!;
    final hasOnline = pro['isOnline'] == true;
    final hasInPerson = pro['isInPerson'] == true;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          Center(child: Container(width: 40, height: 4,
            decoration: const BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full))),
          const SizedBox(height: 14),

          // Header professionnel
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: typeConf.color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Text(typeConf.emoji, style: const TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pro['fullName'] ?? '', style: AppTextStyles.h4),
              Text(typeConf.label, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
          ]),
          const SizedBox(height: 4),
          const Divider(),

          // Corps scrollable
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Erreur ───────────────────────────────────────────────────
              if (_error != null) _ErrorBanner(message: _error!),

              // ── Canal ────────────────────────────────────────────────────
              if (hasOnline && hasInPerson) ...[
                const SizedBox(height: 4),
                _SectionLabel(label: 'Mode de consultation', icon: Icons.videocam_outlined),
                const SizedBox(height: 8),
                Row(children: [
                  _ConsultChip(
                    label: '🌐 En ligne', selected: _consultationType == 'online',
                    onTap: () => setState(() => _consultationType = 'online')),
                  const SizedBox(width: 10),
                  _ConsultChip(
                    label: '📍 Présentiel', selected: _consultationType == 'in_person',
                    onTap: () => setState(() => _consultationType = 'in_person')),
                ]),
              ] else ...[
                const SizedBox(height: 8),
                _InfoChip(
                  label: hasOnline ? '🌐 Consultation en ligne uniquement' : '📍 Consultation en présentiel uniquement',
                ),
              ],
              const SizedBox(height: 20),

              // ── Créneaux disponibles ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionLabel(label: 'Choisir un créneau', icon: Icons.calendar_month_outlined),
                  if (_lastRefresh != null)
                    GestureDetector(
                      onTap: _loadSlots,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.refresh, size: 13, color: AppColors.onSurfaceMuted),
                        const SizedBox(width: 3),
                        Text('Actualiser', style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
                      ]),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (_loadingSlots)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              else if (_slotsByDate.isEmpty)
                _NoSlotsBox()
              else ...[
                // Sélecteur de dates
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _slotsByDate.keys.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final date = _slotsByDate.keys.elementAt(i);
                      final isSelected = _selectedDate == date;
                      return GestureDetector(
                        onTap: () => setState(() { _selectedDate = date; _selectedSlotId = null; _selectedSlotLabel = null; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                            borderRadius: AppRadius.md,
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                          ),
                          child: Text(_fmtDate(date),
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected ? Colors.white : AppColors.onSurface,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Grille d'heures pour la date sélectionnée
                if (_selectedDate != null) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: (_slotsByDate[_selectedDate] ?? []).map((slot) {
                      final slotId    = slot['_id']?.toString() ?? '';
                      final isSelected = _selectedSlotId == slotId;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedSlotId    = slotId;
                          _selectedSlotLabel = '${_fmtDate(_selectedDate!)} à ${slot['startTime']}';
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.secondary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                            borderRadius: AppRadius.md,
                            border: Border.all(
                              color: isSelected ? AppColors.secondary : AppColors.divider,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text('${slot['startTime']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected ? AppColors.secondary : AppColors.onSurface,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            )),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Récap créneau sélectionné
                if (_selectedSlotLabel != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.md,
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('Créneau sélectionné : $_selectedSlotLabel',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // ── Message (optionnel) ───────────────────────────────────────
              _SectionLabel(label: 'Motif (optionnel)', icon: Icons.chat_bubble_outline),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl, maxLines: 3, minLines: 2, maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Ex: Je traverse une période difficile…',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),

              // Badge confidentialité + chiffrement
              _PrivacyBadge(),
              const SizedBox(height: 20),
            ]),
          )),

          // Bouton confirmer (sticky bas)
          Padding(
            padding: const EdgeInsets.only(bottom: 28, top: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmer le rendez-vous', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Edit Booking Sheet ────────────────────────────────────────────────────────
class _EditBookingSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Function(String?, String?, String?) onUpdate;
  const _EditBookingSheet({required this.booking, required this.onUpdate});
  @override
  State<_EditBookingSheet> createState() => _EditBookingSheetState();
}

class _EditBookingSheetState extends State<_EditBookingSheet> {
  final _messageCtrl = TextEditingController();
  String _consultationType = 'online';

  @override
  void initState() {
    super.initState();
    _messageCtrl.text   = widget.booking['message']?.toString() ?? '';
    _consultationType   = widget.booking['consultationType']?.toString() ?? 'online';
  }

  @override
  void dispose() { _messageCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pro      = widget.booking['professional'] as Map<String, dynamic>?;
    final typeConf = _typeConfigDefault[pro?['type']] ?? _typeConfigDefault['psychologist']!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: const BoxDecoration(color: AppColors.divider, borderRadius: AppRadius.full))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: typeConf.color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(child: Text(typeConf.emoji, style: const TextStyle(fontSize: 22)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pro?['fullName'] ?? 'Professionnel', style: AppTextStyles.h4),
              Text(typeConf.label, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
            ])),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20)),
          ]),
          const SizedBox(height: 20),
          const Text('Modifier ma demande', style: AppTextStyles.h3),
          const SizedBox(height: 20),
          _SectionLabel(label: 'Type de consultation', icon: Icons.videocam_outlined),
          const SizedBox(height: 8),
          Row(children: [
            _ConsultChip(label: '🌐 En ligne',    selected: _consultationType == 'online',    onTap: () => setState(() => _consultationType = 'online')),
            const SizedBox(width: 10),
            _ConsultChip(label: '📍 Présentiel', selected: _consultationType == 'in_person', onTap: () => setState(() => _consultationType = 'in_person')),
          ]),
          const SizedBox(height: 16),
          _SectionLabel(label: 'Motif (optionnel)', icon: Icons.chat_bubble_outline),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl, maxLines: 4, minLines: 3, maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Explique brièvement pourquoi tu souhaites consulter…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          _PrivacyBadge(),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              widget.onUpdate(
                _consultationType,
                null,
                _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Enregistrer les modifications'),
          )),
        ])),
      ),
    );
  }
}

// ─── Widgets helpers ──────────────────────────────────────────────────────────

class _ConsultChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ConsultChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceVariant,
        borderRadius: AppRadius.full,
        border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(
        color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      )),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: AppColors.primary),
    const SizedBox(width: 6),
    Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
  ]);
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.full),
    child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted)),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.08),
      borderRadius: AppRadius.md,
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.accent, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent))),
    ]),
  );
}

class _NoSlotsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.md),
    child: Column(children: [
      const Icon(Icons.calendar_today_outlined, size: 28, color: AppColors.onSurfaceMuted),
      const SizedBox(height: 8),
      Text('Aucun créneau disponible en ligne', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurfaceMuted)),
      const SizedBox(height: 4),
      Text('Ta demande sera traitée manuellement par l\'équipe LinkMind.',
        style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
        textAlign: TextAlign.center),
    ]),
  );
}

class _PrivacyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.05),
      borderRadius: AppRadius.md,
    ),
    child: Row(children: [
      const Icon(Icons.lock_outline, size: 14, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'Ton message est chiffré de bout en bout. Seule l\'équipe LinkMind y a accès pour traiter ta demande.',
        style: AppTextStyles.caption.copyWith(color: AppColors.primary, height: 1.4),
      )),
    ]),
  );
}