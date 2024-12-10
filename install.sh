#!/bin/bash

# SMTP Server Setup Script
# Fully automated setup for an SMTP server with compliance and encryption.

set -e

echo "=== SMTP Server Deployment Script ==="

# Variables
DOMAIN=""
EMAIL=""
SERVER_IP=$(curl -s ifconfig.me)
INSTALL_DIR="/etc/smtp_server"

# Prompt user for input
read -p "Enter your domain name (e.g., example.com): " DOMAIN
read -p "Enter your email address for Let's Encrypt (e.g., admin@example.com): " EMAIL

echo "Setting up SMTP server for domain: $DOMAIN"

# Update and install necessary packages
echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y postfix dovecot-core dovecot-imapd opendkim opendkim-tools certbot curl ufw

# Configure Postfix
echo "Configuring Postfix..."
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydomain = $DOMAIN"
postconf -e "myorigin = $DOMAIN"
postconf -e "inet_interfaces = all"
postconf -e "mydestination = localhost, $DOMAIN, mail.$DOMAIN"
postconf -e "relay_domains ="
postconf -e "home_mailbox = Maildir/"
postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem"
postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/mail.$DOMAIN/privkey.pem"
postconf -e "smtpd_use_tls=yes"
postconf -e "smtpd_tls_auth_only=yes"
postconf -e "smtpd_tls_security_level=encrypt"
postconf -e "smtp_tls_security_level=may"
postconf -e "smtpd_relay_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination"
postconf -e "smtpd_sasl_auth_enable=yes"
postconf -e "broken_sasl_auth_clients=yes"
postconf -e "smtpd_sasl_path=private/auth"
postconf -e "smtpd_sasl_type=dovecot"

# Configure Dovecot
echo "Configuring Dovecot..."
cat > /etc/dovecot/dovecot.conf <<EOF
protocols = imap lmtp
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.$DOMAIN/privkey.pem
mail_location = maildir:~/Maildir
auth_mechanisms = plain login
passdb {
  driver = pam
}
userdb {
  driver = passwd
}
EOF

# Configure DKIM
echo "Setting up DKIM..."
apt install -y opendkim opendkim-tools
cat > /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
Syslog                  yes
UMask                   002
OversignHeaders         From
KeyTable                /etc/opendkim/key.table
SigningTable            /etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
EOF

mkdir -p /etc/opendkim/keys
cat > /etc/opendkim/key.table <<EOF
mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN.private
EOF
cat > /etc/opendkim/signing.table <<EOF
*@${DOMAIN} mail._domainkey.${DOMAIN}
EOF
cat > /etc/opendkim/trusted.hosts <<EOF
127.0.0.1
localhost
$SERVER_IP
EOF

# Generate DKIM key
opendkim-genkey -s mail -d $DOMAIN
mv mail.private /etc/opendkim/keys/$DOMAIN.private
mv mail.txt /etc/opendkim/keys/$DOMAIN.txt
chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN.private
chmod 600 /etc/opendkim/keys/$DOMAIN.private

# Enable DKIM in Postfix
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 6"
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e "non_smtpd_milters = inet:localhost:8891"

systemctl restart opendkim
systemctl enable opendkim

# Obtain Let's Encrypt certificate
echo "Obtaining SSL certificate from Let's Encrypt..."
certbot certonly --standalone -d mail.$DOMAIN --agree-tos -m $EMAIL --non-interactive

# Restart services
echo "Restarting services..."
systemctl restart postfix dovecot

# Output DNS records
echo "=== Setup Complete ==="
echo "Configure the following DNS records:"
echo "1. A Record: mail.$DOMAIN -> $SERVER_IP"
echo "2. MX Record: $DOMAIN -> mail.$DOMAIN (priority 10)"
echo "3. TXT Record (SPF): v=spf1 ip4:$SERVER_IP -all"
cat /etc/opendkim/keys/$DOMAIN.txt
echo "4. Add the above DKIM TXT record."
echo "5. TXT Record (DMARC): _dmarc.$DOMAIN -> v=DMARC1; p=quarantine; rua=mailto:$EMAIL"
echo "You can now send and receive emails using your SMTP server."

exit 0
