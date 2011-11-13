Name "Scala for Windows"

# General Symbol Definitions
!define REGKEY "SOFTWARE\$(^Name)"

# MultiUser Symbol Definitions
!define MULTIUSER_EXECUTIONLEVEL Admin
!define MULTIUSER_MUI
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_KEY "${REGKEY}"
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME MultiUserInstallMode
!define MULTIUSER_INSTALLMODE_COMMANDLINE
!define MULTIUSER_INSTALLMODE_INSTDIR Scala
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_KEY "${REGKEY}"
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUE "Path"

# MUI Symbol Definitions
!define MUI_ICON "scala.ico"
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_STARTMENUPAGE_REGISTRY_ROOT HKLM
!define MUI_STARTMENUPAGE_REGISTRY_KEY ${REGKEY}
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME StartMenuGroup
!define MUI_STARTMENUPAGE_DEFAULTFOLDER Scala
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\orange-uninstall.ico"
!define MUI_UNFINISHPAGE_NOAUTOCLOSE

# Included files
!include MultiUser.nsh
!include Sections.nsh
!include MUI2.nsh
!include EnvVarUpdate.nsh
!include NSISpcre.nsh
!insertmacro REMatches

# Variables
Var StartMenuGroup
var PathKey
var ScalaVer

# Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE license.txt
!insertmacro MULTIUSER_PAGE_INSTALLMODE
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuGroup
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

# Installer languages
!insertmacro MUI_LANGUAGE English

# Installer attributes
OutFile SetupScala.exe
InstallDir Scala
CRCCheck on
XPStyle on
ShowInstDetails show
InstallDirRegKey HKLM "${REGKEY}" Path
ShowUninstDetails show

# Installer sections
!macro CREATE_SMGROUP_SHORTCUT NAME PATH
	Push "${NAME}"
	Push "${PATH}"
	Call CreateSMGroupShortcut
!macroend

Section -Scala SEC0000
	ExecWait '"java.exe" -version'
	IfErrors 0 GetScala
		MessageBox MB_OK "JVM cannot be found. Installation will continue but you have to install a JVM and make 'java' available to command line."

	GetScala:
	#Download, download page to get latest version information
	inetc::get "http://www.scala-lang.org/downloads" "$TEMP\scala-dl.html"
	Pop $R0
	StrCmp $R0 "OK" 0 VersionFail
	ClearErrors
	FileOpen $0 "$TEMP\scala-dl.html" r
	IfErrors VersionFail
	ReadLine:
		FileRead $0 $1
		${RECaptureMatches} $2 "The current version of Scala is <strong>(.+)<\/strong>" $1 1
		StrCmp $2 "false" +3
			Pop $ScalaVer
			Goto EndVersion
		StrCmp $1 "" 0 ReadLine
	EndVersion:
	FileClose $0
	Delete "$TEMP\scala-dl.html"
	Goto +3
	VersionFail:
		MessageBox MB_OK "Cannot get or parse latest Scala version!"
		Quit
	
	DetailPrint "Found Scala at version $ScalaVer"
	#Download latest version of Scala for Windows
	inetc::get "http://www.scala-lang.org/downloads/distrib/files/scala-$ScalaVer.final.zip" $TEMP\scala-latest.zip
	Pop $R0 ;Get the return value
	StrCmp $R0 "OK" +3
		MessageBox MB_OK "Scala download failed: $R0"
		Quit

  #Unzip the files
	CreateDirectory $INSTDIR
  nsisunz::UnzipToLog "$TEMP\scala-latest.zip" "$TEMP"
	Pop $R0
	StrCmp $R0 "success" +3
		MessageBox MB_OK "Scala unzip failed: $R0"
		Quit
	Delete $TEMP\scala-latest.zip
	CopyFiles "$TEMP\scala-$ScalaVer\*" "$INSTDIR"
	RMDir /r "$TEMP\scala-$ScalaVer"
  
	#Update PATH variable
	StrCpy $PathKey "HKLM"
	StrCmp $MultiUser.InstallMode "AllUsers" +2
		StrCpy $PathKey "HKCU"
	
	${EnvVarUpdate} $0 "PATH" "A" "$PathKey" "$INSTDIR\bin"

	!insertmacro CREATE_SMGROUP_SHORTCUT "Scala Console" "$INSTDIR\bin\scala.bat"
	!insertmacro CREATE_SMGROUP_SHORTCUT "Scala Website" http://scala-lang.org
	WriteRegStr HKLM "${REGKEY}\Components" Scala 1
SectionEnd

