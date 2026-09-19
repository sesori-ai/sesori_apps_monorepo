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
    password: Data
) -> (OSStatus, SecKeychainItem?) {
    var item: SecKeychainItem?
    let status = service.withCString { serviceBytes in
        account.withCString { accountBytes in
            password.withUnsafeBytes { passwordBytes in
                SecKeychainAddGenericPassword(
                    nil,
                    UInt32(service.utf8.count),
                    serviceBytes,
                    UInt32(account.utf8.count),
                    accountBytes,
                    UInt32(passwordBytes.count),
                    passwordBytes.baseAddress!,
                    &item
                )
            }
        }
    }
    return (status, item)
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

let item: SecKeychainItem
let created: Bool
switch operation {
case .create:
    let (status, addedItem) = addGenericPassword(service: service, account: account, password: password)
    guard status == errSecSuccess, let addedItem else {
        fail("Could not create Keychain item: \(describe(status))")
    }
    item = addedItem
    created = true
case .update:
    let (findStatus, existingItem) = genericPasswordItem(service: service, account: account)
    guard findStatus == errSecSuccess, let existingItem else {
        fail("Could not find Keychain item to update: \(describe(findStatus))")
    }
    let updateStatus = updateGenericPassword(item: existingItem, password: password)
    guard updateStatus == errSecSuccess else {
        fail("Could not update Keychain item: \(describe(updateStatus))")
    }
    item = existingItem
    created = false
}

let itemAccessStatus = SecKeychainItemSetAccess(item, access)
if itemAccessStatus != errSecSuccess {
    if created {
        let rollbackStatus = SecKeychainItemDelete(item)
        if rollbackStatus != errSecSuccess {
            fail(
                "Could not apply Keychain access policy: \(describe(itemAccessStatus)); "
                    + "rollback also failed: \(describe(rollbackStatus))"
            )
        }
    }
    fail("Could not apply Keychain access policy: \(describe(itemAccessStatus))")
}
