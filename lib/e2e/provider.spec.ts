import { test, expect, deviceUrl } from './device.fixture';

test.describe('Provider Settings', () => {
  test.beforeEach(async ({ devicePage }) => {
    await devicePage.evaluate((href) => { window.history.pushState({}, '', href); window.dispatchEvent(new PopStateEvent('popstate')); }, deviceUrl('/settings/provider'));
    await devicePage.waitForTimeout(500);
    await devicePage.waitForSelector('h1', { timeout: 10000 });
  });

  test('shows title and 5 provider types', async ({ devicePage }) => {
    await expect(devicePage.locator('h1')).toHaveText('AI 제공자 설정');
    await expect(devicePage.locator('.radio-item')).toHaveCount(5);
  });

  test('shows all provider labels', async ({ devicePage }) => {
    const labels = devicePage.locator('.radio-item span');
    await expect(labels.nth(0)).toHaveText('Z.AI');
    await expect(labels.nth(1)).toHaveText('Z.AI (Coding)');
    await expect(labels.nth(2)).toHaveText('OpenAI');
    await expect(labels.nth(3)).toHaveText('Anthropic');
    await expect(labels.nth(4)).toHaveText('Custom');
  });

  test('click switches provider type', async ({ devicePage }) => {
    await devicePage.locator('.radio-item').nth(3).click();
    await devicePage.waitForTimeout(300);

    const activeLabel = await devicePage.evaluate(() => {
      const items = document.querySelectorAll('.radio-item');
      for (const item of items) {
        const dot = item.querySelector('.radio-dot');
        if (dot && dot.classList.contains('active')) {
          return item.querySelector('span')?.textContent || '';
        }
      }
      return '';
    });
    expect(activeLabel).toBe('Anthropic');
  });

  test('base URL input only visible for custom provider', async ({ devicePage }) => {
    await devicePage.locator('.radio-item').nth(1).click();
    await devicePage.waitForTimeout(200);
    await expect(devicePage.locator('input[placeholder*="example.com"]')).not.toBeVisible();

    await devicePage.locator('.radio-item').nth(4).click();
    await devicePage.waitForTimeout(200);
    await expect(devicePage.locator('input[placeholder*="example.com"]')).toBeVisible();
  });

  test('shows API key input', async ({ devicePage }) => {
    await expect(devicePage.locator('input[type="password"]')).toBeVisible();
  });

  test('shows connect/save button', async ({ devicePage }) => {
    const saveBtn = devicePage.locator('.sticky-save-bar .elevated-btn');
    await expect(saveBtn).toBeVisible();
    const text = await saveBtn.textContent();
    expect(text).toBeTruthy();
  });
});
