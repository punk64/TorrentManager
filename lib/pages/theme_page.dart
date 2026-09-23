import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/page_style.dart';
import '../app/style_keys.dart';
import '../app/theme.dart';
import '../controllers/theme_controller.dart';
import '../utils/formatter.dart';
import '../utils/i18n.dart';
import '../utils/strings.dart';
import '../widgets/app_toast.dart';
import '../widgets/color_picker.dart';
import '../widgets/page_preview.dart';
import '../widgets/theme_preview.dart';















class ThemePage extends StatefulWidget {
  const ThemePage({super.key});

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  ThemeController get _tc => Get.find<ThemeController>();

  
  
  @override
  void initState() {
    super.initState();
    _tc.beginThemeEditing();
  }

  
  
  
  
  @override
  void dispose() {
    _tc.cancelThemeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = _tc;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.themeCustom),
        actions: <Widget>[
          
          TextButton.icon(
            onPressed: () => _saveDialog(context, tc),
            icon: const Icon(Icons.save_outlined, size: 16, color: Colors.white),
            label: Text(L.t('保存'),
                style: const TextStyle(fontSize: 12, color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              
              
              
              
              
              
              tc.restoreFactoryDefaults();
              _toast(S.restoreDefaults);
            },
            child: Text(S.restoreDefaults, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: <Widget>[
            
            
            
            
            
            ExpansionTile(
        clipBehavior: Clip.antiAlias,
              dense: true,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.palette, size: AppTheme.iconSize),
              title: Text(S.themeCustom, style: const TextStyle(fontSize: 12)),
              subtitle: Row(
                children: <Widget>[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: tc.seed.value,
                      borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_hex(tc.seed.value), style: const TextStyle(fontSize: 10)),
                ],
              ),
              children: <Widget>[
                ColorPicker(
                  color: tc.seed.value,
                  onChanged: tc.setSeed,
                ),
                const SizedBox(height: 8),
                
                const PagePreview(page: AppPageKey.serverList),
                const SizedBox(height: 8),
              ],
            ),

            
            
            
            
            
            ExpansionTile(
        clipBehavior: Clip.antiAlias,
              dense: true,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.text_fields, size: AppTheme.iconSize),
              title: Text(S.themeFontColor, style: const TextStyle(fontSize: 12)),
              subtitle: Row(
                children: <Widget>[
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: tc.effectiveFontColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tc.isFontColorCustom
                        ? _hex(tc.fontColor.value!)
                        : '${S.themeFontColorAuto}（${_hex(tc.effectiveFontColor)}）',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              children: <Widget>[
                ColorPicker(
                  color: tc.effectiveFontColor,
                  onChanged: tc.setFontColor,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.auto_awesome,
                        size: AppTheme.iconSize),
                    label: Text(S.themeFontColorAuto,
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      tc.setFontColor(null);
                      _toast(S.themeFontColorAuto);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    S.themeFontColorHelp,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: PagePreview(page: AppPageKey.serverList),
                ),
              ],
            ),

            const Divider(height: 20),

            
            
            
            
            
            
            
            
            
            
            
            
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(S.themeGlass, style: const TextStyle(fontSize: 12)),
              subtitle:
                  Text(S.themeGlassHelp, style: const TextStyle(fontSize: 10)),
              value: tc.glassEnabled,
              onChanged: tc.setGlassEnabled,
            ),
            _valueSlider(context, S.themeOpacity, tc.componentOpacity.value, 0, 1,
                tc.setComponentOpacity,
                (double v) => '${(v * 100).round()}%'),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
              child: Text(S.themeOpacityHelp, style: const TextStyle(fontSize: 10)),
            ),

            
            
            
            
            
            
            
            
            
            
            
            
            
            
            const SizedBox(height: 8),
            ThemePreview(
                theme: tc.previewTheme,
                transparency: tc.componentOpacity.value),

            const SizedBox(height: 8),

            
            
            
            
            _actionTile(Icons.menu_open, S.themePickMenuImage,
                () => _pick(context, tc)),
            
            
            
            
            
            
            
            
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 6, 0, 2),
              child: PagePreview(page: AppPageKey.drawer),
            ),
            
            
            
            
            
