import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/proxyapi_config.dart';

final class AITaskResult {
  const AITaskResult({
    required this.title,
    this.description,
    this.plannedFor,
    this.durationMinutes,
  });

  final String title;
  final String? description;
  final DateTime? plannedFor;
  final int? durationMinutes;

  factory AITaskResult.fromJson(Map<String, dynamic> json) {
    return AITaskResult(
      title: json['title'] as String? ?? 'Новая задача',
      description: json['description'] as String?,
      plannedFor: json['plannedFor'] != null ? DateTime.tryParse(json['plannedFor'] as String) : null,
      durationMinutes: json['durationMinutes'] as int?,
    );
  }
}

final class AITaskService {
  static const _transcribeUrl = 'https://api.proxyapi.ru/openai/v1/audio/transcriptions';
  static const _geminiUrl = 'https://api.proxyapi.ru/google/v1beta/models/gemini-3.5-flash-lite:generateContent';

  /// 1. Переводит аудио в текст с помощью OpenAI API через ProxyAPI
  Future<String> transcribeAudio(String filePath) async {
    final apiKey = ProxyApiConfig.apiKey;
    if (apiKey.isEmpty) throw Exception('PROXYAPI_KEY не задан');

    final request = http.MultipartRequest('POST', Uri.parse(_transcribeUrl));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = 'gpt-4o-mini-transcribe';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Ошибка транскрибации: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['text'] as String;
  }

  /// 2. Парсит текст в структуру задачи с помощью Gemini API через ProxyAPI
  Future<AITaskResult> parseTaskFromText(String text) async {
    final apiKey = ProxyApiConfig.apiKey;
    if (apiKey.isEmpty) throw Exception('PROXYAPI_KEY не задан');

    final now = DateTime.now();
    final prompt = '''
Текущая дата и время: ${now.toIso8601String()}

Пользователь продиктовал задачу: "$text"

Твоя цель: извлечь детали задачи и вернуть ТОЛЬКО валидный JSON (без маркдауна и лишних символов).
Структура JSON:
{
  "title": "Краткое название задачи",
  "description": "Дополнительные детали, если есть (иначе null)",
  "plannedFor": "Дата в формате ISO 8601, на которую запланирована задача (вычисли относительно текущей даты, например 'завтра' = дата завтрашнего дня. Если время не указано, поставь текущее время или 12:00)",
  "durationMinutes": 30 (число в минутах, если пользователь сказал 'на 2 часа', верни 120, иначе null)
}
''';

    final response = await http.post(
      Uri.parse(_geminiUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка Gemini API: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    String rawText = data['candidates'][0]['content']['parts'][0]['text'];

    // Очистка от маркдауна, если модель его вернула
    rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

    return AITaskResult.fromJson(jsonDecode(rawText));
  }
}