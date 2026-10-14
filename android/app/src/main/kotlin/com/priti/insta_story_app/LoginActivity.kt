package com.priti.insta_story_app

import android.annotation.SuppressLint
import android.app.Activity
import android.os.Bundle
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.File

/**
 * Shows Instagram's own login page. Once a session cookie appears, the cookies are exported
 * in Netscape format so yt-dlp can fetch reels the way a logged-in browser would.
 */
class LoginActivity : Activity() {

    private lateinit var webView: WebView

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Sign in to Instagram"
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            // Instagram treats the "; wv" WebView marker as an embedded browser and may refuse login.
            settings.userAgentString = settings.userAgentString.replace("; wv", "")
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    if (exportCookies(this@LoginActivity)) {
                        setResult(RESULT_OK)
                        finish()
                    }
                }
            }
        }
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
        setContentView(webView)
        webView.loadUrl("https://www.instagram.com/accounts/login/")
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) webView.goBack() else super.onBackPressed()
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }

    companion object {
        fun cookieFile(activity: Activity) = File(activity.filesDir, "instagram_cookies.txt")

        /** Writes cookies.txt once Instagram has issued a session; returns whether it did. */
        fun exportCookies(activity: Activity): Boolean {
            val manager = CookieManager.getInstance()
            manager.flush()
            val raw = manager.getCookie("https://www.instagram.com") ?: return false
            val cookies = raw.split(';')
                .map { it.trim() }
                .filter { '=' in it }
                .associate { it.substringBefore('=') to it.substringAfter('=') }
            if (cookies["sessionid"].isNullOrEmpty()) return false

            // CookieManager doesn't expose expiry, so give each cookie a year; Instagram rotates them anyway.
            val expiry = System.currentTimeMillis() / 1000 + 365L * 24 * 3600
            val lines = buildString {
                appendLine("# Netscape HTTP Cookie File")
                cookies.forEach { (name, value) ->
                    appendLine(".instagram.com\tTRUE\t/\tTRUE\t$expiry\t$name\t$value")
                }
            }
            cookieFile(activity).writeText(lines)
            return true
        }

        fun signOut(activity: Activity) {
            cookieFile(activity).delete()
            CookieManager.getInstance().removeAllCookies(null)
            CookieManager.getInstance().flush()
        }
    }
}
