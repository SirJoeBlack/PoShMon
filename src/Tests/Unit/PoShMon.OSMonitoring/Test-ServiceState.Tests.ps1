$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
Remove-Module PoShMon -ErrorAction SilentlyContinue
Import-Module (Join-Path $rootPath -ChildPath "PoShMon.psd1")

class ServiceInstanceMock {
    [object]$Status
    [object]$Service
    [object]$Server

    ServiceInstanceMock ([string]$NewServerDisplayName, [string]$NewServiceName, [string]$NewStatusValue) {
        $this.Server = [pscustomobject]@{DisplayName=$NewServerDisplayName};
        $this.Service = [pscustomobject]@{Name=$NewServiceName};
        $this.Status = [pscustomobject]@{Value=$NewStatusValue};
    }
}

Describe "Test-ServiceState" {
    It "Should return a matching output structure" {

        Mock -CommandName Test-ServiceStatePartial -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                        @{
                            'GroupName' = $ServerName
                            'NoIssuesFound' = $true
                            'GroupOutputValues' = @(
                                                    @{
                                                        'DisplayName' = 'Service 1 DisplayName';
                                                        'Name' = 'Svc1';
                                                        'Status' = "Running";
                                                        'Highlight' = @()
                                                    },
                                                    @{
                                                        'DisplayName' = 'Service 2 DisplayName';
                                                        'Name' = 'Svc2';
                                                        'Status' = "Running";
                                                        'Highlight' = @()
                                                    }
                                                   )
                        }
                    )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                                    General -ServerNames "Server1"
                                    OperatingSystem -WindowsServices "ABC"
                                }   

        $actual = Test-ServiceState $poShMonConfiguration

        $headerKeyCount = 3

        $actual.Keys.Count | Should Be 5
        $actual.ContainsKey("NoIssuesFound") | Should Be $true
        $actual.ContainsKey("OutputHeaders") | Should Be $true
        $actual.ContainsKey("OutputValues") | Should Be $true
        $actual.ContainsKey("SectionHeader") | Should Be $true
        $actual.ContainsKey("ElapsedTime") | Should Be $true
        $valuesGroup1 = $actual.OutputValues[0]
        $valuesGroup1.Keys.Count | Should Be $headerKeyCount
        $values1 = $valuesGroup1.GroupOutputValues[0]
        $values1.Keys.Count | Should Be ($headerKeyCount + 1)
        $values1.ContainsKey("DisplayName") | Should Be $true
        $values1.ContainsKey("Name") | Should Be $true
        $values1.ContainsKey("Status") | Should Be $true
        $values1.ContainsKey("Highlight") | Should Be $true

    }

    It "Should write the expected Verbose output" {
    
        Mock -CommandName Test-ServiceStatePartial -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                        @{
                            'GroupName' = $ServerName
                            'NoIssuesFound' = $true
                            'GroupOutputValues' = @(
                                                    @{
                                                        'DisplayName' = 'Service 2 DisplayName';
                                                        'Name' = $Services;
                                                        'Status' = "Started";
                                                        'Highlight' = @('Status')
                                                    }
                                                   )
                        }
                    )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                                    General -ServerNames "Server2"
                                    OperatingSystem -WindowsServices "ABC"
                                }

        $actual = Test-ServiceState $poShMonConfiguration -Verbose
        $output = $($actual = Test-ServiceState $poShMonConfiguration -Verbose) 4>&1

        $output.Count | Should Be 2
        $output[0].ToString() | Should Be "Windows Service State' Test..."
        $output[1].ToString() | Should Be "Complete 'Windows Service State' Test, Issues Found: No"
    }

    It "Should pass for all running services" {

        Mock -CommandName Test-ServiceStatePartial -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                        @{
                            'GroupName' = $ServerName
                            'NoIssuesFound' = $true
                            'GroupOutputValues' = @(
                                                    @{
                                                        'DisplayName' = 'Service 2 DisplayName';
                                                        'Name' = $Services;
                                                        'Status' = "Started";
                                                        'Highlight' = @('Status')
                                                    }
                                                   )
                        }
                    )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                                    General -ServerNames "Server2"
                                    OperatingSystem -WindowsServices "ABC"
                                }

        $actual = Test-ServiceState $poShMonConfiguration

        Assert-VerifiableMocks

        $actual.OutputValues.Count | Should Be 1
        $actual.OutputValues[0].GroupOutputValues.Count | Should Be 1
        $actual.OutputValues[0].GroupOutputValues[0].Name | Should Be "ABC"
    }

    It "Should fail for any service in the wrong state" {
    
        Mock -CommandName Invoke-RemoteCommand -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                [ServiceInstanceMock]::new('Server1', 'TheService', 'Online')
            )
        }

        Mock -CommandName Test-ServiceStatePartial -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                        @{
                            'GroupName' = $ServerName
                            'NoIssuesFound' = $false
                            'GroupOutputValues' = @(
                                                    @{
                                                        'DisplayName' = 'Service 2 DisplayName';
                                                        'Name' = 'Svc2';
                                                        'Status' = "Stopped";
                                                        'Highlight' = @('Status')
                                                    }
                                                   )
                        }
                    )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
                                    General -ServerNames "Server1"
                                    OperatingSystem -WindowsServices "ABC"
                                }

        $actual = Test-ServiceState $poShMonConfiguration

        $actual.NoIssuesFound | Should Be $false
    }

}