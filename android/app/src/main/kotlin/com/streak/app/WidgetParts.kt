package com.streak.app

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.layout.Column
import androidx.glance.layout.size
import androidx.glance.unit.ColorProvider

@Composable
fun Glyph(res: Int, size: Dp, tint: Color? = null) {
    Image(
        provider = ImageProvider(res),
        contentDescription = null,
        colorFilter = tint?.let { ColorFilter.tint(ColorProvider(it)) },
        modifier = GlanceModifier.size(size),
    )
}

@Composable
fun Flame(size: Dp) {
    Image(
        provider = ImageProvider(R.drawable.widget_flame_3d),
        contentDescription = null,
        modifier = GlanceModifier.size(size),
    )
}

@Composable
fun EmptyNote(text: String, style: WidgetStyle) {
    val context = LocalContext.current
    val density = WidgetDraw.density(context)
    val room = LocalSize.current.width.value - 28f
    Column {
        text.lines().forEach { line ->
            Drawn(WidgetDraw.text(context, line, 13f, style.muted, 600, room), density, line)
        }
    }
}
