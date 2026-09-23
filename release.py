#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TorrentManager —— 一条命令出包：对齐版本号 → 构建 → 重命名 → 断言 → 汇总。

用法
----
    python release.py                     出 pubspec 记账的那个版本，成功后版本 +1
    python release.py --dry-run           只打印计划，不构建、不写任何文件
    python release.py --no-bump           同版本重编（不占版本号）
    python release.py --version 0.2.10    指定本次要出的版本（成功后推进到 0.2.11+…）
    python release.py --abi armeabi-v7a   改出其它架构（可重复；默认只出 arm64-v8a）
    python release.py --debug-sign        改用调试证书签名（无需正式密钥库）
    python release.py --verify-only       只对已有产物跑打包断言
    python release.py --rehash            只给已有交付包补 / 重算 .sha1 侧车
    python release.py --no-verify         跳过打包断言（不建议）
    python release.py --mirror <备份目录> 构建完成后把交付包再拷一份到该目录
    python release.py --log build.log     把本次构建记入指定日志文件

版本号语义
----------
`pubspec.yaml` 里存的是「**这次要出的版本**」，不是「上次出过的版本」：

    首次运行  → 出 V0.0.0   → 成功后 pubspec 变成 0.0.1+2
    第二次    → 出 V0.0.1   → 成功后 pubspec 变成 0.0.2+3

版本推进**只在构建成功且断言通过之后**才发生：构建失败不消耗版本号，重跑还是同一个号，
也不需要任何额外的状态文件（pubspec 自己就是状态）。
`+N` 是 Android 的 versionCode（系统只认它判新旧），与版本号同步 +1。

界面上的版本号来自 `lib/app/app_version.dart` 的 `kAppVersion`。它是独立常量、
不会自动跟着 pubspec 走，所以本脚本在**构建前**会把它对齐到本次版本，避免出现
「界面写着 V1.0.0、装进去的却是 V0.0.6」这种漂移。

签名
----
release 包必须用正式密钥库签名：`android/key.properties` + `android/app/` 下的密钥库文件
（文件名由 `build.gradle.kts` 指定，可用 key.properties 里的 `storeFile` 覆盖）。
两者缺一，脚本会在构建前停下并给出配置指引。
只想把工程编译起来看看的，加 `--debug-sign` 改用调试证书 —— 能装能跑，
但签名与正式版不同，**不能覆盖安装正式版**。

环境
----
Flutter      : FLUTTER_ROOT / FLUTTER_HOME → PATH → android/local.properties 的 flutter.sdk
Android SDK  : ANDROID_SDK_ROOT / ANDROID_HOME → android/local.properties 的 sdk.dir
Gradle / Pub : 沿用各自默认缓存；若环境里已显式指定则尊重之
可选环境变量 : TM_MIRROR_DIR（等同 --mirror）、TM_LOG（等同 --log）

构建时会把全部代理变量清掉：Gradle 与 Dart 会把 127.0.0.1 也当作代理目标，
表现为静默卡死，排查成本很高。
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

# ── 路径 ────────────────────────────────────────────────────────────────────
# 本脚本放在**工程根目录**（与 pubspec.yaml 同级），路径一律由脚本自身位置推导，
# 因此从哪个目录调用都得到相同结果。
APP = Path(__file__).resolve().parent
PUBSPEC = APP / 'pubspec.yaml'
# 界面显示的版本号常量（`lib/app/app_version.dart`）—— 与 pubspec 互为镜像，
# 由本脚本在构建前自动对齐。
APP_VERSION_DART = APP / 'lib' / 'app' / 'app_version.dart'
OUT_DIR = APP / 'build' / 'app' / 'outputs' / 'flutter-apk'
LOCAL_PROPS = APP / 'android' / 'local.properties'
KEY_PROPS = APP / 'android' / 'key.properties'
APP_MODULE_DIR = APP / 'android' / 'app'

# 全部支持的 ABI，顺序即展示顺序（arm64 在前 —— 绝大多数真机是它）
ABIS = ['arm64-v8a', 'armeabi-v7a', 'x86_64']
# 默认只出 arm64-v8a：包体最小、构建最快。要其它架构用 `--abi` 显式指定。
DEFAULT_ABIS = ['arm64-v8a']

