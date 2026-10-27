package icu.codealive.anch

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class StrongBiometricBridge(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private var prompt: BiometricPrompt? = null
    private var pendingResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailability" -> result.success(availability())
            "authenticate" -> authenticate(result)
            "cancel" -> {
                cancelAuthentication()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(): String {
        return when (
            BiometricManager.from(activity).canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG,
            )
        ) {
            BiometricManager.BIOMETRIC_SUCCESS -> "available"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "notEnrolled"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "noHardware"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "temporarilyUnavailable"
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> "securityUpdateRequired"
            else -> "unsupported"
        }
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.success("busy")
            return
        }
        if (availability() != "available") {
            result.success("unavailable")
            return
        }

        pendingResult = result
        try {
            val executor = ContextCompat.getMainExecutor(activity)
            prompt = BiometricPrompt(
                activity,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        authenticationResult: BiometricPrompt.AuthenticationResult,
                    ) {
                        complete("success")
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        val status = when (errorCode) {
                            BiometricPrompt.ERROR_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_USER_CANCELED
                            -> "cancelled"
                            BiometricPrompt.ERROR_LOCKOUT,
                            BiometricPrompt.ERROR_LOCKOUT_PERMANENT
                            -> "lockedOut"
                            else -> "unavailable"
                        }
                        complete(status)
                    }
                },
            )
            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("使用生物识别解锁安册")
                .setSubtitle("仅接受本机强指纹或强人脸识别")
                .setNegativeButtonText("使用安册 PIN")
                .setConfirmationRequired(true)
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()
            prompt?.authenticate(promptInfo)
        } catch (_: RuntimeException) {
            complete("unavailable")
        }
    }

    private fun complete(status: String) {
        val result = pendingResult ?: return
        pendingResult = null
        prompt = null
        result.success(status)
    }

    private fun cancelAuthentication() {
        val activePrompt = prompt
        complete("cancelled")
        activePrompt?.cancelAuthentication()
    }

    fun dispose() {
        cancelAuthentication()
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val CHANNEL = "anch/strong_biometric"
    }
}
