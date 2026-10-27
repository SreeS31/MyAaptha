import { test, expect } from '@playwright/test';

test('production CSP rejects injected scripts and generates a fresh nonce', async ({ page, request }) => {
  test.skip(!process.env.PLAYWRIGHT_PRODUCTION, 'Requires the actual production build');
  const response = await page.goto('/');
  const policy = response!.headers()['content-security-policy'];
  expect(policy).toContain("'strict-dynamic'");
  expect(policy).not.toContain("'unsafe-eval'");
  expect(policy).toContain("frame-ancestors 'none'");
  const nonce = policy.match(/'nonce-([^']+)'/)?.[1];
  expect(nonce).toBeTruthy();
  const next = await request.get('/');
  expect(next.headers()['content-security-policy'].match(/'nonce-([^']+)'/)?.[1]).not.toBe(nonce);
  // Inject untrusted parser-inserted markup. Scripts created by trusted JavaScript
  // inherit strict-dynamic trust, so page.evaluate/createElement is not an XSS fixture.
  await page.route('http://127.0.0.1:3100/', async route => {
    const original = await route.fetch();
    const body = (await original.text()).replace('</head>', '<script>window.__injectedScriptRan = true</script></head>');
    await route.fulfill({ response: original, body });
  });
  await page.reload();
  expect(await page.evaluate(() => (window as Window & { __injectedScriptRan?: boolean }).__injectedScriptRan)).toBeUndefined();
});
