import 'package:equatable/equatable.dart';

/// Ticket Model
class Ticket extends Equatable {
  final String ticketId;
  final String userId;
  final String category;
  final String priority;
  final String status;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Alias for ticketId to maintain compatibility
  String get id => ticketId;
  
  /// Alias for title to maintain compatibility
  String get subject => title;

  const Ticket({
    required this.ticketId,
    required this.userId,
    required this.category,
    required this.priority,
    required this.status,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketId: json['ticketId'] as String,
      userId: json['userId'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticketId': ticketId,
      'userId': userId,
      'category': category,
      'priority': priority,
      'status': status,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        ticketId,
        userId,
        category,
        priority,
        status,
        title,
        description,
        createdAt,
        updatedAt,
      ];
}

/// Ticket State
enum TicketStatus {
  initial,
  loading,
  loaded,
  error,
}

class TicketState extends Equatable {
  final TicketStatus status;
  final List<Ticket> tickets;
  final String? error;

  const TicketState({
    this.status = TicketStatus.initial,
    this.tickets = const [],
    this.error,
  });

  bool get isLoading => status == TicketStatus.loading;
  bool get isLoaded => status == TicketStatus.loaded;

  TicketState copyWith({
    TicketStatus? status,
    List<Ticket>? tickets,
    String? error,
  }) {
    return TicketState(
      status: status ?? this.status,
      tickets: tickets ?? this.tickets,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, tickets, error];
}