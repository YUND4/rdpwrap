# ============================================================================
# RDP Wrapper - Asistente de instalacion y acceso remoto
# Wizard con GUI: instala RDP Wrapper, configura seguridad, crea usuario RDP
# y conecta Tailscale con la cuenta del PROPIO usuario (sin IP fija).
# Uso: doble clic en "Iniciar asistente.bat" o:
#   powershell -STA -ExecutionPolicy Bypass -File RDPWrap-Setup-Wizard.ps1
# ============================================================================

# --- Auto-elevacion (OBLIGATORIA) --------------------------------------------
# El asistente siempre requiere administrador, sin importar como se lance
# (doble clic en el .bat, comando directo, terminal, etc.). Si no es admin,
# se relanza elevado via UAC; si el usuario rechaza el UAC, avisa y sale.
# Dev: RDPWRAP_WIZARD_NOELEVATE=1 omite la elevacion (solo para probar la UI)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $env:RDPWRAP_WIZARD_NOELEVATE -ne '1') {
    $self = $PSCommandPath
    if (-not $self) { $self = $MyInvocation.MyCommand.Path }
    try {
        Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-STA','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$self`""
    } catch {
        try {
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show("El asistente necesita permisos de administrador.`nVuelve a abrirlo y acepta el aviso de Windows (UAC).", 'RDP Wrapper - Permisos requeridos', 'OK', 'Warning') | Out-Null
        } catch {}
        Write-Host 'Se requieren privilegios de administrador. Ejecuta el asistente como administrador.' -ForegroundColor Yellow
    }
    exit 1
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# --- Rutas del paquete ------------------------------------------------------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$root = Split-Path -Parent $scriptDir   # installer/ -> raiz del repo

