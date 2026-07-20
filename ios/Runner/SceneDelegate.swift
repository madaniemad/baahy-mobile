import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Overlay that hides live content while the system snapshots the scene.
  private var launchOverlay: UIView?

  override init() {
    super.init()
    // Cover the UI with the LaunchScreen just before iOS snapshots the scene, and reveal it
    // once active again. Without this, iOS caches the last frame (e.g. Home) and shows it for
    // a split second on the next cold launch before Flutter renders the splash. Covering makes
    // the cached snapshot the brand LaunchScreen, so launches look seamless.
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(coverForSnapshot),
                   name: UIScene.willDeactivateNotification, object: nil)
    nc.addObserver(self, selector: #selector(revealAfterSnapshot),
                   name: UIScene.didActivateNotification, object: nil)
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func coverForSnapshot() {
    guard launchOverlay == nil, let window = self.window else { return }
    let overlay: UIView
    if let vc = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController(),
       let view = vc.view {
      overlay = view
    } else {
      let fallback = UIView()
      fallback.backgroundColor = .white
      overlay = fallback
    }
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(overlay)
    window.bringSubviewToFront(overlay)
    launchOverlay = overlay
  }

  @objc private func revealAfterSnapshot() {
    launchOverlay?.removeFromSuperview()
    launchOverlay = nil
  }
}
