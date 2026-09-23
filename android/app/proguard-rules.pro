# 2026-09-17 体积优化：release 启用 R8 的完整配置。
# 取舍与「不要写宽泛 -keep」的教训见 README 的构建配置说明。
#
# 【血泪教训】不要在这里写 -keep class androidx.** / io.flutter.** 之类的宽泛规则。
#   实测：加上 `-keep class androidx.core.** { *; }` + `-keep class androidx.lifecycle.** { *; }`
#        + `-keep class androidx.datastore.** { *; }` + `-keep class io.flutter.** { *; }`
#        后，classes.dex 从 1.10 MB 涨到 4.30 MB（classDefs 1,231 → 5,354），
#        resources.arsc 90,860 → 214,704，arm64 包反而变大。
#   原因：-keep 会把整棵依赖树钉死，并且**不去混淆**，把大量本来会被裁掉的类一起拖进来。
#   正确做法：依赖各 AAR 自带的 consumer ProGuard rules（Flutter embedding 自带 keep），
#            这里只补「R8 静态分析看不见」的反射/JNI 入口。

# ---------- R8 分析不到的反射入口（必须） ----------
# MainActivity 由 AndroidManifest 引用，AGP 已自动保留；此处显式声明防未来改名漏掉。
-keep public class com.torrentmanager.MainActivity { *; }

# 插件注册表是 GeneratedPluginRegistrant 反射调用 FlutterEngine.getPlugins().add(...) 的入口
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# ---------- JNI ----------
# libdartjni.so / libdatastore_shared_counter.so 通过 native 方法回调 Java
-keepclasseswithmembers class * {
    native <methods>;
}
-keepclassmembers class * {
    native <methods>;
}

# ---------- 缺失依赖的告警抑制（必须，否则 :app:minifyReleaseWithR8 直接失败） ----------
# Flutter embedding 的 FlutterPlayStoreSplitApplication / PlayStoreDeferredComponentManager
# 会引用 com.google.android.play.core.*，但本项目未引入 com.google.android.play:core。
# 该规则由 AGP 自动生成在 build/app/outputs/mapping/release/missing_rules.txt。
-dontwarn com.google.android.play.core.**

# ---------- 其余交给默认的 proguard-android-optimize.txt + 库的 consumer rules ----------
# 允许 R8 混淆与彻底收缩：这是本机能把 dex 压到约 1.1 MB 的关键。