$script:Paths = @{
    RDPWInst   = @("$root\dist\RDPWInst.exe", "$root\bin\RDPWInst.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    IniLocal   = "$root\res\rdpwrap.ini"
    InstallDir = "$env:ProgramFiles\RDP Wrapper"
    IniUrl     = 'https://raw.githubusercontent.com/YUND4/rdpwrap/master/res/rdpwrap.ini'
}

# --- Registro de ejecucion (diagnostico sin capturas de pantalla) -----------
$script:LogFile = Join-Path $env:TEMP 'RDPWrap-Wizard.log'
function Write-Log($msg) {
    $line = '{0:HH:mm:ss.fff} [PID {1}] {2}' -f (Get-Date), $PID, $msg
    try { Add-Content -Path $script:LogFile -Value $line -Encoding utf8 } catch {}
}
Write-Log "=== inicio wizard | admin=$isAdmin | user=$env:USERNAME | autopilot=$env:RDPWRAP_WIZARD_AUTOPILOT ==="
if (-not $isAdmin) { Write-Log 'ADVERTENCIA: sin privilegios de administrador, varios pasos fallaran con acceso denegado' }

# ============================================================================
# XAML
# ============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RDP Wrapper - Asistente v1.5" Width="820" Height="600"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#FF1E1E2E" FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent" Color="#FF89B4FA"/>
    <SolidColorBrush x:Key="Ok" Color="#FFA6E3A1"/>
    <SolidColorBrush x:Key="Err" Color="#FFF38BA8"/>
    <SolidColorBrush x:Key="Muted" Color="#FF6C7086"/>
    <SolidColorBrush x:Key="Fg" Color="#FFCDD6F4"/>
    <SolidColorBrush x:Key="Panel" Color="#FF313244"/>
    <SolidColorBrush x:Key="PanelDark" Color="#FF181825"/>

    <Style TargetType="Button" x:Key="BtnPrimary">
      <Setter Property="Background" Value="#FF89B4FA"/>
      <Setter Property="Foreground" Value="#FF11111B"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="18,9"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button" x:Key="BtnGhost" BasedOn="{StaticResource BtnPrimary}">
      <Setter Property="Background" Value="#FF45475A"/>
      <Setter Property="Foreground" Value="#FFCDD6F4"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#FFCDD6F4"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,6"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="230"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- ======================= SIDEBAR ======================= -->
    <Border Grid.Column="0" Background="#FF181825" Padding="18,24">
      <StackPanel>
        <TextBlock Text="RDP Wrapper" Foreground="#FF89B4FA" FontSize="20" FontWeight="Bold"/>
        <TextBlock Text="Asistente de instalacion" Foreground="#FF6C7086" FontSize="12" Margin="0,2,0,24"/>
        <StackPanel x:Name="Sidebar"/>
        <TextBlock Text="v1.5 - fork YUND4" Foreground="#FF585B70" FontSize="10" VerticalAlignment="Bottom" Margin="0,180,0,0"/>
      </StackPanel>
    </Border>

    <!-- ======================= CONTENIDO ======================= -->
    <Grid Grid.Column="1" Margin="26,22,26,16">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Grid x:Name="ContentArea" Grid.Row="0">

        <!-- ========== PAGINA: BIENVENIDA ========== -->
        <Grid x:Name="PageWelcome">
          <StackPanel>
            <TextBlock x:Name="WelcomeTitle" Text="Bienvenido" FontSize="30" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock TextWrapping="Wrap" FontSize="14" Foreground="#FFA6ADC8" Margin="0,14,0,0" LineHeight="22">
Este asistente dejara este equipo listo para recibir conexiones de Escritorio Remoto (RDP) de forma segura, paso a paso:</TextBlock>
            <StackPanel Margin="12,18,0,0">
              <TextBlock Foreground="#FFCDD6F4" FontSize="14" Margin="0,4">1.  Instala RDP Wrapper (sesiones RDP habilitadas)</TextBlock>
              <TextBlock Foreground="#FFCDD6F4" FontSize="14" Margin="0,4">2.  Protege la instalacion (exclusiones del antivirus)</TextBlock>
              <TextBlock Foreground="#FFCDD6F4" FontSize="14" Margin="0,4">3.  Crea un usuario dedicado para el acceso remoto</TextBlock>
              <TextBlock Foreground="#FFCDD6F4" FontSize="14" Margin="0,4">4.  Conecta Tailscale con TU cuenta (acceso desde cualquier lugar)</TextBlock>
            </StackPanel>
            <Border Background="#FF313244" CornerRadius="8" Padding="14" Margin="0,26,0,0">
              <StackPanel>
                <TextBlock Text="No necesitas IP fija ni abrir puertos" FontWeight="SemiBold" Foreground="#FFA6E3A1" FontSize="14"/>
                <TextBlock TextWrapping="Wrap" Foreground="#FFA6ADC8" FontSize="13" Margin="0,6,0,0" LineHeight="20">
El acceso remoto funciona sobre una red privada virtual (Tailscale). Da igual que tu proveedor de Internet cambie tu IP o uses CGNAT: tus dispositivos siempre se encuentran entre si.</TextBlock>
              </StackPanel>
            </Border>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: COMO FUNCIONA ========== -->
        <Grid x:Name="PageHow" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Como funciona" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock TextWrapping="Wrap" FontSize="13" Foreground="#FFA6ADC8" Margin="0,10,0,16" LineHeight="20">
Dos piezas trabajando juntas. Cada una resuelve un problema distinto:</TextBlock>

            <Border Background="#FF313244" CornerRadius="8" Padding="14" Margin="0,0,0,12" BorderBrush="#FF89B4FA" BorderThickness="1">
              <StackPanel>
                <TextBlock Text="RDP Wrapper  -  habilita el servidor RDP" FontWeight="SemiBold" Foreground="#FF89B4FA" FontSize="14"/>
                <TextBlock TextWrapping="Wrap" Foreground="#FFA6ADC8" FontSize="12.5" Margin="0,6,0,0" LineHeight="19">
Windows en ediciones hogar trae el escritorio remoto deshabilitado. RDP Wrapper lo habilita SIN modificar archivos del sistema: se interpone en memoria entre Windows y el servicio de Terminal Services. Sobrevive a reinicios y (casi siempre) a Windows Update.</TextBlock>
              </StackPanel>
            </Border>

            <Border Background="#FF313244" CornerRadius="8" Padding="14" Margin="0,0,0,12" BorderBrush="#FFA6E3A1" BorderThickness="1">
              <StackPanel>
                <TextBlock Text="Tailscale  -  red privada sin IP fija" FontWeight="SemiBold" Foreground="#FFA6E3A1" FontSize="14"/>
                <TextBlock TextWrapping="Wrap" Foreground="#FFA6ADC8" FontSize="12.5" Margin="0,6,0,0" LineHeight="19">
Es una VPN de malla basada en WireGuard. Cada dispositivo donde instalas Tailscale e inicias sesion con TU cuenta recibe una IP privada FIJA (100.x.x.x) dentro de tu red. El trafico sale cifrado hacia Internet, atraviesa NAT y firewalls sin abrir puertos, y solo tus dispositivos pueden verse entre si.</TextBlock>
              </StackPanel>
            </Border>

            <Grid Margin="0,4,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="46"/><ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Grid.Column="0" Background="#FF45475A" CornerRadius="8" Padding="10">
                <TextBlock Text="Este equipo (servidor RDP)" Foreground="#FFCDD6F4" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
              </Border>
              <TextBlock Grid.Column="1" Text="&lt;=&gt;" Foreground="#FFA6E3A1" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              <Border Grid.Column="2" Background="#FF45475A" CornerRadius="8" Padding="10">
                <TextBlock Text="Tus equipos (laptop, celular)" Foreground="#FFCDD6F4" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
              </Border>
            </Grid>
            <TextBlock Text="Conexion cifrada extremo a extremo (WireGuard) - tu IP publica es irrelevante"
                       Foreground="#FF6C7086" FontSize="11" HorizontalAlignment="Center" Margin="0,8,0,0"/>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: OPCIONES ========== -->
        <Grid x:Name="PageOptions" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Que quieres instalar?" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock Text="Cada paso es independiente. Puedes desmarcar lo que no necesites."
                       Foreground="#FF6C7086" FontSize="12" Margin="0,6,0,14"/>
            <CheckBox x:Name="OptWrapper" IsChecked="True" Content="Instalar RDP Wrapper y actualizar su base de datos (INI)"/>
            <CheckBox x:Name="OptDefender" IsChecked="True" Content="Agregar exclusiones en Windows Defender (evita falsos positivos)"/>
            <CheckBox x:Name="OptUser" IsChecked="True" Content="Crear usuario local dedicado para RDP (recomendado)"/>
            <CheckBox x:Name="OptTailscale" IsChecked="True" Content="Instalar Tailscale (acceso remoto sin IP fija)"/>
            <CheckBox x:Name="OptFirewall" IsChecked="True" Content="Restringir el puerto 3389 (solo Tailscale y tu red local)"/>
            <CheckBox x:Name="OptWU" IsChecked="False" Content="Desactivar Windows Update (evita que rompa el soporte)"/>
            <Border Background="#FF313244" CornerRadius="6" Padding="10" Margin="16,2,0,0">
              <TextBlock TextWrapping="Wrap" Foreground="#FFF9E2AF" FontSize="11.5">
Advertencia: sin Windows Update el equipo no recibe parches de seguridad. Alternativa: dejarlo activo y ejecutar el actualizador del INI si algun dia RDP deja de funcionar tras una actualizacion.</TextBlock>
            </Border>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: PROGRESO ========== -->
        <Grid x:Name="PageProgress" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Instalando" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock x:Name="ProgressSubtitle" Text="Ejecutando pasos seleccionados..."
                       Foreground="#FF6C7086" FontSize="12" Margin="0,6,0,14"/>
            <StackPanel x:Name="StepsPanel"/>
            <ProgressBar x:Name="OverallBar" Height="6" Margin="0,18,0,0" Minimum="0" Maximum="100"
                         Background="#FF313244" Foreground="#FF89B4FA" BorderThickness="0"/>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: TAILSCALE ========== -->
        <Grid x:Name="PageTailscale" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Conecta tu red privada" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock TextWrapping="Wrap" Foreground="#FFA6ADC8" FontSize="13" Margin="0,10,0,14" LineHeight="20">
Ahora conectaras este equipo a Tailscale con TU propia cuenta (Google, Microsoft o GitHub). La red privada quedara a tu nombre: solo los dispositivos de TU cuenta podran acceder a este equipo. Nadie mas (ni quien creo este instalador) tendra acceso.</TextBlock>

            <Border Background="#FF313244" CornerRadius="8" Padding="14" x:Name="TsStatusCard">
              <StackPanel>
                <TextBlock x:Name="TsStatus" Text="Tailscale instalado. Listo para conectar." Foreground="#FFCDD6F4" FontSize="14" TextWrapping="Wrap"/>
                <TextBlock x:Name="TsDetail" Text="" Foreground="#FF6C7086" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap"/>
                <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                  <Button x:Name="BtnTsLogin" Style="{StaticResource BtnGhost}" Content="Login Tailscale"/>
                  <Button x:Name="BtnTsRepair" Style="{StaticResource BtnGhost}" Content="Reparar conexion" Margin="8,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>

            <StackPanel x:Name="TsLoginPanel" Visibility="Collapsed" Margin="0,14,0,0">
              <TextBlock Text="1. Abre este enlace en tu navegador e inicia sesion con TU cuenta:" Foreground="#FFCDD6F4" FontSize="13"/>
              <Button x:Name="BtnTsUrl" Style="{StaticResource BtnGhost}" Margin="0,8" HorizontalAlignment="Left">
                <TextBlock x:Name="TsUrlText" Text="" Foreground="#FF89DCEB" FontSize="13"/>
              </Button>
              <TextBlock Text="2. Autoriza el equipo. Esta ventana detectara la conexion automaticamente."
                         Foreground="#FF6C7086" FontSize="12" TextWrapping="Wrap"/>
            </StackPanel>

            <StackPanel x:Name="TsDonePanel" Visibility="Collapsed" Margin="0,14,0,0">
              <Border Background="#FF313244" CornerRadius="8" Padding="14" BorderBrush="#FFA6E3A1" BorderThickness="1">
                <StackPanel>
                  <TextBlock Text="Conectado a tu red Tailscale" Foreground="#FFA6E3A1" FontWeight="SemiBold" FontSize="14"/>
                  <TextBlock x:Name="TsIpText" Text="" Foreground="#FFCDD6F4" FontSize="16" FontWeight="Bold" Margin="0,6,0,0"/>
                  <TextBlock x:Name="TsAccountText" Text="" Foreground="#FF6C7086" FontSize="12"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: CREDENCIALES ========== -->
        <Grid x:Name="PageCreds" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Credenciales de acceso" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"/>
            <TextBlock Text="Guardalas en un lugar seguro: la contrasena no se volvera a mostrar."
                       Foreground="#FFF9E2AF" FontSize="12.5" Margin="0,6,0,14"/>
            <Border Background="#FF313244" CornerRadius="8" Padding="16">
              <StackPanel>
                <TextBlock Text="Usuario" Foreground="#FF6C7086" FontSize="12"/>
                <TextBlock x:Name="CredUser" Text="-" Foreground="#FFCDD6F4" FontSize="18" FontWeight="Bold" Margin="0,2,0,12"/>
                <TextBlock x:Name="CredPassLabel" Text="Contrasena" Foreground="#FF6C7086" FontSize="12"/>
                <Grid Margin="0,4,0,0">
                  <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                  <Border Grid.Column="0" Background="#FF181825" CornerRadius="6" Padding="12,6" VerticalAlignment="Center">
                    <TextBox x:Name="CredPass" Text="-" Foreground="#FFF9E2AF" FontSize="17" FontWeight="Bold" FontFamily="Consolas"
                             Background="Transparent" BorderThickness="0" IsReadOnly="True" VerticalContentAlignment="Center" Cursor="IBeam"/>
                  </Border>
                  <Button Grid.Column="1" x:Name="BtnCopyPass" Style="{StaticResource BtnGhost}" Content="Copiar" VerticalAlignment="Center" Margin="10,0,0,0"/>
                </Grid>
              </StackPanel>
            </Border>
            <Border Background="#FF313244" CornerRadius="8" Padding="14" Margin="0,16,0,0">
              <StackPanel>
                <TextBlock Text="Archivos .rdp generados (listos para copiar)" Foreground="#FFCDD6F4" FontWeight="SemiBold" FontSize="13.5"/>
                <TextBox x:Name="CredRdpFiles" Text="" Foreground="#FFA6ADC8" FontSize="12.5" Margin="0,6,0,0"
                         Background="Transparent" BorderThickness="0" IsReadOnly="True" TextWrapping="Wrap"
                         FontFamily="Consolas" Cursor="IBeam"/>
                <TextBlock Text="Copia el .rdp a cualquier equipo cliente, abrelo con mstsc y usa estas credenciales."
                           Foreground="#FF6C7086" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap"/>
                <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                  <Button x:Name="BtnCopyRdp" Style="{StaticResource BtnGhost}" Content="Copiar rutas"/>
                  <Button x:Name="BtnOpenRdp" Style="{StaticResource BtnGhost}" Content="Abrir carpeta" Margin="8,0,0,0"/>
                  <Button x:Name="BtnExportClient" Style="{StaticResource BtnGhost}" Content="Exportar paquete cliente (.zip)" Margin="8,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>
          </StackPanel>
        </Grid>

        <!-- ========== PAGINA: FINAL ========== -->
        <Grid x:Name="PageFinish" Visibility="Collapsed">
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="FinishIcon" Text="OK" FontSize="40" FontWeight="Bold" Foreground="#FFA6E3A1" HorizontalAlignment="Center"/>
            <TextBlock Text="Instalacion completada" FontSize="26" FontWeight="Bold" Foreground="#FFCDD6F4"
                       HorizontalAlignment="Center" Margin="0,10,0,0"/>
            <TextBlock x:Name="FinishSummary" Text="" TextWrapping="Wrap" TextAlignment="Center"
                       Foreground="#FFA6ADC8" FontSize="13" Margin="30,16" LineHeight="21"/>
          </StackPanel>
        </Grid>
      </Grid>

      <!-- ======================= NAV INFERIOR ======================= -->
      <Grid Grid.Row="1" Margin="0,14,0,0">
        <Button x:Name="BtnBack" Style="{StaticResource BtnGhost}" Content="&lt; Atras"
                HorizontalAlignment="Left" Visibility="Collapsed"/>
        <Button x:Name="BtnNext" Style="{StaticResource BtnPrimary}" Content="Comenzar &gt;"
                HorizontalAlignment="Right"/>
      </Grid>
    </Grid>
  </Grid>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# --- Referencias UI ----------------------------------------------------------
$ui = @{}
foreach ($n in @('Sidebar','PageWelcome','PageHow','PageOptions','PageProgress','PageTailscale','PageCreds','PageFinish',
                 'BtnBack','BtnNext','OptWrapper','OptDefender','OptUser','OptTailscale','OptFirewall','OptWU',
                 'StepsPanel','OverallBar','ProgressSubtitle','TsStatus','TsDetail','TsLoginPanel','BtnTsUrl','TsUrlText','BtnTsLogin','BtnTsRepair',
                 'TsDonePanel','TsIpText','TsAccountText','CredUser','CredPass','CredRdpFiles','BtnCopyPass','BtnCopyRdp','BtnOpenRdp','BtnExportClient','FinishSummary','FinishIcon')) {
    $ui[$n] = $window.FindName($n)
}

# --- Animaciones -------------------------------------------------------------
$script:spinners = @{}

function New-Spinner {
    $e = New-Object System.Windows.Shapes.Ellipse
    $e.Width = 18; $e.Height = 18
    $e.Stroke = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#89B4FA')
    $e.StrokeThickness = 2.5
    $dash = New-Object System.Windows.Media.DoubleCollection
    $dash.Add(8.0); $dash.Add(5.0)
    $e.StrokeDashArray = $dash
    $e.RenderTransformOrigin = '0.5,0.5'
    $rt = New-Object System.Windows.Media.RotateTransform
    $e.RenderTransform = $rt
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 360, [TimeSpan]::FromSeconds(1.2))
    $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $rt.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)
    return $e
}

