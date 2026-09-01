import Foundation

#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import AppKit
  import CoreImage
  import FlutterMacOS
#endif

public final class ThemePregoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeActivityIndicatorPlatformViewFactory(),
      withId: NativeActivityIndicatorPlatformViewFactory.viewType
    )
    registrar.register(
      NativeAiLoaderPlatformViewFactory(),
      withId: NativeAiLoaderPlatformViewFactory.viewType
    )
  }
}

private struct ColorComponents {
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
  let alpha: CGFloat

  init(fromARGB value: Int64) {
    let argb = UInt32(truncatingIfNeeded: value)
    red = CGFloat((argb >> 16) & 0xff) / 255
    green = CGFloat((argb >> 8) & 0xff) / 255
    blue = CGFloat(argb & 0xff) / 255
    alpha = CGFloat((argb >> 24) & 0xff) / 255
  }

  var cgColor: CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
  }
}

/// What the Dart spinner sends when it creates a native indicator: an optional
/// ARGB tint and whether the app's resolved theme is dark.
private struct ActivityIndicatorCreationParams {
  let color: Int64?
  let dark: Bool

  init?(from args: Any?) {
    guard let dictionary = args as? [String: Any] else { return nil }
    if let color = dictionary["color"] {
      guard let number = color as? NSNumber else { return nil }
      self.color = number.int64Value
    } else {
      self.color = nil
    }
    self.dark = dictionary["dark"] as? Bool ?? false
  }
}

/// The three keyframe colours and phase offset the Dart sparkle sends when
/// it creates a native twinkle view.
private struct AiLoaderCreationParams {
  let solid: CGColor
  let outline: CGColor
  let faded: CGColor
  let phase: Double

  init?(from args: Any?) {
    guard
      let dictionary = args as? [String: Any],
      let solid = dictionary["solid"] as? NSNumber,
      let outline = dictionary["outline"] as? NSNumber,
      let faded = dictionary["faded"] as? NSNumber,
      let phase = dictionary["phase"] as? NSNumber
    else { return nil }
    self.solid = ColorComponents(fromARGB: solid.int64Value).cgColor
    self.outline = ColorComponents(fromARGB: outline.int64Value).cgColor
    self.faded = ColorComponents(fromARGB: faded.int64Value).cgColor
    self.phase = phase.doubleValue
  }
}

/// The AI sparkle's geometry and twinkle, mirroring `PregoAiLoader`'s
/// painter.
///
/// The keyframes — solid brand, hollow outline at 0.4, faded solid at 0.7,
/// back to solid — and the 1.4s period must stay in step with the Dart
/// fallback painter. The path is the painter's Tabler `sparkle-2` outline
/// with its arcs pre-converted to cubic Béziers (CGPath has no SVG-style
/// endpoint-parameterised arc).
private enum AiLoaderSparkle {
  static let viewBox: CGFloat = 24
  static let period: CFTimeInterval = 1.4

