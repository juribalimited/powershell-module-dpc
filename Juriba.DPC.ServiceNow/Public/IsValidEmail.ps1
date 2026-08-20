function IsValidEmail {
    <#
    .Synopsis
    Tests whether a string is a valid email address.

    .Description
    Returns $true when the supplied string parses as a [mailaddress], otherwise $false.

    .Parameter EmailAddress
    The string to test.

    .Outputs
    Output type [bool]

    .Example
    IsValidEmail -EmailAddress "duncan.greenshields@juriba.com"
    #>
    [OutputType([bool])]
    param([string]$EmailAddress)

    try {
        $null = [mailaddress]$EmailAddress
        return $true
    }
    catch {
        return $false
    }
}
