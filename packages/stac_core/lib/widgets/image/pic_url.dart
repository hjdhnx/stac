/// drpyS / T4 图片防盗链约定：真实 URL 尾缀内嵌请求头
/// `x.jpg@Referer=https://api.douban.com/@User-Agent=Mozilla/5.0 (…)`。
///
/// **不剥离一定挂**：URL 里带空格不合法（请求直接失败），剥掉却不带 Referer
/// 又会被图床 403 —— 两件事都得做。与 DsPlayer `parseT4PicUrl`
/// （`lib/models/t4/t4.dart`）同口径，判定略严：尾缀每段必须是 `Name=value`
/// 且 Name 像 HTTP 头名，否则整串当 URL 原样返回（避免 `poster@2x.png`
/// 这类正常文件名被误拆）。
///
/// 放在解析器 / 模型层而不是页面 JS：海报 URL 常以 `{{vodPic}}` 模板形式下发，
/// 真实值由 `template_binder` 在 Dart 侧绑定，JS 静态阶段看不到。
({String url, Map<String, String>? headers}) splitPicHeaders(String raw) {
  final at = raw.indexOf('@');
  if (at <= 0) return (url: raw, headers: null);
  final nameRe = RegExp(r'^[A-Za-z][A-Za-z0-9-]*$');
  final headers = <String, String>{};
  for (final part in raw.substring(at + 1).split('@')) {
    final eq = part.indexOf('=');
    if (eq <= 0) return (url: raw, headers: null);
    final name = part.substring(0, eq).trim();
    final value = part.substring(eq + 1).trim();
    if (value.isEmpty || !nameRe.hasMatch(name)) {
      return (url: raw, headers: null);
    }
    headers[name] = value;
  }
  return (url: raw.substring(0, at), headers: headers.isEmpty ? null : headers);
}
