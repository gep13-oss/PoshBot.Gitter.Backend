
function New-PoshBotGitterBackend {
    <#
    .SYNOPSIS
        Creates a new instance of the Gitter PoshBot backend class.
    .DESCRIPTION
        Creates a new instance of the Gitter PoshBot backend class.
    .PARAMETER Configuration
        Hashtable of required properties needed by the backend to initialize and
        connect to the backend chat network.
    .EXAMPLE
        PS C:\> $config = @{Name = 'GitterBackend'; Token = '<API-TOKEN>'; RoomId = '<ROOM-ID>'}
        PS C:\> $backend = New-PoshBotGitterBackend -Configuration $config

        Create a hashtable containing required properties for the backend
        and create a new backend instance from them
    .INPUTS
        hashtable
    .OUTPUTS
        GitterBackend
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function', Target='*')]
    [cmdletbinding()]
    param(
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('BackendConfiguration')]
        [hashtable[]]$Configuration
    )

    process {
        foreach ($item in $Configuration) {
            if (-not $item.Token) {
                throw 'Configuration is missing [Token] parameter'
            } else {
                Write-Verbose 'Creating new Gitter backend instance'

                $backend = [GitterBackend]::new($item.Token, $item.RoomId)
                if ($item.Name) {
                    $backend.Name = $item.Name
                }
                $backend
            }
        }
    }
}

Export-ModuleMember -Function 'New-PoshBotGitterBackend'
