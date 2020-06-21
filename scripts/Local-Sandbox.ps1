cd $PSScriptRoot

. ".\Initialize.ps1"

$containername = "$($settings.name)-dev"
$name = Read-Host -Prompt "Enter name of container (enter for $containerName)"
if ($name) {
    $containername = $name
}

. ".\Install-NavContainerHelper.ps1" -buildEnv Local -navContainerHelperPath $userProfile.navContainerHelperPath
. ".\Create-Container.ps1"           -buildEnv Local -containerName $containerName -imageName $imageversion.containerImage -credential $credential -licensefile $licensefile -alwaysPull:($imageversion.alwaysPull)

UpdateLaunchJson -name "Local Sandbox ($containername)" -server "http://$containername"
