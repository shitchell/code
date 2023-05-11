"""
Provides functions for sending emails via SMTP
"""

import mimetypes
import re
import smtplib

from email import message_from_string
from email.message import EmailMessage, Message
from pathlib import Path as _Path
from typing import IO as _IO, Iterable as _Iterable


class InvalidCredentialsError(Exception):
    """
    Exception raised when invalid credentials are provided
    """


class NoRecipientsError(Exception):
    """
    Exception raised when no recipients are provided
    """


class SMTPClient:
    """
    A class for sending emails via SMTP
    """

    def __init__(
        self,
        smtp_user: str,
        smtp_password: str,
        smtp_server: str = "smtp.office365.com",
        smtp_port: int = 587,
        smtp_tls: bool = True,
    ) -> None:
        """
        Initialize the SMTP client
        """
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.smtp_tls = smtp_tls
        self.smtp_user = smtp_user
        self.smtp_password = smtp_password
        if not self._test_auth():
            raise InvalidCredentialsError(
                f"Username '{smtp_user}' or password '{smtp_password}' is invalid"
            )

    def _test_auth(self) -> bool:
        """
        Use the initialized credentials to test the SMTP server
        """
        try:
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as smtp:
                smtp.ehlo()
                if self.smtp_tls:
                    smtp.starttls()
                smtp.login(self.smtp_user, self.smtp_password)
                smtp.quit()
        except smtplib.SMTPException:
            return False
        return True

    @staticmethod
    def _generate_email_list(emails: str | _Iterable | dict[str, str]) -> str:
        """
        Accepts a string, list, or dict of names:emails and returns an SMTP compatible
        comma delimited string of recipients
        """
        email_list_str: str = ""
        if isinstance(emails, str):
            email_list_str = emails
        elif isinstance(emails, bytes):
            email_list_str = emails.decode()
        elif isinstance(emails, dict):
            email_list_str = ", ".join(
                [f"{name} <{email}>" for name, email in emails.items()]
            )
        elif isinstance(emails, _Iterable):
            email_list: list[str] = []
            for address in emails:
                if isinstance(address, str):
                    email_list.append(address)
                elif isinstance(address, bytes):
                    email_list.append(address.decode("utf-8"))
                elif isinstance(address, (list, tuple)) and len(address) == 2:
                    email_list.append(f"{address[0]} <{address[1]}>")
                elif isinstance(address, dict):
                    email_list.append(SMTPClient._generate_email_list(address))
                elif isinstance(address, _Iterable):
                    email_list.append(SMTPClient._generate_email_list(address))
                else:
                    email_list.append(str(address))
            email_list_str = ", ".join(email_list)
        else:
            raise TypeError("recipients must be a string, list, or dict")

        return email_list_str

    @staticmethod
    def _html_to_text(html: str) -> str:
        """
        Converts HTML to plain text, converting a few tags to markdown-ish text and
        removing the rest

        Args:
            html (str): The HTML to convert

        Returns:
            str: The plain text version of the HTML
        """
        text: str
        # Replace some tags with markdown-ish text and remove the rest
        text = re.sub("\n+", "\n", html)
        text = re.sub(r"<br\s*/?>", "\n", text)
        text = re.sub(r"<(strong|b)>(.*?)</(strong|b)>", "**\\2**", text)
        text = re.sub(r"<(i|em)>(.*?)</(i|em)>", "*\\2*", text)
        text = re.sub(r"<u>(.*?)</u>", "__\\1__", text)
        text = re.sub(r"<s>(.*?)</s>", "~~\\1~~", text)
        text = re.sub(r"</p>", "\n\n", text)
        text = re.sub(
            r"""<a\s+href=['"]?([^'" ]+)[^>]*>(.*?)</a>""", "[\\2](\\1)", text
        )
        text = re.sub(r"""<img\s+src=['"]?([^'" ]+)[^>]*>""", "![image](\\1)", text)
        text = re.sub(r"<[^>]+>", "", text)
        return text

    @staticmethod
    def build_email(
        to: str | _Iterable | dict[str, str] = [],
        subject: str = "No subject",
        sender: str = None,
        body_html: str = "",
        body_text: str = "",
        cc: str | _Iterable | dict[str, str] = [],
        bcc: str | _Iterable | dict[str, str] = [],
        attachments: dict[str, str | bytes | _Path | _IO] = {},
        continue_on_error: bool = False,
        headers: dict[str, str] = {},
    ) -> EmailMessage:
        """
        Build an email message

        Args:
            to (str): The email address of the recipient
            subject (str): The subject of the email
            sender (str): The email address of the sender
            body_html (str): The HTML body of the email
            body_text (str): The plain text body of the email
            cc (str | list | dict): The email address(es) of the CC recipient(s)
            bcc (str | list | dict): The email address(es) of the BCC recipient(s)
            attachments (dict): A filename:attachment list of attachments to include in
                                the email
            continue_on_error (bool): If True, continue sending emails even if one or
                                      more errors occur
            headers (dict): A dictionary of SMTP headers to include in the email
        """
        email: EmailMessage = EmailMessage()

        # Set the headers
        email["From"] = sender
        email["To"] = SMTPClient._generate_email_list(to)
        email["Subject"] = subject
        if cc:
            email["CC"] = SMTPClient._generate_email_list(cc)
        if bcc:
            email["BCC"] = SMTPClient._generate_email_list(bcc)
        for header, value in headers.items():
            email[header] = value

        # Add the body
        if body_text:
            email.set_content(body_text)
        if body_html:
            if not body_text:
                # If no text body is provided, replace some HTML tags with markdown-ish
                # text and remove the rest of the HTML tags
                body_text = SMTPClient._html_to_text(body_html)
                email.set_content(body_text)
            email.add_alternative(body_html, subtype="html")

        # Add the attachments
        for filename, attachment in attachments.items():
            content: bytes = None

            # If the attachment is a string or Path, read the file at that path
            if isinstance(attachment, (str, _Path)):
                try:
                    content = open(attachment, "rb").read()
                except FileNotFoundError as e:
                    if continue_on_error:
                        continue
                    else:
                        raise e
            # If the attachment is a bytes object, assume it is the content of the file
            if isinstance(attachment, bytes):
                content = attachment
            # If the attachment is an IO object, read the content from the IO object
            if isinstance(attachment, _IO):
                content = attachment.read()

            # Try to determine the content type and subtype
            mimetype = mimetypes.guess_type(filename)[0]

            # If the mimetype is not found, use the python-magic library if it's
            # installed
            if mimetype is None:
                try:
                    import magic

                    mimetype = magic.from_buffer(content, mime=True)
                except ImportError:
                    pass

            # If the mimetype is still not found, use a default value
            if mimetype is None:
                mimetype = "application/octet-stream"

            # Add the attachment to the email
            maintype, subtype = mimetype.split("/", 1)

            email.add_attachment(
                content,
                maintype=maintype,
                subtype=subtype,
                filename=filename,
            )

        return email

    def send_email(
        self,
        to: str | _Iterable | dict[str, str] = [],
        subject: str = "No subject",
        sender: str = None,
        body_html: str = "",
        body_text: str = "",
        cc: str | _Iterable | dict[str, str] = [],
        bcc: str | _Iterable | dict[str, str] = [],
        attachments: dict[str, str | bytes | _Path | _IO] = {},
        headers: dict[str, str] = {},
        continue_on_error: bool = False,
        raw: str = "",
    ) -> EmailMessage:
        """
        Send an email via SMTP
        """
        # Require at least one receiptient be provided in either the to, raw, or headers
        if not to and "To" not in headers and not re.match(r"^To:.*$", raw, re.I):
            raise NoRecipientsError("No recipients provided")

        with smtplib.SMTP(self.smtp_server, self.smtp_port) as smtp:
            # Start a connection with the SMTP server
            smtp.ehlo()
            if self.smtp_tls:
                smtp.starttls()
            smtp.login(self.smtp_user, self.smtp_password)

            # Set the sender if not set
            if sender is None:
                sender = self.smtp_user

            # Generate the email
            email: Message
            if raw:
                email = message_from_string(raw)
            else:
                email = SMTPClient.build_email(
                    to,
                    subject,
                    sender,
                    body_html,
                    body_text,
                    cc,
                    bcc,
                    attachments,
                    continue_on_error,
                    headers,
                )

            # Send the email
            smtp.send_message(email)
            return email

        raise Exception("Unable to send email")


# TODO: raise better exception if email fails to send
