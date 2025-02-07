function Set-MSAdminGroupEmailAddresses {
    <#
    .SYNOPSIS
        Updates the email addresses of a Microsoft 365 group.

    .DESCRIPTION
        This function updates both the primary SMTP address and proxy addresses of a Microsoft 365 group
        using the Microsoft 365 admin center API.

    .PARAMETER GroupId
        The object ID of the group to update.

    .PARAMETER CurrentPrimarySmtpAddress
        The current primary SMTP address of the group.

    .PARAMETER NewPrimaryAddress
        The new primary SMTP address for the group. If not specified, the current primary SMTP address is used.

    .PARAMETER ProxyAddresses
        Additional email addresses (aliases) to add to the group. If not specified, existing proxy addresses are used.

    .EXAMPLE
        Set-MSAdminGroupEmailAddresses -GroupId "5208ad9f-f22c-4abc-908b-8bb8954dbd22" -CurrentPrimarySmtpAddress "test1@contoso.com" -NewPrimaryAddress "newtest1@contoso.com"

        Updates the primary SMTP address of the specified group.

    .EXAMPLE
        Set-MSAdminGroupEmailAddresses -GroupId "5208ad9f-f22c-4abc-908b-8bb8954dbd22" -CurrentPrimarySmtpAddress "test1@contoso.com" -ProxyAddresses @("alias1@contoso.com", "alias2@contoso.com")

        Updates the proxy addresses (aliases) of the specified group while maintaining the current primary SMTP address.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupId,

        [Parameter(Mandatory=$true)]
        [string]$CurrentPrimarySmtpAddress,

        [Parameter(Mandatory=$false)]
        [string]$NewPrimaryAddress,

        [Parameter(Mandatory=$false)]
        [array]$ProxyAddresses
    )

    begin {
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
            'content-type' = 'application/json; charset=utf-8'
        }

        $aliases = $ProxyAddresses | Where-Object {
            $_ -cnotlike 'SMTP:*'
        }

        if ([string]::IsNullOrEmpty($NewPrimaryAddress)) {
            $NewPrimaryAddress = $CurrentPrimarySmtpAddress
        }

        $body = @{
            CurrentPrimarySmtpAddress = $CurrentPrimarySmtpAddress
            GroupId = $GroupId
            NewPrimarySmtpAddress = $NewPrimaryAddress
            RawAliasesList = @($aliases)
            SecondarySmtpAddresses = @()
        } | ConvertTo-Json
    }

    process {
        if ($PSCmdlet.ShouldProcess($GroupId, "Updating email addresses")) {
            Write-Verbose "Updating primary email for $GroupId to $NewPrimaryAddress and aliases to $($aliases -join ',')"

            $uri = "https://admin.microsoft.com/admin/api/groups/UpdateEmailAddresses"

            try {
                $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
                Write-Output $response
            }
            catch {
                Throw "Failed to update email addresses for group '$GroupId': $_"
            }
        }
    }
}