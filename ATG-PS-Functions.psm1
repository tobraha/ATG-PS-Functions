Function Start-PPKGLog ([String] $LogLabel) {
	Write-Host "Making a log file for debugging"
		$LogPath = "C:\Ambitions\" + $SiteCode + "-" + $LogLabel + ".log"
		Start-Transcript -path $LogPath -Force -Append
}

Function Update-WindowTitle ([String] $PassNumber) {
	Write-Host "Changing window title"
		$host.ui.RawUI.WindowTitle = "$SiteCode Provisioning | $env:computername | Pass $PassNumber | Please Wait"
}

Function Enable-SSL {
	Write-Host "Enabling SSL"
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
}

Function Set-MountainTime {
	Write-Host "Setting local time zone to Mountain Time"
	Set-TimeZone -Name "Mountain Standard Time"
	net start W32Time
	W32tm /resync /force
}

Function Install-Choco {
	Write-Host "Installing Chocolatey"
	$progressPreference = 'silentlyContinue'
	Set-ExecutionPolicy Bypass -Scope Process -Force
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
	Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/Chocolatey/installchoco.txt -UseBasicParsing | Invoke-Expression
}

Function Update-Edge {
	Write-Host "Updating Microsoft Edge"
	If (!(Get-Command choco)) {Install-Choco}
	If (Get-Process MicrosoftEdge -ErrorAction SilentlyContinue) {Get-Process MicrosoftEdge | Stop-Process -Force}
	Choco upgrade microsoft-edge -y
}

Function Update-PWSH {
	Write-Host "Updating PWSH"
	If (!(Get-Command choco)) {Install-Choco}
	Choco upgrade pwsh -y
}

Function Set-NumLock {
	Write-Host "Setting Numlock on keyboard as default"
	Reg.exe add "HKU\.DEFAULT\Control Panel\Keyboard" /v "InitialKeyboardIndicators" /t REG_SZ /d "2" /f
}

Function Install-ITS247Agent {
	$progressPreference = 'silentlyContinue'
	Set-ExecutionPolicy Bypass -Scope Process -Force
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
	Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/ITS247Agent/Install_ITS247_Agent.txt -UseBasicParsing | Invoke-Expression
}

Function Update-ITS247Agent {
	$DisplayVersion = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\SAAZOD).DisplayVersion
	$TYPE = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\SAAZOD).TYPE
	$AvailableVersion = (Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/ITS247Agent/DPMAVersion.txt -UseBasicParsing)

	if(($DisplayVersion -ne $AvailableVersion) -and ($TYPE -eq "DPMA")) {
	 WRITE-HOST "Updating Agent from $DisplayVersion to $AvailableVersion"
		 $SaveFolder = 'C:\Ambitions'
		 New-Item -ItemType Directory -Force -Path $SaveFolder
		 $PatchPath = $SaveFolder + '\DPMAPatch' + $AvailableVersion + '.exe'
		 (New-Object System.Net.WebClient).DownloadFile('http://update.itsupport247.net/agtupdt/DPMAPatch.exe', $PatchPath)
		 & $PatchPath | Wait-Process
		 $DisplayVersion = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\SAAZOD).DisplayVersion
	 WRITE-HOST "Agent is now version $DisplayVersion"
	}
<#
    .DESCRIPTION
		Updates the Continuum ITS247 Desktop agent to the latest available. No parameters are needed.
#>
}

Function Deploy-AppDefaults {
	Write-Host "Downloading App Defaults"
	New-Item -ItemType Directory -Force -Path C:\Ambitions\ITS247Agent
	(New-Object System.Net.WebClient).DownloadFile('https://download.ambitionsgroup.com/AppDefaults.xml', 'C:\Ambitions\AppDefaults.xml')
	Write-Host "Deploying App Defaults"
	Dism.exe /online /import-defaultappassociations:'C:\Ambitions\AppDefaults.xml'
}

Function Install-NinitePro {
	Write-Host "Downloading Ninite Installer"
	New-Item -ItemType Directory -Force -Path C:\Ambitions
	(New-Object System.Net.WebClient).DownloadFile('https://download.ambitionsgroup.com/NinitePro.exe', 'C:\Ambitions\NinitePro.exe')
	Write-Host "Schedule Ninite Updates"
	$Trigger = New-ScheduledTaskTrigger -AtStartup
	$User = "NT AUTHORITY\SYSTEM"
	$Action = New-ScheduledTaskAction -Execute "C:\Ambitions\NinitePro.exe" -Argument "/updateonly /nocache /silent C:\Ambitions\NiniteUpdates.log"
	Register-ScheduledTask -TaskName "Update Apps" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest -Force
	Write-Host "End of Schedule Ninite Updates"
}

