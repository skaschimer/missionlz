/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

targetScope = 'subscription'

param arcGisProInstaller string = ''
param computeGalleryImageResourceId string = ''
param computeGalleryName string
param containerName string
param customizations array = []
param deploymentNameSuffix string = utcNow('yyMMddHHs')
param diskEncryptionSetResourceId string
param enableBuildAutomation bool = false
param excludeFromLatest bool = true
param hybridUseBenefit bool = false
param imageDefinitionName string
param imageMajorVersion int
param imageMinorVersion int
param imagePatchVersion int
param imageVirtualMachineName string
param installAccess bool = false
param installArcGisPro bool = false
param installExcel bool = false
param installOneDrive bool = false
param installOneNote bool = false
param installOutlook bool = false
param installPowerPoint bool = false
param installProject bool = false
param installPublisher bool = false
param installSkypeForBusiness bool = false
param installTeams bool = false
param installUpdates bool = false
param installVirtualDesktopOptimizationTool bool = false
param installVisio bool = false
param installWord bool = false
param keyVaultName string
param location string = deployment().location
param managementVirtualMachineName string
param marketplaceImageOffer string
param marketplaceImagePublisher string
param marketplaceImageSKU string
param mlzTags object = {}
param msrdcwebrtcsvcInstaller string = ''
param officeInstaller string = ''
param replicaCount int = 1
param resourceGroupName string
param runbookExecution bool = false
param sourceImageType string = 'AzureMarketplace'
param storageAccountResourceId string
param subnetResourceId string
param tags object = {}
param teamsInstaller string = ''
param updateService string = 'MU'
param userAssignedIdentityClientId string
param userAssignedIdentityPrincipalId string
param userAssignedIdentityResourceId string
param vcRedistInstaller string = ''
param vDOTInstaller string = ''
@secure()
param virtualMachineAdminPassword string = ''
@secure()
param virtualMachineAdminUsername string = ''
param virtualMachineSize string
param wsusServer string = ''

var autoImageVersion = '${imageMajorVersion}.${imageMinorVersion}.${imagePatchVersion}'
var storageAccountName = split(storageAccountResourceId, '/')[8]
var storageEndpoint = environment().suffixes.storage
var subscriptionId = subscription().subscriptionId

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing =
  if (runbookExecution) {
    name: keyVaultName
    scope: resourceGroup(subscriptionId, resourceGroupName)
  }

module managementVM 'managementVM.bicep' =
  if (!enableBuildAutomation) {
    name: 'management-vm-${deploymentNameSuffix}'
    scope: resourceGroup(subscriptionId, resourceGroupName)
    params: {
      diskEncryptionSetResourceId: diskEncryptionSetResourceId
      hybridUseBenefit: hybridUseBenefit
      location: location
      mlzTags: mlzTags
      subnetResourceId: subnetResourceId
      tags: tags
      userAssignedIdentityResourceId: userAssignedIdentityResourceId
      virtualMachineAdminPassword: virtualMachineAdminPassword
      virtualMachineAdminUsername: virtualMachineAdminUsername
      virtualMachineName: managementVirtualMachineName
      virtualMachineSize: virtualMachineSize
    }
  }

module virtualMachine 'virtualMachine.bicep' = {
  name: 'image-vm-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    // diskEncryptionSetResourceId: diskEncryptionSetResourceId
    location: location
    marketplaceImageOffer: marketplaceImageOffer
    marketplaceImagePublisher: marketplaceImagePublisher
    marketplaceImageSKU: marketplaceImageSKU
    mlzTags: mlzTags
    computeGalleryImageResourceId: computeGalleryImageResourceId
    sourceImageType: sourceImageType
    subnetResourceId: subnetResourceId
    tags: tags
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
    virtualMachineAdminPassword: runbookExecution
      ? keyVault.getSecret('VirtualMachineAdminPassword')
      : virtualMachineAdminPassword
    virtualMachineAdminUsername: runbookExecution
      ? keyVault.getSecret('VirtualMachineAdminUsername')
      : virtualMachineAdminUsername
    virtualMachineName: imageVirtualMachineName
    virtualMachineSize: virtualMachineSize
  }
  dependsOn: []
}

