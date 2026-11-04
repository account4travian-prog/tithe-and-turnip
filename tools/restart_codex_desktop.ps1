<#
Restarts the locally installed ChatGPT/Codex desktop app.

Run from an ordinary PowerShell window, not from a Codex task that you need to
keep open:

    .\tools\restart_codex_desktop.ps1 -Force

Without -Force, the script asks for confirmation. It closes the Codex desktop
processes, so active local tasks may be interrupted.
#>

[CmdletBinding()]
param(
	[switch]$Force,
	[int]$WaitSeconds = 3
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Force) {
	$answer = Read-Host 'Close Codex/ChatGPT desktop and restart it? Active Codex tasks may stop. [y/N]'
	if ($answer -notmatch '^(?i:y|yes)$') {
		Write-Host 'Restart cancelled.'
		exit 0
	}
}

$processNames = @('codex', 'codex-code-mode-host')
$processes = Get-Process -Name $processNames -ErrorAction SilentlyContinue
if ($null -ne $processes) {
	$processes | Stop-Process -Force
	Write-Host 'Closed Codex desktop processes.'
}
else {
	Write-Host 'No Codex desktop processes were running.'
}

Start-Sleep -Seconds $WaitSeconds

# The package-family name is stable across versioned WindowsApps install
# folders. shell:AppsFolder asks Windows to launch the registered desktop app
# instead of bypassing its package activation lifecycle.
$package = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop |
	Select-Object -First 1
if ($null -eq $package) {
	throw 'The OpenAI.Codex package is not installed for this Windows user.'
}

$appId = "$($package.PackageFamilyName)!App"
Start-Process -FilePath 'explorer.exe' -ArgumentList "shell:AppsFolder\$appId"
Write-Host "Requested launch for $appId."
