#!/usr/bin/env python3

import os, sys, smtplib, ssl

smtp_server = os.getenv('SMTP_SERVER', "smtp.gmail.com")
port = os.getenv('SMTP_PORT', 587)  # For starttls
sender_email = os.getenv('SMTP_SENDER_EMAIL', "your_gmail@gmail.com")
receiver_emails = os.getenv('SMTP_RECEIVER_EMAILS', "user1@gmail.com;user2@gmail.com").split(';')
username = os.getenv('SMTP_USERNAME', sender_email)
password = os.getenv('SMTP_PASSWD', '')
email_msg = os.getenv('SMTP_MSG', """\
Subject: Test Alert! Computation6 is disconnected from VPN

This message is automatically sent from S2-VPN server.""")

# Create a secure SSL context
context = ssl.create_default_context()

# Try to log in to server and send email
N_success = 0
try:
	server = smtplib.SMTP(smtp_server, port)
	server.ehlo() # Can be omitted
	server.starttls(context=context) # Secure the connection
	server.ehlo() # Can be omitted
	server.login(username, password)
	for receiver_email in receiver_emails:
		try:
			server.sendmail(sender_email, receiver_email, email_msg)
			print(f'Email sent to {receiver_email} successfully!')
			N_success += 1
		except Exception as e:
			print(f'Email sent to {receiver_email} failed: {e}')
except Exception as e:
	# Print any error messages to stdout
	print(e)
finally:
	server.quit()

sys.exit(0 if N_success else 1)
