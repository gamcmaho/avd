param location string
param hostpool_name string

// Desktop Virtualization Contributor = '082f0a83-3be5-4ba1-904c-961cca79b387'
var uamiRbacRoleDefinitionId = '082f0a83-3be5-4ba1-904c-961cca79b387'
var uamiRbacAssignmentName = guid(resourceGroup().id)

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'uamigethostpooltoken'
  location: location
}

resource roledefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: uamiRbacRoleDefinitionId
  scope: subscription()
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: uamiRbacAssignmentName
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roledefinition.id
  }
}

resource deploymentscript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  dependsOn: [
    roleassignment
  ]
  name: 'gethostpooltokendeploymentscript'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '9.0'
    retentionInterval: 'PT2H'
    scriptContent: loadTextContent('../scripts/gethostpooltoken.ps1')
    arguments: '-ResourceGroupName \'${resourceGroup().name}\' -HostPoolName \'${hostpool_name}\''
    cleanupPreference: 'OnSuccess'
    timeout: 'PT1H'
  }
}

output token string = deploymentscript.properties.outputs.token
