import unittest
from reset_beta_passwords import email_targets, literal, reset_sql


class BetaPasswordResetTest(unittest.TestCase):
    def test_requires_one_or_two_distinct_email_targets(self):
        self.assertEqual(email_targets([' A@example.test ']), ['a@example.test'])
        self.assertEqual(email_targets([' A@example.test ', 'b@example.test']),
                         ['a@example.test', 'b@example.test'])
        for targets in [[], ['a@example.test', 'b@example.test', 'c@example.test'], ['A@example.test', 'a@example.test'],
                        ['a@example.test\nextra', 'b@example.test']]:
            with self.assertRaises(ValueError):
                email_targets(targets)

    def test_quotes_literal_instead_of_interpreting_sql(self):
        self.assertEqual(literal("a'@example.test"), "'a''@example.test'")

    def test_rejects_unsafe_password_encodings_before_any_sql(self):
        accounts = [{'id': 1, 'email': 'a@example.test'}, {'id': 2, 'email': 'b@example.test'}]
        for value in ['plaintext', '$6$sha512', '$2b$04$' + 'a' * 53, '$2b$12$' + 'a' * 52 + "'"]:
            with self.assertRaises(ValueError):
                reset_sql(accounts, [value, '$2b$12$' + 'a' * 53])

    def test_refuses_duplicate_accounts_and_unexpected_target_count(self):
        account = {'id': 1, 'email': 'a@example.test'}
        for accounts in [[], [account, account], [account] * 3]:
            with self.assertRaises(ValueError):
                reset_sql(accounts, ['$2b$12$' + 'a' * 53] * 2)

    def test_single_account_reset_is_bound_to_one_id_and_hash(self):
        account = {'id': 7, 'email': 'one@example.test'}
        statement = reset_sql([account], ['$2b$12$' + 'a' * 53])
        self.assertIn('IF changed <> 1 THEN', statement)
        self.assertIn('user_id IN (7)', statement)
        with self.assertRaises(ValueError):
            reset_sql([account], ['$2b$12$' + 'a' * 53] * 2)


if __name__ == '__main__':
    unittest.main()
