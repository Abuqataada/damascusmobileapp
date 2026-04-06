package com.damascusprojects.webviewwrapper

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "damascus_projects/recording_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveRecording" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mimeType = call.argument<String>("mimeType") ?: "video/webm"

                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("invalid_args", "Missing fileName or bytes", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val savedPath = saveVideoToPublicStorage(fileName, bytes, mimeType)
                            result.success(savedPath)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun saveVideoToPublicStorage(
        fileName: String,
        bytes: ByteArray,
        mimeType: String
    ): String {
        val resolver = applicationContext.contentResolver

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_MOVIES + File.separator + "DamascusProjects"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val itemUri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Failed to create MediaStore entry")

            resolver.openOutputStream(itemUri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("Failed to open output stream")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)

            itemUri.toString()
        } else {
            @Suppress("DEPRECATION")
            val moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
            val targetDir = File(moviesDir, "DamascusProjects")
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            val file = File(targetDir, fileName)
            FileOutputStream(file).use { output ->
                output.write(bytes)
            }

            android.media.MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(file.absolutePath),
                arrayOf(mimeType),
                null
            )

            file.absolutePath
        }
    }
}
