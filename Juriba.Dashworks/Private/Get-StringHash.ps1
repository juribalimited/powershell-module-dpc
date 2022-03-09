Function Get-StringHash{
    [OutputType([String])]
    Param (
        [parameter(Mandatory=$True)]
        [string]$StringToHash
        )

    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($StringToHash)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -InputStream $stringAsStream | Select-Object -property Hash).Hash
}