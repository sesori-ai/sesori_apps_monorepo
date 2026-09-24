import Foundation
import Security

private enum Operation: String {
    case create
    case update
    case read
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

private func describe(_ status: OSStatus) -> String {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Security.framework error"
    return "OSStatus \(status): \(message)"
}

private func developerIdTeam(path: String) -> String {
    var code: SecStaticCode?
    let codeStatus = SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code)
    guard codeStatus == errSecSuccess, let code else {
        fail("Could not inspect trusted executable: \(describe(codeStatus))")
    }
    var requirement: SecRequirement?
    let requirementStatus = SecRequirementCreateWithString(
        "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists" as CFString,
        [],
        &requirement
    )
    guard requirementStatus == errSecSuccess, let requirement else {
        fail("Could not create Developer ID requirement: \(describe(requirementStatus))")
    }
    let validity = SecStaticCodeCheckValidity(code, [], requirement)
    guard validity == errSecSuccess else {
        fail("Keychain helper and app must both have valid Developer ID signatures: \(describe(validity))")
    }
    var information: CFDictionary?
    let infoStatus = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
    guard infoStatus == errSecSuccess,
          let information = information as? [String: Any],
          let team = information[kSecCodeInfoTeamIdentifier as String] as? String,
          !team.isEmpty else {
        fail("Could not read Developer ID team: \(describe(infoStatus))")
    }
    return team
}

private func secretInput() -> Data {
    var password = FileHandle.standardInput.readDataToEndOfFile()
    if password.last == 0x0A { password.removeLast() }
    if password.last == 0x0D { password.removeLast() }
    guard !password.isEmpty else { fail("Keychain writer received an empty secret") }
    return password
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
            // Pinned FlutterSecureStorage classic mode skips only the entitlement-requiring
            // synchronizable=true branch; its base query still fixes these two attributes.
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

private func flutterSecureStorageItem(service: String, account: String) -> (OSStatus, Data?) {
    var value: CFTypeRef?
    let status = SecItemCopyMatching(
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
    return (status, value as? Data)
}

guard CommandLine.arguments.count == 5 else {
    fail("Usage: keychain-writer <create|update|read> <account> <service> <trusted-app>")
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
let writerPath = URL(fileURLWithPath: absoluteWriterPath).standardizedFileURL.path
let appPath = CommandLine.arguments[4]
// The trusted-app ACL alone does not cross the login Keychain's signing partition.
// Developer ID-signed processes share their team partition; retain the exact-app ACL as well.
guard developerIdTeam(path: writerPath) == developerIdTeam(path: appPath) else {
    fail("Keychain helper and desktop app must share the same Developer ID team")
}
let interactionStatus = SecKeychainSetUserInteractionAllowed(false)
guard interactionStatus == errSecSuccess else {
    fail("Could not disable interactive Keychain prompts: \(describe(interactionStatus))")
}

switch operation {
case .create:
    let password = secretInput()
    let trustedApplications = [appPath, writerPath].map { trustedApplication(path: $0) }
    var access: SecAccess?
    let accessStatus = SecAccessCreate(
        "Sesori desktop QA credential" as CFString,
        trustedApplications as CFArray,
        &access
    )
    guard accessStatus == errSecSuccess, let access else {
        fail("Could not create Keychain access policy: \(describe(accessStatus))")
    }
    let (status, addedItem) = addGenericPassword(
        service: service,
        account: account,
        password: password,
        access: access
    )
    guard status == errSecSuccess, addedItem != nil else {
        fail("Could not create Keychain item: \(describe(status))")
    }
case .update:
    let password = secretInput()
    let (findStatus, existingItem) = genericPasswordItem(service: service, account: account)
    guard findStatus == errSecSuccess, let existingItem else {
        fail("Could not find Keychain item to update: \(describe(findStatus))")
    }
    let updateStatus = updateGenericPassword(item: existingItem, password: password)
    guard updateStatus == errSecSuccess else {
        fail("Could not update Keychain item: \(describe(updateStatus))")
    }
case .read:
    let (status, value) = flutterSecureStorageItem(service: service, account: account)
    guard status == errSecSuccess, let value else {
        fail("Could not read Keychain item: \(describe(status))")
    }
    // The qualification driver captures this pipe privately. Never send it to an artifact or terminal.
    FileHandle.standardOutput.write(value)
    exit(0)
}
let (readStatus, _) = flutterSecureStorageItem(service: service, account: account)
guard readStatus == errSecSuccess else {
    fail("Written Keychain item does not match Flutter secure-storage query: \(describe(readStatus))")
}
