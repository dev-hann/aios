import { test as base, expect, type Page, type BrowserContext, type Browser } from '@playwright/test';

const CDP_PORT = 9222;
const BASE_URL = process.env.E2E_BASE_URL || 'http://192.168.0.7:3000';

type DeviceFixtures = {
  devicePage: Page;
  deviceBrowser: Browser;
  storeAction: (action: string, ...args: unknown[]) => Promise<void>;
};

export const test = base.extend<DeviceFixtures>({
  deviceBrowser: async ({}, use) => {
    const { chromium } = await import('@playwright/test');
    console.log('[E2E Fixture] Connecting to CDP...');
    const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`, { timeout: 10000 });
    console.log('[E2E Fixture] CDP connected');
    await use(browser);
    console.log('[E2E Fixture] Browser fixture done');
  },

  devicePage: async ({ deviceBrowser }, use) => {
    console.log('[E2E Fixture] Getting page...');
    const context = deviceBrowser.contexts()[0];
    console.log('[E2E Fixture] Contexts:', deviceBrowser.contexts().length);
    const pages = context.pages();
    console.log('[E2E Fixture] Pages:', pages.length);
    const page = pages.length > 0 ? pages[0] : await context.newPage();
    const url = page.url();
    console.log('[E2E Fixture] Page URL:', url);
    if (!url.includes('192.168.0.7') && !url.includes('localhost') && !url.includes('127.0.0.1')) {
      console.log('[E2E Fixture] Navigating to', BASE_URL);
      await page.goto(BASE_URL, { timeout: 15000 });
    }
    await use(page);
  },

  storeAction: async ({ devicePage }, use) => {
    const action = async (name: string, ...args: unknown[]) => {
      await devicePage.evaluate(
        ({ actionName, actionArgs }) => {
          const store = (window as any).__aios;
          if (!store) throw new Error('Store bridge not available');
          const state = store.getState();
          if (typeof state[actionName] !== 'function') throw new Error(`Unknown action: ${actionName}`);
          state[actionName](...actionArgs);
        },
        { actionName: name, actionArgs: args },
      );
    };
    await use(action);
  },
});

export function deviceUrl(path: string): string {
  return `${BASE_URL}${path}`;
}

export { expect };
