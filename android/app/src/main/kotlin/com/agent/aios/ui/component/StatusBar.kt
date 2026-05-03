package com.agent.aios.ui.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.agent.aios.domain.model.ServiceState
import com.agent.aios.ui.theme.AIOSColors

@Composable
fun StatusBar(
    state: ServiceState,
    modifier: Modifier = Modifier,
) {
    val (color, label) =
        when (state) {
            ServiceState.DISCONNECTED -> AIOSColors.StatusIdle to "Offline"
            ServiceState.CONNECTING -> AIOSColors.StatusRunning to "Connecting"
            ServiceState.READY -> AIOSColors.StatusIdle to "Ready"
            ServiceState.MODEL_LOADED -> AIOSColors.StatusReady to "Online"
            ServiceState.GENERATING -> AIOSColors.StatusRunning to "Generating"
            ServiceState.AGENT_RUNNING -> AIOSColors.Accent to "Agent Active"
        }

    val isAnimating =
        state == ServiceState.GENERATING ||
            state == ServiceState.AGENT_RUNNING ||
            state == ServiceState.CONNECTING

    val infiniteTransition = rememberInfiniteTransition()
    val pulse by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1f,
        animationSpec =
            infiniteRepeatable(
                animation = tween(800),
                repeatMode = RepeatMode.Reverse,
            ),
        label = "pulse",
    )

    val animatedColor by animateColorAsState(
        targetValue = color,
        animationSpec = tween(300),
        label = "statusColor",
    )

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = modifier,
    ) {
        androidx.compose.foundation.layout.Box(
            modifier =
                Modifier
                    .size(7.dp)
                    .clip(CircleShape)
                    .background(
                        if (isAnimating) animatedColor.copy(alpha = pulse) else animatedColor,
                    ),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = animatedColor,
        )
    }
}
