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
      NativeAiLoaderPlatformViewFactory(
        messenger: {
          #if os(iOS)
            registrar.messenger()
          #else
            registrar.messenger
          #endif
        }()
      ),
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
    // The codec decodes Dart's null as NSNull; both spellings mean untinted.
    switch dictionary["color"] {
    case nil, is NSNull:
      self.color = nil
    case let number as NSNumber:
      self.color = number.int64Value
    default:
      return nil
    }
    self.dark = (dictionary["dark"] as? NSNumber)?.boolValue ?? false
  }
}

/// Theme colours and initial state supplied by the Flutter decoration.
private struct AiLoaderCreationParams {
  let solid: CGColor
  let outline: CGColor
  let loading: Bool

  init?(from args: Any?) {
    guard
      let dictionary = args as? [String: Any],
      let solid = dictionary["solid"] as? NSNumber,
      let outline = dictionary["outline"] as? NSNumber,
      let loading = dictionary["loading"] as? Bool
    else { return nil }
    self.solid = ColorComponents(fromARGB: solid.int64Value).cgColor
    self.outline = ColorComponents(fromARGB: outline.int64Value).cgColor
    self.loading = loading
  }
}

/// Mirrors the Flutter painter: a 14px Tabler sparkle inside Figma's 20px
/// frame. Core Animation owns every animation frame on Apple platforms.
private enum AiLoaderSparkle {
  static let viewBox: CGFloat = 20
  static let period: CFTimeInterval = 2
  static let completionDuration: CFTimeInterval = 0.7
  static let resumeDuration: CFTimeInterval = 0.15
  static let clear = ColorComponents(fromARGB: 0x00b2d1ff).cgColor
  static let completionHighlight = ColorComponents(fromARGB: 0xffb2d1ff).cgColor
  static let colourTiming = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.5, 1)

  static func makeShapeLayer(params: AiLoaderCreationParams) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.bounds = CGRect(x: 0, y: 0, width: viewBox, height: viewBox)
    layer.path = path()
    layer.lineWidth = 7.0 / 6.0
    layer.lineJoin = .round
    layer.lineCap = .round
    layer.fillColor = params.loading ? clear : params.solid
    layer.strokeColor = params.loading ? params.outline : params.solid
    return layer
  }

  /// Capture displayed geometry and colours before replacing animations, so
  /// finishing and rapid restart never jump to a different visual frame.
  static func animate(
    layer: CAShapeLayer,
    params: AiLoaderCreationParams,
    loading: Bool,
    loadingTransitionCompleted: (() -> Void)? = nil
  ) {
    let displayed = layer.presentation() ?? layer
    let angle = (displayed.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.doubleValue ?? 0
    let fill = displayed.fillColor ?? clear
    let stroke = displayed.strokeColor ?? params.outline
    let quarterTurn = Double.pi / 2
    let synchronizedTarget = synchronizedAngle(at: Date(timeIntervalSinceNow: resumeDuration))
    let target = loading
      ? synchronizedTarget + round((angle - synchronizedTarget) / (.pi * 2)) * .pi * 2
      : ceil((angle + 0.593) / quarterTurn) * quarterTurn

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    if loading {
      CATransaction.setCompletionBlock(loadingTransitionCompleted)
    }
    layer.removeAllAnimations()
    layer.setValue(target, forKeyPath: "transform.rotation.z")
    layer.fillColor = loading ? clear : params.solid
    layer.strokeColor = loading ? params.outline : params.solid

    let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
    rotation.fromValue = angle
    rotation.toValue = target
    rotation.duration = loading ? resumeDuration : completionDuration
    rotation.timingFunction = loading
      ? CAMediaTimingFunction(name: .linear)
      : CAMediaTimingFunction(controlPoints: 0.45, 1.45, 0.833, 1.368)
    layer.add(rotation, forKey: loading ? "loading" : "completion")

    let fillAnimation = CAKeyframeAnimation(keyPath: "fillColor")
    fillAnimation.values = loading ? [fill, clear] : [fill, completionHighlight, params.solid]
    fillAnimation.keyTimes = loading ? [0, 1] : [0, 0.5, 1]
    fillAnimation.timingFunctions = loading ? [colourTiming] : [colourTiming, colourTiming]
    fillAnimation.duration = loading ? resumeDuration : completionDuration
    layer.add(fillAnimation, forKey: "fill")

    let strokeAnimation = CABasicAnimation(keyPath: "strokeColor")
    strokeAnimation.fromValue = stroke
    strokeAnimation.toValue = loading ? params.outline : params.solid
    strokeAnimation.duration = loading ? resumeDuration : completionDuration
    strokeAnimation.timingFunction = colourTiming
    layer.add(strokeAnimation, forKey: "stroke")
    CATransaction.commit()
  }

  /// Start an unthrottled Core Animation loop at current Unix-clock phase.
  /// Sampling here, rather than from Flutter creation arguments, also aligns
  /// views mounted later and views resuming after suspension.
  static func startSynchronizedLoading(layer: CAShapeLayer, params: AiLoaderCreationParams) {
    let localNow = layer.convertTime(CACurrentMediaTime(), from: nil)
    let epochOffset = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.setValue(synchronizedAngle(at: Date()), forKeyPath: "transform.rotation.z")
    layer.fillColor = clear
    layer.strokeColor = params.outline

    let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
    rotation.fromValue = 0
    rotation.toValue = Double.pi * 2
    rotation.duration = period
    rotation.repeatCount = .infinity
    rotation.timingFunction = CAMediaTimingFunction(name: .linear)
    rotation.beginTime = localNow - epochOffset
    layer.add(rotation, forKey: "loading")
    CATransaction.commit()
  }

  private static func synchronizedAngle(at date: Date) -> Double {
    date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period * .pi * 2
  }

  static func showStatic(layer: CAShapeLayer, params: AiLoaderCreationParams, loading: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAllAnimations()
    layer.transform = CATransform3DIdentity
    layer.fillColor = loading ? clear : params.solid
    layer.strokeColor = loading ? params.outline : params.solid
    CATransaction.commit()
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
    var transform = CGAffineTransform(a: 7.0 / 12.0, b: 0, c: 0, d: 7.0 / 12.0, tx: 3, ty: 3.4)
    return path.copy(using: &transform)!
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
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
      self.messenger = messenger
      super.init()
    }

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
      return NativeAiLoaderPlatformView(frame: frame, params: params, messenger: messenger, viewId: viewId)
    }
  }

  private final class NativeAiLoaderPlatformView: UIView, FlutterPlatformView {
    private let params: AiLoaderCreationParams
    private let fitLayer = CALayer()
    private let sparkleLayer: CAShapeLayer
    private let channel: FlutterMethodChannel
    private var loading: Bool

    init(frame: CGRect, params: AiLoaderCreationParams, messenger: FlutterBinaryMessenger, viewId: Int64) {
      self.params = params
      loading = params.loading
      channel = FlutterMethodChannel(name: "sesori/native-ai-loader/\(viewId)", binaryMessenger: messenger)
      sparkleLayer = AiLoaderSparkle.makeShapeLayer(params: params)
      super.init(frame: frame)

      // The Flutter widget owns any meaning; hide the decoration from
      // VoiceOver like the activity indicator above.
      isAccessibilityElement = false
      accessibilityElementsHidden = true
      fitLayer.bounds = CGRect(
        x: 0, y: 0, width: AiLoaderSparkle.viewBox, height: AiLoaderSparkle.viewBox)
      // Keep Figma's baseline offset outside rotation so every quarter-turn
      // rests on the same footprint as an initially idle sparkle.
      sparkleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.52)
      sparkleLayer.position = CGPoint(x: 10, y: 10.4)
      fitLayer.addSublayer(sparkleLayer)
      layer.addSublayer(fitLayer)

      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "setLoading" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let loading = call.arguments as? Bool else {
          result(FlutterError(
            code: "invalid_arguments",
            message: "Expected a Boolean loading argument for native AI loader view \(viewId)",
            details: call.arguments
          ))
          return
        }
        self?.setLoading(loading: loading)
        result(nil)
      }

      let notificationCenter = NotificationCenter.default
      notificationCenter.addObserver(
        self,
        selector: #selector(animationConditionsDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
      // UIKit strips animations on backgrounding. Resume only loading when
      // the app returns; idle must never replay its completion transition.
      notificationCenter.addObserver(
        self,
        selector: #selector(animationConditionsDidChange),
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
      notificationCenter.addObserver(
        self,
        selector: #selector(animationConditionsDidChange),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      channel.setMethodCallHandler(nil)
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

    @objc private func animationConditionsDidChange() {
      updateAnimationState()
    }

    private var canAnimate: Bool {
      window != nil && UIApplication.shared.applicationState == .active
        && !UIAccessibility.isReduceMotionEnabled
    }

    private func setLoading(loading: Bool) {
      guard self.loading != loading else { return }
      self.loading = loading
      if canAnimate {
        if loading {
          startLoading()
        } else {
          AiLoaderSparkle.animate(layer: sparkleLayer, params: params, loading: false)
        }
      } else {
        AiLoaderSparkle.showStatic(layer: sparkleLayer, params: params, loading: loading)
      }
    }

    private func updateAnimationState() {
      if !canAnimate {
        AiLoaderSparkle.showStatic(layer: sparkleLayer, params: params, loading: loading)
      } else if loading && sparkleLayer.animation(forKey: "loading") == nil {
        AiLoaderSparkle.startSynchronizedLoading(layer: sparkleLayer, params: params)
      }
    }

    private func startLoading() {
      AiLoaderSparkle.animate(layer: sparkleLayer, params: params, loading: true) { [weak self] in
        guard let self, self.loading, self.canAnimate else { return }
        AiLoaderSparkle.startSynchronizedLoading(layer: self.sparkleLayer, params: self.params)
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
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
      self.messenger = messenger
      super.init()
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      guard let params = AiLoaderCreationParams(from: args) else {
        preconditionFailure("Invalid native AI loader creation arguments")
      }
      return NativeAiLoaderView(params: params, messenger: messenger, viewId: viewId)
    }
  }

  private final class NativeAiLoaderView: NSView {
    private let params: AiLoaderCreationParams
    private let fitLayer = CALayer()
    private let sparkleLayer: CAShapeLayer
    private let channel: FlutterMethodChannel
    private var loading: Bool

    override var isFlipped: Bool { true }

    init(params: AiLoaderCreationParams, messenger: FlutterBinaryMessenger, viewId: Int64) {
      self.params = params
      loading = params.loading
      channel = FlutterMethodChannel(name: "sesori/native-ai-loader/\(viewId)", binaryMessenger: messenger)
      sparkleLayer = AiLoaderSparkle.makeShapeLayer(params: params)
      super.init(frame: .zero)

      // The Flutter widget owns any meaning; hide the decoration from
      // VoiceOver like the activity indicator above.
      setAccessibilityElement(false)
      wantsLayer = true
      fitLayer.bounds = CGRect(
        x: 0, y: 0, width: AiLoaderSparkle.viewBox, height: AiLoaderSparkle.viewBox)
      // Keep Figma's baseline offset outside rotation so every quarter-turn
      // rests on the same footprint as an initially idle sparkle.
      sparkleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.52)
      sparkleLayer.position = CGPoint(x: 10, y: 10.4)
      fitLayer.addSublayer(sparkleLayer)
      layer?.addSublayer(fitLayer)

      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "setLoading" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let loading = call.arguments as? Bool else {
          result(FlutterError(
            code: "invalid_arguments",
            message: "Expected a Boolean loading argument for native AI loader view \(viewId)",
            details: call.arguments
          ))
          return
        }
        self?.setLoading(loading: loading)
        result(nil)
      }

      NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(accessibilityDisplayOptionsDidChange),
        name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil
      )
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    deinit {
      channel.setMethodCallHandler(nil)
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

    private var canAnimate: Bool {
      window != nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func setLoading(loading: Bool) {
      guard self.loading != loading else { return }
      self.loading = loading
      if canAnimate {
        if loading {
          startLoading()
        } else {
          AiLoaderSparkle.animate(layer: sparkleLayer, params: params, loading: false)
        }
      } else {
        AiLoaderSparkle.showStatic(layer: sparkleLayer, params: params, loading: loading)
      }
    }

    private func updateAnimationState() {
      if !canAnimate {
        AiLoaderSparkle.showStatic(layer: sparkleLayer, params: params, loading: loading)
      } else if loading && sparkleLayer.animation(forKey: "loading") == nil {
        AiLoaderSparkle.startSynchronizedLoading(layer: sparkleLayer, params: params)
      }
    }

    private func startLoading() {
      AiLoaderSparkle.animate(layer: sparkleLayer, params: params, loading: true) { [weak self] in
        guard let self, self.loading, self.canAnimate else { return }
        AiLoaderSparkle.startSynchronizedLoading(layer: self.sparkleLayer, params: self.params)
      }
    }
  }

#endif
