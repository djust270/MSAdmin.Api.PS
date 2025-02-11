function Get-MSAdminGroup {
    <#
    .SYNOPSIS
        Retrieves a list of Microsoft 365 groups based on the specified criteria.

    .DESCRIPTION
        This function retrieves a list of Microsoft 365 groups based on the specified criteria.
        The function supports retrieval of groups by type (Microsoft365, Distribution, Mail-Enabled security, Security) or by ID.

    .PARAMETER GroupType
        Specifies the type of groups to retrieve. Valid values are:
        - Microsoft365
        - Distribution
        - Mail-Enabled security
        - Security

    .PARAMETER GroupId
        Specifies the ID of the group to retrieve.

    .PARAMETER All
        Specifies that all groups should be retrieved, regardless of type.

    .EXAMPLE
        Get-MSAdminGroup -GroupType Microsoft365

        Retrieves all Microsoft 365 groups.

    .EXAMPLE
        Get-MSAdminGroup -GroupType Distribution

        Retrieves all Distribution groups.

    .EXAMPLE
        Get-MSAdminGroup -GroupType Mail-Enabled security

        Retrieves all Mail-Enabled security groups.

    .EXAMPLE
        Get-MSAdminGroup -GroupType Security

        Retrieves all Security groups.

    .EXAMPLE
        Get-MSAdminGroup -GroupId <GroupId>

        Retrieves the group with the specified ID.

    .EXAMPLE
        Get-MSAdminGroup -All

        Retrieves all groups, regardless of type.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName='ByType')]
        [ValidateSet('Microsoft365', 'Distribution', 
        'Mail-Enabled security', 'Security')]
        [String[]]$GroupType,

        [Parameter(Mandatory, ParameterSetName='ById')]
        [String]$GroupId,

        [Parameter(Mandatory, ParameterSetName='All')]
        [Switch]$All
    )
    begin {
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
        $groupTypeMap = @{
            'Microsoft365' = 0
            'Distribution' = 2
            'Mail-Enabled security' = 3
            'Security' = 1
        }
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ByType' {
                $groupTypeValue = $GroupType | ForEach-Object { $groupTypeMap[$_] }
                $body = @{
                    GroupTypes = @($groupTypeValue)
                    SearchString = ''
                    SortDirection = 'asc'
                    SortField = 'GroupName'
                } | ConvertTo-Json
                Write-Verbose "Constructed body: $body"
                $uri = "https://admin.microsoft.com/admin/api/groups/GetGroups"
                $response = (Invoke-RestMethod -uri $uri -Body $body -headers $headers -Method POST).Groups
            }
            'All' {
                $groupTypeValue = @(0, 2, 3, 1)
                $body = @{
                    GroupTypes = @($groupTypeValue)
                    SearchString = ''
                    SortDirection = 'asc'
                    SortField = 'GroupName'
                } | ConvertTo-Json
                $uri = "https://admin.microsoft.com/admin/api/groups/GetGroups"
                $response = (Invoke-RestMethod -uri $uri -Body $body -headers $headers -Method POST).Groups
            }
            'ById' {
                $uri = "https://admin.microsoft.com/admin/api/groups/$GroupId"
                $response = Invoke-RestMethod -uri $uri -headers $headers -Method GET
            }
        }
    }
    end {
        $response
    }
}

