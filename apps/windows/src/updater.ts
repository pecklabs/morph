import { check } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";

/// Checks the update feed (configured in tauri.conf.json → plugins.updater).
/// On launch this runs once; if an update exists it asks the user, then
/// downloads, installs, and relaunches. Mirrors the macOS Sparkle behavior.
export async function checkForUpdates(prompt = true): Promise<void> {
  try {
    const update = await check();
    if (!update) return;

    const accepted =
      !prompt ||
      window.confirm(
        `새 버전 ${update.version} 이(가) 있습니다. 지금 업데이트할까요?`
      );
    if (!accepted) return;

    await update.downloadAndInstall();
    await relaunch();
  } catch (err) {
    // Network/feed errors should never crash the app; just log.
    console.error("Update check failed:", err);
  }
}
