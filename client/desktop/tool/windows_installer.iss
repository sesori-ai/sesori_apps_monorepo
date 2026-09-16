#ifndef BundleDir
  #error BundleDir must name the absolute staged Windows bundle
#endif
#ifndef OutputDir
  #error OutputDir must name the absolute installer output directory
#endif
#ifndef AppVersion
  #error AppVersion must be supplied by the bundle manifest
#endif
#ifndef Architecture
  #error Architecture must be x64 or arm64
#endif

#define AppName "Sesori"
#define AppId "com.sesori.desktop"
#define RunningMutexPrefix "Global\com.sesori.desktop.running."

#if Architecture == "x64"
  #define AllowedArchitecture "x64os"
#elif Architecture == "arm64"
  #define AllowedArchitecture "arm64"
#else
  #error Unsupported Architecture
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Sesori
DefaultGroupName=Sesori
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
SetupArchitecture=x64
ArchitecturesAllowed={#AllowedArchitecture}
ArchitecturesInstallIn64BitMode={#AllowedArchitecture}
AppMutex={code:RunningMutexName}
CloseApplications=no
RestartApplications=no
OutputDir={#OutputDir}
OutputBaseFilename=Sesori-windows-{#Architecture}-{#AppVersion}
Compression=lzma2
SolidCompression=yes
SetupLogging=yes
UninstallDisplayIcon={app}\sesori_desktop.exe
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Sesori"; Filename: "{app}\sesori_desktop.exe"
Name: "{autodesktop}\Sesori"; Filename: "{app}\sesori_desktop.exe"; Tasks: desktopicon

[Code]
const
  TokenUser = 1;
  TokenQuery = $0008;

type
  TTokenUserBuffer = record
    Sid: NativeUInt;
    Attributes: Cardinal;
    AlignmentPadding: Cardinal;
    SidData: array[0..67] of Byte;
  end;

function GetCurrentProcess: THandle;
external 'GetCurrentProcess@kernel32.dll stdcall';
function OpenProcessToken(ProcessHandle: THandle; DesiredAccess: Cardinal; var TokenHandle: THandle): Boolean;
external 'OpenProcessToken@advapi32.dll stdcall';
function GetTokenInformation(TokenHandle: THandle; TokenInformationClass: Integer;
  var TokenInformation: TTokenUserBuffer; TokenInformationLength: Cardinal;
  var ReturnLength: Cardinal): Boolean;
external 'GetTokenInformation@advapi32.dll stdcall';
function ConvertSidToStringSid(Sid: NativeUInt; var StringSid: NativeUInt): Boolean;
external 'ConvertSidToStringSidW@advapi32.dll stdcall';
function LocalFree(Memory: NativeUInt): NativeUInt;
external 'LocalFree@kernel32.dll stdcall';
function CloseHandle(Handle: THandle): Boolean;
external 'CloseHandle@kernel32.dll stdcall';

function RunningMutexName(Param: String): String;
var
  Token: THandle;
  TokenUserBuffer: TTokenUserBuffer;
  ReturnLength: Cardinal;
  StringSid: NativeUInt;
begin
  if not OpenProcessToken(GetCurrentProcess, TokenQuery, Token) then
    RaiseException('Sesori Setup could not open the current Windows user token.');
  try
    if not GetTokenInformation(Token, TokenUser, TokenUserBuffer, SizeOf(TokenUserBuffer), ReturnLength) then
      RaiseException('Sesori Setup could not read the current Windows user SID.');
    if not ConvertSidToStringSid(TokenUserBuffer.Sid, StringSid) then
      RaiseException('Sesori Setup could not format the current Windows user SID.');
    try
      Result := '{#RunningMutexPrefix}' + CastIntegerToString(StringSid);
    finally
      LocalFree(StringSid);
    end;
  finally
    CloseHandle(Token);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Sesori');
end;
