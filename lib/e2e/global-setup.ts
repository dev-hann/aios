import { execSync } from 'child_process';

const DEVICE = process.env.ADB_DEVICE || '10000000a0010793';
const CDP_PORT = 9222;

export default async function globalSetup() {
  console.log('[E2E Setup] Checking device...');
  try {
    execSync(`adb -s ${DEVICE} shell pidof com.agent.aios`, { encoding: 'utf-8', timeout: 10000 });
  } catch {
    throw new Error(`App not running on ${DEVICE}. Launch first: adb -s ${DEVICE} shell am start -n com.agent.aios/.MainActivity`);
  }

  const pid = execSync(`adb -s ${DEVICE} shell pidof com.agent.aios`, { encoding: 'utf-8' }).trim();
  console.log(`[E2E Setup] App PID: ${pid}`);

  try {
    execSync(`adb -s ${DEVICE} forward --remove tcp:${CDP_PORT}`, { timeout: 3000 });
  } catch {}

  execSync(`adb -s ${DEVICE} forward tcp:${CDP_PORT} localabstract:webview_devtools_remote_${pid}`, {
    timeout: 5000,
  });
  console.log(`[E2E Setup] adb forward tcp:${CDP_PORT} → webview_devtools_remote_${pid}`);
}
