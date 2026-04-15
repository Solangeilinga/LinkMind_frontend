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

  ProfessionalsNotifier() : super(ProfessionalsState()) {
    loadProfessionals();
    loadBookings();
  }

  Future<void> loadProfessionals({String? search, String? type}) async {
    if (search != null) _currentSearch = search;
    if (type != null) _currentType = type;

    state = state.copyWith(isLoadingPros: true, page: 1, error: null);
    try {
      final typeQuery = _currentType == 'all' ? '' : '&type=$_currentType';
      final data = await _api.get('/professionals?search=$_currentSearch$typeQuery&page=1&limit=20');
      final pros = List<Map<String, dynamic>>.from(data['professionals'] ?? []);
      
      state = state.copyWith(
        isLoadingPros: false,
        professionals: pros,
        hasMore: pros.length == 20,
      );
    } catch (e) {
      state = state.copyWith(isLoadingPros: false, error: "Impossible de charger les professionnels.");
    }
  }

  Future<void> loadMoreProfessionals() async {
    if (!state.hasMore || state.isPaginating || state.isLoadingPros) return;
    
    state = state.copyWith(isPaginating: true);
    final nextPage = state.page + 1;
    
    try {
      final typeQuery = _currentType == 'all' ? '' : '&type=$_currentType';
      final data = await _api.get('/professionals?search=$_currentSearch$typeQuery&page=$nextPage&limit=20');
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

  Future<void> loadBookings() async {
    state = state.copyWith(isLoadingBookings: true);
    try {
      final data = await _api.get('/professionals/bookings/me');
      state = state.copyWith(
        isLoadingBookings: false,
        bookings: List<Map<String, dynamic>>.from(data['bookings'] ?? []),
      );
    } catch (e) {
      state = state.copyWith(isLoadingBookings: false);
    }
  }
}

final professionalsProvider = StateNotifierProvider<ProfessionalsNotifier, ProfessionalsState>(
  (ref) => ProfessionalsNotifier(),
);