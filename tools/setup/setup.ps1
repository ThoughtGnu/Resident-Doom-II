# setup.ps1 - builds a fresh copy of Resident Doom from your own game files.
# Run it with setup.bat (double-click). It:
#   1. finds (or asks for) your GOG Resident Evil folder and your doom2.wad
#   2. checks they're the right files
#   3. builds the converter (with the C# compiler that comes with Windows)
#   4. rebuilds every model, picture and sound from your RE1 files into mod\
#   5. downloads GZDoom 4.14.2 into tools\gzdoom (checked by its fingerprint)
#   6. takes the Level Select pictures (GZDoom opens for a minute or two)
# Nothing is installed on your PC and your game folders are only read.
#
# Options (for setup.bat too):
#   -RE1 <folder>      the Resident Evil folder (the one with ResidentEvil.exe and USA)
#   -DoomWad <file>    your doom2.wad
#   -GZDoom <folder>   use a GZDoom 4.14.2 you already have instead of downloading it
#   -Force             build everything again, even what's already there
#   -NoCapture         skip the Level Select pictures (plain cards are shown instead)
#   -Yes               never ask (fail with a message instead); for scripted runs

param([string]$RE1 = '', [string]$DoomWad = '', [string]$GZDoom = '', [switch]$Force, [switch]$NoCapture, [switch]$Yes)

$ErrorActionPreference = 'Stop'
$Game = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Log = Join-Path $Game 'setup-log.txt'
try { Start-Transcript -Path $Log -Force | Out-Null } catch { }

$GZVersion = 'g4.14.2'
$GZUrl = 'https://github.com/ZDoom/gzdoom/releases/download/g4.14.2/gzdoom-4-14-2-windows.zip'
$GZSha256 = '6D01C5BB48610CEBFA9DFD0B7705A1E20BFD56032A74484AC256D8C4E3C51BEE'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Step($msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }
function Done {
    try { Stop-Transcript | Out-Null } catch { }
}
function Fail($msg) {
    Write-Host ''
    Write-Host "SETUP STOPPED: $msg" -ForegroundColor Red
    Write-Host "(Everything setup printed is also in setup-log.txt.)" -ForegroundColor DarkGray
    Done
    exit 1
}

Say 'Resident Doom setup' 'White'
Say "Game folder: $Game"
if ($Game -match '[^\x20-\x7E]') { Say 'Note: the game folder path has unusual characters; if anything fails, move the folder to a simple path like C:\Games\Resident-Doom.' 'Yellow' }

# --- 1. find the game files ------------------------------------------------
function Test-RE1($f) {
    if (-not $f -or -not (Test-Path -LiteralPath $f)) { return $false }
    if (Test-Path -LiteralPath (Join-Path $f 'USA\Players')) { return $true }
    return (Split-Path -Leaf $f) -ieq 'USA' -and (Test-Path -LiteralPath (Join-Path $f 'Players'))
}

