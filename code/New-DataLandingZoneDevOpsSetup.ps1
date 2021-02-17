[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $OrgName,

    [Parameter(Mandatory = $true)]
    [String]
    $SourceProjectName,

    [Parameter(Mandatory = $true)]
    [String]
    $SourceRepositoryName,

    [Parameter(Mandatory = $true)]
    [String]
    $DestinationProjectName,

    [Parameter(Mandatory = $true)]
    [String]
    $DestinationRepositoryName,

    [Parameter(Mandatory = $true)]
    [String]
    $PatToken,

    [Parameter(Mandatory = $true)]
    [String]
    $MainBranchName,

    [Parameter(Mandatory = $true)]
    [String]
    $YamlFilePath,

    [Parameter(Position = 1, ValueFromRemainingArguments)]
    $Remaining
)


function Invoke-DevOpsApiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $RestMethod,

        [Parameter(Mandatory = $true)]
        [String]
        $UriExtension,

        [Parameter(Mandatory = $true)]
        [String]
        $Body,

        [Parameter(Mandatory = $true)]
        [String]
        $ApiVersion
    )
    # Define Endpoint Uri
    Write-Verbose "Defining Endpoint Uri"
    $devOpsApiUri = "https://dev.azure.com/${UriExtension}?api-version=${ApiVersion}"
    Write-Verbose "Endpoint URI: ${devOpsApiUri}"

    # Define Header for REST call
    Write-Verbose "Defining Header for REST call"
    $base64PatToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($PatToken)"))
    $headers = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Basic ${base64PatToken}"
    }
    Write-Verbose $headers.values

    # Define parameters for REST method
    Write-Verbose "Defining parameters for pscore method"
    $parameters = @{
        'Uri'         = $devOpsApiUri
        'Method'      = $RestMethod
        'Headers'     = $headers
        'Body'        = $Body
        'ContentType' = 'application/json'
    }

    # Invoke REST API
    Write-Verbose "Invoking REST API"
    try {
        $response = Invoke-RestMethod @parameters
        $responseBody = $response.value
        Write-Verbose "Response: ${responseBody}"
    }
    catch {
        Write-Host -ForegroundColor:Red $_
        Write-Host -ForegroundColor:Red "StatusCode:" $_.Exception.Response.StatusCode.value__
        Write-Host -ForegroundColor:Red "StatusDescription:" $_.Exception.Response.StatusDescription
        Write-Host -ForegroundColor:Red $_.Exception.Message
        throw "REST API call failed"
    }
    return $response
}


function Get-ProjectId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ProjectName,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/_apis/projects"

    # Define Body
    Write-Verbose "Defining Body"
    $body = @{} | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Get -UriExtension $uriExtension -Body $body -ApiVersion "6.0"

    # Iterate through Projects and return ID
    Write-Verbose "Iterating through Projects and returning ID"
    foreach ($project in $result.value) {
        if ($project.name -eq $ProjectName) {
            return $project.id
        }
    }
    return $null
}


function Get-RepositoryId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $RepositoryName,

        [Parameter(Mandatory = $true)]
        [String]
        $ProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/${ProjectId}/_apis/git/repositories"

    # Define Body
    Write-Verbose "Defining Body"
    $body = @{} | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Get -UriExtension $uriExtension -Body $body -ApiVersion "6.0"

    # Iterate through Repositories and return ID
    Write-Verbose "Iterating through Repositories and return ID"
    foreach ($repository in $result.value) {
        if ($repository.name -eq $RepositoryName) {
            return $repository.id
        }
    }
}


function New-Fork {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $SourceRepositoryId,

        [Parameter(Mandatory = $true)]
        [String]
        $SourceProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationRepositoryName,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/_apis/git/repositories"

    # Define Body
    Write-Verbose "Defining Body"
    $body = @{
        "name"             = $DestinationRepositoryName
        "project"          = @{
            "id" = $DestinationProjectId
        }
        "parentRepository" = @{
            "id"      = $SourceRepositoryId
            "project" = @{
                "id" = $SourceProjectId
            }
        }
    } | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Post -UriExtension $uriExtension -Body $body -ApiVersion "6.0"
    return $result
}


