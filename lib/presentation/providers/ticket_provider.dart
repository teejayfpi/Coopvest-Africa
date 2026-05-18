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
        '/tickets',
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

  /// Create a new support ticket
  Future<Ticket> createTicket({
    required String subject,
    required String message,
    String? category,
    String? priority,
  }) async {
    try {
      final response = await _apiClient.post(
        '/tickets',
        data: {
          'subject': subject,
          'message': message,
          if (category != null) 'category': category,
          if (priority != null) 'priority': priority,
        },
      );

      if (response['success'] == true) {
        return Ticket.fromJson(response['ticket'] as Map<String, dynamic>);
      } else {
        throw Exception(response['error'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      logger.e('Create ticket error: $e');
      rethrow;
    }
  }

  /// Reply to an existing ticket
  Future<void> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    try {
      final response = await _apiClient.post(
        '/tickets/$ticketId/replies',
        data: {'message': message},
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to send reply');
      }
    } catch (e) {
      logger.e('Reply to ticket error: $e');
      rethrow;
    }
  }

  /// Close a ticket
  Future<void> closeTicket(String ticketId) async {
    try {
      final response = await _apiClient.patch(
        '/tickets/$ticketId',
        data: {'status': 'closed'},
      );

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to close ticket');
      }
    } catch (e) {
      logger.e('Close ticket error: $e');
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

  /// Create a new ticket
  Future<Ticket?> createTicket({
    required String subject,
    required String message,
    String? category,
    String? priority,
  }) async {
    state = state.copyWith(status: TicketStatus.loading);
    try {
      final ticket = await _ticketRepository.createTicket(
        subject: subject,
        message: message,
        category: category,
        priority: priority,
      );
      state = state.copyWith(
        status: TicketStatus.loaded,
        tickets: [ticket, ...state.tickets],
      );
      return ticket;
    } catch (e) {
      logger.e('Create ticket error: $e');
      state = state.copyWith(
        status: TicketStatus.error,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Reply to a ticket
  Future<bool> replyToTicket({
    required String ticketId,
    required String message,
  }) async {
    try {
      await _ticketRepository.replyToTicket(ticketId: ticketId, message: message);
      await loadTickets();
      return true;
    } catch (e) {
      logger.e('Reply to ticket error: $e');
      state = state.copyWith(
        status: TicketStatus.error,
        error: e.toString(),
      );
      return false;
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
