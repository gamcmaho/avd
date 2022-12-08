param location string
param vnet_name string
param vm_name string

resource vnet 'Microsoft.Network/virtualNetworks@2020-11-01' existing = {
  name: vnet_name
}

resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: 'nic-${vm_name}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}
