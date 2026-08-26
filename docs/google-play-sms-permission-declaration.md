# Google Play SMS permission declaration for CircleNet

## Before opening Play Console

1. Publish a privacy-policy page that specifically covers transactional SMS access, filtering, synchronization, retention, deletion, encryption, and the fact that SMS data is never sold or used for advertising.
2. Keep `READ_SMS` only. CircleNet does not need `SEND_SMS`, `WRITE_SMS`, `RECEIVE_SMS`, MMS, call-log, or background SMS permissions for the current user-initiated import.
3. Ensure the store listing prominently describes **SMS-based money management** as a core feature.
4. Keep manual entry available when permission is declined or unavailable.
5. Create a dedicated reviewer account containing safe demonstration data.
6. Build and upload the Android App Bundle. The declaration normally appears only after Play Console detects the restricted permission in an uploaded bundle.

## Permissions Declaration Form

In Play Console open **Policy and programs → App content → Permissions Declaration Form**.

1. Review the newly detected `READ_SMS` permission.
2. Under core functionality select **SMS-based money management**.
3. Describe the feature using text similar to:

   > CircleNet uses READ_SMS only when a signed-in Android user chooses “Import SMS” in Money & insights. The app examines up to 200 recent messages on the device, filters for transaction-related messages, and sends only those candidate financial messages to the user’s private CircleNet account to extract amount, direction, merchant and category. Personal conversations are excluded. The original SMS text is not retained in the financial transaction record. Users may decline permission, use manual entry, revoke permission in Android settings, and delete imported transactions.

4. Provide reviewer steps:
   - Sign in with the dedicated reviewer account.
   - Open **Your life tools → Money & insights**.
   - Tap **Import SMS**.
   - Review the prominent disclosure and choose **Allow and import**.
   - Grant Android SMS permission.
   - Show categorized transactions and charts.
   - Repeat the flow and choose **Not now** to demonstrate graceful degradation.
5. Provide the reviewer credentials. Never provide a production user’s credentials.
6. Upload an unlisted YouTube or accessible cloud-storage video showing the complete disclosure, accept path, decline path, Android permission prompt, imported results, deletion, and permission revocation.
7. Submit the declaration and monitor **Policy status** and the developer-account email.

## Other required Play Console declarations

- Complete **Data safety** accurately for financial information, messages, user IDs, encryption in transit, deletion, and sharing practices.
- Complete **Financial features**. For the current tracker, select the closest accurate support category—normally **Other**—and do not describe CircleNet as a broker, investment executor, bank, wallet, or licensed adviser.
- Add the privacy-policy URL under **App content → Privacy policy** and expose the same policy inside the app.

## Video checklist

- App opening and sign-in.
- Navigation to Money & insights.
- Full disclosure visible without editing.
- Affirmative consent followed immediately by the Android prompt.
- Import results and charts.
- Delete an imported transaction.
- Revoke permission and show that manual tracking continues.
- Decline path and later re-entry to the permission flow.

Approval is decided by Google case-by-case. Submitting the form does not guarantee approval.
