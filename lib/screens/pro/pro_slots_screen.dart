import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/theme.dart';
import '../../services/pro_api.service.dart';

class ProSlotsScreen extends StatefulWidget {
  const ProSlotsScreen({super.key});

  @override
  State<ProSlotsScreen> createState() => _ProSlotsScreenState();
}

class _ProSlotsScreenState extends State<ProSlotsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _slots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // `silent` évite le flash plein écran du spinner quand le rechargement
  // suit directement une action locale (ajout/suppression) — l'utilisateur
  // vient déjà de voir son action, pas besoin de repasser par un écran vide.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      if (!await ProApiService().isLoggedIn()) {
        if (mounted) context.go('/pro/login');
        return;
      }
      setState(() { _isLoading = true; _error = null; });
    }
    try {
      final me = await ProApiService().getMe();
      final slots = List<dynamic>.from(me['professional']?['availableSlots'] ?? []);
      // Tri par date puis heure, les plus proches en premier
      slots.sort((a, b) {
        final da = '${a['date']}_${a['startTime']}';
        final db = '${b['date']}_${b['startTime']}';
        return da.compareTo(db);
      });
      if (mounted) setState(() { _slots = slots; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!silent) _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addSlot() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final startTime = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (startTime == null || !mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startTime.hour + 1, minute: startTime.minute),
    );
    if (endTime == null) return;

    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr = '${date.year}-${two(date.month)}-${two(date.day)}';
    final startStr = '${two(startTime.hour)}:${two(startTime.minute)}';
    final endStr = '${two(endTime.hour)}:${two(endTime.minute)}';

    try {
      await ProApiService().addSlot(date: dateStr, startTime: startStr, endTime: endStr);
      _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _deleteSlot(String slotId, bool isBooked) async {
    if (isBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce créneau est réservé — annule d\'abord le rendez-vous concerné.')),
      );
      return;
    }
    try {
      await ProApiService().deleteSlot(slotId);
      _load(silent: true);
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mes créneaux', style: AppTextStyles.h3),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                  : _slots.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Aucun créneau disponible pour l\'instant.\nAjoute-en un avec le bouton ci-dessous.',
                                style: AppTextStyles.body.copyWith(color: AppColors.onSurfaceMuted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _slots.length,
                          itemBuilder: (context, index) {
                            final slot = _slots[index] as Map<String, dynamic>;
                            final isBooked = slot['isBooked'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.md,
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isBooked ? Icons.event_busy_outlined : Icons.event_available_outlined,
                                    color: isBooked ? AppColors.accentOrange : AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${slot['date']}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                                        Text(
                                          '${slot['startTime']} – ${slot['endTime']}${isBooked ? ' · Réservé' : ' · Disponible'}',
                                          style: AppTextStyles.caption.copyWith(color: AppColors.onSurfaceMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isBooked)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.onSurfaceMuted, size: 20),
                                      onPressed: () => _deleteSlot(slot['_id'] as String, isBooked),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un créneau', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
