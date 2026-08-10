package com.lockdin.lockdin_app

object PictureInPictureInterventionPolicy {
    const val MAX_ATTEMPTS = 6

    fun matchesTargetWindow(
        targetPackageName: String,
        windowPackageName: String?,
        isInPictureInPictureMode: Boolean,
    ): Boolean {
        return isInPictureInPictureMode &&
            targetPackageName.isNotBlank() &&
            windowPackageName == targetPackageName
    }

    fun shouldRetry(attempt: Int): Boolean = attempt + 1 < MAX_ATTEMPTS
}
