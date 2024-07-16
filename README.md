# Domain Credentials Hunter

This PowerShell script is a Windows domain credentials phishing tool designed for post-exploitation scenarios. It repeatedly prompts users for their domain credentials, verifies their validity automatically, and logs successful logins to a JSON file. The script persists in requesting credentials until a domain admin logs in, leveraging a scenario where the most vulnerable users like secretaries ask for help from the "tech guy".

## Features

- **Domain Auto-detection**: Identifies the current domain automatically.
- **Credential Dialog**: Displays a Windows Security dialog to collect domain credentials.
- **Credential Validation**: Automatically checks the validity of the entered credentials against the detected domain.
- **Logging**: Records valid credentials, including username, password, and group memberships, to a JSON file (`C:\login_success_log.json`) (You should probably change this in a realistic pentest scenario).
- **Persistent Credential Prompt**: Continues to ask for credentials until a domain admin provides their login.
- **Topmost Window Enforcement**: I've tried to ensures the credential prompt and error dialogs stay on top of other windows, but failed af. `Help needed to make it work`.
- **Error Handling**: Displays error messages if the domain is not detected or if no credentials are entered. `Probably no-need to do this IRL.`

## Requirements

- Windows PowerShell
- Domain-joined machine
- Permissions to execute PowerShell scripts

## Execution

1. Save the PowerShell script to "your" computer.
2. Open PowerShell with local administrative privileges (Didn't check without local admin).
3. Execute the script with the following command:
    ```powershell
    .\domain-credentials-hunter.ps1
    ```
Or use `meterpreter` and `load powershell` command and you're good to go.

## Logs

- Logs of successful logins are saved in `C:\login_success_log.json`.
- Each log entry includes the timestamp, username, password, and user groups.

## Known Issues

- Top-most functionality isn't working. At all.

## Disclaimer

This script is intended for ethical use and educational purposes only. Unauthorized use may be illegal and unethical. The author is not liable for any misuse or damage caused by this script.
