# Intro and basic info

Here we will use Azure DevOps (Azure Pipelines) for below examples and notes.

### First basic pipeline example

Basic pipeline file `azure-pipeline.yml`:
```
trigger: none

pool:
  vmImage: ''

jobs:
  - job:
    steps:
      - script: echo Helo world!
        displayName: "Placeholder step"
```

### Deploy bicep with pipeline

To deploy bicep file we need to define following deploymnet task (`task` is subsection of `step`) `AzureResourceManagerTempalteDeployment@3` as follows:
```
- task: AzureResourceManagerTempalteDeployment@3
  inputs:
    connectedServiceName: 'MySerivceConnection'
    location: 'northeurope'
    resourceGroupName: Example
    csmFile: deploy/main.bicep
    overrideParameters: >
      -parameterName parameterValue
```

### Using variables

To use variables in pipeline, first we need to define them in repository host (Azure DevOps in our case - in pipeline edit mode we can define variables for the pipeline). Later, we can use them in pipeline file as follows woth special sntax `$(VariableName)`:
```
- task: AzureResourceManagerTemplateDeployment@3
  inputs:
    connectedServiceName: $(ServiceConnectionName)
    location: $(DeploymentDefaultLocation)
    resourceGroupName: $(ResourceGroupName)
    csmFile: deploy/main.bicep
    overrideParameters: >
      -environmentType $(EnvironmentType)
```

#### System variables

Azure Pipelines also use system variables, which contain predefined information, for example:
- `Build.BuildNumber` - unique identifier for pipeline run (usually a string, not a number),
- `Agent.BuildDirectory` - path on agent machine's file system, where piepline run's files are stored (useful when we want to reference files on the build agent)

#### Using variables directly in pipeline

We can also define variables directly in pipeline file by defining `variables` section, as follows:
```
variables:
  ServiceConnectionName: 'MyServiceConnection'
  EnvironmentType: 'Test'
  ResourceGroupName: 'MyResourceGroup'
  DeploymentDefaultLocation: 'westus3'
```
### Triggers

Triggers are used to run pipeline whenever "trigger event" occurs. It maybe some time interval, or push to specific branch on repository. For example branch trigger could be defined as follows:
```
trigger:
- main
```
More complaex example: trigger on every push to `main` branch or branch that starts with `release/*`:
```
trigger:
  branches:
    includes:
    - main
    - release/*
```
Trigger on all branches except specific ones:
```
trigger:
  branches:
    include:
    - '*'
    exclude:
    - feature/*
```
Sometimes, we want to trigger pipeline only when speicifc directory within repository is affected, for example when we have directory with documentation, we are not interested to run pipeline when docs are changing. We can define also such trigger, to run pipeline when speicifc directory is affected:
```
trigger:
  branches:
    include:
    - main
  paths:
    exclude:
    - docs
    include:
    - deploy
```

#### Run pipeline on schedule

To define trigger that will run pipeline on schedule follow below example:
```
schedules:
- cron: "0 0 * * *"
  displayName: Daily environment restore
  branches:
    include:
    - main
```

#### Combine trigger and schdule

We can combine triggers and schedules, like in this example (so pipeline runs on schedule as well as on trigger events):
```
trigger:
- main

schedules:
- cron: "0 0 * * *"
  displayName: Deploy test environment
  branches:
    include:
    - main
```

### Concurrency control

Azure Pipelines are run in parallel by default (when there are multiple runs at once, for example multiple trigger events happened at once).

Sometimes it is not desired and we can prohibit that behavior by using `batch: true` in pipeline file:
```
trigger:
  batch: true
  branches:
    include:
    - main
```
When trigger fires, Azure Pipelines ensures that it waits for any active pipeline run to complete. Then, it starts a new run with all of the changes that have accumulated since the last run.

### Pipeline stages

When pipeline does not define any stage, Azure implicitly creates one stage for the whole pipeline.

If we want to use multiple stages, we need to define them as follows:
```
stages:
- stage: TestStage
  jobs:
  - job: Test
- stage: DeployUSStage
  dependsOn: TestStage
  jobs:
  - job: DeployUS
- stage: DeployEuropeStage
  dependsOn: TestStage
  jobs:
  - job: DeployEurope
```
`dependsOn` keyword speicifies what stage needs to finish *succesfully* before the stage can start.

We can also run stages conditionally, when some stage failed for example:
```
- stage: RollbackStage
  condition: failed('DeployStage')
  jobs:
  - job: Rollback
```
If stage `DeployStage` fails, above stage will execute.

#### Validating Bicep file in pipeline

