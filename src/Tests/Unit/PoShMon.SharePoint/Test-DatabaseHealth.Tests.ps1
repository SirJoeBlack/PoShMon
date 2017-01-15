$rootPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath ('..\..\..\') -Resolve
Remove-Module PoShMon -ErrorAction SilentlyContinue
Import-Module (Join-Path $rootPath -ChildPath "PoShMon.psd1")

class SPDatabaseMock {
    [string]$DisplayName
    [string]$ApplicationName
    [bool]$NeedsUpgrade
    [UInt64]$DiskSizeRequired

    SPDatabaseMock ([string]$NewDisplayName, [string]$NewApplicationName, [bool]$NewNeedsUpgrade, [UInt64]$NewDiskSizeRequired) {
        $this.DisplayName = $NewDisplayName;
        $this.ApplicationName = $NewApplicationName;
        $this.NeedsUpgrade = $NewNeedsUpgrade;
        $this.DiskSizeRequired = $NewDiskSizeRequired;
    }
}

Describe "Test-DatabaseHealth" {
    It "Should return a matching output structure" {
    
        Mock -CommandName Invoke-RemoteCommand -ModuleName PoShMon -MockWith {
            return @(
                [SPDatabaseMock]::new('Database1', 'Application1', $false, [UInt64]50GB)
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {
            }

        $actual = Test-DatabaseHealth $poShMonConfiguration

        $headerKeyCount = 3

        $actual.Keys.Count | Should Be 5
        $actual.ContainsKey("NoIssuesFound") | Should Be $true
        $actual.ContainsKey("OutputHeaders") | Should Be $true
        $actual.ContainsKey("OutputValues") | Should Be $true
        $actual.ContainsKey("SectionHeader") | Should Be $true
        $actual.ContainsKey("ElapsedTime") | Should Be $true
        $headers = $actual.OutputHeaders
        $headers.Keys.Count | Should Be $headerKeyCount
        $values1 = $actual.OutputValues[0]
        $values1.Keys.Count | Should Be ($headerKeyCount+1)
        $values1.ContainsKey("DatabaseName") | Should Be $true
        $values1.ContainsKey("NeedsUpgrade") | Should Be $true
        $values1.ContainsKey("Size") | Should Be $true
        $values1.ContainsKey("Highlight") | Should Be $true
    }

    It "Should not warn on databases that are all fine" {

        Mock -CommandName Invoke-RemoteCommand -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                [SPDatabaseMock]::new('Database1', 'Application1', $false, [UInt64]50GB),
                [SPDatabaseMock]::new('Database2', 'Application1', $false, [UInt64]4GB)
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {}

        $actual = Test-DatabaseHealth $poShMonConfiguration
        
        Assert-VerifiableMocks

        $actual.NoIssuesFound | Should Be $true

        $actual.OutputValues.Highlight.Count | Should Be 0
    }

    It "Should warn on databases that are need upgrade" {

        Mock -CommandName Invoke-RemoteCommand -ModuleName PoShMon -Verifiable -MockWith {
            return @(
                [SPDatabaseMock]::new('Database1', 'Application1', $false, [UInt64]50GB),
                [SPDatabaseMock]::new('Database2', 'Application1', $true, [UInt64]4GB)
            )
        }

        $poShMonConfiguration = New-PoShMonConfiguration {}

        $actual = Test-DatabaseHealth $poShMonConfiguration
        
        Assert-VerifiableMocks

        $actual.NoIssuesFound | Should Be $false

        $actual.OutputValues[0].Highlight.Count | Should Be 0
        $actual.OutputValues[1].Highlight.Count | Should Be 1
        $actual.OutputValues[1].Highlight[0] | Should Be 'NeedsUpgrade'
    }

}