Function Install-NiniteApps {
	If (-not (Test-Path 'C:\Ambitions\NinitePro.exe')) {Install-NinitePro}
	Write-Host "Install Ninite Apps, waiting for install to complete and logging the results."
		$NiniteCache = "\\adsaltoxl\data\Software\Ninite\NiniteDownloads"
		If(test-path $NiniteCache){
			& C:\Ambitions\NinitePro.exe /select 7-Zip Air Chrome 'Firefox ESR' Flash Greenshot 'Notepad++' 'Paint.NET' Reader Silverlight VLC /cachepath $NiniteCache /silent 'C:\Ambitions\NiniteReport.txt' | Wait-Process
		} ELSE {
			& C:\Ambitions\NinitePro.exe /select 7-Zip Air Chrome 'Firefox ESR' Flash Greenshot 'Notepad++' 'Paint.NET' Reader Silverlight VLC /nocache /silent 'C:\Ambitions\NiniteReport.txt' | Wait-Process
		}
	Write-Host "End of Install Ninite Apps"
}

Function Install-O365([String] $SiteCode = "Generic"){
	Write-Host "Downloading MS Office"
		Enable-SSL
		New-Item -ItemType Directory -Force -Path "C:\Ambitions\O365"
		(New-Object System.Net.WebClient).DownloadFile('https://download.ambitionsgroup.com/O365/setup.exe', 'C:\Ambitions\O365\setup.exe')
	Write-Host "Downloading MS Office config files"
		$O365ConfigSource = "https://download.ambitionsgroup.com/Sites/" + $SiteCode + "/" + $SiteCode + "_O365_Config.xml"
		$O365ConfigDest = "C:\Ambitions\O365\" + $SiteCode + "_O365_Config.xml"
		(New-Object System.Net.WebClient).DownloadFile($O365ConfigSource, $O365ConfigDest)
	Write-Host "Installing Office"
		& C:\Ambitions\O365\setup.exe /configure $O365ConfigDest | Wait-Process
	Write-Host "Placing Shortcuts"
		$TargetFile = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
		$ShortcutFile = "$env:Public\Desktop\Outlook.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()

		$TargetFile = "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
		$ShortcutFile = "$env:Public\Desktop\Excel.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()
		
		$TargetFile = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
		$ShortcutFile = "$env:Public\Desktop\Word.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()
}

Function Install-O2016STD([String] $MSPURL){
	Write-Host "Downloading MS Office"
		Enable-SSL
		New-Item -ItemType Directory -Force -Path 'C:\Ambitions\O2016STD'
		(New-Object System.Net.WebClient).DownloadFile('http://download.ambitionsgroup.com/Software/O2016_STD_X64.exe', 'C:\Ambitions\O2016STD\O2016_STD_X64.exe')
		
	Write-Host "Downloading MS Office config files"
		$MSPfilename = $MSPURL.Substring($MSPURL.LastIndexOf("/") + 1)
		$MSPfilepath = 'C:\Ambitions\O2016STD\' + $MSPfilename
		(New-Object System.Net.WebClient).DownloadFile($MSPURL, $MSPfilepath)

	Write-Host "Installing Office"
		& 'C:\Ambitions\O2016STD\O2016_STD_X64.exe' -pth!nSong70 -oC:\Ambitions\O2016STD -y | Wait-Process
		& 'C:\Ambitions\O2016STD\setup.exe' /adminfile $MSPfilepath | Wait-Process

	Write-Host "Placing Shortcuts"
		$TargetFile = 'C:\Program Files\Microsoft Office\Office16\OUTLOOK.EXE'
		$ShortcutFile = "$env:Public\Desktop\Outlook.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()

		$TargetFile = 'C:\Program Files\Microsoft Office\Office16\EXCEL.EXE'
		$ShortcutFile = "$env:Public\Desktop\Excel.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()
		
		$TargetFile = 'C:\Program Files\Microsoft Office\Office16\WINWORD.EXE'
		$ShortcutFile = "$env:Public\Desktop\Word.lnk"
		$WScriptShell = New-Object -ComObject WScript.Shell
		$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
		$Shortcut.TargetPath = $TargetFile
		$Shortcut.Save()
}