function Fade-In($element, [double]$fromX = 26) {
    $element.Opacity = 0
    $tt = New-Object System.Windows.Media.TranslateTransform($fromX, 0)
    $element.RenderTransform = $tt
    $fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromMilliseconds(320))
    $slide = New-Object System.Windows.Media.Animation.DoubleAnimation($fromX, 0, [TimeSpan]::FromMilliseconds(320))
    $slide.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
    $element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $slide)
}

function Pop-In($element) {
    $st = New-Object System.Windows.Media.ScaleTransform(0.4, 0.4)
    $element.RenderTransform = $st
    $element.RenderTransformOrigin = '0.5,0.5'
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0.4, 1, [TimeSpan]::FromMilliseconds(260))
    $anim.EasingFunction = New-Object System.Windows.Media.Animation.BackEase
    $st.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $anim)
    $st.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $anim)
    Fade-In $element 0
}

# --- Navegacion de paginas ---------------------------------------------------
$script:pages  = @('PageWelcome','PageHow','PageOptions','PageProgress','PageTailscale','PageCreds','PageFinish')
$script:titles = @('Bienvenida','Como funciona','Opciones','Instalacion','Tailscale','Credenciales','Listo')
$script:pageIndex = 0

# Construir sidebar
$script:sidebarItems = @()
foreach ($t in $script:titles) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $t; $tb.FontSize = 13; $tb.Margin = '0,7'
    $tb.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#6C7086')
    $ui.Sidebar.Children.Add($tb) | Out-Null
    $script:sidebarItems += $tb
}

