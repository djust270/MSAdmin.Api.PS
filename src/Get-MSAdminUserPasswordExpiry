function Get-MSAdminUserPasswordExpiry {
    <#
    .SYNOPSIS
        Gets password expiry information for a specified user from the Microsoft 365 admin center.

    .DESCRIPTION
        This function retrieves password expiry details for a specified user from the Microsoft 365 
        admin center. It returns information including the number of days until 
        password expiration and notification settings.

    .PARAMETER ObjectId
        The ObjectId (GUID) of the user to retrieve password expiry information for. This parameter is required.

    .EXAMPLE
        Get-MSAdminUserPasswordExpiry -ObjectId "a3209c7f-3d68-4f69-a9b2-9a7db61d0fdc"

        Retrieves password expiry information for the specified user.

    .EXAMPLE
        "a3209c7f-3d68-4f69-a9b2-9a7db61d0fdc" | Get-MSAdminUserPasswordExpiry

        Retrieves password expiry information for the specified user using pipeline input.
    #>
    [CmdletBinding()]
    [OutputType([Object])]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$ObjectId
    )

    begin {
        $baseUri = "https://admin.microsoft.com/admin/api/users"

        if (-Not $script:adminAccessToken) {
            throw "Session not authenticated. Please run 'Get-MSAdminToken' and try again."
        }
        else {
            switch (($script:adminAccessToken.expires_on - [DateTime]::UtcNow).TotalSeconds) {
                {$_ -lt 600 -and $_ -gt 5} {
                    # Attempt to refresh token
                    Write-Verbose "Attempting token refresh"
                    Get-MSAdminToken -RefreshToken $script:adminAccessToken.refresh_token
                }
                {$_ -lt 5} {
                    # Acquire new access token
                    throw "Access token is expired. Please run 'Get-MSAdminToken' and try again."
                }
            }
        }

        $headers = @{
            'Authorization' = "Bearer $($script:adminAccessToken.access_token)"
            'content-type' = 'application/json'
        }
    }

    process {
        $uri = "$baseUri/$ObjectId/passwordexpiry"
        
        try {
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            Write-Output $response
        }
        catch {
            Write-Error "Failed to retrieve password expiry for user with ObjectId '$ObjectId': $_"
        }
    }
}