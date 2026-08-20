import 'package:flutter/material.dart';

class SupportMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'user' | 'partner' | 'admin'
  final String text;
  final String timestamp;

  SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'timestamp': timestamp,
    };
  }

  factory SupportMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return SupportMessage(
      id: map['id']?.toString() ?? id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? 'Support Agent',
      senderRole: map['senderRole']?.toString() ?? 'user',
      text: map['text']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userPhone;
  final String userRole; // 'user' | 'partner'
  final String subject;
  final String description;
  final String category; // 'booking' | 'payment' | 'space' | 'account' | 'general'
  final String status; // 'open' | 'in_progress' | 'resolved' | 'closed'
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final String createdAt;
  final String? updatedAt;
  final String? resolutionNotes;
  final String? lastMessage;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    this.userRole = 'user',
    required this.subject,
    required this.description,
    this.category = 'general',
    this.status = 'open',
    this.priority = 'medium',
    required this.createdAt,
    this.updatedAt,
    this.resolutionNotes,
    this.lastMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      if (userEmail != null) 'userEmail': userEmail,
      if (userPhone != null) 'userPhone': userPhone,
      'userRole': userRole,
      'subject': subject,
      'description': description,
      'category': category,
      'status': status,
      'priority': priority,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
      if (lastMessage != null) 'lastMessage': lastMessage,
    };
  }

  factory SupportTicket.fromMap(String id, Map<dynamic, dynamic> map) {
    return SupportTicket(
      id: map['id']?.toString() ?? id,
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'Customer',
      userEmail: map['userEmail']?.toString(),
      userPhone: map['userPhone']?.toString(),
      userRole: map['userRole']?.toString() ?? 'user',
      subject: map['subject']?.toString() ?? 'Support Request',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      status: map['status']?.toString() ?? 'open',
      priority: map['priority']?.toString() ?? 'medium',
      createdAt: map['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt']?.toString(),
      resolutionNotes: map['resolutionNotes']?.toString(),
      lastMessage: map['lastMessage']?.toString(),
    );
  }

  Color get statusColor {
    switch (status) {
      case 'open':
        return const Color(0xFF3B82F6); // Blue
      case 'in_progress':
        return const Color(0xFFF59E0B); // Amber
      case 'resolved':
        return const Color(0xFF10B981); // Green
      case 'closed':
        return const Color(0xFF6B7280); // Gray
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status.toUpperCase();
    }
  }
}
