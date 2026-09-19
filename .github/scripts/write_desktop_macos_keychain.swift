import Foundation
import Security

private enum Operation: String {
    case create
    case update
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

private func describe(_ status: OSStatus) -> String {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Security.framework error"
    return "OSStatus \(status): \(message)"
}

private func trustedApplication(path: String) -> SecTrustedApplication {
    var application: SecTrustedApplication?
    let status = SecTrustedApplicationCreateFromPath(path, &application)
    guard status == errSecSuccess, let application else {
        fail("Could not trust \(path): \(describe(status))")
    }
    return application
}

private func genericPasswordItem(service: String, account: String) -> (OSStatus, SecKeychainItem?) {
    var item: SecKeychainItem?
    let status = service.withCString { serviceBytes in
        account.withCString { accountBytes in
            SecKeychainFindGenericPassword(
                nil,
                UInt32(service.utf8.count),
                serviceBytes,
                UInt32(account.utf8.count),
                accountBytes,
                nil,
                nil,
                &item
            )
        }
    }
    return (status, item)
}

private func addGenericPassword(
    service: String,
    account: String,
    password: Data,
    access: SecAccess
) -> (OSStatus, SecKeychainItem?) {
    var result: CFTypeRef?
    let status = SecItemAdd(
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: password,
            // Match FlutterSecureStorage's classic-Keychain query envelope exactly.
            kSecAttrSynchronizable: false,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecAttrAccess: access,
            kSecReturnRef: true,
        ] as CFDictionary,
        &result
    )
    return (status, result as! SecKeychainItem?)
}

private func updateGenericPassword(item: SecKeychainItem, password: Data) -> OSStatus {
    password.withUnsafeBytes { passwordBytes in
        SecKeychainItemModifyAttributesAndData(
            item,
            nil,
            UInt32(passwordBytes.count),
            passwordBytes.baseAddress!
        )
    }
}

private func flutterSecureStorageItemStatus(service: String, account: String) -> OSStatus {
    var value: CFTypeRef?
    return SecItemCopyMatching(
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary,
        &value
    )
}

guard CommandLine.arguments.count == 6 else {
    fail("Usage: keychain-writer <create|update> <account> <service> <trusted-app> <trusted-tool>")
}
guard let operation = Operation(rawValue: CommandLine.arguments[1]) else {
    fail("Unknown Keychain writer operation")
}

let account = CommandLine.arguments[2]
let service = CommandLine.arguments[3]
let rawWriterPath = CommandLine.arguments[0]
let absoluteWriterPath = rawWriterPath.hasPrefix("/")
    ? rawWriterPath
    : (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(rawWriterPath)
let trustedPaths = [
    CommandLine.arguments[4],
    CommandLine.arguments[5],
    URL(fileURLWithPath: absoluteWriterPath).standardizedFileURL.path,
]
var password = FileHandle.standardInput.readDataToEndOfFile()
if password.last == 0x0A {
    password.removeLast()
}
if password.last == 0x0D {
    password.removeLast()
}
guard !password.isEmpty else {
    fail("Keychain writer received an empty secret")
}

let trustedApplications = trustedPaths.map { trustedApplication(path: $0) }
var access: SecAccess?
let accessStatus = SecAccessCreate(
    "Sesori desktop QA credential" as CFString,
    trustedApplications as CFArray,
    &access
)
guard accessStatus == errSecSuccess, let access else {
    fail("Could not create Keychain access policy: \(describe(accessStatus))")
}

switch operation {
case .create:
    let (status, addedItem) = addGenericPassword(
        service: service,
        account: account,
        password: password,
        access: access
    )
    guard status == errSecSuccess, addedItem != nil else {
        fail("Could not create Keychain item: \(describe(status))")
    }
    let readStatus = flutterSecureStorageItemStatus(service: service, account: account)
    guard readStatus == errSecSuccess else {
        fail("Created Keychain item does not match Flutter secure-storage query: \(describe(readStatus))")
    }
case .update:
    let (findStatus, existingItem) = genericPasswordItem(service: service, account: account)
    guard findStatus == errSecSuccess, let existingItem else {
        fail("Could not find Keychain item to update: \(describe(findStatus))")
    }
    let updateStatus = updateGenericPassword(item: existingItem, password: password)
    guard updateStatus == errSecSuccess else {
        fail("Could not update Keychain item: \(describe(updateStatus))")
    }
    let readStatus = flutterSecureStorageItemStatus(service: service, account: account)
    guard readStatus == errSecSuccess else {
        fail("Updated Keychain item does not match Flutter secure-storage query: \(describe(readStatus))")
    }
}
