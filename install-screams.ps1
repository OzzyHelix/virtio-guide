  $currentDate = Get-Date
  
  Write-Host "Current Date: $currentDate";
  $newDate = Get-Date "2023-07-04 12:00:00";
  
  Write-Host "Setting date to: $newDate to circumvent cert issue";
  Set-Date $newDate;
  # ! Scream driver certificate expired on July 5th, to avoid issues while installing driver we set the clock to July 4th, install the driver
  # ! then revert back to the original date/time
  # ? Get Latest release from the github repo
  $gitRepo = "duncanthrax/scream";
  $latest = (Invoke-RestMethod -Method Get -Uri https://api.github.com/repos/$gitRepo/releases/latest | Select-Object -ExpandProperty tag_name);
  # ? Download latest release
  Invoke-Webrequest -Uri https://github.com/duncanthrax/scream/releases/download/$latest/Scream$latest.zip -Out "scream.zip";
  Expand-Archive scream.zip
  # ? Extract the certificate from the driver file
  # ! We need to import the certificate to TrustedPublisher so that we can install the driver unattended.
  $driverFile = 'scream\install\driver\x64\Scream.sys';
  # ? Extract Cert
  $cert = (Get-AuthenticodeSignature $driverFile).SignerCertificate;
  Export-Certificate -Cert $cert -FilePath $PWD\scream\scream.crt
  # ? Install Cert in Cert:\LocalMachine\TrustedPublisher
  Import-Certificate -FilePath $PWD\scream\scream.crt -CertStoreLocation Cert:\LocalMachine\TrustedPublisher
  # ! We need to remove the "pause" at the end of their batch script to make sure we can go ahead unattended.
  Set-Content -Path $PWD\scream\install\install-x64.bat -Value (get-content -Path $PWD\scream\install\install-x64.bat | Select-String -Pattern 'pause' -NotMatch)
  # ? Install the SCREAM WDDM driver
  cmd.exe /c $PWD\scream\install\install-x64.bat
  # ? Cleanup
  rmdir -Force -Recurse .\scream
  rm -Force .\scream.zip
  # ? Enable Audio SRV STARTUP
  Set-Service -Name audiosrv -StartupType Automatic;
  Set-Service -Name audiosrv -Status Running -PassThru;
  # ? Revert back to current date
  Set-Date $currentDate;