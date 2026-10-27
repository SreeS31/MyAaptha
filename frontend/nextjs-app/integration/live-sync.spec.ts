import { expect, test } from './fixtures';
import { randomUUID } from 'node:crypto';

test('mobile API and browser share private finance and AI preferences', async ({ page, playwright }) => {
  const api = await playwright.request.newContext({ baseURL: 'http://127.0.0.1:8080' });
  const username = `sync-${randomUUID().slice(0, 12)}`;
  const email = `${username}@example.test`;
  const password = `Preview-${randomUUID()}`;
  const phoneNumber = `+1999${Date.now().toString().slice(-10)}`;
  const created = await api.post('/api/users', { data: { username, email, password, phoneNumber } });
  expect(created.status()).toBe(200);
  const login = await api.post('/api/auth/login', { data: { identifier: username, password } });
  expect(login.status()).toBe(200);
  const session = await login.json();
  const headers = { Authorization: `Bearer ${session.accessToken}` };
  const merchant = `Mobile purchase ${username}`;
  const added = await api.post('/api/finance/transactions', { headers, data: {
    amount: 123, direction: 'EXPENSE', category: 'OTHER', merchant,
    description: 'Synthetic cross-client check', occurredAt: new Date().toISOString(), source: 'MANUAL',
  } });
  expect(added.status()).toBe(200);
  await page.goto('/auth');
  await page.getByLabel('Username or mobile number', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page).toHaveURL(/dashboard/, { timeout: 20_000 });
  await page.goto('/finance');
  await expect(page.getByText(merchant, { exact: true })).toBeVisible();
  const cookies = await page.context().cookies();
  expect(cookies.some(c => c.name === 'myaaptha_access' && c.httpOnly)).toBe(true);
  expect(await page.evaluate(() => document.cookie)).not.toContain('myaaptha_access');
  await page.locator('summary').filter({hasText:'Add transactions'}).click();
  await page.getByLabel('Amount', { exact: true }).fill('45');
  await page.getByLabel('Merchant', { exact: true }).fill('Browser purchase');
  await page.getByRole('button', { name: 'Save transaction' }).click();
  await expect(page.getByText('Browser purchase', { exact: true })).toBeVisible();
  const summary = await api.get('/api/finance/summary', { headers });
  expect(summary.status()).toBe(200);
  expect((await summary.json()).transactions.some((t: { merchant: string }) => t.merchant === 'Browser purchase')).toBe(true);
  const prefs = await api.put('/api/ai/preferences', { headers, data: {
    aiEnabled: true, allowSensitiveData: true, allowPersonalization: false, activityRetentionDays: 30,
  } });
  expect(prefs.status()).toBe(200);
  const ai = await api.post('/api/ai/contacts/organize', { headers, data: {
    consent: true, contacts: [{ contact_key: 'demo', display_name: 'Lakshmi Akka' }],
  } });
  expect(ai.status()).toBe(200);
  expect((await ai.json())[0].suggested_relationship).toBe('Sister');
  const webPrefs = await page.request.get('/api/ai/preferences');
  expect((await webPrefs.json()).allowSensitiveData).toBe(true);
  // A separate unauthenticated client cannot read this account's private data.
  expect((await api.get('/api/finance/summary')).status()).toBe(401);
  for (const transaction of (await summary.json()).transactions) {
    expect((await api.delete(`/api/finance/transactions/${transaction.id}`, { headers })).status()).toBe(204);
  }
  await api.dispose();
});
