$certPath = Join-Path -Path $PSScriptRoot -ChildPath "OPENSSL.pfx"
$certPassword = ConvertTo-SecureString "Admin123@" -AsPlainText -Force

# Check if the certificate file exists
if (Test-Path $certPath) {
    # Write-Host "Certificate file found at: $certPath"

    # Install the certificate to the Trusted People store
    $cert = Import-PfxCertificate -FilePath $certPath -Password $certPassword -CertStoreLocation Cert:\LocalMachine\TrustedPeople

    if ($cert) {
        Write-Host "Certificate installed successfully!"
    } else {
        Write-Host "Failed to install the certificate."
    }
} else {
    Write-Host "Error: Certificate file not found at $certPath"
}
