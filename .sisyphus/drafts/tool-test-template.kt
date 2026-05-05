package com.agent.aios.tools

import android.content.Context
import com.agent.aios.domain.ToolContext
import com.agent.aios.service.AIOSAccessibilityService
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Tool Test Template — 복사하여 사용하세요.
 *
 * 클래스명 규칙: {ToolName}Test.kt (예: SmartWaitToolTest.kt)
 * 함수명 규칙: {method}_{scenario}_expectedResult()
 *
 * 테스트 범위 (TESTING.md §4):
 * - Happy path: 1 test per action
 * - Edge case: missing required params, empty input, boundary values
 * - Error path: service null, permission denied, unknown action
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE)
class ToolTestTemplate {

    // ==================== Setup ====================

    private lateinit var mockService: AIOSAccessibilityService
    private lateinit var mockContext: Context
    private lateinit var toolContext: ToolContext

    @Before
    fun setup() {
        // 1. Mock android.util.Log (모든 테스트에서 필수)
        mockkStatic(android.util.Log::class)
        every { android.util.Log.i(any(), any()) } returns 0
        every { android.util.Log.e(any(), any(), any()) } returns 0
        every { android.util.Log.d(any(), any()) } returns 0
        every { android.util.Log.w(any(), any<String>()) } returns 0

        // 2. Mock AIOSAccessibilityService
        mockService = mockk(relaxed = true)

        // 3. Mock Context
        mockContext = mockk(relaxed = true)

        // 4. Create ToolContext
        toolContext = ToolContext(
            appContext = mockContext,
            accessibilityService = { mockService }
        )
    }

    @After
    fun tearDown() {
        unmockkStatic(android.util.Log::class)
    }

    // ==================== Helper Methods ====================

    /**
     * ToolContext with null accessibility service.
     * Use for testing "service not enabled" error paths.
     */
    private fun nullServiceToolContext(): ToolContext = ToolContext(
        appContext = mockContext,
        accessibilityService = { null }
    )

    // ==================== Example: Action Dispatch Tests ====================

    // @Test
    // fun execute_{action}_{scenario}_expectedResult() {
    //     val tool = MyTool()
    //     val args = """{"action": "my_action", "param": "value"}"""
    //
    //     // Setup mocks
    //     every { mockService.someMethod(any()) } returns expectedResult
    //
    //     val result = tool.execute(args, toolContext)
    //
    //     // Assert
    //     assertTrue(result.contains("expected content"))
    //     assertFalse(result.startsWith("Error:"))
    // }

    // ==================== Required Test Patterns ====================

    // Pattern 1: Happy path per action
    // @Test
    // fun execute_{action}_withValidParams_returnsSuccess() { ... }

    // Pattern 2: Missing required parameter
    // @Test
    // fun execute_{action}_missingParam_returnsError() {
    //     val tool = MyTool()
    //     val result = tool.execute("""{"action": "my_action"}""", toolContext)
    //     assertTrue(result.startsWith("Error:"))
    //     assertTrue(result.contains("required"))
    // }

    // Pattern 3: Unknown action
    // @Test
    // fun execute_unknownAction_returnsError() {
    //     val tool = MyTool()
    //     val result = tool.execute("""{"action": "nonexistent"}""", toolContext)
    //     assertTrue(result.startsWith("Error:"))
    //     assertTrue(result.contains("Unknown action"))
    // }

    // Pattern 4: Service not enabled (ExtendedTool only)
    // @Test
    // fun execute_serviceNull_returnsError() {
    //     val tool = MyTool()
    //     val result = tool.execute("""{"action": "my_action"}""", nullServiceToolContext())
    //     assertEquals("Error: Accessibility service not enabled", result)
    // }
}
