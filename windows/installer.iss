#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{EB1BEEEF-EC84-4267-A9E7-078FE4863579}
AppName=Streak
AppVersion={#AppVersion}
AppVerName=Streak {#AppVersion}
AppPublisher=InlitX
AppPublisherURL=https://github.com/InlitX/streak
AppSupportURL=https://github.com/InlitX/streak/issues
AppUpdatesURL=https://github.com/InlitX/streak/releases
DefaultDirName={autopf}\Streak
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=Streak-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Streak.exe
UninstallDisplayName=Streak
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Streak"; Filename: "{app}\Streak.exe"; AppUserModelID: "com.streak.app"
Name: "{autodesktop}\Streak"; Filename: "{app}\Streak.exe"; Tasks: desktopicon; AppUserModelID: "com.streak.app"

[Run]
Filename: "{app}\Streak.exe"; Description: "{cm:LaunchProgram,Streak}"; Flags: nowait postinstall skipifsilent
