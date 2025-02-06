function Get-MSAdminToken {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$TenantId,
        [Parameter(Mandatory=$false)]
        [switch]$ReturnToken
    )
    begin {
        if (-Not [String]::IsNullOrEmpty($TenantId)) {
            $authority = $TenantId
        }
        else{
            $authority = 'common'
        }
    }
    process {
        $authorization_endpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/authorize"
        $clientid = '1950a258-227b-4e31-a9cf-717495945fc2'
        $scope = 'https://admin.microsoft.com/.default'
        $redirect_uri = 'http://localhost:8400/'
        $nonce = (New-Guid).Guid
        # Create job to start http listener to receive code response
        # sourced from https://github.com/alflokken/PSAuthClient/blob/main/src/internal/New-HttpListener.ps1
        $null = Start-Job -Name 'CodeResponse' -Scriptblock {
            param($redirect_uri)
            $httpListener = New-Object System.Net.HttpListener
            $httpListener.Prefixes.Add($redirect_uri)
            $httpListener.Start()
            # wait for request
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
        # Exchange authorization code for bearer token
        $body = "grant_type=authorization_code&client_id=$clientid&nonce=$nonce&code=$code&redirect_uri=$redirect_uri&scope=$scope"
        $headers = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
        $tokenEndpoint = "https://login.microsoftonline.com/$authority/oauth2/token"
        $tokenResponse = Invoke-RestMethod -Method POST -Uri $tokenEndpoint -Body $body -Headers $headers
        $tokenResponse.expires_on = (Get-Date "1970-01-01T00:00:00Z").ToUniversalTime().AddSeconds($tokenResponse.expires_on)
    }
    end {
        switch ($ReturnToken){
            $false {$script:adminAccessToken = $tokenResponse}
            $true {$tokenResponse}
        }
    }
}

