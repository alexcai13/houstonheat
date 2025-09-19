import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatGPTService {
  final String apiKey;

  ChatGPTService(this.apiKey);

  Future<String> getChatResponse(
    String message, {
    String? weatherContext,
    List<Map<String, String>>? chatHistory,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // You can add weather context to the system prompt for more relevant answers
    // Make weather context more prominent in system prompt
    final systemPrompt = weatherContext != null && weatherContext.isNotEmpty
      ? """You are a concise assistant specializing in weather and heat safety.
          CURRENT WEATHER: $weatherContext
          INSTRUCTIONS:
          - Give brief, complete answers
          - No lengthy explanations
          - Include current weather when relevant
          - Be direct and to the point
          - Never say you can't access weather data"""
      : "You are a concise assistant specializing in weather and heat safety. Give brief, complete answers.";
    print('Weather context: $weatherContext');
    final messages = <Map<String, String>>[
      {"role": "system", "content": systemPrompt},
      if (chatHistory != null) ...chatHistory,
      {"role": "user", "content": message}
    ];

    // ...then use messages in your API call body:
    final body = jsonEncode({
      "model": "openai/gpt-oss-120b",
      "messages": messages,
      "temperature": 0.7,
      "top_p": 0.9,      // Add this to encourage focused responses
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('Failed to get response: ${response.body}');
    }
  }

  Future<String> getChatTitle(List<Map<String, String>> chatHistory) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // Special system prompt for title generation
    const systemPrompt = "You are a helpful assistant. Summarize the following conversation in 3-5 words for a chat title. Only return the title, nothing else.";

    // Build messages: system prompt + chat history
    final messages = [
      {"role": "system", "content": systemPrompt},
      ...chatHistory,
      {"role": "user", "content": "Please generate a concise chat title."},
    ];

    final body = jsonEncode({
      "model": "openai/gpt-oss-120b",
      "messages": messages,
      "max_tokens": 512,
      "temperature": 0.2,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('Failed to get title: ${response.body}');
    }
  }
}