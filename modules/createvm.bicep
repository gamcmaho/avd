param location string
param vm_name string
param vm_size string
param vm_gallery_image_id string

@secure()
param adminUsername string
@secure()
param adminPassword string

resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' existing = {
  name: 'nic-${vm_name}'
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm_name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    storageProfile: {
      imageReference: {
        id: vm_gallery_image_id
      }
      osDisk: {
        osType: 'Windows'
        name: '${vm_name}_osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
    }
    osProfile: {
      computerName: vm_name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Client'
  }
}
