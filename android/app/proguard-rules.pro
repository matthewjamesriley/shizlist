# Flutter image_picker plugin
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep all Flutter plugins
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }

# Don't warn about missing classes
-dontwarn io.flutter.plugins.imagepicker.**

# Google Play Core (deferred components) - suppress warnings for optional features
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

