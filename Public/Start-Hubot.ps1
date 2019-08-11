﻿<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Start-Hubot
{
    [CmdletBinding(SupportsShouldProcess)]
    Param
    (
        # Path to the PoshHubot Configuration File
        [Parameter(Mandatory=$true)]
        [ValidateScript({
        if(Test-Path -Path $_ -ErrorAction SilentlyContinue)
        {
            return $true
        }
        else
        {
            throw "$($_) is not a valid path."
        }
        })]
        [string]
        $ConfigPath
    )

    $Config = Import-HubotConfiguration -ConfigPath $ConfigPath

    function Test-HubotRunning
    {
        [CmdletBinding()]
        Param
        (
            # Path to the PoshHubot Configuration File
            [Parameter(Mandatory=$true)]
            [ValidateScript({
            if(Test-Path -Path $_ -ErrorAction SilentlyContinue)
            {
                return $true
            }
            else
            {
                throw "$($_) is not a valid path."
            }
            })]
            [string]
            $ConfigPath
        )

        # Check if bot is already running, otherwise don't start it again
        if (Test-Path -Path $Config.PidPath)
        {
            $pidOfHubot = Get-Content -Path $Config.PidPath

            # if it exists, get the id from it and make sure that exists too
            try
            {
                $huproc = Get-Process -Id $pidOfHubot -ErrorAction Stop

                Write-Verbose "Hubot process path: $($huproc.Path)"
                Write-Verbose "Hubot process pid: $($huproc.Id)"

                return $true
            }
            catch
            {
                Write-Verbose "No process for bot found. Will bring one up"
                return $false
            }
        }
        else
        {
            return $false
        }
    }


    if (Test-HubotRunning -ConfigPath $ConfigPath)
    {
        return "Your bot $($Config.BotName) is already running."
    }
    # If the bot is not running
    else
    {
        # create log folder
        if (-not(Test-Path -Path $Config.LogPath))
        {
            New-Item -Path $Config.LogPath -ItemType directory | Out-Null
        }

        # Do an npm install incase there are any new modules
        Write-Verbose -Message "Running npm install"
        if ($PSCmdlet.ShouldProcess("ShouldProcess command: 'Start-Process -FilePath npm -ArgumentList ""install"" -Wait -NoNewWindow -WorkingDirectory $Config.BotPath'")) 
        {
            Start-Process -FilePath npm -ArgumentList "install" -Wait -NoNewWindow -WorkingDirectory $Config.BotPath
        }

        # Add the environment variables from the config
        ForEach ($envVar in $Config.EnvironmentVariables.psobject.Properties)
        {
            Write-Verbose "Setting Environment Variable $($envVar.Name)"
            if ($PSCmdlet.ShouldProcess("ShouldProcess command: 'New-Item -Path Env:\ -Name $envVar.Name -Value $envVar.Value -Force | Out-Null'.")) 
            {
                New-Item -Path Env:\ -Name $envVar.Name -Value $envVar.Value -Force | Out-Null
            }
        }

        $fileDate = Get-Date -format yyyy-M-ddTHHmmss

        $processParams = @{
            FilePath = 'cmd'
            ArgumentList = "/c forever start --uid ""$($Config.BotName)"" --pidFile ""$($Config.PidPath)"" --verbose --append -l ""$($Config.LogPath)\$($fileDate)_$($Config.BotName).log"" --sourceDir ""$($Config.BotPath)"" --workingDir ""$($Config.BotPath)"" --minUptime 100 --spinSleepTime 100 .\node_modules\coffeescript\bin\coffee .\node_modules\hubot\bin\hubot $($Config.ArgumentList)"
            NoNewWindow = $true
            WorkingDirectory = $Config.BotPath
            PassThru = $true
        }

        Write-Verbose "Start Command:"
        Write-Verbose $processParams.ArgumentList

        
        if ($PSCmdlet.ShouldProcess("ShouldProcess: Start Hubot and check that it is running.")) 
        {
            # Start Hubot
            $proc = Start-Process @processParams
            # Wait for the command prompt to close
            $proc.WaitForExit()

            # Wait a few seconds for pid to be created
            Start-Sleep -Seconds 2

            # Verify bot started ok by checking if the pid file exists
            if (Test-HubotRunning -ConfigPath $ConfigPath)
            {
                return "Your bot $($Config.BotName) is running."
            }
            else
            {
                throw "Could not find pid file at $($Config.PidPath). Check $($Config.LogPath) for logs."
            }
        }
    }
}