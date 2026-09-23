allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 统一强制所有 Android 模块（含 Flutter 插件如 :app_links）使用本地已安装的 android-37。
// 原因：本机未安装完整 android-36（仅有失败安装留下的残缺目录），而 Flutter 默认
// compileSdk=36 会触发 SDK 自动下载并被沙箱拦截导致构建失败。反射调用以兼容 AGP 8/9 API。
// 注意：必须注册在 evaluationDependsOn(":app") 之前，否则项目已被求值会抛
// "Cannot run Project.afterEvaluate(Action) when the project is already evaluated"。
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        val setter = androidExtension.javaClass.methods.firstOrNull { m ->
            m.name == "setCompileSdk" && m.parameterCount == 1 &&
                m.parameterTypes[0] == Integer.TYPE
        }
        if (setter != null) {
            setter.invoke(androidExtension, 37)
        } else {
            val legacy = androidExtension.javaClass.methods.firstOrNull { m ->
                m.name == "compileSdkVersion" && m.parameterCount == 1 &&
                    m.parameterTypes[0] == Integer.TYPE
            }
            legacy?.invoke(androidExtension, 37)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
