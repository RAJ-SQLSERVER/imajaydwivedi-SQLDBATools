Function Add-sdtVolumeInfo
{
    
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('ServerName','MachineName')]
        [String]$ComputerName = $env:COMPUTERNAME
    )

    $ExecutionLogsFile = "$$SdtLogsPath\Get-SdtVolumeInfo\___ExecutionLogs.txt";
    
    if ($ComputerName -eq "")
    {
        Write-Error 'Invalid Value for ComputerName parameter';
    }
    else 
    {
        
        # Making entry into General Logs File
        #"$ComputerName " | Out-File -Append $ExecutionLogsFile;

        $errorFile = "$$SdtLogsPath\Get-SdtVolumeInfo\$($ComputerName -replace '\\','__').txt";
        Push-Location;

        try {

            # http://www.itprotoday.com/microsoft-sql-server/bulk-copy-data-sql-server-powershell
            $diskInfo = Get-SdtVolumeInfo -ComputerName $ComputerName;

            if ($diskInfo -eq $null)
            {
                $MessageText = "Get-SdtVolumeInfo -ComputerName '$ComputerName'   did not work.";
                Write-Verbose $MessageText;
                Add-SdtCollectionError -ComputerName $ComputerName -Cmdlet 'Collect-VolumeInfo' -CommandText "Get-SdtVolumeInfo -ComputerName '$ComputerName'" -ErrorText $MessageText -Remark $null;
                return;
            }

            $diskInfo = $diskInfo | Select-Object *, @{l='CollectionTime';e={(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")}};
            $dtable = $diskInfo | Out-SdtDataTable;    
        
            $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$sdtInventoryInstance;Integrated Security=SSPI;Initial Catalog=$sdtInventoryDatabase");
            $cn.Open();

            $bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn;
            $bc.DestinationTableName = "Staging.VolumeInfo";
            $bc.WriteToServer($dtable);
            $cn.Close();
        }
        catch {
            $ErrorMessage = $_.Exception.Message;
            $FailedItem = $_.Exception.ItemName;
            
            # Create if Error Log path does not exist
            if (!(Test-Path "$$SdtLogsPath\Get-SdtVolumeInfo")) {
                New-Item "$$SdtLogsPath\Get-SdtVolumeInfo" -ItemType directory;
            }

            # Drop old error log file
            if (Test-Path $errorFile) {
                Remove-Item $errorFile;
            }

            # Output Error in file
            @"
Error occurred while running 
Collect-VolumeInfo -ComputerName $ComputerName -Verbose
$ErrorMessage
"@ | Out-File $errorFile;
            Write-Verbose "Error occurred in while trying to get VolumeInfo for server [$ComputerName]. Kindly check logs at $errorFile";
        }
        
        Pop-Location;
    }    
}
