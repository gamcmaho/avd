// Deploy:  az deployment group create -g <resource group name> --template-file main.bicep --parameters parameters.json
@secure()
param adminUsername string
@secure()
param adminPassword string
@secure()
param domainFQDN string

param location string
param vm_gallery_image_id string
param token_expiration_time string
param modules_url string
param vm_dc_name string
param vm_test_name string
param vm_rdsh_name string
param vm_size string
param vm_dc_nic_name string
param vm_test_nic_name string
param vm_rdsh_nic_name string
param bastion_name string
param bastion_pip_name string
param vnet_hub_name string
param vnet_avd_name string
param vnet_shared_name string
param azfw_policy_name string
param azfw_pip_name string
param azfw_name string
param avd_rt_name string
param shared_rt_name string
param workspace_name string
param hostpool_name string
param storage_account_name string
param dag_name string
param rag_name string
param private_dns_zone_name string
param vnet_hub_cidr string
param azfw_subnet_cidr string
param bastion_subnet_cidr string
param vnet_avd_cidr string
param avd_subnet_name string
param avd_subnet_cidr string
param vnet_shared_cidr string
param shared_subnet_name string
param shared_subnet_cidr string
param custom_dns_servers string
param domain_join_options int

var storage_pe_name = 'pe-${storage_account_name}'
var user_principal_name = '${adminUsername}@${domainFQDN}'

resource addrdsh 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  parent: vmrdsh
  name: 'Microsoft.PowerShell.DSC'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    settings: {
      modulesUrl: modules_url
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostpool.name
        registrationInfoToken: hostpool.properties.registrationInfo.token
        aadJoin: false
        UseAgentDownloadEndpoint: true
        aadJoinPreview: false
      }
    }
  }
  dependsOn: [
    domainjoinrdsh
  ]
}

resource vmrdsh 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm_rdsh_name
  location: location
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
        name: '${vm_rdsh_name}_osdisk'
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
      computerName: vm_rdsh_name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmrdshnic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Client'
  }
}

resource azfwpolicy 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: azfw_policy_name
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Off'
  }
}

resource netrulecollectiongroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  parent: azfwpolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'netRuleCollection1'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allowHttpHttpsOut'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              shared_subnet_cidr
              avd_subnet_cidr
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '*'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '80'
              '443'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'netRuleCollection2'
        priority: 300
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allowADDNStcp'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              avd_subnet_cidr
            ]
            sourceIpGroups: []
            destinationAddresses: [
              shared_subnet_cidr
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '135'
              '1024-65535'
              '389'
              '636'
              '3268-3269'
              '53'
              '88'
              '445'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'netRuleCollection3'
        priority: 400
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allowADDNSudp'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              avd_subnet_cidr
            ]
            sourceIpGroups: []
            destinationAddresses: [
              shared_subnet_cidr
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '389'
              '53'
              '88'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'netRuleCollection4'
        priority: 500
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allowDnsOut'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: [
              shared_subnet_cidr
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '*'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '53'
            ]
          }
        ]
      }
    ]
  }
}

resource azfw 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: azfw_name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Off'
    additionalProperties: {}
    ipConfigurations: [
      {
        name: '${azfw_name}Ipconf'
        properties: {
          publicIPAddress: {
            id: azfwpip.id
          }
          subnet: {
            id: '${vnethub.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    networkRuleCollections: []
    applicationRuleCollections: []
    natRuleCollections: []
    firewallPolicy: {
      id: azfwpolicy.id
    }
  }
  dependsOn: [
    netrulecollectiongroup
  ]
}

resource privatednszone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: private_dns_zone_name
  location: 'global'
  properties: {}
}

resource azfwpip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: azfw_pip_name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionpip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: bastion_pip_name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource avd_rt 'Microsoft.Network/routeTables@2022-01-01' = {
  name: avd_rt_name
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'override-default-system-route'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource shared_rt 'Microsoft.Network/routeTables@2022-01-01' = {
  name: shared_rt_name
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'override-default-system-route'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storage_account_name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource fileservice 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' existing = {
  parent: storageaccount
  name: 'default'
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  parent: fileservice
  name: 'profiles'
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120
    enabledProtocols: 'SMB'
  }
}

resource vmdc 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm_dc_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${vm_dc_name}_osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: vm_dc_name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmdcnic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource vmtest 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vm_test_name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm_size
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-datacenter-gensecond'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${vm_test_name}_osdisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: vm_test_name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmtestnic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource deployadds 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: '${vm_dc_name}/Microsoft.Powershell.DSC'
  dependsOn: [
    vmdc
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/gamcmaho/avd/raw/main/scripts/Deploy-DomainServices.zip'
      ConfigurationFunction: 'Deploy-DomainServices.ps1\\Deploy-DomainServices'
      Properties: {
        domainFQDN: domainFQDN
        adminCredential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:adminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        adminPassword: adminPassword
      }
    }
  }
}

