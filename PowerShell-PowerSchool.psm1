<#
  .SYNOPSIS
    This module contains functions for working with the PowerSchool API in PowerShell
  
  .DESCRIPTION
    
  .LINK
    https://support.powerschool.com/developer/#/
  .NOTES
    Authors: Charles Crossan
  
  .VERSION 
    1.0.0

#>

function Connect-PowerSchoolService {
<#

.PARAMETER Username
    ClientID for OAUTH pplugin
.PARAMETER Password
    $password = ConvertTo-SecureString –String "password" –AsPlainText -Force

#>
    param (
        [parameter(Mandatory=$true)]
        [String]
        $ClientID,
        [String]
        $ClientSecret,
        [String]
        $PowerSchoolURL
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", 'application/x-www-form-urlencoded;charset=UTF-8')
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientID,$ClientSecret)))

    $headers.add("Authorization","Basic $base64AuthInfo")

    $body = "grant_type=client_credentials"

    $Response = Invoke-RestMethod -Uri $PowerSchoolURL"/oauth/access_token" -Method Post -Headers $headers -Body $body

    Set-Variable -Scope Global -Name "PowerSchoolAccessToken" -Value $Response.access_token
    Set-Variable -Scope Global -Name "PowerSchoolAccessTokenExpiration" -Value $(Get-Date).AddSeconds($Response.expires_in)
}

function Invoke-PowerSchoolRESTMethod {
    param(
        $EndpointURL
    )

    $Response = Invoke-RestMethod -Uri $PowerSchoolURL"/oath/access_token" -Method Post -Headers $headers -Credential $Credential

}



function Get-PowerSchoolStudents {
   param(
       [int16]
       $MaxResults
   )
   /ws/v1/student
}