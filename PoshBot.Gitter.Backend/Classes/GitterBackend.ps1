
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
        $this.LogInfo('Connecting to backend')
        $this.Connection.Connect()
        $this.BotId = $this.GetBotIdentity()
        $this.LoadUsers()
        $this.LoadRooms()
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
    [Message]ReceiveMessage() {
        # Implement logic to receive a message from the
        # chat network using network-specific APIs.

        # This method assumes that a connection to the chat network
        # has already been made using $this.Connect()

        # This method should return quickly (no blocking calls)
        # so PoshBot can continue in its message processing loop
        return $null
    }

    # Send a message back to the chat network
    [void]SendMessage([Response]$Response) {
        # Implement logic to send a message
        # back to the chat network
    }

    # Return a user object given an Id
    [Person]GetUser([string]$UserId) {
        # Return a [Person] instance (or a class derived from [Person])
        return $null
    }

    # Resolve a user name to user id
    [string]UsernameToUserId([string]$Username) {
        # Do something using the chat network APIs to
        # resolve a username to an Id and return it
        return '12345'
    }

    # Resolve a user ID to a username/nickname
    [string]UserIdToUsername([string]$UserId) {
        # Do something using the network APIs to
        # resolve a username from an Id and return it
        return 'JoeUser'
    }

    [void]LoadUsers() {
        $this.LogDebug('Getting Gitter Room Users')

        #$allUsers = Get-Slackuser -Token $this.Connection.Config.Credential.GetNetworkCredential().Password -Verbose:$false

        $token = $this.Config.Credential.GetNetworkCredential().Password
        $roomId = $this.Config.Endpoint
        $restParams = @{
            ContentType = 'application/json'
            Verbose = $false
            Headers = @{
                Authorization = "Bearer $($token)"
            }
            Uri = "https://api.gitter.im/v1/rooms/$roomId/users"
        }
        $allUsers = Invoke-RestMethod @restParams

        $this.LogDebug("[$($allUsers.Count)] users returned")
        $allUsers | ForEach-Object {
            $user = [GitterPerson]::new()
            $user.Id = $_.id
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
                $this.Users[$_.ID] =  $user
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
