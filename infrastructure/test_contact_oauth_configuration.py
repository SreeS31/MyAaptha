import unittest
from configure_beta_contact_oauth import credentials, replace_settings, ORIGIN


class ContactOAuthConfigurationTest(unittest.TestCase):
    def sample(self):
        return {'web': {'client_id': 'fixture.apps.googleusercontent.com',
                        'client_secret': 'synthetic-secret',
                        'redirect_uris': [ORIGIN + '/api/contact-organizer/oauth/callback/google']}}

    def test_google_download_requires_exact_callback(self):
        self.assertEqual(len(credentials(self.sample(), 'google')), 2)
        invalid = self.sample()
        invalid['web']['redirect_uris'] = ['http://localhost:8080/callback']
        with self.assertRaises(ValueError):
            credentials(invalid, 'google')

    def test_secret_cannot_inject_environment_lines(self):
        invalid = self.sample()
        invalid['web']['client_secret'] = 'synthetic\nOTHER=value'
        with self.assertRaises(ValueError):
            credentials(invalid, 'google')

    def test_existing_runtime_values_and_other_provider_are_preserved(self):
        before = 'UNCHANGED=value\nMICROSOFT_CONTACTS_CLIENT_ID=existing\nGOOGLE_CONTACTS_CLIENT_ID=old\n'
        after = replace_settings(before, credentials(self.sample(), 'google'))
        self.assertIn('UNCHANGED=value\nMICROSOFT_CONTACTS_CLIENT_ID=existing\n', after)
        self.assertEqual(after.count('GOOGLE_CONTACTS_CLIENT_ID='), 1)
        with self.assertRaises(ValueError):
            replace_settings('GOOGLE_CONTACTS_CLIENT_ID=a\nGOOGLE_CONTACTS_CLIENT_ID=b\n', credentials(self.sample(), 'google'))
