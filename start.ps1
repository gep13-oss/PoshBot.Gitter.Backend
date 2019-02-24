# Import necessary modules
Import-Module PoshBot
Import-Module C:\github_local\gep13\PoshBot.Gitter.Backend\out\PoshBot.Gitter.Backend\0.1.0\PoshBot.Gitter.Backend.psm1

# Store config path in variable
$configPath = 'C:\temp\poshbot\Gitter\GitterConfig.psd1'

# Create hashtable of parameters for New-PoshBotConfiguration
$botParams = @{
    # The friendly name of the bot instance
    Name                   = 'GitterBot'
    # The primary email address(es) of the admin(s) that can manage the bot
    BotAdmins              = @('gep13')
    # Universal command prefix for PoshBot.
    # If the message includes this at the start, PoshBot will try to parse the command and
    # return an error if no matching command is found
    CommandPrefix          = '!'
    # PoshBot log level.
    LogLevel               = 'Verbose'
    # The path containing the configuration files for PoshBot
    ConfigurationDirectory = 'C:\temp\poshbot\Gitter'
    # The path where you would like the PoshBot logs to be created
    LogDirectory           = 'C:\temp\poshbot\Gitter'
    # The path containing your PoshBot plugins
    PluginDirectory        = 'c:\temp\poshbot\Plugins'

    # You will need to populate this with a Token and RoomId
    # that you would like this Backend to work with
    BackendConfiguration   = @{
        Token              = ""
        RoomId             = ""
        Name               = 'GitterBackend'
    }
}

# Create the bot backend
$backend = New-PoshBotGitterBackend -Configuration $botParams.BackendConfiguration

# Create the bot configuration
$myBotConfig = New-PoshBotConfiguration @botParams

# Save bot configuration
Save-PoshBotConfiguration -InputObject $myBotConfig -Path $configPath -Force

# Create the bot instance from the backend and configuration path
$bot = New-PoshBotInstance -Backend $backend -Path $configPath

# Start the bot
$bot | Start-PoshBot