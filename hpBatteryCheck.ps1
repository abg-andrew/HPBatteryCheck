if ($env:TEMP -eq $null) {
    $env:TEMP = Join-Path $env:SystemDrive 'temp'
  }
  $chocTempDir = Join-Path $env:TEMP "HPBatCheck"
  $tempDir = $chocTempDir
  if (![System.IO.Directory]::Exists($tempDir)) {[void][System.IO.Directory]::CreateDirectory($tempDir)}
  $file = Join-Path $tempDir "HP.BRCU.Installer.msi"


function Get-Downloader {
    param (
      [string]$url
     )
    
      $downloader = new-object System.Net.WebClient
    
      $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
      if ($defaultCreds -ne $null) {
        $downloader.Credentials = $defaultCreds
      }
    
      $ignoreProxy = $env:chocolateyIgnoreProxy
      if ($ignoreProxy -ne $null -and $ignoreProxy -eq 'true') {
        Write-Debug "Explicitly bypassing proxy due to user environment variable"
        $downloader.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
      } else {
        # check if a proxy is required
        $explicitProxy = $env:chocolateyProxyLocation
        $explicitProxyUser = $env:chocolateyProxyUser
        $explicitProxyPassword = $env:chocolateyProxyPassword
        if ($explicitProxy -ne $null -and $explicitProxy -ne '') {
          # explicit proxy
          $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
          if ($explicitProxyPassword -ne $null -and $explicitProxyPassword -ne '') {
            $passwd = ConvertTo-SecureString $explicitProxyPassword -AsPlainText -Force
            $proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
          }
    
          Write-Debug "Using explicit proxy server '$explicitProxy'."
          $downloader.Proxy = $proxy
    
        } elseif (!$downloader.Proxy.IsBypassed($url)) {
          # system proxy (pass through)
          $creds = $defaultCreds
          if ($creds -eq $null) {
            Write-Debug "Default credentials were null. Attempting backup method"
            $cred = get-credential
            $creds = $cred.GetNetworkCredential();
          }
    
          $proxyaddress = $downloader.Proxy.GetProxy($url).Authority
          Write-Debug "Using system proxy server '$proxyaddress'."
          $proxy = New-Object System.Net.WebProxy($proxyaddress)
          $proxy.Credentials = $creds
          $downloader.Proxy = $proxy
        }
      }
    
      return $downloader
    }

    function Download-File {
        param (
          [string]$url,
          [string]$file
         )
          #Write-Output "Downloading $url to $file"
          $downloader = Get-Downloader $url
        
          $downloader.DownloadFile($url, $file)
        }

$url = "https://batteryprogram687.ext.hp.com/Utility/HP.BRCU.Installer.msi"
$installedBCUPath = "$env:ProgramW6432\Hewlett-Packard\HP Battery Recall Utility\HPBRCU.exe"

Write-Output "Downloading Software"
gitDownload-File $url $file
$arguments = "/i $file /q"
Write-Output "Installing MSI..."
Start-Process -Wait msiexec -ArgumentList $arguments
Write-Output "MSI Installed"
Write-Output "Running Check..."
Start-Process -Wait $installedBCUPath
$result = [xml] (Get-Content .\*.xml)

Write-Output $result.HPNotebookBatteryValidationUtility.SystemInfo.PrimaryBatteryRecallStatus
Write-Output $result.HPNotebookBatteryValidationUtility.SystemInfo.SecondaryBatteryRecallStatus
