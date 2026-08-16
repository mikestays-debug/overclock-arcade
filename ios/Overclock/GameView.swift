import SwiftUI
import WebKit
import UIKit

/// Hosts the bundled game and gives it native powers a web page can't have:
/// haptics, no screen-sleep, and the iOS share sheet.
struct GameView: UIViewRepresentable {

    @Binding var isLoading: Bool
    @Binding var gameState: String
    /// Handed back so the parent can call togglePause() on the live web view.
    let onReady: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        // The game talks to Swift through these two channels.
        controller.add(context.coordinator, name: "haptic")
        controller.add(context.coordinator, name: "share")
        controller.add(context.coordinator, name: "state")
        controller.addUserScript(WKUserScript(source: Self.bridgeJS,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))
        // Re-apply the layout CSS after the page's own stylesheet has loaded,
        // otherwise the game's styles win and content slides under the notch.
        controller.addUserScript(WKUserScript(source: Self.bridgeJS,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: false))

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = controller
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.suppressesIncrementalRendering = true      // no half-drawn first frame

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = Self.ink
        web.scrollView.backgroundColor = Self.ink
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false
        web.scrollView.maximumZoomScale = 1            // no accidental pinch-zoom mid-game
        web.scrollView.minimumZoomScale = 1

        // The phone must not dim or sleep while a game is on screen.
        UIApplication.shared.isIdleTimerDisabled = true