function Update-Sidebar {
    for ($i = 0; $i -lt $script:sidebarItems.Count; $i++) {
        $item = $script:sidebarItems[$i]
        if ($i -eq $script:pageIndex) {
            $item.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#89B4FA')
            $item.FontWeight = 'Bold'
            Pop-In $item
        } elseif ($i -lt $script:pageIndex) {
            $item.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#A6E3A1')
            $item.FontWeight = 'Normal'
        } else {
            $item.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#6C7086')
            $item.FontWeight = 'Normal'
        }
    }
}

function GoTo-Page([int]$idx) {
    $ui[$script:pages[$script:pageIndex]].Visibility = 'Collapsed'
    $script:pageIndex = $idx
    $page = $ui[$script:pages[$idx]]
    $page.Visibility = 'Visible'
    Fade-In $page
    Update-Sidebar

    $ui.BtnBack.Visibility = $(if ($idx -in @(1,2)) {'Visible'} else {'Collapsed'})
    $ui.BtnNext.Visibility = 'Visible'
    switch ($idx) {
        0 { $ui.BtnNext.Content = 'Comenzar >' }
        1 { $ui.BtnNext.Content = 'Siguiente >' }
        2 { $ui.BtnNext.Content = 'Instalar >' }
        3 { $ui.BtnNext.Visibility = 'Collapsed' }
        4 { $ui.BtnNext.Content = 'Continuar >' }
        5 { $ui.BtnNext.Content = 'Finalizar >' }
        6 { $ui.BtnNext.Content = 'Cerrar' }
    }
}

# ============================================================================
# Definicion de pasos de instalacion (independientes)
# ============================================================================
$script:stepDefs = @(
    @{ Id='wrapper';  Name='Instalar RDP Wrapper';            Opt='OptWrapper' }
    @{ Id='ini';      Name='Actualizar base de datos INI';    Opt='OptWrapper' }
    @{ Id='defender'; Name='Exclusiones en Windows Defender'; Opt='OptDefender' }
    @{ Id='wu';       Name='Desactivar Windows Update';       Opt='OptWU' }
    @{ Id='user';     Name='Crear usuario RDP dedicado';      Opt='OptUser' }
    @{ Id='tailscale';Name='Instalar Tailscale';              Opt='OptTailscale' }
    @{ Id='firewall'; Name='Restringir puerto 3389';          Opt='OptFirewall' }
)

$script:stepRows = @{}

function Build-StepsUI($selected) {
    $ui.StepsPanel.Children.Clear()
    $script:stepRows = @{}
    foreach ($s in $selected) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'; $row.Margin = '0,5'

        $iconHost = New-Object System.Windows.Controls.ContentControl
        $iconHost.Width = 24
        $glyph = New-Object System.Windows.Controls.TextBlock
        $glyph.Text = '...'; $glyph.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#6C7086')
        $glyph.FontSize = 14; $glyph.VerticalAlignment = 'Center'
        $iconHost.Content = $glyph

        $txt = New-Object System.Windows.Controls.StackPanel
        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = $s.Name; $name.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#CDD6F4'); $name.FontSize = 14
        $detail = New-Object System.Windows.Controls.TextBlock
        $detail.Text = 'En espera'; $detail.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#6C7086'); $detail.FontSize = 11.5
        $txt.Children.Add($name) | Out-Null; $txt.Children.Add($detail) | Out-Null

        $row.Children.Add($iconHost) | Out-Null; $row.Children.Add($txt) | Out-Null
        $ui.StepsPanel.Children.Add($row) | Out-Null
        $script:stepRows[$s.Id] = [pscustomobject]@{ Host=$iconHost; Glyph=$glyph; Detail=$detail; Name=$name; LastState='' }
        Fade-In $row ($ui.StepsPanel.Children.Count * 8)
    }
}

# --- Ejecucion de pasos en runspace (UI responsiva) --------------------------
$script:sync = [hashtable]::Synchronized(@{ Status=@{}; Log=@(); Creds=$null; Done=$false; TailscaleExe=$null; LogFile=$script:LogFile })

