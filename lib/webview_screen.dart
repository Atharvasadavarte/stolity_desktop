import 'dart:async';
import 'dart:io';
import 'dart:ui';
import '../services/snackbar_service.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

import 'constants.dart';
import 'services/file_picker_service.dart';
import 'services/window_service.dart';
import 'services/download_service.dart';
import 'dart:convert';
import 'auth_token_service.dart';

class StolityWebView extends StatefulWidget {
  const StolityWebView({super.key});

  @override
  State<StolityWebView> createState() => _StolityWebViewState();
}

class _StolityWebViewState extends State<StolityWebView> with SingleTickerProviderStateMixin {
  final WebviewController _windowsController = WebviewController();
  WebViewController? _macController;
  bool _ready = false;
  bool _popupOpen = false;
  bool _showNavPill = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isPillHovered = false;
  double _pillIdleOpacity = 1.0;
  Timer? _navStateTimer;
  Timer? _pillIdleTimer;
  Timer? _pillShowDelayTimer;
  StreamSubscription<HistoryChanged>? _windowsHistorySubscription;
  StreamSubscription<String>? _windowsUrlSubscription;
  bool _windowsCanGoBack = false;
  bool _windowsCanGoForward = false;
  late final AnimationController _pillAnimationController;
  late final Animation<Offset> _pillSlideAnimation;
  late final Animation<double> _pillFadeAnimation;
  // Added fields for JWT handling
  String? _savedKey;
  String? _savedToken;
  bool _tokenInjected = false;
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
        setState(() {
          _showNavPill = false;
        });
      }
    });
    _startup();
  }

  Future<void> _startup() async {
    await _attemptAutoLogin(); // Wait for token first
    await _init();             // Then initialize webview
  }

  Future<void> _attemptAutoLogin() async {
   
    final info = await AuthTokenService.loadTokenInfo();
    if (info != null && AuthTokenService.isTokenValid(info['token']!)) {
      _savedKey = info['key'];
      _savedToken = info['token'];
   
    } else {
    
      await AuthTokenService.clear();
      _savedKey = null;
      _savedToken = null;
    }
  }