resource domainjointest 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: '${vm_test_name}/JoinDomain'
  dependsOn: [
    vmtest
    deployadds
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainFQDN
      //ouPath: ouPath
      user: user_principal_name
      restart: true
      options: domain_join_options
    }
    protectedSettings: {
      password: adminPassword
    }
  }
}

resource domainjoinrdsh 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = {
  name: '${vm_rdsh_name}/JoinDomain'
  dependsOn: [
    vmrdsh
    deployadds
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainFQDN
      //ouPath: ouPath
      user: user_principal_name
      restart: true
      options: domain_join_options
    }
    protectedSettings: {
      password: adminPassword
    }
  }
}

resource vmrdshnic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: vm_rdsh_nic_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetavd.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource vmdcnic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: vm_dc_nic_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetshared.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource vmtestnic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: vm_test_nic_name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetavd.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

resource privatednszonerecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '${privatednszone.name}/${storageaccount.name}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: storagepe.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

resource avddefaultroute 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  parent: avd_rt
  name: 'override-default-system-route'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
    hasBgpOverride: false
  }
}

resource shareddefaultroute 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  parent: shared_rt
  name: 'override-default-system-route'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
    hasBgpOverride: false
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastion_name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: '${bastion_name}-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionpip.id
          }
          subnet: {
            id: vnethub.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource vnetlink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privatednszone.name}/vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetshared.id
    }
    registrationEnabled: false
  }
}

resource storagepe 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: storage_pe_name
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${storage_pe_name}-conn'
        properties: {
          privateLinkServiceId: storageaccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: vnetavd.properties.subnets[0].id
    }
  }
}


resource vnetavd 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnet_avd_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_avd_cidr
      ]
    }
    dhcpOptions: {
      dnsServers: [
        custom_dns_servers
      ]
    }
    subnets: [
      {
        name: avd_subnet_name
        properties: {
          addressPrefix: avd_subnet_cidr
          routeTable: {
            id: avd_rt.id
          }
        }
      }
    ]
  }
}

resource vnethub 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnet_hub_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_hub_cidr
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azfw_subnet_cidr
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastion_subnet_cidr
        }
      }
    ]
  }
}

resource vnetshared 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnet_shared_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_shared_cidr
      ]
    }
    subnets: [
      {
        name: shared_subnet_name
        properties: {
          addressPrefix: shared_subnet_cidr
          routeTable: {
            id: shared_rt.id
          }
        }
      }
    ]
  }
}

resource hubtoavdpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: '${vnethub.name}/hub-to-avd-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnetavd.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource avdtohubpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: '${vnetavd.name}/avd-to-hub-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnethub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubtoavdpeer
  ]
}

resource hubtosharedpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: '${vnethub.name}/hub-to-shared-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnetshared.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource sharedtohubpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-11-01' = {
  name: '${vnetshared.name}/shared-to-hub-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnethub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubtosharedpeer
  ]
}

resource hostpool'Microsoft.DesktopVirtualization/hostpools@2021-07-12' = {
  name: hostpool_name
  location: location
  properties: {
    hostPoolType: 'Pooled'
    customRdpProperty: 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;'
    maxSessionLimit: 5
    loadBalancerType: 'BreadthFirst'
    validationEnvironment: false
    preferredAppGroupType: 'Desktop'
    startVMOnConnect: false
    registrationInfo: {
      expirationTime: token_expiration_time
      token: null
      registrationTokenOperation: 'Update'
    }
  }
}

resource dag 'Microsoft.DesktopVirtualization/applicationgroups@2021-07-12' = {
  name: dag_name
  location: location
  kind: 'Desktop'
  properties: {
    hostPoolArmPath: hostpool.id
    friendlyName: 'Default Desktop'
    applicationGroupType: 'Desktop'
  }
}

resource rag 'Microsoft.DesktopVirtualization/applicationgroups@2021-07-12' = {
  name: rag_name
  location: location
  kind: 'RemoteApp'
  properties: {
    hostPoolArmPath: hostpool.id
    friendlyName: 'Default Remote App Group'
    applicationGroupType: 'RemoteApp'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' = {
  name: workspace_name
  location: location
  properties: {
    applicationGroupReferences: [
      dag.id
      rag.id
    ]
  }
}
