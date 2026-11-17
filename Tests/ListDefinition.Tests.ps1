#requires -Version 7
# Pester v5 tests for the private list queryString parser used by
# Export-JuribaListDefinition and Import-JuribaListDefinition.
#
# These are NOT run by the current CI (which only runs PSScriptAnalyzer) and are
# not part of the published module. Run locally with Pester 5+:
#   Invoke-Pester .\Tests\ListDefinition.Tests.ps1
#
# The fixtures are queryStrings exactly as DPC stores them (GET /apiv1/lists/{type}).

BeforeAll {
    Set-StrictMode -Version Latest
    $privateDir = Join-Path $PSScriptRoot '..\Juriba.DPC\Private'
    foreach ($name in 'Split-JuribaListColumnExpression', 'Split-JuribaListFilterExpression',
                      'ConvertFrom-JuribaListQueryString', 'ConvertTo-JuribaListQueryString') {
        . (Resolve-Path (Join-Path $privateDir "$name.ps1"))
    }

    function Get-FilterSegment {
        param([string]$QueryString, [string]$Kind)
        $p = ConvertFrom-JuribaListQueryString -QueryString $QueryString | Where-Object Name -eq '$filter'
        @($p.Segments | Where-Object Kind -eq $Kind)
    }
}

Describe 'List queryString parser' {

    Context 'Round trip' {
        It 'rebuilds <Name> exactly' -ForEach @(
            @{ Name = 'task value filter'; QueryString = '$filter=(project_122_onboarded%20EQUALS%20(''1'')%20AND%20project_task_122_13779_4_Task_Value%20EQUALS%20(''3''))&$select=hostname,chassisCategory,oSCategory,ownerDisplayName,selfServiceField_30_link,project_task_122_13779_4_Task&$pinleft=&$pinright=&$archiveditems=false' }
            @{ Name = 'association WHERE clause'; QueryString = '$filter=(applicationSavedListId%20EQUALS%20(''33'')%20WHERE%20(uod%2Cetd%2Ciod%2Cubdo%2Cetdo))&$select=hostname,chassisCategory,oSCategory,ownerDisplayName' }
            @{ Name = 'pivot'; QueryString = '$filter=&$rowgroups=oSCategory,migrationRAG&$columns=chassisCategory,manufacturer&$values=computerKey%20count&$archiveditems=false' }
            @{ Name = 'always-false filter'; QueryString = '$select=hostname&$filter=(1=0)' }
            @{ Name = 'relative date'; QueryString = '$filter=(project_63_onboarded%20EQUALS%20(''1'')%20AND%20project_task_63_13265_2_Task%20ON%20BEFORE%20RELATIVE%20(2_day_ahead)%20AND%20project_task_63_13266_1_Task_Value%20EQUALS%20(''2''%2C''1''))&$select=hostname,chassisCategory,oSCategory,ownerDisplayName&$archiveditems=false' }
            @{ Name = 'OR groups'; QueryString = '$filter=(project_task_94_13414_1_date%20ON%20AFTER%20RELATIVE%20(0_day_ago))%20OR%20(project_task_94_13414_1_Task_Value%20EQUALS%20(''5''))&$select=principalEmailAddress,mailboxPlatform,project_task_94_13414_1_Task&$pinleft=&$pinright=&$archiveditems=false' }
            @{ Name = 'orderby'; QueryString = '$filter=(vulnerabilityName%20IS%20NOT%20EMPTY%20()%20WHERE%20(cv))&$select=packageName,highestVulnerabilitySeverityScore&$orderby=highestVulnerabilitySeverityScore%20desc' }
            @{ Name = 'comparisons'; QueryString = '$filter=(entitledApplications%20%3E%3D%201%20AND%20project_task_130_14123_2_Task%20%3E%202025-03-07)&$select=hostname' }
            @{ Name = 'quoted value with quote, comma and brackets'; QueryString = '$filter=(hostname%20CONTAINS%20(''O''''Brien%2C%20(x)''))&$select=hostname' }
            @{ Name = 'non-ASCII value'; QueryString = '$filter=(city%20EQUALS%20(''K%C3%B8benhavn''))&$select=hostname' }
            @{ Name = 'empty string'; QueryString = '' }
        ) {
            $parameters = ConvertFrom-JuribaListQueryString -QueryString $QueryString
            ConvertTo-JuribaListQueryString -Parameters $parameters | Should -BeExactly $QueryString
        }
    }

    Context 'Filters' {
        It 'finds each condition''s field and its values' {
            $qs = '$filter=(project_130_ringId%20EQUALS%20(''235''%2C''239'')%20AND%20project_130_bucket%20EQUALS%20(''1055''))%20OR%20(customField_5_1101%20IS%20NOT%20EMPTY%20())&$select=hostname'
            (Get-FilterSegment $qs 'Filter').Text | Should -Be @('project_130_ringId', 'project_130_bucket', 'customField_5_1101')
            $values = Get-FilterSegment $qs 'Value'
            $values.Text | Should -Be @('235', '239', '1055')
            $values.Field | Should -Be @('project_130_ringId', 'project_130_ringId', 'project_130_bucket')
        }

        It 'treats bare values as unquoted values' {
            $values = Get-FilterSegment '$filter=(entitledApplications%20%3E%3D%201%20AND%20project_task_63_13265_2_Task%20ON%20BEFORE%20RELATIVE%20(2_day_ahead))' 'Value'
            $values.Text | Should -Be @('1', '2_day_ahead')
            $values.Quoted | Should -Be @($false, $false)
        }

        It 'keeps WHERE codes and numeric literals out of the fields' {
            (Get-FilterSegment '$filter=(applicationSavedListId%20EQUALS%20(''33'')%20WHERE%20(uod%2Cetd))' 'Filter').Text | Should -Be @('applicationSavedListId')
            (Get-FilterSegment '$filter=(1=0)' 'Filter') | Should -BeNullOrEmpty
        }

        It 'unescapes doubled quotes in values' {
            (Get-FilterSegment '$filter=(hostname%20CONTAINS%20(''O''''Brien''))' 'Value').Text | Should -Be "O'Brien"
        }
    }

    Context 'Columns' {
        It 'finds column tokens and keeps sort and aggregate modifiers' {
            $parameters = ConvertFrom-JuribaListQueryString -QueryString '$select=hostname,customField_1_68&$orderby=project_56_ragStatus%20asc&$values=computerKey%20count'
            $columns = @($parameters.Segments | Where-Object Kind -eq 'Column')
            $columns.Text | Should -Be @('hostname', 'customField_1_68', 'project_56_ragStatus', 'computerKey')
        }
    }

    Context 'Rewriting' {
        It 'replaces tokens and values and re-encodes only encoded parameters' {
            $qs = '$filter=(project_130_ringId%20EQUALS%20(''235''%2C''NULL''))&$select=hostname,project_130_ring&$orderby=project_130_ring%20asc'
            $parameters = ConvertFrom-JuribaListQueryString -QueryString $qs
            foreach ($segment in $parameters.Segments) {
                switch ($segment.Kind) {
                    'Column' { $segment.Text = $segment.Text -replace '_130_', '_7_' }
                    'Filter' { $segment.Text = $segment.Text -replace '_130_', '_7_' }
                    'Value'  { if ($segment.Text -eq '235') { $segment.Text = '12' } }
                }
            }
            ConvertTo-JuribaListQueryString -Parameters $parameters |
                Should -BeExactly '$filter=(project_7_ringId%20EQUALS%20(''12''%2C''NULL''))&$select=hostname,project_7_ring&$orderby=project_7_ring%20asc'
        }

        It 'quotes rewritten values that contain a quote' {
            $parameters = ConvertFrom-JuribaListQueryString -QueryString '$filter=(city%20EQUALS%20(''x''))'
            ($parameters.Segments | Where-Object Kind -eq 'Value').Text = "O'Hare"
            ConvertTo-JuribaListQueryString -Parameters $parameters | Should -BeExactly '$filter=(city%20EQUALS%20(''O''''Hare''))'
        }
    }
}
