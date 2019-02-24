class GitterBackend : Backend {
    # Constructor
    GitterBackend ([string]$Token, [string]$RoomId) {
        $config = [ConnectionConfig]::new()
        $secToken = $Token | ConvertTo-SecureString -AsPlainText -Force
        $config.Credential = New-Object System.Management.Automation.PSCredential('asdf', $secToken)
        $config.Endpoint = $RoomId
        $conn = [GitterConnection]::New()
        $conn.Config = $config
        $this.Connection = $conn
    }

    # Connect to the chat network
    [void]Connect() {
        $this.LogInfo('Connecting to backend...')
        $this.Connection.Connect()
        $this.BotId = $this.GetBotIdentity()
        $this.LoadUsers()
    }

    # Disconnect from the chat network
    [void]Disconnect() {
        # Include logic to disconnect to the chat network

        # The actual logic to disconnect to the chat network
        # should be in the [Connection] object
        $this.Connection.Disconnect()
    }

    # Send a ping on the chat network
    [void]Ping() {
        # Only implement this method to send a message back
        # to the chat network to keep the connection open

        # If N/A, you don't need to implement this
    }

    # Receive a message from the chat network
    [Message[]]ReceiveMessage() {
        $messages = New-Object -TypeName System.Collections.ArrayList

        try {
            # Read the output stream from the receive job and get any messages since our last read
            [string[]]$jsonResults = $this.Connection.ReadReceiveJob()

            foreach ($jsonResult in $jsonResults) {
                if ($null -ne $jsonResult -and $jsonResult -ne [string]::Empty) {
                    #Write-Debug -Message "[SlackBackend:ReceiveMessage] Received `n$jsonResult"
                    $this.LogDebug('Received message', $jsonResult)

                    $gitterMessage = @($jsonResult | ConvertFrom-Json)

                    $msg = [Message]::new()
                    $msg.From = $gitterMessage.fromUser.id
                    $msg.Text = $gitterMessage.text
                    $msg.Time = $gitterMessage.sent

                    # ** Important safety tip, don't cross the streams **
                    # Only return messages that didn't come from the bot
                    # else we'd cause a feedback loop with the bot processing
                    # it's own responses
                    if (-not $this.MsgFromBot($msg.From)) {
                        $messages.Add($msg) > $null
                    }
                }
            }
        } catch {
            Write-Error $_
        }

        return $messages
    }

    # Return a user object given an Id
    [Person]GetUser([string]$UserId) {
        $user = $this.Users[$UserId]
        if (-not $user) {
            $this.LogDebug([LogSeverity]::Warning, "User [$UserId] not found. Refreshing users")
            $this.LoadUsers()
            $user = $this.Users[$UserId]
        }

        if ($user) {
            $this.LogDebug("Resolved user [$UserId]", $user)
        } else {
            $this.LogDebug([LogSeverity]::Warning, "Could not resolve user [$UserId]")
        }
        return $user
    }

    # Get all user info by their ID
    [hashtable]GetUserInfo([string]$UserId) {
        $user = $null
        if ($this.Users.ContainsKey($UserId)) {
            $user = $this.Users[$UserId]
        } else {
            $this.LogDebug([LogSeverity]::Warning, "User [$UserId] not found. Refreshing users")
            $this.LoadUsers()
            $user = $this.Users[$UserId]
        }

        if ($user) {
            $this.LogDebug("Resolved [$UserId] to [$($user.UserName)]")
            return $user.ToHash()
        } else {
            $this.LogDebug([LogSeverity]::Warning, "Could not resolve channel [$UserId]")
            return $null
        }
    }

    # Add a reaction to an existing chat message
    [void]AddReaction([Message]$Message, [ReactionType]$Type, [string]$Reaction) {
        $this.LogDebug("Reactions are not yet supported in Gitter - Ignoring")
        # TODO: Must build out once Gitter supports it.
    }

    # Remove a reaction from an existing chat message
    [void]RemoveReaction([Message]$Message, [ReactionType]$Type, [string]$Reaction) {
        $this.LogDebug("Reactions are not yet supported in Gitter - Ignoring")
        # TODO: Must build out once Gitter supports it.
    }

    # Send a message back to Gitter
    [void]SendMessage([Response]$Response) {
        # Process any custom responses
        $this.LogVerbose("[$($Response.Data.Count)] custom responses")
        $NL = [System.Environment]::NewLine
        foreach ($customResponse in $Response.Data) {
            [string]$sendTo = $Response.To
            if ($customResponse.DM) {
                $sendTo = "@$($this.UserIdToUsername($Response.MessageFrom))"
            }

            switch -Regex ($customResponse.PSObject.TypeNames[0]) {
                '(.*?)PoshBot\.Card\.Response' {
                    $this.LogDebug('Custom response is [PoshBot.Card.Response]')
                    $t = '```' + $NL + $customResponse.Text + '```'
                    $this.SendGitterMessage($t)
                    break
                }
                '(.*?)PoshBot\.Text\.Response' {
                    $this.LogDebug('Custom response is [PoshBot.Text.Response]')
                    $t = '```' + $NL + $customResponse.Text + '```'
                    $this.SendGitterMessage($t)
                    break
                }
                '(.*?)PoshBot\.File\.Upload' {
                    $this.LogDebug('Custom response is [PoshBot.File.Upload]')
                    $this.LogVerbose('Not currently implemented')
                    break
                }
            }
        }

        if ($Response.Text.Count -gt 0) {
            foreach ($t in $Response.Text) {
                $this.LogDebug("Sending response back to Gitter channel [$($Response.To)]", $t)
                $t = '```' + $NL + $t + '```'
                $this.SendGitterMessage($t)
            }
        }
    }

    [void]SendGitterMessage([string]$message) {
        $token = $this.Connection.Config.Credential.GetNetworkCredential().Password
        $roomId = $this.Connection.Config.Endpoint
        $restParams = @{
            Method = 'Post'
            ContentType = 'application/json'
            Verbose     = $false
            Headers     = @{
                Authorization = "Bearer $($token)"
            }
            Uri         = "https://api.gitter.im/v1/rooms/$roomId/chatMessages"
            Body = @{
                text = "$message"
            } | ConvertTo-Json
        }

        $gitterResponse = Invoke-RestMethod @restParams
    }

    # Resolve a user name to user id
    [string]UsernameToUserId([string]$Username) {
        $Username = $Username.TrimStart('@')
        $user = $this.Users.Values | Where-Object {$_.UserName -eq $Username}
        $id = $null

        if ($user) {
            $id = $user.Id
        } else {
            # User each doesn't exist or is not in the local cache
            # Refresh it and try again
            $this.LogDebug([LogSeverity]::Warning, "User [$Username] not found. Refreshing users")
            $this.LoadUsers()
            $user = $this.Users.Values | Where-Object {$_.Nickname -eq $Username}

            if (-not $user) {
                $id = $null
            } else {
                $id = $user.Id
            }
        }
        if ($id) {
            $this.LogDebug("Resolved [$Username] to [$id]")
        } else {
            $this.LogDebug([LogSeverity]::Warning, "Could not resolve user [$Username]")
        }

        return $id
    }

    # Resolve a user ID to a username/nickname
    [string]UserIdToUsername([string]$UserId) {
        $name = $null
        if ($this.Users.ContainsKey($UserId)) {
            $name = $this.Users[$UserId].UserName
        } else {
            $this.LogDebug([LogSeverity]::Warning, "User [$UserId] not found. Refreshing users")
            $this.LoadUsers()
            $name = $this.Users[$UserId].UserName
        }

        if ($name) {
            $this.LogDebug("Resolved [$UserId] to [$name]")
        } else {
            $this.LogDebug([LogSeverity]::Warning, "Could not resolve user [$UserId]")
        }

        return $name
    }

    # Get the bot identity Id
    [string]GetBotIdentity() {
        $id = $this.Connection.LoginData.id
        $this.LogVerbose("Bot identity is [$id]")
        return $id
    }

    # Determine if incoming message was from the bot
    [bool]MsgFromBot([string]$From) {
        $frombot = ($this.BotId -eq $From)
        if ($fromBot) {
            $this.LogDebug("Message is from bot [From: $From == Bot: $($this.BotId)]. Ignoring")
        } else {
            $this.LogDebug("Message is not from bot [From: $From <> Bot: $($this.BotId)]")
        }
        return $fromBot
    }

    [void]LoadUsers() {
        $this.LogVerbose('Getting Gitter Room Users...')

        $token = $this.Connection.Config.Credential.GetNetworkCredential().Password
        $roomId = $this.Connection.Config.Endpoint
        $restParams = @{
            ContentType = 'application/json'
            Verbose     = $false
            Headers     = @{
                Authorization = "Bearer $($token)"
            }
            Uri         = "https://api.gitter.im/v1/rooms/$roomId/users"
        }

        $allUsers = Invoke-RestMethod @restParams

        $this.LogVerbose("[$($allUsers.Count)] users returned")
        $allUsers | ForEach-Object {
            $user = [GitterPerson]::new()
            $user.Id = $_.id
            $user.UserName = $_.username
            $user.DisplayName = $_.displayname
            $user.Url = $_.url
            $user.AvatarUrl = $_.avatarUrl
            $user.AvatarUrlSmall = $_.avatarUrlSmall
            $user.AvatarUrlMedium = $_.avatarUrlMedium
            $user.Role = $_.role
            $user.V = $_.v
            $user.GV = $_.gv
            if (-not $this.Users.ContainsKey($_.ID)) {
                $this.LogDebug("Adding user [$($_.ID):$($_.Name)]")
                $this.Users[$_.ID] = $user
            }
        }

        foreach ($key in $this.Users.Keys) {
            if ($key -notin $allUsers.ID) {
                $this.LogDebug("Removing outdated user [$key]")
                $this.Users.Remove($key)
            }
        }
    }
}
