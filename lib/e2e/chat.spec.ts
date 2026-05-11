import { test, expect, deviceUrl } from './device.fixture';

test.describe('Chat Screen', () => {
  test.beforeEach(async ({ devicePage }) => {
    await devicePage.evaluate((href) => { window.history.pushState({}, '', href); window.dispatchEvent(new PopStateEvent('popstate')); }, deviceUrl('/'));
    await devicePage.waitForTimeout(500);
    await devicePage.waitForSelector('.chat-header-title', { timeout: 10000 });
  });

  test('shows header and input textarea', async ({ devicePage }) => {
    await expect(devicePage.locator('.chat-header-title')).toBeVisible();
    await expect(devicePage.locator('.input-bar textarea')).toBeVisible();
    await expect(devicePage.locator('.send-btn')).toBeVisible();
  });

  test('sends message and receives assistant response', async ({ devicePage }) => {
    await devicePage.fill('.input-bar textarea', '안녕하세요');
    await devicePage.click('.send-btn');

    await expect(devicePage.locator('.message-bubble.user').last()).toBeVisible({ timeout: 5000 });
    await expect(devicePage.locator('.message-bubble.assistant').last()).toBeVisible({ timeout: 90000 });
  });

  test('executes calculator tool and returns answer', async ({ devicePage }) => {
    await devicePage.fill('.input-bar textarea', '15 더하기 27은?');
    await devicePage.click('.send-btn');

    await expect(devicePage.locator('.system-annotation').first()).toBeVisible({ timeout: 30000 });
    await expect(devicePage.locator('.message-bubble.assistant').last()).toBeVisible({ timeout: 90000 });
  });

  test('executes notepad tool', async ({ devicePage }) => {
    await devicePage.fill('.input-bar textarea', '테스트라고 메모해줘');
    await devicePage.click('.send-btn');

    await expect(devicePage.locator('.system-annotation').first()).toBeVisible({ timeout: 30000 });
    await expect(devicePage.locator('.message-bubble.assistant').last()).toBeVisible({ timeout: 90000 });
  });
});
