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

    final systemPrompt = weatherContext != null && weatherContext.isNotEmpty
      ? """You are a concise assistant specializing in weather and heat safety.
          You have access to the following CURRENT WEATHER data (for internal use only):
          $weatherContext

          IMPORTANT GUIDELINES:
          - Do NOT mention or summarize the weather data unless the user asks about weather or the user explicitly references it.
          - If the user asks about weather, use the provided data to answer succinctly and accurately.
          - Give brief, helpful answers; avoid unsolicited weather details.
          - Be direct and to the point.
          """
      : "You are a concise assistant specializing in weather and heat safety. Give brief, complete answers.";
    print('Weather context: $weatherContext');
    final messages = <Map<String, String>>[
      {"role": "system", "content": systemPrompt},
      if (chatHistory != null) ...chatHistory,
      {"role": "user", "content": message}
    ];

    final body = jsonEncode({
      "model": "openai/gpt-oss-120b",
      "messages": messages,
      "temperature": 0.7,
      "top_p": 0.9,
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

    const systemPrompt = "You are a helpful assistant. Summarize the following conversation in 3-5 words for a chat title. Only return the title, nothing else.";

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

  Future<String> getWeatherSummary({
    required double currentTemp,
    required double feelsLike,
    required String condition,
    required String cityName,
    List<Map<String, dynamic>>? hourlyForecast,
    List<Map<String, dynamic>>? dailyForecast,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    String weatherContext = """Current weather in $cityName:
    - Temperature: ${currentTemp.toStringAsFixed(0)}°F
    - Feels like: ${feelsLike.toStringAsFixed(0)}°F
    - Condition: $condition""";

    if (hourlyForecast != null && hourlyForecast.isNotEmpty) {
      weatherContext += "\n\nNext few hours:";
      for (var i = 0; i < hourlyForecast.length && i < 6; i++) {
        final hour = hourlyForecast[i];
        weatherContext += "\n- ${hour['time']}: ${hour['temp'].toStringAsFixed(0)}°F, feels like ${hour['feels'].toStringAsFixed(0)}°F, ${hour['condition']}";
      }
    }

    if (dailyForecast != null && dailyForecast.isNotEmpty) {
      weatherContext += "\n\nToday's forecast:";
      final today = dailyForecast[0];
      weatherContext += "\n- High: ${today['high'].toStringAsFixed(0)}°F, Low: ${today['low'].toStringAsFixed(0)}°F";
      weatherContext += "\n- Condition: ${today['condition']}";
      weatherContext += "\n- Precipitation chance: ${today['precipitationChance']}%";
    }

    const systemPrompt = """You are a friendly weather assistant. Generate a single conversational sentence (max 20 words) giving practical advice and suggestions for the day based on the weather. 

    Examples:
    - "Expect muggy air this afternoon — it's a good day for indoor plans until after 6 p.m."
    - "Not a good day to bike — high ozone alert at 3 PM."
    - "Great time to walk the dog around 7 PM when the breeze picks up."

    Be concise, friendly, and actionable. Only return the single sentence, nothing else.""";

    final messages = [
      {"role": "system", "content": systemPrompt},
      {"role": "user", "content": "Based on this weather data, give me a one-sentence summary:\n\n$weatherContext"},
    ];

    final body = jsonEncode({
      "model": "openai/gpt-oss-120b",
      "messages": messages,
      "max_tokens": 400,
      "temperature": 0.8,
    });

    final response = await http.post(url, headers: headers, body: body);
    
    print('Weather summary API response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('Weather summary API error body: ${response.body}');
    }
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final summary = data['choices'][0]['message']['content'].trim().replaceAll('"', '');
      print('Weather summary generated: $summary');
      return summary;
    } else {
      throw Exception('Failed to get weather summary: ${response.body}');
    }
  }
}