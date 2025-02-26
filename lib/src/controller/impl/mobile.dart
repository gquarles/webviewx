import 'dart:async' show Future;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webviewx/src/utils/html_utils.dart';
import 'package:webviewx/src/utils/source_type.dart';
import 'package:webviewx/src/utils/utils.dart';

import 'package:webviewx/src/controller/interface.dart' as i;

/// Mobile implementation
class WebViewXController extends ChangeNotifier
    implements i.WebViewXController<wf.WebViewController> {
  /// Webview controller connector
  @override
  late wf.WebViewController connector;

  /// Boolean value notifier used to toggle ignoring gestures on the webview
  final ValueNotifier<bool> _ignoreAllGesturesNotifier;

  /// INTERNAL
  /// Used to tell the last used [SourceType] and last headers.
  late WebViewContent value;

  /// Constructor
  WebViewXController({
    required String initialContent,
    required SourceType initialSourceType,
    required bool ignoreAllGestures,
  })  : _ignoreAllGesturesNotifier = ValueNotifier(ignoreAllGestures),
        value = WebViewContent(
          source: initialContent,
          sourceType: initialSourceType,
        );

  /// Boolean getter which reveals if the gestures are ignored right now
  @override
  bool get ignoresAllGestures => _ignoreAllGesturesNotifier.value;

  /// Set ignore gestures on/off (true/false)
  @override
  void setIgnoreAllGestures(bool value) {
    _ignoreAllGesturesNotifier.value = value;
  }

  /// Returns true if the webview's current content is HTML
  @override
  bool get isCurrentContentHTML => value.sourceType == SourceType.html;

  /// Returns true if the webview's current content is URL
  @override
  bool get isCurrentContentURL => value.sourceType == SourceType.url;

  /// Returns true if the webview's current content is URL, and if
  /// [SourceType] is [SourceType.urlBypass], which means it should
  /// use the bypass to fetch the web page content.
  @override
  bool get isCurrentContentURLBypass =>
      value.sourceType == SourceType.urlBypass;

  /// Set webview content to the specified `content`.
  /// Example: https://flutter.dev/
  /// Example2: '<html><head></head> <body> <p> Hi </p> </body></html>
  ///
  /// If `fromAssets` param is set to true,
  /// `content` param must be a String path to an asset
  /// Example: `assets/some_url.txt`
  ///
  /// `headers` are optional HTTP headers.
  ///
  /// `body` is only used on the WEB version, when clicking on a submit button in a form
  ///
  @override
  Future<void> loadContent(
    String content,
    SourceType sourceType, {
    Map<String, String>? headers,
    Object? body, // NO-OP HERE
    bool fromAssets = false,
  }) async {
    if (fromAssets) {
      final _content = await rootBundle.loadString(content);

      value = WebViewContent(
        source: _content,
        sourceType: sourceType,
        headers: headers,
      );
    } else {
      value = WebViewContent(
        source: content,
        sourceType: sourceType,
        headers: headers,
      );
    }

    if (sourceType == SourceType.html) {
      await connector.loadHtmlString(
        HtmlUtils.preprocessSource(
          value.source,
          jsContent: const {},
          encodeHtml: true,
        ),
      );
    } else {
      await connector.loadRequest(
        Uri.parse(value.source),
        headers: headers ?? {},
      );
    }
    _notifyWidget();
  }

  /// This function allows you to call Javascript functions defined inside the webview.
  ///
  /// Suppose we have a defined a function (using [EmbeddedJsContent]) as follows:
  ///
  /// ```javascript
  /// function someFunction(param) {
  ///   return 'This is a ' + param;
  /// }
  /// ```
  /// Example call:
  ///
  /// ```dart
  /// var resultFromJs = await callJsMethod('someFunction', ['test'])
  /// print(resultFromJs); // prints "This is a test"
  /// ```
  @override
  Future<dynamic> callJsMethod(
    String name,
    List<dynamic> params,
  ) async {
    // This basically will transform a "raw" call (evaluateJavascript)
    // into a little bit more "typed" call, that is - calling a method.
    final result = await connector.runJavaScriptReturningResult(
      HtmlUtils.buildJsFunction(name, params),
    );

    // (MOBILE ONLY) Unquotes response if necessary
    //
    // In the mobile version responses from Js to Dart come wrapped in single quotes (')
    // The web works fine because it is already into it's native environment
    return result is String
        ? HtmlUtils.unQuoteJsResponseIfNeeded(result)
        : result;
  }

  /// Evaluates the given JavaScript [code] in the context of the current page.
  @override
  Future<dynamic> evalRawJavascript(
    String code, {
    bool inGlobalContext = false,
  }) async {
    try {
      final result = await connector.runJavaScriptReturningResult(code);
      return result is String
          ? HtmlUtils.unQuoteJsResponseIfNeeded(result)
          : result;
    } catch (e) {
      return null;
    }
  }

  /// Gets the current content
  @override
  Future<WebViewContent> getContent() async {
    return value;
  }

  /// Returns a Future that completes with the value true, if you can go
  /// back in the history stack.
  @override
  Future<bool> canGoBack() {
    return connector.canGoBack();
  }

  /// Returns a Future that completes with the value true, if you can go
  /// forward in the history stack.
  @override
  Future<bool> canGoForward() {
    return connector.canGoForward();
  }

  /// Gets the height of the HTML content.
  @override
  Future<double?> getScrollHeight() async {
    final result = await evalRawJavascript(
      'document.documentElement.scrollHeight;',
    );
    if (result == null) return null;
    if (result is num) return result.toDouble();
    return double.tryParse(result.toString());
  }

  /// Gets the width of the HTML content.
  @override
  Future<double?> getScrollWidth() async {
    final result = await evalRawJavascript(
      'document.documentElement.scrollWidth;',
    );
    if (result == null) return null;
    if (result is num) return result.toDouble();
    return double.tryParse(result.toString());
  }

  /// Reloads the current content.
  @override
  Future<void> reload() async {
    await connector.reload();
  }

  /// Goes back in history.
  @override
  Future<void> goBack() async {
    if (await connector.canGoBack()) {
      await connector.goBack();
    }
  }

  /// Goes forward in history.
  @override
  Future<void> goForward() async {
    if (await connector.canGoForward()) {
      await connector.goForward();
    }
  }

  /// Get scroll position on X axis
  @override
  Future<int> getScrollX() async {
    final result = await evalRawJavascript('window.scrollX');
    if (result is num) return result.toInt();
    return 0;
  }

  /// Get scroll position on Y axis
  @override
  Future<int> getScrollY() async {
    final result = await evalRawJavascript('window.scrollY');
    if (result is num) return result.toInt();
    return 0;
  }

  /// Scrolls by `x` on X axis and by `y` on Y axis
  @override
  Future<void> scrollBy(int x, int y) {
    return connector.runJavaScript(
      'window.scrollBy($x, $y)',
    );
  }

  /// Scrolls exactly to the position `(x, y)`
  @override
  Future<void> scrollTo(int x, int y) {
    return connector.runJavaScript(
      'window.scrollTo($x, $y)',
    );
  }

  /// Retrieves the inner page title
  @override
  Future<String?> getTitle() async {
    final result = await evalRawJavascript('document.title');
    return result?.toString();
  }

  /// Clears cache
  @override
  Future<void> clearCache() async {
    await connector.clearCache();
    await connector.clearLocalStorage();
  }

  /// INTERNAL
  void addIgnoreGesturesListener(void Function() cb) {
    _ignoreAllGesturesNotifier.addListener(cb);
  }

  /// INTERNAL
  void removeIgnoreGesturesListener(void Function() cb) {
    _ignoreAllGesturesNotifier.removeListener(cb);
  }

  void _notifyWidget() {
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _ignoreAllGesturesNotifier.dispose();
    super.dispose();
  }
}
