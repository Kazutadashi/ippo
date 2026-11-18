// SPDX-License-Identifier: GPL-3.0-or-later

package org.ippo.ippo

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * The Android half of Ippo's storage: the only Kotlin code that touches files.
 *
 * Android does not let apps open shared folders with normal file paths.
 * Instead, the user picks a folder in the system's folder picker (the
 * "Storage Access Framework"), and Android gives the app access to that one
 * folder and nothing else. This needs no storage permission at all.
 *
 * The Dart side (`lib/core/storage/android_data_folder.dart`) calls the
 * methods below over a [MethodChannel]. Every file path it sends is relative
 * to the chosen folder, with `/` between folder names, for example
 * `events/my-device.jsonl`. The Dart side checks those paths before sending
 * them, and this class checks them again.
 *
 * Methods:
 * - `pickFolder()`: opens the folder picker. Returns the folder's URI as a
 *   string, or null if the user cancelled. Access to any previously chosen
 *   folder is given back, so the app only ever holds access to one folder.
 * - `savedFolder()`: the folder chosen earlier, or null if there is none.
 *   Android itself remembers which folder access it granted, so the app
 *   does not need to store this anywhere.
 * - `privateFolderPath()`: the path of the app's own private folder, where
 *   only this app can read and write. Ippo keeps its settings file there
 *   (see `lib/core/storage/settings_file.dart`). Dart reads and writes
 *   that one file directly, because private folders need no picker.
 * - `listFiles(folderUri, path)`: names of the files (not folders) directly
 *   inside `path`. Returns an empty list if `path` does not exist.
 * - `readText(folderUri, path)`: the whole file as UTF-8 text.
 * - `appendText(folderUri, path, text)`: adds `text` to the end of the file,
 *   creating the file and its parent folders if needed.
 */
class StorageBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        /** The channel name. It must match the Dart side. */
        const val CHANNEL_NAME = "org.ippo.ippo/storage"

        /** Identifies our folder picker request when its result comes back. */
        const val PICK_FOLDER_REQUEST_CODE = 4201

        /**
         * The type we give new files. With this generic type, Android keeps
         * the file name exactly as given; with a text type it may add `.txt`.
         */
        private const val NEW_FILE_TYPE = "application/octet-stream"

        /** The access we ask Android to keep: reading and writing. */
        private const val READ_AND_WRITE =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    // File work runs on one background thread, so it never freezes the
    // screen, and so two writes can never run at the same time.
    private val fileWorker = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())
    private val resolver: ContentResolver = activity.contentResolver

    // The folder picker answers later, in onActivityResult, so we keep the
    // pending reply here until then.
    private var pendingPickResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "savedFolder" -> result.success(savedFolder()?.toString())
            "privateFolderPath" -> result.success(activity.filesDir.absolutePath)
            "listFiles" -> runInBackground(result) {
                listFiles(folderUriArgument(call), pathArgument(call))
            }
            "readText" -> runInBackground(result) {
                readText(folderUriArgument(call), pathArgument(call))
            }
            "appendText" -> runInBackground(result) {
                val text = call.argument<String>("text")
                    ?: throw IllegalArgumentException("Missing argument: text")
                appendText(folderUriArgument(call), pathArgument(call), text)
                null
            }
            else -> result.notImplemented()
        }
    }

    /** Opens the system folder picker. The answer arrives in [onPickFolderResult]. */
    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "The folder picker is already open.", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        activity.startActivityForResult(intent, PICK_FOLDER_REQUEST_CODE)
    }

    /**
     * Receives the folder the user picked. Called from [MainActivity].
     *
     * We ask Android to keep our access after the app restarts
     * ("persistable" permission), so the user only has to pick once.
     */
    fun onPickFolderResult(resultCode: Int, data: Intent?) {
        val result = pendingPickResult ?: return
        pendingPickResult = null

        val folderUri = data?.data
        if (resultCode != Activity.RESULT_OK || folderUri == null) {
            result.success(null) // The user cancelled. That is not an error.
            return
        }
        try {
            releaseFoldersExcept(folderUri)
            resolver.takePersistableUriPermission(folderUri, READ_AND_WRITE)
            result.success(folderUri.toString())
        } catch (error: SecurityException) {
            result.error("no_access", "Could not keep access to the folder: ${error.message}", null)
        }
    }

    /** The folder we still have read and write access to, if any. */
    private fun savedFolder(): Uri? {
        return resolver.persistedUriPermissions
            .firstOrNull { permission -> permission.isReadPermission && permission.isWritePermission }
            ?.uri
    }

    /**
     * Gives back access to every folder except [keptFolderUri]. When the
     * user picks a new data folder, the app should not keep access to the
     * old one.
     */
    private fun releaseFoldersExcept(keptFolderUri: Uri) {
        for (permission in resolver.persistedUriPermissions) {
            if (permission.uri != keptFolderUri) {
                resolver.releasePersistableUriPermission(permission.uri, READ_AND_WRITE)
            }
        }
    }

    private fun listFiles(folderUri: Uri, path: String): List<String> {
        val folderId = findDocumentId(folderUri, splitPath(path)) ?: return emptyList()
        return listChildren(folderUri, folderId)
            .filter { child -> !child.isFolder }
            .map { child -> child.name }
    }

    private fun readText(folderUri: Uri, path: String): String {
        val fileId = findDocumentId(folderUri, splitPath(path))
            ?: throw FileNotFoundException("No such file: $path")
        val fileUri = DocumentsContract.buildDocumentUriUsingTree(folderUri, fileId)
        val input = resolver.openInputStream(fileUri)
            ?: throw FileNotFoundException("Could not open: $path")
        input.use { stream -> return stream.readBytes().toString(Charsets.UTF_8) }
    }

    private fun appendText(folderUri: Uri, path: String, text: String) {
        val parts = splitPath(path)
        val parentId = findOrCreateFolders(folderUri, parts.dropLast(1))
        val fileName = parts.last()
        val fileId = findChildId(folderUri, parentId, fileName)
            ?: createDocument(folderUri, parentId, NEW_FILE_TYPE, fileName)
        val fileUri = DocumentsContract.buildDocumentUriUsingTree(folderUri, fileId)

        // Mode "wa" means "write, append": new bytes go after the existing
        // ones. Nothing already in the file is ever changed.
        val output = resolver.openOutputStream(fileUri, "wa")
            ?: throw FileNotFoundException("Could not open for appending: $path")
        output.use { stream -> stream.write(text.toByteArray(Charsets.UTF_8)) }
    }

    /** One entry inside a folder. */
    private data class Child(val id: String, val name: String, val isFolder: Boolean)

    private fun listChildren(folderUri: Uri, parentId: String): List<Child> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(folderUri, parentId)
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE
        )
        val children = mutableListOf<Child>()
        val cursor = resolver.query(childrenUri, columns, null, null, null)
            ?: throw FileNotFoundException("Could not list folder")
        cursor.use {
            while (cursor.moveToNext()) {
                children.add(
                    Child(
                        id = cursor.getString(0),
                        name = cursor.getString(1),
                        isFolder = cursor.getString(2) == Document.MIME_TYPE_DIR
                    )
                )
            }
        }
        return children
    }

    private fun findChildId(folderUri: Uri, parentId: String, name: String): String? {
        return listChildren(folderUri, parentId).firstOrNull { child -> child.name == name }?.id
    }

    /** Walks down [parts] from the chosen folder. Returns null if any part is missing. */
    private fun findDocumentId(folderUri: Uri, parts: List<String>): String? {
        var currentId = DocumentsContract.getTreeDocumentId(folderUri)
        for (part in parts) {
            currentId = findChildId(folderUri, currentId, part) ?: return null
        }
        return currentId
    }

    /** Like [findDocumentId], but creates any missing folders on the way. */
    private fun findOrCreateFolders(folderUri: Uri, folderNames: List<String>): String {
        var currentId = DocumentsContract.getTreeDocumentId(folderUri)
        for (name in folderNames) {
            currentId = findChildId(folderUri, currentId, name)
                ?: createDocument(folderUri, currentId, Document.MIME_TYPE_DIR, name)
        }
        return currentId
    }

    private fun createDocument(folderUri: Uri, parentId: String, type: String, name: String): String {
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(folderUri, parentId)
        val newUri = DocumentsContract.createDocument(resolver, parentUri, type, name)
            ?: throw FileNotFoundException("Could not create: $name")
        return DocumentsContract.getDocumentId(newUri)
    }

    /**
     * Splits a relative path into its parts, and refuses anything that could
     * reach outside the chosen folder. The Dart side checks this too; we check
     * again here so this file is safe on its own.
     */
    private fun splitPath(path: String): List<String> {
        val parts = path.split("/")
        val isSafe = path.isNotEmpty() &&
            parts.none { part -> part.isEmpty() || part == "." || part == ".." }
        if (!isSafe) {
            throw IllegalArgumentException("Not a safe relative path: $path")
        }
        return parts
    }

    private fun folderUriArgument(call: MethodCall): Uri {
        val text = call.argument<String>("folderUri")
            ?: throw IllegalArgumentException("Missing argument: folderUri")
        return Uri.parse(text)
    }

    private fun pathArgument(call: MethodCall): String {
        return call.argument<String>("path")
            ?: throw IllegalArgumentException("Missing argument: path")
    }

    /**
     * Runs [work] on the background thread and sends its answer (or its
     * error) back to Dart on the main thread, as Flutter requires.
     */
    private fun runInBackground(result: MethodChannel.Result, work: () -> Any?) {
        fileWorker.execute {
            try {
                val answer = work()
                mainThread.post { result.success(answer) }
            } catch (error: Exception) {
                // Never hide a failure: pass it to Dart, which shows it.
                val message = error.message ?: error.javaClass.simpleName
                mainThread.post { result.error("storage_error", message, null) }
            }
        }
    }
}
