package com.arcglow.arc_reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class SourceFileNavigator(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "arc_reader/source_file")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in listOf("retain", "openLocation")) {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val uri = Uri.parse(call.argument<String>("uri") ?: "")
                        require(uri.scheme == "content" && !uri.authority.isNullOrEmpty())
                        if (call.method == "retain") {
                            val retained = try {
                                activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                true
                            } catch (_: SecurityException) { false }
                            main.post { result.success(retained) }
                        } else if (Build.VERSION.SDK_INT < 26) {
                            main.post { result.error("UNSUPPORTED", "此设备系统不支持定位原文件目录。", null) }
                        } else {
                            validateSource(uri)
                            main.post {
                                try {
                                    activity.startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                        addCategory(Intent.CATEGORY_OPENABLE)
                                        type = "*/*"
                                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
                                    })
                                    result.success(null)
                                } catch (_: Exception) {
                                    result.error("NO_FILE_BROWSER", "无法打开系统文件浏览器。", null)
                                }
                            }
                        }
                    } catch (_: SecurityException) {
                        main.post { result.error("SOURCE_ACCESS_LOST", "原文件访问权限已失效，请重新关联原文件。", null) }
                    } catch (_: java.io.FileNotFoundException) {
                        main.post { result.error("SOURCE_MISSING", "原文件已移动或删除，请重新关联。", null) }
                    } catch (_: Exception) {
                        main.post { result.error("SOURCE_LOCATION_FAILED", "无法定位来源文件，请重新关联原文件后重试。", null) }
                    }
                }
            }
        }
    }

    private fun validateSource(uri: Uri) {
        require(DocumentsContract.isDocumentUri(activity, uri))
        // A file's parent is used as the initial browser location; no unrelated root fallback.
        activity.contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) throw java.io.FileNotFoundException()
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
