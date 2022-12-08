param location string
param vm_name string
@secure()
param adminUsername string
@secure()
param adminPassword string
@secure()
param domainFQDN string

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vm_name
}

resource domainjointest 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: '${vm.name}/JoinDomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainFQDN
      //ouPath: ouPath
      user: adminUsername
      restart: true
      options: 3
    }
    protectedSettings: {
      password: adminPassword
    }
  }
}
