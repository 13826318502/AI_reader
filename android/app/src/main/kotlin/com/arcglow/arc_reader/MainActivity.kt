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
    private val readerControlsChannel = "arc_reader/reader_controls"
    private var volumePageTurn = false
    private var billingCredentialStore: BillingCredentialStore? = null
    private var sourceFileNavigator: SourceFileNavigator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        billingCredentialStore = BillingCredentialStore(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        sourceFileNavigator = SourceFileNavigator(this, flutterEngine.dartExecutor.binaryMessenger)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, readerControlsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolumePageTurn" -> {
                        volumePageTurn = call.argument<Boolean>("enabled") == true
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sourceFileNavigator?.close()
        sourceFileNavigator = null
        billingCredentialStore?.close()
        billingCredentialStore = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent): Boolean {
        if (volumePageTurn && event.repeatCount == 0 &&
            (keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP ||
                keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val direction = if (keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP) 1 else -1
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, readerControlsChannel).invokeMethod(
                    "volumeKey",
                    mapOf("direction" to direction),
                )
            }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun openFolder(path: String): Boolean {
        // 先交给 Android 选择器，保留 MT 管理器和系统文件管理器两个入口。
        // 旧逻辑强制指定 MT，导致用户无法选择其他文件管理器。
        val folder = File(path)
        val folderUri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            folder,
        )
        val mtIntents = arrayListOf<android.os.Parcelable>()
        val mtCandidates = listOf(
            "bin.mt.plus",
            "bin.mt.file",
        )
        for (pkg in mtCandidates) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                val uri = Uri.Builder()
                    .scheme("mt")
                    .authority("open")
                    .appendQueryParameter("path", path)
                    .build()
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(pkg)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    mtIntents.add(intent)
                }
            } catch (_: Exception) {
                // 未安装或组件不存在，继续检查其他文件管理器。
            }
        }

        val generic = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(folderUri, "*/*")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        if (generic.resolveActivity(packageManager) != null) {
            val chooser = Intent.createChooser(generic, "打开 AI 图片文件夹")
            chooser.putParcelableArrayListExtra(
                Intent.EXTRA_INITIAL_INTENTS,
                mtIntents,
            )
            startActivity(chooser)
            return true
        }
        if (mtIntents.isNotEmpty()) {
            startActivity(Intent.createChooser(mtIntents.first() as Intent, "打开 AI 图片文件夹"))
            return true
        }
        return false
    }
}