  static func makeShapeLayer(params: AiLoaderCreationParams) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: viewBox, height: viewBox)
    layer.path = path()
    layer.lineWidth = 2
    layer.lineJoin = .round
    layer.lineCap = .round
    // The base (non-animated) values are the resting solid keyframe: the
    // same frame the Dart painter shows when the loop is off. The running
    // twinkle overrides them in the presentation layer only.
    layer.fillColor = params.solid
    layer.strokeColor = params.solid
    return layer
  }

  /// The infinitely repeating twinkle, animated entirely by the render
  /// server: once added, the app process schedules no frames for it.
  static func twinkle(params: AiLoaderCreationParams) -> CAAnimationGroup {
    let keyTimes: [NSNumber] = [0, 0.4, 0.7, 1]

    let fill = CAKeyframeAnimation(keyPath: "fillColor")
    // The fill hollows out towards the outline keyframe and refills towards
    // the faded one; encoding the opacity into the colour's alpha lets one
    // linear colour interpolation carry both.
    fill.values = [
      params.solid,
      params.outline.copy(alpha: 0) ?? params.outline,
      params.faded,
      params.solid,
    ]
    fill.keyTimes = keyTimes

    let stroke = CAKeyframeAnimation(keyPath: "strokeColor")
    stroke.values = [params.solid, params.outline, params.faded, params.solid]
    stroke.keyTimes = keyTimes

    let scale = CAKeyframeAnimation(keyPath: "transform.scale")
    scale.values = [1, 0.86, 0.92, 1]
    scale.keyTimes = keyTimes

    let group = CAAnimationGroup()
    group.animations = [fill, stroke, scale]
    // A group's duration does NOT propagate to its children; an unset child
    // duration falls back to the 0.25s CATransaction default, which would end
    // each keyframe pass almost immediately and leave the sparkle solid for
    // the rest of every repeat.
    for animation in group.animations ?? [] {
      animation.duration = period
    }
    group.duration = period
    group.repeatCount = .infinity
    // Staggers list rows apart, matching the Dart painter's phase offset.
    group.timeOffset = params.phase * period
    return group
  }

  private static func path() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 12, y: 3))
    path.addCurve(
      to: CGPoint(x: 12.846, y: 3.581),
      control1: CGPoint(x: 12.375, y: 3), control2: CGPoint(x: 12.711, y: 3.231))
    path.addLine(to: CGPoint(x: 14.496, y: 7.871))
    path.addCurve(
      to: CGPoint(x: 16.128, y: 9.504),
      control1: CGPoint(x: 14.785, y: 8.621), control2: CGPoint(x: 15.378, y: 9.214))
    path.addLine(to: CGPoint(x: 20.419, y: 11.154))
    path.addCurve(
      to: CGPoint(x: 21.001, y: 12),
      control1: CGPoint(x: 20.769, y: 11.288), control2: CGPoint(x: 21.001, y: 11.625))
    path.addCurve(
      to: CGPoint(x: 20.419, y: 12.846),
      control1: CGPoint(x: 21.001, y: 12.375), control2: CGPoint(x: 20.769, y: 12.712))
    path.addLine(to: CGPoint(x: 16.129, y: 14.496))
    path.addCurve(
      to: CGPoint(x: 14.496, y: 16.128),
      control1: CGPoint(x: 15.378, y: 14.784), control2: CGPoint(x: 14.785, y: 15.377))
    path.addLine(to: CGPoint(x: 12.846, y: 20.419))
    path.addCurve(
      to: CGPoint(x: 12, y: 21.001),
      control1: CGPoint(x: 12.712, y: 20.769), control2: CGPoint(x: 12.375, y: 21.001))
    path.addCurve(
      to: CGPoint(x: 11.154, y: 20.419),
      control1: CGPoint(x: 11.625, y: 21.001), control2: CGPoint(x: 11.288, y: 20.769))
    path.addLine(to: CGPoint(x: 9.504, y: 16.129))
    path.addCurve(
      to: CGPoint(x: 7.872, y: 14.496),
      control1: CGPoint(x: 9.216, y: 15.378), control2: CGPoint(x: 8.623, y: 14.785))
    path.addLine(to: CGPoint(x: 3.581, y: 12.846))
    path.addCurve(
      to: CGPoint(x: 2.999, y: 12),
      control1: CGPoint(x: 3.231, y: 12.712), control2: CGPoint(x: 2.999, y: 12.375))
    path.addCurve(
      to: CGPoint(x: 3.581, y: 11.154),
      control1: CGPoint(x: 2.999, y: 11.625), control2: CGPoint(x: 3.231, y: 11.288))
    path.addLine(to: CGPoint(x: 7.871, y: 9.504))
    path.addCurve(
      to: CGPoint(x: 9.504, y: 7.872),
      control1: CGPoint(x: 8.622, y: 9.216), control2: CGPoint(x: 9.215, y: 8.623))
    path.addLine(to: CGPoint(x: 11.154, y: 3.581))
    path.addCurve(
      to: CGPoint(x: 12, y: 3),
      control1: CGPoint(x: 11.289, y: 3.232), control2: CGPoint(x: 11.625, y: 3.001))
    path.closeSubpath()
    return path
  }
}