function New-Pipeline {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $DestinationProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationRepositoryId,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationRepositoryName,

        [Parameter(Mandatory = $true)]
        [String]
        $BranchName,

        [Parameter(Mandatory = $true)]
        [String]
        $YamlFilePath,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/${DestinationProjectId}/_apis/pipelines"

    # Define Body
    Write-Verbose "Defining Body"
    $triggers = New-Object System.Collections.ArrayList
    $triggers.Add(@{"settingsSourceType" = 2; "triggerType" = 2; })
    $body = @{
        "name"          = "${DestinationRepositoryName}-NodeDeployment"
        "folder"        = "\\"
        "configuration" = @{
            "path"       = "${BranchName}"
            "repository" = @{
                "id"     = $DestinationRepositoryId
                "name"   = $DestinationRepositoryName
                "type"   = "azureReposGit"
                "branch" = "${YamlFilePath}"
            }
            "type"       = "yaml"
            "triggers"   = $triggers
        }
    } | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Post -UriExtension $uriExtension -Body $body -ApiVersion "6.0-preview"
    return $result
}


function New-PipelineRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $PipelineId,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/${ProjectId}/_apis/pipelines/${PipelineId}/runs"

    # Define Body
    Write-Verbose "Defining Body"
    $body = @{
        "previewRun" = $false
    } | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Post -UriExtension $uriExtension -Body $body -ApiVersion "6.0-preview.1"
    return $result
}

function New-PullRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ProjectId,

        [Parameter(Mandatory = $true)]
        [String]
        $RepositoryId,

        [Parameter(Mandatory = $true)]
        [String]
        $SourceBranchName,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationBranchName,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken,

        [Parameter(Mandatory = $true)]
        [String]
        $OrgName
    )
    # Define URI Extension
    Write-Verbose "Defining URI Extension"
    $uriExtension = "${OrgName}/${ProjectId}/_apis/git/repositories/${RepositoryId}/pullRequests"

    # Define Body
    Write-Verbose "Defining Body"
    $body = @{
        'isDraft'       = $false
        'labels'        = @()
        'reviewers'     = @()
        'sourceRefName' = "refs/heads/${SourceBranchName}"
        'targetRefName' = "refs/heads/${DestinationBranchName}"
        'title'         = 'Updated Parameters'
        'description'   = 'Updated Parameters'
    } | ConvertTo-Json -Depth 5

    # Call REST API
    Write-Verbose "Calling REST API"
    $result = Invoke-DevOpsApiRequest -PatToken $PatToken -RestMethod Post -UriExtension $uriExtension -Body $body -ApiVersion "6.1-preview.1"
    return $result
}

function Update-Repository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $GlobalDnsResourceGroupId,
        
        [Parameter(Mandatory = $true)]
        [String]
        $DataLandingZoneSubscriptionId,

        [Parameter(Mandatory = $true)]
        [String]
        $DataLandingZoneName,

        [Parameter(Mandatory = $true)]
        [String]
        $Location,

        [Parameter(Mandatory = $true)]
        [String]
        $SubnetId,

        [Parameter(Mandatory = $true)]
        [String]
        $SynapseStorageAccountName,

        [Parameter(Mandatory = $true)]
        [String]
        $SynapseStorageAccountFileSystemName,

        [Parameter(Mandatory = $true)]
        [String]
        $RepositoryUri,

        [Parameter(Mandatory = $true)]
        [String]
        $PatToken
    )
    # Create Folder for Repository
    Write-Verbose "Creating Folder for Repository"
    $repositoryFolderName = './Repository'
    New-Item $repositoryFolderName -ItemType Directory -Force

    # Define Credentials for Authentication
    Write-Verbose "Defining Credentials for Authentication"
    $password = ConvertTo-SecureString $PatToken -AsPlainText -Force
    $credSp = New-Object System.Management.Automation.PSCredential ($UserName, $password)

    # Clone Repository
    Write-Verbose "Cloning Repository '${RepositoryUri}'"
    Copy-GitRepository `
        -Source $RepositoryUri `
        -DestinationPath "${repositoryFolderName}" `
        -Credential $credSp
    
    # Add Git Branch
    Write-Verbose "Adding Git Branch"
    $time = (Get-Date -Format "yyyy-MM-ddTHH-mm-ssZ")
    $branchName = "testBranch-${time}"
    New-GitBranch `
        -RepoRoot "${repositoryFolderName}" `
        -Name $branchName
    
    # TODO Update files in folder and return list of file paths
    Set-Location "${repositoryFolderName}"
    & "./configs/UpdateParameters.ps1" `
        -ConfigurationFilePath "configs/config.json" `
        -GlobalDnsResourceGroupId $GlobalDnsResourceGroupId `
        -DataLandingZoneSubscriptionId $DataLandingZoneSubscriptionId `
        -DataLandingZoneName $DataLandingZoneName `
        -Location $Location `
        -SubnetId $SubnetId `
        -SynapseStorageAccountName $SynapseStorageAccountName `
        -SynapseStorageAccountFileSystemName $SynapseStorageAccountFileSystemName
    Set-Location ".."
    
    # Stage Changes
    Write-Verbose "Staging Changes"
    Add-GitItem `
        -RepoRoot "${repositoryFolderName}" `
        -Path @('.\')
    
    # Commit Changes
    Write-Verbose "Committing Changes"
    Save-GitCommit `
        -RepoRoot "${repositoryFolderName}" `
        -Message 'Updated Parameters' `
        -Signature (New-GitSignature -Name 'Bot' -EmailAddress 'bot@noreply.com')
    
    # Push Changes
    Write-Verbose "Pushing Changes"
    Send-GitCommit `
        -RepoRoot "${repositoryFolderName}" `
        -Credential $credSp
    
    return $branchName
}


