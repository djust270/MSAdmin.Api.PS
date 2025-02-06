function Get-MSAdminDomainDependencies {
    <#
    .SYNOPSIS
        Gets dependencies for a specified domain from the Microsoft 365 admin center.

    .DESCRIPTION
        This function retrieves dependencies (users, groups, and applications) for a specified domain 
        from the Microsoft 365 admin center using the Graph API.

        Dependencies can be filtered by type (Users, Groups, Applications, or All).
        The function handles pagination automatically to retrieve all results.

    .PARAMETER DomainName
        The domain name to retrieve dependencies for. This parameter is required.

    .PARAMETER Type
        The type of dependencies to retrieve. Valid values are:
        - Users (Kind=1)
        - Groups (Kind=2)
        - Applications (Kind=4)
        - All (Default, includes all types)

    .EXAMPLE
        Get-MSAdminDomainDependencies -DomainName "contoso.onmicrosoft.com" -Type Users

        Retrieves all user dependencies for the specified domain.

    .EXAMPLE
        Get-MSAdminDomainDependencies -DomainName "contoso.onmicrosoft.com"

        Retrieves all dependencies (users, groups, and applications) for the specified domain.
    #>
    [CmdletBinding()]
    [OutputType([Array])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Users', 'Groups', 'Applications', 'All')]
        [string]$Type = 'All'
    )

    begin {
        # Map Type parameter to Kind values
        $kindMap = @{
            'Users' = '1'
            'Groups' = '2'
            'Applications' = '4'
            'All' = '1,2,4'
        }

        $kind = $kindMap[$Type]
        $baseUri = "https://admin.microsoft.com/admin/api/Domains/Dependencies"

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
        $nextLink = $null
        
        do {
            $uri = if ($nextLink) { 
                $nextLink 
            } else { 
                "$baseUri`?domainName=$DomainName&kind=$kind"
            }

            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers

            if ($response.Data.Dependencies) {
                $response.Data.Dependencies | Write-Output
            }

            $nextLink = $response.Data.NextLink

        } while ($nextLink -and -not $response.Data.IsLastPage)
    }
}