import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api.service.dart';

class ProfessionalsState {
  final bool isLoadingPros;
  final bool isPaginating;
  final List<Map<String, dynamic>> professionals;
  final int page;
  final bool hasMore;
  
  final bool isLoadingBookings;
  final List<Map<String, dynamic>> bookings;
  
  final String? error;

  ProfessionalsState({
    this.isLoadingPros = true,
    this.isPaginating = false,
    this.professionals = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingBookings = true,
    this.bookings = const [],
    this.error,
  });

  ProfessionalsState copyWith({
    bool? isLoadingPros, bool? isPaginating, List<Map<String, dynamic>>? professionals,
    int? page, bool? hasMore, bool? isLoadingBookings, 
    List<Map<String, dynamic>>? bookings, String? error,
  }) {
    return ProfessionalsState(
      isLoadingPros: isLoadingPros ?? this.isLoadingPros,
      isPaginating: isPaginating ?? this.isPaginating,
      professionals: professionals ?? this.professionals,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingBookings: isLoadingBookings ?? this.isLoadingBookings,
      bookings: bookings ?? this.bookings,
      error: error,
    );
  }
}

class ProfessionalsNotifier extends StateNotifier<ProfessionalsState> {
  final ApiService _api = ApiService();
  String _currentSearch = '';
  String _currentType = 'all';
  String _currentCity = '';

  ProfessionalsNotifier() : super(ProfessionalsState()) {
    loadProfessionals();
    loadBookings();
  }

  String _buildQuery(int page) {
    final params = <String, String>{
      'page': '$page',
      'limit': '20',
    };
    if (_currentSearch.isNotEmpty) params['search'] = _currentSearch;
    if (_currentType != 'all') params['type'] = _currentType;
    if (_currentCity.isNotEmpty) params['city'] = _currentCity;

    final query = params.entries.map((e) =>
        '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}'
    ).join('&');
    return '/professionals?$query';
  }

  Future<void> loadProfessionals({String? search, String? type, String? city, bool forceRefresh = false}) async {
    if (search != null) _currentSearch = search;
    if (type != null) _currentType = type;
    if (city != null) _currentCity = city;
    if (forceRefresh) _api.invalidateCache('/professionals');

    state = state.copyWith(isLoadingPros: true, page: 1, error: null);
    try {
      final data = await _api.get(_buildQuery(1));
      final pros = List<Map<String, dynamic>>.from(data['professionals'] ?? []);
      debugPrint('📋 [Bookings] loadProfessionals: ${pros.length} pros loaded');
      state = state.copyWith(
        isLoadingPros: false,
        professionals: pros,
        hasMore: pros.length == 20,
      );
    } catch (e) {
      debugPrint('❌ [Bookings] loadProfessionals error: $e');
      state = state.copyWith(isLoadingPros: false, error: "Impossible de charger les professionnels.");
    }
  }

  Future<void> loadMoreProfessionals() async {
    if (!state.hasMore || state.isPaginating || state.isLoadingPros) return;
    
    state = state.copyWith(isPaginating: true);
    final nextPage = state.page + 1;
    
    try {
      final data = await _api.get(_buildQuery(nextPage));
      final newPros = List<Map<String, dynamic>>.from(data['professionals'] ?? []);
      
      state = state.copyWith(
        isPaginating: false,
        page: nextPage,
        professionals: [...state.professionals, ...newPros],
        hasMore: newPros.length == 20,
      );
    } catch (e) {
      state = state.copyWith(isPaginating: false);
    }
  }

  Future<void> loadBookings({bool forceRefresh = false}) async {
    if (forceRefresh) _api.invalidateCache('/professionals/bookings');
    state = state.copyWith(isLoadingBookings: true);
    try {
      final data = await _api.get('/professionals/bookings/me');
      final bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
      
      debugPrint('📋 [Bookings] loadBookings: ${bookings.length} bookings');
      for (final b in bookings) {
        final status = b['status'] ?? 'unknown';
        final feedback = b['userFeedback'];
        final id = b['_id'] ?? b['id'] ?? '?';
        debugPrint('  → booking $id | status=$status | userFeedback=${feedback != null ? "present(attended=${feedback['attended']})" : "null"}');
      }
      
      state = state.copyWith(
        isLoadingBookings: false,
        bookings: bookings,
      );
    } catch (e) {
      debugPrint('❌ [Bookings] loadBookings error: $e');
      state = state.copyWith(isLoadingBookings: false);
    }
  }
}

final professionalsProvider = StateNotifierProvider<ProfessionalsNotifier, ProfessionalsState>(
  (ref) => ProfessionalsNotifier(),
);