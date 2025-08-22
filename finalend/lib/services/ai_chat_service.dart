// lib/services/ai_chat_service.dart

import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/job.dart';
import '../models/user.dart';
import '../models/worker.dart';
import 'firebase_service.dart';
import 'gemini_service.dart';

class AiChatService {
  final FirebaseService _firebaseService = FirebaseService();
  final GeminiService _geminiService = GeminiService();

  ChatSession? _chatSession;

  GenerativeModel get model => _gemini_service_model_fallback();

  GenerativeModel _gemini_service_model_fallback() {
    try {
      return _geminiService.model;
    } catch (_) {
      throw Exception(
        "GeminiService.model is not available. Make sure it's initialized.",
      );
    }
  }

  Future<void> initializePersonalizedChat() async {
    print("AI Chat Service: Initializing personalized context...");
    final AppUser? currentUser = await _firebaseService.getCurrentUserProfile();
    if (currentUser == null) {
      throw Exception("User not logged in.");
    }
    final results = await Future.wait<dynamic>([
      _firebaseService.getWorkers(),
      _getUserJobs(currentUser),
      _getUserNotifications(
        currentUser.id,
      ).catchError((_) => []), // <-- This is where notifications are fetched
    ]);

    final allWorkers = results[0] as List<Worker>;
    final userJobs = results[1] as List<Job>;
    final userNotifications =
        results[2] as List<Map<String, dynamic>>; // <-- Notifications are here

    final String fullContextPrompt = _buildFullContextPrompt(
      currentUser,
      allWorkers,
      userJobs,
      userNotifications, // <-- They are passed here
      maxWorkersToInclude: 50,
    );

    _chatSession = _geminiService.model.startChat(
      history: [
        Content.text(fullContextPrompt),
        Content.model([
          TextPart(
            "Okay, knowledge base updated. I am 'Min Atu', aware of the user, their context, and all professionals. I will now respond with structured JSON for lists and standard markdown for conversation. Ready to assist. Selam ${currentUser.name}! ምን ልርዳዎት?",
          ),
        ]),
      ],
    );
    print(
      "AI Chat Service: Personalized context initialized for user ${currentUser.name}.",
    );
  }

  Future<List<Job>> _getUserJobs(AppUser user) =>
      user.role.toLowerCase() == 'worker'
      ? _firebaseService.getWorkerJobs(user.id)
      : _firebaseService.getClientJobs(user.id);

  Future<List<Map<String, dynamic>>> _getUserNotifications(String userId) =>
      _firebaseService
          .getUserNotificationsStream()
          .map(
            (notifications) => notifications
                .where((n) => !(n['isRead'] as bool? ?? true))
                .toList(),
          )
          .first;