        if let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            web.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        } else if let live = URL(string: "https://overclock-arcade.vercel.app") {
            web.load(URLRequest(url: live))
        }
        onReady(web)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static let ink = UIColor(red: 0.043, green: 0.059, blue: 0.118, alpha: 1)  // #0b0f1e

    // MARK: - Bridge
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: GameView
        // Prepared generators fire with far less latency than ones created on demand.
        private let light  = UIImpactFeedbackGenerator(style: .light)
        private let medium = UIImpactFeedbackGenerator(style: .medium)
        private let heavy  = UIImpactFeedbackGenerator(style: .heavy)
        private let notify = UINotificationFeedbackGenerator()

        init(_ parent: GameView) {
            self.parent = parent
            super.init()
            [light, medium, heavy].forEach { $0.prepare() }
            notify.prepare()
        }

        func userContentController(_ ucc: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "haptic":
                switch message.body as? String ?? "light" {
                case "medium":  medium.impactOccurred()
                case "heavy":   heavy.impactOccurred()
                case "success": notify.notificationOccurred(.success)
                case "warning": notify.notificationOccurred(.warning)
                case "error":   notify.notificationOccurred(.error)
                default:        light.impactOccurred()
                }
            case "state":
                let s = message.body as? String ?? ""
                if s != parent.gameState { parent.gameState = s }
            case "share":
                let text = message.body as? String ?? "I'm playing Overclock"
                presentShare(text)
            default: break
            }
        }

        private func presentShare(_ text: String) {
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first,
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            else { return }
            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            av.popoverPresentationController?.sourceView = root.view          // iPad needs an anchor
            av.popoverPresentationController?.sourceRect =
                CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            root.present(av, animated: true)
        }

        /// A web server turns `apex_run/` into `apex_run/index.html` automatically.
        /// `file://` URLs have no such directory-index behaviour, so a link to a
        /// folder simply lands on nothing and the game never opens. Catch those and
        /// append index.html ourselves — this way the game's own HTML never has to
        /// change, and it keeps working after every future update.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, url.isFileURL else {
                decisionHandler(.allow); return
            }
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if exists && isDir.boolValue {
                let index = url.appendingPathComponent("index.html")
                if FileManager.default.fileExists(atPath: index.path) {
                    decisionHandler(.cancel)
                    webView.loadFileURL(index, allowingReadAccessTo: Self.webRoot ?? index)
                    return
                }
            }
            decisionHandler(.allow)
        }

        /// Read access must cover the whole bundled site, not just one file,
        /// or sub-pages can't load their siblings.
        static let webRoot: URL? = Bundle.main.url(forResource: "index",
                                                   withExtension: "html",
                                                   subdirectory: "web")?
                                              .deletingLastPathComponent()

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Small delay so the game paints its first frame before the cover lifts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.35)) { self.parent.isLoading = false }
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError e: Error) {
            withAnimation { parent.isLoading = false }
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) {
            withAnimation { parent.isLoading = false }
        }
    }

    /// Injected before the game's own code runs, so it can use these immediately.
    ///
    /// FOR WHOEVER IS WRITING THE GAME — call these from JavaScript:
    ///     Overclock.haptic('light')     tap / tick
    ///     Overclock.haptic('medium')    landed a jump
    ///     Overclock.haptic('heavy')     crash / big hit
    ///     Overclock.haptic('success')   new high score
    ///     Overclock.haptic('error')     game over
    ///     Overclock.share('Scored 4,200 on Apex Run!')
    ///     Overclock.isApp               true only inside the iOS app
    ///
    /// They're safe to call on the web too — there they just do nothing.
    static let bridgeJS = """
    (function () {
      var send = function (name, body) {
        try { window.webkit.messageHandlers[name].postMessage(body); } catch (e) {}
      };
      window.Overclock = {
        isApp: true,
        haptic: function (style) { send('haptic', style || 'light'); },
        share:  function (text)  { send('share', text || 'Overclock'); }
      };
      // Report the game's own gameState up to Swift whenever it changes, so the
      // pause button can appear only while a race is actually running. Polling is
      // used rather than patching the game — nothing in the game has to know.
      (function watchState () {
        // This script is injected twice (document start AND end) so its CSS wins
        // over the page's own. Only ever run one poller.
        if (window.__ocStateWatch) { return; }
        window.__ocStateWatch = true;

        var last = null;
        setInterval(function () {
          var s = null;
          // The game declares `let gameState = "menu"` at top level. `let` creates a
          // LEXICAL binding, not a property on window — so `window.gameState` is
          // undefined and only the bare identifier resolves. Reading it via eval
          // keeps the lookup in the page's scope chain.
          try { s = eval('typeof gameState !== "undefined" ? gameState : null'); } catch (e) { s = null; }
          if (typeof s === 'string' && s !== last) {
            last = s;
            try { window.webkit.messageHandlers.state.postMessage(s); } catch (e) {}
          }
        }, 200);
      })();

      // ---- Pause control, injected into the game's OWN touch row ----------
      // The game binds togglePause() to P and Escape, which a phone can't reach.
      // Rather than floating a native button over the canvas, add a real .tbtn to
      // the game's #touch container: it inherits the existing styling, sits in the
      // control row, and follows the same body.touch show/hide rule as the others.
      // Layout: t-left / t-right sit bottom-LEFT, t-brake / t-gas bottom-RIGHT,
      // so the gap between them is dead centre.
      (function addPause () {
        if (window.__ocPause) { return; }
        var tries = 0;
        var timer = setInterval(function () {
          var row = document.getElementById('touch');
          if (!row) { if (++tries > 60) { clearInterval(timer); } return; }
          if (document.getElementById('t-pause')) { clearInterval(timer); return; }
          window.__ocPause = true;
          clearInterval(timer);

          var b = document.createElement('div');
          b.className = 'tbtn';
          b.id = 't-pause';
          b.textContent = '❚❚';
          b.setAttribute('aria-label', 'Pause');
          // Smaller than the driving controls so it is never hit by accident,
          // and centred between them.
          b.style.cssText =
            'left:50%;transform:translateX(-50%);' +
            'width:48px;height:48px;font-size:15px;letter-spacing:1px;' +
            'background:rgba(255,255,255,0.07);border-color:rgba(255,255,255,0.22);';
          row.appendChild(b);

          var fire = function (e) {
            e.preventDefault();
            e.stopPropagation();
            // Reuse the game's own keyboard path — no need to reach togglePause(),
            // which is a lexical binding and not on window.
            ['keydown', 'keyup'].forEach(function (t) {
              document.dispatchEvent(new KeyboardEvent(t, {
                key: 'p', code: 'KeyP', keyCode: 80, which: 80, bubbles: true
              }));
            });
            try { window.Overclock.haptic('light'); } catch (err) {}
          };
          b.addEventListener('touchstart', fire, { passive: false });
          b.addEventListener('click', fire);
        }, 200);
      })();

      var css = document.createElement('style');
      css.textContent =
        // No text-selection magnifier or long-press callout menu.
        '*{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none;}' +
        'html,body{overscroll-behavior:none;touch-action:manipulation;background:#0b0f1e;}' +
        // Keep page content clear of the Dynamic Island / notch and the home indicator.
        // A full-screen game canvas uses position:fixed, which ignores this padding,
        // so the game still runs edge to edge — only the menus get inset.
        'body{padding-top:env(safe-area-inset-top) !important;' +
              'padding-left:env(safe-area-inset-left) !important;' +
              'padding-right:env(safe-area-inset-right) !important;' +
              'padding-bottom:env(safe-area-inset-bottom) !important;' +
              'box-sizing:border-box !important;}' +
        // Comfortable side margins and a readable line length. Long lines running
        // edge to edge are hard to read on a phone; content is centred instead.
        '@media (max-width:900px){body>*{padding-left:18px !important;' +
              'padding-right:18px !important;}' +
              'body{max-width:640px !important;margin:0 auto !important;}}';
      document.documentElement.appendChild(css);
      // NOTE: no touchend/preventDefault handler here on purpose.
      // Double-tap-to-zoom is already disabled by `touch-action: manipulation`
      // below. Doing it in JS as well swallows real taps and makes buttons and
      // links stop responding — that bug cost us a round trip on 2026-08-16.
    })();
    """
}