# `flutter build apk --target-platform` 用的平台名（注意不是 ABI 名）
_TARGET_PLATFORM = {
    'arm64-v8a': 'android-arm64',
    'armeabi-v7a': 'android-arm',
    'x86_64': 'android-x64',
}

VERSION_RE = re.compile(r'^(version:\s*)(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', re.M)
APP_VERSION_RE = re.compile(r"^const String kAppVersion = '([0-9.]+)';", re.M)
# 交付包命名：TorrentManager-V<major>.<minor>.<patch>-<abi>[-lite].apk
NEW_NAME_RE = re.compile(r'TorrentManager-V(\d+)\.(\d+)\.(\d+)-([\w-]+?)(-lite)?\.apk$')


def log(msg: str) -> None:
    print(msg, flush=True)


def die(msg: str, code: int = 1):
    log('✖ ' + msg)
    sys.exit(code)


# ── 读 local.properties ─────────────────────────────────────────────────────
def read_local_props() -> dict:
    """读 `android/local.properties` → {键: 值}。

    这是 Android 工程存放本机 SDK 路径的标准位置（`sdk.dir` / `flutter.sdk`），
    由 IDE 或首次构建自动生成，因此**不进版本库**。缺失不是错误，
    脚本会继续往环境变量那一层找。
    """
    props: dict[str, str] = {}
    if not LOCAL_PROPS.exists():
        return props
    for line in LOCAL_PROPS.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('!') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        # java properties 里反斜杠是转义符，Windows 路径的每个 \ 会写成两个
        props[k.strip()] = v.strip().replace('\\\\', '\\')
    return props


def resolve_flutter(props: dict) -> Path:
    """定位 flutter 可执行文件：环境变量 → PATH → local.properties。"""
    exe_name = 'flutter.bat' if os.name == 'nt' else 'flutter'
    for var in ('FLUTTER_ROOT', 'FLUTTER_HOME'):
        root = os.environ.get(var)
        if root:
            exe = Path(root) / 'bin' / exe_name
            if exe.exists():
                return exe
    found = shutil.which('flutter')
    if found:
        return Path(found)
    sdk = props.get('flutter.sdk')
    if sdk:
        exe = Path(sdk) / 'bin' / exe_name
        if exe.exists():
            return exe
    die('找不到 flutter 可执行文件。三选一：\n'
        '   · 把 Flutter SDK 的 bin 目录加进 PATH；\n'
        '   · 设置环境变量 FLUTTER_ROOT=<SDK 根目录>；\n'
        '   · 在 android/local.properties 里写 flutter.sdk=<SDK 根目录>。')


# ── 版本号读写 ──────────────────────────────────────────────────────────────
def read_version() -> tuple[str, int]:
    """读 pubspec 的 `version:` → (core, code)，如 ('0.2.9', 32)。"""
    if not PUBSPEC.exists():
        die('找不到 %s —— 本脚本必须放在工程根目录（与 pubspec.yaml 同级）。' % PUBSPEC)
    m = VERSION_RE.search(PUBSPEC.read_text(encoding='utf-8'))
    if not m:
        die('pubspec.yaml 里找不到形如 `version: 0.0.0+1` 的行 —— 请先修好它。')
    return '%s.%s.%s' % (m.group(2), m.group(3), m.group(4)), int(m.group(5))


def write_version(core: str, code: int) -> None:
    text = PUBSPEC.read_text(encoding='utf-8')
    new = VERSION_RE.sub(lambda m: '%s%s+%d' % (m.group(1), core, code), text, count=1)
    if new == text:
        die('写版本号失败（正则没命中？）')
    PUBSPEC.write_text(new, encoding='utf-8')


def read_app_version() -> str | None:
    """读 `lib/app/app_version.dart` 的 kAppVersion；读不到返回 None。"""
    if not APP_VERSION_DART.exists():
        return None
    m = APP_VERSION_RE.search(APP_VERSION_DART.read_text(encoding='utf-8'))
    return m.group(1) if m else None


def write_app_version(core: str) -> None:
    """把 kAppVersion 改写成 core（文件里其它内容保持不动）。"""
    text = APP_VERSION_DART.read_text(encoding='utf-8')
    new = APP_VERSION_RE.sub(lambda _m: "const String kAppVersion = '%s';" % core,
                             text, count=1)
    if new == text:
        die('改写 kAppVersion 失败（正则没命中？）—— 检查 %s' % APP_VERSION_DART)
    APP_VERSION_DART.write_text(new, encoding='utf-8')


