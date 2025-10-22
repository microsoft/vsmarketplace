@description('The username used to access the container registry hosting the deployable image.')
param containerRegistryUsername string

@description('The password associated with the containerRegistryUsername parameter.')
@secure()
param containerRegistryPassword string

@description('The tag (version) of the image to deploy.')
param imageTag string = '1.0.52'

@description('The name of the deployment, used to prefix resource names. Should only contain lowercase letters to avoid resource name restrictions.')
param resourceNamePrefix string = 'vscodeprivate'

@description('The Azure region to deploy to. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('The container registry hosting the deployable image.')
param containerRegistry string = 'mcr.microsoft.com'

@description('The name of the image in the container registry.')
param containerRepository string = 'vsmarketplace/vscode-private-marketplace'

@description('The name of the organization that owns the Private Marketplace for Visual Studio Code. This is used to identify the Private Marketplace in the UI.')
param organizationName string = ''

@description('The name of Azure DevOps organization this feed belongs to')
param artifactsOrganization string = ''

@description('The name of Azure DevOps project this feed belongs to.')
param artifactsProject string = ''

@description('The name of the Azure Artifacts feed. Both can be used interchangeably.')
param artifactsFeed string = ''

@description('Whether to enable file logging for the container app.')
param enableFileLogging bool = false

@description('Whether to enable console logging for the container app.')
param enableConsoleLogging bool = false

@description('The list of IP address or CIDR range strings that are allowed to access the container app.')
param ipAllowList array = []

@description('Whether to restrict the container app to only receive traffic from the virtual network.')
param vnetTrafficOnly bool = false

@description('The daily quota for the Log Analytics workspace in GB.')
param logAnalyticsDailyQuotaGb int = 1

param logAnalyticsWorkspaceName string = '${resourceNamePrefix}-la'
param applicationInsightsName string = '${resourceNamePrefix}-ai'
param containerAppsEnvironmentName string = '${resourceNamePrefix}-cae'
param containerAppName string = '${resourceNamePrefix}-ca'
param nsgName string = '${resourceNamePrefix}-nsg'
param vnetName string = '${resourceNamePrefix}-vnet'
param managedIdentityName string = '${resourceNamePrefix}-identity'
param storageAccountName string = 'default'

@description('Controls upstreaming to the Public Marketplace. Allowed values: None, Search, SearchAndAssets')
@allowed([
  'None'
  'Search'
  'SearchAndAssets'
])
param publicMarketplaceProxyMode string = 'SearchAndAssets'

@description('A list of feature flags to disable, each flag seperated by a comma. Only needed if the flag is provided by the Private Marketplace for Visual Studio Code team.')
param disabledFeatureFlags array = []

var featureFlagSkip = 100

var useArtifactsSource = !empty(artifactsOrganization)
var useFileSystemSource = !useArtifactsSource
var createStorageAccount = useFileSystemSource || enableFileLogging

var disabledFeatureFlagsIdsEnvironmentVars = [
  for (flag, i) in disabledFeatureFlags: {
    name: 'feature_management__feature_flags__${i+featureFlagSkip}__id'
    value: flag
  }
]
var disabledFeatureFlagsValuesEnvironmentVars = [
  for (flag, i) in disabledFeatureFlags: {
    name: 'feature_management__feature_flags__${i+featureFlagSkip}__enabled'
    value: false
  }
]
var disabledFeatureFlagsEnvironmentVars = concat(
  disabledFeatureFlagsIdsEnvironmentVars,
  disabledFeatureFlagsValuesEnvironmentVars
)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsDailyQuotaGb
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

var storageAccountSuffix = uniqueString(subscription().subscriptionId, resourceGroup().id, resourceNamePrefix)
var defaultStorageAccountName = '${replace(replace(resourceNamePrefix, '_', ''), '-', '')}${storageAccountSuffix}'
var resolvedStorageAccountName = storageAccountName == 'default'
  ? (length(defaultStorageAccountName) > 24 ? substring(defaultStorageAccountName, 0, 24) : defaultStorageAccountName)
  : storageAccountName

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = if (createStorageAccount) {
  name: resolvedStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowSharedKeyAccess: true // needed for SMB mounts
  }
  kind: 'StorageV2'
}

var logsShareName = 'logs'
var extensionsShareName = 'extensions'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (useArtifactsSource) {
  name: managedIdentityName
  location: location
}

var resolvedArtifactsClientId = useArtifactsSource ? userAssignedIdentity.properties.clientId : ''

resource logsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = if (enableFileLogging) {
  #disable-next-line use-parent-property
  name: '${storageAccount.name}/default/${logsShareName}'
  properties: {
    enabledProtocols: 'SMB'
  }
}

resource extensionsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = if (useFileSystemSource) {
  #disable-next-line use-parent-property
  name: '${storageAccount.name}/default/${extensionsShareName}'
  properties: {
    enabledProtocols: 'SMB'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-03-01' = if (vnetTrafficOnly) {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = if (vnetTrafficOnly) {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'container-apps'
        properties: {
          addressPrefix: '10.1.1.0/24'
          serviceEndpoints: [{ service: 'Microsoft.Storage.Global', locations: ['*'] }]
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = if (vnetTrafficOnly) {
  name: 'container-apps'
  parent: vnet
}

resource environment 'Microsoft.App/managedEnvironments@2024-10-02-preview' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    publicNetworkAccess: vnetTrafficOnly ? 'Disabled' : 'Enabled'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    vnetConfiguration: vnetTrafficOnly ? { infrastructureSubnetId: subnet.id, internal: true } : null
  }
}

resource logsStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = if (enableFileLogging) {
  parent: environment
  name: logsShareName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: logsShareName
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
    }
  }
}

