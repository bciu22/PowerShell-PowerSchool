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

    Set-Variable -Scope Global -Name "PowerSchoolURL" -Value $PowerSchoolURL
    Set-Variable -Scope Global -Name "PowerSchoolAccessToken" -Value $Response.access_token
    Set-Variable -Scope Global -Name "PowerSchoolAccessTokenExpiration" -Value $(Get-Date).AddSeconds($Response.expires_in)
}

function Invoke-PowerSchoolRESTMethod {
    param(
        $EndpointURL,
        $Method,
        $PageNumber=0,
        $PageSize=0
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add("Authorization","Bearer $($(Get-Variable -Name "PowerSchoolAccessToken").Value)")
    $headers.Add("Accept", 'application/json')
    $headers.Add("Content-Type",'application/json')

    if($PageNumber -ne 0)
    {
        if ($EndpointURL -like "*?*")
        {
           $EndpointURL +="&page=$PageNumber"
        }
    }
    if ($PageSize -lt 100 -and $PageSize -gt 0)
    {
        if ($EndpointURL -like "*?*")
        {
           $EndpointURL +="&pagesize=$PageSize"
        }
    }
    $uri ="$($(Get-Variable -Name 'PowerSchoolURL').value)$($EndpointURL)"
    Write-Host $uri
    $Response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers
    $Response
}

function Get-RecordCount {
    param(
        $EndpointURL
    )
    $split = $EndpointURL.split('?')
    $URL = "$($split[0])/count?$($split[1])"
    Invoke-PowerSchoolRESTMethod -EndpointURL $URL  -Method "GET" | Select-Object -ExpandProperty Resource | Select-Object -ExpandProperty Count

}


function Get-PowerSchoolStudents {
   param(
       [int16]
       $MaxResults=0,
       [int16]
       $SchoolID = 3,
       [String[]]
       $EnrollmentStatus = @("A","P"),
       [String[]]
       $Expansions = @("demographics","addresses","alerts","phones","school_enrollment","ethnicity_race","contact","contact_info","initial_enrollment","schedule_setup","fees", "lunch"),
       [String[]]
       $Extensions=@("s_pa_stu_x","s_stu_crdc_x","c_studentlocator","s_stu_ncea_x","studentcorefields")
   )
    $URL = "/ws/v1/district/student?q=school_enrollment.enroll_status==($($EnrollmentStatus -join ','))"
    if ($Expansions.count -gt 0)
    { 
        $URL ="$URL&expansions=$($Expansions -join ',')"
    }
    if ($Extensions.count -gt 0)
    {
        $URL ="$URL&extensions=$($Extensions -join ',')"
    }
    $count = Get-RecordCount -EndpointURL $URL
    Write-Host "Found $count Students"
    $studentResults = @()
    $pageCounter = 0
    While ( $studentResults.Count -lt $count -and $studentResults.count -lt $MaxResults)
    {
        $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
        Foreach ($student in $response.students.student)
        {
            $studentResults += $student
        }
        $pageCounter +=1
    }
    $studentResults
}

function Get-PowerSchoolDatabaseTables {
    $URL = "/ws/schema/table"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response
}

Function Get-PowerSchoolTableSchema {
    param(
        $tableName
    )
    $URL = "/ws/schema/table/$tableName/metadata"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response

}

function Get-PowerSchoolTableRecord {
    param(
        $tableName,
        $id,
        [string[]]
        $columns=@("*")
    )
    $URL = "/ws/schema/table/$tableName/$($id)?projection=$($columns -join ',')"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response
}