#requires -Version 7.0
<#
.SYNOPSIS
    Thin PowerShell wrapper around the WinCC Unified V20 GraphQL Runtime API.

.DESCRIPTION
    Discovered + verified 2026-05-19 against a PC Runtime instance serving
    `hmiDemoSCARA_ABCDE` at https://localhost/. Documented surface:
      - Endpoint:    /graphql/ (trailing slash required; no slash returns 301)
      - Auth flow:   mutation login(username, password) -> Session { token }
      - Subsequent: Authorization: Bearer <token>
      - Tag read:    query tagValues(names:[String!]!, directRead:Boolean)
      - Tag write:   mutation writeTagValues(input:[TagValueInput]!, timestamp?, quality?)
      - CSRF bypass: header `apollo-require-preflight: true` on all requests

    SSL: WinCC Unified PC Runtime uses a self-signed localhost certificate.
    Must call with `-SkipCertificateCheck` (PS7+). Also: connect only via
    `https://localhost/`, NOT the hostname — the cert is issued for `localhost`
    only and PowerShell .NET TLS will reject hostname mismatch (browser uses
    schannel renegotiation that masks this).

.EXAMPLE
    Import-Module .\WinCCUnified_GraphQL.psm1
    $sess = Connect-WinCCUnified -BaseUrl 'https://localhost' -Username 'admin' -Password 'p@ss'
    Read-WinCCUnifiedTag -Session $sess -Names @('bo_Start', 'bo_Mode')
    Write-WinCCUnifiedTag -Session $sess -Tags @{ bo_Mode = $true; bo_Start = $true }

.NOTES
    References:
      - Official: https://docs.tia.siemens.cloud/r/en-us/v20/wincc-unified-graphql-rt-unified/
      - Open-source reference impl: github.com/vogler75/winccua-mcp-server
      - Manual PDF: support.industry.siemens.com/cs/attachments/109826709/GQLWCCUenUS_en-US.pdf
#>

function Invoke-WuGraphQL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Variables,
        [string]$BearerToken
    )
    $url = ($BaseUrl.TrimEnd('/')) + '/graphql/'
    $body = @{ query = $Query }
    if ($Variables) { $body.variables = $Variables }
    $bodyJson = $body | ConvertTo-Json -Depth 10 -Compress

    $headers = @{
        'Content-Type' = 'application/json'
        'apollo-require-preflight' = 'true'
    }
    if ($BearerToken) { $headers['Authorization'] = "Bearer $BearerToken" }

    try {
        $resp = Invoke-RestMethod -Uri $url -Method POST -Body $bodyJson -Headers $headers `
            -SkipCertificateCheck -ErrorAction Stop
        return $resp
    } catch {
        throw "GraphQL POST failed: $($_.Exception.Message)"
    }
}

function Connect-WinCCUnified {
    <#
    .SYNOPSIS Login to WinCC Unified Runtime and return a session object with bearer token.
    .OUTPUTS [PSCustomObject] @{ BaseUrl; Token; Expires; User }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Password
    )
    $mutation = @'
mutation LoginUser($username: String!, $password: String!) {
  login(username: $username, password: $password) {
    token
    expires
    user { id name fullName }
    error { code description }
  }
}
'@
    $r = Invoke-WuGraphQL -BaseUrl $BaseUrl -Query $mutation -Variables @{ username = $Username; password = $Password }
    if ($r.errors) { throw "Login GraphQL errors: $($r.errors | ConvertTo-Json -Compress)" }
    $login = $r.data.login
    if (-not $login) { throw "Login returned null data" }
    if ($login.error -and $login.error.code -ne 0 -and $login.error.code -ne $null) {
        throw "Login error code=$($login.error.code) desc='$($login.error.description)'"
    }
    if (-not $login.token) { throw "Login succeeded but no token returned" }
    return [PSCustomObject]@{
        BaseUrl = $BaseUrl
        Token   = $login.token
        Expires = $login.expires
        User    = $login.user
    }
}

function Read-WinCCUnifiedTag {
    <#
    .SYNOPSIS Read one or more HMI tag values.
    .PARAMETER Session  Session object from Connect-WinCCUnified.
    .PARAMETER Names    HMI tag names (NOT PLC paths — use HMI tag-table names).
    .PARAMETER DirectRead  If TRUE, force a direct PLC read (slow). Default FALSE (cache).
    .OUTPUTS Array of {name; value; error}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Session,
        [Parameter(Mandatory)][string[]]$Names,
        [bool]$DirectRead = $false
    )
    $query = @'
query GetTagValues($names: [String!]!, $directRead: Boolean) {
  tagValues(names: $names, directRead: $directRead) {
    name
    value { value timestamp }
    error { code description }
  }
}
'@
    $r = Invoke-WuGraphQL -BaseUrl $Session.BaseUrl -Query $query `
        -Variables @{ names = $Names; directRead = $DirectRead } `
        -BearerToken $Session.Token
    if ($r.errors) { throw "tagValues errors: $($r.errors | ConvertTo-Json -Compress)" }
    return $r.data.tagValues
}

function Write-WinCCUnifiedTag {
    <#
    .SYNOPSIS Write one or more HMI tag values (bool/int/real/string).
    .PARAMETER Session  Session from Connect-WinCCUnified.
    .PARAMETER Tags     Hashtable: @{ tagName1 = $value1; tagName2 = $value2; ... }
    .OUTPUTS Array of {name; error{code; description}}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject]$Session,
        [Parameter(Mandatory)][hashtable]$Tags
    )
    $input = @()
    foreach ($k in $Tags.Keys) {
        $input += @{ name = "$k"; value = $Tags[$k] }
    }
    $mutation = @'
mutation WriteTagValues($input: [TagValueInput]!) {
  writeTagValues(input: $input) {
    name
    error { code description }
  }
}
'@
    $r = Invoke-WuGraphQL -BaseUrl $Session.BaseUrl -Query $mutation `
        -Variables @{ input = $input } `
        -BearerToken $Session.Token
    if ($r.errors) { throw "writeTagValues errors: $($r.errors | ConvertTo-Json -Compress)" }
    return $r.data.writeTagValues
}

function Get-WinCCUnifiedSession {
    <# .SYNOPSIS Probe session status (debug/sanity). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Session)
    $q = '{ session { user { name } expires } }'
    return (Invoke-WuGraphQL -BaseUrl $Session.BaseUrl -Query $q -BearerToken $Session.Token).data.session
}

function Disconnect-WinCCUnified {
    <# .SYNOPSIS Logout (invalidate the bearer token server-side). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][PSCustomObject]$Session)
    $m = 'mutation { logout(allSessions: false) }'
    return (Invoke-WuGraphQL -BaseUrl $Session.BaseUrl -Query $m -BearerToken $Session.Token).data.logout
}

Export-ModuleMember -Function Connect-WinCCUnified, Read-WinCCUnifiedTag, Write-WinCCUnifiedTag, Get-WinCCUnifiedSession, Disconnect-WinCCUnified, Invoke-WuGraphQL
