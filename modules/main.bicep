param michalTestTags object = {tag1: 'testing pipelines'}

var resourceGroupLocation = resourceGroup().location
var appServicePlanNamePrefix = 'pipeline-bicep-test'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${appServicePlanNamePrefix}-asp'
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
  name: '${appServicePlanNamePrefix}-webapp'
  location: resourceGroupLocation
  properties: {
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
  kind: 'linux'
  tags: michalTestTags
}

output appServiceAppHostName string = webapp.properties.defaultHostName
