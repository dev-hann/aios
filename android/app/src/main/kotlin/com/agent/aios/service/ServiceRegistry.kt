package com.agent.aios.service

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ServiceRegistry @Inject constructor() {
    private val _accessibilityService = MutableStateFlow<AIOSAccessibilityService?>(null)
    val accessibilityService: StateFlow<AIOSAccessibilityService?> = _accessibilityService.asStateFlow()

    private val _notificationService = MutableStateFlow<NotificationListener?>(null)
    val notificationService: StateFlow<NotificationListener?> = _notificationService.asStateFlow()

    fun setAccessibilityService(service: AIOSAccessibilityService?) {
        _accessibilityService.value = service
    }

    fun setNotificationService(service: NotificationListener?) {
        _notificationService.value = service
    }
}
