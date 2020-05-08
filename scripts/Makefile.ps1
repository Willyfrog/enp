# We would have preferred to put this main section to the end of the script,
# but PowerSchell script arguments must be defined as the first statement in
# a PowerShell script.
Param (
    [parameter(Position=0)]$makeRule
)

# imports
# these should be better with modules, but we would have to install them on circleci servers

# import tools
. .\scripts\tools.ps1

# import dependencies functions
. .\scripts\dependencies.ps1

################################################################################
# Appveyor related functions
################################################################################
#region

function Is-AppVeyor {
    if ($env:APPVEYOR -eq $True) {
        return $True
    }
    return $False
}

function Enable-AppVeyorRDP {
    if (-not (Is-AppVeyor)) {
        Print-Error "You are not running on AppVeyor. Enabling RDP will be bypassed."
        return
    }
    # src.: https://www.appveyor.com/docs/how-to/rdp-to-build-worker/
    $blockRdp = $true;
    iex ((new-object net.webclient).DownloadString(
        "https://raw.githubusercontent.com/appveyor/ci/master/scripts/enable-rdp.ps1"
    ))
}

#endregion

################################################################################
# enp related functions
################################################################################
#region

function Catch-Interruption {
    [console]::TreatControlCAsInput = $true
    while ($true) {
        if ([console]::KeyAvailable) {
            $key = Read-Host
            #$key = [system.console]::readkey($true)
            if (($key.modifiers -band [consolemodifiers]"control") -and
                ($key.key -eq "C")) {
                Print-Warning "Ctrl-C pressed. Cancelling the build process and restoring computer state..."
                Restore-ComputerState
                exit
            }
        }
    }
}

function Backup-ComputerState {
    $env:COM_ENP_MAKEFILE_PATH_BACKUP = $env:Path

    Push-Location "$(Get-RootDir)"
    # Needed because for native apps, PowerShell doesn't change the
    # process current path location
    #src.: https://stackoverflow.com/a/4725090/3514658
    [Environment]::CurrentDirectory = $PWD

    # Refresh path because it might have been made durty in the current shell
    # Refresh-Path
}

function Restore-ComputerState {

    # Print-Info "Restoring PATH..."
    # $env:Path = $env:COM_ENP_MAKEFILE_PATH_BACKUP

    Print-Info "Restoring current working directory..."
    Pop-location
    [Environment]::CurrentDirectory = $PWD

    # Remove all COM_ENP_MAKEFILE_ prefixed env variable
    foreach ($item in (Get-Item -Path Env:*)) {
        if ($item.Name -imatch 'COM_ENP_MAKEFILE_') {
            Print-Info "Removing Enp env variable: $($item.Name)..."
            Remove-Item env:\$($item.Name)
        }
    }
}


function Optimize-Build {
    Print-Info "Checking if Windows Search is running..."
    if ((Get-Service -Name "Windows Search").Status -eq "Running") {
        Print-Info "Windows Search is running. Disabling it..."
        Stop-Service "Windows Search"
        Print-Warning "WARNING: This makefile disabled Windows Search, to reenable it, type in an administror Powershell: Start-Service ""Windows Search"""
    } else {
        Print-Info "Windows Search has already been disabled."
    }

    Print-Info "Checking if Windows Defender realtime protection is active..."
    if (!(Get-MpPreference).DisableRealtimeMonitoring) {
        Print-Info "Windows Defender realtime protection is active. Disabling it..."
        Set-MpPreference -DisableRealtimeMonitoring $true
        Print-Warning "WARNING: This makefile disabled Windows Defender realtime protection, to reenable it, type in an administror Powershell: Set-MpPreference -DisableRealtimeMonitoring `$false"
    } else {
        Print-Info "Windows Defender realtime protection has already been disabled."
    }
}

function Run-BuildId {
    Print-Info -NoNewLine "Getting build date..."
    $env:COM_ENP_MAKEFILE_BUILD_DATE = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    Print " [$env:COM_ENP_MAKEFILE_BUILD_DATE]"

        # Prepend the PATH with wix dir
    Print-Info "Checking if wix dir is already in the PATH..."
    $env:Path = "$(Get-WixDir)" + ";" + $env:Path

    # Prepend the PATH with signtool dir
    Print-Info "Checking if signtool dir is already in the PATH..."
    $env:Path = "$(Get-SignToolDir)" + ";" + $env:Path

    $version = "$(jq -r '.version' package.json)"
    $winVersion = "$($version -Replace '-','.' -Replace '[^0-9.]')"

    Print-Info "Checking build id tag validity... [$version]"
    [version]$appVersion = New-Object -TypeName System.Version
    [void][version]::TryParse($winVersion, [ref]$appVersion)
    if (!($appVersion)) {
        # if we couldn't parse, it might be a -develop or something similar, so we just add a 
        # number there that will change overtime. Most likely this is a PR to be tested
        $revision = "$(git rev-list --all --count)"
        $winVersion = "$($version -Replace '-.*').${revision}"
        [void][version]::TryParse($winVersion, [ref]$appVersion)
        if (!($appVersion)) {
            Print-Error "Non parsable tag detected. Fallbacking to version 0.0.0."
            $version = "0.0.0"
        }
    }

    Print-Info -NoNewLine "Getting build id version..."
    $env:COM_ENP_MAKEFILE_BUILD_ID = "$version"
    Print " [$env:COM_ENP_MAKEFILE_BUILD_ID]"

    Print-Info -NoNewLine "Getting build id version for msi..."
    $env:COM_ENP_MAKEFILE_BUILD_ID_MSI = $winVersion.Split('.')[0..3] -Join '.'
    Print " [$env:COM_ENP_MAKEFILE_BUILD_ID_MSI]"

    Print-Info -NoNewLine "Getting build id version for node/npm..."
    $env:COM_ENP_MAKEFILE_BUILD_ID_NODE = $version
    Print " [$env:COM_ENP_MAKEFILE_BUILD_ID_NODE]"

    Print-Info "Patching version from msi xml descriptor..."
    $msiDescriptorFileName = "scripts\msi_installer.wxs"
    $msiDescriptor = [xml](Get-Content $msiDescriptorFileName)
    $msiDescriptor.Wix.Product.Version = [string]$env:COM_ENP_MAKEFILE_BUILD_ID_MSI
    $ComponentDownload = $msiDescriptor.CreateElement("Property", "http://schemas.microsoft.com/wix/2006/wi")
    $ComponentDownload.InnerText = "https://releases.enp.com/desktop/$version/enp-desktop-$version-`$(var.Platform).msi"
    $ComponentDownload.SetAttribute("Id", "ComponentDownload")
    $msiDescriptor.Wix.Product.AppendChild($ComponentDownload)
    $msiDescriptor.Save($msiDescriptorFileName)
    Print-Info "Modified Wix XML"
}

