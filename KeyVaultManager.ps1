Param (
    [parameter(Mandatory = $true )][string]$KeyVault = $(throw "KeyVault parameter is required."),
    [Parameter(Mandatory = $false)][System.IO.FileInfo]$ExportSecrets, # = $( Read-Host "Specify FilePath please" )
    [Parameter(Mandatory = $false)][ValidateScript({if( -Not ($_ | Test-Path) ){throw "File or folder does not exist"}
                    return $true})][System.IO.FileInfo]$ImportSecrets, # = $( Read-Host "Specify FilePath please" )
    [Parameter(Mandatory = $false)][bool]$DisableOld = $false ,
    [Parameter(Mandatory = $false)][bool]$ListSecrets = $false,
    [Parameter(Mandatory = $false)][ValidateLength(0, 32)][string]$Description
)

Function ExportSecrets {
    Param(
        [parameter(Mandatory = $true)]
        [string] $KeyVaultName, 
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo] $FileName
    );
    $Fullpath = Resolve-Path -Path $FileName.Directory
    Write-Host "Exporting to $Fullpath"
    if (!(Test-Path -Path $Fullpath -PathType Container )) {
        Write-Host "Folder Not Found"
        Write-Host "Check your filepath and try again please!"
        exit
    }
    Write-Host "Exporting to $FileName"
    $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName 
    $keys = @{}
    foreach ($secret in $secrets) {
        $secretName = $secret.name
        if ( $secret.Enabled ) {
            $keyvalue = (Get-AzKeyVaultSecret -VaultName $keyvaultName -name $secretName -AsPlainText)         
            $keys.Add("$secretName", "$keyvalue")
        }
        else {
            Write-Warning $secret.name 
            Write-Host "Has been disabled. skipping"
        }           
    }
    # $keys.GetEnumerator() |
    #   Select-Object -Property Key, Value | Export-Csv -NoTypeInformation -Path $FileName -Force

     $jsonname = ([String]$FileName).Replace(".csv",".json")
     $jsonobject = [PSCustomObject]$keys
     $jsonobject | ConvertTo-Json -Depth 5 | Out-File $jsonname
    
}
Function ImportSecrets {
    Param(
        [parameter(Mandatory = $true)]
        [string] $KeyVaultName, 
        [parameter(Mandatory = $true)]
        [System.IO.FileInfo] $FileName,
        [parameter(Mandatory = $false)]
        [string] $Description
    );
    
    if (!(Test-Path -Path $FileName)) {
        Write-Host "File Not Found"
        Write-Host "Check your filepath and try again please!"
        exit
    }
    else {
    

        if ($DisableOld) {
            Write-Host "Disabling secrets in $KeyVaultName"
            DisableSecrets -KeyVaultName $KeyVaultName
        }

    
        Write-Host "Importing from $FileName"
        $Expires = (Get-Date).AddYears(2).ToUniversalTime()
        $NBF = (Get-Date).ToUniversalTime()
        $ContentType = 'txt'
        if ($Description.Length -gt 0) {
            Write-Host $Description
            $Tags = @{ 'Priority' = 'medium'; 'Department' = 'true'; 'Source' = $FileName; 'Description' = $Description }
        }
        else {
            $Tags = @{ 'Priority' = 'medium'; 'Department' = 'true'; 'Source' = $FileName; 'Description' = '' }    
        }

        <#  Import-csv $FileName | ForEach-Object {
            $tkey = $_.Key
            $tval = $_.Value
            $secret = ConvertTo-SecureString -string $tval  -asplaintext -force
            Start-ThreadJob -ScriptBlock {
                Set-AzKeyVaultSecret -vaultname $Using:KeyVaultName -name $Using:tkey -SecretValue $Using:secret -ContentType $Using:ContentType -Expires $Using:Expires -NotBefore $Using:NBF -Tags $Using:Tags
            }
        } #>

        $json = Get-Content $FileName | Out-String | ConvertFrom-Json -AsHashtable
 
        foreach ($v in $json.GetEnumerator()) {
    
            $tkey = $v.Name
            $tval = $v.Value
            $secret = ConvertTo-SecureString -string $tval  -asplaintext -force
            Start-ThreadJob -ScriptBlock {
                Set-AzKeyVaultSecret -vaultname $Using:KeyVaultName -name $Using:tkey -SecretValue $Using:secret -ContentType $Using:ContentType -Expires $Using:Expires -NotBefore $Using:NBF -Tags $Using:Tags
            }
        }
        Measure-Command -Expression { Get-Job | Wait-Job } 
    }
}
Function DisableSecrets {
    Param(
        [parameter(Mandatory = $true)]
        [string] $KeyVaultName
    );
    $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName 
    foreach ($secret in $secrets) {
        Start-ThreadJob -ScriptBlock {
            $tsecret = $Using:secret
            $tsecretName = $tsecret.Name
            
            if ( $tsecret.Enabled ) {
                Write-Host "Disabling" $tsecretName
                
                $keyvalue = ConvertTo-SecureString -String (Get-AzKeyVaultSecret -VaultName $Using:KeyVaultName -name $tsecretName -AsPlainText) -AsPlainText -Force
                Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $tsecretName -SecretValue $keyvalue -Disable
            }
            else {
                 
                Write-Warning $tsecretName 
                Write-Host "Has been already disabled. skipping"
            }      
        }
    }
    Measure-Command -Expression { Get-Job | Wait-Job } 

}
Function ListSecrets {
    Param(
        [parameter(Mandatory = $true)]
        [string] $KeyVaultName
    );
    
    $secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName 
    $keys = @{}
    foreach ($secret in $secrets) {
        $secretName = $secret.name
       
        if ( $secret.Enabled ) {
            $keyvalue = (Get-AzKeyVaultSecret -VaultName $keyvaultName -name $secretName -AsPlainText)         
            $keys.Add("$secretName", "$keyvalue")
        }
        else {
            Write-Warning $secret.name 
            Write-Host "Has been disabled. skipping"
        }       
    }
    $str = $keys  | Out-String
    Write-Host $str -ForegroundColor Red
}

if ($ListSecrets) {
    ListSecrets -KeyVaultName $KeyVault
}
elseif ($ExportSecrets) {
    ExportSecrets -KeyVaultName $KeyVault -FileName $ExportSecrets 
}
elseif ($ImportSecrets) {
    ImportSecrets -KeyVaultName $KeyVault -FileName $ImportSecrets -Description $Description
}
else {
    Write-Host "Use with parameter please."
    Write-Host " -Keyvaut <KeyVaultName> -ListSecrets $true"
}
