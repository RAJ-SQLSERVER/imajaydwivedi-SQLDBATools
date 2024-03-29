Function Add-SdtCollectionError
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [Alias('ServerName','MachineName')]
        [String]$ComputerName,
	
        [Parameter(Mandatory=$true)]
        [Alias('Function')]
        [String]$Cmdlet,

	    [Parameter(Mandatory=$false)]
        [Alias('Command')]
        [String]$CommandText,

	    [Parameter(Mandatory=$true)]
        [String]$ErrorText,

	    [Parameter(Mandatory=$false)]
        [Alias('OtherInfo')]
        [String]$Remark
    )

    #Add switch
    $AddSwitch = $true;
    if([String]::IsNullOrEmpty($Remark)) 
    {
        $Remark = @"
Caller ServerName:- $($env:COMPUTERNAME).
Caller UserName:- $([Environment]::UserDomainName + "\" + [Environment]::UserName).

"@;
    }
    else
    {
        $Remark = @"
Caller ServerName:- $($env:COMPUTERNAME).
Caller UserName:- $([Environment]::UserDomainName + "\" + [Environment]::UserName).

"@ + $Remark;
    }

    # Check $AddSwitch value
    if($AddSwitch)
    {
        $CollectionTime = [DateTime]((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"));

        $props = [Ordered]@{
                    'collection_time' = $CollectionTime;
                    'server' = $ComputerName;
                    'cmdlet' = $Cmdlet;
                    'command' = $CommandText;
                    'error' = $ErrorText;
                    'remark' = $Remark;
                    
                }

        $obj = New-Object -TypeName psobject -Property $props;

        try
        {
            $dtable = $obj | Out-SdtDataTable;
        
            $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$sdtInventoryInstance;Integrated Security=SSPI;Initial Catalog=$sdtInventoryDatabase");
            $cn.Open();

            $bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn;
            $bc.DestinationTableName = "$SdtErrorTable";
            $bc.WriteToServer($dtable);
            $cn.Close();

            Write-Host "Added Entry into Error Logs table [$sdtInventoryInstance].[$sdtInventoryDatabase].$SdtErrorTable" -ForegroundColor Yellow;
        }
        catch
        {
            Write-Host "Error occurred while adding Error Logs entry in table [$sdtInventoryInstance].[$sdtInventoryDatabase].$SdtErrorTable" -ForegroundColor Red;
        }             
    }
}

# Add-SdtCollectionError -ComputerName $env:COMPUTERNAME -Cmdlet 'Add-SdtServerInfo' -CommandText "Add-SdtServerInfo -ComputerName $($env:COMPUTERNAME)" -ErrorText 'Access Denied' -Remark 'Dummy'