function Start-Steps($selected) {
    $ids = $selected | ForEach-Object { $_.Id }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $script:sync)
    $rs.SessionStateProxy.SetVariable('paths', $script:Paths)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $ps.AddScript({
        param($ids)
        function Write-LogR($msg) {
            $line = '{0:HH:mm:ss.fff} [runspace] {1}' -f (Get-Date), $msg
            try { Add-Content -Path $sync.LogFile -Value $line -Encoding utf8 } catch {}
        }
        function Set-St($id, $st, $msg) { $sync.Status[$id] = @($st, $msg); Write-LogR "paso ${id}: $st - $msg" }
        Write-LogR "inicio de pasos: $($ids -join ', ')"

        foreach ($id in $ids) {
            try {
                switch ($id) {
                    'wrapper' {
                        Set-St $id 'run' 'Ejecutando instalador...'
                        if (-not $paths.RDPWInst) { throw 'No se encontro RDPWInst.exe (colocalo en dist\ o bin\)' }
                        $out = & $paths.RDPWInst -i 2>&1 | Out-String
                        Set-St $id 'ok' 'Servicio registrado con rdpwrap.dll'
                    }
                    'ini' {
                        Set-St $id 'run' 'Copiando INI actualizado...'
                        $dest = Join-Path $paths.InstallDir 'rdpwrap.ini'
                        if (Test-Path $paths.IniLocal) {
                            Copy-Item $paths.IniLocal $dest -Force
                            Set-St $id 'ok' 'INI local instalado'
                        } else {
                            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                            Invoke-WebRequest -Uri $paths.IniUrl -OutFile $dest -UseBasicParsing
                            Set-St $id 'ok' 'INI descargado e instalado'
                        }
                    }
                    'defender' {
                        Set-St $id 'run' 'Agregando exclusiones...'
                        Add-MpPreference -ExclusionPath $paths.InstallDir -ErrorAction Stop
                        Add-MpPreference -ExclusionPath "$env:WINDIR\System32\rdpwrap.dll" -ErrorAction SilentlyContinue
                        foreach ($p in 'RDPWInst.exe','RDPConf.exe','RDPCheck.exe') {
                            Add-MpPreference -ExclusionProcess $p -ErrorAction SilentlyContinue
                        }
                        Set-St $id 'ok' 'Exclusiones configuradas'
                    }
                    'wu' {
                        Set-St $id 'run' 'Deshabilitando servicios de actualizacion...'
                        foreach ($s in 'wuauserv','UsoSvc') {
                            Stop-Service $s -Force -ErrorAction SilentlyContinue
                            Set-Service $s -StartupType Disabled -ErrorAction Stop
                        }
                        $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                        New-Item -Path $k -Force | Out-Null
                        Set-ItemProperty -Path $k -Name 'NoAutoUpdate' -Value 1 -Type DWord
                        Set-St $id 'ok' 'Windows Update desactivado'
                    }
                    'user' {
                        Set-St $id 'run' 'Creando usuario local...'
                        $chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*+-=?'
                        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
                        $b = New-Object byte[] 20; $rng.GetBytes($b)
                        $pass = -join ($b | ForEach-Object { $chars[$_ % $chars.Length] })
                        $sec = ConvertTo-SecureString $pass -AsPlainText -Force
                        if (Get-LocalUser -Name 'rdp' -ErrorAction SilentlyContinue) {
                            Set-LocalUser -Name 'rdp' -Password $sec -PasswordNeverExpires $true -ErrorAction Stop
                        } else {
                            New-LocalUser -Name 'rdp' -Password $sec -PasswordNeverExpires -UserMayNotChangePassword -Description 'Cuenta dedicada RDP' -ErrorAction Stop | Out-Null
                        }
                        $g = Get-LocalGroup | Where-Object { $_.SID.Value -like '*-555' }
                        if ($g) {
                            $m = Get-LocalGroupMember -Group $g.Name -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*\rdp' }
                            if (-not $m) { Add-LocalGroupMember -Group $g.Name -Member 'rdp' -ErrorAction Stop }
                        }
                        $rdpLan = Join-Path ([Environment]::GetFolderPath('Desktop')) "rdp-$env:COMPUTERNAME.rdp"
                        @("full address:s:$env:COMPUTERNAME","username:s:rdp","prompt for credentials:i:1","screen mode id:i:2","use multimon:i:1","redirectclipboard:i:1","authentication level:i:2","enablecredsspsupport:i:1") |
                            Out-File $rdpLan -Encoding ascii
                        $sync['Creds'] = [pscustomobject]@{ User="$env:COMPUTERNAME\rdp"; Pass=$pass; RdpLan=$rdpLan; RdpTs=$null }
                        Set-St $id 'ok' "Usuario 'rdp' creado y agregado al grupo RDP"
                    }
                    'tailscale' {
                        Set-St $id 'run' 'Instalando Tailscale (winget)...'
                        $exe = 'C:\Program Files\Tailscale\tailscale.exe'
                        if (Test-Path $exe) {
                            Set-St $id 'ok' 'Tailscale ya estaba instalado'
                        } else {
                            $out = winget install --id tailscale.tailscale --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
                            if (Test-Path $exe) { Set-St $id 'ok' 'Tailscale instalado' }
                            else { throw "winget no logro instalar Tailscale: $out" }
                        }
                        $sync['TailscaleExe'] = $exe
                    }
                    'firewall' {
                        Set-St $id 'run' 'Configurando firewall...'
                        foreach ($r in 'RemoteDesktop-UserMode-In-TCP','RemoteDesktop-UserMode-In-UDP') {
                            Disable-NetFirewallRule -Name $r -ErrorAction SilentlyContinue
                        }
                        $rn = 'RDP-Wrapper-Tailscale-LAN'
                        Remove-NetFirewallRule -Name $rn -ErrorAction SilentlyContinue
                        New-NetFirewallRule -Name $rn -DisplayName 'RDP (solo Tailscale y LAN local)' `
                            -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow `
                            -RemoteAddress @('100.64.0.0/10','LocalSubnet') -Profile Any -ErrorAction Stop | Out-Null
                        Get-NetFirewallRule -DisplayName 'Remote Desktop' -ErrorAction SilentlyContinue |
                            Where-Object { ($_ | Get-NetFirewallPortFilter).LocalPort -eq '3389' } |
                            Set-NetFirewallRule -RemoteAddress @('100.64.0.0/10','LocalSubnet') -ErrorAction Stop
                        Set-St $id 'ok' 'Puerto 3389 limitado a Tailscale y LAN'
                    }
                }
            } catch {
                Set-St $id 'err' $_.Exception.Message
                Write-LogR "paso ${id} EXCEPCION: $($_.Exception.GetType().FullName): $($_.Exception.Message) en $($_.InvocationInfo.ScriptLineNumber)"
            }
        }
        Write-LogR 'fin de pasos'
        $sync.Done = $true
    }).AddArgument([string[]]@($ids)) | Out-Null   # array plano: (,$ids) anidaba y el foreach iteraba una sola vez
    $script:async = $ps.BeginInvoke()
    $script:psRunner = $ps
}

