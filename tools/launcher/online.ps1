param([string]$Ini, [switch]$ClearOnly)
# Used by play.bat: reads the Online choice that Resident Doom saved in GZDoom's
# settings file (main menu > Online, RE_Online.zs), prints it as REQ= / REQMAP= /
# REQADDR= lines, and clears re_net_request in the file, so the same choice is
# never used twice (no relaunch loop). -ClearOnly just clears it. Only that one
# line changes; the rest of the file is kept byte for byte.
if (-not $Ini -or -not (Test-Path -LiteralPath $Ini)) { exit 0 }
$text = [IO.File]::ReadAllText($Ini)
function Value($key) {
    $m = [regex]::Match($text, '(?m)^' + $key + '=([^\r\n]*)')
    if ($m.Success) { return $m.Groups[1].Value } else { return '' }
}
if (-not $ClearOnly) {
    'REQ=' + ((Value 're_net_request') -replace '[^a-z]', '')
    'REQMAP=' + ((Value 're_net_map') -replace '[^A-Za-z0-9]', '')
    # only characters an address can have, so nothing typed can break the command line
    'REQADDR=' + ((Value 're_net_address') -replace '[^A-Za-z0-9.:\-\[\]]', '')
}
$new = [regex]::Replace($text, '(?m)^re_net_request=[^\r\n]*', 're_net_request=')
if ($new -ne $text) { [IO.File]::WriteAllText($Ini, $new, (New-Object Text.UTF8Encoding $false)) }
