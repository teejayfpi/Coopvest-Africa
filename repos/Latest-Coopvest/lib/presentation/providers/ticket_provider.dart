import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../../data/models/ticket_models.dart';

/// Ticket Repository Provider
final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TicketRepository(apiClient);
});

/// Ticket Repository
class TicketRepository {
  final ApiClient _apiClient;

  TicketRepository(this._apiClient);

  /// Get user's tickets
  Future<List<Ticket>> getTickets({
    String? status,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/tickets',
        queryParameters: {
          if (status != null) 'status': status,
          if (category != null) 'category': category,
          'page': page,
          'limit': limit,
        },
      );

      if (response['success'] == true) {
        final List<dynamic> ticketsJson = response['tickets'] ?? [];
        return ticketsJson.map((json) => Ticket.fromJson(json)).toList();
      } else {
        throw Exception(response['error'] ?? 'Failed to load tickets');
      }
    } catch (e) {
      logger.e('Get tickets error: $e');
      rethrow;
    }
  }
}

/// Ticket Notifier
class TicketNotifier extends StateNotifier<TicketState> {
  final TicketRepository _ticketRepository;

  TicketNotifier(this._ticketRepository) : super(const TicketState());

  /// Load tickets
  Future<void> loadTickets() async {
    state = state.copyWith(status: TicketStatus.loading);
    try {
      final tickets = await _ticketRepository.getTickets();
      state = state.copyWith(
        status: TicketStatus.loaded,
        tickets: tickets,
      );
    } catch (e) {
      logger.e('Load tickets error: $e');
      state = state.copyWith(
        status: TicketStatus.error,
        error: e.toString(),
      );
    }
  }
}

/// Ticket Provider
final ticketProvider = StateNotifierProvider<TicketNotifier, TicketState>((ref) {
  final ticketRepository = ref.watch(ticketRepositoryProvider);
  return TicketNotifier(ticketRepository);
});

/// User's tickets provider
final userTicketsProvider = Provider<List<Ticket>>((ref) {
  final ticketState = ref.watch(ticketProvider);
  return ticketState.tickets;
});