function Find-RE1 {
    $roots = @(${env:ProgramFiles(x86)}, $env:ProgramFiles, 'C:\', 'D:\', 'E:\') | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $subs = @('GOG Galaxy\Games\Resident Evil', 'GOG Games\Resident Evil', 'Games\Resident Evil', 'GOG.com\Resident Evil')
    foreach ($r in $roots) { foreach ($s in $subs) { $c = [IO.Path]::Combine($r, $s); if (Test-RE1 $c) { return $c } } }
    return ''
}

function Steam-Libraries {
    $libs = @()
    foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        try {
            $sp = (Get-ItemProperty -Path $k -ErrorAction Stop)
            $path = if ($sp.SteamPath) { $sp.SteamPath } else { $sp.InstallPath }
            if ($path) { $libs += $path.Replace('/', '\') }
        } catch { }
    }
    foreach ($l in @($libs)) {
        $vdf = [IO.Path]::Combine($l, 'steamapps\libraryfolders.vdf')
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\', '\') }
        }
    }
    return $libs | Select-Object -Unique
}

function Find-Doom2 {
    $c = @()
    foreach ($r in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, 'C:\', 'D:\', 'E:\') | Where-Object { $_ -and (Test-Path -LiteralPath $_) }) {
        $c += [IO.Path]::Combine($r, 'GOG Galaxy\Games\DOOM + DOOM II\doom2.wad')
        $c += [IO.Path]::Combine($r, 'GOG Games\DOOM + DOOM II\doom2.wad')
        $c += [IO.Path]::Combine($r, 'GOG Galaxy\Games\DOOM II\doom2\DOOM2.WAD')
        $c += [IO.Path]::Combine($r, 'GOG Galaxy\Games\DOOM II\DOOM2.WAD')
        $c += [IO.Path]::Combine($r, 'GOG Games\DOOM II\doom2\DOOM2.WAD')
    }
    foreach ($l in Steam-Libraries) {
        $c += [IO.Path]::Combine($l, 'steamapps\common\Ultimate Doom\rerelease\DOOM2.WAD')
        $c += [IO.Path]::Combine($l, 'steamapps\common\Doom 2\rerelease\DOOM2.WAD')
        $c += [IO.Path]::Combine($l, 'steamapps\common\Doom 2\base\DOOM2.WAD')
        $c += [IO.Path]::Combine($l, 'steamapps\common\Doom 2\masterbase\doom2\DOOM2.WAD')
    }
    foreach ($f in $c) { if (Test-Path -LiteralPath $f) { return $f } }
    return ''
}

function Ask-Folder($title) {
    if ($Yes) { return '' }
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $title
    if ($d.ShowDialog() -eq 'OK') { return $d.SelectedPath }
    return ''
}

function Ask-File($title) {
    if ($Yes) { return '' }
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = $title
    $d.Filter = 'DOOM II (doom2.wad)|doom2.wad;DOOM2.WAD|WAD files (*.wad)|*.wad'
    if ($d.ShowDialog() -eq 'OK') { return $d.FileName }
    return ''
}

Step 'Finding your game files'
if (-not $RE1) { $RE1 = Find-RE1 }
if (-not $RE1) {
    Say 'Resident Evil (GOG) was not found in the usual places. Please pick its folder (the one with ResidentEvil.exe and a USA folder).' 'Yellow'
    $RE1 = Ask-Folder 'Pick your GOG Resident Evil folder (it contains ResidentEvil.exe and USA)'
}
if (-not $RE1) { Fail 'No Resident Evil folder. Install Resident Evil from GOG, then run setup again (or run setup.bat -RE1 "<folder>").' }
if (-not (Test-RE1 $RE1)) { Fail "This isn't the Resident Evil folder: $RE1. Pick the folder that contains ResidentEvil.exe and a USA folder." }
if ((Split-Path -Leaf $RE1) -ieq 'USA') { $RE1 = Split-Path -Parent $RE1 }
Say "Resident Evil: $RE1"

if (-not $DoomWad) { $DoomWad = Find-Doom2 }
if (-not $DoomWad) {
    Say 'doom2.wad was not found in the usual places. Please pick it (from your GOG or Steam DOOM II, or DOOM + DOOM II).' 'Yellow'
    $DoomWad = Ask-File 'Pick your doom2.wad'
}
if (-not $DoomWad) { Fail 'No doom2.wad. Install DOOM II (or DOOM + DOOM II) from GOG or Steam, then run setup again (or run setup.bat -DoomWad "<file>").' }
if (-not (Test-Path -LiteralPath $DoomWad -PathType Leaf)) { Fail "doom2.wad not found: $DoomWad" }
Say "DOOM II: $DoomWad"

# --- 2./3. build the converter and check the files -------------------------
Step 'Building the converter'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { Fail "Windows' C# compiler (.NET Framework 4) wasn't found. It comes with Windows 10 and 11; on older Windows, install .NET Framework 4.8 from Microsoft and run setup again." }
$conv = Join-Path $Game 'tools\re1convert'
Push-Location $conv
& $csc /nologo /optimize /out:re1convert.exe *.cs
$built = $LASTEXITCODE
Pop-Location
if ($built -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $conv 're1convert.exe'))) { Fail 'The converter did not build (see the messages above).' }
$exe = Join-Path $conv 're1convert.exe'
Say 'Converter built.'

Step 'Checking your game files'
& $exe check $RE1 $DoomWad
if ($LASTEXITCODE -ne 0) { Fail 'Your game files did not pass the check (see PROBLEM lines above).' }