module addCustomizations 'customizations.bicep' = {
  name: 'customizations-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    arcGisProInstaller: arcGisProInstaller
    containerName: containerName
    customizations: customizations
    installAccess: installAccess
    installArcGisPro: installArcGisPro
    installExcel: installExcel
    installOneDrive: installOneDrive
    installOneNote: installOneNote
    installOutlook: installOutlook
    installPowerPoint: installPowerPoint
    installProject: installProject
    installPublisher: installPublisher
    installSkypeForBusiness: installSkypeForBusiness
    installTeams: installTeams
    installVirtualDesktopOptimizationTool: installVirtualDesktopOptimizationTool
    installVisio: installVisio
    installWord: installWord
    location: location
    mlzTags: mlzTags
    msrdcwebrtcsvcInstaller: msrdcwebrtcsvcInstaller
    officeInstaller: officeInstaller
    storageAccountName: storageAccountName
    storageEndpoint: storageEndpoint
    tags: tags
    teamsInstaller: teamsInstaller
    userAssignedIdentityObjectId: userAssignedIdentityPrincipalId
    vcRedistInstaller: vcRedistInstaller
    vDotInstaller: vDOTInstaller
    virtualMachineName: virtualMachine.outputs.name
  }
}

module restartVirtualMachine1 'restartVirtualMachine.bicep' = {
  name: 'restart-vm-1-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    imageVirtualMachineName: virtualMachine.outputs.name
    resourceGroupName: resourceGroupName
    location: location
    mlzTags: mlzTags
    tags: tags
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineName: enableBuildAutomation ? managementVirtualMachineName : managementVM.outputs.name
  }
  dependsOn: [
    addCustomizations
  ]
}

module microsoftUdpates 'microsoftUpdates.bicep' =
  if (installUpdates) {
    name: 'microsoft-updates-${deploymentNameSuffix}'
    scope: resourceGroup(subscriptionId, resourceGroupName)
    params: {
      imageVirtualMachineName: virtualMachine.outputs.name
      location: location
      mlzTags: mlzTags
      tags: tags
      updateService: updateService
      wsusServer: wsusServer
    }
    dependsOn: [
      restartVirtualMachine1
    ]
  }

module restartVirtualMachine2 'restartVirtualMachine.bicep' = if (installUpdates) {
  name: 'restart-vm-2-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    imageVirtualMachineName: virtualMachine.outputs.name
    resourceGroupName: resourceGroupName
    location: location
    mlzTags: mlzTags
    tags: tags
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineName: enableBuildAutomation ? managementVirtualMachineName : managementVM.outputs.name
  }
  dependsOn: [
    microsoftUdpates
  ]
}
module sysprepVirtualMachine 'sysprepVirtualMachine.bicep' = {
  name: 'sysprep-vm-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    location: location
    mlzTags: mlzTags
    tags: tags
    virtualMachineName: virtualMachine.outputs.name
  }
  dependsOn: [
    restartVirtualMachine1
    restartVirtualMachine2
  ]
}

module generalizeVirtualMachine 'generalizeVirtualMachine.bicep' = {
  name: 'generalize-vm-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    imageVirtualMachineName: virtualMachine.outputs.name
    resourceGroupName: resourceGroupName
    location: location
    mlzTags: mlzTags
    tags: tags
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineName: enableBuildAutomation ? managementVirtualMachineName : managementVM.outputs.name
  }
  dependsOn: [
    sysprepVirtualMachine
  ]
}

module imageVersion 'imageVersion.bicep' = {
  name: 'image-version-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    computeGalleryImageResourceId: computeGalleryImageResourceId
    computeGalleryName: computeGalleryName
    //diskEncryptionSetResourceId: diskEncryptionSetResourceId
    excludeFromLatest: excludeFromLatest
    imageDefinitionName: imageDefinitionName
    imageVersionNumber: autoImageVersion
    imageVirtualMachineResourceId: virtualMachine.outputs.resourceId
    location: location
    marketplaceImageOffer: marketplaceImageOffer
    marketplaceImagePublisher: marketplaceImagePublisher
    mlzTags: mlzTags
    replicaCount: replicaCount
    tags: tags
  }
  dependsOn: [
    generalizeVirtualMachine
  ]
}

module removeVirtualMachine 'removeVirtualMachine.bicep' = {
  name: 'remove-vm-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    enableBuildAutomation: enableBuildAutomation
    imageVirtualMachineName: virtualMachine.outputs.name
    location: location
    mlzTags: mlzTags
    tags: tags
    userAssignedIdentityClientId: userAssignedIdentityClientId
    virtualMachineName: enableBuildAutomation ? managementVirtualMachineName : managementVM.outputs.name
  }
  dependsOn: [
    imageVersion
  ]
}

output imageDefinitionResourceId string = imageVersion.outputs.imageDefinitionResourceId
