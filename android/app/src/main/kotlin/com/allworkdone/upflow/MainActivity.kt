package com.allworkdone.upflow

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.allworkdone.upflow.media_scanner"
    private val FILE_MANAGER_CHANNEL = "com.allworkdone.upflow.file_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Media Scanner Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        scanFile(filePath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // File Manager Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_MANAGER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFileManager" -> {
                    openFileManager(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scanFile(filePath: String, result: MethodChannel.Result) {
        try {
            MediaScannerConnection.scanFile(
                this,
                arrayOf(filePath),
                null
            ) { path, uri ->
                result.success("File scanned: $path")
            }
        } catch (e: Exception) {
            result.error("SCAN_ERROR", "Failed to scan file: ${e.message}", null)
        }
    }

    private fun openFileManager(result: MethodChannel.Result) {
        try {
            // Method 1: Try to open Downloads folder via DocumentsContract
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        Uri.parse("content://com.android.externalstorage.documents/document/primary%3ADownload"),
                        "resource/folder"
                    )
                    addCategory(Intent.CATEGORY_OPENABLE)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success("Downloads folder opened")
                    return
                }
            } catch (e: Exception) {
                // Continue to next method
            }
            
            // Method 2: Try to open file manager with Downloads path
            try {
                val intent = Intent("android.intent.action.VIEW").apply {
                    setDataAndType(Uri.parse("file:///storage/emulated/0/Download"), "*/*")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success("File manager opened with Downloads")
                    return
                }
            } catch (e: Exception) {
                // Continue to next method
            }
            
            // Method 3: Try to launch specific file manager apps
            val fileManagerPackages = listOf(
                "com.google.android.documentsui",
                "com.android.documentsui",
                "com.mi.android.globalFileexplorer",
                "com.es.fileexplorer"
            )
            
            for (packageName in fileManagerPackages) {
                try {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        startActivity(intent)
                        result.success("File manager app opened: $packageName")
                        return
                    }
                } catch (e: Exception) {
                    // Continue to next package
                }
            }
            
            // Method 4: Open generic file picker
            try {
                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(Intent.createChooser(intent, "Open File Manager"))
                result.success("Generic file picker opened")
                return
            } catch (e: Exception) {
                // Continue to error
            }
            
            result.error("NO_FILE_MANAGER", "No suitable file manager found", null)
            
        } catch (e: Exception) {
            result.error("OPEN_ERROR", "Failed to open file manager: ${e.message}", null)
        }
    }
}