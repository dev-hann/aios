import { execSync } from 'child_process';

const DEVICE = process.env.ADB_DEVICE || '10000000a0010793';
const CDP_PORT = 9222;

export default async function globalTeardown() {
  try {
    execSync(`adb -s ${DEVICE} forward --remove tcp:${CDP_PORT}`, { timeout: 3000 });
    console.log('[E2E Teardown] adb forward removed');
  } catch {
    console.log('[E2E Teardown] adb forward cleanup skipped');
  }
}
