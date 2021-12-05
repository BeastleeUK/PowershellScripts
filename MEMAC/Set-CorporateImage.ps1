<#
.SYNOPSIS
	Change Lock Screen and Desktop Background in Windows 10 Pro.
.DESCRIPTION
	This script allows you to change logon screen and desktop background in Windows 10 Professional using GPO startup script.
.PARAMETER LockScreenFile (Optional)
	Path to the Lock Screen image to copy locally in computer.
    Example: "LockScreen.jpg"
.PARAMETER BackgroundFile (Optional)
	Path to the Desktop Background image to copy locally in computer.
    Example: "BackgroundScreen.jpg"
.PARAMETER LogPath (Optional)
    Path where save log file. If it's not specified no log is recorded.
.EXAMPLE
    Set Lock Screen and Desktop Wallpaper:
    Set-CoporateImage -LockScreenFile "LockScreen.jpg" -BackgroundFile "BackgroundScreen.jpg"
.EXAMPLE
    Set Lock Screen only:
    Set-CoporateImage -LockScreenFile "LockScreen.jpg"
.EXAMPLE
	Set Desktop Wallpaper only:
    Set-CoporateImage -BackgroundFile "BackgroundScreen.jpg"
.NOTES 
	Author: Juan Granados 
    Date:   September 2018
    
    Modified by:    Lee Eastham
    Date:           April 2020
    Reason:         Made to work for company requirements
#>

Param(
		[Parameter(Mandatory=$false,Position=0)] 
		[ValidateNotNullOrEmpty()]
		[string]$LockScreenFile,
        [Parameter(Mandatory=$false,Position=1)] 
		[ValidateNotNullOrEmpty()]
		[string]$BackgroundFile
	)


#Requires -RunAsAdministrator
#We need to run under 64bit process to write to correct regkey
if (-not ([Environment]::Is64BitProcess)) {
    write-warning "Y'arg Matey, we're off to 64-bit land....."
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }else{
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }
exit $lastexitcode
}

Function ConvertHash-ToBase64 #Pass a file path to get the equivalent Base64 Hash
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Path')]
        [string]$FilePath,

        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Algorithm = "MD5"
    )

    Begin
    {
        #Check if file path exists
        If (!(Test-Path -Path $FilePath)) {
            Write-Error "Path $FilePath does not exist or is not accessible"
            Exit
        }
    }

    Process 
    {

        #Get hash of chosen file
        $Hash = (Get-FileHash -Path $FilePath -Algorithm $Algorithm).hash

        $HashBytes = @()
        #Convert to Formatted Byte String      
        for ($i = 0 ; $i -lt ($Hash.Length); $i += 2) {
            $HashBytes += "0x" + $Hash.Substring($i,2)
        }


        #Base64 Encode
        $Hash = [System.Convert]::ToBase64String($HashBytes)
    }

    End
    {
        Return $Hash
    }
}


$progresspreference = 'silentlyContinue'

$LogPath = "$env:SystemRoot\Logs\<COMPANYNAME>\Set-CorporateImage.log"
Start-Transcript -Path $LogPath | Out-Null

$AzureStorageURL = "https://<BLOBURL>"
$ErrorActionPreference = "Stop"

$RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"

$CompKeyPath = "HKLM:\SOFTWARE\<COMPANYNAME>"

$DesktopPath = "DesktopImagePath"
$DesktopStatus = "DesktopImageStatus"
$DesktopUrl = "DesktopImageUrl"
$DesktopSource = "$AzureStorageURL/Desktops/$BackgroundFile"
$LockScreenPath = "LockScreenImagePath"
$LockScreenStatus = "LockScreenImageStatus"
$LockScreenUrl = "LockScreenImageUrl"
$LockScreenSource = "$AzureStorageURL/LockScreens/$LockScreenFile"

$StatusValue = "1"
$DesktopImageValue = "$($env:SystemRoot)\DesktopBackground.png"
$LockScreenImageValue = "$($env:SystemRoot)\LockScreenBackground.png"

if (!$LockScreenFile -and !$BackgroundFile) 
{
    Write-Host "Either LockScreenFile or BackgroundFile must has a value."
}
else 
{
    if(!(Test-Path $RegKeyPath)) {
        Write-Host "Creating registry path $($RegKeyPath)."
        New-Item -Path $RegKeyPath -Force | Out-Null
    }
    if ($LockScreenFile) {
        $progresspreference = 'silentlyContinue'
        Invoke-WebRequest -Uri $LockScreenSource -OutFile $LockScreenImageValue
        $progresspreference = 'Continue'
        $LockScreenHash = (ConvertHash-ToBase64 -Path $LockScreenImageValue)
        Write-Host "Creating registry entries for Lock Screen"
        New-ItemProperty -Path $RegKeyPath -Name $LockScreenStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path $RegKeyPath -Name $LockScreenPath -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path $RegKeyPath -Name $LockScreenUrl -Value $LockScreenImageValue -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path $CompKeyPath -Name "Lock Screen Background Hash" -Value $LockScreenHash -PropertyType STRING -Force | Out-Null
    }
    if ($BackgroundFile) {
        $progresspreference = 'silentlyContinue'
        Invoke-WebRequest -Uri $DesktopSource -OutFile $DesktopImageValue
        $progresspreference = 'Continue'
        $DesktopHash = (ConvertHash-ToBase64 -Path $DesktopImageValue)
        Write-Host "Creating registry entries for Desktop Background"
        New-ItemProperty -Path $RegKeyPath -Name $DesktopStatus -Value $StatusValue -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path $RegKeyPath -Name $DesktopPath -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path $RegKeyPath -Name $DesktopUrl -Value $DesktopImageValue -PropertyType STRING -Force | Out-Null
        New-ItemProperty -Path $CompKeyPath -Name "Desktop Background Hash" -Value $DesktopHash -PropertyType STRING -Force | Out-Null
    }
}

if (-not [string]::IsNullOrWhiteSpace($LogPath)){Stop-Transcript}