Function Install-NetExtender {
	Write-Host "Downloading & Installing NetExtender"
		If (!(Get-Command choco)) {Install-Choco}
		choco install sonicwall-sslvpn-netextender -y
}

Function Connect-NetExtender {
	param
	(
		[Parameter(Mandatory=$False)]
		[string]$DC,
		
		[Parameter(Mandatory=$true)]
		[string]$VPNuri,
		
		[Parameter(Mandatory=$true)]
		[string]$VPNuser,
		
		[Parameter(Mandatory=$true)]
		[string]$VPNpassword,
		
		[Parameter(Mandatory=$true)]
		[string]$VPNdomain
	)

	If (([string]::IsNullOrWhiteSpace($DC)) -or (-not (Test-Connection -comp $DC -quiet))) {
		If (!(Test-Path -LiteralPath 'C:\Program Files (x86)\SonicWALL\SSL-VPN\NetExtender\NEClI.exe')) { 
			Install-NetExtender
		}
		Write-host "Initiating VPN connection"
		echo y | & 'C:\Program Files (x86)\SonicWALL\SSL-VPN\NetExtender\NEClI.exe' connect -s $VPNuri -u $VPNuser -p $VPNpassword -d $VPNdomain
	}
<#
    .DESCRIPTION
		Initiates an SSLVPN connection to a site using Sonicwall NetExtender
	.PARAMETER DC
		(Optional) A domain controller whose connection to can be tested to see if the vpn connection is needed. Example -DC "tsdc"
	.PARAMETER VPNuri
		The connection URL and port. Example -VPNuri "vpn.ambitinsgroup.com:4433"
	.PARAMETER VPNuser
		The vpn enable user to be used. Example -VPNuser "vpnuser"
    .PARAMETER VPNpassword
		The vpn user's password to be used. Example -VPNpassword "s0m3Gr3@tPw"
	.PARAMETER VPNdomain
		The SSLVPN domain to be used, found in the sonicwall settings. Example -VPNdomain "LocalDomain"
	.EXAMPLE
		Connect-NetExtender -DC "TSDC" -VPNuri "vpn.ts.com:4433" -VPNuser "tsadmin" -VPNpassword "R@nD0m!" -VPNdomain "LocalDomain"
		This example connects to the client Test Site, if such a client were to exist.
#>
}

Function Update-WindowsApps {
	Write-Host "Updating Windows Apps"
		Start-Process ms-windows-store:
		Start-Sleep -Seconds 5
		(Get-WmiObject -Namespace "root\cimv2\mdm\dmmap" -Class "MDM_EnterpriseModernAppManagement_AppManagement01").UpdateScanMethod()
	Write-Host "Update Windows Apps initiated"
}

Function Add-WebShortcut{
	param
	(
		[string]$Label,
		[string]$Url
	)
	
	Write-Host "Adding a shortcut to $Label to the desktop"
	$Shell = New-Object -ComObject ("WScript.Shell")
	$URLFilePath = $env:Public + "\Desktop\" + $Label + ".url"
	$Favorite = $Shell.CreateShortcut($URLFilePath)
	$Favorite.TargetPath = $Url
	$Favorite.Save()
}

Function Add-IEShortcut{
	param
	(
		[string]$Label,
		[string]$Url
	)
	
	$TargetFile = "C:\Program Files\Internet Explorer\iexplore.exe" 
	$ShortcutFile = "$env:Public\Desktop\" + $Label + ".lnk"
	$WScriptShell = New-Object -ComObject WScript.Shell
	$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
	$Shortcut.TargetPath = $TargetFile
	$Shortcut.Arguments = $Url
	$Shortcut.Save()
}

Function Disable-FastStartup {
	Write-Host "Disable Windows Fast Startup"
		REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d "0" /f
		powercfg -h off
}

Function Set-DailyReboot {
	Write-Host "Schedule Daily Restart"
		$Action = New-ScheduledTaskAction -Execute 'shutdown.exe' -Argument '-f -r -t 0'
		$Trigger =New-ScheduledTaskTrigger -Daily -At 3am
		$Idle = New-ScheduledTaskSettingsSet -RunOnlyIfIdle -IdleDuration 00:30:00 -IdleWaitTimeout 02:00:00
		$User = "NT AUTHORITY\SYSTEM"
		Register-ScheduledTask -Action $action -Trigger $trigger -User $User -Settings $Idle -TaskName "Daily Restart" -Description "Daily restart"
}

