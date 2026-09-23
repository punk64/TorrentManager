import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.torrentmanager"
    // 本地 Android SDK 只安装了 android-37，而 Flutter 默认 compileSdk=36 缺平台，故指向已装的 37
    compileSdk = 37
    // 本地已装 NDK 28.2.13676358，显式指定避免 AGP 重新下载
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 正式签名配置（替代 AGP 默认的 debug 证书）。
    // 关键点：强制开启 v1(JAR) 签名。AGP 在 minSdk >= 24 时会自动关闭 v1，
    // 只保留 v2；但华为/荣耀的定制安装器常去检查 META-INF 下的 v1 证书，
    // 找不到就报「该安装包未包含任何证书」或归类为「解析包时出现问题」。
    // 同时把证书从 CN=Android Debug 换成正式主体，避免被国产 ROM 判为测试包。
    signingConfigs {
        create("release") {
            // ⚠️ 口令**不能硬编码在这个文件里** —— 它一旦随源码外发，就等于把
            //    签名私钥的钥匙一并交出去了。
            //    改为从 `android/key.properties` 读取（该文件已被 .gitignore 排除），
            //    或退而读环境变量 TORRENTMANAGER_STORE_PASSWORD / _KEY_PASSWORD。
            //    两者都缺 → 口令为空，release 签名会失败，此时请补齐 key.properties。
            // ⚠️ 必须显式 import `Properties`（见文件顶部）：在 `android {}` 块**内**
            //    写 `java.util.Properties()` 会解析失败 —— 这里的 `java` 被 Android 的
            //    `java` extension 遮蔽了（Unresolved reference 'util'）。
            val kp = Properties()
            val kpFile = rootProject.file("key.properties")
            if (kpFile.exists()) {
                kpFile.inputStream().use { stream -> kp.load(stream) }
            }
            // 密钥库文件名默认 torrentmanager-release.jks；想用自己的文件名与位置，
            // 在 key.properties 里加一行 storeFile=<路径>（相对路径以 android/app/ 为基准）。
            storeFile = file(kp.getProperty("storeFile") ?: "torrentmanager-release.jks")
            storePassword = kp.getProperty("storePassword")
                ?: System.getenv("TORRENTMANAGER_STORE_PASSWORD") ?: ""
            keyAlias = kp.getProperty("keyAlias")
                ?: System.getenv("TORRENTMANAGER_KEY_ALIAS") ?: "torrentmanager"
            keyPassword = kp.getProperty("keyPassword")
                ?: System.getenv("TORRENTMANAGER_KEY_PASSWORD") ?: ""
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.torrentmanager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 从 pubspec.yaml 读取版本号。缺这两行会让 APK 的 versionCode / versionName
        // 变为空值，部分设备与商店会因此拒绝安装。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 默认用上面配置的正式密钥库。构建时加 `-PtmDebugSign=true`
            // （等价环境变量 ORG_GRADLE_PROJECT_tmDebugSign=true）则改用调试证书 ——
            // 供没有密钥库、只想把工程编译起来试跑的人使用。
            // ⚠️ 调试签名的包**不能覆盖安装正式版**（签名不同，系统会拒绝）。
            signingConfig = signingConfigs.getByName(
                if (project.findProperty("tmDebugSign") == "true") "debug" else "release")
            // 2026-09-17 体积优化：启用 R8 收缩 + 混淆 + 无用资源剔除。
            //
            // 【复盘】本轮曾一度判成「R8 让包变大」而关掉，
            //   真相是 proguard-rules.pro 里写了 -keep class androidx.** / io.flutter.**
            //   这类宽泛规则（-keep 同时禁止混淆），把整棵依赖树钉死。
            //   改成最小规则集后：classes.dex 4.30 MB → 约 1.1 MB（classDefs 5,354 → ~1,231）。
            //   最小规则集见 `proguard-rules.pro` 的注释。
            isMinifyEnabled = true
            isShrinkResources = true
            // ⚠️ AGP 9 不再支持 getDefaultProguardFile("proguard-android.txt")（自带 -dontoptimize）
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // ★★★ 2026-09-23 铁律：本块的默认包型（**不压缩 = STORED**）与 `release.py` 的
    //    `run_checks()` 期望值**互为镜像** —— 改一边必须同时改另一边。当天出现过一次
    //    「只把本文件改成压缩、release.py 没跟着改」⇒ 构建成功但断言必 FAIL、版本号不推进
    //    （`write_version` 在断言之后）的卡发版故障。判断开关是否真生效**只看产物里 so 的
    //    压缩态与体积**，别信"构建有没有报错"。
    //
    // ⚠️ 2026-09-20（推荐落地步骤②）：lite 包开关**参数化**。
    //    标准包（默认，不带 -Plite）：useLegacyPackaging=false → so STORED（不压缩），
    //      设备直接 mmap、只一份、启动快、占用小（≈22.82 MB）。
    //    lite 包（命令行带 -Plite）：useLegacyPackaging=true → so 被 DEFLATE 压缩，
    //      下载体积减半（≈11~13 MB），但安装后多一份解压副本（占用 +38%），且首装慢一步。
    //    ⚠️ **2026-09-20 用户决定：以后不再编译 lite 包** —— 日常构建**一律不带**
    //    `--android-project-arg`（即标准包）。本开关保留仅为留档，**别再启用 lite**。
    //    （2026-09-23 用户再次确认：so 不压缩、体积保持 22.82 MB 档。）
    //    （若将来确要恢复 lite，按下面的命令与「先 lite→改名→再标准」顺序走，
    //     并自查 APK 内 so 的压缩方式确为 DEFLATED。）
    //    切换只需在 `flutter build apk` 时加 `--android-project-arg=lite=true`
    //    （flutter 原生开关，等价于 `-Plite=true`，直接透传给 gradle 的 `-P`）；
    //    **不必再手改本文件**，从根本上消除「改完忘还原 → 下次全编成 lite」的回归风险
    //    （上一轮就是这么踩的）。
    //
    //    ⚠️ 别用环境变量 `ORG_GRADLE_PROJECT_lite=true` 驱动：2026-09-20 实测
    //    **传不到 gradle**（产物与标准包字节级相同、`useLegacyPackaging` 仍为 false，
    //    且第二次构建被判定 up-to-date 只用了 8 秒 —— 两次配置其实一样）。
    //    flutter 的 `-P` / `--android-project-arg` 才是受支持的通道。
    //    ⚠️ manifest 里**不许**再显式写 `android:extractNativeLibs`：AGP 9 下它与本开关
    //    冲突会**直接构建失败**（"Avoid setting ... explicitly ... instead set
    //    ...useLegacyPackaging"）。已按 AGP 建议从 AndroidManifest.xml 移除，
    //    由本块**单一来源派生**（标准→false，lite→true）。2026-09-20 实测。
    //
    //    ⚠️ 产物命名：**AGP 9 已移除 `defaultConfig.archivesBaseName`**
    //    （`android.newDsl=true` 为 AGP 9.0 起默认，该属性被删；2026-09-20 实测加它直接
    //     `Unresolved reference 'archivesBaseName'` → 编译失败）。
    //    所以 lite 包的 `-lite` 后缀**不能**在 gradle 里改，改为**构建后重命名**：
    //    lite 先编 → 重命名为 `app-<abi>-release-lite.apk` → 再编标准包（保留规范的
    //    `app-<abi>-release.apk`）。顺序不能反，否则标准包会被 lite 同名产物覆盖。
    packaging {
        jniLibs {
            useLegacyPackaging = project.hasProperty("lite")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