# --- Timer: refresca estado de pasos ----------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
  try {
    foreach ($id in @($sync.Status.Keys)) {
        $row = $script:stepRows[$id]
        if (-not $row -or -not $row.Detail) { continue }
        $st, $msg = $sync.Status[$id]
        if ($row.LastState -eq "$st-$msg") { continue }
        $row.LastState = "$st-$msg"
        $row.Detail.Text = [string]$msg
        switch ($st) {
            'run' {
                $row.Host.Content = New-Spinner
                $row.Detail.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#89B4FA')
            }
            'ok' {
                $t = New-Object System.Windows.Controls.TextBlock
                $t.Text = [char]0x2713; $t.FontSize = 16; $t.FontWeight = 'Bold'
                $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#A6E3A1')
                $row.Host.Content = $t; Pop-In $t
                $row.Detail.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#A6E3A1')
            }
            'err' {
                $t = New-Object System.Windows.Controls.TextBlock
                $t.Text = [char]0x2717; $t.FontSize = 16; $t.FontWeight = 'Bold'
                $t.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#F38BA8')
                $row.Host.Content = $t; Pop-In $t
                $row.Detail.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#F38BA8')
            }
        }
        $done = ($sync.Status.Values | Where-Object { $_[0] -in @('ok','err') }).Count
        $ui.OverallBar.Value = 100.0 * $done / [Math]::Max(1, $script:stepRows.Count)
    }

    if ($sync.Done -and -not $script:advanced) {
        $script:advanced = $true
        Write-Log 'pasos terminados, avanzando de pagina'
        if ($env:RDPWRAP_WIZARD_AUTOPILOT -eq '1') {
            foreach ($k in $sync.Status.Keys) { Write-Log "resumen ${k}: $($sync.Status[$k] -join ' | ')" }
            if ($sync.Creds) {
                $z = Export-ClientPackage
                Write-Log "AUTOPILOT: paquete cliente: $z"
            }
            Write-Log 'AUTOPILOT: fin, cerrando ventana'
            $window.Close()
            return
        }
        $ui.ProgressSubtitle.Text = 'Pasos completados.'
        if ($ui.OptTailscale.IsChecked) {
            GoTo-Page 4
            Init-TailscalePage
        } elseif ($ui.OptUser.IsChecked -and $sync.Creds) {
            Show-Creds; GoTo-Page 5
        } else {
            Build-Summary; GoTo-Page 6
        }
    }
  } catch {
    $timer.Stop()
    Write-Log "ERROR en tick del progreso: $($_.Exception.GetType().FullName): $($_.Exception.Message) (linea $($_.InvocationInfo.ScriptLineNumber))"
    if ($env:RDPWRAP_WIZARD_AUTOPILOT -eq '1') {
        Write-Log 'AUTOPILOT: tick fallo, cerrando ventana'
        $window.Close()
    } else {
        [System.Windows.MessageBox]::Show("Error actualizando el progreso: $($_.Exception.Message)", 'RDP Wrapper') | Out-Null
    }
  }
})

# --- Pagina Tailscale: login interactivo ------------------------------------
$script:tsTimer = $null
function Get-TsExe {
    $exe = $sync.TailscaleExe
    if (-not $exe) { $exe = 'C:\Program Files\Tailscale\tailscale.exe' }
    if (Test-Path $exe) { return $exe }
    return $null
}

function Get-TsState($exe) {
    # NoState: el demonio no responde aun (pegado o iniciando)
    $sj = & $exe status --json 2>$null | ConvertFrom-Json
    $state = if ($sj -and $sj.BackendState) { $sj.BackendState } else { 'NoState' }
    return [pscustomobject]@{ State=$state; Json=$sj }
}

function Start-TsLogin {
    # Lanza 'tailscale up' (NO se mata: sale solo al conectar) y vigila URL/estado.
    $exe = Get-TsExe
    if (-not $exe) { return }
    Write-Log 'tailscale: iniciando flujo de login (up)'
    $ui.TsStatus.Text = 'Iniciando conexion con Tailscale...'
    $ui.TsDetail.Text = ''
    $outFile = "$env:TEMP\ts-up-output.txt"
    $script:tsOutFile = $outFile
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = 'up'
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $script:tsProc = [System.Diagnostics.Process]::Start($psi)
        $script:tsOutWriter = New-Object System.IO.StreamWriter($outFile, $false)
        $onData = { param($s, $e) if ($e.Data) { $script:tsOutWriter.WriteLine($e.Data); $script:tsOutWriter.Flush() } }
        $script:tsProc.add_OutputDataReceived($onData)
        $script:tsProc.add_ErrorDataReceived($onData)
        $script:tsProc.BeginOutputReadLine()
        $script:tsProc.BeginErrorReadLine()
    } catch {
        Write-Log "tailscale: no se pudo lanzar up: $($_.Exception.Message)"
        $ui.TsStatus.Text = "No se pudo iniciar tailscale up: $($_.Exception.Message)"
        return
    }
    $script:tsTicks = 0
    if ($script:tsTimer) { $script:tsTimer.Stop() }
    $script:tsTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:tsTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:tsTimer.Add_Tick({
        $script:tsTicks++
        $exe2 = Get-TsExe
        # Buscar URL de login -> abrirla en el navegador automaticamente
        if ((Test-Path $script:tsOutFile) -and $ui.TsLoginPanel.Visibility -ne 'Visible') {
            $raw = Get-Content $script:tsOutFile -Raw -ErrorAction SilentlyContinue
            if ($raw -match 'https://login\.tailscale\.com/a/\w+') {
                $script:tsUrl = $Matches[0]
                Write-Log "tailscale: URL de login $script:tsUrl (abriendo navegador)"
                $ui.TsUrlText.Text = $script:tsUrl
                $ui.TsLoginPanel.Visibility = 'Visible'
                Fade-In $ui.TsLoginPanel
                $ui.TsStatus.Text = 'Esperando que inicies sesion en el navegador...'
                Start-Process $script:tsUrl
            }
        }
        # Estado
        $st = Get-TsState $exe2
        if ($st.State -eq 'Running') {
            Write-Log 'tailscale: conectado'
            $script:tsTimer.Stop()
            Show-TsConnected $st.Json
        } elseif ($script:tsTicks -eq 15 -and $st.State -eq 'NoState') {
            # 30s en NoState: demonio pegado, ofrecer reparacion
            Write-Log 'tailscale: demonio pegado en NoState, sugiriendo reparacion'
            $ui.TsDetail.Text = 'Tailscale no responde (pegado iniciando). Pulsa "Reparar conexion".'
        }
    })
    $script:tsTimer.Start()
}

