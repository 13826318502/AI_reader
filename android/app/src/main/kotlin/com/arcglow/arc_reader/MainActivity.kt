package com.arcglow.arc_reader

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "arc_reader/file_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "openFolder") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "Folder path is empty", null)
                    return@setMethodCallHandler
                }
                try {
                    if (!openFolder(path)) {
                        // 没有可用的文件管理器时，退回 Android 系统目录选择器。
                        startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        })
                    }
                    result.success(true)
                } catch (error: Exception) {
                    result.error("OPEN_FOLDER_FAILED", error.message, null)
                }
            }
    }

    private fun openFolder(path: String): Boolean {
        // 1) 优先交给 MT 管理器：通过 mt://open 协议直接定位到目标目录，
        //    并显式指定主 Activity，避免弹出多个 MT 选项。
        val mtCandidates = listOf(
            "bin.mt.plus" to "bin.mt.plus.MT",
            "bin.mt.file" to "bin.mt.file.MT",
        )
        for ((pkg, activity) in mtCandidates) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                packageManager.getActivityInfo(ComponentName(pkg, activity), 0)
                val uri = Uri.Builder()
                    .scheme("mt")
                    .authority("open")
                    .appendQueryParameter("path", path)
                    .build()
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(pkg)
                    component = ComponentName(pkg, activity)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // 未安装或组件不存在，尝试下一个。
            }
        }

        // 2) 没有 MT 时，交给系统已安装的文件管理器。
        val folder = File(path)
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            folder,
        )
        val mimeCandidates = listOf(
            "resource/folder",
            "vnd.android.document/directory",
            "*/*",
        )
        for (mime in mimeCandidates) {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(Intent.createChooser(intent, "打开 AI 图片文件夹"))
                return true
            }
        }
        return false
    }
}
