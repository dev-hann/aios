package com.agent.aios.ui.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.agent.aios.ui.theme.AIOSColors

@Composable
fun MessageBubble(
    role: String,
    text: String,
    toolName: String = "",
    toolArgs: String = "",
    toolResult: String = "",
    modifier: Modifier = Modifier,
) {
    val isUser = role == "user"

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 3.dp),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
        verticalAlignment = Alignment.Bottom,
    ) {
        if (!isUser) {
            AIOSAvatar(role)
            Spacer(modifier = Modifier.width(8.dp))
        }

        Column(
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

            Box(
                modifier = Modifier
                    .clip(
                        RoundedCornerShape(
                            topStart = 20.dp,
                            topEnd = 20.dp,
                            bottomStart = if (isUser) 20.dp else 4.dp,
                            bottomEnd = if (isUser) 4.dp else 20.dp,
                        )
                    )
                    .background(bgColor)
                    .then(
                        if (isUser) Modifier else Modifier
                    )
                    .padding(horizontal = 16.dp, vertical = 10.dp),
            ) {
                Column {
                    Text(
                        text = text,
                        color = textColor,
                        fontSize = if (role == "system") 13.sp else 15.sp,
                        lineHeight = if (role == "system") 18.sp else 21.sp,
                        fontFamily = if (role == "system") FontFamily.Monospace else FontFamily.Default,
                        fontWeight = if (role == "agent_answer") FontWeight.Medium else FontWeight.Normal,
                    )
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
                        Box(
                            modifier = Modifier
                                .padding(top = 6.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.Black.copy(alpha = 0.2f))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = toolResult.take(400),
                                color = textColor.copy(alpha = 0.7f),
                                fontSize = 12.sp,
                                fontFamily = FontFamily.Monospace,
                                lineHeight = 16.sp,
                            )
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