def sync_app_version(core: str) -> None:
    """**构建前**把界面显示的版本号对齐到本次要出的版本，并回读校验。

    为什么必须在构建前做：APK 的 versionName 来自 pubspec，而抽屉顶部显示的
    是 Dart 常量。两者不同源就会漂移，用户装完看到的版本号和包里写的不一致。
    """
    cur = read_app_version()
    if cur is None:
        die('读不到 %s 里的 kAppVersion —— 界面版本号将无处可取。' % APP_VERSION_DART)
    if cur == core:
        log('界面版本号   : kAppVersion = %s   ✔ 与 pubspec 一致' % cur)
        return
    log('界面版本号   : kAppVersion %s → %s（自动同步到本次版本）' % (cur, core))
    write_app_version(core)
    if read_app_version() != core:          # 回读，防止静默写失败
        die('同步 kAppVersion 后回读仍是 %s —— 未生效，已中止。' % read_app_version())


def bump(core: str, code: int) -> tuple[str, int]:
    """版本号 +1：patch 位进位，`+N` 同步 +1。"""
    a, b, c = (int(x) for x in core.split('.'))
    return '%d.%d.%d' % (a, b, c + 1), code + 1


# ── 构建环境 ────────────────────────────────────────────────────────────────
def build_env(props: dict) -> dict:
    """构造构建环境：**尊重调用者已有配置，只补缺失项**。

    ⚠️ 必须清掉代理：Gradle / Dart 会把 127.0.0.1 也当代理目标，表现为静默卡死。
    """
    env = dict(os.environ)
    for k in ('http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY',
              'all_proxy', 'ALL_PROXY', 'ftp_proxy', 'FTP_PROXY'):
        env.pop(k, None)
    env['NO_PROXY'] = '127.0.0.1,localhost'

    # Android SDK：环境变量优先，其次 local.properties（Android 工程的标准位置）
    if not env.get('ANDROID_SDK_ROOT') and not env.get('ANDROID_HOME'):
        sdk = props.get('sdk.dir')
        if sdk:
            env['ANDROID_SDK_ROOT'] = sdk
            env['ANDROID_HOME'] = sdk

    # JAVA_HOME / GRADLE_USER_HOME / PUB_CACHE 一律不设置：
    # 让 Gradle、Dart 用自己的默认解析（IDE 配置、JAVA_HOME、~/.gradle、默认 pub 缓存）。
    # 只有在环境里已经显式给出时才生效 —— 那正是上面 dict(os.environ) 拷贝过来的值。
    env.setdefault('GRADLE_OPTS', '-Xmx2g')
    return env


# ── 签名检查 ────────────────────────────────────────────────────────────────
def find_keystore(props_kp: dict | None = None) -> Path | None:
    """找出密钥库文件：key.properties 的 storeFile 优先，其次 android/app 下唯一的 .jks。"""
    if props_kp:
        sf = props_kp.get('storeFile')
        if sf:
            p = Path(sf)
            if not p.is_absolute():
                p = APP_MODULE_DIR / p
            return p if p.exists() else None
    jks = sorted(APP_MODULE_DIR.glob('*.jks'))
    return jks[0] if jks else None


def read_key_props() -> dict:
    if not KEY_PROPS.exists():
        return {}
    props = {}
    for line in KEY_PROPS.read_text(encoding='utf-8', errors='replace').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        props[k.strip()] = v.strip()
    return props


def signing_help() -> str:
    return (
        '  release 包必须用正式密钥库签名，两种做法：\n'
        '\n'
        '  【配置自己的密钥库】\n'
        '    ① 复制 android/key.properties.example 为 android/key.properties\n'
        '       （该文件在 .gitignore 里，不会被提交，也不要提交）\n'
        '    ② 生成密钥库（别名、口令自行替换）：\n'
        '         keytool -genkeypair -v -keystore android/app/release.jks \\\n'
        '                 -alias release -keyalg RSA -keysize 2048 -validity 10000\n'
        '    ③ 在 key.properties 里填 storeFile / storePassword / keyAlias / keyPassword\n'
        '\n'
        '  【只想编译起来看看】\n'
        '    加 --debug-sign 改用调试证书签名：能装能跑，\n'
        '    但签名与正式版不同，不能覆盖安装正式版。')