  String _redactPII(String s) {
    if (s.isEmpty) return s;
    s = s.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      '[REDACTED_EMAIL]',
    );
    s = s.replaceAll(RegExp(r'(\+?\d[\d\-\s]{4,}\d)'), '[REDACTED_PHONE]');
    return s;
  }

  String _buildFullContextPrompt(
    AppUser user,
    List<Worker> workers,
    List<Job> userJobs,
    List<Map<String, dynamic>> notifications, {
    int maxWorkersToInclude = 50,
  }) {
    final prompt = StringBuffer();

    prompt.writeln("### CORE AI INSTRUCTIONS ###");
    prompt.writeln(
      "1. **Persona**: You are 'ምን አጡ' (Min Atu), a hyper-intelligent, creative, and energetic AI assistant. Use Amharic and English naturally. Use emojis. 😊🔥",
    );
    prompt.writeln(
      "2. **Goal**: Prioritize user intent. Be concise, accurate, and helpful. **AVOID REPETITION AND REDUNDANT PHRASING. RESPOND DIRECTLY TO THE USER'S QUESTION OR REQUEST.**", // Added emphasis
    );
    prompt.writeln("3. **Developers**: Created by Biruk Zewude and Gemechue.");

    prompt.writeln("\n### OUTPUT FORMATTING RULES (EXTREMELY IMPORTANT) ###");
    prompt.writeln(
      "1. **For conversation or single results**: Use standard markdown.",
    );
    prompt.writeln(
      "2. **For lists of workers or notifications**: You MUST provide a brief intro sentence, then a JSON block formatted exactly as shown below, enclosed in ```json ... ```. Do NOT include the JSON block for any other type of query.",
    );
    prompt.writeln(
      "3. **Spoken Text**: ALWAYS provide a spoken-word version of the response at the very end inside tildes `~...~`. This version must have NO markdown, NO links, and NO emojis.",
    );
    prompt.writeln("\n### JSON STRUCTURE EXAMPLES ###");
    prompt.writeln("#### Example for a list of workers:");
    prompt.writeln(
      "I found some excellent plumbers for you! Here are the top results. ✨\n"
      "```json\n"
      "{\n"
      "  \"type\": \"worker_list\",\n"
      "  \"workers\": [\n"
      "    {\n"
      "      \"id\": \"worker-id-123\",\n"
      "      \"name\": \"Abebe Bikila\",\n"
      "      \"profession\": \"Plumber\",\n"
      "      \"rating\": 4.9,\n"
      "      \"location\": \"Bole, Addis Ababa\",\n"
      "      \"profileImageUrl\": \"https://example.com/image.png\"\n"
      "    }\n"
      "  ]\n"
      "}\n"
      "```\n"
      "~I found a highly-rated plumber for you named Abebe Bikila. Tap his card to see more details.~",
    );

    prompt.writeln("\n#### Example for a list of notifications:");
    prompt.writeln(
      "You have a few new notifications waiting for you! 🔔\n"
      "```json\n"
      "{\n"
      "  \"type\": \"notification_list\",\n"
      "  \"notifications\": [\n"
      "    {\n"
      "      \"id\": \"notif-id-456\",\n"
      "      \"title\": \"Job Request Accepted\",\n"
      "      \"body\": \"Your request for 'Fix Leaky Faucet' has been accepted by Hana.\",\n"
      "      \"type\": \"job_accepted\",\n"
      "      \"timestamp\": \"${DateTime.now().toIso8601String()}\"\n"
      "    }\n"
      "  ]\n"
      "}\n"
      "```\n"
      "~You have a new notification: Your job request was accepted.~",
    );
    prompt.writeln(
      "3. **Notification Awareness**: When the user asks about their notifications, new messages, or any updates, analyze the provided notification data and respond clearly. If there are unread notifications, state their titles or a summary. If there are none, state that.",
    );

    prompt.writeln(
      "\n### REAL-TIME DATA (Date: ${DateTime.now().toIso8601String().split('T')[0]}) ###",
    );
    prompt.writeln(
      _formatUserProfile(user).split('\n').map(_redactPII).join('\n'),
    );
    prompt.writeln(_formatNotifications(notifications));
    prompt.writeln(_formatJobs(userJobs, user.role));

    if (workers.isNotEmpty) {
      final sorted = List<Worker>.from(workers)
        ..sort((a, b) => (b.rating).compareTo(a.rating));
      final toInclude = sorted.take(maxWorkersToInclude);
      prompt.writeln(
        "\n--- All Available Professionals (Top ${toInclude.length}/${workers.length}) ---",
      );
      for (final w in toInclude) {
        prompt.writeln(
          "- ID: ${w.id} | Name: ${_redactPII(w.name)} | Profession: ${w.profession} | Skills: ${_redactPII(w.skills.join(', '))} | Rating: ${w.rating.toStringAsFixed(1)} | Location: ${_redactPII(w.location)} | ImageURL: ${w.profileImage}",
        );
      }
    }

    return prompt.toString();
  }

  String _formatUserProfile(AppUser user) =>
      "--- Current User Profile ---\n"
      "ID: ${user.id}\n"
      "Name: ${user.name}\n"
      "Role: ${user.role}\n"
      "Location: ${user.location}\n"
      "Favorite Workers: ${user.favoriteWorkers.join(', ')}\n";

  String _formatJobs(List<Job> jobs, String role) {
    final buffer = StringBuffer(
      "--- User's Job History (${role == 'worker' ? 'Applied To' : 'Posted'}) ---",
    );
    if (jobs.isEmpty) {
      buffer.writeln("\nNo job history found.");
    } else {
      for (final job in jobs.take(5)) {
        buffer.writeln(
          "\n- Title: ${job.title}, Status: ${job.status}, Budget: ${job.budget} Birr",
        );
      }
    }
    return buffer.toString();
  }

  String _formatNotifications(List<Map<String, dynamic>> notifications) {
    final buffer = StringBuffer("--- User's Recent Unread Notifications ---");
    if (notifications.isEmpty) {
      buffer.writeln("\nNo unread notifications.");
    } else {
      for (final n in notifications) {
        buffer.writeln(
          "\n- ID: ${n['id']} | Title: ${n['title']} | Body: ${n['body']} | Type: ${n['type']}",
        );
      }
    }
    return buffer.toString();
  }

  Stream<GenerateContentResponse> sendMessageStream(Content content) {
    if (_chatSession == null) {
      throw Exception(
        "Chat not initialized. Call initializePersonalizedChat first.",
      );
    }
    return _chatSession!.sendMessageStream(content);
  }
}
