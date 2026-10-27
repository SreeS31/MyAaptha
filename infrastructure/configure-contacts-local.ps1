param([Parameter(Mandatory=$true)][ValidateSet('google','microsoft')][string]$Provider)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$directory=Join-Path $projectRoot '.tools/preview'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$file=Join-Path $directory 'contact-providers.dpapi'
$settings=@{}
if(Test-Path -LiteralPath $file){
    $protected=(Get-Content -LiteralPath $file -Raw).Trim() | ConvertTo-SecureString
    $decoded=[System.Net.NetworkCredential]::new('', $protected).Password | ConvertFrom-Json
    foreach($property in $decoded.PSObject.Properties){$settings[$property.Name]=$property.Value}
    $protected.Dispose()
}
$clientId=Read-Host 'OAuth application client ID'
if([string]::IsNullOrWhiteSpace($clientId)){throw 'Client ID is required.'}
$secret=Read-Host 'OAuth application client secret (hidden)' -AsSecureString
if($secret.Length -eq 0){$secret.Dispose();throw 'Client secret is required.'}
$settings[$Provider+'Id']=$clientId.Trim()
$settings[$Provider+'Secret']=[System.Net.NetworkCredential]::new('', $secret).Password
$secret.Dispose()
$protected=ConvertTo-SecureString -String ($settings | ConvertTo-Json -Compress) -AsPlainText -Force
$protected | ConvertFrom-SecureString | Set-Content -LiteralPath $file -Encoding UTF8
$protected.Dispose()
Write-Output "Provider configuration saved for this Windows user. Register http://localhost:8080/api/contact-organizer/oauth/callback/$Provider as the OAuth redirect URI, then restart the local preview."
