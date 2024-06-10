import-module intunebackupandrestore
import-module Microsoft.Graph.Intune

##############################################################################################################################################
##### UPDATE THESE VALUES #################################################################################################################
##############################################################################################################################################
## Your Azure Tenant Name
$tenant = "fisherpaykel.onmicrosoft.com"

##Your Azure Tenant ID
$tenantid = "263a7cc6-04d1-402b-9f10-fd15e54c48d6"

##Your App Registration Details
$clientId = "e74c7353-fe0e-41a2-a2d9-122ede8291f9"
$clientSecret = Get-AutomationVariable -Name "intunebackupclientsecret"

##############################################################################################################################################
##### DO NOT EDIT BELOW THIS LINE #############################################################################################################
##############################################################################################################################################
$authority = "https://login.windows.net/$tenant"

## Connect to MS Graph
Update-MSGraphEnvironment -AppId $clientId -Quiet
Update-MSGraphEnvironment -AuthUrl $authority -Quiet
Update-MSGraphEnvironment -SchemaVersion “Beta” -Quiet
Connect-MSGraph -ClientSecret $ClientSecret -Quiet

##Get Date
$date = get-date -format "dd-MM-yyy"

##Create temp folder
$dir = $env:temp + "\IntuneBackup" + $date
$tempFolder = New-Item -Type Directory -Force -Path $dir

$containerName = "intunebackup"
$subContainerName = (Get-Item $tempFolder).Name

##Backup Locally
Start-IntuneBackup `
		-Path $tempFolder
		
##Connect to AZURE using Managed identity
Connect-AzAccount -Identity -AccountId 4e68c19b-5bbc-4158-9b4c-b1d5e63a348d

##Upload to Azure Blob
$files = "$env:TEMP\IntuneBackup$date" 
$context = New-AzStorageContext -StorageAccountName "intunebackupfpa"

# Function to upload files recursively
function UploadFilesRecursively {
    param (
        [string]$SourcePath,
        [string]$ContainerName,
        [string]$ParentFolder
    )

    # Get all items in the source path
    $items = Get-ChildItem -Path $SourcePath

    # Upload files and recurse into directories
    foreach ($item in $items) {
        if ($item.PSIsContainer) {
            # Recurse into sub-directory
            $newParentFolder = if ($ParentFolder -eq "") { $item.Name } else { "$ParentFolder/$($item.Name)" }
            UploadFilesRecursively -SourcePath $item.FullName -ContainerName $ContainerName -ParentFolder $newParentFolder
        } else {
            # Upload file to Azure Blob Storage
            $blobName = if ($ParentFolder -eq "") { $item.Name } else { "$ParentFolder/$($item.Name)" }
            Set-AzStorageBlobContent -File $item.FullName -Container $ContainerName -Blob $blobName -Context $context -Force
        }
    }
}

# Upload files recursively from the local folder to the Azure Blob Storage container
UploadFilesRecursively -SourcePath $tempFolder -ContainerName $containerName -ParentFolder $subContainerName

Write-Host "Upload completed."