In pipelines we can define task that deploys with given Bicep file (additionally, by adding `deploymentMode: Validation` we can prevent actual deployment, and only validate the deployment, without actually running it):
```
- task: AzureResourceManagerTemplateDeployment@3
  inputs:
    connectedServiceName: 'MyServiceConnection'
    location: 'northeurope'
    deploymentMode: Validation
    resourceGroupName: $(ResourceGroupName)
    csmFile: ./main.bicep
```

### Environments

In Azure we can define `Environments`, that can be later used in pipelines. Then we can define checks on environment, such as required approvals (particular people, etc.). Then those checks will be reflected in a pipeline, that has defined `environment` property on step, such as below:
```
- stage: Deploy
  jobs:
    - deployment: Deploy
      environment: MyAzureEnvironment
      strategy:
        runOnce:
          deploy:
            steps:
            - checkout: self
            - task: AzureResourceManagerTemplateDeployment@3
              name: Deploy
              displayName: Deploy to Azure
              inputs:
                connectedServiceName: 'MyServiceConnection'
                location: $(deploymentDefaultLocation)
                resourceGroupName: $(ResourceGroupName)
                csmFile: deploy/main.bicep
```

### Pipeline templates

We can create also reusable pieces of pipelines by using templates. Template is simply some piece of pipeline, for example particular `steps` for job, like below:

`script.yml`
```
steps:
- script: |
  echo Hello world!
```
Now it can be included in other pipeline file with `template` keyword, like below:

`jobs.yml`
```
jobs:
- job: Job1
  pool:
    vmImage: 'windows-latest'
  steps:
  - template: script.yml
```

We can also *nest pipelines* - so above `jobs.yml` can also be used in another pipeline (`scipr.yml` is now nested pieline):
```
trigger:
  branches:
    inlucde:
    - main
  
pool:
  vmImage: ubuntu-latest

stages:
- stage: Stage1
  jobs:
  - template: jobs.yml
- stage: Stage2
  jobs:
  - template: jobs.yml
```

#### Parameters in pipelines

We can pass parameters to pipelines by using special syntac `${{parameters.YOUR_PARAMETER_NAME}}`. And we can pass the parameters from file with `paramters` keyword, like below:

`script.yml`
```
steps:
- script: |
    echo Hello ${{parameters.environmentType}}!
```

`jobs.yml`
```
steps:
- template: script.yml
  parameters:
    environmentType: Test

- template: script.yml
  parameters: 
    environmentType: Production
```

#### Conditions

We can use conditions to, for example, run stages conditionally:
```
${{ if eq(parameters.environmentType, 'Production') }}
```
For example:
```
parameters: 
- name: environmentType
  type: string
  default: 'Test'

steps:
- script: |
    echo Hello ${{parameters.environmentType}}!

- ${{ if eq(parameters.environmentType, 'Production') }}:
  - script: |
      echo This step only runs for production deployments.
```

### Passing variables between bicep and pipelines

To pass file between bicep and pipeline, we need to define output variables in bicep `output outVar string = 'hello'`, then use the bicep template in deployment task in pipeline.

To capture taht variable in pipeline, we nee to specify `deploymentOutputs: deploymentOutputs` on deployment task and define shell task (bash in this case):
```
- task: AzureResourceManagerTemplateDeployment@3
  name: Deploy
  displayName: Deploy to Azure
  inputs:
    connectedServiceName: $(ServiceConnectionName)
    location: 'polandcentral'
    resourceGroupName: $(ResourceGroupName)
    csmFile: ./main.bicep
    deploymentOutputs: deploymentOutputs
- bash: |
    echo "##vso[task.setvariable variable=outVar;isoutput=true]$(echo $DEPLOYMENT_OUTPUTS | jq -r '.outVar.value')"
  name: SaveDeploymentOutputs
  displayName: Save deployment outputs into variables
  env:
    DEPLOYMENT_OUTPUTS: $(deploymentOutputs)
```
- `deploymentOutputs: deploymentOutputs` stores bicep outputs in variable.
- `env: DEPLOYMENT_OUTPUTS: $(deploymentOutputs)` set `DEPLOYMENT_OUTPUTS` environment variable for script
- `echo "##vso[task.setvariable variable=outVar;isoutput=true]$(echo $DEPLOYMENT_OUTPUTS | jq -r '.outVar.value')"` sets output variable called also `outVar`

Then to use it from other stages, we need to follow syntax `stageDependencies.{stageName}.{jobName}.outputs['{jobName}.{stepName}.{variableName}'] `, in our case it would look like `stageDependencies.Deploy.DeployWebsite.outputs['SaveDeploymentOutputs.appServiceAppHostName']` assuming we have stage `Deploy` with job named `DeployWebsite` which has task `SaveDeploymentOutputs` defined above.

File `validate-bicep-multi-stage.yml` or `passing-values-of-outputs-of-steps.yml` contains example of passing value from Bicep file (which deployes web app), passes it to pipeline, which then passes it to smoke test for tests.