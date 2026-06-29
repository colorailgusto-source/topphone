# ===== Flutter Engine =====
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ===== Stripe SDK =====
-keep class com.stripe.android.** { *; }
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.stripe.android.**

# ===== Firebase / Google Play Services =====
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ===== OkHttp / Retrofit (usati da Supabase) =====
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ===== Gson / kotlinx.serialization (usati da Supabase/Gotrue) =====
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.json.** { *; }

# ===== Kotlin =====
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ===== Plugin Flutter — package locali =====
# Mantieni MainActivity e GeneratedPluginRegistrant
-keep class com.topphone.topphone.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ===== Generic Android (callback nativi, JNI) =====
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ===== Mantieni nomi delle eccezioni per stack trace leggibili =====
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ===== App Links / Deep Links =====
-keep class com.llfbandit.app_links.** { *; }

# ===== WebView =====
-keep class * extends android.webkit.WebViewClient
-keep class * extends android.webkit.WebChromeClient

# ===== Image Picker =====
-keep class androidx.lifecycle.** { *; }

# ===== Coroutines =====
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.flow.**
