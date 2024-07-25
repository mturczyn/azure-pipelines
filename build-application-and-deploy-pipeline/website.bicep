param environmentType string
param michalTestTags object = {tag1: 'testing pipelines'}

var resourceGroupLocation = resourceGroup().location
var resourceNamePrefix = 'pipeline-envs-learn-${toLower(environmentType)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${resourceNamePrefix}-asp'
  location: resourceGroupLocation
  sku: {
    name: 'F1'
    tier: 'Free'
    size: 'F1'
    capacity: 1
  }
  kind: 'linux'
  tags: michalTestTags
}

resource webapp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${resourceNamePrefix}-webapp'
  location: resourceGroupLocation
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
  kind: 'linux'
  tags: michalTestTags
}

output appServiceAppHostName string = webapp.properties.defaultHostName