#if os(iOS)

  private final class NativeActivityIndicatorPlatformViewFactory: NSObject,
    FlutterPlatformViewFactory
  {
    static let viewType = "sesori/native-activity-indicator"

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      guard let params = ActivityIndicatorCreationParams(from: args) else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      return NativeActivityIndicatorPlatformView(frame: frame, params: params)
    }
  }

  private final class NativeActivityIndicatorPlatformView: UIView, FlutterPlatformView {
    private let indicator = UIActivityIndicatorView(style: .medium)

    init(frame: CGRect, params: ActivityIndicatorCreationParams) {
      super.init(frame: frame)

      isAccessibilityElement = false
      accessibilityElementsHidden = true
      // Follow the app's resolved appearance rather than the host's: a forced
      // in-app dark mode must not leave dark ticks on dark Flutter surfaces.
      indicator.overrideUserInterfaceStyle = params.dark ? .dark : .light
      // A nil colour keeps the system spinner colour; a tint is still honoured
      // when a caller asks for one.
      if let color = params.color {
        let c = ColorComponents(fromARGB: color)
        indicator.color = UIColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
      }
      indicator.hidesWhenStopped = false
      indicator.translatesAutoresizingMaskIntoConstraints = false
      addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(reduceMotionStatusDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NotificationCenter.default.removeObserver(
        self,
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
    }

    func view() -> UIView {
      self
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let diameter = indicator.intrinsicContentSize.width
      let minDimension = min(bounds.width, bounds.height)
      guard diameter > 0, minDimension > 0 else { return }
      let scale = minDimension / diameter
      indicator.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      updateAnimationState()
    }

    @objc private func reduceMotionStatusDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !UIAccessibility.isReduceMotionEnabled {
        indicator.startAnimating()
      } else {
        indicator.stopAnimating()
      }
    }
  }


  private final class NativeAiLoaderPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "sesori/native-ai-loader"

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      guard let params = AiLoaderCreationParams(from: args) else {
        preconditionFailure("Invalid native AI loader creation arguments")
      }
      return NativeAiLoaderPlatformView(frame: frame, params: params)
    }
  }

  private final class NativeAiLoaderPlatformView: UIView, FlutterPlatformView {
    private let params: AiLoaderCreationParams
    private let fitLayer = CALayer()
    private let sparkleLayer: CAShapeLayer

    init(frame: CGRect, params: AiLoaderCreationParams) {
      self.params = params
      sparkleLayer = AiLoaderSparkle.makeShapeLayer(params: params)
      super.init(frame: frame)

      // The Flutter widget owns any meaning; hide the decoration from
      // VoiceOver like the activity indicator above.
      isAccessibilityElement = false
      accessibilityElementsHidden = true
      fitLayer.bounds = CGRect(
        x: 0, y: 0, width: AiLoaderSparkle.viewBox, height: AiLoaderSparkle.viewBox)
      sparkleLayer.position = CGPoint(
        x: AiLoaderSparkle.viewBox / 2, y: AiLoaderSparkle.viewBox / 2)
      fitLayer.addSublayer(sparkleLayer)
      layer.addSublayer(fitLayer)

      let notificationCenter = NotificationCenter.default
      notificationCenter.addObserver(
        self,
        selector: #selector(twinkleConditionsDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
      // UIKit strips CAAnimations when the app backgrounds; the repeating
      // twinkle has to be re-added on return.
      notificationCenter.addObserver(
        self,
        selector: #selector(twinkleConditionsDidChange),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    func view() -> UIView {
      self
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let minDimension = min(bounds.width, bounds.height)
      guard minDimension > 0 else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      fitLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
      let scale = minDimension / AiLoaderSparkle.viewBox
      fitLayer.transform = CATransform3DMakeScale(scale, scale, 1)
      CATransaction.commit()
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      // A CAShapeLayer rasterizes at its contentsScale; without the screen's
      // scale a retina sparkle renders blurry.
      sparkleLayer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
      updateAnimationState()
    }

    @objc private func twinkleConditionsDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !UIAccessibility.isReduceMotionEnabled {
        if sparkleLayer.animation(forKey: "twinkle") == nil {
          sparkleLayer.add(AiLoaderSparkle.twinkle(params: params), forKey: "twinkle")
        }
      } else {
        // The base layer values are the resting solid keyframe, so removing
        // the animation is itself the static reduced-motion frame.
        sparkleLayer.removeAnimation(forKey: "twinkle")
      }
    }
  }

#elseif os(macOS)

  private final class NativeActivityIndicatorPlatformViewFactory: NSObject,
    FlutterPlatformViewFactory
  {
    static let viewType = "sesori/native-activity-indicator"

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      guard let params = ActivityIndicatorCreationParams(from: args) else {
        preconditionFailure("Invalid native activity indicator creation arguments")
      }
      return NativeActivityIndicatorView(params: params)
    }
  }

  private final class NativeActivityIndicatorView: NSView {
    private let indicator = NSProgressIndicator()

    init(params: ActivityIndicatorCreationParams) {
      super.init(frame: .zero)
      // Follow the app's resolved appearance rather than the host's: a forced
      // in-app dark mode must not leave dark ticks on dark Flutter surfaces.
      indicator.appearance = NSAppearance(named: params.dark ? .darkAqua : .aqua)
      // A nil colour keeps the system spinner colour; a tint is still honoured
      // when a caller asks for one.
      var color: NSColor?
      if let argb = params.color {
        let c = ColorComponents(fromARGB: argb)
        color = NSColor(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
      }

      // The Flutter wrapper owns the loading-spinner semantics; hide both the
      // container and the native indicator from VoiceOver.
      setAccessibilityElement(false)
      indicator.setAccessibilityElement(false)
      indicator.style = .spinning
      indicator.isIndeterminate = true
      indicator.isDisplayedWhenStopped = true
      indicator.translatesAutoresizingMaskIntoConstraints = false
      if let color, let filter = CIFilter(name: "CIColorMonochrome"), let ciColor = CIColor(color: color) {
        // Content filters only apply to a layer-backed view.
        indicator.wantsLayer = true
        // The spinner draws its ticks in the label colour at varying alpha:
        // black under the light appearance, white under dark. A monochrome
        // filter maps luminance onto the requested colour, so black ticks
        // would stay black; pin the dark appearance so the ticks are white,
        // which the filter maps exactly onto the colour while keeping each
        // tick's alpha. NSProgressIndicator has no tint API of its own.
        indicator.appearance = NSAppearance(named: .darkAqua)
        filter.setValue(ciColor, forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        indicator.contentFilters = [filter]
      }
      addSubview(indicator)
      NSLayoutConstraint.activate([
        indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
        indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
      ])

      NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(accessibilityDisplayOptionsDidChange),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NSWorkspace.shared.notificationCenter.removeObserver(
        self,
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
    }

    override func layout() {
      super.layout()
      let minDimension = min(bounds.width, bounds.height)
      guard minDimension > 0 else { return }
      // A spinning NSProgressIndicator draws at its control size rather than
      // its frame; pick the largest size that fits so small consumers (16px
      // inline rows and buttons) neither clip nor overflow.
      let fitting: NSControl.ControlSize =
        minDimension >= 32 ? .regular : minDimension >= 16 ? .small : .mini
      if indicator.controlSize != fitting {
        indicator.controlSize = fitting
      }
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateAnimationState()
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        indicator.startAnimation(nil)
      } else {
        indicator.stopAnimation(nil)
      }
    }
  }

  private final class NativeAiLoaderPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    static let viewType = "sesori/native-ai-loader"

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      guard let params = AiLoaderCreationParams(from: args) else {
        preconditionFailure("Invalid native AI loader creation arguments")
      }
      return NativeAiLoaderView(params: params)
    }
  }

  private final class NativeAiLoaderView: NSView {
    private let params: AiLoaderCreationParams
    private let fitLayer = CALayer()
    private let sparkleLayer: CAShapeLayer

    init(params: AiLoaderCreationParams) {
      self.params = params
      sparkleLayer = AiLoaderSparkle.makeShapeLayer(params: params)
      super.init(frame: .zero)

      // The Flutter widget owns any meaning; hide the decoration from
      // VoiceOver like the activity indicator above.
      setAccessibilityElement(false)
      wantsLayer = true
      fitLayer.bounds = CGRect(
        x: 0, y: 0, width: AiLoaderSparkle.viewBox, height: AiLoaderSparkle.viewBox)
      sparkleLayer.position = CGPoint(
        x: AiLoaderSparkle.viewBox / 2, y: AiLoaderSparkle.viewBox / 2)
      fitLayer.addSublayer(sparkleLayer)
      layer?.addSublayer(fitLayer)

      NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(accessibilityDisplayOptionsDidChange),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
      updateAnimationState()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      NSWorkspace.shared.notificationCenter.removeObserver(
        self,
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
    }

    override func layout() {
      super.layout()
      let minDimension = min(bounds.width, bounds.height)
      guard minDimension > 0 else { return }
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      fitLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
      let scale = minDimension / AiLoaderSparkle.viewBox
      fitLayer.transform = CATransform3DMakeScale(scale, scale, 1)
      CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      // A CAShapeLayer rasterizes at its contentsScale; without the screen's
      // backing scale a retina sparkle renders blurry.
      sparkleLayer.contentsScale = window?.backingScaleFactor ?? 2
      updateAnimationState()
    }

    @objc private func accessibilityDisplayOptionsDidChange() {
      updateAnimationState()
    }

    private func updateAnimationState() {
      if window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        if sparkleLayer.animation(forKey: "twinkle") == nil {
          sparkleLayer.add(AiLoaderSparkle.twinkle(params: params), forKey: "twinkle")
        }
      } else {
        // The base layer values are the resting solid keyframe, so removing
        // the animation is itself the static reduced-motion frame.
        sparkleLayer.removeAnimation(forKey: "twinkle")
      }
    }
  }

#endif