Function Disable-ATGLocalExpiration {
	Write-Host "Set local ATGLocal account to never expire"
		Set-LocalUser -Name "ATGLocal" -PasswordNeverExpires $True
}

Function Install-WindowsUpdates {
	Write-Host "Install Windows Updates"
		Set-ExecutionPolicy Bypass -Scope Process -Force
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
		Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/Windows-Update/UpdateWindows.txt -UseBasicParsing | Invoke-Expression
	Write-Host "End of Install Windows Updates"
}

Function Install-DellUpdates {
	Write-Host "Dell  Updates"
		$Manufact = (Get-CimInstance -Class Win32_ComputerSystem).Manufacturer
		if( $Manufact -like "*Dell*")
		{
			[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
			Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/Dell-Command-Update/DCU_AUTO.txt -UseBasicParsing | Invoke-Expression
		} else { Write-Host This is not a Dell Computer}
	Write-Host "End of Dell Updates"
}

Function Set-AutoLogon ([String] $SiteCode) {
	Write-Host "Set autologon"
		#Registry path declaration
		$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
		$RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
		[String]$DefaultUsername = 'ATGLocal'
		[String]$DefaultPassword = $SiteCode + 'T3mpP@ss'
		#setting registry values
		Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String
		Set-ItemProperty $RegPath "DefaultUsername" -Value $DefaultUsername -type String
		Set-ItemProperty $RegPath "DefaultPassword" -Value $DefaultPassword -type String
		Set-ItemProperty $RegPath "AutoLogonCount" -Value "1" -type DWord
	Write-Host "End of Set autologon"
}

Function Set-RunOnceScript {
	param
	(
		[string]$Label,
		[string]$Script
	)
	Write-Host "Install After Reboot"
	Set-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name $Label -Value "PowerShell.exe -ExecutionPolicy Bypass -File $Script"
}

Function Join-Domain {
Write-Host "Join Domain"
	param
	(
		[string]$Domain,
		[string]$Username,
		[string]$Password
	)
	$Password = $Password | ConvertTo-SecureString -asPlainText -Force
	$Username = $Domain + "\" + $Username
	$credential = New-Object System.Management.Automation.PSCredential($Username,$Password)
	Add-Computer -DomainName $Domain -Credential $credential
}

Function Remove-ITS247InstallFolder {
	Write-Host "Cleaning up and Restarting Computer"
	PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "If (Test-Path C:\Ambitions\ITS247Agent){Remove-Item -LiteralPath 'C:\Ambitions\ITS247Agent' -Force -Recurse};Restart-Computer -Force"
	Stop-transcript
	Restart-Computer -Force
}

Function Rename-ClientComputer {
	Write-Host "Rename Computer"
		$title = 'Rename Computer'
		$msg   = 'Enter the client shortcode (e.g. AAIHB) or Dept code'
		$SerialNumber = (Get-WmiObject win32_bios).SerialNumber
		#Message box prompts onscreen for input
		[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
		$ClientCode = [Microsoft.VisualBasic.Interaction]::InputBox($msg, $title)
		Rename-Computer ($ClientCode + "-" + $SerialNumber) -Force
	Write-Host "End of Rename Computer"
}

Function Connect-O365 {
    $UserCredential = Get-Credential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    Import-PSSession $Session
	Write-Host '!!!REMEMBER!!! When you want to disconnect from Office 365, type in "Remove-PSSession $Session"'
}

Function Run-Win10Decrap {
	Write-Host "Windows 10 Decrapifier"
	$progressPreference = 'silentlyContinue'
	Set-ExecutionPolicy Bypass -Scope Process -Force
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
	Invoke-WebRequest https://raw.githubusercontent.com/AmbitionsTechnologyGroup/ATG-PS-Functions/master/Scripts/Win-10-DeCrapifier/Windows10Decrapifier.txt -UseBasicParsing | Invoke-Expression
}

# Print out functions from this file
Write-Host `n====================================================
Write-Host The below functions are now loaded and ready to use:
Write-Host ====================================================`n

Get-ChildItem function: | Where-Object { $_.Name -match "-" -and $_.Name -ne "Clear-Host" } | Sort-Object | Format-Wide -Column 3

Write-Host `n====================================================
Write-Host "Type: 'Help <function name> -Detailed' for more info"
Write-Host ====================================================`n
