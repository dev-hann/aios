import { test, expect, deviceUrl } from './device.fixture';

test.describe('Permission Management', () => {
  test.beforeEach(async ({ devicePage }) => {
    await devicePage.evaluate((href) => { window.history.pushState({}, '', href); window.dispatchEvent(new PopStateEvent('popstate')); }, deviceUrl('/settings/permissions'));
    await devicePage.waitForTimeout(500);
    await devicePage.waitForSelector('h1', { timeout: 10000 });
  });

  test('shows title and info banner', async ({ devicePage }) => {
    await expect(devicePage.locator('h1')).toHaveText('권한');
    const banner = devicePage.locator('.permission-banner');
    await expect(banner).toBeVisible();
    await expect(banner).toContainText('Gyo Bridge 연동 후 활성화됩니다');
  });

  test('shows 6 permission cards', async ({ devicePage }) => {
    await expect(devicePage.locator('.permission-card')).toHaveCount(6);
  });

  test('shows correct permission labels', async ({ devicePage }) => {
    const labels = devicePage.locator('.permission-label');
    const expected = ['저장소', '알림', '연락처', '전화', 'SMS', '접근성'];
    for (let i = 0; i < expected.length; i++) {
      await expect(labels.nth(i)).toHaveText(expected[i]);
    }
  });

  test('shows 6 pending badges', async ({ devicePage }) => {
    await expect(devicePage.locator('.permission-pending-badge')).toHaveCount(6);
  });
});
