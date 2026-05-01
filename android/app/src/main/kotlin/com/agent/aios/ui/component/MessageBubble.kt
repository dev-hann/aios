package com.agent.aios.ui.component

import android.widget.Toast
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.ui.theme.AIOSColors

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    role: String,
    text: String,
    toolName: String = "",
    toolArgs: String = "",
    toolResult: String = "",
    isStreaming: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val isUser = role == "user"
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 5.dp),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Bottom,
    ) {
        if (!isUser) {
            AIOSAvatar(role)
            Spacer(modifier = Modifier.width(8.dp))
        }

        Column(
            modifier = Modifier.fillMaxWidth(if (isUser) 0.75f else 0.85f),
            horizontalAlignment = if (isUser) Alignment.End else Alignment.Start,
        ) {
            if (role in listOf("agent_think", "agent_action", "agent_obs")) {
                val labelColor = when (role) {
                    "agent_think" -> AIOSColors.AgentThought
                    "agent_action" -> AIOSColors.AgentAction
                    "agent_obs" -> AIOSColors.AgentObservation
                    else -> AIOSColors.TextTertiary
                }
                val labelText = when (role) {
                    "agent_think" -> "THINKING"
                    "agent_action" -> "ACTION: $toolName"
                    "agent_obs" -> "OBSERVATION"
                    else -> ""
                }
                Text(
                    text = labelText,
                    style = MaterialTheme.typography.labelSmall,
                    color = labelColor,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(start = 4.dp, bottom = 3.dp, top = 8.dp),
                )
            }

            val (bgColor, textColor) = when (role) {
                "user" -> AIOSColors.UserBubble to Color.White
                "assistant", "agent_answer" -> AIOSColors.AssistantBubble to AIOSColors.TextPrimary
                "agent_think" -> AIOSColors.AgentThinkBubble to AIOSColors.AgentThought
                "agent_action" -> AIOSColors.AgentActionBubble to AIOSColors.AgentAction
                "agent_obs" -> AIOSColors.AgentObsBubble to AIOSColors.AgentObservation
                else -> AIOSColors.SurfaceVariant to AIOSColors.TextTertiary
            }

            val bubbleBackground = if (isUser) {
                Brush.verticalGradient(
                    colors = listOf(AIOSColors.Primary, AIOSColors.Primary.copy(alpha = 0.8f))
                )
            } else {
                Brush.verticalGradient(colors = listOf(bgColor, bgColor))
            }

            Box(
                modifier = Modifier
                    .animateContentSize(animationSpec = tween(300))
                    .clip(
                        RoundedCornerShape(
                            topStart = 20.dp,
                            topEnd = 20.dp,
                            bottomStart = if (isUser) 20.dp else 4.dp,
                            bottomEnd = if (isUser) 4.dp else 20.dp,
                        )
                    )
                    .background(bubbleBackground)
                    .combinedClickable(
                        onClick = {},
                        onLongClick = {
                            if (text.isNotBlank()) {
                                clipboardManager.setText(AnnotatedString(text))
                                Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show()
                            }
                        }
                    )
                    .padding(horizontal = 16.dp, vertical = 10.dp),
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = text,
                            color = textColor,
                            fontSize = if (role == "system") 13.sp else 15.sp,
                            lineHeight = if (role == "system") 18.sp else 21.sp,
                            fontFamily = if (role == "system") FontFamily.Monospace else FontFamily.Default,
                            fontWeight = if (role == "agent_answer") FontWeight.Medium else FontWeight.Normal,
                            modifier = Modifier.weight(1f, fill = false),
                        )
                        if (isStreaming && text.isNotEmpty()) {
                            StreamingCursor(color = textColor)
                        }
                    }
                    if (role == "agent_action" && toolArgs.isNotBlank()) {
                        Box(
                            modifier = Modifier
                                .padding(top = 6.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.Black.copy(alpha = 0.2f))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = toolArgs,
                                color = textColor.copy(alpha = 0.7f),
                                fontSize = 12.sp,
                                fontFamily = FontFamily.Monospace,
                            )
                        }
                    }
                    if (role == "agent_obs" && toolResult.isNotBlank()) {
                        var isExpanded by remember { mutableStateOf(false) }

                        Box(
                            modifier = Modifier
                                .animateContentSize(animationSpec = tween(300))
                                .padding(top = 6.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.Black.copy(alpha = 0.2f))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Column {
                                Text(
                                    text = if (isExpanded) toolResult else toolResult.take(150),
                                    color = textColor.copy(alpha = 0.7f),
                                    fontSize = 12.sp,
                                    fontFamily = FontFamily.Monospace,
                                    lineHeight = 16.sp,
                                )
                                if (toolResult.length > 150) {
                                    Text(
                                        text = if (isExpanded) "Show less" else "Show more",
                                        color = textColor,
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Medium,
                                        modifier = Modifier
                                            .padding(top = 4.dp)
                                            .clickable { isExpanded = !isExpanded },
                                    )
                                }
                            }
                        }
                    }
                }
            }

            if (isUser) {
                Spacer(modifier = Modifier.width(8.dp))
            }
        }

        if (isUser) {
            UserAvatar()
        }
    }
}

@Composable
private fun StreamingCursor(color: Color) {
    val infiniteTransition = rememberInfiniteTransition()
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "cursor_blink",
    )
    Box(
        modifier = Modifier
            .padding(start = 2.dp)
            .size(width = 2.dp, height = 16.dp)
            .clip(RoundedCornerShape(1.dp))
            .background(color.copy(alpha = alpha)),
    )
}

@Composable
private fun AIOSAvatar(role: String) {
    val (bg, icon) = when (role) {
        "assistant", "agent_answer" -> AIOSColors.Primary to "AI"
        "agent_think" -> AIOSColors.AgentThought to "T"
        "agent_action" -> AIOSColors.AgentAction to "A"
        "agent_obs" -> AIOSColors.AgentObservation to "O"
        else -> AIOSColors.SurfaceVariant to "?"
    }
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(bg),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = icon,
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun UserAvatar() {
    Box(
        modifier = Modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    colors = listOf(AIOSColors.Secondary, AIOSColors.Primary)
                )
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "U",
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
