# Email Templates

This folder contains the email templates used by the Mailing.ps1 script.

## Template Files

### attendee-email.html
Main email template sent to attendees with their SpeedPass attachment.

**Available Placeholders:**
- `{{FirstName}}` - Replaced with attendee's first name
- `{{BANNER}}` - Replaced with banner content when -ShowBanner is used

### volunteer-email.html
Email template sent to volunteers (when using -EmailType volunteer).

**Available Placeholders:**
- `{{FirstName}}` - Replaced with volunteer's first name

### banner.html
Banner template used when -ShowBanner switch is enabled. This is inserted into the `{{BANNER}}` placeholder in attendee-email.html.

## Usage

The templates are automatically loaded by the Mailing.ps1 script. To modify email content:

1. Edit the appropriate template file
2. Save your changes
3. Run the mailing script - it will automatically use the updated templates

## Template Guidelines

- Use standard HTML formatting
- Keep templates responsive and email-client friendly
- Use placeholder syntax `{{PLACEHOLDER}}` for dynamic content
- Test templates thoroughly before mass email sends
