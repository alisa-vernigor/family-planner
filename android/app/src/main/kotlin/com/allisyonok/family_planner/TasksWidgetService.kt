package com.allisyonok.family_planner

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONException

class TasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TasksRemoteViewsFactory(this.applicationContext)
    }
}

class TasksRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val tasksJson = prefs.getString("today_tasks", "[]")
        try {
            tasks = JSONArray(tasksJson)
        } catch (e: JSONException) {
            tasks = JSONArray()
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int = tasks.length()

    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks.getJSONObject(position)
        val id = task.getString("id")
        val title = task.getString("title")
        val isCompleted = task.getBoolean("isCompleted")
        val householdId = task.getString("householdId")
        val memberId = task.getString("memberId")

        val rv = RemoteViews(context.packageName, R.layout.tasks_widget_item)
        rv.setTextViewText(R.id.task_title, title)

        if (isCompleted) {
            rv.setTextViewText(R.id.task_checkbox, "☑")
            rv.setTextColor(R.id.task_checkbox, context.getColor(R.color.checkbox_checked))
            rv.setTextColor(R.id.task_title, context.getColor(R.color.task_title_completed))
        } else {
            rv.setTextViewText(R.id.task_checkbox, "☐")
            rv.setTextColor(R.id.task_checkbox, context.getColor(R.color.checkbox_unchecked))
            rv.setTextColor(R.id.task_title, context.getColor(R.color.task_title))
        }

        val fillInIntent = Intent().apply {
            data = Uri.parse("familyplanner://task/toggle?id=$id&status=${if (isCompleted) "completed" else "pending"}&householdId=$householdId&memberId=$memberId")
        }
        rv.setOnClickFillInIntent(R.id.task_checkbox, fillInIntent)
        rv.setOnClickFillInIntent(R.id.task_title, fillInIntent)

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}