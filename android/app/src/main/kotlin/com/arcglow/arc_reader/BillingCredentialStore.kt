package com.arcglow.arc_reader

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class BillingCredentialStore(context: Context, messenger: BinaryMessenger) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "billing_credentials.v1"))
    private val channel = MethodChannel(messenger, "arc_reader/billing_credentials")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val alias = "arc_reader.billing.v1"

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method !in listOf("read", "write", "clear")) {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val value = if (call.method == "read") read() else if (call.method == "clear") {
                            file.delete()
                            check(!file.baseFile.exists())
                            KeyStore.getInstance("AndroidKeyStore").apply { load(null); deleteEntry(alias) }
                            null
                        } else {
                            val text = call.argument<String>("value") ?: error("Missing value")
                            require(text.toByteArray(Charsets.UTF_8).size <= 16384)
                            write(text)
                            null
                        }
                        main.post { result.success(value) }
                    } catch (_: Exception) {
                        main.post { result.error("SECURE_STORAGE_FAILED", "Unable to access encrypted credentials", null) }
                    }
                }
            }
        }
    }

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(alias, null)
        if (existing is SecretKey) return existing
        check(create)
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build())
        return generator.generateKey()
    }

    private fun read(): String? {
        val bytes = try { file.readFully() } catch (_: java.io.FileNotFoundException) { return null }
        require(bytes.size >= 29 && bytes[0].toInt() == 1)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(1, 13)))
        return cipher.doFinal(bytes.copyOfRange(13, bytes.size)).toString(Charsets.UTF_8)
    }

    private fun write(text: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        check(cipher.iv.size == 12)
        val bytes = byteArrayOf(1) + cipher.iv + cipher.doFinal(text.toByteArray(Charsets.UTF_8))
        val output = file.startWrite()
        try {
            output.write(bytes)
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
