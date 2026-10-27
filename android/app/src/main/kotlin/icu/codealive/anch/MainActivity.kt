package icu.codealive.anch

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.OsConstants
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InterruptedIOException
import java.io.OutputStream
import kotlin.concurrent.thread

class MainActivity : FlutterFragmentActivity() {
    private val READ_CHANNEL = "anch/backup_file_read"
    private val STREAM_V2_CHANNEL = "anch/backup_stream_v2"
    private val ATTACHMENT_EXTERNAL_OPEN_CHANNEL = "anch/attachment_external_open"
    private val EXTERNAL_URL_CHANNEL = "anch/external_url"
    private val READ_REQUEST_CODE = 4322
    private val ATTACHMENT_READ_REQUEST_CODE = 4323
    private val STREAM_WRITE_REQUEST_CODE = 4324
    private val MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024
    private val STREAM_V2_MAGIC = byteArrayOf(0x41, 0x4e, 0x43, 0x48, 0x42, 0x4b, 0x02, 0x0a)
    private val BACKUP_MIME_TYPE = "application/vnd.icu.codealive.abk"
    private val LEGACY_BACKUP_MIME_TYPE = "application/octet-stream"
    private val BACKUP_STREAM_DEBUG_TAG = "AnchBackupStream"

    private var pendingReadResult: MethodChannel.Result? = null

    private var pendingStreamingWriteResult: MethodChannel.Result? = null
    private var streamingOutputStream: OutputStream? = null
    private var streamingWrittenBytes: Long = 0
    private var streamingInputStream: java.io.InputStream? = null
    private var streamingInputPrefix: ByteArray? = null
    private var streamingInputSizeBytes: Long? = null
    private var streamingInputUri: Uri? = null

    private var pendingAttachmentReadResult: MethodChannel.Result? = null
    private var attachmentReadRequestId: Long = 0
    private var lastAttachmentDocumentUri: Uri? = null
    private var strongBiometricBridge: StrongBiometricBridge? = null
    private var foregroundSecureWindowEnabled = false
    private var isBackgrounded = false

    private data class AttachmentReadPayload(
        val bytes: ByteArray? = null,
        val originalName: String? = null,
        val mimeType: String? = null,
        val errorCode: String? = null,
        val errorMessage: String? = null,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ 的公开任务快照保护；不依赖客户端生命周期时序。
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun onPause() {
        // Android 12L 及以下没有任务快照专用 API，后台期间使用窗口保护兜底。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            enableBackgroundSecureWindow()
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            isBackgrounded = false
        }
        applySecureWindowProtection()
    }

    private fun enableBackgroundSecureWindow() {
        isBackgrounded = true
        applySecureWindowProtection()
    }

