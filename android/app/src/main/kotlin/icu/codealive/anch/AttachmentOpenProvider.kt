package icu.codealive.anch

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.ProxyFileDescriptorCallback
import android.os.storage.StorageManager
import java.io.FileNotFoundException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min

/** 仅向用户在系统选择器中选定的应用临时提供内存附件内容。 */
object AttachmentOpenRegistry {
    const val authority = "icu.codealive.anch.attachment_open"
    private const val tokenLifetimeMs = 60_000L
    private val entries = ConcurrentHashMap<String, Entry>()
    private val handler = Handler(Looper.getMainLooper())

    internal class Entry(
        val bytes: ByteArray,
        val mimeType: String,
        @Volatile var opened: Boolean = false,
    )

    fun register(bytes: ByteArray, mimeType: String): Uri {
        val token = UUID.randomUUID().toString()
        entries[token] = Entry(bytes, mimeType)
        handler.postDelayed({ expire(token) }, tokenLifetimeMs)
        return Uri.Builder()
            .scheme("content")
            .authority(authority)
            .appendPath("attachment")
            .appendPath(token)
            .build()
    }

    fun mimeType(uri: Uri): String? = entries[tokenFrom(uri)]?.mimeType

    fun open(uri: Uri): OpenedEntry? {
        val token = tokenFrom(uri)
        val entry = entries[token] ?: return null
        synchronized(entry) {
            if (entry.opened) return null
            entry.opened = true
        }
        return OpenedEntry(token, entry)
    }

    fun release(openedEntry: OpenedEntry) {
        if (entries.remove(openedEntry.token, openedEntry.entry)) {
            openedEntry.entry.bytes.fill(0)
        }
    }

    fun revoke(uri: Uri) {
        val entry = entries.remove(tokenFrom(uri)) ?: return
        entry.bytes.fill(0)
    }

    private fun expire(token: String) {
        val entry = entries[token] ?: return
        synchronized(entry) {
            if (entry.opened) return
            if (entries.remove(token, entry)) entry.bytes.fill(0)
        }
    }

    private fun tokenFrom(uri: Uri): String =
        if (uri.pathSegments.size == 2 && uri.pathSegments[0] == "attachment") {
            uri.pathSegments[1]
        } else {
            ""
        }

    class OpenedEntry internal constructor(
        val token: String,
        internal val entry: Entry,
    ) {
        val bytes: ByteArray get() = entry.bytes
    }
}

class AttachmentOpenProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String? = AttachmentOpenRegistry.mimeType(uri)

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException()
        val opened = AttachmentOpenRegistry.open(uri) ?: throw FileNotFoundException()
        val storageManager = context?.getSystemService(StorageManager::class.java)
            ?: run {
                AttachmentOpenRegistry.release(opened)
                throw FileNotFoundException()
            }
        return storageManager.openProxyFileDescriptor(
            ParcelFileDescriptor.MODE_READ_ONLY,
            AttachmentProxyCallback(opened),
            Handler(Looper.getMainLooper()),
        )
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}

private class AttachmentProxyCallback(
    private val opened: AttachmentOpenRegistry.OpenedEntry,
) : ProxyFileDescriptorCallback() {
    override fun onGetSize(): Long = opened.bytes.size.toLong()

    override fun onRead(offset: Long, size: Int, data: ByteArray): Int {
        if (offset < 0 || offset >= opened.bytes.size) return -1
        val byteCount = min(size, opened.bytes.size - offset.toInt())
        opened.bytes.copyInto(data, 0, offset.toInt(), offset.toInt() + byteCount)
        return byteCount
    }

    override fun onRelease() {
        AttachmentOpenRegistry.release(opened)
    }
}