# ── 构建 / 重命名 ───────────────────────────────────────────────────────────
def run_build(env: dict, abis: list[str], debug_sign: bool) -> bool:
    props = read_local_props()
    flutter = resolve_flutter(props)
    # `--split-per-abi` 必须保留：产物名才是稳定的 `app-<abi>-release.apk`。
    platforms = ','.join(_TARGET_PLATFORM[a] for a in abis)
    cmd = [str(flutter), 'build', 'apk', '--release', '--split-per-abi',
           '--target-platform', platforms, '--no-pub']
    if debug_sign:
        # Gradle 会把 ORG_GRADLE_PROJECT_<name> 环境变量当作 -P<name> 使用
        env = dict(env)
        env['ORG_GRADLE_PROJECT_tmDebugSign'] = 'true'
    log('Flutter          = %s' % flutter)
    log('$ ' + ' '.join(cmd[1:]))
    log('  （工作目录 %s）' % APP)
    t0 = time.time()
    # 不要 pipe / capture：构建要跑几分钟，实时输出才能判断是"在干活"还是"卡死了"。
    rc = subprocess.call(cmd, cwd=str(APP), env=env)
    log('构建结束，退出码 %d，耗时 %.1f 分钟' % (rc, (time.time() - t0) / 60.0))
    return rc == 0


def sha1_of(p: Path) -> str:
    """流式计算 SHA1，输出小写十六进制（大文件也不吃内存）。"""
    h = hashlib.sha1()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def md5_of(p: Path) -> str:
    h = hashlib.md5()
    with p.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def write_sha1_sidecar(apk: Path) -> Path:
    """写 `<apk 名>.sha1`（内容 = 该 APK 的 SHA1），返回侧车路径。"""
    side = apk.with_name(apk.name + '.sha1')
    side.write_text(sha1_of(apk), encoding='ascii')
    return side


def sweep_orphan_sha1() -> int:
    """清掉「旧命名、且对应 .apk 已不在」的孤儿 `.sha1`。

    只删孤儿：只要同名 `.apk` 还在就一律不动 —— 宁可留着，也不误删。
    不清理会让产物目录里出现"两个时代的文件混在一起"。
    """
    n = 0
    for side in sorted(OUT_DIR.glob('app-*-release.apk.sha1')):
        base = side.with_name(side.name[:-len('.sha1')])
        if not base.exists():
            side.unlink()
            log('清理孤儿校验文件：%s' % side.name)
            n += 1
    return n


def rename_outputs(core: str, abis: list[str]) -> list[Path]:
    """app-<abi>-release.apk → TorrentManager-V<core>-<abi>.apk，**连同 `.sha1` 侧车**。

    ⚠️ 别只搬 `.apk`。Flutter 每次构建成功后都会给每个包写一份同名的 `<apk>.sha1`。
    只搬 apk、不搬侧车，交付目录里就会残留 `app-x86_64-release.apk.sha1` 这种
    "校验文件与交付名对不上"的旧名文件。

    策略：能搬就搬（沿用它自己算的那份，零额外成本）；搬不到（构建中断、
    或产物是从别处拷来的）就按新名现算一份 —— 让「每个交付包旁边都有一份
    同名且校验一致的 .sha1」这个不变式恒成立。
    """
    made: list[Path] = []
    for abi in [a for a in ABIS if a in abis]:
        src = OUT_DIR / ('app-%s-release.apk' % abi)
        if not src.exists():
            die('构建产物缺失：%s' % src.name)
        src_sha = src.with_name(src.name + '.sha1')
        dst = OUT_DIR / ('TorrentManager-V%s-%s.apk' % (core, abi))
        dst_sha = dst.with_name(dst.name + '.sha1')
        for old in (dst, dst_sha):              # 同版本重编时覆盖旧的同名交付包
            if old.exists():
                old.unlink()
        shutil.move(str(src), str(dst))
        if src_sha.exists():
            shutil.move(str(src_sha), str(dst_sha))
        else:
            write_sha1_sidecar(dst)
        made.append(dst)
    sweep_orphan_sha1()
    return made


