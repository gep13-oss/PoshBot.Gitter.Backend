class GitterConnection : Connection {
    [pscustomobject]$LoginData
    [bool]$Connected
    [object]$ReceiveJob = $null

    GitterConnection() {
        # Implement any needed initialization steps
    }

    # Connect to the chat network
    [void]Connect() {
        $token = $this.Config.Credential.GetNetworkCredential().Password
        $restParams = @{
            ContentType = 'application/json'
            Verbose     = $false
            Headers     = @{
                Authorization = "Bearer $($token)"
            }
            Uri         = "https://api.gitter.im/v1/user"
        }

        $currentUser = Invoke-RestMethod @restParams
        $this.LoginData = $currentUser[0]

        if ($null -eq $this.ReceiveJob -or $this.ReceiveJob.State -ne 'Running') {
            $this.LogDebug('Connecting to Gitter Streaming API')
            $this.StartReceiveJob()
        } else {
            $this.LogDebug([LogSeverity]::Warning, 'Receive job is already running')
        }
    }

    # Disconnect from the chat network
    [void]Disconnect() {
        $this.LogInfo('Closing connection...')
        if ($this.ReceiveJob) {
            $this.LogInfo("Stopping receive job [$($this.ReceiveJob.Id)]")
            $this.ReceiveJob | Stop-Job -Confirm:$false -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
        }
        $this.Connected = $false
        $this.Status = [ConnectionStatus]::Disconnected
    }

    # Read all available data from the job
    [string]ReadReceiveJob() {
        # Read stream info from the job so we can log them
        $infoStream = $this.ReceiveJob.ChildJobs[0].Information.ReadAll()
        $warningStream = $this.ReceiveJob.ChildJobs[0].Warning.ReadAll()
        $errStream = $this.ReceiveJob.ChildJobs[0].Error.ReadAll()
        $verboseStream = $this.ReceiveJob.ChildJobs[0].Verbose.ReadAll()
        $debugStream = $this.ReceiveJob.ChildJobs[0].Debug.ReadAll()
        foreach ($item in $infoStream) {
            $this.LogInfo($item.ToString())
        }
        foreach ($item in $warningStream) {
            $this.LogInfo([LogSeverity]::Warning, $item.ToString())
        }
        foreach ($item in $errStream) {
            $this.LogInfo([LogSeverity]::Error, $item.ToString())
        }
        foreach ($item in $verboseStream) {
            $this.LogVerbose($item.ToString())
        }
        foreach ($item in $debugStream) {
            $this.LogVerbose($item.ToString())
        }

        # The receive job stopped for some reason. Reestablish the connection if the job isn't running
        if ($this.ReceiveJob.State -ne 'Running') {
            $this.LogInfo([LogSeverity]::Warning, "Receive job state is [$($this.ReceiveJob.State)]. Attempting to reconnect...")
            Start-Sleep -Seconds 5
            $this.Connect()
        }

        if ($this.ReceiveJob.HasMoreData) {
            return $this.ReceiveJob.ChildJobs[0].Output.ReadAll()
        } else {
            return $null
        }
    }

    [void]StartReceiveJob() {
        $recv = {
            [cmdletbinding()]
            param(
                [parameter(mandatory)]
                $token,
                [parameter(mandatory)]
                $roomId
            )

            # Connect to Gitter
            Write-Verbose "[GitterBackend:ReceiveJob] Connecting to RoomId [$($roomId)]"

            Add-Type -AssemblyName System.Net.Http
            $httpClient = New-Object System.Net.Http.Httpclient
            $httpClient.DefaultRequestHeaders.Add("Authorization", "Bearer $token");

            $stream = $httpClient.GetStreamAsync("https://stream.gitter.im/v1/rooms/$roomId/chatMessages").Result

            $streamReader = New-Object System.IO.StreamReader $stream

            $line = $null;
            while ($null -ne ($line = $streamReader.ReadLine()))
            {
                # Ignore heartbeat message
                if($line -ne " ") {
                    $line
                }
            }
        }

        try {
            $this.ReceiveJob = Start-Job -Name ReceiveGitterMessages -ScriptBlock $recv -ArgumentList $this.Config.Credential.GetNetworkCredential().Password, $this.Config.Endpoint -ErrorAction Stop -Verbose
            $this.Connected = $true
            $this.Status = [ConnectionStatus]::Connected
            $this.LogInfo("Started streaming API receive job [$($this.ReceiveJob.Id)]")
        } catch {
            $this.LogInfo([LogSeverity]::Error, "$($_.Exception.Message)", [ExceptionFormatter]::Summarize($_))
        }
    }
}
