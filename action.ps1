# HelloID-Task-SA-Target-AzureActiveDirectory-AccountRevokeGroupMembership
#########################################################################
# Form mapping
$formObject = @{
    userPrincipalName = $form.UserPrincipalName
    groupsToRemove    = $form.GroupsToRemove
}

try {
    Write-Information "Executing AzureActiveDirectory action: [AccountRevokeGroupMembership] for: [$($formObject.userPrincipalName)]"

    # Action logic here
    Write-Information "Retrieving Microsoft Graph AccessToken for tenant: [$AADTenantID]"
    $splatTokenParams = @{
        Uri         = "https://login.microsoftonline.com/$AADTenantID/oauth2/token"
        ContentType = 'application/x-www-form-urlencoded'
        Method      = 'POST'
        Verbose     = $false
        Body        = @{
            grant_type    = 'client_credentials'
            client_id     = $AADAppID
            client_secret = $AADAppSecret
            resource      = 'https://graph.microsoft.com'
        }
    }
    $accessToken = (Invoke-RestMethod @splatTokenParams).access_token
}
catch {
    Write-Error "Could not execute AzureActiveDirectory action [AccountRevokeGroupMembership] for: [$($formObject.userPrincipalName)]. Could not aquire Microsoft Graph AccessToken. Error: [$($_.Exception.Message)], Details : [$($_.Exception.ErrorDetails)]"
    return
}

try {
    $splatGetUserParams = @{
        Uri     = "https://graph.microsoft.com/v1.0/users/$($formObject.userPrincipalName)"
        Method  = 'GET'
        Verbose = $false
        Headers = @{
            Authorization  = "Bearer $accessToken"
            Accept         = 'application/json'
            'Content-Type' = 'application/json'
        }
    }
    $azureADUser = Invoke-RestMethod @splatGetUserParams
}
catch {
    Write-Error "Could not execute AzureActiveDirectory action [AccountRevokeGroupMembership] for: [$($formObject.userPrincipalName)]. User not found in the directory. Error: [$($_.Exception.Message)], Details : [$($_.Exception.ErrorDetails)]"
    return
}

try {
    foreach ( $group in $formObject.GroupsToRemove) {
        try {

            $splatRevokeParams = @{
                Uri     = "https://graph.microsoft.com/v1.0/groups/$($group.id)/members/$($azureADUser.id)/`$ref"
                Method  = 'Delete'
                Verbose = $false
                Headers = @{
                    Authorization  = "Bearer $accessToken"
                    Accept         = 'application/json'
                    'Content-Type' = 'application/json'
                }
            }

            $null = Invoke-RestMethod @splatRevokeParams
            $auditLog = @{
                Action            = 'RevokeMembership'
                System            = 'AzureActiveDirectory'
                TargetIdentifier  = "$($azureADUser.id)"
                TargetDisplayName = "$($formObject.userPrincipalName)"
                Message           = "AzureActiveDirectory action: [AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)] executed successfully"
                IsError           = $false
            }
            Write-Information -Tags 'Audit' -MessageData $auditLog
            Write-Information "AzureActiveDirectory action: [AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)] executed successfully"
        }
        catch {
            $ex = $_
            if (($ex.Exception.Response) -and ($Ex.Exception.Response.StatusCode -eq 404)) {
                # 404 indicates already removed
                   $auditLog = @{
                    Action            = 'RevokeMembership'
                    System            = 'AzureActiveDirectory'
                    TargetIdentifier  = "GroupId [$($group.id)]"
                    TargetDisplayName = "User UPN [$formObject.userPrincipalName]"
                    Message           = "AzureActiveDirectory action: [AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)] executed successfully. Note that the account was not a member"
                    IsError           = $false
                }
                Write-Information -Tags 'Audit' -MessageData $auditLog
                Write-Information "AzureActiveDirectory action: [AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)] executed successfully.  Note that the account was not a member"

            }
            else {
                    $auditLog = @{
                    Action            = 'RevokeMembership'
                    System            = 'AzureActiveDirectory'
                    TargetIdentifier  = "$($azureADUser.id)"
                    TargetDisplayName = "$($formObject.userPrincipalName)"
                    Message           = "Could not execute AzureActiveDirectory action:[AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)], error: $($ex.Exception.Message), Details : [$($ex.ErrorDetails.message)]"
                    IsError           = $true
                }
                Write-Information -Tags "Audit" -MessageData $auditLog
                Write-Error "Could not execute AzureActiveDirectory action:[AccountRevokeGroupMembership to group [$($group.Name)($($group.id))] ] for: [$($formObject.userPrincipalName)], error: $($ex.Exception.Message), Details : [$($ex.ErrorDetails.message)]"
            }
        }
    }
}
catch {
    $ex = $_
    $auditLog = @{
        Action            = 'RevokeMembership'
        System            = 'AzureActiveDirectory'
        TargetIdentifier  =  "$($azureADUser.id)"
        TargetDisplayName = "$($formObject.userPrincipalName)"
        Message           =  "Could not execute AzureActiveDirectory action: [AccountRevokeGroupMembership] for: [$($formObject.userPrincipalName)], error: $($ex.Exception.Message) details : [$($ex.ErrorDetails.message)] "
        IsError           = $true
    }
    Write-Information -Tags "Audit" -MessageData $auditLog
    Write-Error   "Could not execute AzureActiveDirectory action: [AccountRevokeGroupMembership] for: [$($formObject.userPrincipalName)], error: $($ex.Exception.Message) details : [$($ex.ErrorDetails.message)] "
}
#########################################################################
