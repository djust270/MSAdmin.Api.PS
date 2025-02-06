function Get-MSAdminToken {
    <#
    .SYNOPSIS
        Gets an access token for the Microsoft 365 admin center.

    .DESCRIPTION
        This function will retrieve an access token for the Microsoft 365 admin center. The token can be obtained using the client credentials flow or the authorization code flow.

        The client credentials flow requires the client ID and client secret of an AAD application. The authorization code flow requires the user to authenticate interactively.

    .PARAMETER TenantId
        The ID of the tenant to authenticate to. If not specified, the token will be obtained for the 'common' tenant.

    .PARAMETER ReturnToken
        If specified, the function will return the access token instead of storing it in the script context.

    .PARAMETER RefreshToken
        The refresh token to use when obtaining the access token using the authorization code flow.

    .PARAMETER ClientId
        The client ID of the AAD application to use when obtaining the access token using the client credentials flow.

    .PARAMETER ClientSecret
        The client secret of the AAD application to use when obtaining the access token using the client credentials flow.

    .EXAMPLE
        Get-MSAdminToken -ClientId <client id> -ClientSecret <client secret>

        This example will retrieve an access token using the client credentials flow.

    .EXAMPLE
        Get-MSAdminToken

        This example will retrieve an access token using the authorization code flow and store it in the script context.

    .EXAMPLE
        Get-MSAdminToken -ReturnToken

        This example will retrieve an access token using the authorization code flow and return it instead of storing it in the script context.
    #>
    [cmdletbinding(DefaultParameterSetName='Interactive')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [Parameter(Mandatory=$false, ParameterSetName='Interactive')]
        [Parameter(Mandatory=$false, ParameterSetName='RefreshToken')]
        [string]$TenantId,
 
        [Parameter(Mandatory=$false)]
        [switch]$ReturnToken,
 
        [Parameter(Mandatory=$true, ParameterSetName='RefreshToken')]
        [string]$RefreshToken,
 
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [string]$ClientId,
 
        [Parameter(Mandatory=$true, ParameterSetName='ClientCredentials')]
        [string]$ClientSecret
    )
    begin {
        $authority = if ($TenantId) { $TenantId } else { 'common' }
        $clientid = if ($ClientId) { $ClientId } else { '1950a258-227b-4e31-a9cf-717495945fc2' }
        $scope = 'https://admin.microsoft.com/.default'
    }
 
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ClientCredentials' {
                $body = "grant_type=client_credentials&client_id=$clientid&client_secret=$ClientSecret&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/token"
            }
            'RefreshToken' {
                $body = "grant_type=refresh_token&client_id=$clientid&refresh_token=$RefreshToken&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/token"
            }
            'Interactive' {
                $authorization_endpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/authorize"
                $redirect_uri = 'http://localhost:8400/'
                $nonce = (New-Guid).Guid
                
                $null = Start-Job -Name 'CodeResponse' -Scriptblock {
                    param($redirect_uri)
                    $httpListener = New-Object System.Net.HttpListener
                    $httpListener.Prefixes.Add($redirect_uri)
                    $httpListener.Start()
                    $context = $httpListener.GetContext()
                    $context.Response.StatusCode = 200
                    $context.Response.ContentType = 'application/json'
                    $responseBytes = [System.Text.Encoding]::UTF8.GetBytes('')
                    $context.Response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)        
                    $context.Response.Close()
                    $httpListener.Close()
                    $context.Request
                } -ArgumentList $redirect_uri
 
                $code_endpoint = "$authorization_endpoint`?client_id=$clientid&scope=$scope&redirect_uri=$redirect_uri&response_type=code&nonce=$nonce&prompt=select_account"
                Start-Process $code_endpoint
                $url = Get-Job -Name CodeResponse | Wait-Job | Receive-Job
                Remove-Job -Name CodeResponse
                $code = [System.Web.HTTPUtility]::ParseQueryString($url.url.query)['code']
 
                $body = "grant_type=authorization_code&client_id=$clientid&nonce=$nonce&code=$code&redirect_uri=$redirect_uri&scope=$scope"
                $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/token"
            }
        }
 
        $headers = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body -Headers $headers
 
        if ($tokenResponse.expires_on) {
            $tokenResponse.expires_on = (Get-Date "1970-01-01T00:00:00Z").ToUniversalTime().AddSeconds($tokenResponse.expires_on)
        }
    }
 
    end {
        switch ($ReturnToken){
            $false {$script:adminAccessToken = $tokenResponse}
            $true {$tokenResponse}
        }
    }
 }
