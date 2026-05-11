import { test, expect, deviceUrl } from './device.fixture';

test.describe('Inference Settings', () => {
  test.beforeEach(async ({ devicePage }) => {
    await devicePage.evaluate((href) => { window.history.pushState({}, '', href); window.dispatchEvent(new PopStateEvent('popstate')); }, deviceUrl('/settings/inference'));
    await devicePage.waitForTimeout(500);
    await devicePage.waitForSelector('h1', { timeout: 10000 });
  });

  test('shows 3 sections with correct titles', async ({ devicePage }) => {
    await expect(devicePage.locator('h1')).toHaveText('추론 설정');
    const sections = devicePage.locator('.section-header-title');
    await expect(sections).toHaveCount(3);
    await expect(sections.nth(0)).toHaveText('샘플링');
    await expect(sections.nth(1)).toHaveText('출력');
    await expect(sections.nth(2)).toHaveText('에이전트');
  });

  test('shows 4 sliders with correct labels', async ({ devicePage }) => {
    const sliders = devicePage.locator('.slider-input');
    await expect(sliders).toHaveCount(4);
    const labels = devicePage.locator('.slider-tile-label');
    await expect(labels.nth(0)).toHaveText('Temperature');
    await expect(labels.nth(1)).toHaveText('Top-P');
    await expect(labels.nth(2)).toHaveText('최대 토큰');
    await expect(labels.nth(3)).toHaveText('최대 반복');
  });

  test('shows reset defaults button', async ({ devicePage }) => {
    await expect(devicePage.locator('.outlined-btn', { hasText: '기본값 복원' })).toBeVisible();
  });

  test('store update reflects in slider value', async ({ devicePage, storeAction }) => {
    await storeAction('setInferenceConfig', { temperature: 0.3 });
    await devicePage.waitForTimeout(300);
    const sliderValue = await devicePage.locator('.slider-input').nth(0).inputValue();
    expect(Number(sliderValue)).toBeCloseTo(0.3, 1);
    const display = devicePage.locator('.slider-value-btn').nth(0);
    await expect(display).toContainText('0.30');
    await storeAction('setInferenceConfig', { temperature: 1.0 });
  });

  test('reset button restores all defaults', async ({ devicePage, storeAction }) => {
    await storeAction('setInferenceConfig', { temperature: 0.1, topP: 0.5, maxTokens: 128, maxIterations: 3 });
    await devicePage.waitForTimeout(300);

    await devicePage.locator('.outlined-btn', { hasText: '기본값 복원' }).click();
    await devicePage.waitForTimeout(500);

    const temp = await devicePage.locator('.slider-input').nth(0).inputValue();
    expect(Number(temp)).toBeCloseTo(1.0, 1);
    const topP = await devicePage.locator('.slider-input').nth(1).inputValue();
    expect(Number(topP)).toBeCloseTo(0.95, 1);
    const maxTokens = await devicePage.locator('.slider-input').nth(2).inputValue();
    expect(Number(maxTokens)).toBe(512);
    const maxIter = await devicePage.locator('.slider-input').nth(3).inputValue();
    expect(Number(maxIter)).toBe(8);
  });

  test('value click opens dialog, confirm applies new value', async ({ devicePage }) => {
    await devicePage.locator('.slider-value-btn').nth(2).click();
    await devicePage.waitForTimeout(300);
    await expect(devicePage.locator('.dialog-overlay')).toBeVisible();

    await devicePage.fill('.dialog-overlay .settings-input', '2048');
    await devicePage.waitForTimeout(100);
    await devicePage.locator('.dialog-btn-confirm').click();
    await devicePage.waitForTimeout(500);

    await expect(devicePage.locator('.dialog-overlay')).not.toBeVisible();
    const sliderValue = await devicePage.locator('.slider-input').nth(2).inputValue();
    expect(Number(sliderValue)).toBe(2048);
  });

  test('dialog cancel does not change value', async ({ devicePage }) => {
    const beforeValue = await devicePage.locator('.slider-input').nth(2).inputValue();

    await devicePage.locator('.slider-value-btn').nth(2).click();
    await devicePage.waitForTimeout(300);
    await devicePage.fill('.dialog-overlay .settings-input', '9999');
    await devicePage.locator('.dialog-btn-cancel').click();
    await devicePage.waitForTimeout(300);

    const afterValue = await devicePage.locator('.slider-input').nth(2).inputValue();
    expect(afterValue).toBe(beforeValue);
  });
});
