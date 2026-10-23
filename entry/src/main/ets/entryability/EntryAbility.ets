import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import { window, display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { statusBarManager } from '@kit.DeskTopExtensionKit';
import { vpnExtension } from '@kit.NetworkKit';
import { VPN_WANT } from '../common/AppState';

const DOMAIN = 0x0000;
const TRAY_MENU_SHOW: string = 'show';
const TRAY_MENU_EXIT: string = 'exit';

function syncAvoidArea(win: window.Window): void {
  try {
    let systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    AppStorage.setOrCreate('topRectHeight', systemArea.topRect.height);
    let navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    AppStorage.setOrCreate('bottomRectHeight', navArea.bottomRect.height);
  } catch (err) {
    hilog.error(DOMAIN, 'testTag', 'Failed to get avoid area. Cause: %{public}s', JSON.stringify(err));
  }
}

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined;
  private trayReady: boolean = false;
  // Window size events arrive per animation frame during restore/resize on
  // tablets; committing each one makes the adaptive layout thrash between the
  // rail and tab roots. Only commit after the size has settled.
  private pendingWinWidthVp: number = -1;
  private winWidthCommitTimer: number = -1;
  private lastCommittedWinWidthVp: number = -1;

  private pxToVp(px: number): number {
    try {
      let density = display.getDefaultDisplaySync().densityPixels;
      return density > 0 ? px / density : px;
    } catch (err) {
      return px;
    }
  }

  private commitWinWidthVp(vp: number): void {
    if (vp < 100 || !isFinite(vp)) {
      // Transient rects while minimizing/restoring — never drive layout.
      return;
    }
    if (Math.abs(vp - this.lastCommittedWinWidthVp) < 1) {
      return;
    }
    this.lastCommittedWinWidthVp = vp;
    AppStorage.setOrCreate('winWidthVp', vp);
    hilog.info(DOMAIN, 'testTag', 'winWidthVp commit: %{public}s', vp.toFixed(1));
  }

  private onWindowWidthEvent(px: number): void {
    this.pendingWinWidthVp = this.pxToVp(px);
    if (this.winWidthCommitTimer >= 0) {
      clearTimeout(this.winWidthCommitTimer);
    }
    this.winWidthCommitTimer = setTimeout(() => {
      this.winWidthCommitTimer = -1;
      if (this.pendingWinWidthVp > 0) {
        this.commitWinWidthVp(this.pendingWinWidthVp);
      }
    }, 120);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('systemDarkFlag',
      this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'onConfigurationUpdate');
    AppStorage.setOrCreate('systemDarkFlag',
      newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    // True termination (tray menu exit, dock right-click close, in-app exit):
    // tear the tunnel down so no orphaned VPN keeps running without a
    // controlling UI, and drop the status-bar (tray) icon.
    vpnExtension.stopVpnExtensionAbility(VPN_WANT).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, 'testTag', 'stopVpnExtension on destroy failed: %{public}s', JSON.stringify(err));
    });
    if (this.trayReady) {
      try {
        statusBarManager.removeFromStatusBar(this.context);
      } catch (err) {
        // 1010710004: cannot remove while no window is in the foreground —
        // the icon is cleaned up anyway once the process exits.
        hilog.warn(DOMAIN, 'testTag', 'removeFromStatusBar failed: %{public}s', JSON.stringify(err));
      }
    }
  }

  // Runs on 2-in-1 (PC) and tablet only: the X button asks permission to close.
  // Intercept only on PC, where the tray icon keeps the app reachable — on a
  // tablet there is no tray, so a blocked close would strand the app.
  onPrepareToTerminate(): boolean {
    if (deviceInfo.deviceType !== '2in1') {
      return false;
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'close intercepted, hiding to tray');
    if (this.trayReady) {
      this.context.hideAbility().catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'hideAbility failed: %{public}s', JSON.stringify(err));
        this.minimizeWindow();
      });
    } else {
      this.minimizeWindow();
    }
    return true;
  }

  private minimizeWindow(): void {
    if (this.mainWindow !== undefined) {
      this.mainWindow.minimize().catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'minimize failed: %{public}s', JSON.stringify(err));
      });
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Relaunching from the dock/launcher while hidden in the tray brings the
    // window back. On tablets the tray feature is disabled entirely — calling
    // showAbility() there fights the launcher's scene transition and loops
    // the window scale animation.
    if (this.trayReady) {
      this.context.showAbility().catch((err: BusinessError) => {
        hilog.warn(DOMAIN, 'testTag', 'showAbility failed: %{public}s', JSON.stringify(err));
      });
    }
  }

  private async loadTrayIcon(): Promise<image.PixelMap | undefined> {
    try {
      let data = this.context.resourceManager.getMediaContentSync($r('app.media.icon'));
      let buf = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer;
      let src = image.createImageSource(buf);
      return await src.createPixelMap({ desiredSize: { width: 48, height: 48 } });
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'loadTrayIcon failed: %{public}s', JSON.stringify(err));
      return undefined;
    }
  }

  // Status-bar (tray) icon: 2-in-1 only. The API technically succeeds on
  // pads too, but hideAbility/showAbility on a tablet conflicts with the
  // launcher's scene transition (window scale animation loop), so the whole
  // tray path stays disabled there.
  private async setupTray(): Promise<void> {
    if (deviceInfo.deviceType !== '2in1') {
      return;
    }
    let white = await this.loadTrayIcon();
    let black = await this.loadTrayIcon();
    if (white === undefined || black === undefined) {
      return;
    }
    let showItem: statusBarManager.StatusBarMenuItem = {
      title: '显示主窗口',
      menuCode: TRAY_MENU_SHOW,
      menuAction: { abilityName: 'EntryAbility', moduleName: 'entry', notifyOnly: true }
    };
    let exitItem: statusBarManager.StatusBarMenuItem = {
      title: '退出 v2rayH',
      menuCode: TRAY_MENU_EXIT,
      menuAction: { abilityName: 'EntryAbility', moduleName: 'entry', notifyOnly: true }
    };
    let item: statusBarManager.StatusBarItem = {
      icons: { white: white, black: black },
      quickOperation: { title: 'v2rayH', height: 1, abilityName: '', moduleName: 'entry' },
      statusBarGroupMenu: [[showItem], [exitItem]],
      hoverTips: 'v2rayH 正在后台运行'
    };
    try {
      statusBarManager.on('statusBarIconClick', (event: emitter.EventData) => {
        this.context.showAbility().catch((err: BusinessError) => {
          hilog.warn(DOMAIN, 'testTag', 'showAbility from tray click failed: %{public}s', JSON.stringify(err));
        });
      });
      statusBarManager.on('rightMenuClick', (event: emitter.EventData) => {
        let code = '';
        let payload = event.data as Record<string, Object>;
        if (payload['menuCode'] !== undefined) {
          code = payload['menuCode'].toString();
        }
        if (code === TRAY_MENU_SHOW) {
          this.context.showAbility().catch(() => {
          });
        } else if (code === TRAY_MENU_EXIT) {
          this.quitFromTray();
        }
      });
      statusBarManager.addToStatusBar(this.context, item, (err) => {
        if (err) {
          hilog.warn(DOMAIN, 'testTag', 'addToStatusBar failed: %{public}s', JSON.stringify(err));
        } else {
          this.trayReady = true;
          hilog.info(DOMAIN, 'testTag', '%{public}s', 'tray icon ready');
        }
      });
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'setupTray failed (device without status bar): %{public}s', JSON.stringify(err));
    }
  }

  private quitFromTray(): void {
    vpnExtension.stopVpnExtensionAbility(VPN_WANT).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, 'testTag', 'stopVpnExtension from tray failed: %{public}s', JSON.stringify(err));
    });
    if (this.trayReady) {
      try {
        statusBarManager.removeFromStatusBar(this.context);
      } catch (err) {
        hilog.warn(DOMAIN, 'testTag', 'removeFromStatusBar on quit failed: %{public}s', JSON.stringify(err));
      }
    }
    this.context.terminateSelf().catch((err: BusinessError) => {
      hilog.error(DOMAIN, 'testTag', 'terminateSelf failed: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    try {
      let mainWindow = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        syncAvoidArea(mainWindow);
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full screen. Cause: %{public}s', JSON.stringify(err));
      });
      syncAvoidArea(mainWindow);
      this.commitWinWidthVp(this.pxToVp(mainWindow.getWindowProperties().windowRect.width));
      mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topRectHeight', data.area.topRect.height);
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomRectHeight', data.area.bottomRect.height);
        }
      });
      // Free-window (PC) resizing drives the adaptive layout breakpoint.
      mainWindow.on('windowSizeChange', (size: window.Size) => {
        this.onWindowWidthEvent(size.width);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to prepare immersive window. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.setupTray();
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    this.mainWindow = undefined;
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background; the VPN extension keeps the tunnel alive,
    // so the UI process is allowed to be frozen by the system to save power.
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