function Repair-TsService {
    Write-Log 'tailscale: reparando (reinicio de servicio)...'
    $ui.TsStatus.Text = 'Reparando Tailscale...'
    $ui.TsDetail.Text = 'Reiniciando el servicio, espera unos segundos.'
    if ($script:tsTimer) { $script:tsTimer.Stop() }
    Restart-Service Tailscale -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 8
    Init-TailscalePage
}

function Init-TailscalePage {
    $exe = Get-TsExe
    if (-not $exe) {
        $ui.TsStatus.Text = 'Tailscale no esta instalado.'
        $ui.TsDetail.Text = 'El paso de instalacion fallo o fue omitido.'
        return
    }
    $st = Get-TsState $exe
    Write-Log "tailscale: estado al entrar a la pagina: $($st.State)"
    if ($st.State -eq 'Running') {
        Show-TsConnected $st.Json
        return
    }
    Start-TsLogin
}

function Show-TsConnected($sj) {
    $ip = $sj.Self.TailscaleIPs[0]
    $account = ''
    if ($sj.User -and $sj.Self.UserID) {
        $uid = "$($sj.Self.UserID)"
        if ($sj.User.PSObject.Properties[$uid]) { $account = $sj.User.$uid.LoginName }
    }
    $ui.TsLoginPanel.Visibility = 'Collapsed'
    $ui.TsDonePanel.Visibility = 'Visible'
    Pop-In $ui.TsDonePanel
    $ui.TsStatus.Text = 'Conexion establecida.'
    $ui.TsIpText.Text = "IP privada de este equipo:  $ip"
    $ui.TsAccountText.Text = "Cuenta propietaria de la red:  $account"
    # Generar .rdp con IP Tailscale
    if ($sync.Creds) {
        $rdpTs = Join-Path ([Environment]::GetFolderPath('Desktop')) "rdp-$env:COMPUTERNAME-tailscale.rdp"
        @("full address:s:$ip","username:s:rdp","prompt for credentials:i:1","screen mode id:i:2","use multimon:i:1","redirectclipboard:i:1","authentication level:i:2","enablecredsspsupport:i:1") |
            Out-File $rdpTs -Encoding ascii
        $sync.Creds.RdpTs = $rdpTs
    }
    $script:tsConnectedIp = $ip
}

# --- Credenciales y resumen --------------------------------------------------
function Export-ClientPackage {
    # Genera en el Escritorio un zip con todo lo que necesita el equipo CLIENTE:
    # los .rdp, credenciales.txt y el instalador de cliente (Tailscale + README).
    if (-not $sync.Creds) { Write-Log 'exportacion omitida: no hay credenciales'; return $null }
    $c = $sync.Creds

    # Asegurar el .rdp de Tailscale aunque no se haya pasado por la pagina Tailscale.
    # La IP se busca por varias vias (el demonio puede estar reiniciandose).
    $tsIp = $script:tsConnectedIp
    $tsExe = 'C:\Program Files\Tailscale\tailscale.exe'
    for ($i = 0; $i -lt 3 -and -not $tsIp; $i++) {
        if (Test-Path $tsExe) {
            try {
                $ip4 = & $tsExe ip -4 2>$null | Select-Object -First 1
                if ($ip4 -and "$ip4".Trim() -match '^100\.') { $tsIp = "$ip4".Trim() }
            } catch {}
        }
        if (-not $tsIp) {
            try {
                $tsIp = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -match '^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.' } |
                    Select-Object -First 1).IPAddress
            } catch {}
        }
        if (-not $tsIp -and $i -lt 2) { Start-Sleep -Seconds 2 }
    }
    if (-not $tsIp) { Write-Log 'ADVERTENCIA: sin IP Tailscale; el paquete sale solo con el .rdp de LAN' }
    if ($tsIp -and -not $c.RdpTs) {
        $c.RdpTs = Join-Path ([Environment]::GetFolderPath('Desktop')) "rdp-$env:COMPUTERNAME-tailscale.rdp"
        @("full address:s:$tsIp","username:s:rdp","prompt for credentials:i:1","screen mode id:i:2","use multimon:i:1","redirectclipboard:i:1","authentication level:i:2","enablecredsspsupport:i:1") |
            Out-File $c.RdpTs -Encoding ascii
    }

    $stage = Join-Path $env:TEMP "rdpwrap-cliente-$env:COMPUTERNAME"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $stage | Out-Null

    foreach ($f in @($c.RdpLan, $c.RdpTs) | Where-Object { $_ -and (Test-Path $_) }) { Copy-Item $f $stage }

    $credTxt = @"
RDP Wrapper - Credenciales de acceso remoto
============================================
Equipo host:  $env:COMPUTERNAME
Usuario:      $($c.User)
Contrasena:   $($c.Pass)

Archivos .rdp incluidos:
- rdp-$env:COMPUTERNAME.rdp            (misma red local / LAN)
- rdp-$env:COMPUTERNAME-tailscale.rdp  (desde cualquier lugar, via Tailscale)

