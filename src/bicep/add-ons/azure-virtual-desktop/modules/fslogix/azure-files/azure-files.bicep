param activeDirectorySolution string
param availability string
param azureFilesPrivateDnsZoneResourceId string
param delimiter string
param deploymentNameSuffix string
// param enableRecoveryServices bool
param encryptionUserAssignedIdentityResourceId string
param fileShares array
param fslogixShareSizeInGB int
param hostPoolResourceId string
param keyVaultUri string
param location string
param mlzTags object
param names object
// param recoveryServicesVaultName string
// param resourceGroupManagement string
param securityPrincipalObjectIds array
param storageCount int
param storageEncryptionKeyName string
param storageIndex int
param storageSku string
param subnetResourceId string
param tags object

var roleDefinitionId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor 
var smbMultiChannel = {
  multichannel: {
    enabled: true
  }
}
var smbSettings = {
  versions: 'SMB3.1.1;'
  authenticationMethods: 'NTLMv2;Kerberos;'
  kerberosTicketEncryption: 'AES-256;'
  channelEncryption: 'AES-128-GCM;AES-256-GCM;'
}
var storageAccountNamePrefix = uniqueString(names.storageAccount, resourceGroup().id)
var storageRedundancy = availability == 'availabilityZones' ? '_ZRS' : '_LRS'
var tagsPrivateEndpoints = union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Network/privateEndpoints'] ?? {}, mlzTags)
var tagsStorageAccounts = union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.Storage/storageAccounts'] ?? {}, mlzTags)
// var tagsRecoveryServicesVault = union({'cm-resource-parent': hostPoolResourceId}, tags[?'Microsoft.recoveryServices/vaults'] ?? {}, mlzTags)

resource storageAccounts 'Microsoft.Storage/storageAccounts@2022-09-01' = [for i in range(0, storageCount): {
  name: take('${storageAccountNamePrefix}${padLeft(i + storageIndex, 2, '0')}', 15)
  location: location
  tags: tagsStorageAccounts
  sku: {
    name: '${storageSku}${storageRedundancy}'
  }
  kind: storageSku == 'Standard' ? 'StorageV2' : 'FileStorage'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${encryptionUserAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'PrivateLink'
    allowSharedKeyAccess: true
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: activeDirectorySolution == 'MicrosoftEntraDomainServices' ? 'AADDS' : 'None'
    }
    defaultToOAuthAuthentication: false
    dnsEndpointType: 'Standard'
    encryption: {
      identity: {
        userAssignedIdentity: encryptionUserAssignedIdentityResourceId
      }
      requireInfrastructureEncryption: true
      keyvaultproperties: {
          keyvaulturi: keyVaultUri
          keyname: storageEncryptionKeyName
      }
      services: storageSku == 'Standard' ? {
        file: {
          keyType: 'Account'
          enabled: true
        }
        table: {
          keyType: 'Account'
          enabled: true
        }
        queue: {
            keyType: 'Account'
            enabled: true
        }
        blob: {
            keyType: 'Account'
            enabled: true
        }
      } : {
        file: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.KeyVault'
    }
    largeFileSharesState: storageSku == 'Standard' ? 'Enabled' : null
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }
}]

// Assigns the SMB Contributor role to the Storage Account so users can save their profiles to the file share using FSLogix
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, storageCount): {
  scope: storageAccounts[i]
  name: guid(securityPrincipalObjectIds[i], roleDefinitionId, storageAccounts[i].id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: securityPrincipalObjectIds[i]
  }
}]

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = [for i in range(0, storageCount): {
  parent: storageAccounts[i]
  name: 'default'
  properties: {
    protocolSettings: {
      smb: storageSku == 'Standard' ? smbSettings : union(smbSettings, smbMultiChannel)
    }
    shareDeleteRetentionPolicy: {
      enabled: false
    }
  }
}]

module shares 'shares.bicep' = [for i in range(0, storageCount): {
  name: 'deploy-file-shares-${i}-${deploymentNameSuffix}'
  params: {
    fileShares: fileShares
    fslogixShareSizeInGB: fslogixShareSizeInGB
    storageAccountName: storageAccounts[i].name
    storageSku: storageSku
  }
  dependsOn: [
    fileServices
    roleAssignment
  ]
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2023-04-01' = [for i in range(0, storageCount): {
  name: '${names.storageAccountFilePrivateEndpoint}${delimiter}fslogix${delimiter}${padLeft(i + storageIndex, 2, '0')}'
  location: location
  tags: tagsPrivateEndpoints
  properties: {
    customNetworkInterfaceName: '${names.storageAccountFileNetworkInterface}${delimiter}fslogix${delimiter}${padLeft(i + storageIndex, 2, '0')}'
    privateLinkServiceConnections: [
      {
        name: '${names.storageAccountFilePrivateEndpoint}${delimiter}fslogix${delimiter}${padLeft(i + storageIndex, 2, '0')}'
        properties: {
          privateLinkServiceId: storageAccounts[i].id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: subnetResourceId
    }
  }
}]

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-08-01' = [for i in range(0, storageCount): {
  parent: privateEndpoints[i]
  name: storageAccounts[i].name
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'ipconfig1'
        properties: {
          privateDnsZoneId: azureFilesPrivateDnsZoneResourceId
        }
      }
    ]
  }
  dependsOn: [
    storageAccounts
  ]
}]

// Deploys backup items for Azure Files
/* module recoveryServices 'recoveryServices.bicep' = if (enableRecoveryServices) {
  name: 'deploy-backup-${deploymentNameSuffix}'
  scope: resourceGroup(resourceGroupManagement)
  params: {
    deploymentNameSuffix: deploymentNameSuffix
    fileShares: fileShares
    location: location
    recoveryServicesVaultName: recoveryServicesVaultName
    resourceGroupStorage: resourceGroup().name
    storageAccountNamePrefix: storageAccountNamePrefix
    storageCount: storageCount
    storageIndex: storageIndex
    tagsRecoveryServicesVault: tagsRecoveryServicesVault
  }
} */

output storageAccountNamePrefix string = storageAccountNamePrefix
