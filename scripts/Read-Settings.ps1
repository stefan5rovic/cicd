Param(
    [ValidateSet('AzureDevOps','Local','AzureVM')]
    [Parameter(Mandatory=$false)]
    [string] $buildEnv = "AzureDevOps",

    [Parameter(Mandatory=$false)]
    [string] $version = $ENV:VERSION,

    [Parameter(Mandatory=$false)]
    [string] $buildProjectFolder = $ENV:BUILD_REPOSITORY_LOCALPATH,

    [Parameter(Mandatory=$false)]
    [string] $appVersion = ""
)

if ($appVersion) {
    write-host "##vso[build.updatebuildnumber]$appVersion"
}

$settings = (Get-Content (Join-Path $buildProjectFolder "scripts\settings.json") | ConvertFrom-Json)
if ("$version" -eq "")  {
    $version = $settings.versions[0].version
    Write-Host "Version not defined, using $version"
}

$containerName = "build"

$property = $settings.PSObject.Properties.Match('containerName')
if ($property.Value) {
    $containerName = $property.Value
}

$property = $settings.PSObject.Properties.Match('navContainerHelperVersion')
if ($property.Value) {
    $navContainerHelperVersion = $property.Value
    Write-Host "Set navContainerHelperVersion = $navContainerHelperVersion"
    Write-Host "##vso[task.setvariable variable=navContainerHelperVersion]$navContainerHelperVersion"
}

$appFolders = $settings.appFolders
Write-Host "Set appFolders = $appFolders"
Write-Host "##vso[task.setvariable variable=appFolders]$appFolders"

$testFolders = $settings.testFolders
Write-Host "Set testFolders = $testFolders"
Write-Host "##vso[task.setvariable variable=testFolders]$testFolders"

$imageversion = $settings.versions | Where-Object { $_.version -eq $version }
if ($imageversion) {
    Write-Host "Set imageName = $($imageVersion.containerImage)"
    Write-Host "##vso[task.setvariable variable=imageName]$($imageVersion.containerImage)"
    "alwaysPull","reuseContainer" | ForEach-Object {
        $property = $imageVersion.PSObject.Properties.Match($_)
        if ($property.Value) {
            $propertyValue = $property.Value
        }
        else {
            $propertyValue = $false
        }
        Write-Host "Set $_ = $propertyValue"
        Write-Host "##vso[task.setvariable variable=$_]$propertyValue"
    }
    if ($imageVersion.PSObject.Properties.Match("containerName").Value) {
        $containerName = $imageversion.containerName
    }
}
else {
    throw "Unknown version: $version"
}

$containerName = "$($ENV:AGENT_NAME.Replace(' ',''))-$containerName"
Write-Host "Set containerName = $containerName"
Write-Host "##vso[task.setvariable variable=containerName]$containerName"
