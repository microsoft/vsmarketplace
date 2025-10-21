@description('The username used to access the container registry hosting the deployable image.')
param containerRegistryUsername string

@description('The password associated with the containerRegistryUsername parameter.')
@secure()
param containerRegistryPassword string

@description('The tag (version) of the image to deploy.')
param imageTag string = '1.1.20-main.30616245'

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

@description('The VM size for AKS nodes.')
param aksNodeVmSize string = 'Standard_D2s_v3'

@description('The minimum number of nodes for the AKS cluster.')
param aksNodeCountMin int = 1

@description('The maximum number of nodes for the AKS cluster.')
param aksNodeCountMax int = 3

param logAnalyticsWorkspaceName string = '${resourceNamePrefix}-la'
param applicationInsightsName string = '${resourceNamePrefix}-ai'
param aksClusterName string = '${resourceNamePrefix}-aks'
param nsgName string = '${resourceNamePrefix}-nsg'
param vnetName string = '${resourceNamePrefix}-vnet'
param managedIdentityName string = '${resourceNamePrefix}-identity'
param storageAccountName string = 'default'
param publicIpName string = '${resourceNamePrefix}-pip'

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

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
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

// Storage account configuration for Kubernetes mounting

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
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
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.1.1.0/24'
          serviceEndpoints: [{ service: 'Microsoft.Storage.Global', locations: ['*'] }]
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'aks-subnet'
  parent: vnet
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = if (!vnetTrafficOnly) {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    kubernetesVersion: '1.33.0'
    dnsPrefix: aksClusterName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: aksNodeCountMin
        vmSize: aksNodeVmSize
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: true
        minCount: aksNodeCountMin
        maxCount: aksNodeCountMax
        vnetSubnetID: subnet.id
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
      outboundType: vnetTrafficOnly ? 'userDefinedRouting' : 'loadBalancer'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
    }
    storageProfile: {
      fileCSIDriver: {
        enabled: true
      }
      diskCSIDriver: {
        enabled: true
      }
      snapshotController: {
        enabled: true
      }
    }
  }
}

// Grant AKS cluster access to pull images from ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, containerRegistry, 'acrpull')
  scope: resourceGroup()
  properties: {
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    ) // AcrPull role
  }
}

// Grant managed identity access to storage account if needed
resource storageContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (createStorageAccount) {
  name: guid(userAssignedIdentity.id, storageAccount.id, 'storage-contributor')
  scope: storageAccount
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    ) // Storage Blob Data Contributor
  }
}

// Grant managed identity AKS Cluster User access for deployment script
resource managedIdentityAksUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(userAssignedIdentity.id, aksCluster.id, 'aks-cluster-user')
  scope: aksCluster
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
    ) // Azure Kubernetes Service Cluster User Role
  }
}

