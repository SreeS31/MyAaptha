import { expect, test } from './fixtures';

for (const scenario of [
  { status: 400, message: 'Invalid username, email, phone number, or password', expected: 'Invalid username, email, phone number, or password' },
  { status: 429, message: 'Rate limited', expected: 'Too many sign-in attempts. Please wait a minute and try again.' },
  { status: 503, message: 'Unavailable', expected: 'The sign-in service is unavailable or took too long to respond. Please try again shortly.' },
]) {
  test(`sign-in reports HTTP ${scenario.status} accurately`, async ({ page }) => {
    await page.route('**/api/web-auth/login', route => route.fulfill({
      status: scenario.status, contentType: 'application/json', body: JSON.stringify({ message: scenario.message }),
    }));
    await page.goto('/auth');
    await page.getByLabel('Username or mobile number', { exact: true }).fill('test@example.test');
    await page.getByLabel('Password', { exact: true }).fill('ExamplePassword123');
    await page.getByRole('button', { name: 'Continue', exact: true }).click();
    await expect(page.getByText(scenario.expected, { exact: true })).toBeVisible();
    await expect(page).toHaveURL(/\/auth$/);
  });
}
