package com.arcglow.arc_reader

import android.content.Intent
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
                    val folder = File(path)
                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        folder,
                    )
                    val packageCandidates = listOf(
                        "bin.mt.plus", // MT 管理器
                        "bin.mt.file", // MT 文件管理器旧包名
                    )
                    val mimeCandidates = listOf(
                        "resource/folder",
                        "vnd.android.document/directory",
                        "*/*",
                    )
                    var opened = false

                    // 如果设备安装了 MT，优先交给 MT 打开。
                    for (packageName in packageCandidates) {
                        for (mime in mimeCandidates) {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setPackage(packageName)
                                setDataAndType(uri, mime)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                opened = true
                                break
                            }
                        }
                        if (opened) break
                    }

                    // 没有 MT 时，交给系统已安装的文件管理器。
                    if (!opened) {
                        for (mime in mimeCandidates) {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mime)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(Intent.createChooser(intent, "打开 AI 图片文件夹"))
                                opened = true
                                break
                            }
                        }
                    }

                    if (!opened) {
                        // 最后退回 Android 系统目录选择器。
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
}