def rehash_existing() -> None:
    """给产物目录里已有的交付包补 / 重算同名 `.sha1`。不构建、不动版本号。"""
    apks = sorted(OUT_DIR.glob('TorrentManager-V*.apk'))
    if not apks:
        die('产物目录里没有 TorrentManager-V*.apk —— 先跑一次出包。')
    for apk in apks:
        side = write_sha1_sidecar(apk)
        log('  %-46s -> %s' % (apk.name, side.name))
    if sweep_orphan_sha1() == 0:
        log('  （无孤儿校验文件需要清理）')


# ── 可选：镜像到别的目录 ────────────────────────────────────────────────────
def mirror_outputs(apks: list[Path], dest: Path) -> None:
    """把交付包（连同 `.sha1` 侧车）额外复制一份到 `dest`。

    三条纪律：
      * **目标不可用时只警告、绝不让出包失败** —— 目标盘（U 盘 / 网盘目录）常常不在，
        缺盘不该阻断发版，更不该让已经构建成功的 APK 白费；
      * 用 `copy2` 并**覆盖**同名文件：同版本重编时对方那份必须跟着更新，
        否则会留下一个"名字一样、内容不同"的假交付包；
      * 复制后**复核大小**：Windows 上大文件复制偶发静默截断（写出 0 字节或半截
        文件却不报错），不比对一眼不算成功。
    """
    try:
        if not dest.exists():
            log('  [镜像] 目标不可用（%s）—— 跳过，出包不受影响' % dest)
            return
    except OSError as e:
        log('  [镜像] 目标探测失败（%s）—— 跳过，出包不受影响' % e)
        return
    for apk in apks:
        side = apk.with_name(apk.name + '.sha1')
        for src in (apk, side):
            if not src.exists():
                continue
            dst = dest / src.name
            try:
                shutil.copy2(str(src), str(dst))
            except OSError as e:
                log('  [镜像] %s 复制失败：%s（出包不受影响）' % (src.name, e))
                continue
            ok = dst.exists() and dst.stat().st_size == src.stat().st_size
            log('  [镜像] %-44s %s' % (src.name, 'OK' if ok else '⚠️ 大小不一致，请复查'))


# ── 可选：记账 ──────────────────────────────────────────────────────────────
BUILD_LOG_HEAD = ('# 构建记录（由 release.py 自动追加）\n\n'
                  '| 时间 | 版本 | versionCode（基础） | 产物 | 体积 | MD5 |\n'
                  '|---|---|---|---|---|---|\n')


