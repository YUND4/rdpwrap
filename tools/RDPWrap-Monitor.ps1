# RDPWrap Monitor - widget de estado de RDP Wrapper
# Uso: powershell -ExecutionPolicy Bypass -File RDPWrap-Monitor.ps1
Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="RDPWrap Monitor" Width="460" Height="520" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" Background="#FF1E1E2E">
    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="RDP Wrapper - Estado del sistema"
                   Foreground="#FFCDD6F4" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>

        <ListView Grid.Row="1" Name="StatusList" Background="#FF313244" BorderThickness="0"
                  Foreground="#FFCDD6F4" FontSize="13">
            <ListView.ItemContainerStyle>
                <Style TargetType="ListViewItem">
                    <Setter Property="Padding" Value="8,5"/>
                </Style>
            </ListView.ItemContainerStyle>
        </ListView>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,12,0,0">
            <Button Name="BtnRefresh" Content="Actualizar" Width="100" Margin="4"/>
            <Button Name="BtnUpdateIni" Content="Actualizar INI" Width="100" Margin="4"/>
            <Button Name="BtnOpenConf" Content="RDPConf" Width="100" Margin="4"/>
        </StackPanel>
    </Grid>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$list = $window.FindName('StatusList')

function Get-StatusItems {
    $items = [System.Collections.Generic.List[object]]::new()

    # Servicio TermService
    $svc = Get-Service TermService -ErrorAction SilentlyContinue
    $items.Add([pscustomobject]@{ Icon = $(if ($svc.Status -eq 'Running') {'OK'} else {'!!'}); Item = 'TermService'; Value = "$($svc.Status) ($($svc.StartType))" })

    # Wrapper instalado
    $serviceDll = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters' -ErrorAction SilentlyContinue).ServiceDll
    $wrapped = $serviceDll -like '*rdpwrap*'
    $items.Add([pscustomobject]@{ Icon = $(if ($wrapped) {'OK'} else {'!!'}); Item = 'Wrapper instalado'; Value = $serviceDll })

    # Listener 3389
    $netstat = netstat -an | Select-String ':3389\s' | Select-String 'LISTENING'
    $items.Add([pscustomobject]@{ Icon = $(if ($netstat) {'OK'} else {'!!'}); Item = 'Listener RDP (3389)'; Value = $(if ($netstat) {'Escuchando'} else {'Sin listener'}) })

    # Version termsrv y soporte en INI
    $tsv = (Get-Item "$env:WINDIR\System32\termsrv.dll").VersionInfo.FileVersion
    $iniPath = "$env:ProgramFiles\RDP Wrapper\rdpwrap.ini"
    $supported = $false
    if (Test-Path $iniPath) {
        $supported = [bool](Select-String -Path $iniPath -Pattern "^\[$([regex]::Escape($tsv.Split(' ')[0]))\]" -Quiet)
        $iniDate = (Select-String -Path $iniPath -Pattern '^Updated=(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
    }
    $items.Add([pscustomobject]@{ Icon = $(if ($supported) {'OK'} else {'!!'}); Item = "termsrv.dll $tsv"; Value = $(if ($supported) {'[fully supported]'} else {'[not supported] - ejecuta update.bat'}) })
    if ($iniDate) { $items.Add([pscustomobject]@{ Icon = 'i'; Item = 'INI actualizado'; Value = $iniDate }) }

    # Exclusiones Defender
    try {
        $excl = (Get-MpPreference -ErrorAction Stop).ExclusionPath | Where-Object { $_ -like '*RDP*' }
        $items.Add([pscustomobject]@{ Icon = $(if ($excl) {'OK'} else {'--'}); Item = 'Exclusiones Defender'; Value = $(if ($excl) {"$($excl.Count) configuradas"} else {'No detectadas (requiere admin)'}) })
    } catch {
        $items.Add([pscustomobject]@{ Icon = '--'; Item = 'Exclusiones Defender'; Value = 'Requiere admin para leer' })
    }

    # Windows Update
    $wua = Get-Service wuauserv -ErrorAction SilentlyContinue
    $items.Add([pscustomobject]@{ Icon = $(if ($wua.StartType -eq 'Disabled') {'OK'} else {'!!'}); Item = 'Windows Update'; Value = "$($wua.Status) ($($wua.StartType))" })

    # Cloudflare Tunnel
    $cfd = Get-Service cloudflared -ErrorAction SilentlyContinue
    $items.Add([pscustomobject]@{ Icon = $(if ($cfd -and $cfd.Status -eq 'Running') {'OK'} else {'--'}); Item = 'Cloudflare Tunnel'; Value = $(if ($cfd) { "$($cfd.Status)" } else { 'No instalado' }) })

    return $items
}

function Refresh-List {
    $list.Items.Clear()
    foreach ($i in Get-StatusItems) {
        $list.Items.Add("$($i.Icon)  $($i.Item)  ->  $($i.Value)") | Out-Null
    }
}

$window.FindName('BtnRefresh').Add_Click({ Refresh-List })
$window.FindName('BtnUpdateIni').Add_Click({
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $PSScriptRoot '..\bin\update-ini.ps1')
})
$window.FindName('BtnOpenConf').Add_Click({
    $conf = "$env:ProgramFiles\RDP Wrapper\RDPConf.exe"
    if (Test-Path $conf) { Start-Process $conf } else { [System.Windows.MessageBox]::Show('RDPConf.exe no encontrado en la instalacion.') }
})

$window.Add_Loaded({ Refresh-List })
[void]$window.ShowDialog()
