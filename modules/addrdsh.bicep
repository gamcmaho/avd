param location string
param vm_name string
param hostpool_name string
param hostpool_token string
param modules_url string

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vm_name
}

resource hostpool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' existing = {
  name: hostpool_name
}

resource addsessionhost 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: vm
  name: 'Microsoft.PowerShell.DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: modules_url
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostpool.name
        registrationInfoToken: hostpool_token
        aadJoin: true
      }
    }
  }
}