# Get Project IDs and Repository IDs
Write-Host "Getting Project IDs and Repository IDs"
$sourceProjectId = Get-ProjectId `
    -ProjectName $SourceProjectName `
    -PatToken $PatToken `
    -OrgName $OrgName

$destinationProjectId = Get-ProjectId `
    -ProjectName $DestinationProjectName `
    -PatToken $PatToken `
    -OrgName $OrgName

$sourceRepositoryId = Get-RepositoryId `
    -RepositoryName $SourceRepositoryName `
    -ProjectId $sourceProjectId `
    -PatToken $PatToken `
    -OrgName $OrgName

# Fork Repository
Write-Host "Fork Repository"
$result = New-Fork `
    -SourceRepositoryId $sourceRepositoryId `
    -SourceProjectId $sourceProjectId `
    -DestinationProjectId $destinationProjectId `
    -DestinationRepositoryName $DestinationRepositoryName `
    -PatToken $PatToken `
    -OrgName $OrgName
Write-Verbose "Result from Forking the Repository: ${result}"

# Sleep for X Seconds to give the DevOps Backend Process some time to Finish
$seconds = 5
Write-Host "Sleeping for ${seconds} Seconds to give the DevOps Backend Process some time to Finish"
Start-Sleep -Seconds $seconds

# Get Repository ID of Fork
Write-Host "Getting Repository ID of Fork"
$destinationRepositoryId = Get-RepositoryId `
    -RepositoryName $DestinationRepositoryName `
    -ProjectId $destinationProjectId `
    -PatToken $PatToken `
    -OrgName $OrgName

# Update Forked Repository
Write-Host "Updating Forked Repository"
$branchName = Update-Repository `
    -GlobalDnsResourceGroupId 'my-global-dns-resource-group-resource-id' `
    -DataLandingZoneSubscriptionId 'my-data-landing-zone-subscription-id' `
    -DataLandingZoneName 'my-data-landing-zone-name' `
    -Location 'my-region' `
    -SubnetId 'my-subnet-resource-id' `
    -SynapseStorageAccountName 'my-synapse-storage-account-name' `
    -SynapseStorageAccountFileSystemName 'my-synapse-storage-account-file-system-name' `
    -RepositoryUri "https://dev.azure.com/${OrgName}/${DestinationProjectName}/_git/${DestinationRepositoryName}" `
    -PatToken $PatToken

# Create Pull Request
Write-Host "Creating Pull Request"
New-PullRequest `
    -ProjectId $destinationProjectId `
    -RepositoryId $destinationRepositoryId `
    -SourceBranchName $branchName `
    -DestinationBranchName $MainBranchName

# Create Pipeline in Fork
Write-Host "Creating Pipeline in Fork"
$result = New-Pipeline `
    -DestinationProjectId $destinationProjectId `
    -DestinationRepositoryId $destinationRepositoryId `
    -DestinationRepositoryName $DestinationRepositoryName `
    -BranchName $MainBranchName `
    -YamlFilePath $YamlFilePath `
    -OrgName $OrgName `
    -PatToken $PatToken
$pipelineId = $result.id

# # Trigger pipeline
# Write-Host "Triggering Pipeline"
# $result = New-PipelineRun -DestinationProjectId $destinationProjectId -PipelineId $pipelineId -OrgName $OrgName -PatToken $PatToken
# Write-Verbose $result
