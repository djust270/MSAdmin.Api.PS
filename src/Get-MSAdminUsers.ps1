function Get-MSAdminUsers {
    <# 
    .SYNOPSIS
        Gets a list of users from the Microsoft 365 admin center.

    .DESCRIPTION
        This function will retrieve a list of users from the Microsoft 365 admin center using the Graph API. The list can be filtered by the user's display name or user principal name.

        The function will return a list of objects containing the user's properties. The list can be filtered by the user's display name or user principal name.

    .EXAMPLE
        Get-MSAdminUsers -DisplayName "John Doe"

        This example will retrieve a list of users who have the display name of "John Doe" from the Microsoft 365 admin center.

    .EXAMPLE
        Get-MSAdminUsers -UserPrincipalName "john.doe@example.com"

        This example will retrieve a list of users who have the user principal name of "john.doe@example.com" from the Microsoft 365 admin center.

    .EXAMPLE
        Get-MSAdminUsers -All

        This example will retrieve a list of all users from the Microsoft 365 admin center.   
    #>
    [cmdletbinding()]
    param(      
        [Parameter(Mandatory=$false,
        ValueFromPipelineByPropertyName=$true, 
        ParameterSetName='ByName')]
        [string]$DisplayName,
        
        [Parameter(Mandatory=$false, 
        ValueFromPipelineByPropertyName=$true, 
        ParameterSetName='ByUserPrincipalName')]
        [string]$UserPrincipalName,

        [Parameter(Mandatory=$false, 
        ParameterSetName='Default')]
        [switch]$All
    )
    begin{
        Write-Verbose "Using parameter set: $($PSCmdlet.ParameterSetName)"
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {
                $searchString = $DisplayName
            }
            'ByUserPrincipalName' {
                $searchString = $UserPrincipalName
            }
            'Default' {
                $searchString = ''
            }
        }
        $uri = 'https://admin.microsoft.com/admin/api/Users/ListUsers'
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
        $body = @{
            ListAction = -1
            ListContext = $null
            MSGraphFilter = @{
                domains = @()
                locations = @()
                skuIds = @()
            }
            SearchText = $searchString
            SelectedView = ""
            SelectedViewType = ""
            ServerContext = $null
            SortDirection = 0
            SortPropertyName = "DisplayName"
        } | ConvertTo-Json
        
    }
    process {
        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
            $response.users
            if ($response.NextLink){
                do {
                    $response = Invoke-RestMethod -Uri $response.NextLink -Headers $headers -Method Get
                    $response.users
                } while ($response.NextLink)
            }
        }
        catch {
            Write-Error "Request failed. Error details: $_"
        }
    }
    end {}
}
