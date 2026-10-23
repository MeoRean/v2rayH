import { uiMaterial } from '@kit.ArkUI';
import { AppTheme } from '../common/AppTheme';
import { AppState } from '../common/AppState';
import { HomeTab } from '../view/HomeTab';
import { ConfigTab } from '../view/ConfigTab';
import { SettingsTab } from '../view/SettingsTab';

// HarmonyOS lg breakpoint: >= 600vp switches to the side-rail (PC) layout.
const WIDE_BREAKPOINT_VP: number = 600;
const CONTENT_MAX_WIDTH: number = 840;

@Entry
@Component
struct Index {
  @State app: AppState = new AppState();
  @State currentIndex: number = 0;
  @State configReset: number = 0;
  @State settingsReset: number = 0;
  @StorageProp('bottomRectHeight') bottomRectPx: number = 0;
  @StorageProp('winWidthVp') winWidthVp: number = 360;
  @StorageProp('systemDarkFlag') @Watch('onSystemDark') systemDarkFlag: boolean = false;
  @StorageProp('openEditorTick') @Watch('onOpenEditor') openEditorTick: number = 0;
  @StorageLink('themeRev') themeRev: number = 0;
  private tabsController: TabsController = new TabsController();

  private isWide(): boolean {
    return this.winWidthVp >= WIDE_BREAKPOINT_VP;
  }

  onSystemDark(): void {
    this.app.setSystemDark(this.systemDarkFlag);
  }

  onOpenEditor(): void {
    if (this.app.editingIdx >= 0) {
      this.currentIndex = 1;
    }
  }

  onTabBarTap(index: number): void {
    if (index !== this.currentIndex) {
      return;
    }
    if (index === 1) {
      this.configReset = this.configReset + 1;
    } else if (index === 2) {
      this.settingsReset = this.settingsReset + 1;
    }
  }

  aboutToAppear(): void {
    let ctx = this.getUIContext().getHostContext();
    if (ctx !== undefined) {
      this.app.init(ctx);
    }
  }

  @Builder
  tabItem(label: string, icon: Resource, idx: number) {
    Column({ space: 2 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentIndex === idx ? AppTheme.PRIMARY : AppTheme.TEXT_SUB])
      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === idx ? AppTheme.PRIMARY : AppTheme.TEXT_SUB)
        .fontWeight(this.currentIndex === idx ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  railItem(label: string, icon: Resource, idx: number) {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(19)
        .fontColor([this.currentIndex === idx ? AppTheme.PRIMARY : AppTheme.TEXT_SUB])
      Text(label)
        .fontSize(14)
        .fontWeight(this.currentIndex === idx ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentIndex === idx ? AppTheme.PRIMARY : AppTheme.TEXT_SUB)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .alignItems(VerticalAlign.Center)
    .borderRadius(12)
    .backgroundColor(this.currentIndex === idx ? AppTheme.PRIMARY_SOFT : Color.Transparent)
    .margin({ bottom: 6 })
    .onClick(() => {
      this.onTabBarTap(idx);
      this.currentIndex = idx;
    })
  }

  @Builder
  sideRail() {
    Column() {
      Text('v2rayH')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT)
        .width('100%')
        .margin({ bottom: 18 })

      this.railItem('主页', $r('sys.symbol.house'), 0)
      this.railItem('配置', $r('sys.symbol.slider_horizontal_2'), 1)
      this.railItem('设置', $r('sys.symbol.gearshape'), 2)

      Blank()

      Row({ space: 6 }) {
        Circle()
          .width(8)
          .height(8)
          .fill(this.app.connected ? AppTheme.OK : AppTheme.TEXT_WEAK)
        Text(this.app.connected ? 'VPN 已连接' : 'VPN 未连接')
          .fontSize(11)
          .fontColor(this.app.connected ? AppTheme.OK : AppTheme.TEXT_SUB)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.app.connected ? AppTheme.OK_SOFT : AppTheme.CHIP_BG)
      .borderRadius(100)
      .justifyContent(FlexAlign.Center)
    }
    .width(200)
    .height('100%')
    .padding({ left: 12, right: 12, top: 20, bottom: 16 })
    .backgroundColor(AppTheme.CARD_BG)
    .alignItems(HorizontalAlign.Start)
    .border({ width: { right: 1 }, color: AppTheme.DIVIDER })
  }

  @Builder
  railContent() {
    Column() {
      if (this.currentIndex === 0) {
        HomeTab({ app: this.app })
      } else if (this.currentIndex === 1) {
        ConfigTab({ app: this.app, resetTick: this.configReset })
      } else {
        SettingsTab({ app: this.app, resetTick: this.settingsReset })
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: CONTENT_MAX_WIDTH })
  }

  @Builder
  wideLayout() {
    Row() {
      this.sideRail()

      Row() {
        this.railContent()
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.PAGE_BG)
  }

  @Builder
  compactLayout() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        HomeTab({ app: this.app })
      }
      .tabBar(this.tabItem('主页', $r('sys.symbol.house'), 0))

      TabContent() {
        ConfigTab({ app: this.app, resetTick: this.configReset })
      }
      .tabBar(this.tabItem('配置', $r('sys.symbol.slider_horizontal_2'), 1))

      TabContent() {
        SettingsTab({ app: this.app, resetTick: this.settingsReset })
      }
      .tabBar(this.tabItem('设置', $r('sys.symbol.gearshape'), 2))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.PAGE_BG)
    .barMode(BarMode.Fixed)
    .barHeight(56)
    .barOverlap(true)
    .scrollable(false)
    .animationDuration(0)
    .barFloatingStyle({
      barBottomMargin: px2vp(this.bottomRectPx) + 8,
      systemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        interactive: true,
        applyShadow: true
      })
    })
    .onTabBarClick((index: number) => {
      this.onTabBarTap(index);
    })
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }

  build() {
    if (this.isWide()) {
      this.wideLayout()
    } else {
      this.compactLayout()
    }
  }
}
