#Requires -RunAsAdministrator

# Set up Event Log logging
$LogSrc = "UpdateRdpSsl"

# If Submit-Renewal actually renews do stuff
if ($cert = Submit-Renewal) {
   try {
      # Grab Current Cert
      $CurrentCert = Get-CimInstance `
         -Namespace root\cimv2\TerminalServices `
         -ClassName Win32_TSGeneralSetting `
         -Filter "TerminalName='RDP-Tcp'"

      $CurrentThumbprint = $CurrentCert.SSLCertificateSHA1Hash
      $NewThumbprint     = $cert.Thumbprint

      # Error if new Thumbprint is equal to the old one. How would this even happen
      if ($CurrentThumbprint -eq $NewThumbprint) {
         Write-EventLog `
            -LogName Application `
            -Source $LogSrc `
            -EventId 2 `
            -EntryType Warning `
            -Message "New Certificate Thumbprint matches existing thumbprint. ($CurrentThumbprint ?= $NewThumbprint)"
      }

      # Update Binding
      Set-CimInstance `
         -InputObject $CurrentCert `
         -Property @{ SSLCertificateSHA1Hash = $NewThumbprint}

      Restart-Service -Name TermService -Force

      Write-EventLog `
         -LogName Application `
         -Source $LogSrc `
         -EventId 0 `
         -EntryType Information `
         -Message "RDP certificate updated. Old: $CurrentThumbprint | New: $NewThumbprint | Expires: $($cert.NotAfter)"

   }
   catch {
      Write-EventLog `
         -LogName Application `
         -Source $LogSrc `
         -EventId 3 `
         -EntryType Error `
         -Message "RDP cert bind failed: $_"
    throw
   }
} else {
   Write-EventLog `
         -LogName Application `
         -Source $LogSrc `
         -EventId 1 `
         -EntryType Information `
         -Message "RDP cert was not updated."
}