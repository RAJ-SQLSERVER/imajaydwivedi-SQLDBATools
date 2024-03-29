Function Get-SdtSQLInstanceInfo
{
    <#
        .SYNOPSIS
            Retrieves SQL Server instance general information.

        .DESCRIPTION
            Retrieves SQL Server instance general information based on ComputerName parameter value.

        .NOTES
            Name: Get-SdtSQLInstanceInfo
            Author: Ajay Dwivedi

        .EXAMPLE
            Get-SdtSQLInstanceInfo -ServerName $env:COMPUTERNAME

            Description
            -----------
            Retrieves SQL Server instance general information based on ComputerName parameter value.

        .LINK
            https://www.mssqltips.com/sqlservertip/2013/find-sql-server-instances-across-your-network-using-windows-powershell/
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None')]
    Param(
        <#
        [Parameter( Mandatory = $true,
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true)]
        [String[]]$ServerName
        #>
        [Parameter( Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('SqlInstance')]
        [String[]]$ServerName
    )
    BEGIN 
    {
        $Check = $false;
        $Result = @();
        $InstanceInfo = @();
    }
    PROCESS
    {
        Write-Verbose "Inside PROCESS block";
        if($_ -ne $null) {
            $ServerName = $_;
            Write-Verbose "Parameters received from PipeLine.";
        }

        # Loop through each machines
        foreach($machine in $ServerName)
        {
            Write-Verbose "Processing ServerName: $machine";
            $isManagedComputerAccessible = $true;

            # Reset with each loop
            $Discover = $true;
            $instances = @();
            if($Global:sdtPrintUserFriendlyMessage) {
                Write-Host "Starting:- Searching for instances on $machine" -ForegroundColor Yellow;
            }
            Write-Debug "Before Error"
            if ([String]::IsNullOrEmpty($machine) -or (Test-Connection -ComputerName $machine -Count 1 -Quiet) -eq $false) {
                $MessageText = "(Get-SdtSQLInstanceInfo)=> Supplied value '$machine' for ServerName parameter is invalid, or server is not accessible.";
                if($Global:sdtPrintUserFriendlyMessage) {
                    Write-Host $MessageText -ForegroundColor Red;
                }
                Continue;
            }
            else {
                $FQDN = (Get-SdtFullQualifiedDomainName -ComputerName $machine);
                $pServerName = if($FQDN  -match "^(?'ServerName'[0-9A-Za-z_-]+)\.*?.*"){$Matches['ServerName']}else{$null}
                if([String]::IsNullOrEmpty($machine)) 
                {
                    if($Global:sdtPrintUserFriendlyMessage) {
                        Write-Host "(Get-SdtFullQualifiedDomainName)=> Server '$machine' is not reachable." -ForegroundColor Red;
                    }
                    Continue;
                }
            }

            Write-Verbose "Creating ManagedComputer Object to find installed Sql Instances";
            $m = New-Object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer') "$FQDN";
            
            try{
                $InstanceNames = $m.ServerInstances.Name;
            }
            catch {
                Write-Verbose "ManagedComputer object did not return value. So trying raw method of Get-Service";
                $isManagedComputerAccessible = $false;
                $InstanceNames = @();
                Get-Service -Name *sql* -ComputerName $machine | ForEach-Object {
                    if($_.DisplayName -match "SQL Server \((?'InstanceName'\w+)\)") {
                        $InstanceNames += $Matches['InstanceName']
                    }
                }
            }

            try {
                #$productKeys = Get-DbaProductKey -ComputerName "$pServerName";
                $productKeys = Get-SqlServerProductKeys -Servers $FQDN -ErrorAction Stop;
            } 
            catch 
            {
                $returnMessage = $null;
                $formatstring = "{0} : {1}`n{2}`n" +
                            "    + CategoryInfo          : {3}`n" +
                            "    + FullyQualifiedErrorId : {4}`n"
                $fields = $_.InvocationInfo.MyCommand.Name,
                          $_.ErrorDetails.Message,
                          $_.InvocationInfo.PositionMessage,
                          $_.CategoryInfo.ToString(),
                          $_.FullyQualifiedErrorId

                $returnMessage = $formatstring -f $fields;

                $returnMessage = @"

$ErrorText
$($_.Exception.Message)


"@ + $returnMessage;
                if($SdtLogErrorToInventory) {
                    Add-SdtCollectionError -ComputerName $FQDN `
                                        -Cmdlet 'Get-DbaProductKey' `
                                        -CommandText "Get-DbaProductKey -ComputerName '$FQDN'" `
                                        -ErrorText $returnMessage;
                } 
                if ($Global:sdtPrintUserFriendlyMessage) {
                    Write-Host $returnMessage -ForegroundColor Red;
                }
            }
            
            foreach($Instance in $InstanceNames)
            {
                Write-Debug "Inside foreach block of `$InstanceNames";
                # Instantiate Server Object for SqlInstance
                $sqlInstance = if($Instance -eq 'MSSQLSERVER') {"$pServerName"} else {"$pServerName\$Instance"};
                
                $Server = New-Object Microsoft.SqlServer.Management.SMO.Server($sqlInstance);
                $info = $Server.Information;

                $CommonVersion = ($info.VersionMajor).ToString() + '.' + ($info.VersionMinor).ToString();
                $VersionString = if($CommonVersion -eq '9.0') { 'SQL Server 2005' } 
                                 elseif ($CommonVersion -eq '10.0') { 'SQL Server 2008' }
                                 elseif ($CommonVersion -eq '10.50') { 'SQL Server 2008 R2' }
                                 elseif ($CommonVersion -eq '11.0') { 'SQL Server 2012' }
                                 elseif ($CommonVersion -eq '12.0') { 'SQL Server 2014' }
                                 elseif ($CommonVersion -eq '13.0') { 'SQL Server 2016' }
                                 elseif ($CommonVersion -eq '14.0') { 'SQL Server 2017' }
                                 elseif ($CommonVersion -eq '15.0') { 'SQL Server 2019' }
                
                #$productKeys
                $productKey = ($productKeys | Where-Object {$_.InstanceName -eq $Instance}).ProductKey;
                
                $DefaultDataLocation = $Server.Settings.DefaultFile;
	            $DefaultLogLocation = $Server.Settings.DefaultLog;
	            if ($DefaultDataLocation.Length -eq 0) {
	                $DefaultDataLocation = $Server.Information.MasterDBPath
                }
	            if ($DefaultLogLocation.Length -eq 0) {
	                $DefaultLogLocation = $Server.Information.MasterDBLogPath
	            }
                $DefaultBackupLocation = $Server.Settings.BackupDirectory;
                if($isManagedComputerAccessible) {
                    $m = New-Object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') "$FQDN";
                    $port = $m.ServerInstances["$Instance"].ServerProtocols['Tcp'].IPAddresses['IPALL'].IPAddressProperties['TcpPort'].Value;
                }
                else {
                    $port = $null;
                }

                [boolean]$IsStandaloneInstance = $false;
                [boolean]$IsSqlCluster = $false;
                [boolean]$IsAgListener = $false;
                [boolean]$IsAGNode = $false;
                [string]$AGListener = $null;
                
                # If AlwaysOn feature is Installed
                if($Server.IsHadrEnabled) 
                {
                    # Find Listener name
                    $AGListener = $Server.AvailabilityGroups.AvailabilityGroupListeners[0].Name;
                    if(!([string]::IsNullOrEmpty($AGListener))) # If Listener name is not empty
                    {
                        if($AGListener -eq $pServerName) {
                            $IsAgListener = $true;
                            $AGListener = $null;
                        } else {
                            $IsAGNode = $true;
                        }
                    }
                }
                elseif ($Server.IsClustered) {
                    $IsSqlCluster = $true
                } else {
                    $IsStandaloneInstance = $true;
                }

                $instanceProps = [Ordered]@{
                        #'InstanceID' = $null;
                        #'ServerID' = $null;
                        'ServerName' = $pServerName; # Should be taken from Passed ServerName variable
                        'SqlInstance' = $sqlInstance;
                        'InstanceName' = $Instance;
                        'RootDirectory' = $info.RootDirectory;
                        'Version' = $info.VersionString;
                        'CommonVersion' = $CommonVersion;
                        'Build' = $info.BuildNumber;
                        'VersionString' = $VersionString; <# VersionString=SQL Server 2008 R2 for @@version = 10.50.4000.0 #>
                        'Edition' = $info.Edition;
                        'Collation' = $info.Collation;
                        'ProductKey' =  if($productKey -notlike "*Could not read*") {$productKey} else {$null};
                        'DefaultDataLocation' = $DefaultDataLocation;
                        'DefaultLogLocation' = $DefaultLogLocation;
                        'DefaultBackupLocation' = $DefaultBackupLocation;
                        'ErrorLogPath' = $info.ErrorLogPath;
                        'ServiceAccount' = $Server.ServiceAccount;
                        'Port' = $port;
                        'IsStandaloneInstance' = $IsStandaloneInstance;
                        'IsSqlCluster' = $IsSqlCluster;
                        'IsAgListener' = $IsAgListener;
                        'IsAGNode' = $IsAGNode;
                        'AGListenerName' = $AGListener;
                        #'HasOtherHASetup' = $null;
                        #'HARole' = $null;
                        #'HAPartner' = $null;
                        #'IsPowershellLinked' = 1;
                        #'IsDecom' = 0;
                        #'DecomDate' = $null;
                        #'CollectionDate' = (Get-Date -Format "yyyy-MM-dd HH:mm:ss");
                        #'CollectedBy' = "$($env:USERDOMAIN)\$($env:USERNAME)";
                        #'UpdatedDate' = (Get-Date -Format "yyyy-MM-dd HH:mm:ss");
                        #'UpdatedBy' = "$($env:USERDOMAIN)\$($env:USERNAME)";
                        #'Remark1' = $null;
                        #'Remark2' = $null;        
                     }
                $instanceObj = New-Object -TypeName PSObject -Property $instanceProps;
                $InstanceInfo += $instanceObj;    
            } # $instances loop
            
        } # process loop
    }
    END
    {
        Write-Output $InstanceInfo;
    }
}
