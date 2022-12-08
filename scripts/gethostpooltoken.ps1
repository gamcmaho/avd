[CmdletBinding()]
param (
  [string]
  $ResourceGroupName,

  [string]
  $HostPoolName
)

$token = Get-AzWvdHostPoolRegistrationToken -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName | Select-Object -ExpandProperty token
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs['token'] = $token