    private fun applySecureWindowProtection() {
        val shouldProtect = foregroundSecureWindowEnabled || isBackgrounded
        if (shouldProtect) {
            window?.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        strongBiometricBridge = StrongBiometricBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )

        // 1.5 V2 分帧流式导出通道。它不持有整包字节，失败时只关闭未提交文件，不自动删除用户选择的位置。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_V2_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "beginStreamingBackupDocument" -> {
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                        result.error("invalidPackage", "备份文件参数不正确", null)
                        return@setMethodCallHandler
                    }
                    if (pendingStreamingWriteResult != null || streamingOutputStream != null) {
                        result.error("operationInProgress", "上一次文件操作尚未结束", null)
                        return@setMethodCallHandler
                    }
                    // 读取会话只服务于已离开当前页面的恢复流程；用户主动开始导出时，
                    // 释放这条无运行任务的只读流，避免它错误阻断新的写入会话。
                    closeStreamingInput()
                    pendingStreamingWriteResult = result
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    try {
                        startActivityForResult(intent, STREAM_WRITE_REQUEST_CODE)
                    } catch (e: ActivityNotFoundException) {
                        pendingStreamingWriteResult?.error("systemPickerUnavailable", "系统文件选择器不可用", null)
                        clearPendingStreamingWrite()
                    } catch (e: Exception) {
                        pendingStreamingWriteResult?.error("unknown", "无法调起系统选择器", null)
                        clearPendingStreamingWrite()
                    }
                }
                "writeStreamingBackupChunk" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val outputStream = streamingOutputStream
                    if (bytes == null || bytes.isEmpty() || bytes.size > 256 * 1024 || outputStream == null) {
                        logBackupStreamFailure(
                            phase = "write",
                            kind = "stream_state",
                            wroteAny = streamingWrittenBytes > 0L,
                        )
                        val errorCode = if (streamingWrittenBytes == 0L) {
                            "targetWriteFailed"
                        } else {
                            "writeFailed"
                        }
                        result.error(errorCode, "备份流写入状态无效", null)
                        return@setMethodCallHandler
                    }
                    try {
                        outputStream.write(bytes)
                        streamingWrittenBytes += bytes.size.toLong()
                        result.success(mapOf("success" to true))
                    } catch (e: SecurityException) {
                        closeStreamingOutput()
                        result.error("permissionDenied", "系统未授予写入权限", null)
                    } catch (e: IOException) {
                        val hasWrittenBytes = streamingWrittenBytes > 0L
                        val errorCode = backupStreamFailureCode(
                            error = e,
                            phase = "write",
                            fallbackCode = if (hasWrittenBytes) "writeFailed" else "targetWriteFailed",
                            wroteAny = hasWrittenBytes,
                        )
                        closeStreamingOutput()
                        result.error(errorCode, "备份文件写入失败", null)
                    } catch (e: Exception) {
                        logBackupStreamFailure(
                            phase = "write",
                            kind = "unknown",
                            wroteAny = streamingWrittenBytes > 0L,
                        )
                        closeStreamingOutput()
                        result.error("unknown", "备份文件写入失败", null)
                    }
                }
                "finishStreamingBackupDocument" -> {
                    val outputStream = streamingOutputStream
                    if (outputStream == null) {
                        logBackupStreamFailure(
                            phase = "finish",
                            kind = "stream_state",
                            wroteAny = streamingWrittenBytes > 0L,
                        )
                        result.error("finalizationFailed", "备份流写入状态无效", null)
                        return@setMethodCallHandler
                    }
                    try {
                        outputStream.flush()
                        outputStream.close()
                        streamingOutputStream = null
                        result.success(
                            mapOf(
                                "success" to true,
                                "savedAt" to System.currentTimeMillis(),
                                "sizeBytes" to streamingWrittenBytes
                            )
                        )
                        streamingWrittenBytes = 0
                    } catch (e: SecurityException) {
                        closeStreamingOutput()
                        result.error("permissionDenied", "系统未授予写入权限", null)
                    } catch (e: IOException) {
                        val errorCode = backupStreamFailureCode(
                            error = e,
                            phase = "finish",
                            fallbackCode = "finalizationFailed",
                            wroteAny = streamingWrittenBytes > 0L,
                        )
                        closeStreamingOutput()
                        result.error(errorCode, "备份文件写入失败", null)
                    } catch (e: Exception) {
                        logBackupStreamFailure(
                            phase = "finish",
                            kind = "unknown",
                            wroteAny = streamingWrittenBytes > 0L,
                        )
                        closeStreamingOutput()
                        result.error("unknown", "备份文件写入失败", null)
                    }
                }
                "abortStreamingBackupDocument" -> {
                    closeStreamingOutput()
                    result.success(null)
                }
                "getSelectedStreamingBackupInfo" -> {
                    if (streamingInputStream == null) {
                        result.error("readFailed", "备份流读取状态无效", null)
                    } else {
                        result.success(
                            mapOf(
                                "success" to true,
                                "sizeBytes" to streamingInputSizeBytes
                            )
                        )
                    }
                }
                "readSelectedStreamingBackupChunk" -> {
                    val inputStream = streamingInputStream
                    if (inputStream == null) {
                        result.error("readFailed", "备份流读取状态无效", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val prefix = streamingInputPrefix
                        if (prefix != null) {
                            streamingInputPrefix = null
                            result.success(mapOf("success" to true, "bytes" to prefix, "eof" to false))
                        } else {
                            val buffer = ByteArray(256 * 1024)
                            val bytesRead = inputStream.read(buffer)
                            if (bytesRead == -1) {
                                result.success(mapOf("success" to true, "eof" to true))
                            } else {
                                result.success(
                                    mapOf(
                                        "success" to true,
                                        "bytes" to buffer.copyOf(bytesRead),
                                        "eof" to false
                                    )
                                )
                            }
                        }
                    } catch (e: SecurityException) {
                        closeStreamingInput()
                        result.error("permissionDenied", "系统未授予读取权限", null)
                    } catch (e: IOException) {
                        closeStreamingInput()
                        result.error("readFailed", "备份文件读取失败", null)
                    } catch (e: Exception) {
                        closeStreamingInput()
                        result.error("unknown", "备份文件读取失败", null)
                    }
                }
                "restartSelectedStreamingBackupRead" -> {
                    try {
                        if (!restartSelectedStreamingInput()) {
                            closeStreamingInput()
                            result.error("readFailed", "备份流读取状态无效", null)
                        } else {
                            result.success(
                                mapOf(
                                    "success" to true,
                                    "sizeBytes" to streamingInputSizeBytes
                                )
                            )
                        }
                    } catch (e: SecurityException) {
                        closeStreamingInput()
                        result.error("permissionDenied", "系统未授予读取权限", null)
                    } catch (e: IOException) {
                        closeStreamingInput()
                        result.error("readFailed", "备份文件读取失败", null)
                    } catch (e: Exception) {
                        closeStreamingInput()
                        result.error("unknown", "备份文件读取失败", null)
                    }
                }
                "closeSelectedStreamingBackupRead" -> {
                    closeStreamingInput()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 2. 注册读取通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READ_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openBackupDocumentAndRead") {
                // ⚠️ 【并发锁与排他性校验】同一时间只允许一个 SAF 读取请求
                if (pendingReadResult != null || streamingInputStream != null) {
                    result.error("readFailed", "上一个读取请求尚未结束", null)
                    return@setMethodCallHandler
                }

                pendingReadResult = result

                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(BACKUP_MIME_TYPE, LEGACY_BACKUP_MIME_TYPE)
                    )
                }

                try {
                    startActivityForResult(intent, READ_REQUEST_CODE)
                } catch (e: ActivityNotFoundException) {
                    pendingReadResult?.error("systemPickerUnavailable", "当前设备无法打开系统文件选择器", null)
                    clearPendingRead()
                } catch (e: Exception) {
                    pendingReadResult?.error("unknown", "无法调起系统文件选择器", null)
                    clearPendingRead()
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anch/attachment_file_read").setMethodCallHandler { call, result ->
            if (call.method == "openAttachmentDocumentAndRead") {
                if (pendingAttachmentReadResult != null) {
                    result.error("readFailed", "上一个附件读取请求尚未结束", null)
                    return@setMethodCallHandler
                }

				pendingAttachmentReadResult = result
                attachmentReadRequestId += 1
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(
                            "image/jpeg",
                            "image/png",
                            "image/webp",
                            "application/pdf",
                            "text/plain",
                            "application/msword",
                            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                        )
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        lastAttachmentDocumentUri?.let {
                            putExtra(DocumentsContract.EXTRA_INITIAL_URI, it)
                        }
                    }
                }

                try {
                    startActivityForResult(intent, ATTACHMENT_READ_REQUEST_CODE)
                } catch (e: ActivityNotFoundException) {
                    pendingAttachmentReadResult?.error("systemPickerUnavailable", "当前设备无法打开系统文件选择器", null)
                    clearPendingAttachmentRead()
                } catch (e: Exception) {
                    pendingAttachmentReadResult?.error("unknown", "无法调起系统文件选择器", null)
                    clearPendingAttachmentRead()
                }
            } else if (call.method == "clearAttachmentPickerLocation") {
                lastAttachmentDocumentUri = null
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXTERNAL_URL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "openExternalUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val rawUrl = call.argument<String>("url")
            val uri = rawUrl?.let(Uri::parse)
            if (uri == null || uri.scheme != "https" || uri.host.isNullOrBlank()) {
                result.error("invalidUrl", "网页地址无效", null)
                return@setMethodCallHandler
            }
            try {
                val browserIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addCategory(Intent.CATEGORY_BROWSABLE)
                }
                startActivity(Intent.createChooser(browserIntent, "选择浏览器"))
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.error("noBrowserAvailable", "本机没有可打开网页的浏览器", null)
            } catch (e: Exception) {
                result.error("unknown", "无法打开网页", null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ATTACHMENT_EXTERNAL_OPEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "openAttachmentExternally") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val mimeType = call.argument<String>("mimeType")
            if (bytes == null || bytes.isEmpty() || mimeType.isNullOrBlank()) {
                result.error("invalidAttachment", "附件打开参数无效", null)
                return@setMethodCallHandler
            }
            var uri: Uri? = null
            try {
                val openedUri = AttachmentOpenRegistry.register(bytes, mimeType)
                uri = openedUri
                val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(openedUri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = android.content.ClipData.newRawUri("附件", openedUri)
                }
                startActivity(Intent.createChooser(viewIntent, "使用其他应用打开"))
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                uri?.let(AttachmentOpenRegistry::revoke) ?: bytes.fill(0)
                result.error("noAppAvailable", "本机没有可打开该附件的应用", null)
            } catch (e: Exception) {
                uri?.let(AttachmentOpenRegistry::revoke) ?: bytes.fill(0)
                result.error("unknown", "无法使用其他应用打开附件", null)
            }
        }

        // 3. 注册前台安全窗口通道；后台任务快照保护由原生生命周期负责。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anch/secure_window").setMethodCallHandler { call, result ->
            if (call.method == "setSecureWindowEnabled") {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("invalidParameter", "参数 enabled 缺失", null)
                    return@setMethodCallHandler
                }

                try {
                    foregroundSecureWindowEnabled = enabled
                    applySecureWindowProtection()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("failed", "设置窗口 FLAG_SECURE 失败", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != READ_REQUEST_CODE &&
            requestCode != ATTACHMENT_READ_REQUEST_CODE &&
            requestCode != STREAM_WRITE_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        if (requestCode == STREAM_WRITE_REQUEST_CODE) {
            val result = pendingStreamingWriteResult ?: return
            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.data
                if (uri == null) {
                    result.error("writeFailed", "备份文件写入失败，未获取到存储位置", null)
                    clearPendingStreamingWrite()
                    return
                }
                try {
                    val outputStream = contentResolver.openOutputStream(uri)
                    if (outputStream == null) {
                        logBackupStreamFailure(
                            phase = "open",
                            kind = "stream_unavailable",
                            wroteAny = false,
                        )
                        result.error("targetWriteFailed", "无法打开目标文件输出流", null)
                    } else {
                        streamingOutputStream = outputStream
                        streamingWrittenBytes = 0
                        result.success(mapOf("success" to true))
                    }
                } catch (e: SecurityException) {
                    result.error("permissionDenied", "系统未授予写入权限", null)
                } catch (e: IOException) {
                    result.error(
                        backupStreamFailureCode(
                            error = e,
                            phase = "open",
                            fallbackCode = "targetWriteFailed",
                            wroteAny = false,
                        ),
                        "无法打开目标文件输出流",
                        null,
                    )
                } catch (e: Exception) {
                    result.error("unknown", "无法打开目标文件输出流", null)
                } finally {
                    clearPendingStreamingWrite()
                }
            } else if (resultCode == Activity.RESULT_CANCELED) {
                result.error("userCancelled", "用户取消了导出操作", null)
                clearPendingStreamingWrite()
            } else {
                result.error("unknown", "导出未完成，请稍后重试", null)
                clearPendingStreamingWrite()
            }
        } else if (requestCode == READ_REQUEST_CODE) {
            val result = pendingReadResult ?: return

            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.data
                if (uri == null) {
                    result.error("readFailed", "备份文件读取失败，未获取到目标路径", null)
                    clearPendingRead()
                    return
                }

                lastAttachmentDocumentUri = uri

                var inputStream: java.io.InputStream? = null
                val byteBuffer = ByteArrayOutputStream()
                try {
                    inputStream = contentResolver.openInputStream(uri)
                    if (inputStream == null) {
                        result.error("fileUnavailable", "无法打开目标文件输入流", null)
                    } else {
                        val prefix = ByteArray(STREAM_V2_MAGIC.size)
                        var prefixLength = 0
                        while (prefixLength < prefix.size) {
                            val count = inputStream.read(prefix, prefixLength, prefix.size - prefixLength)
                            if (count == -1) break
                            prefixLength += count
                        }
                        if (prefixLength == STREAM_V2_MAGIC.size && isStreamingV2Magic(prefix)) {
                            streamingInputStream = inputStream
                            streamingInputPrefix = prefix
                            streamingInputSizeBytes = backupDocumentSize(uri)
                            streamingInputUri = uri
                            inputStream = null
                            result.error("streamV2Selected", "已选择流式备份文件", null)
                            return
                        }

                        val buffer = ByteArray(4096)
                        var bytesRead: Int
                        var totalBytes = prefixLength
                        val maxBytes = 50 * 1024 * 1024 // 50MB 物理上限熔断阈值

                        if (prefixLength > 0) {
                            byteBuffer.write(prefix, 0, prefixLength)
                        }
                        if (totalBytes > maxBytes) {
                            result.error("fileTooLarge", "备份文件体积超出 50MB 规格限制", null)
                            return
                        }

                        while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                            totalBytes += bytesRead
                            if (totalBytes > maxBytes) {
                                result.error("fileTooLarge", "备份文件体积超出 50MB 规格限制", null)
                                return
                            }
                            byteBuffer.write(buffer, 0, bytesRead)
                        }

                        val bytes = byteBuffer.toByteArray()
                        val resultMap = mapOf(
                            "success" to true,
                            "bytes" to bytes,
                            "readAt" to System.currentTimeMillis()
                        )
                        result.success(resultMap)
                    }
                } catch (e: SecurityException) {
                    result.error("permissionDenied", "系统未授予读取权限", null)
                } catch (e: IOException) {
                    result.error("readFailed", "备份文件读取失败", null)
                } catch (e: Exception) {
                    result.error("unknown", "读取未完成，未知错误", null)
                } finally {
                    try {
                        inputStream?.close()
                    } catch (ignored: Exception) {}
                    clearPendingRead()
                }
            } else if (resultCode == Activity.RESULT_CANCELED) {
                result.error("userCancelled", "用户取消了选择备份文件", null)
                clearPendingRead()
            } else {
                result.error("unknown", "读取未完成，请稍后重试", null)
                clearPendingRead()
            }
        } else if (requestCode == ATTACHMENT_READ_REQUEST_CODE) {
            val result = pendingAttachmentReadResult ?: return

            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.data
                if (uri == null) {
                    result.error("readFailed", "附件读取失败，未获取到文件", null)
                    clearPendingAttachmentRead()
                    return
                }

                val requestId = attachmentReadRequestId
                thread(name = "anch-attachment-read") {
                    val payload = readAttachmentPayload(uri)
                    runOnUiThread {
                        if (requestId != attachmentReadRequestId || pendingAttachmentReadResult !== result) {
                            payload.bytes?.fill(0)
                            return@runOnUiThread
                        }

                        val bytes = payload.bytes
                        if (bytes != null && payload.originalName != null && payload.mimeType != null) {
                            lastAttachmentDocumentUri = uri
                            result.success(
                                mapOf(
                                    "bytes" to bytes,
                                    "originalName" to payload.originalName,
                                    "mimeType" to payload.mimeType
                                )
                            )
                        } else {
                            result.error(
                                payload.errorCode ?: "unknown",
                                payload.errorMessage ?: "附件读取未完成",
                                null
                            )
                        }
                        clearPendingAttachmentRead()
                    }
                }
            } else if (resultCode == Activity.RESULT_CANCELED) {
                result.error("userCancelled", "用户取消了选择附件", null)
                clearPendingAttachmentRead()
            } else {
                result.error("unknown", "附件读取未完成，请稍后重试", null)
                clearPendingAttachmentRead()
            }
        }
    }

    private fun clearPendingRead() {
        pendingReadResult = null
    }

    private fun clearPendingStreamingWrite() {
        pendingStreamingWriteResult = null
    }

    private fun closeStreamingOutput() {
        try {
            streamingOutputStream?.close()
        } catch (ignored: Exception) {}
        streamingOutputStream = null
        streamingWrittenBytes = 0
    }

    /// 仅在 Debug 构建记录脱敏诊断，禁止输出异常消息、Uri、路径、文件名或任何资料内容。
    private fun backupStreamFailureCode(
        error: IOException,
        phase: String,
        fallbackCode: String,
        wroteAny: Boolean,
    ): String {
        val kind = backupStreamFailureKind(error)
        logBackupStreamFailure(phase = phase, kind = kind, wroteAny = wroteAny)
        return when (kind) {
            "no_space" -> "insufficientSpace"
            "interrupted", "broken_pipe" -> "writeInterrupted"
            else -> fallbackCode
        }
    }

    private fun backupStreamFailureKind(error: IOException): String {
        var current: Throwable? = error
        repeat(8) {
            val errno = (current as? ErrnoException)?.errno
            when (errno) {
                OsConstants.ENOSPC -> return "no_space"
                OsConstants.EINTR -> return "interrupted"
                OsConstants.EPIPE -> return "broken_pipe"
            }
            current = current?.cause
        }
        return if (error is InterruptedIOException) "interrupted" else "io"
    }

    private fun logBackupStreamFailure(
        phase: String,
        kind: String,
        wroteAny: Boolean,
    ) {
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.i(
                BACKUP_STREAM_DEBUG_TAG,
                "v2_export_failure phase=$phase kind=$kind wrote_any=$wroteAny",
            )
        }
    }

    private fun restartSelectedStreamingInput(): Boolean {
        val uri = streamingInputUri ?: return false
        closeStreamingInput(clearSelection = false)
        val inputStream = contentResolver.openInputStream(uri) ?: return false
        val prefix = ByteArray(STREAM_V2_MAGIC.size)
        var prefixLength = 0
        while (prefixLength < prefix.size) {
            val count = inputStream.read(prefix, prefixLength, prefix.size - prefixLength)
            if (count == -1) break
            prefixLength += count
        }
        if (prefixLength != prefix.size || !isStreamingV2Magic(prefix)) {
            inputStream.close()
            return false
        }
        streamingInputStream = inputStream
        streamingInputPrefix = prefix
        streamingInputSizeBytes = backupDocumentSize(uri)
        return true
    }

    private fun closeStreamingInput(clearSelection: Boolean = true) {
        try {
            streamingInputStream?.close()
        } catch (ignored: Exception) {}
        streamingInputStream = null
        streamingInputPrefix = null
        streamingInputSizeBytes = null
        if (clearSelection) streamingInputUri = null
    }

    private fun isStreamingV2Magic(bytes: ByteArray): Boolean {
        if (bytes.size != STREAM_V2_MAGIC.size) return false
        for (index in bytes.indices) {
            if (bytes[index] != STREAM_V2_MAGIC[index]) return false
        }
        return true
    }

    private fun backupDocumentSize(uri: Uri): Long? {
        var cursor: android.database.Cursor? = null
        try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val columnIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (columnIndex >= 0 && !cursor.isNull(columnIndex)) {
                    return cursor.getLong(columnIndex)
                }
            }
        } catch (ignored: Exception) {
        } finally {
            try {
                cursor?.close()
            } catch (ignored: Exception) {}
        }
        return null
    }

    private fun attachmentDisplayName(uri: Uri): String {
        var cursor: android.database.Cursor? = null
        try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val columnIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (columnIndex >= 0) {
                    val displayName = cursor.getString(columnIndex)
                    if (!displayName.isNullOrBlank()) return displayName
                }
            }
        } catch (ignored: Exception) {
        } finally {
            try {
                cursor?.close()
            } catch (ignored: Exception) {}
        }
        return "附件"
    }

    private fun clearPendingAttachmentRead() {
        pendingAttachmentReadResult = null
        attachmentReadRequestId += 1
    }

    private fun readAttachmentPayload(uri: Uri): AttachmentReadPayload {
        var inputStream: java.io.InputStream? = null
        val byteBuffer = ByteArrayOutputStream()
        try {
            inputStream = contentResolver.openInputStream(uri)
                ?: return AttachmentReadPayload(
                    errorCode = "fileUnavailable",
                    errorMessage = "无法读取所选附件"
                )
            val buffer = ByteArray(64 * 1024)
            var bytesRead: Int
            var totalBytes = 0
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                totalBytes += bytesRead
                if (totalBytes > MAX_ATTACHMENT_BYTES) {
                    return AttachmentReadPayload(
                        errorCode = "fileTooLarge",
                        errorMessage = "附件不能超过 20 MB"
                    )
                }
                byteBuffer.write(buffer, 0, bytesRead)
            }
            return AttachmentReadPayload(
                bytes = byteBuffer.toByteArray(),
                originalName = attachmentDisplayName(uri),
                mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
            )
        } catch (e: SecurityException) {
            return AttachmentReadPayload(
                errorCode = "permissionDenied",
                errorMessage = "系统未授予读取附件权限"
            )
        } catch (e: IOException) {
            return AttachmentReadPayload(
                errorCode = "readFailed",
                errorMessage = "附件读取失败"
            )
        } catch (e: Exception) {
            return AttachmentReadPayload(
                errorCode = "unknown",
                errorMessage = "附件读取未完成"
            )
        } finally {
            try {
                inputStream?.close()
            } catch (ignored: Exception) {}
        }
    }

    override fun onDestroy() {
        strongBiometricBridge?.dispose()
        strongBiometricBridge = null
        clearPendingAttachmentRead()
        lastAttachmentDocumentUri = null
        closeStreamingOutput()
        closeStreamingInput()
        super.onDestroy()
    }

}
