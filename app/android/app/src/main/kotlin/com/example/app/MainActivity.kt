package com.example.app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContextCompat.startActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "stu_edu/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("StuEdu", "MethodChannel registered")

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "saveToDownloads" -> {
                    try {
                        val fileName = call.argument<String>("fileName")
                        val mimeType = call.argument<String>("mimeType")
                        val bytes = call.argument<ByteArray>("bytes")

                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error("INVALID_ARGS", "Missing fileName or bytes", null)
                            return@setMethodCallHandler
                        }

                        val resolver = applicationContext.contentResolver

                        val values = ContentValues().apply {
                            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                            put(
                                MediaStore.Downloads.MIME_TYPE,
                                mimeType ?: "application/octet-stream"
                            )

                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                put(
                                    MediaStore.Downloads.RELATIVE_PATH,
                                    Environment.DIRECTORY_DOWNLOADS + "/StuEdu"
                                )
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                        }

                        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
                        val itemUri = resolver.insert(collection, values)

                        if (itemUri == null) {
                            result.error("SAVE_FAILED", "Cannot create MediaStore record", null)
                            return@setMethodCallHandler
                        }

                        resolver.openOutputStream(itemUri)?.use { output ->
                            output.write(bytes)
                            output.flush()
                        } ?: run {
                            result.error("SAVE_FAILED", "Cannot open output stream", null)
                            return@setMethodCallHandler
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val doneValues = ContentValues().apply {
                                put(MediaStore.Downloads.IS_PENDING, 0)
                            }
                            resolver.update(itemUri, doneValues, null, null)
                        }

                        // Trả về URI string thay vì chỉ fileName
                        result.success(itemUri.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }

                "openDownloadedFile" -> {
                    try {
                        val uriString = call.argument<String>("uri")
                        val mimeType = call.argument<String>("mimeType")

                        if (uriString.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "Missing uri", null)
                            return@setMethodCallHandler
                        }

                        val uri = Uri.parse(uriString)

                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, mimeType ?: "*/*")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        startActivity(applicationContext, intent, null)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}