package com.finkit.mobile

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

/**
 * Telefonun kendi gezinme çubuğunu (geri/home/recents) uygulama açıkken gizler.
 *
 * Flutter tarafındaki `SystemChrome` çağrısı bazı üretici ROM'larında ve klavye
 * açılıp kapandıktan sonra çubuğu geri getiriyor. Bu yüzden gizleme işlemi
 * pencere odağı her değiştiğinde native tarafta yeniden uygulanır.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Sistem çubuklarının arkasına çizim yapılabilmesi için kenardan kenara yerleşim.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        hideSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemBars()
    }

    override fun onResume() {
        super.onResume()
        hideSystemBars()
    }

    private fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            val controller = window.insetsController ?: return
            controller.hide(WindowInsets.Type.navigationBars())
            controller.systemBarsBehavior =
                WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
        }
        val compat = WindowInsetsControllerCompat(window, window.decorView)
        compat.hide(WindowInsetsCompat.Type.navigationBars())
        compat.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
}
