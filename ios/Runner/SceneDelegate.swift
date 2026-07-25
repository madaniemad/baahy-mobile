import Flutter
import UIKit

// Minimal scene delegate.
//
// We intentionally do NOT cover the UI with the LaunchScreen before the system
// snapshot. A previous version added a "cover for snapshot" overlay so cold
// launches looked seamless, but the side effect was that the App Switcher showed
// a solid tiffany card instead of the live app content — unlike every other app.
// With the overlay gone, iOS snapshots the real screen, so baahy's switcher
// preview shows the current page (Home, product, etc.) just like normal apps.
class SceneDelegate: FlutterSceneDelegate {
}
