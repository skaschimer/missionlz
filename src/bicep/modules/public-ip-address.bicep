/*
Copyright (c) Microsoft Corporation.
Licensed under the MIT License.
*/

param availabilityZones array
param location string
param mlzTags object
param name string
param publicIpAllocationMethod string
param skuName string
param tags object

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: name
  location: location
  tags: union(tags[?'Microsoft.Network/publicIPAddresses'] ?? {}, mlzTags)
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod
  }
  zones: availabilityZones
}

output id string = publicIPAddress.id
