# KeyVaultManager

Before start Connect-AzAccount

# Usage

# List Secrets

.\KeyVaultManager.ps1 -KeyVault <YourVault> -ListSecrets $True

# Export secrets to json

.\KeyVaultManager.ps1 -KeyVault <YourVault> -ExportSecrets <FilePath>

# Import secrets from json

.\KeyVaultManager.ps1 -KeyVault <YourVault> -ImportSecrets <FilePath>

# Import secrets from json and disable old one

.\KeyVaultManager.ps1 -KeyVault <YourVault> -ImportSecrets <FilePath> -DisableOld $True

# Import secrets from json and add Description to tag

.\KeyVaultManager.ps1 -KeyVault <YourVault> -ImportSecrets <FilePath> -Description "32 chars description"
