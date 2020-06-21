﻿Param(
    [ValidateSet('AzureDevOps','Local','AzureVM')]
    [Parameter(Mandatory=$false)]
    [string] $buildenv = "AzureDevOps",

    [Parameter(Mandatory=$false)]
    [string] $containerName = $ENV:CONTAINERNAME,

    [Parameter(Mandatory=$false)]
    [string] $imageName = $ENV:IMAGENAME,

    [Parameter(Mandatory=$false)]
    [pscredential] $credential = $null,

    [Parameter(Mandatory=$false)]
    [securestring] $licenseFile = $null,

    [bool] $alwaysPull = ($ENV:ALWAYSPULL -eq "True"),

    [bool] $reuseContainer = ($ENV:REUSECONTAINER -eq "True")
)

if (-not ($credential)) {
    $securePassword = try { $ENV:PASSWORD | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:PASSWORD -AsPlainText -Force }
    $credential = New-Object PSCredential -ArgumentList $ENV:USERNAME, $SecurePassword
}

if (-not ($licenseFile)) {
    $licenseFile = try { $ENV:LICENSEFILE | ConvertTo-SecureString } catch { ConvertTo-SecureString -String $ENV:LICENSEFILE -AsPlainText -Force }
}

Write-Host "Create $containerName from $imageName"

$parameters = @{
    "Accept_Eula" = $true
    "Accept_Outdated" = $true
}

if ($licenseFile) {
    $unsecureLicenseFile = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($licenseFile)))
    $parameters += @{
        "licenseFile" = $unsecureLicenseFile
    }
}

if ($buildenv -eq "Local") {
    $workspaceFolder = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
    $additionalParameters = @("--volume ""${workspaceFolder}:C:\Source""") 
}
elseif ($buildenv -eq "AzureDevOps") {
    $segments = "$PSScriptRoot".Split('\')
    $rootFolder = "$($segments[0])\$($segments[1])"
    $additionalParameters = @("--volume ""$($rootFolder):C:\Agent""")
    $parameters += @{ 
        "shortcuts" = "None"
    }
}
else {
    $workspaceFolder = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
    $additionalParameters = @("--volume ""C:\DEMO:C:\DEMO""")
    $parameters += @{ 
        "shortcuts" = "None"
        "useTraefik" = $true
        "myscripts" = @(@{ "AdditionalOutput.ps1" = "copy-item -Path 'C:\Run\*.vsix' -Destination 'C:\ProgramData\navcontainerhelper\Extensions\$containerName' -force" })
    }

}

$restoreDb = $reuseContainer -and (Test-BCContainer -containerName $containerName)
if ($restoreDb) {
    try {
        Restore-DatabasesInBCContainer -containerName $containerName -bakFolder $containerName
        Invoke-ScriptInBCContainer -containerName $containerName -scriptBlock { Param([pscredential]$credential)
            $user = Get-NAVServerUser -ServerInstance $ServerInstance | Where-Object { $_.Username -eq $credential.UserName }
            if ($user) {
                Write-Host "Setting Password for user: $($credential.UserName)"
                Set-NavServerUser -ServerInstance $ServerInstance -UserName $credential.UserName -Password $credential.Password
            }
            else {
                Write-Host "Creating user: $($credential.UserName)"
                New-NavServerUser -ServerInstance $ServerInstance -UserName $credential.UserName -Password $credential.Password
                New-NavServerUserPermissionSet -ServerInstance $ServerInstance -UserName $credential.UserName -PermissionSetId "SUPER"
            }
        } -argumentList $credential
    }
    catch {
        $restoreDb = $false
    }
}
if (!$restoreDb) {
    New-BCContainer @Parameters `
                    -doNotCheckHealth `
                    -updateHosts `
                    -useBestContainerOS `
                    -containerName $containerName `
                    -imageName $imageName `
                    -alwaysPull:$alwaysPull `
                    -auth "UserPassword" `
                    -Credential $credential `
                    -additionalParameters $additionalParameters `
                    -includeTestToolkit `
                    -includeTestLibrariesOnly `
                    -doNotUseRuntimePackages
    
    Backup-BCContainerDatabases -containerName $containerName -bakFolder $containerName
}
