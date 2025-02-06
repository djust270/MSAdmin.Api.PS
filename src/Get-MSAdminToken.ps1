#Requires -Module PSAuthClient
function Get-MSAdminToken {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$TenantId
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
        $token_endpoint = "https://login.microsoftonline.com/$authority/oauth2/v2.0/token"

        $splat = @{
            client_id = "1950a258-227b-4e31-a9cf-717495945fc2"
            scope = "https://admin.microsoft.com/.default"
            redirect_uri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
        }
        $code = Invoke-OAuth2AuthorizationEndpoint -uri $authorization_endpoint @splat -usePkce:$false
        $token = Invoke-OAuth2TokenEndpoint -uri $token_endpoint @code
    }
    end {
        $script:adminAccessToken = $Token
    }
}