resource extensionStorage 'Microsoft.App/managedEnvironments/storages@2023-05-01' = if (useFileSystemSource) {
  parent: environment
  name: extensionsShareName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: extensionsShareName
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadOnly'
    }
  }
}

var containerRegistryPasswordSecretName = 'registry-password'
var azureFilesMountPath = '/data/extensions'
var logsMountPath = '/data/logs'
var targetPort = 8080 // default for ASP.NET Core
var containerImage = '${containerRegistry}/${containerRepository}:${imageTag}'

resource containerApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: containerAppName
  location: location
  kind: 'containerapps'
  identity: useArtifactsSource
    ? {
        type: 'UserAssigned'
        userAssignedIdentities: {
          '${userAssignedIdentity.id}': {}
        }
      }
    : null
  properties: {
    environmentId: environment.id
    configuration: {
      secrets: [
        {
          name: containerRegistryPasswordSecretName
          value: containerRegistryPassword
        }
      ]
      registries: [
        {
          passwordSecretRef: containerRegistryPasswordSecretName
          server: containerRegistry
          username: containerRegistryUsername
        }
      ]
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        transport: 'Auto'
        allowInsecure: false
        targetPort: targetPort
        ipSecurityRestrictions: [
          for ip in ipAllowList: {
            action: 'Allow'
            ipAddressRange: ip
            name: 'Allow ${ip}'
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'vscode-private-marketplace'
          image: containerImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(
            disabledFeatureFlagsEnvironmentVars,
            [
              {
                name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
                value: applicationInsights.properties.ConnectionString
              }
            ],
            useFileSystemSource
              ? [
                  {
                    name: 'Marketplace__ExtensionSourceDirectory'
                    value: azureFilesMountPath
                  }
                ]
              : [],
            !empty(organizationName)
              ? [
                  {
                    name: 'Marketplace__OrganizationName'
                    value: organizationName
                  }
                ]
              : [],
            useArtifactsSource
              ? [
                  {
                    name: 'Marketplace__ArtifactsOrganization'
                    value: artifactsOrganization
                  }
                ]
              : [],
            !empty(artifactsProject)
              ? [
                  {
                    name: 'Marketplace__ArtifactsProject'
                    value: artifactsProject
                  }
                ]
              : [],
            !empty(artifactsFeed)
              ? [
                  {
                    name: 'Marketplace__ArtifactsFeed'
                    value: artifactsFeed
                  }
                ]
              : [],
            useArtifactsSource
              ? [
                  {
                    name: 'Marketplace__ArtifactsClientId'
                    value: resolvedArtifactsClientId
                  }
                ]
              : [],
            enableFileLogging
              ? [
                  {
                    name: 'Marketplace__LogsDirectory'
                    value: logsMountPath
                  }
                ]
              : [],
            enableConsoleLogging
              ? [
                  {
                    name: 'Marketplace__Logging__LogToConsole'
                    value: true
                  }
                ]
              : [],
            publicMarketplaceProxyMode != 'None'
              ? [
                  {
                    name: 'Marketplace__Upstreaming__Mode'
                    value: publicMarketplaceProxyMode
                  }
                ]
              : []
          )
          probes: [
            {
              type: 'Startup'

              httpGet: {
                path: '/health/alive' // successful HTTP request = startup is complete
                port: targetPort
                scheme: 'HTTP'
              }
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready' // all health checks (e.g. extension source refresh) pass = ready for requests
                port: targetPort
                scheme: 'HTTP'
              }
            }
          ]
          volumeMounts: concat(
            useFileSystemSource
              ? [
                  {
                    mountPath: azureFilesMountPath
                    volumeName: extensionStorage.name
                  }
                ]
              : [],
            enableFileLogging
              ? [
                  {
                    mountPath: logsMountPath
                    volumeName: logsStorage.name
                  }
                ]
              : []
          )
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: concat(
        useFileSystemSource
          ? [
              {
                name: extensionStorage.name
                storageName: extensionStorage.name
                storageType: 'AzureFile'
              }
            ]
          : [],
        enableFileLogging
          ? [
              {
                name: logsStorage.name
                storageName: logsStorage.name
                storageType: 'AzureFile'
              }
            ]
          : []
      )
    }
    workloadProfileName: 'Consumption'
  }
}

module privateDnsSetup 'private-dns-setup.bicep' = if (vnetTrafficOnly) {
  name: 'private-dns-${uniqueString(deployment().name)}'
  params: {
    privateDnsZoneName: environment.properties.defaultDomain
    recordName: split(containerApp.properties.configuration.ingress.fqdn, '.')[0]
    staticIp: environment.properties.staticIp
    vnetId: vnet.id
  }
}

output extensionSourceType string = useArtifactsSource ? 'Artifacts' : 'FileSystem'
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}/'
output storageAccountName string = createStorageAccount ? storageAccount.name : 'No storage account created'
output containerStaticIp string = environment.properties.staticIp
output clientId string = useArtifactsSource ? userAssignedIdentity.properties.clientId : 'No managed identity created'
