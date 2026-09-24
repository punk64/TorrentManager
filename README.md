# TorrentManager

> Flutter + GetX 实现的 **qBittorrent / Transmission 远程种子管理器**（Android）。
>
> 用手机管理局域网或公网上的下载服务器：查看种子列表与实时速度、增删种子、
> 管理 Tracker 与文件优先级、查看 Peers 与下载器日志，并支持主题 / 壁纸自定义。
>
> 预编译的 APK 见本仓库的 **Releases** 页面。
>
> 项目主页：<https://github.com/punk64/TorrentManager> —— 以 **MIT License** 开源。

---

## ✨ 界面预览

| 服务器列表 | 种子列表 | 种子详情 |
| :---: | :---: | :---: |
| ![服务器列表](docs/screenshots/server_list.png) | ![种子列表](docs/screenshots/torrent_list.png) | ![种子详情](docs/screenshots/torrent_detail.png) |

---

## 一、开发环境

| 项 | 要求 | 依据 |
| --- | --- | --- |
| Flutter | **3.47.4** stable | `.metadata` 的 `revision` |
| Dart SDK | `>=3.0.0 <4.0.0` | `pubspec.yaml` 的 `environment.sdk` |
| JDK | **17 或更高**（实测 21） | `build.gradle.kts` 的 `compileOptions` / Kotlin `jvmTarget` |
| Android SDK | platform **37** | `build.gradle.kts` 的 `compileSdk = 37` |
| NDK | **28.2.13676358** | 同上（显式 `ndkVersion`） |
| Android Gradle Plugin | **9.1.0** | `android/settings.gradle.kts` |
| Kotlin | **2.4.0** | 同上 |
| Gradle | **9.3.1** | `android/gradle/wrapper/gradle-wrapper.properties` |
| minSdk / targetSdk | 跟随 Flutter 默认值 | `build.gradle.kts` 引用 `flutter.minSdkVersion` / `flutter.targetSdkVersion` |

> `android/local.properties`（SDK / Flutter 路径）由 Flutter 工具链在首次构建时自动生成，**不要手工提交**。

---

## 二、代码结构

```
lib/                  应用源码（73 个文件 / 约 27,200 行）
  app/                启动与全局装配（6）
  controllers/        GetX 控制器（5）
  data/               数据层（12）
  pages/              页面（15）
  utils/              工具（17）
  widgets/            通用组件（17）
  main.dart           入口
test/                 单元 / Widget 测试（69 个文件 / 约 15,700 行）
android/              仅 Android 平台工程
assets/images/        图标素材 + 六套壁纸
pubspec.yaml          依赖与版本号
analysis_options.yaml 静态检查配置
```

`lib/` 按职责分六层，层间只允许上层依赖下层：

| 目录 | 职责 | 文件 |
| --- | --- | --- |
| `app/` | 启动与全局装配 | `main.dart` · `routes.dart` · `bindings.dart` · `theme.dart` · `page_style.dart` · `style_keys.dart` · `app_version.dart` |
| `controllers/` | 全局状态（GetX） | `server_controller.dart` · `torrent_controller.dart` · `theme_controller.dart` · `locale_controller.dart` · `auth_controller.dart` |
| `data/` | 数据层 | `dio/log_interceptor.dart` · `dio/redirect_interceptor.dart` · `local/local_store.dart` · `local/secure_prefs.dart` · `models/`（`server_data` · `server_state` · `torrent` · `qb_log` · `qb_ip_filter`）· `prefs/server_prefs.dart` · `qbittorrent/qb_method.dart` · `transmission/tr_method.dart` |
| `pages/` | 页面 | `server_list_page`（首屏）· `torrent_list_page` · `torrent_info_page` + 四个分页（`_overview` / `_files` / `_peers` / `_trackers`）· `torrent_add_page` · `server_setting_page` · `server_dialog` · `theme_page` · `share_page` · `log_page` · `log_qb_page` · `drawer_page` |
| `utils/` | 工具 | `formatter` · `strings` · `i18n` / `i18n_en` · `app_log` / `log_scope` / `log_export` · `net_error` · `crypto_box` · `lan_detector` · `ip_geo` / `ip_geo_sources` · `startup_update` · `add_batch` · `file_export` · `theme_backup` · `update_check` |
| `widgets/` | 通用组件 | `auto_refresh` · `app_toast` · `bottom_panel` · `color_picker` · `draggable_fab` · `filtered_image` · `disk_io_chip` / `io_chip` · `list_loading_placeholder` · `log_selection` · `page_preview` / `theme_preview` · `server_stats_panel` · `slidable_tile` · `sort_filter_panel` · `speed_sparkline` · `arc_text` |

### 关键实现位置

