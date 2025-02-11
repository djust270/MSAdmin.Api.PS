function Get-MSAdminProducts {
    [CmdletBinding()]
    param()
    begin {
        $Uri = 'https://admin.microsoft.com/admin/api/users/products'
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
        $Products = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }
    end {
        $Products.Products
    }
}