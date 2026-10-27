# Run once from an administrator PowerShell if the phone cannot open port 4320.
# Only Node on this computer's current Wi-Fi subnet is allowed.
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell as administrator, then run this script again.'
}
if (-not (Get-NetFirewallRule -Name 'MyAaptha-Phone-Preview-4320' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'MyAaptha-Phone-Preview-4320' -DisplayName 'MyAaptha phone preview (local Wi-Fi only)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4320 -LocalAddress 192.168.1.5 -RemoteAddress 192.168.1.0/24 -InterfaceAlias 'Wi-Fi' -Profile Public,Private -Program 'C:\Program Files\nodejs\node.exe' | Out-Null
}
Write-Host 'Phone preview allowed from your local Wi-Fi subnet on port 4320.'
