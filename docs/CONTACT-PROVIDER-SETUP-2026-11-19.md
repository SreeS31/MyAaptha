# Google and Outlook contact connections

The beta VM had neither Google nor Microsoft OAuth application credentials configured. Signing into `gcloud` authorizes deployment; it does not register a contact-import application. The Google People API was enabled on 19 November 2026. Each member must still sign into their provider and approve read-only contact access.

## Google

1. Open [Google Auth Platform](https://console.cloud.google.com/auth/clients?project=project-5c36c021-87c7-4cfc-833) in the existing MyAaptha project.
2. Complete Branding if prompted, using MyAaptha and your support/developer email. For Gmail users, choose an External audience. While the app is in Testing, add the Gmail accounts that will test it under Audience.
3. Under Data Access, configure `https://www.googleapis.com/auth/contacts.readonly`.
4. Create an OAuth client with application type **Web application**. Set JavaScript origin to `https://35-244-31-192.sslip.io` and authorized redirect URI to `https://35-244-31-192.sslip.io/api/contact-organizer/oauth/callback/google`.
5. Download the client JSON to a private local folder. Do not paste its secret into chat, GitHub, or a screenshot. Provide its local path to the deployment operator.

The reviewed activation helper is:

```powershell
powershell -ExecutionPolicy Bypass -File infrastructure/configure-contacts-beta.ps1 -CredentialsFile "C:\private\google-oauth-client.json"
```

It transfers the file into a private directory through IAP/SSH, verifies the expected project/VM and callback, stores settings in the protected beta runtime, restarts only the backend, checks the applied values without printing them, and checks health. Failure restores the prior runtime settings. It deletes the uploaded credential copy; the original local download remains with its owner. Deploy the updated `compose.gcp-beta.yml` before activation.

For access beyond the provider's testing audience, complete the provider's publishing and verification process. The setup above does not bypass that process.

## Outlook

Register an app supporting the intended Microsoft organizational/personal accounts, with delegated `Contacts.Read` and the callback `https://35-244-31-192.sslip.io/api/contact-organizer/oauth/callback/microsoft`. Its confidential Web application needs an application ID and secret. Supply these through a private JSON file with `client_id`, `client_secret`, and `redirect_uris`; run the same helper with `-Provider microsoft`. Do not use a directory-wide application permission for this member-authorized import.

References: [Google OAuth application setup](https://developers.google.com/identity/oauth2/web/guides/get-google-api-clientid), [Google web-server OAuth](https://developers.google.com/identity/protocols/oauth2/web-server), [Microsoft app registration](https://learn.microsoft.com/en-us/graph/auth-register-app-v2), [Microsoft contact permissions](https://learn.microsoft.com/en-us/graph/api/user-list-contacts).
