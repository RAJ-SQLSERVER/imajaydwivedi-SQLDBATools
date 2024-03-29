function Show-SdtRSJob
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        $JobNamePrefix,
        [Parameter(Mandatory=$true)]
        $StatusReportIntervalMinutes,
        [Parameter(Mandatory=$true)]
        $ScriptTimeoutMinutes,
        [Parameter(Mandatory=$false)]
        $LogFile,
        [Switch]$NoGUIProgressBar
    )

    Write-Verbose "Inside Show-SdtRSJob"

    $jobsStartTime = Get-Date
    $timeOutFlag = $false

    # Get all the running ps jobs
    $rsJobs = Get-RSJob | Where-Object {$_.Name -like "$JobNamePrefix*"}
    if(-not [String]::IsNullOrEmpty($LogFile)) {
        $rsJobs | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $LogFile -Append | Write-Verbose
    }
    else {
        $rsJobs | Format-Table -AutoSize | Out-String | Write-Verbose
    }

    while($True)
    {
        $loopStartTime = Get-Date
        if($NoGUIProgressBar) {
            $rsJobs | Wait-RSJob -Timeout ($StatusReportIntervalMinutes*60) | Out-Null
        }
        else {
            $rsJobs | Wait-RSJob -ShowProgress -Timeout ($StatusReportIntervalMinutes*60) | Out-Null
        }
        $loopEndTime = Get-Date

        $timeSpan = New-TimeSpan -Start $loopStartTime -End $loopEndTime
        if($timeSpan.TotalSeconds -le 5) { # If no jobs in progress
            break;
        }
        else {
            if(-not [String]::IsNullOrEmpty($LogFile)) {
                "PSJobs are in progress.." | Tee-Object -FilePath $LogFile -Append | Write-Verbose
                "`n$($rsJobs | Format-Table -AutoSize | Out-String)" | Tee-Object -FilePath $LogFile -Append | Write-Verbose
            }
            else {
                "PSJobs are in progress.." | Write-Verbose
                "`n$($rsJobs | Format-Table -AutoSize | Out-String)" | Write-Verbose
            }
            
        }
        if((New-TimeSpan -Start $jobsStartTime -End (Get-Date)).TotalMinutes -ge $ScriptTimeoutMinutes) { # If jobs ran longer than $ScriptTimeoutMinutes
            if(-not [String]::IsNullOrEmpty($LogFile)) {
                "PSJobs could not complete within `$ScriptTimeoutMinutes ($ScriptTimeoutMinutes) threshold" | Tee-Object -FilePath $LogFile -Append | Write-Warning
            }
            else {
                "PSJobs could not complete within `$ScriptTimeoutMinutes ($ScriptTimeoutMinutes) threshold" | Write-Warning
            }
            $timeOutFlag = $true
            break;
        }
    }

    if(-not [String]::IsNullOrEmpty($LogFile)) {
        "PSJobs completed. Checking success/failure state.." | Tee-Object -FilePath $LogFile -Append | Write-Verbose
        $rsJobs | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $LogFile -Append | Write-Verbose
    }
    else {
        "PSJobs completed. Checking success/failure state.." | Write-Verbose
        $rsJobs | Format-Table -AutoSize | Write-Verbose
    }

    # Get Data for Successful Jobs
    $resultRsJobs = $rsJobs | Where-Object {$_.HasErrors -eq $false} | Receive-RSJob;
    $failedRsJobs = $rsJobs | Where-Object {$_.HasErrors}

    $failureMessages = @()
    if(-not [String]::IsNullOrEmpty($failedRsJobs)) {
        $failureMessages = $failedRsJobs | Receive-RSJob
        if(-not [String]::IsNullOrEmpty($LogFile)) {
            "Following RSJob(s) failed- `n`n $( $failedRsJobs | Format-Table -AutoSize | Out-String) `n`n$failureMessages" | Tee-Object -FilePath $LogFile -Append | Write-Warning
        }
        else {
            "Following RSJob(s) failed- `n`n $( $failedRsJobs | Format-Table -AutoSize | Out-String) `n`n$failureMessages" | Write-Warning
        }
    }
    
    # Stop the jobs
    if($timeOutFlag) {
        if(-not [String]::IsNullOrEmpty($LogFile)) {
            "Stopping RSJobs post timeout.." | Tee-Object -FilePath $LogFile -Append | Write-Verbose
        }
        else {
            "Stopping RSJobs post timeout.." | Write-Verbose
        }
        $rsJobs | Stop-RSJob
    }

    if(-not [String]::IsNullOrEmpty($LogFile)) {
        "Removing RSJobs.." | Tee-Object -FilePath $LogFile -Append | Write-Verbose
    }
    else {
        "Removing RSJobs.." | Write-Verbose
    }
    $rsJobs | Remove-RSJob | Write-Verbose

    return $timeOutFlag, $resultRsJobs, $failedRsJobs, $failureMessages

<#
    .SYNOPSIS 
      Get progress of RSJobs in log file as well as in Progress bar
    .DESCRIPTION
      This function shows progress bar of RSJobs running in parallel, and logs the status into log files at regular interval.
    .PARAMETER JobNamePrefix
      RSJob name prefix keyword to identify jobs
    .PARAMETER StatusReportIntervalMinutes
      Duration in minutes at which progress status of RSJob will be posted in LogFile
    .PARAMETER ScriptTimeoutMinutes
      Collective duration in minutes after which RSJobs will be considered timeout, and will be stopped
    .PARAMETER LogFile
      Name of the log file that would contain output of script from each step
    .PARAMETER NoGUIProgressBar
      Switch when used disable the GUI Progress bar usually displayed
    .EXAMPLE

      @(1,2,2,4,5,6,7,8,9,10,30,60,90) | Start-RSJob -Name {"Test_$_"} -Throttle 2 -ScriptBlock { start-sleep -Seconds ($_*60); $_; } | Out-Null

      $timeOutFlag, $resultRsJobs, $failedRsJobs, $failureMessages = Show-SdtRSJob -JobNamePrefix 'Test_' `
                                                                            -StatusReportIntervalMinutes 1 `
                                                                            -ScriptTimeoutMinutes 10 `
                                                                            -LogFile 'C:\Temp\psjob_tracking.txt' `
                                                                            -Verbose #-Debug 

    .LINK
      http://google.com
#>
}
