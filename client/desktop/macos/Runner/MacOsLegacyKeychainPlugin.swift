import FlutterMacOS
import Security

/// Classic Keychain storage for non-provisioned desktop builds.
///
/// The SecItem queries deliberately omit Data Protection, accessibility, and
/// synchronizable attributes because those require a provisioned
/// keychain-access-group entitlement on macOS. Without a keychain selector,
/// SecItemAdd uses the user's default keychain and the same query also finds
/// credentials written by the former explicit-default-keychain path.
final class MacOsLegacyKeychainPlugin {
  private static let channelName = "com.sesori.desktop/legacy-keychain"
  private static let service = "com.sesori.desktop"
  private static let operationQueue = DispatchQueue(
    label: "com.sesori.desktop.legacy-keychain",
    qos: .userInitiated
  )
  private static var channel: FlutterMethodChannel?

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      guard ["read", "write", "delete"].contains(call.method) else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let key = arguments["key"] as? String,
        !key.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "A non-empty Keychain key is required",
            details: nil
          )
        )
        return
      }

      operationQueue.async {
        do {
          let value = try execute(method: call.method, key: key, arguments: arguments)
          DispatchQueue.main.async {
            result(value)
          }
        } catch let error as KeychainOperationError {
          DispatchQueue.main.async {
            result(error.flutterError)
          }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "keychain_error",
                message: "Unexpected macOS Keychain failure",
                details: nil
              )
            )
          }
        }
      }
    }
    self.channel = channel
  }

  private static func execute(
    method: String,
    key: String,
    arguments: [String: Any]
  ) throws -> Any? {
    switch method {
    case "read":
      return try read(key: key)
    case "write":
      guard let value = arguments["value"] as? String else {
        throw KeychainOperationError.invalidValue
      }
      try write(key: key, value: value)
      return nil
    case "delete":
      try delete(key: key)
      return nil
    default:
      return nil
    }
  }

  private static func read(key: String) throws -> String? {
    var result: CFTypeRef?
    var query = baseQuery(key: key)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    try requireSuccess(status: status)
    guard
      let data = result as? Data,
      let value = String(data: data, encoding: .utf8)
    else {
      throw KeychainOperationError.invalidData
    }
    return value
  }

  private static func write(key: String, value: String) throws {
    let data = Data(value.utf8)
    let query = baseQuery(key: key)
    let attributes = [kSecValueData: data] as CFDictionary
    let updateStatus = SecItemUpdate(query as CFDictionary, attributes)
    if updateStatus == errSecItemNotFound {
      var newItem = query
      newItem[kSecValueData] = data
      let addStatus = SecItemAdd(newItem as CFDictionary, nil)
      if addStatus == errSecDuplicateItem {
        try requireSuccess(status: SecItemUpdate(query as CFDictionary, attributes))
      } else {
        try requireSuccess(status: addStatus)
      }
      return
    }
    try requireSuccess(status: updateStatus)
  }

  private static func delete(key: String) throws {
    let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
    if status != errSecItemNotFound {
      try requireSuccess(status: status)
    }
  }

  private static func baseQuery(key: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: key,
    ]
  }

  private static func requireSuccess(status: OSStatus) throws {
    if status != errSecSuccess {
      throw KeychainOperationError.status(status)
    }
  }
}

private enum KeychainOperationError: Error {
  case invalidValue
  case invalidData
  case status(OSStatus)

  var flutterError: FlutterError {
    switch self {
    case .invalidValue:
      return FlutterError(
        code: "invalid_arguments",
        message: "A Keychain value is required",
        details: nil
      )
    case .invalidData:
      return FlutterError(
        code: "invalid_keychain_data",
        message: "The Keychain value is not valid UTF-8",
        details: nil
      )
    case .status(let status):
      return FlutterError(
        code: "keychain_error",
        message: SecCopyErrorMessageString(status, nil) as String?
          ?? "Unexpected macOS Keychain status",
        details: Int(status)
      )
    }
  }
}
