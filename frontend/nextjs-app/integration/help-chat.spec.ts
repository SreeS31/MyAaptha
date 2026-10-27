import { expect, test } from './fixtures';
import { randomUUID } from 'node:crypto';

test('application help answers with sources and clears history', async ({ page, request }) => {
  const username=`help-${randomUUID().slice(0,12)}`, password=`Help-${randomUUID()}`;
  const created=await request.post('http://127.0.0.1:8080/api/users',{data:{username,password,phoneNumber:`+1998${Date.now().toString().slice(-10)}`}});
  expect(created.status()).toBe(200);
  await page.goto('/auth');
  await page.getByLabel('Username or mobile number',{exact:true}).fill(username);
  await page.getByLabel('Password',{exact:true}).fill(password);
  await page.getByRole('button',{name:'Continue',exact:true}).click();
  await expect(page).toHaveURL(/dashboard/);
  await page.goto('/help');
  await expect(page.getByRole('heading',{name:'Ask MyAaptha'})).toBeVisible();
  await page.getByRole('button',{name:'Is MyAaptha free?',exact:true}).click();
  await page.getByRole('button',{name:'Ask',exact:true}).click();
  await expect(page.getByRole('log')).toContainText('free for all users');
  await expect(page.getByRole('log').getByText('Sources',{exact:true})).toBeVisible();
  await page.getByRole('button',{name:'Clear chat'}).click();
  await expect(page.getByRole('log')).not.toContainText('free for all users');
  await page.getByLabel('Your question',{exact:true}).fill('How do I send messages horizontally and vertically to all relations?');
  await page.getByRole('button',{name:'Ask',exact:true}).click();
  await expect(page.getByRole('log')).toContainText('not every relation');
  await expect(page.getByRole('log')).toContainText('Preview audience');
  await expect(page.getByRole('checkbox',{name:'Use OpenAI answers'})).not.toBeChecked();
  await page.screenshot({path:`../../.tools/preview/help-${test.info().project.name}.png`,fullPage:true});
});