@override
void dispose() {
  _navStateTimer?.cancel();
  _pillIdleTimer?.cancel();
  _pillShowDelayTimer?.cancel();
  _windowsHistorySubscription?.cancel();
  _windowsUrlSubscription?.cancel();
  _pillAnimationController.dispose();
  super.dispose();
}

  bool _isAuthFlowUrl(String url) {
    final u = url.toLowerCase();
    final isAuth = u.contains('/login') ||
        u.contains('login') ||
        u.contains('/signup') ||
        u.contains('sign-up') ||
        u.contains('forgot') ||
        u.contains('reset-password') ||
        u.contains('/auth') ||
        u.contains('/files') ||
        u.contains('accounts.google.com');
    
    
    return isAuth;
  }

  void _handleRouteUpdate(String url) {
    final shouldShow = !_isAuthFlowUrl(url);
    if (!mounted) return;

    _performAuthLogic(url); // Trigger token injection/extraction on every route update

    if (!shouldShow) {
      _pillShowDelayTimer?.cancel();
      if (_showNavPill) {
        _pillAnimationController.reverse();
      }
      return;
    }

    if (_showNavPill && _pillAnimationController.status == AnimationStatus.forward) return;

    // Delay showing the navigation pill when transitioning out of auth pages.
    _pillShowDelayTimer?.cancel();
    _pillShowDelayTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showNavPill = true;
      });
      _pillAnimationController.forward();
      _onPillInteraction();
    });
  }

  Future<void> _performAuthLogic(String url) async {
    if (!mounted) return;

    // 1. Token Injection (Auto-login) - Allow on any page to trigger redirection
    if (!_tokenInjected && _savedKey != null && _savedToken != null) {
      
      final injectJs = "sessionStorage.setItem('$_savedKey', '$_savedToken');";
      try {
        if (Platform.isWindows) {
          await _windowsController.executeScript(injectJs);
          await _windowsController.loadUrl(kStolityFilesUrl);
        } else if (Platform.isMacOS && _macController != null) {
          await _macController!.runJavaScript(injectJs);
          await _macController!.loadRequest(Uri.parse(kStolityFilesUrl));
        }
        _tokenInjected = true;
        
      } catch (e) {
       
      }
      return;
    }

    // 2. Token Extraction (Manual login capture)
    if (!_tokenInjected && !_isAuthFlowUrl(url)) {
     
      const extractJs = '''
        (function() {
          for (var i = 0; i < sessionStorage.length; i++) {
            var key = sessionStorage.key(i);
            var val = sessionStorage.getItem(key);
            if (val && val.startsWith('eyJ')) {
              return JSON.stringify({key:key, token:val});
            }
          }
          return null;
        })();
      ''';
      try {
        String? result;
        if (Platform.isWindows) {
          result = await _windowsController.executeScript(extractJs);
        } else if (Platform.isMacOS && _macController != null) {
          final raw = await _macController!.runJavaScriptReturningResult(extractJs);
          if (raw != null && raw != 'null') {
            result = raw is String ? raw : jsonEncode(raw);
          }
        }

        if (result != null && result != 'null') {
          final map = jsonDecode(result) as Map<String, dynamic>;
          final key = map['key'] as String;
          final token = map['token'] as String;
         
          await AuthTokenService.saveToken(key, token);
          _tokenInjected = true;
        } else {
        
        }
      } catch (e) {
       
      }
    }
  }

  void _onPillInteraction() {
    if (!_showNavPill || !mounted) return;
    _pillIdleTimer?.cancel();
    if (_pillIdleOpacity != 1.0) {
      setState(() {
        _pillIdleOpacity = 1.0;
      });
    }
    _pillIdleTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isPillHovered || !_showNavPill) return;
      setState(() {
        _pillIdleOpacity = 0.7;
      });
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
    bool nextBack = false;
    bool nextForward = false;
    try {
      if (Platform.isWindows) {
        nextBack = _windowsCanGoBack;
        nextForward = _windowsCanGoForward;
      } else if (Platform.isMacOS && _macController != null) {
        nextBack = await _macController!.canGoBack();
        nextForward = await _macController!.canGoForward();
      }
    } catch (_) {
      nextBack = false;
      nextForward = false;
    }

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
      if (Platform.isWindows) {
        await _windowsController.goBack();
      } else if (Platform.isMacOS && _macController != null) {
        await _macController!.goBack();
      }
      await _updateNavigationState();
    } catch (_) {}
  }

  Future<void> _goForward() async {
    _onPillInteraction();
    if (!_canGoForward) return;
    try {
      if (Platform.isWindows) {
        await _windowsController.goForward();
      } else if (Platform.isMacOS && _macController != null) {
        await _macController!.goForward();
      }
      await _updateNavigationState();
    } catch (_) {}
  }

  Future<void> _reloadPage() async {
    _onPillInteraction();
    try {
      if (Platform.isWindows) {
        await _windowsController.reload();
      } else if (Platform.isMacOS && _macController != null) {
        await _macController!.reload();
      }
      await _updateNavigationState();
    } catch (_) {}
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
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

  Future<void> _init() async {
    await initializeWindow();

    if (!mounted) return;
    if (mounted) setState(() => _ready = true);

    if (Platform.isWindows) {
      await _windowsController.initialize();
      _windowsHistorySubscription = _windowsController.historyChanged.listen((history) {
        _windowsCanGoBack = history.canGoBack;
        _windowsCanGoForward = history.canGoForward;
        _updateNavigationState();
      });
      _windowsUrlSubscription = _windowsController.url.listen((url) async {
        _handleRouteUpdate(url);
      });

      // Intercept popup opens and downloads in JS so we can present an in-app popup
      // and handle downloads natively.
      const interceptScript = r"""
        (function(){
          if (window.__stolityPopupPatched) return;
          window.__stolityPopupPatched = true;
          window.open = function(url, target, features){
            try{
              window.chrome.webview.postMessage(JSON.stringify({type:'popup', url: String(url || '')}));
            } catch(ex) {}
            return {
              closed: false,
              postMessage: function() {},
              close: function() { this.closed = true; }
            };
          };

          if (window.__stolityDownloadPatched) return;
          window.__stolityDownloadPatched = true;
          // Disable right-click/context menu globally inside the WebView
          if (!window.__stolityDisableContextMenu) {
            window.__stolityDisableContextMenu = true;
            function _stolityPrevent(e){ try{ e.preventDefault(); e.stopPropagation(); }catch(_){}}
            document.addEventListener('contextmenu', _stolityPrevent, true);
            window.addEventListener('contextmenu', _stolityPrevent, true);
            document.addEventListener('mousedown', function(e){ if (e && e.button === 2) _stolityPrevent(e); }, true);
            // Prevent future listeners for contextmenu from being added
            (function(){
              var _add = EventTarget.prototype.addEventListener;
              EventTarget.prototype.addEventListener = function(type, listener, options){
                if (String(type).toLowerCase() === 'contextmenu') return;
                return _add.call(this, type, listener, options);
              };
              try{ Object.defineProperty(HTMLElement.prototype, 'oncontextmenu', { set: function(){}, get: function(){ return null; }, configurable: true }); }catch(e){}
            })();
          }
          function sendMessage(obj) {
            try { window.chrome.webview.postMessage(JSON.stringify(obj)); } catch(e) {}
          }
          if (!window.__stolityRouteBridgePatched) {
            window.__stolityRouteBridgePatched = true;
            function notifyRoute(){ sendMessage({type:'route-changed', url: String(location.href || '')}); }
            var _ps = history.pushState;
            history.pushState = function(){ var r = _ps.apply(this, arguments); notifyRoute(); return r; };
            var _rs = history.replaceState;
            history.replaceState = function(){ var r = _rs.apply(this, arguments); notifyRoute(); return r; };
            window.addEventListener('popstate', notifyRoute, true);
            window.addEventListener('hashchange', notifyRoute, true);
            window.addEventListener('load', notifyRoute, true);
            setTimeout(notifyRoute, 0);
          }
          function isDownloadAnchor(a) {
            if (!a) return false;
            if (a.hasAttribute && a.hasAttribute('download')) return true;
            var href = a.getAttribute && a.getAttribute('href') || '';
            if (!href) return false;
            if (href.indexOf('blob:') === 0 || href.indexOf('data:') === 0) return true;
            return /\.(zip|exe|pdf|docx?|xlsx?|pptx?|png|jpe?g|gif|csv|tar|gz|rar|7z)$/i.test(href);
          }
          document.addEventListener('click', function(e) {
            var t = e.target;
            while (t && t.tagName !== 'A') t = t.parentElement;
            if (!t) return;
            if (isDownloadAnchor(t)) {
              e.preventDefault();
              var href = t.href || t.getAttribute('href') || '';
              var suggested = t.getAttribute && (t.getAttribute('download') || t.getAttribute('data-filename') || '') || '';
              if (href.indexOf('blob:') === 0) {
                fetch(href).then(function(r){ return r.blob(); }).then(function(blob){
                  var reader = new FileReader();
                  reader.onload = function() {
                    try {
                      var dataUrl = reader.result || '';
                      var comma = dataUrl.indexOf(',');
                      var b64 = dataUrl.substring(comma + 1);
                      sendMessage({type:'download-blob', filename: suggested || '', b64: b64});
                    } catch (err) {
                      sendMessage({type:'download-error', error: String(err), url: href});
                    }
                  };
                  reader.onerror = function(e) { sendMessage({type:'download-error', error: String(e), url: href}); };
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
            }
          }, true);
        })();
      """;

      await _windowsController.addScriptToExecuteOnDocumentCreated(interceptScript);

      _windowsController.webMessage.listen((dynamic message) async {
        try {
          final Map parsed = jsonDecode(message as String) as Map;
          if (parsed['type'] == 'popup' && parsed['url'] != null) {
            final url = parsed['url'] as String;
            if (url.isNotEmpty) {
              await _openWindowsPopup(url);
            }
            return;
          }
          if (parsed['type'] == 'route-changed' && parsed['url'] != null) {
            _handleRouteUpdate(parsed['url'] as String);
            await _updateNavigationState();
            return;
          }
          if (parsed['type'] == 'download-url' && parsed['url'] != null) {
            final url = parsed['url'] as String;
            final filename = (parsed['filename'] as String?) ?? '';
            if (url.isNotEmpty) {
              try {
                final file = await DownloadService.downloadUrl(url, suggestedFilename: filename.isNotEmpty ? filename : null);
                if (mounted) showReusableSnackbar(context, 'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
              } catch (e) {
              }
            }
            return;
          }
          if ((parsed['type'] == 'download-blob' || parsed['type'] == 'download-b64') && parsed['b64'] != null) {
            final b64 = parsed['b64'] as String;
            final filename = (parsed['filename'] as String?) ?? '';
            try {
              await DownloadService.downloadBase64(b64, filename.isNotEmpty ? filename : 'file');
            } catch (e) {
            }
            return;
          }
        } catch (e) {
          // ignore parsing or listener errors
        }
      });

      // Initial Load for Windows: Always load login to establish domain context
    
      await _windowsController.loadUrl(kStolityLoginUrl);
      _startNavigationStateTracking();
    } else if (Platform.isMacOS) {
      final controller = WebViewController(
        onPermissionRequest: (WebViewPermissionRequest request) {
          request.grant();
        },
      );
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.addJavaScriptChannel(
        'flutter_inappwebview_channel',
        onMessageReceived: (JavaScriptMessage message) async {
          try {
            final Map parsed = jsonDecode(message.message) as Map;
            if (parsed['type'] == 'popup' && parsed['url'] != null) {
              final url = parsed['url'] as String;
              if (url.isNotEmpty) {
                await _openMacPopup(url);
              }
            }
            if (parsed['type'] == 'route-changed' && parsed['url'] != null) {
              _handleRouteUpdate(parsed['url'] as String);
              await _updateNavigationState();
            }
          } catch (e) {
            // ignore malformed channel messages
          }
        },
      );
      controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            _handleRouteUpdate(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (String pageUrl) async {
           
            _handleRouteUpdate(pageUrl);
            await _updateNavigationState();
            // Patch window.open for GIS popup mode so Flutter can host popup.
            await controller.runJavaScript(r'''
              (function(){
                if (window.__stolityPopupPatched) return;
                window.__stolityPopupPatched = true;
                window.open = function(url, target, features) {
                  try {
                    flutter_inappwebview_channel.postMessage(JSON.stringify({type: 'popup', url: String(url || '')}));
                  } catch (e) {}
                  return {
                    closed: false,
                    postMessage: function() {},
                    close: function() { this.closed = true; }
                  };
                };
                if (!window.__stolityRouteBridgePatched) {
                  window.__stolityRouteBridgePatched = true;
                  function notifyRoute(){
                    try {
                      flutter_inappwebview_channel.postMessage(JSON.stringify({type: 'route-changed', url: String(location.href || '')}));
                    } catch (e) {}
                  }
                  var _ps = history.pushState;
                  history.pushState = function(){ var r = _ps.apply(this, arguments); notifyRoute(); return r; };
                  var _rs = history.replaceState;
                  history.replaceState = function(){ var r = _rs.apply(this, arguments); notifyRoute(); return r; };
                  window.addEventListener('popstate', notifyRoute, true);
                  window.addEventListener('hashchange', notifyRoute, true);
                  window.addEventListener('load', notifyRoute, true);
                  setTimeout(notifyRoute, 0);
                }
              })();
            ''');

            await controller.runJavaScript(r'''
              (function() {
                if (window.__stolityFilePickerPatched) return;
                window.__stolityFilePickerPatched = true;

                function patchInput(input) {
                  if (input._flutterPatched) return;
                  input._flutterPatched = true;
                  input.addEventListener('click', function(e) {
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    var isFolder = input.hasAttribute('webkitdirectory') || 
                                   input.hasAttribute('directory') ||
                                   input.getAttribute('webkitdirectory') === '' ||
                                   input.getAttribute('webkitdirectory') === 'true';
                    console.log('[JS] Direct click on file input, isFolder:', isFolder, 'webkitdirectory attr:', input.getAttribute('webkitdirectory'));
                    FlutterFilePicker.postMessage(JSON.stringify({
                      accept: input.accept || '',
                      multiple: input.multiple || false,
                      isFolder: isFolder,
                      inputId: input.id || ''
                    }));
                  }, true);
                }

                document.querySelectorAll('input[type="file"]').forEach(patchInput);

                new MutationObserver(function(mutations) {
                  mutations.forEach(function(m) {
                    m.addedNodes.forEach(function(node) {
                      if (node.nodeType !== 1) return;
                      if (node.matches && node.matches('input[type="file"]')) patchInput(node);
                      node.querySelectorAll && node.querySelectorAll('input[type="file"]').forEach(patchInput);
                    });
                  });
                }).observe(document.documentElement, { childList: true, subtree: true });

                // Override the native click() method on file inputs
                // so programmatic clicks (like handleSelectFolder does)
                // are also intercepted
                var originalClick = HTMLInputElement.prototype.click;
                HTMLInputElement.prototype.click = function() {
                  if (this.type === 'file') {
                    var isFolder = this.hasAttribute('webkitdirectory') || 
                                   this.hasAttribute('directory') ||
                                   this.getAttribute('webkitdirectory') === '' ||
                                   this.getAttribute('webkitdirectory') === 'true';
                    console.log('[JS] Programmatic click detected on file input, isFolder:', isFolder, 'webkitdirectory attr:', this.getAttribute('webkitdirectory'));
                    FlutterFilePicker.postMessage(JSON.stringify({
                      accept: this.accept || '',
                      multiple: this.multiple || false,
                      isFolder: isFolder
                    }));
                    return; // prevent native click
                  }
                  return originalClick.apply(this, arguments);
                };
              })();
            ''');

            // Inject download interception for anchors and blob/data URLs
            await controller.runJavaScript(r'''
              (function(){
                if (window.__stolityDownloadPatched) return;
                window.__stolityDownloadPatched = true;
                // Disable right-click/context menu globally inside the WebView
                if (!window.__stolityDisableContextMenu) {
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
                }
                function sendMessage(obj){ try{ FlutterDownload.postMessage(JSON.stringify(obj)); }catch(e){} }
                function isDownloadAnchor(a){ if(!a) return false; if (a.hasAttribute && a.hasAttribute('download')) return true; var href = a.getAttribute && a.getAttribute('href') || ''; if(!href) return false; if (href.indexOf('blob:')===0 || href.indexOf('data:')===0) return true; return /\.(zip|exe|pdf|docx?|xlsx?|pptx?|png|jpe?g|gif|csv|tar|gz|rar|7z)$/i.test(href); }
                document.addEventListener('click', function(e){ var t = e.target; while(t && t.tagName !== 'A') t = t.parentElement; if(!t) return; if(isDownloadAnchor(t)){ e.preventDefault(); var href = t.href || t.getAttribute('href') || ''; var suggested = t.getAttribute && (t.getAttribute('download') || t.getAttribute('data-filename') || '') || ''; if(href.indexOf('blob:')===0){ fetch(href).then(function(r){ return r.blob(); }).then(function(blob){ var reader = new FileReader(); reader.onload = function(){ try{ var dataUrl = reader.result || ''; var comma = dataUrl.indexOf(','); var b64 = dataUrl.substring(comma + 1); sendMessage({type:'download-blob', filename: suggested || '', b64: b64}); }catch(err){ sendMessage({type:'download-error', error: String(err), url: href}); } }; reader.onerror = function(e){ sendMessage({type:'download-error', error: String(e), url: href}); }; reader.readAsDataURL(blob); }).catch(function(err){ sendMessage({type:'download-error', error: String(err), url: href}); }); } else if (href.indexOf('data:')===0){ var comma = href.indexOf(','); var meta = href.substring(5, comma); var isBase64 = /;base64$/.test(meta); var b64 = href.substring(comma+1); if(!isBase64) b64 = btoa(decodeURIComponent(b64)); sendMessage({type:'download-b64', filename: suggested || '', b64: b64}); } else { sendMessage({type:'download-url', url: href, filename: suggested || ''}); } } }, true);
              })();
            ''');
          },
        ),
      );

      controller.addJavaScriptChannel(
        'FlutterDownload',
        onMessageReceived: (JavaScriptMessage message) async {
            try {
            final Map parsed = jsonDecode(message.message) as Map;
            await _handleDownloadMessage(parsed);
          } catch (e) {
          }
        },
      );

      controller.addJavaScriptChannel(
        'FlutterFilePicker',
        onMessageReceived: (JavaScriptMessage message) async {
          await handleFilePick(message.message, controller, null);
        },
      );

      // Initial Load for macOS: Always load login to establish domain context
     
      controller.loadRequest(Uri.parse(kStolityLoginUrl));

      if (mounted) setState(() => _macController = controller);
      _startNavigationStateTracking();
    }
  }

  Future<void> _openMacPopup(String url) async {
    if (_popupOpen || !mounted) return;
    _popupOpen = true;

    final popupController = WebViewController();
    popupController.setJavaScriptMode(JavaScriptMode.unrestricted);
    popupController.addJavaScriptChannel(
      'flutter_inappwebview_channel',
      onMessageReceived: (JavaScriptMessage message) async {
        try {
          final Map parsed = jsonDecode(message.message) as Map;
          if (parsed['type'] == 'popup_to_main_message') {
            final dynamic data = parsed['data'];
            final String origin = (parsed['origin'] as String?) ?? '*';
            final String encodedData = jsonEncode(data);
            final String encodedOrigin = jsonEncode(origin);
            await _macController?.runJavaScript(
              'window.dispatchEvent(new MessageEvent("message", {data: $encodedData, origin: $encodedOrigin}));',
            );
          }
          if (parsed['type'] == 'popup_closed') {
            if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          }
        } catch (e) {
          // ignore malformed popup messages
        }
      },
    );
    popupController.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (String popupUrl) async {
          await popupController.runJavaScript(r'''
            (function() {
              if (window.__stolityPopupBridgePatched) return;
              window.__stolityPopupBridgePatched = true;
              window.opener = {
                closed: false,
                postMessage: function(data, origin) {
                  try {
                    flutter_inappwebview_channel.postMessage(JSON.stringify({type: 'popup_to_main_message', data: data, origin: origin || '*'}));
                  } catch (e) {}
                }
              };
              var originalClose = window.close;
              window.close = function() {
                try {
                  flutter_inappwebview_channel.postMessage(JSON.stringify({type: 'popup_closed'}));
                } catch (e) {}
                if (originalClose) originalClose();
              };
            })();
          ''');

          if (popupUrl.contains('accounts.google.com/gsi/transform')) {
            if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
              Navigator.of(context, rootNavigator: true).pop();
            }
            await _macController?.loadRequest(Uri.parse('https://stolity.com/Files'));
          }
        },
      ),
    );
    popupController.loadRequest(Uri.parse(url));

    if (!mounted) {
      _popupOpen = false;
      return;
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
            child: WebViewWidget(controller: popupController),
          ),
        );
      },
    );

    _popupOpen = false;
  }

  Future<void> _openWindowsPopup(String url) async {
    if (_popupOpen || !mounted) return;
    _popupOpen = true;

    final WebviewController popupController = WebviewController();

    await popupController.initialize();
    await popupController.addScriptToExecuteOnDocumentCreated(r'''
      (function() {
        if (window.__stolityPopupBridgePatched) return;
        window.__stolityPopupBridgePatched = true;
        window.opener = {
          closed: false,
          postMessage: function(data, origin) {
            try {
              window.chrome.webview.postMessage(JSON.stringify({type: 'popup_to_main_message', data: data, origin: origin || '*'}));
            } catch (e) {}
          }
        };
        var originalClose = window.close;
        window.close = function() {
          try {
            window.chrome.webview.postMessage(JSON.stringify({type: 'popup_closed'}));
          } catch (e) {}
          if (originalClose) originalClose();
        };
      })();
    ''');

    popupController.webMessage.listen((dynamic message) async {
      try {
        final Map parsed = jsonDecode(message as String) as Map;
        if (parsed['type'] == 'popup_to_main_message') {
          final dynamic data = parsed['data'];
          final String origin = (parsed['origin'] as String?) ?? '*';
          final String encodedData = jsonEncode(data);
          final String encodedOrigin = jsonEncode(origin);
          await _windowsController.executeScript(
            'window.dispatchEvent(new MessageEvent("message", {data: $encodedData, origin: $encodedOrigin}));',
          );
        }
        if (parsed['type'] == 'popup_closed') {
          if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      } catch (e) {
        // ignore malformed popup messages
      }
    });

    await popupController.loadUrl(url);

    if (!mounted) {
      _popupOpen = false;
      return;
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
            child: Webview(popupController),
          ),
        );
      },
    );

    await _windowsController.loadUrl('https://stolity.com/Dashboard');
    _popupOpen = false;
  }

  Future<void> _handleDownloadMessage(Map parsed) async {
    try {
      final String? type = parsed['type'] as String?;
      if (type == null) return;
      if (type == 'download-url' && parsed['url'] != null) {
        final url = parsed['url'] as String;
        final filename = (parsed['filename'] as String?) ?? '';
        if (url.isNotEmpty) {
          try {
            final file = await DownloadService.downloadUrl(url, suggestedFilename: filename.isNotEmpty ? filename : null);
            if (mounted) showReusableSnackbar(context, 'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
          } catch (e) {
            // ignore download errors
          }
        }
      } else if ((type == 'download-blob' || type == 'download-b64') && parsed['b64'] != null) {
        final b64 = parsed['b64'] as String;
        final filename = (parsed['filename'] as String?) ?? '';
        try {
          final file = await DownloadService.downloadBase64(b64, filename.isNotEmpty ? filename : 'file');
          if (mounted) showReusableSnackbar(context, 'Downloaded: ${file.path.split(Platform.pathSeparator).last}');
        } catch (e) {
          // ignore download errors
        }
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: kBackgroundColor);
    if (Platform.isWindows) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Stack(
          children: [
            ColoredBox(color: kBackgroundColor, child: Webview(_windowsController)),
            _buildNavigationPill(),
          ],
        ),
      );
    }
    if (Platform.isMacOS && _macController != null) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Stack(
          children: [
            ColoredBox(color: kBackgroundColor, child: WebViewWidget(controller: _macController!)),
            _buildNavigationPill(),
          ],
        ),
      );
    }
    return const ColoredBox(color: kBackgroundColor);
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
    final iconColor = widget.enabled ? const Color(0xE6000000) : const Color(0x66000000);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          onEnter: (_) {
            setState(() {
              _hovered = true;
            });
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
                    setState(() {
                      _pressed = true;
                    });
                    widget.onInteract();
                  }
                : null,
            onTapCancel: () {
              if (_pressed) {
                setState(() {
                  _pressed = false;
                });
              }
            },
            onTap: widget.enabled
                ? () async {
                    widget.onInteract();
                    await widget.onTap();
                    if (mounted) {
                      setState(() {
                        _pressed = false;
                      });
                    }
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