            if (tc.menuImagePath.value != null &&
                tc.menuImagePath.value != ThemeController.defaultMenuImage)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${S.fieldPath}${tc.menuImagePath.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            
            
            
            
            
            _valueSlider(context, L.t('亮度'), tc.menuBgBrightness.value, -1, 1,
                tc.setMenuBgBrightness,
                (double v) => '${(v * 100).round()}%'),
            _valueSlider(context, L.t('去色'), tc.menuBgFade.value, 0, 1,
                tc.setMenuBgFade, (double v) => '${(v * 100).round()}%'),
            _valueSlider(context, L.t('模糊'), tc.menuBgBlur.value, 0, 20,
                tc.setMenuBgBlur, (double v) => v.toStringAsFixed(1)),

            const Divider(height: 20),

            
            
            
            
            
            
            
            
            
            
            
            const SizedBox(height: 12),

            
            
            
            
            
            Text(
              L.t('全局背景图片'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(L.t('启用（作用于所有页面）'),
                  style: const TextStyle(fontSize: 12)),
              subtitle: Text(
                tc.globalBgEnabled.value
                    ? L.t('已启用：下面的图片与三档参数立即生效')
                    : L.t('未启用：下方选项已禁用，打开开关后才能调整'),
                style: const TextStyle(fontSize: 10),
              ),
              value: tc.globalBgEnabled.value,
              onChanged: tc.setGlobalBgEnabled,
            ),
            
            
            _actionTile(Icons.image, L.t('选择全局背景图'),
                () => _pickGlobalBg(context, tc),
                enabled: tc.globalBgEnabled.value),
            if (tc.globalBgImagePath.value != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${S.fieldPath}${tc.globalBgImagePath.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            _valueSlider(context, L.t('亮度'), tc.globalBgBrightness.value, -1, 1,
                tc.setGlobalBgBrightness,
                (double v) => '${(v * 100).round()}%',
                enabled: tc.globalBgEnabled.value),
            
            _valueSlider(context, L.t('去色'), tc.globalBgFade.value, 0, 1,
                tc.setGlobalBgFade, (double v) => '${(v * 100).round()}%',
                enabled: tc.globalBgEnabled.value),
            _valueSlider(context, L.t('模糊'), tc.globalBgBlur.value, 0, 20,
                tc.setGlobalBgBlur, (double v) => v.toStringAsFixed(1),
                enabled: tc.globalBgEnabled.value),
            
            
            if (tc.globalBgEnabled.value)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 2),
                child: PagePreview(
                  page: AppPageKey.serverList,
                  backgroundImage: tc.globalBgDecorationImage?.image,
                  
                  
                  useDefaultBackgroundIfEmpty: true,
                ),
              ),
            
            
            
            

            const SizedBox(height: 12),

            
            
            
            
            Text(
              L.t('分页面配色'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              L.t('未设置的分区跟随主题；设置后只影响对应页面。'),
              style: const TextStyle(fontSize: 10),
            ),
            for (final PageStyleSpec spec in kPageStyles)
              _pageStyleTile(context, tc, spec),

            
            
            
          ],
        ),
      ),
    );
  }

  

  
  

  
  
  

  
  
  
  
  Widget _actionTile(IconData icon, String title, VoidCallback onTap,
      {bool enabled = true}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      enabled: enabled,
      leading: Icon(icon, size: AppTheme.iconSize),
      title: Text(title, style: const TextStyle(fontSize: 12)),
      onTap: enabled ? onTap : null,
    );
  }

  
  

  

  
  
  
  
  Future<void> _pick(BuildContext context, ThemeController tc) async {
    try {
      final FilePickerResult? r = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      final String? path = r?.files.single.path;
      if (path == null) {
        _toast(S.noFileSelected);
        return;
      }
      tc.setMenuImage(path);
      
      
      
      
      final String name = path.split(RegExp(r'[/\\]')).last;
      _toast('${L.t('已保存：')}$name');
    } catch (e) {
      _toast('${S.themeSaveBgError}${Formatter.safeErr(e)}');
    }
  }

  
  
  
  
  Widget _valueSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String Function(double) format, {
    bool enabled = true,
  }) {
    
    
    
    final Color? dim = enabled ? null : Theme.of(context).disabledColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: dim)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: 20,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              format(value),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 10, color: dim),
            ),
          ),
        ],
      ),
    );
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  Future<void> _saveDialog(BuildContext context, ThemeController tc) async {
    final List<CustomTheme> targets = tc.overwriteCandidates;
    CustomTheme? target = tc.defaultOverwriteTarget;
    final bool editingSaved = tc.editingCustomId != null;
    final TextEditingController ctrl = TextEditingController(
      text: target?.name ?? _defaultThemeName(tc),
    );

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(L.t(editingSaved ? '保存修改' : '保存自定义主题'),
              style: const TextStyle(fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: L.t('主题名称'),
                  hintText: L.t('例如：我的暗夜紫'),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              if (targets.length > 1) ...<Widget>[
                const SizedBox(height: 12),
                Text(L.t('覆盖目标'), style: const TextStyle(fontSize: 11)),
                DropdownButton<CustomTheme>(
                  value: target,
                  isExpanded: true,
                  
                  
                  
                  
                  
                  
                  style: TextStyle(
                      fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface),
                  items: <DropdownMenuItem<CustomTheme>>[
                    for (final CustomTheme t in targets)
                      DropdownMenuItem<CustomTheme>(
                        value: t,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (CustomTheme? v) => setLocal(() => target = v),
                ),
              ],
              if (target != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    
                    
                    editingSaved
                        ? '「${target!.name}」'
                            '${L.t('是正在编辑的主题。点「覆盖更新」把改动写回它，或点「保存为新主题」另存一份。')}'
                        : '「${target!.name}」'
                            '${L.t('已存在。点「覆盖更新」会用当前配置替换它的全部内容（不可撤销），或点「保存为新主题」另存一份。')}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(L.t('取消')),
            ),
            if (target != null)
              
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('update'),
                child: Text('${L.t('覆盖更新')}「${target!.name}」',
                    style: const TextStyle(fontSize: 12)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('new'),
              child: Text(L.t('保存为新主题')),
            ),
          ],
        ),
      ),
    );

    if (action == null) {
      ctrl.dispose();
      return;
    }
    
    final String name = ctrl.text.trim().isEmpty
        ? (target?.name ?? _defaultThemeName(tc))
        : ctrl.text.trim();
    if (action == 'update' && target != null) {
      
      
      await tc.overwriteThemeEditing(target!.id, name: name);
      _toast('${L.t('已更新')}「$name」');
    } else {
      await tc.commitThemeEditing(name);
      _toast('${L.t('已保存')}「$name」');
    }
    ctrl.dispose();
    if (!context.mounted) return;
    
    Navigator.of(context).pop();
  }

  String _defaultThemeName(ThemeController tc) =>
      '${L.t('自定义主题')} ${tc.customThemes.length + 1}';

  Widget _pageStyleTile(
    BuildContext context,
    ThemeController tc,
    PageStyleSpec spec,
  ) {
    final int custom = spec.slots
        .where((AppStyleSlot s) => tc.pageColor(spec.key, s) != null)
        .length;
    return ExpansionTile(
        clipBehavior: Clip.antiAlias,
      dense: true,
      tilePadding: EdgeInsets.zero,
      leading: Icon(pageIconOf(spec.key), size: AppTheme.iconSize),
      title: Text(spec.titleLocalized, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        custom == 0 ? S.themeFontColorAuto : L.pick('已自定义 $custom 项', 'Customized: $custom'),
        style: const TextStyle(fontSize: 10),
      ),
      children: <Widget>[
        if (spec.help != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(spec.helpLocalized!, style: const TextStyle(fontSize: 10)),
          ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
          child: PagePreview(page: spec.key),
        ),
        for (final AppStyleSlot slot in spec.slots)
          _slotRow(context, tc, spec, slot),
      ],
    );
  }

  
  Widget _slotRow(
    BuildContext context,
    ThemeController tc,
    PageStyleSpec spec,
    AppStyleSlot slot,
  ) {
    final Color? c = tc.pageColor(spec.key, slot);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c ?? Colors.transparent,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(AppTheme.radiusTiny),
            ),
            child: c == null
                ? const Icon(Icons.remove, size: 14, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(spec.labelOf(slot),
                style: const TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: () => _pickSlotColor(context, tc, spec, slot),
            child: Text(L.t('选择'), style: const TextStyle(fontSize: 11)),
          ),
          if (c != null)
            TextButton(
              onPressed: () => tc.setPageColor(spec.key, slot, null),
              child: Text(L.t('跟随主题'), style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  
  Future<void> _pickSlotColor(
    BuildContext context,
    ThemeController tc,
    PageStyleSpec spec,
    AppStyleSlot slot,
  ) async {
    Color temp = tc.pageColor(spec.key, slot) ?? tc.seed.value;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('${spec.titleLocalized} · ${spec.labelOf(slot)}',
            style: const TextStyle(fontSize: 13)),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: temp,
            onChanged: (Color c) => temp = c,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () {
              tc.setPageColor(spec.key, slot, temp);
              Navigator.of(ctx).pop();
            },
            child: Text(L.t('保存')),
          ),
        ],
      ),
    );
  }

  
  Future<void> _pickGlobalBg(BuildContext context, ThemeController tc) async {
    try {
      final FilePickerResult? r = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      final String? path = r?.files.single.path;
      if (path == null) {
        _toast(S.noFileSelected);
        return;
      }
      tc.setGlobalBgImage(path);
      _toast(L.t('已保存'));
    } catch (e) {
      _toast('${S.themeSaveBgError}${Formatter.safeErr(e)}');
    }
  }

  
  void _toast(String msg) => AppToast.show(msg);

  static String _hex(Color c) =>
      '#${(((c.r * 255).round() << 16) | ((c.g * 255).round() << 8) | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
