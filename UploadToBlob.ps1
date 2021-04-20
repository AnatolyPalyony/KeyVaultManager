<#
    .SYNOPSIS
        MicroUI Deployment handler
    .DESCRIPTION
        MicroUI Deployment handler will enable static web site feature, if disabled
        Extract frontend artifacts content and upload it to storage account web container
    .OUTPUTS
        [Log]
    .PARAMETER StorageAccountName
        StorageAccount Name
    .PARAMETER SasToken
        SAS Token for the blob
    .EXAMPLE
        Update-MicroFrontendToStaticWebSite`
            -StorageAccountName [SA_NAME] `
            -PathToArticact [PATH] `
            -SasToken [SasToken]
#>

Param
(
    [Parameter(Mandatory = $true)][System.String]$PathToArtifact,

    [Parameter(Mandatory = $true)][System.String]$StorageAccountName,

    [Parameter(Mandatory = $true)][System.String]$ResourceGroupName

)
function SetContentType {
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$FileName
    )

    PROCESS {
        $Extn = [IO.Path]::GetExtension($FileName)
        $ContentType = @{}
        switch ($Extn) {
            ".txt" { $ContentType = @{'ContentType' = 'text/plain' } }
            ".html" { $ContentType = @{'ContentType' = 'text/html' } }
            ".png" { $ContentType = @{'ContentType' = 'image/png' } }
            ".ico" { $ContentType = @{'ContentType' = 'image/x-icon' } }
            ".js" { $ContentType = @{'ContentType' = 'application/javascript' } }
            ".svg" { $ContentType = @{'ContentType' = 'image/svg+xml' } }
            ".woff" { $ContentType = @{'ContentType' = 'application/font-woff' } }
            ".json" { $ContentType = @{'ContentType' = 'application/json' } }
            Default { $ContentType = @{'ContentType' = '' } }
        }
        return $ContentType
    }
}

$Script:StorageAccountKeys = Get-AzStorageAccountKey `
    -ResourceGroupName $ResourceGroupName `
    -Name $StorageAccountName

$Script:StorageAccountContext = New-AzStorageContext `
    -StorageAccountKey $StorageAccountKeys.Value[0] `
    -StorageAccountName $StorageAccountName

$Script:SasToken = New-AzStorageAccountSASToken `
    -ExpiryTime (Get-Date).AddMinutes('10') `
    -ResourceType Service, Container, Object `
    -Context $StorageAccountContext `
    -StartTime (Get-Date) `
    -Protocol HttpsOnly `
    -Permission 'rw'`
    -Service Blob

$Script:StorageAccountBlobContext = New-AzStorageContext `
    -StorageAccountName $StorageAccountName `
    -SasToken $SasToken

$DefaultIndexDocument = 'index.html'
$DefaultErrorDocument = 'error.html'
Enable-AzStorageStaticWebsite `
    -ErrorDocument404Path $DefaultErrorDocument `
    -IndexDocument $DefaultIndexDocument `
    -Context $StorageAccountContext

Write-Output ('Deployment Storage Account Name: {0}' -f $StorageAccountName)

$artifactdir = Get-ChildItem $PathToArtifact -Filter 'MicroUI*' -Directory
$PathToArtifact = Join-Path -Path $PathToArtifact -ChildPath $artifactdir
Write-Output $PathToArtifact
$artifactdir = $PathToArtifact

foreach ($file in Get-ChildItem -Path $artifactdir  -File -Recurse) {
    $Blob = $file.FullName.Replace($artifactdir, '').Substring(1)
    $prop = $(SetContentType $file.FullName )
    Set-AzStorageBlobContent `
        -Blob $Blob `
        -Container '$web' `
        -File $file.FullName `
        -Properties $prop `
        -Context $StorageAccountContext `
        -Confirm:$false `
        -Force
}