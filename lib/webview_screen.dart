import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'auth_token_service.dart';
import 'constants.dart';
import 'services/download_service.dart';
import 'services/file_picker_service.dart';
import 'services/snackbar_service.dart';
import 'services/window_service.dart';

const String _kDesktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/17.5 Safari/605.1.15';

class StolityWebView extends StatefulWidget {
  const StolityWebView({super.key});

  @override
  State<StolityWebView> createState() => _StolityWebViewState();
}

class _StolityWebViewState extends State<StolityWebView>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? _controller;
  bool _ready = false;
  bool _showNavPill = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isPillHovered = false;
  double _pillIdleOpacity = 1.0;
  Timer? _navStateTimer;
  Timer? _pillIdleTimer;
  Timer? _pillShowDelayTimer;
  late final AnimationController _pillAnimationController;
  late final Animation<Offset> _pillSlideAnimation;
  late final Animation<double> _pillFadeAnimation;

  String? _savedKey;
  String? _savedToken;
  bool _tokenInjected = false;

  bool _hadSavedTokenAtStart = false;
  bool _initialLoadCompleted = false;

  String? _lastMainUrl;
  Timer? _postTransitionExtractTimer;

  @override
  void initState() {
    super.initState();
    _pillAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _pillSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pillAnimationController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
    _pillFadeAnimation = CurvedAnimation(
      parent: _pillAnimationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _pillAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _showNavPill && mounted) {
        setState(() => _showNavPill = false);
      }
    });
    _startup();
  }

  Future<void> _startup() async {
    await _attemptAutoLogin();
    await initializeWindow();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _attemptAutoLogin() async {
    final info = await AuthTokenService.loadTokenInfo();
    if (info != null && AuthTokenService.isTokenValid(info['token']!)) {
      _savedKey = info['key'];
      _savedToken = info['token'];
      _hadSavedTokenAtStart = true;
    } else {
      await AuthTokenService.clear();
      _savedKey = null;
      _savedToken = null;
      _hadSavedTokenAtStart = false;
    }
  }

  Future<void> _clearStoredAuth(String reason) async {
    _savedKey = null;
    _savedToken = null;
    _hadSavedTokenAtStart = false;
    _tokenInjected = false;
    try {
      await AuthTokenService.clear();
    } catch (_) {}
    try {
      await _controller?.evaluateJavascript(source: '''
        try {
          sessionStorage.removeItem(${jsonEncode(_savedKey ?? '')});
          window.__stolityAutoLoginDisabled = true;
        } catch(_) {}
      ''');
    } catch (_) {}
  }

  @override
  void dispose() {
    _navStateTimer?.cancel();
    _pillIdleTimer?.cancel();
    _pillShowDelayTimer?.cancel();
    _postTransitionExtractTimer?.cancel();
    _pillAnimationController.dispose();
    super.dispose();
  }

  bool _isAuthFlowUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host.contains('accounts.google.com') ||
        host.endsWith('googleusercontent.com') ||
        (host.endsWith('google.com') && path.startsWith('/o/oauth2'))) {
      return true;
    }

    if (host.endsWith('stolity.com')) {
      return path == '/login' ||
          path.startsWith('/login/') ||
          path == '/signup' ||
          path.startsWith('/signup/') ||
          path.startsWith('/sign-up') ||
          path.startsWith('/forgot') ||
          path.startsWith('/reset-password') ||
          path.startsWith('/auth');
    }
    return false;
  }

  bool _isOurAppOrigin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host.toLowerCase().endsWith('stolity.com');
  }

  void _handleRouteUpdate(String url) {
    final lower = url.toLowerCase();
    final prev = _lastMainUrl ?? '';
    final wasOnLogin = prev.toLowerCase().contains('/login');
    final nowOffLogin = !lower.contains('/login') && _isOurAppOrigin(url);
    if (wasOnLogin && nowOffLogin) {
      _scheduleTransitionExtraction();
    }

    if (!_initialLoadCompleted &&
        _hadSavedTokenAtStart &&
        _isOurAppOrigin(url) &&
        lower.contains('/login')) {
      _clearStoredAuth('token rejected on initial load');
    }
    _initialLoadCompleted = true;

    _lastMainUrl = url;

    final shouldShow = !_isAuthFlowUrl(url);
    if (!mounted) return;
    _performAuthLogic(url);

    if (!shouldShow) {
      _pillShowDelayTimer?.cancel();
      if (_showNavPill) _pillAnimationController.reverse();
      return;
    }

    if (_showNavPill &&
        _pillAnimationController.status == AnimationStatus.forward) {
      return;
    }

    _pillShowDelayTimer?.cancel();
    _pillShowDelayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showNavPill = true);
      _pillAnimationController.forward();
      _onPillInteraction();
    });
  }

  Future<void> _performAuthLogic(String url) async {
    if (!mounted) return;
    if (!_isOurAppOrigin(url)) return;
    if (_tokenInjected) return;
    if (_isAuthFlowUrl(url)) return;

    const extractJs = r'''
      (function() {
        try {
          var jwtRe = /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
          for (var i = 0; i < sessionStorage.length; i++) {
            var key = sessionStorage.key(i);
            var val = sessionStorage.getItem(key);
            if (val && jwtRe.test(val)) {
              return JSON.stringify({key:key, token:val});
            }
          }
        } catch(e) {}
        return null;
      })();
    ''';
    try {
      final raw = await _controller?.evaluateJavascript(source: extractJs);
      if (raw != null && raw.toString() != 'null' && raw.toString().isNotEmpty) {
        final asString = raw is String ? raw : jsonEncode(raw);
        final map = jsonDecode(asString) as Map<String, dynamic>;
        final key = map['key'] as String;
        final token = map['token'] as String;
        await AuthTokenService.saveToken(key, token);
        _savedKey = key;
        _savedToken = token;
        _tokenInjected = true;
      }
    } catch (_) {}
  }

  void _scheduleTransitionExtraction() {
    _postTransitionExtractTimer?.cancel();
    var attempts = 0;
    const maxAttempts = 8;
    _postTransitionExtractTimer =
        Timer.periodic(const Duration(milliseconds: 500), (t) async {
      attempts++;
      if (!mounted || _tokenInjected) {
        t.cancel();
        return;
      }
      await _performAuthLogic(_lastMainUrl ?? '');
      if (_tokenInjected || attempts >= maxAttempts) {
        t.cancel();
      }
    });
  }
  void _onPillInteraction() {
    if (!_showNavPill || !mounted) return;
    _pillIdleTimer?.cancel();
    if (_pillIdleOpacity != 1.0) {
      setState(() => _pillIdleOpacity = 1.0);
    }
    _pillIdleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isPillHovered || !_showNavPill) return;
      setState(() => _pillIdleOpacity = 0.7);
    });
  }

  void _setPillHover(bool hovered) {
    if (_isPillHovered == hovered || !mounted) return;
    setState(() {
      _isPillHovered = hovered;
      _pillIdleOpacity = hovered ? 1.0 : _pillIdleOpacity;
    });
    if (hovered) {
      _pillIdleTimer?.cancel();
    } else {
      _onPillInteraction();
    }
  }

  Future<void> _updateNavigationState() async {
    if (_controller == null) return;
    bool nextBack = false;
    bool nextForward = false;
    try {
      nextBack = await _controller!.canGoBack();
      nextForward = await _controller!.canGoForward();
    } catch (_) {}
    if (!mounted) return;
    if (nextBack != _canGoBack || nextForward != _canGoForward) {
      setState(() {
        _canGoBack = nextBack;
        _canGoForward = nextForward;
      });
    }
  }

  void _startNavigationStateTracking() {
    _navStateTimer?.cancel();
    _navStateTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      _updateNavigationState();
    });
  }

  Future<void> _goBack() async {
    _onPillInteraction();
    if (!_canGoBack) return;
    try {
      await _controller?.goBack();
      await _updateNavigationState();
    } catch (_) {}
  }

  Future<void> _goForward() async {
    _onPillInteraction();
    if (!_canGoForward) return;
    try {
      await _controller?.goForward();
      await _updateNavigationState();
    } catch (_) {}
  }

  Future<void> _reloadPage() async {
    _onPillInteraction();
    try {
      await _controller?.reload();
      await _updateNavigationState();
    } catch (_) {}
  }

  static const String _disableContextMenuJs = r'''
    (function(){
      if (window.__stolityDisableContextMenu) return;
      window.__stolityDisableContextMenu = true;
      function _stolityPrevent(e){ try{ e.preventDefault(); e.stopPropagation(); }catch(_){}}
      document.addEventListener('contextmenu', _stolityPrevent, true);
      window.addEventListener('contextmenu', _stolityPrevent, true);
      document.addEventListener('mousedown', function(e){ if (e && e.button === 2) _stolityPrevent(e); }, true);
      (function(){
        var _add = EventTarget.prototype.addEventListener;
        EventTarget.prototype.addEventListener = function(type, listener, options){
          if (String(type).toLowerCase() === 'contextmenu') return;
          return _add.call(this, type, listener, options);
        };
        try{ Object.defineProperty(HTMLElement.prototype, 'oncontextmenu', { set: function(){}, get: function(){ return null; }, configurable: true }); }catch(e){}
      })();
    })();
  ''';

  static const String _downloadInterceptJs = r'''
    (function(){
      if (window.__stolityDownloadPatched) return;
      window.__stolityDownloadPatched = true;
      function sendMessage(obj){
        try { window.flutter_inappwebview.callHandler('FlutterDownload', obj); } catch(e) {}
      }
      function isDownloadAnchor(a){
        if(!a) return false;
        if (a.hasAttribute && a.hasAttribute('download')) return true;
        var href = a.getAttribute && a.getAttribute('href') || '';
        if(!href) return false;
        if (href.indexOf('blob:')===0 || href.indexOf('data:')===0) return true;
        return /\.(zip|exe|pdf|docx?|xlsx?|pptx?|png|jpe?g|gif|csv|tar|gz|rar|7z)$/i.test(href);
      }
      document.addEventListener('click', function(e){
        var t = e.target;
        while(t && t.tagName !== 'A') t = t.parentElement;
        if(!t) return;
        if(!isDownloadAnchor(t)) return;
        e.preventDefault();
        var href = t.href || t.getAttribute('href') || '';
        var suggested = (t.getAttribute && (t.getAttribute('download') || t.getAttribute('data-filename'))) || '';
        if (href.indexOf('blob:') === 0) {
          fetch(href).then(function(r){ return r.blob(); }).then(function(blob){
            var reader = new FileReader();
            reader.onload = function(){
              try {
                var dataUrl = reader.result || '';
                var comma = dataUrl.indexOf(',');
                var b64 = dataUrl.substring(comma + 1);
                sendMessage({type:'download-blob', filename: suggested || '', b64: b64});
              } catch(err){ sendMessage({type:'download-error', error: String(err), url: href}); }
            };
            reader.onerror = function(e){ sendMessage({type:'download-error', error: String(e), url: href}); };
            reader.readAsDataURL(blob);
          }).catch(function(err){ sendMessage({type:'download-error', error: String(err), url: href}); });
        } else if (href.indexOf('data:') === 0) {
          var comma = href.indexOf(',');
          var meta = href.substring(5, comma);
          var isBase64 = /;base64$/.test(meta);
          var b64 = href.substring(comma+1);
          if (!isBase64) b64 = btoa(decodeURIComponent(b64));
          sendMessage({type:'download-b64', filename: suggested || '', b64: b64});
        } else {
          sendMessage({type:'download-url', url: href, filename: suggested || ''});
        }
      }, true);
    })();
  ''';

  static const String _filePickerPatchJs = r'''
    (function(){
      if (window.__stolityFilePickerPatched) return;
      window.__stolityFilePickerPatched = true;
      function patchInput(input){
        if (input._flutterPatched) return;
        input._flutterPatched = true;
        input.addEventListener('click', function(e){
          e.preventDefault();
          e.stopImmediatePropagation();
          var isFolder = input.hasAttribute('webkitdirectory') ||
                         input.hasAttribute('directory') ||
                         input.getAttribute('webkitdirectory') === '' ||
                         input.getAttribute('webkitdirectory') === 'true';
          window.flutter_inappwebview.callHandler('FlutterFilePicker', {
            accept: input.accept || '',
            multiple: input.multiple || false,
            isFolder: isFolder,
            inputId: input.id || ''
          });
        }, true);
      }
      document.querySelectorAll('input[type="file"]').forEach(patchInput);
      new MutationObserver(function(mutations){
        mutations.forEach(function(m){
          m.addedNodes.forEach(function(node){
            if (node.nodeType !== 1) return;
            if (node.matches && node.matches('input[type="file"]')) patchInput(node);
            if (node.querySelectorAll) node.querySelectorAll('input[type="file"]').forEach(patchInput);
          });
        });
      }).observe(document.documentElement, { childList: true, subtree: true });

      var originalClick = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function(){
        if (this.type === 'file') {
          var isFolder = this.hasAttribute('webkitdirectory') ||
                         this.hasAttribute('directory') ||
                         this.getAttribute('webkitdirectory') === '' ||
                         this.getAttribute('webkitdirectory') === 'true';
          window.flutter_inappwebview.callHandler('FlutterFilePicker', {
            accept: this.accept || '',
            multiple: this.multiple || false,
            isFolder: isFolder
          });
          return;
        }
        return originalClick.apply(this, arguments);
      };
    })();
  ''';

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      isInspectable: !kReleaseMode,
      javaScriptEnabled: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      userAgent: _kDesktopUserAgent,
      thirdPartyCookiesEnabled: true,
      useOnDownloadStart: true,
      transparentBackground: true,
    );
  }

  List<UserScript> _buildUserScripts() {
    final scripts = <UserScript>[
      UserScript(
        source: _disableContextMenuJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: _downloadInterceptJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
      UserScript(
        source: _filePickerPatchJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
    ];
    final auto = _buildAutoLoginUserScript();
    if (auto != null) scripts.add(auto);
    return scripts;
  }

  UserScript? _buildAutoLoginUserScript() {
    final key = _savedKey;
    final token = _savedToken;
    if (key == null || token == null) return null;
    final keyJson = jsonEncode(key);
    final tokenJson = jsonEncode(token);
    return UserScript(
      source: '''
        (function() {
          try {
            if (window.__stolityAutoLoginDisabled) return;
            var path = (location.pathname || '').toLowerCase();
            if (path.indexOf('/login') !== -1 ||
                path.indexOf('/signup') !== -1 ||
                path.indexOf('/sign-up') !== -1) return;
            var host = (location.hostname || '').toLowerCase();
            if (host.indexOf('stolity.com') === -1) return;
            var k = $keyJson;
            if (!sessionStorage.getItem(k)) {
              sessionStorage.setItem(k, $tokenJson);
            }
          } catch(e) {}
        })();
      ''',
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );
  }

  void _registerJsHandlers(InAppWebViewController c) {
    c.addJavaScriptHandler(
      handlerName: 'FlutterDownload',
      callback: (args) async {
        if (args.isEmpty || args.first is! Map) return;
        await _handleDownloadMessage(args.first as Map);
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'FlutterFilePicker',
      callback: (args) async {
        if (args.isEmpty) return;
        final payload = args.first;
        final message =
            payload is String ? payload : jsonEncode(payload);
        await handleFilePick(message, _controller);
      },
    );
  }

  Future<void> _handleDownloadMessage(Map parsed) async {
    try {
      final String? type = parsed['type'] as String?;
      if (type == 'download-url' && parsed['url'] != null) {
        final url = parsed['url'] as String;
        final filename = (parsed['filename'] as String?) ?? '';
        if (url.isNotEmpty) {
          try {
            final file = await DownloadService.downloadUrl(
              url,
              suggestedFilename: filename.isNotEmpty ? filename : null,
            );
            if (mounted) {
              showReusableSnackbar(context,
                  'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
            }
          } catch (_) {}
        }
      } else if ((type == 'download-blob' || type == 'download-b64') &&
          parsed['b64'] != null) {
        final b64 = parsed['b64'] as String;
        final filename = (parsed['filename'] as String?) ?? '';
        try {
          final file = await DownloadService.downloadBase64(
              b64, filename.isNotEmpty ? filename : 'file');
          if (mounted) {
            showReusableSnackbar(context,
                'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  bool _popupOpen = false;

  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    if (_popupOpen || !mounted) return false;
    _popupOpen = true;

    final int windowId = action.windowId;

    if (!mounted) {
      _popupOpen = false;
      return false;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 520,
            height: 700,
            child: _PopupShell(
              onClose: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: InAppWebView(
                windowId: windowId,
                initialSettings: _buildSettings(),
                initialUserScripts: UnmodifiableListView(_buildUserScripts()),
                onWebViewCreated: (popupController) {
                  _registerJsHandlers(popupController);
                },
                onLoadStart: (c, u) {},
                onLoadStop: (c, u) {},
                onUpdateVisitedHistory: (c, u, _) {},
                onCloseWindow: (c) {
                  if (mounted &&
                      Navigator.of(dialogContext, rootNavigator: true)
                          .canPop()) {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  }
                },
                onConsoleMessage: (c, msg) {},
                onPermissionRequest: (c, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    _tokenInjected = false;
    _popupOpen = false;
    _scheduleTransitionExtraction();
    return true;
  }
  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: kBackgroundColor);
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          ColoredBox(
            color: kBackgroundColor,
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(_hadSavedTokenAtStart
                    ? kStolityFilesUrl
                    : kStolityLoginUrl),
              ),
              initialSettings: _buildSettings(),
              initialUserScripts:
                  UnmodifiableListView(_buildUserScripts()),
              onWebViewCreated: (controller) {
                _controller = controller;
                _registerJsHandlers(controller);
                _startNavigationStateTracking();
              },
              onLoadStart: (c, u) {},
              onLoadStop: (c, u) async {
                final urlStr = u?.toString() ?? '';
                if (urlStr.isNotEmpty) _handleRouteUpdate(urlStr);
                await _updateNavigationState();
              },
              onUpdateVisitedHistory: (c, u, _) {
                final urlStr = u?.toString() ?? '';
                if (urlStr.isNotEmpty) _handleRouteUpdate(urlStr);
              },
              shouldOverrideUrlLoading: (c, navAction) async {
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: _onCreateWindow,
              onCloseWindow: (c) {},
              onPermissionRequest: (c, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onConsoleMessage: (c, msg) {},
              onDownloadStartRequest: (c, req) async {
                try {
                  final file = await DownloadService.downloadUrl(
                    req.url.toString(),
                    suggestedFilename: req.suggestedFilename,
                  );
                  if (!context.mounted) return;
                  showReusableSnackbar(context,
                      'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
                } catch (_) {}
              },
            ),
          ),
          _buildNavigationPill(),
        ],
      ),
    );
  }

  Widget _buildNavigationPill() {
    if (!_showNavPill) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: FadeTransition(
            opacity: _pillFadeAnimation,
            child: SlideTransition(
              position: _pillSlideAnimation,
              child: MouseRegion(
                cursor: SystemMouseCursors.basic,
                onEnter: (_) => _setPillHover(true),
                onExit: (_) => _setPillHover(false),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pillIdleOpacity,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOut,
                    scale: _isPillHovered ? 1.02 : 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: const Color(0x4DFFFFFF), width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _NavPillIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  enabled: _canGoBack,
                                  onTap: _goBack,
                                  onInteract: _onPillInteraction,
                                ),
                                _NavPillIconButton(
                                  icon: Icons.arrow_forward_rounded,
                                  enabled: _canGoForward,
                                  onTap: _goForward,
                                  onInteract: _onPillInteraction,
                                ),
                                _NavPillIconButton(
                                  icon: Icons.refresh_rounded,
                                  enabled: true,
                                  onTap: _reloadPage,
                                  onInteract: _onPillInteraction,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupShell extends StatelessWidget {
  const _PopupShell({required this.onClose, required this.child});
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xFFF5F6F8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(child: child),
      ],
    );
  }
}

class _NavPillIconButton extends StatefulWidget {
  const _NavPillIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.onInteract,
  });

  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;
  final VoidCallback onInteract;

  @override
  State<_NavPillIconButton> createState() => _NavPillIconButtonState();
}

class _NavPillIconButtonState extends State<_NavPillIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveScale = _pressed ? 0.92 : (_hovered ? 1.04 : 1.0);
    final effectiveBg = !_hovered
        ? Colors.transparent
        : (widget.enabled ? const Color(0x1A000000) : const Color(0x0D000000));
    final iconColor =
        widget.enabled ? const Color(0xE6000000) : const Color(0x66000000);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) {
          setState(() => _hovered = true);
          widget.onInteract();
        },
        onExit: (_) {
          setState(() {
            _hovered = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (_) {
                  setState(() => _pressed = true);
                  widget.onInteract();
                }
              : null,
          onTapCancel: () {
            if (_pressed) setState(() => _pressed = false);
          },
          onTap: widget.enabled
              ? () async {
                  widget.onInteract();
                  await widget.onTap();
                  if (mounted) setState(() => _pressed = false);
                }
              : null,
          child: AnimatedScale(
            scale: effectiveScale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: effectiveBg,
              ),
              child: Icon(widget.icon, size: 19, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
