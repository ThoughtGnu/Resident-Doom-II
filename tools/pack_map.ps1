# pack_map.ps1 - turns mod\maps\src\TEXTMAP.txt into mod\maps\REMAP01.wad
# (GZDoom names a map after its file in maps\, so the file name matters.)
#
# GZDoom wants a map inside a small WAD file holding three entries
# ("lumps"): MAP01 (an empty marker), TEXTMAP (our text), and ENDMAP (an
# empty end marker). GZDoom builds everything else itself when it loads.
#
# Run it from the project folder:
#   powershell -ExecutionPolicy Bypass -File tools\pack_map.ps1

param(
    [string]$Source = "$PSScriptRoot\..\mod\maps\src\TEXTMAP.txt",
    [string]$Output = "$PSScriptRoot\..\mod\maps\REMAP01.wad",
    [string]$MapName = "REMAP01"
)

$text = [System.IO.File]::ReadAllBytes((Resolve-Path $Source))

# Lumps in order: name and contents
$lumps = @(
    @{ Name = $MapName;   Data = [byte[]]@() },
    @{ Name = "TEXTMAP";  Data = $text },
    @{ Name = "ENDMAP";   Data = [byte[]]@() }
)

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)

# Header: "PWAD", number of lumps, where the directory starts (filled later)
$bw.Write([System.Text.Encoding]::ASCII.GetBytes("PWAD"))
$bw.Write([int32]$lumps.Count)
$bw.Write([int32]0)

# Lump contents, remembering where each one starts
$offsets = @()
foreach ($l in $lumps) {
    $offsets += [int32]$ms.Position
    $bw.Write([byte[]]$l.Data)
}

# Directory: offset, size, 8-character name for each lump
$dirOffset = [int32]$ms.Position
for ($i = 0; $i -lt $lumps.Count; $i++) {
    $bw.Write([int32]$offsets[$i])
    $bw.Write([int32]$lumps[$i].Data.Length)
    $name = [System.Text.Encoding]::ASCII.GetBytes($lumps[$i].Name.PadRight(8, [char]0).Substring(0, 8))
    $bw.Write($name)
}

# Go back and fill in the directory position
$bw.Seek(8, [System.IO.SeekOrigin]::Begin) | Out-Null
$bw.Write($dirOffset)
$bw.Flush()

$outPath = [System.IO.Path]::GetFullPath($Output)
[System.IO.File]::WriteAllBytes($outPath, $ms.ToArray())
$bw.Close()
Write-Host "Wrote $outPath ($($text.Length) bytes of map text)"