function Run-BuildElectron {
    Print-Info "Installing nodejs/electron dependencies (running yarn install)..."
    yarn.cmd install
    #npm install --prefix="$(Get-RootDir)" "$(Get-RootDir)"
    Print-Info "Building nodejs/electron code (running yarn run compile)..."
    yarn run compile
    #npm run build --prefix="$(Get-RootDir)" "$(Get-RootDir)"
    Print-Info "Packaging nodejs/electron for Windows (running yarn run package:windows)..."
    yarn run package:windows
}

function Run-BuildMsi {
    Print-Info "Building 32 bits msi installer..."
    heat.exe dir "dist\win-ia32-unpacked\" -o "scripts\msi_installer_files.wxs" -scom -frag -srd -sreg -gg -cg EnpDesktopFiles -t "scripts\msi_installer_files_replace_id.xslt" -dr INSTALLDIR
    candle.exe -dPlatform=x86 "scripts\msi_installer.wxs" "scripts\msi_installer_files.wxs" -o "scripts\"
    light.exe "scripts\msi_installer.wixobj" "scripts\msi_installer_files.wixobj" -loc "resources\windows\msi_i18n\en_US.wxl" -o "dist\enp-desktop-$($env:COM_ENP_MAKEFILE_BUILD_ID)-x86.msi" -b "dist\win-ia32-unpacked\"

    Print-Info "Building 64 bits msi installer..."
    heat.exe dir "dist\win-unpacked\" -o "scripts\msi_installer_files.wxs" -scom -frag -srd -sreg -gg -cg EnpDesktopFiles -t "scripts\msi_installer_files_replace_id.xslt" -t "scripts\msi_installer_files_set_win64.xslt" -dr INSTALLDIR
    candle.exe -dPlatform=x64 "scripts\msi_installer.wxs" "scripts\msi_installer_files.wxs" -o "scripts\"
    light.exe "scripts\msi_installer.wixobj" "scripts\msi_installer_files.wixobj" -loc "resources\windows\msi_i18n\en_US.wxl" -o "dist\enp-desktop-$($env:COM_ENP_MAKEFILE_BUILD_ID)-x64.msi" -b "dist\win-unpacked\"
}

function Run-Build {
    Check-Deps -Verbose -Throwable
    Run-BuildId
    Run-BuildElectron
    Run-BuildMsi
}

function Run-Test {
    Check-Deps -Verbose -Throwable
    yarn test
}
#endregion

################################################################################
# Main function
################################################################################
#region
function Main {
    try {
        if ($makeRule -eq $null) {
            Print-Info "No argument passed to the make file. Executing ""all"" rule."
            $makeRule = "all"
        }

        Backup-ComputerState

        switch ($makeRule.toLower()) {
            "all" {
                Install-Deps
                Run-Build
            }
            "build" {
                Run-Build
            }
            "test" {
                Run-Test
            }
            "install-deps" {
                Install-Deps
            }
            "optimize" {
                Optimize-Build
            }
            "debug" {
                Enable-AppVeyorRDP
            }
            default {
                Print-Error "Makefile argument ""$_"" is invalid. Build process aborted."
            }
        }

        $env:COM_ENP_MAKEFILE_EXECUTION_SUCCESS = $true
        $exitcode = 0

    } catch {
        switch ($_.Exception.Message) {
            "com.enp.makefile.deps.missing" {
                Print-Error "The following dependencies are missing: $($missing -Join ', ').`n    Please install dependencies as an administrator:`n    # makefile.ps1 install-deps"
                $exitcode = -1
            }
            "com.enp.makefile.deps.notadmin" {
                Print-Error "Installing dependencies requires admin privileges. Operation aborted.`n    Please reexecute this makefile as an administrator:`n    # makefile.ps1 install-deps"
                $exitcode = -2
            }
            "com.enp.makefile.deps.wix" {
                Print-Error "There was nothing wrong with your source code,but we found a problem installing wix toolset and couldn't continue. please try re-running the job."
                $exitcode = -3
            }   
            default {          
                Print-Error "Another error occurred: $_"
                $exitcode = -100
            }
        }
    } finally {
        if (!($env:COM_ENP_MAKEFILE_EXECUTION_SUCCESS)) {
            Print-Warning "Makefile interrupted by Ctrl + C or by another interruption handler."
        }
        Restore-ComputerState
        exit $exitcode
    }
}

Main
#endregion