Section -post SEC0001
	WriteRegStr HKLM "${REGKEY}" Path $INSTDIR
	WriteRegStr HKLM "${REGKEY}" Mode $MultiUser.InstallMode
	SetOutPath $INSTDIR
	WriteUninstaller $INSTDIR\uninstall.exe
	!insertmacro MUI_STARTMENU_WRITE_BEGIN Application
	SetOutPath $SMPROGRAMS\$StartMenuGroup
	CreateShortcut "$SMPROGRAMS\$StartMenuGroup\Uninstall $(^Name).lnk" $INSTDIR\uninstall.exe
	!insertmacro MUI_STARTMENU_WRITE_END
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayName "$(^Name)"
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" DisplayIcon $INSTDIR\uninstall.exe
	WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" UninstallString $INSTDIR\uninstall.exe
	WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoModify 1
	WriteRegDWORD HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)" NoRepair 1
SectionEnd

# Macro for selecting uninstaller sections
!macro SELECT_UNSECTION SECTION_NAME UNSECTION_ID
	Push $R0
	ReadRegStr $R0 HKLM "${REGKEY}\Components" "${SECTION_NAME}"
	StrCmp $R0 1 0 next${UNSECTION_ID}
	!insertmacro SelectSection "${UNSECTION_ID}"
	GoTo done${UNSECTION_ID}
next${UNSECTION_ID}:
	!insertmacro UnselectSection "${UNSECTION_ID}"
done${UNSECTION_ID}:
	Pop $R0
!macroend

# Uninstaller sections
!macro DELETE_SMGROUP_SHORTCUT NAME
	Push "${NAME}"
	Call un.DeleteSMGroupShortcut
!macroend

Section /o -un.Scala UNSEC0000
	#Update PATH variable
	StrCpy $PathKey "HKLM"
	ReadRegStr $R0 HKLM "${REGKEY}" "Mode"
	StrCmp $R0 "AllUsers" +2
		StrCpy $PathKey "HKCU"
	${un.EnvVarUpdate} $0 "PATH" "R" "$PathKey" "$INSTDIR\bin"
	
	!insertmacro DELETE_SMGROUP_SHORTCUT "Scala Console"
	!insertmacro DELETE_SMGROUP_SHORTCUT "Scala Website"
	DeleteRegValue HKLM "${REGKEY}\Components" Scala
	
	#Remove scala directory
	RMDir /r /REBOOTOK $INSTDIR
SectionEnd

Section -un.post UNSEC0001
	DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$(^Name)"
	Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\Uninstall $(^Name).lnk"
	Delete /REBOOTOK $INSTDIR\uninstall.exe
	DeleteRegValue HKLM "${REGKEY}" StartMenuGroup
	DeleteRegValue HKLM "${REGKEY}" Path
	DeleteRegKey /IfEmpty HKLM "${REGKEY}\Components"
	DeleteRegKey /IfEmpty HKLM "${REGKEY}"
	RmDir /REBOOTOK $SMPROGRAMS\$StartMenuGroup
	RmDir /REBOOTOK $INSTDIR
	Push $R0
	StrCpy $R0 $StartMenuGroup 1
	StrCmp $R0 ">" no_smgroup
no_smgroup:
	Pop $R0
SectionEnd

# Installer functions
Function .onInit
  InitPluginsDir
  !insertmacro MULTIUSER_INIT
FunctionEnd

Function CreateSMGroupShortcut
  Exch $R0 ;PATH
  Exch
  Exch $R1 ;NAME
  Push $R2
  StrCpy $R2 $StartMenuGroup 1
  StrCmp $R2 ">" no_smgroup
  SetOutPath $SMPROGRAMS\$StartMenuGroup
  CreateShortcut "$SMPROGRAMS\$StartMenuGroup\$R1.lnk" $R0
no_smgroup:
  Pop $R2
  Pop $R1
  Pop $R0
FunctionEnd

# Uninstaller functions
Function un.onInit
	#!insertmacro MULTIUSER_UNINIT; breaks the start menu folder detection
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuGroup
  !insertmacro SELECT_UNSECTION Scala ${UNSEC0000}
FunctionEnd

Function un.DeleteSMGroupShortcut
  Exch $R1 ;NAME
  Push $R2
  StrCpy $R2 $StartMenuGroup 1
  StrCmp $R2 ">" no_smgroup
  Delete /REBOOTOK "$SMPROGRAMS\$StartMenuGroup\$R1.lnk"
no_smgroup:
  Pop $R2
  Pop $R1
FunctionEnd