| 能力 | 位置 |
| --- | --- |
| 路由表（9 条 `GetPage`） | `lib/app/routes.dart` |
| 依赖注入 | `lib/app/bindings.dart` |
| 主题装配（seed → 亮 / 暗两套 `ThemeData`） | `lib/app/theme.dart` |
| qBittorrent 客户端（Web API v2） | `lib/data/qbittorrent/qb_method.dart` |
| Transmission 客户端（JSON-RPC） | `lib/data/transmission/tr_method.dart` |
| 服务器偏好适配（两套客户端字段名 / 单位换算） | `lib/data/prefs/server_prefs.dart` |
| 会话保活与重试退避 | `lib/controllers/server_controller.dart` |
| 局域网 / 公网自动选路 | `lib/controllers/server_controller.dart` + `lib/utils/lan_detector.dart` |
| Peer IP 归属地查询（多源池 / 洗牌轮转 / 失败冷却） | `lib/utils/ip_geo.dart` + `lib/utils/ip_geo_sources.dart` |
| 错误归一（把 Dio 异常转成一句人话） | `lib/utils/net_error.dart` |
| 应用内日志总线 | `lib/utils/app_log.dart` |
| 启动版本检测（只检测并挂提醒，不弹窗） | `lib/utils/startup_update.dart` |
| 服务器列表「总计数据卡」 | `lib/widgets/server_stats_panel.dart` |

---

## 三、编译与运行

```bash
flutter pub get                        # 拉依赖
flutter run                            # 连真机 / 模拟器调试
flutter analyze                        # 静态检查
flutter test                           # 跑测试（当前 647 个用例）
flutter build apk --release --split-per-abi --target-platform android-arm64
```

### 一条命令出包

工程根目录的 `release.py` 把整个出包流程收成一条命令：

```bash
python release.py                  # 出 pubspec 记账的那个版本，成功后版本 +1
python release.py --dry-run        # 只打印计划，不构建、不写任何文件
python release.py --version 0.3.0  # 指定本次要出的版本
python release.py --debug-sign     # 用调试证书签（没有密钥库也能编出来试跑）
python release.py --verify-only    # 只对已有产物跑打包断言，不构建
python release.py --rehash         # 只给已有交付包补 / 重算 .sha1 侧车
```

它依次做完这些事：对齐界面版本号 → 构建 → 改名成 `TorrentManager-V<版本>-<abi>.apk`
→ 生成同名 `.sha1` → 对产物跑打包断言（so 压缩态 / CRC / ABI 单一性 / 侧车一致性）
→ 推进 `pubspec.yaml` 与 `kAppVersion` 到下一个版本。

> 版本号**只在构建成功且断言通过之后**才推进：失败不消耗版本号，重跑还是同一个号。
> 所以平时不需要手工改 `pubspec.yaml` 或 `app_version.dart`。

两个可选开关（也可用环境变量，免得每次敲）：`--mirror <目录>` 出包后再把交付包
（连同 `.sha1`）拷一份到别处 —— 目标盘不在只警告、不阻断出包；`--log <文件>`
把本次构建的版本 / 体积 / MD5 追加进去。

Flutter 与 Android SDK 的定位顺序：环境变量（`FLUTTER_ROOT` / `ANDROID_SDK_ROOT`）
→ `PATH` → `android/local.properties`。

### 签名（只有出 release 包才需要）

密钥库默认用 `android/app/torrentmanager-release.jks`，也可以在 `key.properties` 里用 `storeFile`
指向自己的文件（相对路径以 `android/app/` 为基准）。口令按以下优先级取：

1. `android/key.properties`（推荐）：复制 `android/key.properties.example` 为 `key.properties`，填入
   `storeFile` / `storePassword` / `keyPassword` / `keyAlias`；
2. 环境变量 `TORRENTMANAGER_STORE_PASSWORD` / `TORRENTMANAGER_KEY_PASSWORD` / `TORRENTMANAGER_KEY_ALIAS`；
3. 两者都缺 → 口令为空，**release 签名会失败**（`flutter run` 的 debug 构建不受影响）。

> 没有密钥库、只想把工程编译起来试跑的：`python release.py --debug-sign` 会用调试证书
> 签出一个能装能跑的包。⚠️ 它**不能覆盖安装正式版**（签名不同，安装器会拒绝）。

> ⚠️ `key.properties` 与 `*.jks` 已排除在版本管理与分发之外，请自行妥善保管 ——
> 丢失后无法再签出与既有版本**签名一致**的升级包。

### 版本号

两个真源必须**逐字符一致**：

| 位置 | 含义 |
| --- | --- |
| `pubspec.yaml` 的 `version:` | `版本名+versionCode`，例如 `0.2.10+33` |
| `lib/app/app_version.dart` 的 `kAppVersion` | 应用内显示的版本名，必须等于 `+` 号前那一段 |

> ⚠️ `versionCode`（`+` 后的数字）**必须单调递增** —— Android 只认它判断新旧，
> 回退会被安装器拒装并提示「存在更新版本」。使用 `--split-per-abi` 时每个 ABI 会自动偏移。
>
> 两者由 `release.py` 在构建前对齐、构建成功后一起推进，平时无需手工修改。

---

## 四、构建配置要点

