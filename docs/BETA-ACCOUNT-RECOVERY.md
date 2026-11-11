# Operator-assisted beta password recovery

Verified self-service recovery is not configured on the current beta. The connected GCP command service cannot run SSH, and the local CLI has no signed-in account. Password resets therefore require the authorized project operator to use Google Cloud Shell or IAP SSH. No passwords have been changed merely by preparing this tool.

`infrastructure/reset_beta_passwords.py` runs only as root on the exact reviewed beta VM/project. Supply exactly two distinct emails using repeated `--email` arguments. The default mode checks that both identify existing active account records and changes nothing. `--apply` generates independent random passwords, hashes them with BCrypt cost 12 and updates both records atomically. It revokes their refresh tokens without changing roles, MFA, phone verification or any other accounts. Existing access tokens can remain valid until their normal expiry.

Missing, duplicate or ineligible accounts abort the reset. The tool does not create accounts. Database errors do not print passwords or SQL. Credentials are saved in a unique root-only mode-0600 JSON file under `/opt/myaaptha-beta/password-resets/`, with an explicit prepared/applied status. `--show-passwords` displays them only when stdout is an interactive terminal; do not run that option as a startup script or send its output to shared logs. Store the credentials in the owners' password managers and remove the private handoff file afterward. No email delivery is attempted.

Use a commit-pinned reviewed copy transferred to the VM through IAP, then run:

```sh
sudo python3 /tmp/myaaptha-beta-password-reset.py \
  --email ACCOUNT_ONE_EMAIL --email ACCOUNT_TWO_EMAIL \
  --apply --show-passwords
```

The SSH connection must allocate a terminal for password display. Do not paste generated passwords into chat. This operator tool is not exposed through the application's public API and does not bypass the web recovery verification requirement.

Validation: four focused unit tests passed. A disposable PostgreSQL integration check verified that a mismatched account rolls back both password changes and token deletion, while a successful operation changes exactly the two intended hashes, revokes only their refresh tokens and preserves an unrelated account/session. No real account data was used for these tests.
