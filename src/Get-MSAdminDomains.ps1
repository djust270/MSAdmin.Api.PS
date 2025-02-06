function Get-MSAdminDomains {
    <#
    .SYNOPSIS
        Gets a list of domains from the Microsoft 365 admin center.

    .DESCRIPTION
        This function will retrieve a list of domains from the Microsoft 365 admin center using the Graph API.

        The list can be filtered by the domain name.

        The function will return a list of objects containing the domain's properties.

    .PARAMETER SearchText
        The text to search for in the domain names. If not specified, all domains will be retrieved.

    .EXAMPLE
        Get-MSAdminDomains -SearchText "example.com"

        This example will retrieve a list of domains who have the name "example.com" from the Microsoft 365 admin center.

    .EXAMPLE
        Get-MSAdminDomains

        This example will retrieve a list of all domains from the Microsoft 365 admin center.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SearchText
    )
    begin {
        $uri = "https://admin.microsoft.com/admin/api/Domains/List?searchText=$SearchText"
        if (-Not $script:adminAccessToken){
            throw "Session not authenticated. Please run 'Get-MSAdminToken' and try again."
        }
        else {
            switch (($script:adminAccessToken.expires_on - [DateTime]::UtcNow).TotalSeconds){
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
        Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }
}

