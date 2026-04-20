[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{5A1B8C9D-E23F-47A6-9128-DBF5A9A01C2E}
AppName=SpeedShare
AppVersion=1.0.0
AppPublisher=SpeedShare Team
DefaultDirName={autopf}\SpeedShare
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes
OutputDir=installers
OutputBaseFilename=SpeedShare_Windows_Setup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\speedsharemob.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Include required MSVC++ runtime DLLs (if they are present in the build folder, they will be copied by the asterisk. If not, they are sometimes needed depending on the user environment).

[Icons]
Name: "{autoprograms}\SpeedShare"; Filename: "{app}\speedsharemob.exe"
Name: "{autodesktop}\SpeedShare"; Filename: "{app}\speedsharemob.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\speedsharemob.exe"; Description: "{cm:LaunchProgram,SpeedShare}"; Flags: nowait postinstall skipifsilent
