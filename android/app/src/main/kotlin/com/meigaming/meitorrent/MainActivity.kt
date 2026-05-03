package com.meigaming.meitorrent

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val OEM_CHANNEL  = "com.meigaming.meitorrent/oem"
        private const val DISK_CHANNEL = "com.meigaming.meitorrent/disk"
        private const val FILES_CHANNEL = "com.meigaming.meitorrent/files"
        private const val STORAGE_CHANNEL = "com.meigaming.meitorrent/storage"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── OEM Battery Settings Channel ─────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchOemSettings" -> {
                        val packageName = call.argument<String>("package")
                        if (packageName != null) launchOemPackage(packageName, result)
                        else result.error("INVALID_ARG", "package name is null", null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── Disk Space Channel ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFreeDiskBytes" -> {
                        val path = call.argument<String>("path")
                        result.success(getFreeDiskBytes(path))
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── Storage Info Channel (Play Store Compliant) ────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDownloadDirectory" -> {
                        // Use public Download folder for better user accessibility
                        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        result.success(downloads.absolutePath)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── Files / Folder Channel (Scoped Storage Mapping) ────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openFolder" -> {
                        val path = call.argument<String>("path")
                        if (path != null) openFolder(path, result)
                        else result.error("INVALID_ARG", "path is null", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens a folder in the system file manager using Play Store–compliant
     * DocumentsProvider URIs with multiple fallback strategies.
     */
    private fun openFolder(path: String, result: MethodChannel.Result) {
        try {
            val dir = File(path)
            if (!dir.exists()) {
                dir.mkdirs()
            }

            // On modern Android (11+), the most reliable way to open a specific folder
            // is using the DocumentsProvider URI via the system Files app.
            
            val rootPath = Environment.getExternalStorageDirectory().absolutePath
            val relativePath = if (path.startsWith(rootPath)) {
                path.substring(rootPath.length).trimStart('/')
            } else {
                path
            }

            // Strategy 1: DocumentsProvider exact path (Best for Android 11+)
            try {
                val encodedPath = Uri.encode(relativePath)
                val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary:$encodedPath")
                
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "vnd.android.document/directory")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                
                startActivity(intent)
                result.success("exact")
                return
            } catch (e: Exception) {
                android.util.Log.w("MeiTorrent", "Strategy 1 (Exact) failed: ${e.message}")
            }

            // Strategy 2: Open the root of the Download folder as a fallback
            try {
                val uri = Uri.parse("content://com.android.externalstorage.documents/document/primary:Download")
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "vnd.android.document/directory")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success("fallback_root")
                return
            } catch (e: Exception) {
                android.util.Log.w("MeiTorrent", "Strategy 2 (Root) failed: ${e.message}")
            }

            // Strategy 3: Generic Document Tree (Last resort)
            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success("picker")
            } catch (e: Exception) {
                result.error("OPEN_FAILED", "Could not open any file manager: ${e.message}", null)
            }
        } catch (e: Exception) {
            result.error("CRITICAL_ERROR", e.message, null)
        }
    }

    private fun launchOemPackage(packageName: String, result: MethodChannel.Result) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent != null) {
            startActivity(intent)
            result.success(true)
        } else {
            val fallback = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(fallback)
            result.success(false)
        }
    }

    private fun getFreeDiskBytes(path: String?): Long {
        val targetPath = path ?: Environment.getExternalStorageDirectory().absolutePath
        return try {
            val stat = StatFs(targetPath)
            stat.availableBlocksLong * stat.blockSizeLong
        } catch (e: Exception) {
            0L
        }
    }
}