def record_build(path: Path, core: str, code: int, apks: list[Path]) -> None:
    """往指定文件追加一行（本轮构建的版本 / 体积 / MD5）。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_text(BUILD_LOG_HEAD, encoding='utf-8')
    ts = time.strftime('%Y-%m-%d %H:%M')
    rows = []
    for i, p in enumerate(apks):
        rows.append('| %s | V%s | %d | %s | %.2f MB | `%s` |'
                    % (ts if i == 0 else '', core, code, p.name,
                       p.stat().st_size / 1048576.0, md5_of(p)))
    with path.open('a', encoding='utf-8') as f:
        f.write('\n'.join(rows) + '\n')
        f.write('\n> ⚠️ APK 里**实际**的 versionCode 会在上表基础上叠一个 ABI 偏移\n'
                '> （`--split-per-abi` 由 Flutter 自动加）：armeabi-v7a **+1000**、\n'
                '> arm64-v8a **+2000**、x86_64 **+4000**。\n'
                '> 例如基础 `1` → 三个包分别是 `1001` / `2001` / `4001`。\n'
                '> 偏移是常数，所以**升级方向仍然单调**，不影响覆盖安装。\n'
                '> 用户可见的版本号看 `versionName`（= 上表的 V 后面那串）。\n')


# ── 后置断言（打包状态自检） ────────────────────────────────────────────────
def _resolve_standard(out: str) -> tuple[str, list[str]]:
    """选出「标准包」→ (说明, [路径])。

    优先新命名 `TorrentManager-V*`：取版本号最大的一组；
    不假定「三个 ABI 齐全」—— 出包默认只编 arm64-v8a，
    按三个 ABI 逐个点名会把「只出 arm64」误判成「v7a 缺失」。
    """
    def _by_order(p: str) -> int:
        n = os.path.basename(p)
        for i, abi in enumerate(ABIS):
            if n.endswith('-%s.apk' % abi):
                return i
        return len(ABIS)

    found = []
    for p in glob.glob(os.path.join(out, 'TorrentManager-V*.apk')):
        m = NEW_NAME_RE.match(os.path.basename(p))
        if m and not m.group(5):                    # 排除 -lite
            found.append(((int(m.group(1)), int(m.group(2)), int(m.group(3))),
                          m.group(4), p))
    if found:
        best = max(v for v, _, _ in found)
        tag = 'V%d.%d.%d' % best
        paths = sorted((p for v, _, p in found if v == best), key=_by_order)

        def _abi_of(p: str) -> str:
            m = NEW_NAME_RE.match(os.path.basename(p))
            return m.group(4) if m else '?'

        return ('标准包 %s（%d 个：%s）'
                % (tag, len(paths), ' / '.join(_abi_of(p) for p in paths))), paths
    old = [os.path.join(out, 'app-%s-release.apk' % abi) for abi in ABIS]
    return ('标准包（旧命名 app-<abi>-release.apk）',
            [p for p in old if os.path.exists(p)] or old)


def _resolve_lite(out: str) -> list[str]:
    new = [p for p in glob.glob(os.path.join(out, 'TorrentManager-V*.apk'))
           if os.path.basename(p).endswith('-lite.apk')]
    old = [os.path.join(out, 'app-%s-release-lite.apk' % abi) for abi in ABIS]
    return (new or old) + [p for p in old if p not in new]


def _check_sha1(path: str) -> tuple[str, bool]:
    """校验 `<apk>.sha1` 侧车：存在 + 内容等于该 apk 的 SHA1。"""
    name = os.path.basename(path)
    side = path + '.sha1'
    if not os.path.exists(side):
        return '%-34s 缺少同名 .sha1 侧车' % name, False
    with open(side, 'r', encoding='ascii') as f:
        want = f.read().strip().lower()
    got = sha1_of(Path(path))
    ok = want == got
    return ('%-34s .sha1 %s（%s）' % (name, 'OK' if ok else 'MISMATCH', got)), ok


def _check_orphan_sha1(out: str) -> list[str]:
    bad = []
    for side in glob.glob(os.path.join(out, 'app-*-release.apk.sha1')):
        if not os.path.exists(side[:-len('.sha1')]):
            bad.append(os.path.basename(side))
    return bad


def _check_one(path: str, want_stored: bool) -> tuple[str, bool]:
    """校验单个包的 so 压缩态 / CRC / ABI 单一性。返回 (展示行, 是否通过)。"""
    name = os.path.basename(path)
    if not os.path.exists(path):
        return '%-34s 缺失!' % name, False

    zf = zipfile.ZipFile(path)
    namelist = zf.namelist()
    abi_set = sorted({x.split('/')[1] for x in namelist
                      if x.startswith('lib/') and x.count('/') > 1})
    sos = [x for x in namelist if x.endswith('.so')]
    stored = [x for x in sos if zf.getinfo(x).compress_type == zipfile.ZIP_STORED]
    deflated = [x for x in sos if zf.getinfo(x).compress_type == zipfile.ZIP_DEFLATED]
    raw = sum(zf.getinfo(x).file_size for x in sos)
    cmp_ = sum(zf.getinfo(x).compress_size for x in sos)
    bad = zf.testzip()
    size = os.path.getsize(path)

    expect = '全 STORED' if want_stored else '全 DEFLATED'
    state_ok = (len(stored) if want_stored else len(deflated)) == len(sos) and len(sos) > 0
    ok = state_ok and bad is None and len(abi_set) == 1

    return ('%-34s %6.2f MB | so %d: STORED %d / DEFLATED %d (期望%s) %s | '
            'so 原始 %.2f→压缩 %.2f MB | CRC %s | ABI %s | %s'
            % (name, size / 1048576.0, len(sos), len(stored), len(deflated),
               expect, 'OK' if state_ok else 'FAIL',
               raw / 1048576.0, cmp_ / 1048576.0,
               'OK' if bad is None else str(bad), ','.join(abi_set),
               'PASS' if ok else 'FAIL')), ok


def run_checks(out: Path | None = None) -> bool:
    """构建后断言：校验 so 打包态是否符合预期。

    光看"构建成功"判断不出打包开关有没有生效 —— `useLegacyPackaging` 若没真正打开，
    构建照样 exit 0，只是静默编成了标准包。唯一可信的判据是**产物里 so 的压缩态**。

    判据：
        标准包 → so 必须全部 STORED（不压缩）【必需】
        lite 包 → so 必须全部 DEFLATED（压缩）【可选，不存在即跳过】
        + CRC 校验、ABI 单一（确认 --split-per-abi 生效）
        + 每个交付包都必须有**同名且内容一致**的 .sha1 侧车，且无旧命名孤儿
    """
    out_s = str(out or OUT_DIR)
    log('输出目录: %s' % out_s)
    allok = True

    label, std_paths = _resolve_standard(out_s)
    log('')
    log('=== %s（期望 so 全 STORED）===' % label)
    for p in std_paths:
        line, ok = _check_one(p, True)
        log(line)
        allok = allok and ok

    log('')
    log('=== 交付包 .sha1 侧车校验 ===')
    for p in std_paths:
        if os.path.exists(p):
            line, ok = _check_sha1(p)
        else:
            line, ok = ('%-34s 缺失!（无 apk 无从校验）' % os.path.basename(p), False)
        log(line)
        allok = allok and ok
    orphans = _check_orphan_sha1(out_s)
    if orphans:
        log('发现旧命名孤儿校验文件: %s' % ', '.join(orphans))
        allok = False
    else:
        log('无旧命名孤儿 .sha1 OK')

    lite_paths = _resolve_lite(out_s)
    log('')
    log('=== lite 包（可选；期望 so 全 DEFLATED）===')
    if not any(os.path.exists(p) for p in lite_paths):
        log('未生成 lite 包 —— 已跳过')
    else:
        for p in lite_paths:
            line, ok = _check_one(p, False)
            log(line)
            allok = allok and ok

    log('')
    log('总体: %s' % ('ALL PASS' if allok else '有 FAIL —— 打包开关可能未生效'))
    return allok


# ── 主流程 ──────────────────────────────────────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(
        description='一条命令出包：对齐版本号 + 构建 + 重命名 + 打包断言',
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--dry-run', action='store_true', help='只打印计划，不构建不写文件')
    ap.add_argument('--no-bump', action='store_true', help='版本号不自增（同版本重编）')
    ap.add_argument('--version', help='指定本次要出的版本（如 0.2.10）')
    ap.add_argument('--no-verify', action='store_true', help='跳过后置打包断言')
    ap.add_argument('--verify-only', action='store_true',
                    help='只对已有产物跑打包断言（不构建、不动版本号）')
    ap.add_argument('--rehash', action='store_true',
                    help='只给已有交付包补 / 重算同名 .sha1 侧车（不构建、不动版本号）')
    ap.add_argument('--debug-sign', action='store_true',
                    help='改用调试证书签名（无需正式密钥库；不能覆盖安装正式版）')
    ap.add_argument('--mirror', metavar='目录',
                    help='构建完成后把交付包再拷一份到该目录（也可用环境变量 TM_MIRROR_DIR）')
    ap.add_argument('--log', metavar='文件',
                    help='把本次构建记入该文件（也可用环境变量 TM_LOG）')
    ap.add_argument('--abi', action='append', choices=ABIS, metavar='ABI',
                    help='出哪些架构（可重复；默认只出 %s）' % DEFAULT_ABIS[0])
    args = ap.parse_args()

    abis = args.abi if args.abi else list(DEFAULT_ABIS)
    mirror = args.mirror or os.environ.get('TM_MIRROR_DIR')
    logfile = args.log or os.environ.get('TM_LOG')

    # 只校验 / 只补侧车的两条捷径：不构建、不动版本号
    if args.verify_only:
        return 0 if run_checks() else 1
    if args.rehash:
        log('为已有交付包生成同名 .sha1 侧车（不构建、不改版本号）')
        log('输出目录：%s' % OUT_DIR)
        rehash_existing()
        if not args.no_verify and not run_checks():
            log('✖ 断言失败 —— 请检查产物。')
            return 1
        return 0

    props = read_local_props()
    cur_core, cur_code = read_version()
    core, code = ([args.version, cur_code] if args.version else [cur_core, cur_code])
    # 指定 --version 时 versionCode 仍沿用当前值，避免手写时撞号
    nxt_core, nxt_code = bump(core, code)

    log('─' * 68)
    log('本次构建版本 : V%s   (versionCode %d)' % (core, code))
    log('构建后推进到 : V%s   (versionCode %d)%s'
        % (nxt_core, nxt_code, '   ← --no-bump，实际不写回' if args.no_bump else ''))
    log('产物命名     : TorrentManager-V%s-<abi>.apk' % core)
    log('架构         : %s%s' % (', '.join(abis),
                                 '   ← 默认只出 arm64；用 --abi 可加其它架构'
                                 if not args.abi else '   ← 由 --abi 指定'))
    log('输出目录     : %s' % OUT_DIR)
    dart_v = read_app_version()
    log('界面版本号   : kAppVersion = %s%s' % (
        dart_v,
        '   ✔ 与 pubspec 一致' if dart_v == core
        else '   → 构建前自动同步为 V%s' % core))
    log('签名         : %s' % ('调试证书（--debug-sign）' if args.debug_sign else '正式密钥库'))
    if mirror:
        log('镜像目录     : %s' % mirror)
    if logfile:
        log('构建记录     : %s' % logfile)
    log('─' * 68)

    if args.dry_run:
        log('（--dry-run：到此为止，未构建、未改任何文件）')
        return 0

    # 签名前置检查：缺文件就别白等几分钟构建，直接把配置步骤打出来
    if not args.debug_sign:
        kp = read_key_props()
        if not KEY_PROPS.exists():
            die('缺少 android/key.properties —— 无法用正式密钥库签名。\n' + signing_help())
        ks = find_keystore(kp)
        if ks is None:
            die('找不到密钥库文件（android/app/*.jks，或 key.properties 里 storeFile 指向的文件）。\n'
                + signing_help())

    env = build_env(props)
    log('Android SDK      = %s' % (env.get('ANDROID_SDK_ROOT') or '(由 Gradle 自行解析)'))
    log('JAVA_HOME        = %s' % (env.get('JAVA_HOME') or '(由 Gradle 自行解析)'))
    log('')

    # 界面版本号必须先对齐到本次要出的版本再构建 —— 否则 APK 里是 V{core}、
    # 界面上却显示旧常量。
    sync_app_version(core)

    if not run_build(env, abis, args.debug_sign):
        if args.debug_sign:
            log('✖ 构建失败 —— 版本号未消耗（pubspec 仍是 %s+%d），修好后重跑即可。'
                % (core, code))
            return 1
        log('✖ 构建失败 —— 版本号未消耗（pubspec 仍是 %s+%d），修好后重跑即可。\n'
            '  若失败信息与签名有关，检查 android/key.properties 的口令与别名。'
            % (core, code))
        return 1

    apks = rename_outputs(core, abis)
    log('已重命名：')
    for p in apks:
        log('  %-46s %6.2f MB' % (p.name, p.stat().st_size / 1048576.0))

    if not args.no_verify and not run_checks():
        log('✖ 打包断言失败 —— 版本号未消耗；产物已重命名，可人工检查。')
        return 1

    if mirror:
        mirror_outputs(apks, Path(mirror))

    if logfile:
        record_build(Path(logfile), core, code, apks)

    if args.no_bump:
        log('')
        log('✔ 出包完成：V%s（--no-bump，版本号保持 %s+%d）' % (core, cur_core, cur_code))
        return 0

    write_version(nxt_core, nxt_code)
    write_app_version(nxt_core)                 # 界面版本号跟着一起推进
    log('')
    log('✔ 出包完成：V%s' % core)
    log('  下次将出  : V%s（pubspec 已写为 %s+%d，kAppVersion 同步为 %s）'
        % (nxt_core, nxt_core, nxt_code, nxt_core))
    log('  交付文件  : %s' % OUT_DIR)
    return 0


if __name__ == '__main__':
    try:                                   # Windows 控制台默认 GBK，中文会乱码
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    sys.exit(main())