# doom2.wad (and id24res.wad from the 2024 release) into iwad\, so the launchers find them
$iwad = Join-Path $Game 'iwad'
New-Item -ItemType Directory -Force $iwad | Out-Null
Copy-Item -LiteralPath $DoomWad (Join-Path $iwad 'doom2.wad') -Force
$id24 = Join-Path (Split-Path -Parent $DoomWad) 'id24res.wad'
if (Test-Path -LiteralPath $id24) { Copy-Item -LiteralPath $id24 (Join-Path $iwad 'id24res.wad') -Force }
elseif (Test-Path -LiteralPath (Join-Path $iwad 'id24res.wad')) { Remove-Item -LiteralPath (Join-Path $iwad 'id24res.wad') -Force }

# --- 4. rebuild everything -------------------------------------------------
Step 'Building the models, pictures and sounds from your RE1 files'
$mod = Join-Path $Game 'mod'
& $exe all $RE1 $DoomWad $mod
if ($LASTEXITCODE -ne 0) { Fail 'Building the game files failed (the step that failed is named above).' }
$missing = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.txt') | Where-Object { $_ -and -not $_.StartsWith('#') } | Where-Object { -not (Test-Path -LiteralPath (Join-Path $mod $_)) }
if ($missing) { Fail ("These files were not built: " + (($missing | Select-Object -First 5) -join ', ') + $(if ($missing.Count -gt 5) { " and $($missing.Count - 5) more" } else { '' })) }
Say 'All game files built.' 'Green'