| 配置 | 说明 |
| --- | --- |
| R8 收缩与混淆 | `android/app/proguard-rules.pro`。**不要**写 `-keep class androidx.**` / `io.flutter.**` 这类宽泛规则 —— `-keep` 会同时禁止混淆并把整棵依赖树钉死，实测会让 `classes.dex` 从约 1.1 MB 涨到 4.3 MB |
| 签名版本 | 强制开启 v1(JAR) + v2 + v3。AGP 在 `minSdk >= 24` 时会自动关掉 v1，而部分国产 ROM 的安装器仍会检查 `META-INF` 下的 v1 证书 |
| so 打包方式 | `packaging.jniLibs.useLegacyPackaging` 是唯一来源（manifest 里**不要**再写 `extractNativeLibs`，两处并存会在 AGP 9 下直接报错）。**默认不压缩**：`useLegacyPackaging = project.hasProperty("lite")` ⇒ so 以 STORED 存放（设备直接 mmap、只有一份、安装后占用省），APK ≈ 22.82 MB。想要下载体积减半（22.82 MB → 约 11~13 MB，代价是安装时多解压出一份副本、安装后占用 +38%）就加 `--android-project-arg=lite=true`。⚠️ 判断开关是否真生效只能看产物里 so 的压缩态，属性没传进去时构建照样成功；⚠️ 改这个默认值**必须同步** `release.py` 的断言期望值（两处互为镜像，历史上不同步过一次，导致构建成功但断言必 FAIL） |
| 明文流量策略 | `android/app/src/main/res/xml/network_security_config.xml` —— 局域网内的服务器多用明文 http，放行范围与理由都写在该文件里 |
| 权限 | 见 `android/app/src/main/AndroidManifest.xml`，其中两个存储权限设了 `maxSdkVersion`（Android 10+ 已改分区存储、由 SAF 接管） |

---

## 五、已知说明

1. **版本检查源是本项目的 GitHub Releases**：`lib/app/app_version.dart` 的 `kUpdateCheckUrl`
   指向 `api.github.com/repos/punk64/TorrentManager/releases/latest` —— 发新版时打 `vX.Y.Z`
   标签建 Release 即可被查到，**无需维护额外的版本文件**。两种静默降级情形（界面都显示
   「已是最新版本」、不报错）：① 仓库还没有 Release，接口返回 404；② 国内网络访问
   `api.github.com` 失败。换源只需改那一个常量。⚠️ 该请求**必须带 `User-Agent`**，缺了会被 403。
2. **启动更新检测只挂提醒、不打扰**：每次启动自动查一次（`lib/utils/startup_update.dart`），
   **不弹窗** —— 只是把结果挂到抽屉的「检查更新」入口上（有新版时该条目变成「有更新」），
   点它才展开详情并可复制发布页地址。同一进程内只查一次；查询失败与「已是最新」都静默处理
   （对用户而言是同一件事）。抽屉里的手动检查（`compareVersions`）随时可用，两者互不影响。
3. **Peer 归属地走多源池**：`lib/utils/ip_geo_sources.dart` 注册了中 / 英文两套查询源
   （中文池 = 优先返回中文的国内源 + 国际源兜底，英文池 = 全部国际源；按应用语言选池，
   运行时切换即时生效）。为避免被风控，同一源设有请求最小间隔并按洗牌袋轮转，
   连续失败或 429/403 会进冷却；响应体超限直接丢弃不解析，展示字段统一做字符净化
   （剔除控制字符、双向重写符、零宽字符），并校验回环地址以免拿到「查出来是别人」的脏数据。
   **只发送被查询的 IP 本身**，内网与保留地址不发。加源只需在该文件追加一条注册项。
4. **Transmission 侧不提供服务器日志**：其 RPC 规范里没有日志方法，故「服务器日志」页在选中
   Transmission 服务器时展示**会话诊断信息**（`session-get` / `session-stats`）并明确说明这一点。
5. **`lib/utils/i18n_en.dart` 与 `lib/utils/strings.dart` 是成对的文案表**：前者的 key 必须覆盖
   后者 `L.t(...)` 用到的全部 key，缺哪条就会回落到中文原文。两者需同步修改。
6. 首次构建耗时较长（NDK / Gradle 首次下载与编译），属正常现象。

---

## 六、许可证

以 **MIT License** 发布，全文见 [LICENSE](LICENSE)。

### 第三方资源与商标

`assets/images/qbittorrent.png` 与 `assets/images/transmission.png` 分别是
[qBittorrent](https://www.qbittorrent.org/) 与
[Transmission](https://transmissionbt.com/) 项目的官方标识，
**版权归各自项目所有，不适用本仓库的 MIT 许可**；此处仅用于在界面上标识所连接的
服务器类型。

qBittorrent 与 Transmission 均为各自权利人的名称与商标。本项目与二者**无隶属、赞助
或背书关系**，是独立开发的第三方远程管理客户端，仅通过二者公开的 RPC 接口通信。
