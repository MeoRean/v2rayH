import { bundleManager } from '@kit.AbilityKit';

// The bundle name must never be hardcoded: forks rename it (upstream
// com.xii.v2rayh vs com.meo.v2rayh) and a stale name silently breaks
// startVpnExtensionAbility and the self-exclusion routing rule.
export function selfBundleName(): string {
  try {
    let info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    return info.name;
  } catch (e) {
    return 'com.meo.v2rayh';
  }
}