# --- 5. GZDoom 4.14.2 ---------------------------------------------------------
Step 'GZDoom 4.14.2'
$gzDir = Join-Path $Game 'tools\gzdoom'
$gzExe = Join-Path $gzDir 'gzdoom.exe'
function GZ-Version($e) { if (Test-Path -LiteralPath $e) { return (Get-Item -LiteralPath $e).VersionInfo.FileVersion } return '' }
if ($GZDoom) {
    $src = if (Test-Path -LiteralPath $GZDoom -PathType Leaf) { Split-Path -Parent $GZDoom } else { $GZDoom }
    $v = GZ-Version (Join-Path $src 'gzdoom.exe')
    if (-not $v) { Fail "No gzdoom.exe in $src." }
    if (-not $v.StartsWith($GZVersion)) { Fail "That GZDoom is version $v; Resident Doom needs GZDoom 4.14.2. Run setup without -GZDoom to download it." }
    if ((Resolve-Path -LiteralPath $src).Path -ne (Join-Path $Game 'tools\gzdoom')) {
        New-Item -ItemType Directory -Force $gzDir | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $gzDir -Recurse -Force -Exclude '*.ini', 'Save', 'savegames'
    }
    Say "Using your GZDoom ($v)."
} elseif (-not $Force -and (GZ-Version $gzExe).StartsWith($GZVersion)) {
    Say 'GZDoom 4.14.2 is already there.'
} else {
    $dl = Join-Path $PSScriptRoot 'download'
    New-Item -ItemType Directory -Force $dl | Out-Null
    $zip = Join-Path $dl 'gzdoom-4-14-2-windows.zip'
    Say "Downloading $GZUrl ..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri $GZUrl -OutFile $zip
    } catch { Fail "Download failed ($($_.Exception.Message)). Check your internet connection and run setup again. Or download GZDoom 4.14.2 for Windows yourself from https://github.com/ZDoom/gzdoom/releases/tag/g4.14.2, unzip it, and run: setup.bat -GZDoom `"<that folder>`"" }
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if ($hash -ne $GZSha256) { Remove-Item -LiteralPath $zip -Force; Fail "The downloaded GZDoom doesn't match the official 4.14.2 file (fingerprint $hash). Run setup again; if it keeps happening, download it yourself and use -GZDoom." }
    New-Item -ItemType Directory -Force $gzDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $gzDir -Force
    Remove-Item -LiteralPath $zip -Force
    if (-not (GZ-Version $gzExe).StartsWith($GZVersion)) { Fail 'GZDoom did not unpack correctly. Run setup again.' }
    Say 'GZDoom 4.14.2 downloaded and checked.'
}
# portable mode: settings and saves stay in tools\gzdoom (not in your Documents folder)
$ini = Join-Path $gzDir 'gzdoom_portable.ini'
if (-not (Test-Path -LiteralPath $ini)) { New-Item -ItemType File -Path $ini | Out-Null }

# --- 6. Level Select pictures -----------------------------------------------
$lvNames = @(1..32 | ForEach-Object { 'LV{0:00}' -f $_ }) + @('LVRE', 'LVBOSS')
$haveLv = @($lvNames | Where-Object { Test-Path -LiteralPath (Join-Path $mod "graphics\$_.png") }).Count
if ($NoCapture) {
    Say ''
    Say 'Skipping the Level Select pictures (-NoCapture): Level Select shows plain cards.' 'Yellow'
} elseif (-not $Force -and $haveLv -eq $lvNames.Count) {
    Step 'Level Select pictures'
    Say 'Already there.'
} else {
    Step 'Taking the Level Select pictures'
    Say 'GZDoom opens and visits the start of every map (about 2 minutes). Please leave it alone until it closes by itself.' 'Yellow'
    $shots = Join-Path $PSScriptRoot 'shots'
    if (Test-Path -LiteralPath $shots) { Get-ChildItem -LiteralPath $shots -File | Remove-Item -Force }
    New-Item -ItemType Directory -Force $shots | Out-Null
    # GZDoom's "wait" only works inside a chain of console commands, an alias can't
    # be very long, and aliases run at startup only if they're already in the
    # settings file. So the capture gets its own settings file holding one short
    # alias per map, each calling the next, started with +rdcap.
    $steps = @()
    foreach ($i in 1..32) { $steps += , @(('map MAP{0:00}' -f $i), ('LV{0:00}' -f $i)) }
    $steps += , @('map REMAP01', 'LVRE')
    $steps += , @('re_bossfight', 'LVBOSS')
    $ini = @('[Doom.ConsoleAliases]', 'Name=rdcap', 'Command=wait 70; rdcap0')
    for ($k = 0; $k -lt $steps.Count; $k++) {
        $ini += "Name=rdcap$k"
        $ini += ('Command={0}; wait 105; screenshot tools/setup/shots/{1}.png; wait 5; rdcap{2}' -f $steps[$k][0], $steps[$k][1], ($k + 1))
    }
    $ini += "Name=rdcap$($steps.Count)"; $ini += 'Command=quit'
    $capIni = Join-Path $PSScriptRoot 'capture.ini'   # its own settings, so yours are never touched
    Set-Content -LiteralPath $capIni -Value $ini -Encoding ASCII
    $gzArgs = @('-config', "`"$capIni`"", '-iwad', 'iwad/doom2.wad', '-file', 'mod', '-nosound',
        '+vid_fullscreen', '0', '+win_w', '800', '+win_h', '500', '+re_start_view', '1', '+screenblocks', '12',
        '+crosshair', '0', '+show_messages', '0', '+re_cheat_god', '1', '+rdcap')
    $proc = Start-Process -FilePath $gzExe -ArgumentList $gzArgs -WorkingDirectory $Game -PassThru
    if (-not $proc.WaitForExit(420000)) { try { $proc.Kill() } catch { }; Say 'GZDoom took too long; stopped it.' 'Yellow' }
    Remove-Item -LiteralPath $capIni -Force -ErrorAction SilentlyContinue
    $got = @(Get-ChildItem -LiteralPath $shots -Filter 'LV*.png' -File).Count
    if ($got -gt 0) {
        & $exe levelshots $shots $mod | Out-Null
        if ($LASTEXITCODE -ne 0) { Say 'The Level Select pictures could not be converted; Level Select shows plain cards.' 'Yellow' }
    }
    if ($got -lt $lvNames.Count) { Say "Took $got of $($lvNames.Count) Level Select pictures; the rest show a plain card. (Run setup.bat -Force to try again.)" 'Yellow' }
    else { Say 'All Level Select pictures taken.' 'Green' }
}

# --- done ------------------------------------------------------------------
Write-Host ''
Write-Host 'Setup complete. Double-click play.bat to play Resident Doom.' -ForegroundColor Green
Done
exit 0
