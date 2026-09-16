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
#define RunningMutex "Local\com.sesori.desktop.running"

#if Architecture == "x64"
  #define AllowedArchitecture "x64compatible"
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
ArchitecturesAllowed={#AllowedArchitecture}
ArchitecturesInstallIn64BitMode={#AllowedArchitecture}
AppMutex={#RunningMutex}
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
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'Sesori');
end;
