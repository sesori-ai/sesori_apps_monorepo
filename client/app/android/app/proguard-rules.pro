# Preserve Singular SDK classes used through reflection and the Flutter method channel.
-keep class com.singular.sdk.** { *; }

# Preserve Android Install Referrer classes used for install attribution.
-keep public class com.android.installreferrer.** { *; }
