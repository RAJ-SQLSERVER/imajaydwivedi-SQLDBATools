Set-Location $PSScriptRoot;
.\AutoBuild.ps1 -SQLServiceAccount 'Corporate\DevSQL'

#.\Setup.exe /Action=Uninstall /QUIETSIMPLE=true /FEATURES=SQLENGINE,REPLICATION,FULLTEXT,CONN,IS,BC,SDK,BOL,SSMS,ADV_SSMS,SNAC_SDK /INSTANCENAME=MSSQLSERVER