Installs Postfix and Dovecot.
Configures TLS encryption using Let's Encrypt.
Sets up SPF, DKIM, and DMARC.
Outputs the required DNS records.
Save this script and execute it with root privileges.
Usage:
Save the script and make it executable:


chmod +x <filename>.sh
Run the script as root or with sudo:

sudo ./<filename>.sh
Follow the on-screen prompts to provide your domain and email.

Post-Setup Validation:
Use MxToolBox to test your SMTP server, DNS records, and email compliance.
Send a test email to verify inbound and outbound functionality.
This script automates most of the setup while ensuring compliance with SPF, DKIM, DMARC, and TLS encryption.
