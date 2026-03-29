# Google Play Account Deletion Form Template

_Last reviewed: March 27, 2026_

This guide helps BeFam satisfy **Data safety > Account deletion** requirements
in Google Play Console with:

- one public account-deletion request URL page
- one Google Form template
- one copy-paste response set for Play Console

## 1) Public account deletion URL (for Play Console)

Create a public page (no login required), for example:

- `https://<your-domain>/delete-account`
- or a public project docs page

Minimum page content (copy-ready):

```text
BeFam Account Deletion Request

To request deletion of your account and associated data, please submit this form:
<FORM_URL>

Required details:
- Registered phone number (E.164 format, e.g. +84901234567)
- Display name (if available)
- Contact email (if available)

Processing steps:
1) We verify account ownership.
2) We confirm request intake.
3) We process deletion based on the requested scope.

Data deleted for full account deletion:
- Login profile and session linkage
- Device push-notification tokens
- User-provided profile details

Data that may be retained for legal/operational reasons for a limited period:
- Payment transaction and audit logs (if applicable)
- Security/fraud-prevention records

Processing timeline:
- Intake confirmation: within 3 business days
- Deletion completion: within 30 days (except legally required retention)

Support contact:
- Email: <SUPPORT_EMAIL>
```

## 2) Google Form template

Form title:

`BeFam - Account Deletion Request`

Form description:

```text
Use this form to request deletion of your BeFam account and associated data.
Please provide the same phone number used for sign-in so we can verify ownership.
Processing time is up to 30 days.
```

Suggested questions:

1. **Full name** (Short answer, Required)
2. **BeFam account phone number (E.164)** (Short answer, Required)
   - Example: `+84901234567`
3. **Contact email** (Short answer, Optional)
4. **Member ID or UID (if known)** (Short answer, Optional)
5. **Request type** (Multiple choice, Required)
   - Delete my full account and associated data
   - Request partial data deletion
6. **Additional details (optional)** (Paragraph, Optional)
7. **Confirmation** (Checkbox, Required)
   - I confirm I am the account owner or an authorized requester.
   - I understand some records may be retained for legal obligations.

Recommended settings:

- Collect email addresses: `On`
- Send responders a copy: `On`
- Limit to 1 response: `Off` (to avoid blocking non-Google users)

## 3) Play Console copy-paste

In `Data safety`:

- **Delete account URL**: paste the public URL from section (1)
- **Do you provide a way for users to request that some or all data is deleted...?**
  - If you only support full account deletion today: select `No`
  - If partial deletion is truly supported in production: select `Yes`

## 4) Confirmation email template

```text
Subject: [BeFam] Account deletion request received

Hello {{name}},

We have received your BeFam account deletion request for phone number {{phone}}.
Request ID: {{ticket_id}}.

We will verify and process this request within up to 30 days.
If more information is needed, our support team will contact you via this email.

Best regards,
BeFam Support
```

## 5) Pre-submit checklist

- [ ] Deletion URL is publicly accessible without sign-in
- [ ] URL page clearly states deleted data / retained data / timeline
- [ ] Google Form is live and receiving submissions
- [ ] Support email is valid on both URL page and Play Console

