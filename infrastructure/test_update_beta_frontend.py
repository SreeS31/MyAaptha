import unittest
from update_beta_frontend import replace_image, validate_image


class FrontendUpdateTest(unittest.TestCase):
    image = 'ghcr.io/srees31/myaaptha-frontend@sha256:' + 'a' * 64

    def test_only_frontend_reference_changes(self):
        original = 'MYAAPTHA_DOMAIN=beta.test\nMYAAPTHA_FRONTEND_IMAGE=old\nPOSTGRES_DB=existing\nOTHER_SETTING=unchanged\n'
        expected = original.replace('MYAAPTHA_FRONTEND_IMAGE=old', 'MYAAPTHA_FRONTEND_IMAGE=' + self.image)
        self.assertEqual(replace_image(original, self.image), expected)

    def test_rejects_unpinned_wrong_repository_and_environment_injection(self):
        for value in ['ghcr.io/srees31/myaaptha-frontend:latest', self.image + '\nOTHER_SETTING=bad', self.image.replace('frontend', 'backend')]:
            with self.assertRaises(ValueError):
                validate_image(value)

    def test_refuses_missing_or_duplicate_image_setting(self):
        for value in ['POSTGRES_DB=existing\n', 'MYAAPTHA_FRONTEND_IMAGE=one\nMYAAPTHA_FRONTEND_IMAGE=two\n']:
            with self.assertRaises(ValueError):
                replace_image(value, self.image)


if __name__ == '__main__':
    unittest.main()