// Deployment script to configure AKS with kubectl
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${resourceNamePrefix}-aks-deploy'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT30M'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'AKS_NAME'
        value: aksClusterName
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
      {
        name: 'CONTAINER_IMAGE'
        value: '${containerRegistry}/${containerRepository}:${imageTag}'
      }
      {
        name: 'REGISTRY_USERNAME'
        value: containerRegistryUsername
      }
      {
        name: 'REGISTRY_PASSWORD'
        secureValue: containerRegistryPassword
      }
      {
        name: 'REGISTRY_SERVER'
        value: containerRegistry
      }
      {
        name: 'APP_INSIGHTS_CONNECTION'
        value: applicationInsights.properties.ConnectionString
      }
      {
        name: 'NAMESPACE'
        value: 'vscode-private-marketplace'
      }
      {
        name: 'MARKETPLACE_PROXY_MODE'
        value: publicMarketplaceProxyMode
      }
      {
        name: 'MARKETPLACE_ORGANIZATION_NAME'
        value: organizationName
      }
      {
        name: 'MARKETPLACE_ARTIFACTS_PROJECT_NAME'
        value: artifactsProject
      }
      {
        name: 'MARKETPLACE_ARTIFACTS_FEED'
        value: artifactsFeed
      }
      {
        name: 'MARKETPLACE_ARTIFACTS_ORGANIZATION'
        value: artifactsOrganization
      }
      {
        name: 'MARKETPLACE_CLIENT_ID'
        value: resolvedArtifactsClientId
      }
      {
        name: 'MARKETPLACE_CONSOLE_LOGGING'
        value: toLower(string(enableConsoleLogging))
      }
      {
        name: 'STORAGE_ACCOUNT_NAME'
        value: createStorageAccount ? storageAccount.name : ''
      }
      {
        name: 'STORAGE_ACCOUNT_KEY'
        secureValue: createStorageAccount ? storageAccount!.listKeys().keys[0].value : ''
      }
      {
        name: 'EXTENSIONS_SHARE_NAME'
        value: extensionsShareName
      }
      {
        name: 'USE_FILE_SYSTEM_SOURCE'
        value: toLower(string(useFileSystemSource))
      }
      {
        name: 'LOGS_SHARE_NAME'
        value: logsShareName
      }
      {
        name: 'ENABLE_FILE_LOGGING'
        value: toLower(string(enableFileLogging))
      }
    ]
    scriptContent: '''
      #!/bin/bash
      set -e

      # Install kubectl
      echo "Installing kubectl..."
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      mv kubectl /usr/local/bin/

      # Get AKS credentials
      az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

      # Create namespace
      kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

      # Create docker registry secret
      kubectl create secret docker-registry acr-secret \
        --docker-server=$REGISTRY_SERVER \
        --docker-username=$REGISTRY_USERNAME \
        --docker-password=$REGISTRY_PASSWORD \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

      # Create Azure Files secret for storage (if file system source is enabled)
      if [ "$USE_FILE_SYSTEM_SOURCE" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        kubectl create secret generic azure-files-secret \
          --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
          --from-literal=azurestorageaccountkey="$STORAGE_ACCOUNT_KEY" \
          --namespace=$NAMESPACE \
          --dry-run=client -o yaml | kubectl apply -f -
      fi

      # Create Azure Files secret for logs (if file logging is enabled)
      if [ "$ENABLE_FILE_LOGGING" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        kubectl create secret generic azure-files-logs-secret \
          --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT_NAME \
          --from-literal=azurestorageaccountkey="$STORAGE_ACCOUNT_KEY" \
          --namespace=$NAMESPACE \
          --dry-run=client -o yaml | kubectl apply -f -
      fi

      # Apply deployment and service
      # Build volume mounts conditionally
      VOLUME_MOUNTS=""
      if [ "$USE_FILE_SYSTEM_SOURCE" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        VOLUME_MOUNTS="$VOLUME_MOUNTS
        - name: extensions-volume
          mountPath: /data/extensions
          readOnly: true"
      fi
      if [ "$ENABLE_FILE_LOGGING" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        VOLUME_MOUNTS="$VOLUME_MOUNTS
        - name: logs-volume
          mountPath: /data/logs
          readOnly: false"
      fi

      # Build volumes conditionally
      VOLUMES=""
      if [ "$USE_FILE_SYSTEM_SOURCE" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        VOLUMES="$VOLUMES
      - name: extensions-volume
        azureFile:
          secretName: azure-files-secret
          shareName: $EXTENSIONS_SHARE_NAME
          readOnly: true"
      fi
      if [ "$ENABLE_FILE_LOGGING" = "true" ] && [ -n "$STORAGE_ACCOUNT_NAME" ]; then
        VOLUMES="$VOLUMES
      - name: logs-volume
        azureFile:
          secretName: azure-files-logs-secret
          shareName: $LOGS_SHARE_NAME
          readOnly: false"
      fi

      # Build environment variables conditionally
      ENV_VARS="
        - name: APPLICATIONINSIGHTS_CONNECTION_STRING
          value: \"$APP_INSIGHTS_CONNECTION\"
        - name: Marketplace__Upstreaming_Mode
          value: \"$MARKETPLACE_PROXY_MODE\"
        - name: Marketplace__OrganizationName
          value: \"$MARKETPLACE_ORGANIZATION_NAME\"
        - name: Marketplace__ArtifactsProject
          value: \"$MARKETPLACE_ARTIFACTS_PROJECT_NAME\"
        - name: Marketplace__ArtifactsOrganization
          value: \"$MARKETPLACE_ARTIFACTS_ORGANIZATION\"
        - name: Marketplace__ArtifactsClientId
          value: \"$MARKETPLACE_CLIENT_ID\"
        - name: Marketplace__Logging__LogToConsole
          value: \"$MARKETPLACE_CONSOLE_LOGGING\""
      
      if [[ -n "$MARKETPLACE_ARTIFACTS_FEED" ]]; then
        ENV_VARS="$ENV_VARS
        - name: Marketplace__ArtifactsFeed
          value: \"$MARKETPLACE_ARTIFACTS_FEED\""
      fi

      if [ "$USE_FILE_SYSTEM_SOURCE" = "true" ]; then
        ENV_VARS="$ENV_VARS
        - name: Marketplace__ExtensionSourceDirectory
          value: \"/data/extensions\""
      fi
      
      if [ "$ENABLE_FILE_LOGGING" = "true" ]; then
        ENV_VARS="$ENV_VARS
        - name: Marketplace__LogsDirectory
          value: \"/data/logs\""
      fi

      cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vscode-private-marketplace
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vscode-private-marketplace
  template:
    metadata:
      labels:
        app: vscode-private-marketplace
    spec:
      containers:
      - name: vscode-private-marketplace
        image: $CONTAINER_IMAGE
        ports:
        - containerPort: 8080
        env:$ENV_VARS
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
        $([ -n "$VOLUME_MOUNTS" ] && echo "volumeMounts:$VOLUME_MOUNTS")
        livenessProbe:
          httpGet:
            path: /health/alive
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      imagePullSecrets:
      - name: acr-secret
      $([ -n "$VOLUMES" ] && echo "volumes:$VOLUMES")
---
apiVersion: v1
kind: Service
metadata:
  name: vscode-private-marketplace-service
  namespace: $NAMESPACE
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: vscode-private-marketplace
EOF

      # Wait for service to get external IP
      echo "Waiting for LoadBalancer IP..."
      kubectl wait --for=condition=available --timeout=300s deployment/vscode-private-marketplace -n $NAMESPACE
    '''
  }
  dependsOn: [
    aksCluster
    acrPullRoleAssignment
    managedIdentityAksUserRoleAssignment
    storageContributorRoleAssignment
  ]
}

output aksClusterName string = aksCluster.name
output containerAppUrl string = vnetTrafficOnly
  ? 'Internal only - configure ingress controller'
  : 'Use kubectl get service -n vscode-private-marketplace to get the external IP'
output storageAccountName string = createStorageAccount ? storageAccount.name : 'No storage account created'
output clientId string = userAssignedIdentity.properties.clientId
output aksClusterFqdn string = aksCluster.properties.fqdn