La contrasena se regenera cada vez que se ejecuta el asistente en el host.
Si cambia, vuelve a exportar este paquete desde la pagina de credenciales.
"@
    [System.IO.File]::WriteAllText((Join-Path $stage 'credenciales.txt'), $credTxt, (New-Object System.Text.UTF8Encoding $true))

    # Plantillas del cliente (README, instalador) con sustitucion de valores
    $tplDir = Join-Path $scriptDir 'cliente'
    foreach ($t in Get-ChildItem $tplDir -File -ErrorAction SilentlyContinue) {
        $content = [System.IO.File]::ReadAllText($t.FullName)
        $content = $content.Replace('{{HOST}}', $env:COMPUTERNAME).Replace('{{TSIP}}', "$tsIp").Replace('{{USER}}', $c.User)
        $enc = if ($t.Extension -eq '.bat') { [System.Text.Encoding]::ASCII } else { New-Object System.Text.UTF8Encoding $true }
        [System.IO.File]::WriteAllText((Join-Path $stage $t.Name), $content, $enc)
    }

    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) "RDPWrap-Cliente-$env:COMPUTERNAME.zip"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path "$stage\*" -DestinationPath $zip -CompressionLevel Optimal
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "paquete cliente exportado: $zip"
    return $zip
}

function Show-Creds {
    if ($sync.Creds) {
        $ui.CredUser.Text = $sync.Creds.User
        $ui.CredPass.Text = $sync.Creds.Pass
        $files = @($sync.Creds.RdpLan, $sync.Creds.RdpTs) | Where-Object { $_ }
        $ui.CredRdpFiles.Text = ($files -join "`r`n")
        Write-Log "credenciales mostradas; rdp: $($files -join ' | ')"
    } else {
        $ui.CredUser.Text = '(no se creo usuario)'
        $ui.CredPass.Text = '-'
    }
}

function Build-Summary {
    $lines = @()
    foreach ($id in $sync.Status.Keys) {
        $st, $msg = $sync.Status[$id]
        $name = ($script:stepDefs | Where-Object Id -eq $id).Name
        $mark = if ($st -eq 'ok') {'[OK]'} else {'[X]'}
        $lines += "$mark $name - $msg"
    }
    if ($script:tsConnectedIp) { $lines += "[OK] Tailscale conectado: $($script:tsConnectedIp)" }
    if ($sync.Creds) {
        $lines += ''
        $lines += "Usuario RDP: $($sync.Creds.User)"
        foreach ($f in @($sync.Creds.RdpLan, $sync.Creds.RdpTs) | Where-Object { $_ }) { $lines += "Archivo: $f" }
    }
    $ui.FinishSummary.Text = ($lines -join "`n")
    Pop-In $ui.FinishIcon
}

# --- Eventos -----------------------------------------------------------------
$ui.BtnNext.Add_Click({
    switch ($script:pageIndex) {
        0 { GoTo-Page 1 }
        1 { GoTo-Page 2 }
        2 {
            $selected = $script:stepDefs | Where-Object { $ui[$_.Opt].IsChecked }
            if ($selected.Count -eq 0) { Build-Summary; GoTo-Page 6; return }
            GoTo-Page 3
            Build-StepsUI $selected
            Start-Steps $selected
            $timer.Start()
        }
        4 {
            if ($ui.OptUser.IsChecked -and $sync.Creds) { Show-Creds; GoTo-Page 5 }
            else { Build-Summary; GoTo-Page 6 }
        }
        5 { Build-Summary; GoTo-Page 6 }
        6 { $window.Close() }
    }
})

$ui.BtnBack.Add_Click({
    if ($script:pageIndex -gt 0) { GoTo-Page ($script:pageIndex - 1) }
})

$ui.BtnTsUrl.Add_Click({
    if ($script:tsUrl) {
        [System.Windows.Clipboard]::SetText($script:tsUrl)
        Start-Process $script:tsUrl
    }
})

$ui.BtnTsLogin.Add_Click({
    Write-Log 'tailscale: boton Login pulsado'
    Start-TsLogin
})

$ui.BtnTsRepair.Add_Click({
    $ui.TsStatus.Text = 'Reparando Tailscale...'
    $ui.TsDetail.Text = 'Reiniciando el servicio, espera unos segundos.'
    if ($script:tsTimer) { $script:tsTimer.Stop() }
    # Dejar que la UI repinte antes de bloquear con el reinicio del servicio
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(300)
    $t.Add_Tick({ $t.Stop(); Repair-TsService })
    $t.Start()
})

$ui.BtnCopyPass.Add_Click({
    if ($sync.Creds) { [System.Windows.Clipboard]::SetText($sync.Creds.Pass) }
    $ui.BtnCopyPass.Content = 'Copiada!'
})

$ui.BtnCopyRdp.Add_Click({
    if ($sync.Creds) {
        $files = @($sync.Creds.RdpLan, $sync.Creds.RdpTs) | Where-Object { $_ }
        if ($files) {
            [System.Windows.Clipboard]::SetText(($files -join "`r`n"))
            $ui.BtnCopyRdp.Content = 'Copiadas!'
            Write-Log "rutas .rdp copiadas al portapapeles"
        }
    }
})

$ui.BtnOpenRdp.Add_Click({
    if ($sync.Creds -and $sync.Creds.RdpLan -and (Test-Path $sync.Creds.RdpLan)) {
        Start-Process explorer.exe -ArgumentList "/select,`"$($sync.Creds.RdpLan)`""
    } else {
        Start-Process explorer.exe -ArgumentList ([Environment]::GetFolderPath('Desktop'))
    }
})

$ui.BtnExportClient.Add_Click({
    $zip = Export-ClientPackage
    if ($zip) {
        $ui.BtnExportClient.Content = 'Exportado!'
        Start-Process explorer.exe -ArgumentList "/select,`"$zip`""
    } else {
        $ui.BtnExportClient.Content = 'Sin credenciales'
    }
})

$window.Add_Loaded({ Update-Sidebar; Fade-In $ui.PageWelcome })

# --- Autopilot (dev): ejecuta todos los pasos sin clics ---------------------
# Uso: $env:RDPWRAP_WIZARD_AUTOPILOT='1' y lanzar el script. Los resultados
# quedan en %TEMP%\RDPWrap-Wizard.log y la ventana se cierra sola al terminar.
if ($env:RDPWRAP_WIZARD_AUTOPILOT -eq '1') {
    $window.Add_Loaded({
        Write-Log 'AUTOPILOT: seleccionando todos los pasos y arrancando'
        foreach ($o in 'OptWrapper','OptDefender','OptWU','OptUser','OptTailscale','OptFirewall') {
            if ($ui[$o]) { $ui[$o].IsChecked = $true }
        }
        $selected = $script:stepDefs | Where-Object { $ui[$_.Opt].IsChecked }
        GoTo-Page 3
        Build-StepsUI $selected
        Start-Steps $selected
        $timer.Start()
    })
}
[void]$window.ShowDialog()
Write-Log 'ventana cerrada, fin del script'
