import unittest
from update_beta_interests import image, replace_images

class InterestReleaseBoundaryTest(unittest.TestCase):
    def test_rejects_mutable_foreign_or_mismatched_images(self):
        for value in ['latest', 'ghcr.io/srees31/myaaptha-backend:latest', 'ghcr.io/another/myaaptha-backend@sha256:'+'a'*64, 'ghcr.io/srees31/myaaptha-frontend@sha256:'+'a'*64, 'ghcr.io/srees31/myaaptha-backend@sha256:'+'a'*64+';reboot']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                image(value, 'backend')

    def test_changes_only_the_two_application_images_and_preserves_other_config(self):
        backend='ghcr.io/srees31/myaaptha-backend@sha256:'+'a'*64
        frontend='ghcr.io/srees31/myaaptha-frontend@sha256:'+'b'*64
        original='MYAAPTHA_BACKEND_IMAGE=old-api\nMYAAPTHA_FRONTEND_IMAGE=old-web\nPOSTGRES_DB=keep_database\nMYAAPTHA_GCS_BUCKET=keep_media\nOTHER=keep=value\n'
        updated=replace_images(original,backend,frontend)
        self.assertIn('MYAAPTHA_BACKEND_IMAGE='+backend,updated)
        self.assertIn('MYAAPTHA_FRONTEND_IMAGE='+frontend,updated)
        self.assertTrue(updated.endswith('POSTGRES_DB=keep_database\nMYAAPTHA_GCS_BUCKET=keep_media\nOTHER=keep=value\n'))

    def test_missing_or_duplicate_image_settings_fail_closed(self):
        backend='ghcr.io/srees31/myaaptha-backend@sha256:'+'a'*64
        frontend='ghcr.io/srees31/myaaptha-frontend@sha256:'+'b'*64
        for original in ['POSTGRES_DB=keep\n', 'MYAAPTHA_BACKEND_IMAGE=one\nMYAAPTHA_BACKEND_IMAGE=two\nMYAAPTHA_FRONTEND_IMAGE=web\n']:
            with self.assertRaises(ValueError):
                replace_images(original,backend,frontend)
