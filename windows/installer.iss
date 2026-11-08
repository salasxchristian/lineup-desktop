; Inno Setup script for the Windows installer. Build the app first, then from the repo root:
;   flutter build windows --release
;   iscc /DAppVersion=0.1.0 windows\installer.iss
; The installer lands in build\installer\.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{8C6A8A59-81EB-4E9D-9BF8-C61E1062D07C}
AppName=Lineup
AppVersion={#AppVersion}
AppPublisher=mildpepper
DefaultDirName={autopf}\Lineup
DisableProgramGroupPage=yes
OutputDir=..\build\installer
OutputBaseFilename=LineupSetup-{#AppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Lineup.exe
UninstallDisplayName=Lineup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs for the current user without asking for admin, unless they choose all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Lineup"; Filename: "{app}\Lineup.exe"
Name: "{autodesktop}\Lineup"; Filename: "{app}\Lineup.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Lineup.exe"; Description: "{cm:LaunchProgram,Lineup}"; Flags: nowait postinstall skipifsilent
