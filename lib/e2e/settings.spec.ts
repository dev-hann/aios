import { test, expect, deviceUrl } from './device.fixture';

test.describe('Settings Screen', () => {
  test.beforeEach(async ({ devicePage }) => {
    await devicePage.evaluate((href) => { window.history.pushState({}, '', href); window.dispatchEvent(new PopStateEvent('popstate')); }, deviceUrl('/settings'));
    await devicePage.waitForTimeout(500);
    await devicePage.waitForSelector('h1', { timeout: 10000 });
  });

  test('shows section with correct title', async ({ devicePage }) => {
    await expect(devicePage.locator('h1')).toHaveText('설정');

    const sectionTitles = devicePage.locator('.section-header-title');
    await expect(sectionTitles).toHaveCount(1);
    await expect(sectionTitles.nth(0)).toHaveText('AI 제공자');
  });

  test('shows connection indicator', async ({ devicePage }) => {
    const indicator = devicePage.locator('.connection-indicator');
    await expect(indicator).toBeVisible();
    const text = await indicator.textContent();
    expect(text!.length).toBeGreaterThan(0);
  });

  test('shows provider info when connected', async ({ devicePage }) => {
    const providerStatus = devicePage.locator('.provider-status');
    if (await providerStatus.isVisible()) {
      await expect(providerStatus.locator('.provider-model')).toBeVisible();
    }
  });

  test('shows nav tiles for inference and permissions', async ({ devicePage }) => {
    const navTiles = devicePage.locator('.nav-tile-btn');
    await expect(navTiles).toHaveCount(2);
    await expect(navTiles.nth(0)).toContainText('추론 설정');
    await expect(navTiles.nth(1)).toContainText('권한 관리');
  });

  test('inference subtitle shows current config values', async ({ devicePage }) => {
    const subtitle = devicePage.locator('.nav-tile-subtitle').first();
    await expect(subtitle).toBeVisible();
    const text = await subtitle.textContent();
    expect(text).toMatch(/온도/);
    expect(text).toMatch(/최대토큰/);
  });

  test('click inference nav tile → /settings/inference', async ({ devicePage }) => {
    await devicePage.locator('.nav-tile-btn', { hasText: '추론 설정' }).click();
    await expect(devicePage).toHaveURL(/\/settings\/inference/);
    await expect(devicePage.locator('h1')).toHaveText('추론 설정');
  });

  test('click permissions nav tile → /settings/permissions', async ({ devicePage }) => {
    await devicePage.locator('.nav-tile-btn', { hasText: '권한 관리' }).click();
    await expect(devicePage).toHaveURL(/\/settings\/permissions/);
    await expect(devicePage.locator('h1')).toHaveText('권한');
  });

  test('dynamic subtitle reflects store inferenceConfig', async ({ devicePage, storeAction }) => {
    await storeAction('setInferenceConfig', { temperature: 0.3, maxTokens: 2048 });
    await devicePage.waitForTimeout(300);

    const subtitle = devicePage.locator('.nav-tile-subtitle').first();
    await expect(subtitle).toContainText('0.30');
    await expect(subtitle).toContainText('2048');

    await storeAction('setInferenceConfig', { temperature: 1.0, maxTokens: 512 });
  });

  test('footer shows version', async ({ devicePage }) => {
    const footerLabel = devicePage.locator('.footer-label');
    await expect(footerLabel).toBeVisible();
    await expect(footerLabel).toContainText('AIOS');
    await expect(footerLabel).toContainText('3.0.0');
  });
});
