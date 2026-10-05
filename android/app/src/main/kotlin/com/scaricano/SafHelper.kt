package com.scaricano

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Helper class for Storage Access Framework (SAF) operations.
 * Handles USB OTG, SD card, and internal storage access.
 */
class SafHelper(private val context: Context) {
    
    companion object {
        const val REQUEST_CODE_OPEN_DIRECTORY = 42
        const val REQUEST_CODE_CREATE_FILE = 43
        const val MIME_TYPE_AUDIO = "audio/*"
        const val MIME_TYPE_ANY = "*/*"
    }

    /**
     * Opens directory picker for user to select a folder
     */
    fun openDirectoryPicker(activity: Activity) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or 
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            putExtra(DocumentsContract.EXTRA_INITIAL_URI, getDefaultUri())
        }
        activity.startActivityForResult(intent, REQUEST_CODE_OPEN_DIRECTORY)
    }

    /**
     * Creates a new file in the selected directory
     */
    fun createFileInDirectory(
        activity: Activity,
        directoryUri: Uri,
        fileName: String,
        mimeType: String = MIME_TYPE_AUDIO
    ): Uri? {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            putExtra(DocumentsContract.EXTRA_INITIAL_URI, directoryUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or 
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_CREATE_FILE)
        return null // Uri will be returned in onActivityResult
    }

    /**
     * Gets the default storage directory URI
     */
    fun getDefaultUri(): Uri {
        return Uri.fromFile(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC))
    }

    /**
     * Checks if a URI is still valid and accessible
     */
    fun isUriValid(uri: Uri): Boolean {
        return try {
            val resolver = context.contentResolver
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            resolver.takePersistableUriPermission(uri, takeFlags)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Gets available space in bytes for a given URI
     */
    fun getAvailableSpace(uri: Uri): Long {
        return try {
            val documentFile = DocumentFile.fromTreeUri(context, uri)
            val path = documentFile?.uri?.path
            
            // For USB/SD card
            if (path?.contains("/mnt/") == true || path?.contains("/storage/") == true) {
                val stat = StatFs(path)
                stat.availableBytes
            } else {
                // For internal storage
                val stat = StatFs(Environment.getDataDirectory().path)
                stat.availableBytes
            }
        } catch (e: Exception) {
            -1L // Error
        }
    }

    /**
     * Gets the display name for a URI
     */
    fun getDisplayName(uri: Uri): String {
        return try {
            val resolver = context.contentResolver
            var displayName = ""
            resolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    displayName = cursor.getString(nameIndex)
                }
            }
            displayName.ifEmpty { uri.lastPathSegment ?: "Unknown" }
        } catch (e: Exception) {
            uri.lastPathSegment ?: "Unknown"
        }
    }

    /**
     * Writes data to a file at the given URI
     */
    fun writeFile(uri: Uri, data: ByteArray): Boolean {
        return try {
            val resolver = context.contentResolver
            val outputStream: OutputStream = resolver.openOutputStream(uri) ?: return false
            outputStream.write(data)
            outputStream.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Writes data from input stream to a file at the given URI
     */
    fun writeFileFromStream(uri: Uri, inputStream: InputStream, onProgress: (Long) -> Unit): Boolean {
        return try {
            val resolver = context.contentResolver
            val outputStream: OutputStream = resolver.openOutputStream(uri) ?: return false
            val buffer = ByteArray(8192)
            var bytesRead: Int
            var totalBytes: Long = 0
            
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
                totalBytes += bytesRead
                onProgress(totalBytes)
            }
            
            outputStream.close()
            inputStream.close()
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Deletes a file at the given URI
     */
    fun deleteFile(uri: Uri): Boolean {
        return try {
            val documentFile = DocumentFile.fromSingleUri(context, uri)
            documentFile?.delete() ?: false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Lists all files in a directory
     */
    fun listFiles(uri: Uri): List<Uri> {
        val result = mutableListOf<Uri>()
        try {
            val documentFile = DocumentFile.fromTreeUri(context, uri)
            val children = documentFile?.listFiles()
            children?.forEach { file ->
                file.uri?.let { result.add(it) }
            }
        } catch (e: Exception) {
            // Ignore
        }
        return result
    }

    /**
     * Checks if a URI points to a directory
     */
    fun isDirectory(uri: Uri): Boolean {
        return try {
            val documentFile = DocumentFile.fromTreeUri(context, uri)
            documentFile?.isDirectory ?: false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Revokes access to a URI
     */
    fun revokeAccess(uri: Uri) {
        try {
            context.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (e: Exception) {
            // Ignore
        }
    }

    /**
     * Takes persistable URI permission
     */
    fun takePersistablePermission(uri: Uri): Boolean {
        return try {
            val resolver = context.contentResolver
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            resolver.takePersistableUriPermission(uri, takeFlags)
            true
        } catch (e: Exception) {
            false
        }
    }
}
