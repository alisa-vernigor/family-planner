package com.allisyonok.family_planner

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Нативный BroadcastReceiver для обработки тапа по задаче в Home Widget.
 *
 * Вместо запуска тяжеловесного Flutter engine через WorkManager (который
 * часто блокируется на Android 12+ / OEM-прошивках), этот receiver напрямую
 * дёргает Supabase REST API — быстро и надёжно.
 *
 * Читает конфигурацию и сессию из SharedPreferences ("HomeWidgetPreferences"),
 * которые сохраняются Dart-кодом через HomeWidget.saveWidgetData в
 * [HomeWidgetService.initialize] и [HomeWidgetService.syncTasks].
 */
class TasksWidgetActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TasksWidgetAction"
        private const val ACTION_TOGGLE_TASK =
            "com.allisyonok.family_planner.action.TOGGLE_TASK"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun createPendingIntent(context: Context): android.app.PendingIntent {
            val intent = Intent(context, TasksWidgetActionReceiver::class.java).apply {
                action = ACTION_TOGGLE_TASK
            }
            var flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                flags = flags or android.app.PendingIntent.FLAG_IMMUTABLE
            }
            return android.app.PendingIntent.getBroadcast(context, 0, intent, flags)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE_TASK) return

        val uri = intent.data ?: run {
            Log.w(TAG, "No data URI in intent")
            return
        }

        if (uri.host != "task" || uri.path != "/toggle") {
            Log.w(TAG, "Unexpected URI: $uri")
            return
        }

        val taskId = uri.getQueryParameter("id") ?: return
        val currentStatus = uri.getQueryParameter("status")
        val householdId = uri.getQueryParameter("householdId") ?: return
        val memberId = uri.getQueryParameter("memberId") ?: return

        Log.d(TAG, "Toggle task: id=$taskId, status=$currentStatus")

        // goAsync() даёт до 10 секунд на фоновую работу в BroadcastReceiver
        val pendingResult = goAsync()
        Thread {
            try {
                handleToggle(context, taskId, currentStatus, householdId, memberId)
            } catch (e: Exception) {
                Log.e(TAG, "Error toggling task", e)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun handleToggle(
        context: Context,
        taskId: String,
        currentStatus: String?,
        householdId: String,
        memberId: String,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val supabaseUrl = prefs.getString("supabase_url", null)
        val supabaseKey = prefs.getString("supabase_key", null)
        val sessionJsonStr = prefs.getString("supabase_session_json", null)

        if (supabaseUrl == null || supabaseKey == null || sessionJsonStr == null) {
            Log.e(TAG, "Missing configuration in SharedPreferences")
            return
        }

        val sessionJson = JSONObject(sessionJsonStr)

        // Пробуем access_token. Если пришёл 401 — пробуем refresh_token.
        var accessToken = sessionJson.optString("access_token", null)
        var refreshToken = sessionJson.optString("refresh_token", null)

        if (accessToken.isNullOrEmpty()) {
            Log.e(TAG, "No access_token in session JSON")
            return
        }

        val isCompleted = currentStatus == "completed"

        // --- 1. Toggle задачи через Supabase REST API ---
        val patchPayload = JSONObject()
        if (isCompleted) {
            patchPayload.put("status", "pending")
            patchPayload.put("completed_by_member_id", JSONObject.NULL)
            patchPayload.put("completed_at", JSONObject.NULL)
        } else {
            patchPayload.put("status", "completed")
            patchPayload.put("completed_by_member_id", memberId)
            patchPayload.put("completed_at", iso8601Now())
            patchPayload.put("assigned_member_id", memberId)
        }

        var patchResponseCode = supabasePatch(
            supabaseUrl = supabaseUrl,
            supabaseKey = supabaseKey,
            accessToken = accessToken,
            table = "task_occurrences",
            id = taskId,
            payload = patchPayload,
        )

        // Если 401 — возможно, access_token протух. Пробуем refresh.
        if (patchResponseCode == 401 && !refreshToken.isNullOrEmpty()) {
            Log.d(TAG, "Access token expired, trying refresh...")

            val refreshed = supabaseRefreshToken(supabaseUrl, supabaseKey, refreshToken)
            if (refreshed != null) {
                val (newAccessToken, newRefreshToken) = refreshed
                accessToken = newAccessToken
                refreshToken = newRefreshToken

                // Обновляем SharedPreferences для следующих вызовов
                sessionJson.put("access_token", accessToken)
                if (refreshToken != null) {
                    sessionJson.put("refresh_token", refreshToken)
                }
                prefs.edit()
                    .putString("supabase_session_json", sessionJson.toString())
                    .apply()

                Log.d(TAG, "Token refreshed successfully, retrying PATCH")

                // Retry with new token
                patchResponseCode = supabasePatch(
                    supabaseUrl = supabaseUrl,
                    supabaseKey = supabaseKey,
                    accessToken = accessToken,
                    table = "task_occurrences",
                    id = taskId,
                    payload = patchPayload,
                )
            } else {
                Log.e(TAG, "Token refresh failed")
            }
        }

        if (patchResponseCode !in 200..299) {
            Log.e(TAG, "Supabase PATCH failed: HTTP $patchResponseCode")
            return
        }

        Log.d(TAG, "Task $taskId toggled successfully (HTTP $patchResponseCode)")

        // --- 2. Перезапрашиваем задачи на сегодня и обновляем SharedPreferences ---
        try {
            val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                .format(java.util.Date())
            val tasksJson = supabaseGet(
                supabaseUrl = supabaseUrl,
                supabaseKey = supabaseKey,
                accessToken = accessToken,
                table = "task_occurrences",
                query = "select=id,title,status,assigned_member_id&" +
                        "household_id=eq.$householdId&" +
                        "planned_for=eq.$dateStr",
            )

            if (tasksJson != null) {
                val allTasks = JSONArray(tasksJson)
                val myTasks = JSONArray()
                for (i in 0 until allTasks.length()) {
                    val task = allTasks.getJSONObject(i)
                    if (task.optString("assigned_member_id") == memberId) {
                        val t = JSONObject()
                        t.put("id", task.getString("id"))
                        t.put("title", task.getString("title"))
                        t.put("isCompleted", task.optString("status") == "completed")
                        t.put("householdId", householdId)
                        t.put("memberId", memberId)
                        myTasks.put(t)
                    }
                }

                Log.d(TAG, "Refreshed widget data: ${myTasks.length()} tasks")
                prefs.edit().putString("today_tasks", myTasks.toString()).apply()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to refresh widget data after toggle", e)
        }

        // --- 3. Триггерим обновление виджета ---
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TasksWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds.isNotEmpty()) {
                appWidgetManager.notifyAppWidgetViewDataChanged(
                    appWidgetIds, R.id.widget_list_view
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to trigger widget update", e)
        }
    }

    // ──────────────────────────────────────────────────
    //  Supabase REST API helpers
    // ──────────────────────────────────────────────────

    private fun supabasePatch(
        supabaseUrl: String,
        supabaseKey: String,
        accessToken: String,
        table: String,
        id: String,
        payload: JSONObject,
    ): Int {
        val url = URL("$supabaseUrl/rest/v1/$table?id=eq.$id")
        return httpCall("PATCH", url, supabaseKey, accessToken, payload.toString())
    }

    private fun supabaseRefreshToken(
        supabaseUrl: String,
        supabaseKey: String,
        refreshToken: String,
    ): Pair<String, String>? {
        val url = URL("$supabaseUrl/auth/v1/token?grant_type=refresh_token")
        val body = JSONObject().apply { put("refresh_token", refreshToken) }

        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.setRequestProperty("apikey", supabaseKey)
        connection.setRequestProperty("Content-Type", "application/json")
        connection.doOutput = true
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000

        return try {
            OutputStreamWriter(connection.outputStream).use { it.write(body.toString()) }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                Log.w(TAG, "Token refresh HTTP $responseCode")
                null
            } else {
                val response = BufferedReader(InputStreamReader(connection.inputStream)).readText()
                val json = JSONObject(response)
                val newAccessToken = json.getString("access_token")
                val newRefreshToken = json.optString("refresh_token", refreshToken)
                Pair(newAccessToken, newRefreshToken)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Token refresh error", e)
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun supabaseGet(
        supabaseUrl: String,
        supabaseKey: String,
        accessToken: String,
        table: String,
        query: String,
    ): String? {
        val url = URL("$supabaseUrl/rest/v1/$table?$query")
        return httpCallWithBody("GET", url, supabaseKey, accessToken)
    }

    // ──────────────────────────────────────────────────
    //  Low-level HTTP helpers
    // ──────────────────────────────────────────────────

    private fun httpCall(
        method: String,
        url: URL,
        apiKey: String,
        accessToken: String?,
        body: String? = null,
    ): Int {
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.setRequestProperty("apikey", apiKey)
        if (accessToken != null) {
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
        }
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Prefer", "return=minimal")
        connection.doOutput = body != null
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000

        return try {
            if (body != null) {
                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(body)
                    writer.flush()
                }
            }
            connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    private fun httpCallWithBody(
        method: String,
        url: URL,
        apiKey: String,
        accessToken: String?,
    ): String? {
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.setRequestProperty("apikey", apiKey)
        if (accessToken != null) {
            connection.setRequestProperty("Authorization", "Bearer $accessToken")
        }
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000

        return try {
            val responseCode = connection.responseCode
            if (responseCode !in 200..299) null
            else BufferedReader(InputStreamReader(connection.inputStream)).use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun iso8601Now(): String {
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date())
    }
}
