package com.ashspark.image_resizer

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ashspark.image_resizer/system_integration"
    private var methodChannel: MethodChannel? = null

    private var initialSharedFilePath: String? = null
    private var initialShortcut: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Process launch intent
        handleIntent(intent, isInitial = true)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFile" -> {
                        val path = initialSharedFilePath
                        initialSharedFilePath = null // consume once
                        result.success(path)
                    }
                    "getInitialShortcut" -> {
                        val shortcut = initialShortcut
                        initialShortcut = null // consume once
                        result.success(shortcut)
                    }
                    "openInGallery" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            val success = openImageInGallery(path)
                            result.success(success)
                        } else {
                            result.error("INVALID_PATH", "Path cannot be null", null)
                        }
                    }
                    "convertHeicToJpeg" -> {
                        val path = call.argument<String>("path")
                        val targetPath = call.argument<String>("targetPath")
                        val quality = call.argument<Int>("quality") ?: 95
                        if (path == null || targetPath == null) {
                            result.error("INVALID_ARGS", "Path or targetPath cannot be null", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val file = File(path)
                                if (!file.exists()) {
                                    runOnUiThread { result.error("FILE_NOT_FOUND", "File not found: $path", null) }
                                    return@Thread
                                }

                                val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                    val source = ImageDecoder.createSource(file)
                                    ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                                        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                                        decoder.isMutableRequired = true
                                    }
                                } else {
                                    BitmapFactory.decodeFile(path)
                                }

                                if (bitmap != null) {
                                    val outFile = File(targetPath)
                                    outFile.parentFile?.mkdirs()
                                    FileOutputStream(outFile).use { outStream ->
                                        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outStream)
                                    }
                                    bitmap.recycle()
                                    runOnUiThread { result.success(outFile.absolutePath) }
                                } else {
                                    runOnUiThread { result.error("DECODE_FAILED", "Failed to decode image bitmap", null) }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("CONVERT_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, isInitial = false)
    }

    private fun handleIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return

        // Check for shortcut
        val shortcut = intent.getStringExtra("shortcut")
        if (!shortcut.isNullOrEmpty()) {
            if (isInitial) {
                initialShortcut = shortcut
            } else {
                methodChannel?.invokeMethod("onShortcutReceived", shortcut)
            }
        }

        // Check for shared image (ACTION_SEND or ACTION_VIEW)
        val action = intent.action
        val type = intent.type

        val uri: Uri? = when {
            action == Intent.ACTION_SEND && type != null && type.startsWith("image/") -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
            }
            action == Intent.ACTION_VIEW && type != null && type.startsWith("image/") -> {
                intent.data
            }
            action == Intent.ACTION_VIEW && intent.data != null -> {
                intent.data
            }
            else -> null
        }

        if (uri != null) {
            val resolvedPath = copyUriToCache(uri)
            if (resolvedPath != null) {
                if (isInitial) {
                    initialSharedFilePath = resolvedPath
                } else {
                    methodChannel?.invokeMethod("onSharedFileReceived", resolvedPath)
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val extension = when (contentResolver.getType(uri)) {
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> "jpg"
            }
            val cacheFile = File(cacheDir, "shared_incoming_${System.currentTimeMillis()}.$extension")
            FileOutputStream(cacheFile).use { output ->
                inputStream.copyTo(output)
            }
            cacheFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun openImageInGallery(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val contentUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(contentUri, "image/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
