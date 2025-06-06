targetScope = 'subscription'

// param locations object // This is only needed for Recovery Services which has been disabled for now.

var cloudSuffix = replace(replace(environment().resourceManager, 'https://management.', ''), '/', '')
var privateDnsZoneNames = union([
  'privatelink.agentsvc.azure-automation.${privateDnsZoneSuffixes_AzureAutomation[?environment().name] ?? cloudSuffix}' // Automation
  'privatelink.azure-automation.${privateDnsZoneSuffixes_AzureAutomation[?environment().name] ?? cloudSuffix}' // Automation
  'privatelink.${privateDnsZoneSuffixes_AzureWebSites[?environment().name] ?? 'appservice.${cloudSuffix}'}' // Web Apps & Function Apps
  'scm.privatelink.${privateDnsZoneSuffixes_AzureWebSites[?environment().name] ?? 'appservice.${cloudSuffix}'}' // Web Apps & Function Apps
  'privatelink.wvd.${privateDnsZoneSuffixes_AzureVirtualDesktop[?environment().name] ?? cloudSuffix}' // Azure Virtual Desktop
  'privatelink-global.wvd.${privateDnsZoneSuffixes_AzureVirtualDesktop[?environment().name] ?? cloudSuffix}' // Azure Virtual Desktop
  'privatelink.file.${environment().suffixes.storage}' // Azure Files
  'privatelink.queue.${environment().suffixes.storage}' // Azure Queues
  'privatelink.table.${environment().suffixes.storage}' // Azure Tables
  'privatelink.blob.${environment().suffixes.storage}' // Azure Blobs
  'privatelink${replace(environment().suffixes.keyvaultDns, 'vault', 'vaultcore')}' // Key Vault
  'privatelink.monitor.${privateDnsZoneSuffixes_Monitor[?environment().name] ?? cloudSuffix}' // Azure Monitor
  'privatelink.ods.opinsights.${privateDnsZoneSuffixes_Monitor[?environment().name] ?? cloudSuffix}' // Azure Monitor
  'privatelink.oms.opinsights.${privateDnsZoneSuffixes_Monitor[?environment().name] ?? cloudSuffix}' // Azure Monitor
  'privatelink${environment().suffixes.sqlServerHostname}'  // Azure SQL Server
], []) // privateDnsZoneNames_Backup) // Recovery Services has been disabled for now.

// The following variable is only needed for Recovery Services which has been disabled for now.
// var privateDnsZoneNames_Backup = [for location in items(locations): 'privatelink.${location.value.recoveryServicesGeo}.backup.windowsazure.${privateDnsZoneSuffixes_Backup[environment().name] ?? cloudSuffix}']

var privateDnsZoneSuffixes_AzureAutomation = {
  AzureCloud: 'net'
  AzureUSGovernment: 'us'
}
var privateDnsZoneSuffixes_AzureVirtualDesktop = {
  AzureCloud: 'microsoft.com'
  AzureUSGovernment: 'azure.us'
}
var privateDnsZoneSuffixes_AzureWebSites = {
  AzureCloud: 'azurewebsites.net'
  AzureUSGovernment: 'azurewebsites.us'
}

// The following variable is only needed for Recovery Services which has been disabled for now.
/* var privateDnsZoneSuffixes_Backup = {
  AzureCloud: 'com'
  AzureUSGovernment: 'us'
} */

var privateDnsZoneSuffixes_Monitor = {
  AzureCloud: 'azure.com'
  AzureUSGovernment: 'azure.us'
}

output names array = privateDnsZoneNames
