import { webview } from '@kit.ArkWeb';
import { promptAction, window, display, prompt } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import util from '@ohos.util';
import {
  saveHomeUrl,
  getHomeUrl,
  saveUserAgent,
  getUserAgent,
  saveLSRefresh,
  getLSRefresh,
  saveIshidebar,
  getIshidebar,
  getIshidestatus,
  saveIshidestatus,
  getUserAgentType,
  saveUserAgentType,
  getIsfull,
  saveIsfull,
  getSlidenum,
  saveSlidenum,
  getIpResolveMode,
  saveIpResolveMode,
  getThemeMode,
  saveThemeMode
} from '../model/StorageService';
import { DownloadConfirmDialog } from '../component/DownloadConfirmDialog'
import { IAbstractDownloadHandler } from '../delegate/IWebDownloadFile'
import { WebDownloadFileHelper } from '../delegate/WebDownloadFileImpl'
import { EmitterUtil } from '../utiles/EmitterUtil'
import { http, connection } from '@kit.NetworkKit';
import { fileIo as fs, ReadOptions, WriteOptions } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { buffer } from '@kit.ArkTS';

enum ScreenOrientation {
  PORTRAIT = display.Orientation.PORTRAIT,
  LANDSCAPE = display.Orientation.LANDSCAPE,
  REVERSE_PORTRAIT = display.Orientation.PORTRAIT_INVERTED,
  REVERSE_LANDSCAPE = display.Orientation.LANDSCAPE_INVERTED
}

let context_index = getContext(this) as common.UIAbilityContext;
let resourceDir = context_index.resourceDir

const TAG = 'web-savePic';
const context = getContext(this) as common.UIAbilityContext;
/**
 * 复制本地文件到应用沙箱,并返回保存后的沙箱中的文件路径
 */
function copyLocalPicFilesDir(rawfilePath: string, newFileName: string): string {
  let srcFileDescriptor = context.resourceManager.getRawFdSync(rawfilePath); //这里填rawfile文件夹下的文件名（包括后缀）
  let dstPath = context.filesDir + "/" + newFileName;
  let dest: fs.File = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
  let bufsize = 4096
  let buf = new ArrayBuffer(bufsize)
  let off = 0, len = 0, readedLen = 0
  while (len = fs.readSync(srcFileDescriptor.fd, buf, { offset: srcFileDescriptor.offset + off, length: bufsize })) {
    readedLen += len
    fs.writeSync(dest.fd, buf, { offset: off, length: len })
    off = off + len
    if ((srcFileDescriptor.length - readedLen) < bufsize) {
      bufsize = srcFileDescriptor.length - readedLen
    }
  }
  fs.close(dest.fd)

  return dest.path;
}

async function copyUrlPicToFilesDir(picUrl: string, newFileName: string): Promise<string> {
  let uri = '';
  //读取网络图片并保存到沙箱路径下
  let httpRequest = http.createHttp();
  let data: http.HttpResponse = await (httpRequest.request(picUrl) as Promise<http.HttpResponse>);
  if (data?.responseCode == http.ResponseCode.OK) {
    let dstPath = context.filesDir + "/" + newFileName;
    let dest: fs.File = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
    let writeLen: number = fs.writeSync(dest.fd, data.result as ArrayBuffer);
    uri = dest.path;
  }
  return uri;
}



@Entry
@Component
struct Index {
  private isRefreshing: boolean = false;
  private contextmenu_result: WebContextMenuResult | undefined = undefined;
  @State controller: webview.WebviewController = new webview.WebviewController();
  @State webDownloadFile: IAbstractDownloadHandler = new WebDownloadFileHelper()
  downloadWebLoading: CustomDialogController = new CustomDialogController({
    //Web页面加载的弹窗控制器
    builder: DownloadConfirmDialog(),
    customStyle: true,
    alignment: DialogAlignment.Bottom,
    autoCancel: false,
    isModal: false
  })

  saveButtonOptions: SaveButtonOptions = {
    icon: SaveIconStyle.FULL_FILLED,
    text: SaveDescription.SAVE_IMAGE,
    buttonType: ButtonType.Capsule
  } // 设置安全控件按钮属性
  private result: WebContextMenuResult | undefined = undefined;
  @State linkUrl: string = '';
  @State imgUrl: string = '';
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State showMenu: boolean = false;
  @State pic_w:number|undefined = 0;
  @State pic_h:number|undefined = 0;
  @State pic_dl_show:Visibility = Visibility.Hidden;

  // 主题与IP解析偏好状态
  @State themeMode: string = 'system'; // 'system' | 'light' | 'dark'
  @State isDarkActive: boolean = true;  // 当前是否呈现暗色模式（AMOLED黑）
  @State ipResolveMode: string = 'auto'; // 'auto' | 'v4' | 'v6'
  private originalTargetHost: string = ''; // 原始主机名

  @Builder
  //构建自定义菜单及触发功能接口
  MenuBuilder() {
    Column() {
      Row()
        .height(10)
      Row(){
        Text('是否保存至图库')
          .fontSize(18)
          .fontColor(this.isDarkActive ? '#FFFFFF' : '#1A1A1A')
      }
      Row()
        .height(10)
      Row(){
        Image(this.imgUrl)
          .onComplete((event) => {
            this.pic_w = event?.width;
            this.pic_h = event?.height;
            this.pic_dl_show = Visibility.Visible;
            })
          .onError(()=>{
            this.showMenu=false;
            this.pic_dl_show = Visibility.Hidden;
          })
          .width('80%')
          .backgroundColor(this.isDarkActive ? '#121212' : Color.White)
          .borderRadius(15)
          .objectFit(ImageFit.ScaleDown)
          .constraintSize({maxHeight: '50%',maxWidth:'80%'})
      }

      Row() {
        Button("取消").onClick((event: ClickEvent) => {
          this.showMenu = false;
          this.pic_dl_show = Visibility.Hidden;
        })
          .height(32)
          .backgroundColor(this.isDarkActive ? '#2C2C2E' : '#E5E5EA')
          .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
        Text()
          .width(10)
        SaveButton(this.saveButtonOptions) // 创建安全控件按钮。
          .onClick(async (event, result: SaveButtonOnClickResult) => {
            if (result == SaveButtonOnClickResult.SUCCESS) {
              try {
                let context = getContext();
                let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
                let uri = '';
                //复制图片到应用沙箱目录下，并获取uri
                if (this.imgUrl?.includes('rawfile')) {
                  let rawFileName: string = this.imgUrl.substring(this.imgUrl.lastIndexOf('/') + 1);
                  console.info(TAG, `rawfileName ${rawFileName}`)
                  uri = copyLocalPicFilesDir(rawFileName, 'copyFile.png');
                } else if (this.imgUrl?.includes('http') || this.imgUrl?.includes('https')) { // 针对http|https 协议的网络图片
                  uri = await copyUrlPicToFilesDir(this.imgUrl, `onlinePic_${systemDateTime.getTime()}.png`)
                }
                let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, uri);
                await phAccessHelper.applyChanges(assetChangeRequest);
                console.info('createAsset successfully, uri: ' + assetChangeRequest.getAsset().uri);
                this.showMenu = false;
              } catch (err) {
                console.error(`create asset failed with error: ${err.code}, ${err.message}`);
              }
            } else {
              console.error('SaveButtonOnClickResult create asset failed');
            }
          })
      }
      .height(32)
      .margin({ top: 20, bottom: 20 })
      .justifyContent(FlexAlign.Center)
    }
    .width('80%')
    .backgroundColor(this.isDarkActive ? '#1C1C1E' : Color.White)
    .borderRadius(10)
    .visibility(this.pic_dl_show)
  }

  async saveBase64Image(base64Str:string) {
    try {
      const context = getContext(this);
      let helper = photoAccessHelper.getPhotoAccessHelper(context);
      let uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png')
      let imageStr = base64Str.split(',')[1];
      let file = fs.openSync(uri, fs.OpenMode.READ_WRITE);
      const decodeBuffer = buffer.from(imageStr, 'base64').buffer;
      fs.writeSync(file.fd, decodeBuffer);
      fs.closeSync(file);
    } catch (e) {
      console.error(e);
    }
  }

  @State refreshing: boolean = false
  @State list: number[] = Array(20).fill(Date.now())
  @State is_home: boolean = false;
  @State showDialog: boolean = false;
  @State home_url: string = ''
  @State saved_home_url: string = resourceDir + "/nasnav.html";
  @State c_pg_ua: string = '';
  @State c_ua_temp: string = '';
  @State ua_type: string = 'Mobile';
  @State userAgent: string = '';
  @State ua_device: string = '';
  @State showTopRow: boolean = false;
  @State showRefreshRow: boolean = true;
  @State showButtonRow: boolean = true;
  @State refreshTimerId: number | null = null;
  @State showSetting: boolean = false;
  @State isLandscape: boolean = false;
  @State isLSRefresh: string = 'false'; //是否横屏不能刷新
  @State isdrag: number = 1
  @State isHidebar: string = 'false';
  @State isHidestatus: string = 'false';
  @State isFull: string = 'true';
  @State slide_num: number = 0.3;

  async setSystemFull(is_full: string, is_hidestatus: string, is_hidebar: string) {
    let windowClass = await window.getLastWindow(context_index)
    if (is_full == 'true') {
      if (is_hidestatus == 'true') {
        if (is_hidebar == 'true') {
          await windowClass.setWindowLayoutFullScreen(true)
          await windowClass.setSpecificSystemBarEnabled('status', true, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', true, true);
        } else {
          await windowClass.setWindowLayoutFullScreen(true)
          await windowClass.setSpecificSystemBarEnabled('status', true, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', false, true);
        }
      } else {
        if (is_hidebar == 'true') {
          await windowClass.setWindowLayoutFullScreen(true)
          await windowClass.setSpecificSystemBarEnabled('status', false, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', true, true);
        } else {
          await windowClass.setWindowLayoutFullScreen(true)
          await windowClass.setSpecificSystemBarEnabled('status', false, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', false, true);
        }
      }
    } else {
      if (is_hidestatus == 'true') {
        if (is_hidebar == 'true') {
          await windowClass.setWindowLayoutFullScreen(false)
          await windowClass.setSpecificSystemBarEnabled('status', true, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', true, true);
        } else {
          await windowClass.setWindowLayoutFullScreen(false)
          await windowClass.setSpecificSystemBarEnabled('status', true, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', false, true);
        }
      } else {
        if (is_hidebar == 'true') {
          await windowClass.setWindowLayoutFullScreen(true)
          await windowClass.setSpecificSystemBarEnabled('status', false, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', true, true);
        } else {
          await windowClass.setWindowLayoutFullScreen(false)
          await windowClass.setSpecificSystemBarEnabled('status', false, true);
          await windowClass.setSpecificSystemBarEnabled('navigationIndicator', false, true);
        }
      }
    }
  }

  // 应用主题模式
  applyThemeMode(theme: string) {
    this.themeMode = theme;
    saveThemeMode(theme);
    const appCtx = (globalThis.abilityContext as common.UIAbilityContext)?.getApplicationContext() ||
                   context_index.getApplicationContext();
    if (theme === 'light') {
      this.isDarkActive = false;
      appCtx?.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } else if (theme === 'dark') {
      this.isDarkActive = true;
      appCtx?.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else {
      // system
      appCtx?.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      // 跟随当前系统配置判断是否暗色
      const currentConfig = appCtx?.getRunningProcessInformation?.();
      this.isDarkActive = true;
    }
  }

  async aboutToAppear() {
    EmitterUtil.on<number>('affffa', (event) => {
      if (event?.data === 1) {
        this.downloadWebLoading.open()
      } else {
        this.downloadWebLoading.close()
      }
    })
    this.isLSRefresh = await getLSRefresh() || this.isLSRefresh;
    this.c_pg_ua = await getUserAgent() || this.c_pg_ua;
    this.c_ua_temp = await getUserAgent() || this.c_pg_ua;
    this.saved_home_url = await getHomeUrl() || this.saved_home_url;
    this.isHidebar = (await getIshidebar() || this.isHidebar);
    this.isHidestatus = (await getIshidestatus() || this.isHidestatus);
    this.ua_type = (await getUserAgentType() || this.ua_type);
    this.isFull = (await getIsfull() || this.isFull);
    this.slide_num = (await getSlidenum() || this.slide_num);
    this.ipResolveMode = (await getIpResolveMode() || this.ipResolveMode);
    this.themeMode = (await getThemeMode() || this.themeMode);
    this.applyThemeMode(this.themeMode);

    setTimeout(() => {
      this.backToHome();
      this.setSystemFull(this.isFull, this.isHidestatus, this.isHidebar);
    }, 50);
  }

  aboutToDisappear(): void {
    EmitterUtil.off<number>('affffa', (event) => {})
  }

  @Builder
  content() {
    Stack() {
      Column() {
        Row() {
          TextInput({
            placeholder: '请输入有效的URL地址',
            text: this.saved_home_url
          })
            .height(34)
            .width("76%")
            .backgroundColor(this.isDarkActive ? '#1E1E1E' : '#FFFFFF')
            .fontColor(this.isDarkActive ? '#FFFFFF' : '#1A1A1A')
            .placeholderColor(this.isDarkActive ? '#777777' : '#999999')
            .onChange((value) => {
              this.home_url = value;
            })

          Button('保存')
            .height(34)
            .width("20%")
            .type(ButtonType.Capsule)
            .backgroundColor(this.isDarkActive ? '#FFFFFF' : '#000000')
            .fontColor(this.isDarkActive ? '#000000' : '#FFFFFF')
            .onClick(() => {
              if (this.home_url) {
                saveHomeUrl(this.home_url);
                this.saved_home_url = this.home_url
                this.backToHome();
              }
              this.showTopRow = false
              this.showRefreshRow = true
              this.showButtonRow = true
              this.onRefreshing();
            })
        }
        .visibility(this.showTopRow ? Visibility.Visible : Visibility.None)
        .height(44)
        .width("100%")
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.SpaceAround)

        Row() {
          LoadingProgress()
            .height(28)
            .color(this.isDarkActive ? '#FFFFFF' : '#000000')
          Text('正在刷新...')
            .fontSize(15)
            .fontColor(this.isDarkActive ? '#E0E0E0' : '#333333')
            .margin({ left: 16 })
        }
        .visibility(this.showRefreshRow ? Visibility.Visible : Visibility.None)
        .alignItems(VerticalAlign.Center)

        Row() {
          Button({ type: ButtonType.Circle }) {
            Image($r('app.media.settings'))
              .width(20)
              .height(20)
          }
          .backgroundColor(this.isDarkActive ? '#2A2A2A' : '#E0E0E0')
          .onClick(() => {
            this.showSetting = true
          })
          .height(34)
          .width(34)

          Button("清除缓存")
            .onClick(() => {
              this.controller.removeCache(true)
              promptAction.showToast({ message: '缓存已清除' });
            })
            .height(34)
            .width("28%")
            .backgroundColor(this.isDarkActive ? '#2A2A2A' : '#E0E0E0')
            .fontColor(this.isDarkActive ? '#FFFFFF' : '#1A1A1A')

          Button("返回首页")
            .onClick(() => {
              this.is_home = true
              this.backToHome()
              setTimeout(() => {
                this.is_home = false
              }, 1000);
            })
            .height(34)
            .width("54%")
            .backgroundColor(this.isDarkActive ? '#FFFFFF' : '#000000')
            .fontColor(this.isDarkActive ? '#000000' : '#FFFFFF')
        }
        .visibility(this.showButtonRow ? Visibility.Visible : Visibility.None)
        .padding({ top: 6, bottom: 6 })
        .height(46)
        .width("100%")
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.isDarkActive ? '#000000' : '#F5F5F7')
        .justifyContent(FlexAlign.SpaceAround)
      }
    }
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.refreshing, builder: this.content() }) {
        NavDestination() {
          Column() {
            Web({ src: this.saved_home_url, controller: this.controller })
              .onControllerAttached(() => {
                this.controller.setNetworkAvailable(true);
                this.webDownloadFile.setDownloadDelegate(this.controller);
                console.info("onControllerAttached");
                try {
                  this.change_userAgent()
                } catch (error) {
                  console.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
                }
              })
              .onContextMenuShow((event) => {
                  this.result = event.result
                  this.linkUrl = event.param.getLinkUrl();
                  this.imgUrl = event.param.getSourceUrl();
                  let hitValue = this.controller.getHitTestValue()
                  let img64 = hitValue.extra
                if(this.imgUrl==''&&img64!=''){
                  this.imgUrl = img64
                }
                let mediaType = event.param.getMediaType()
                if (mediaType === ContextMenuMediaType.Image) {
                  if(this.imgUrl.startsWith("data:image")) {
                  } else {
                    if(this.imgUrl != '') {
                      this.showMenu = true;
                      this.pic_dl_show = Visibility.Hidden;
                    }
                  }
                }
                return true;
              })
              .bindPopup(this.showMenu,
                {
                  builder: this.MenuBuilder(),
                  enableArrow: false,
                  placement: Placement.LeftTop,
                  offset: { x: this.offsetX, y: this.offsetY },
                  mask: false,
                  onStateChange: (e) => {
                    if (!e.isVisible) {
                      this.showMenu = false;
                    }
                  }
                })
              .domStorageAccess(true)
              .javaScriptAccess(true)
              .geolocationAccess(true)
              .imageAccess(true)
              .onlineImageAccess(true)
              .fileAccess(true)
              .mediaPlayGestureAccess(true)
              .mixedMode(MixedMode.Compatible)
              .darkMode(this.isDarkActive ? WebDarkMode.On : WebDarkMode.Auto)
              .forceDarkAccess(this.isDarkActive)
              .backgroundColor(this.isDarkActive ? '#000000' : '#FFFFFF')
              .onSslErrorEventReceive((event) => {
                // 允许自签名/内网自建证书通过，保证 NAS 局域网访问正常
                event.handler.handleConfirm();
              })
              .onErrorReceive((event) => {
                console.error(`Web error: ${event?.error?.getErrorCode()}, ${event?.error?.getErrorInfo()}`);
              })
              .onHttpErrorReceive((event) => {
                console.error(`HTTP error: ${event?.response?.getResponseCode()}`);
              })
          }
          .width("100%")
          .height("100%")
          .backgroundColor(this.isDarkActive ? '#000000' : '#FFFFFF')
        }
      }
      .pullDownRatio(this.slide_num * this.isdrag)
      .backgroundColor(this.isDarkActive ? '#000000' : '#F5F5F7')
      .onRefreshing(() => this.onRefreshing())
      .onSizeChange(() => {
        window.getLastWindow(this.getUIContext().getHostContext(), (err, win) => {
          let cutOutInfo = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM_GESTURE)
          if (window.Orientation.AUTO_ROTATION) {
            let rotation: number = display.getDefaultDisplaySync().orientation
            if (this.isLSRefresh == 'true') {
              if (rotation == 0 || rotation == 2) {
                this.isLandscape = false;
                this.isdrag = 1;
              } else {
                this.isLandscape = true;
                this.isdrag = 0;
              }
            }
          }
        })
      })
      .width('100%')
      .height('100%')

      // 设置弹窗
      Column() {
        Column() {
          Scroll() {
            Column() {
              // 首页设置
              Row() {
                Text("首页")
                  .width("16%")
                  .height(34)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                TextInput({
                  placeholder: '请输入有效的URL地址',
                  text: this.saved_home_url
                })
                  .height(34)
                  .width("64%")
                  .padding({ top: '4vp', right: '10vp', bottom: '4vp', left: '10vp' })
                  .backgroundColor(this.isDarkActive ? '#2C2C2E' : '#FFFFFF')
                  .fontColor(this.isDarkActive ? '#FFFFFF' : '#1A1A1A')
                  .placeholderColor(this.isDarkActive ? '#777777' : '#999999')
                  .onChange((value) => {
                    this.home_url = value;
                  })
                Text().width(6)
                Button('保存')
                  .height(34)
                  .width("18%")
                  .type(ButtonType.Capsule)
                  .backgroundColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .fontColor(this.isDarkActive ? '#000000' : '#FFFFFF')
                  .onClick(() => {
                    if (this.home_url) {
                      saveHomeUrl(this.home_url);
                      this.saved_home_url = this.home_url;
                      this.backToHome();
                    }
                  })
              }
              .width('100%')

              // 分割线
              Divider()
                .color(this.isDarkActive ? '#2A2A2A' : '#E8E8E8')
                .margin({ top: 12, bottom: 12 })

              // IP解析偏好
              Row() {
                Text("IP解析")
                  .width('18%')
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Row() {
                  Radio({ value: 'auto', group: 'ip_resolve_group' })
                    .checked(this.ipResolveMode === 'auto')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.ipResolveMode = 'auto';
                        saveIpResolveMode('auto');
                        this.backToHome();
                      }
                    })
                  Text("默认")
                    .fontSize(14)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                    .margin({ right: 10 })

                  Radio({ value: 'v4', group: 'ip_resolve_group' })
                    .checked(this.ipResolveMode === 'v4')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.ipResolveMode = 'v4';
                        saveIpResolveMode('v4');
                        this.backToHome();
                      }
                    })
                  Text("IPv4")
                    .fontSize(14)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                    .margin({ right: 10 })

                  Radio({ value: 'v6', group: 'ip_resolve_group' })
                    .checked(this.ipResolveMode === 'v6')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.ipResolveMode = 'v6';
                        saveIpResolveMode('v6');
                        this.backToHome();
                      }
                    })
                  Text("IPv6")
                    .fontSize(14)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                }
              }
              .width('100%')

              // 主题模式选择
              Divider()
                .color(this.isDarkActive ? '#2A2A2A' : '#E8E8E8')
                .margin({ top: 12, bottom: 12 })

              Row() {
                Text("外观主题")
                  .width('20%')
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Row() {
                  Radio({ value: 'system', group: 'theme_mode_group' })
                    .checked(this.themeMode === 'system')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.applyThemeMode('system');
                      }
                    })
                  Text("跟随系统")
                    .fontSize(13)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                    .margin({ right: 8 })

                  Radio({ value: 'light', group: 'theme_mode_group' })
                    .checked(this.themeMode === 'light')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.applyThemeMode('light');
                      }
                    })
                  Text("亮色")
                    .fontSize(13)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                    .margin({ right: 8 })

                  Radio({ value: 'dark', group: 'theme_mode_group' })
                    .checked(this.themeMode === 'dark')
                    .height(20)
                    .onChange((isChecked) => {
                      if (isChecked) {
                        this.applyThemeMode('dark');
                      }
                    })
                  Text("AMOLED黑")
                    .fontSize(13)
                    .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                }
              }
              .width('100%')

              // UA设置
              Divider()
                .color(this.isDarkActive ? '#2A2A2A' : '#E8E8E8')
                .margin({ top: 12, bottom: 12 })

              Row() {
                Text("UA")
                  .width('16%')
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Radio({ value: 'Mobile', group: 'ua_type_group' })
                  .checked(this.ua_type === 'Mobile')
                  .onChange((isChecked) => {
                    if (isChecked) {
                      this.ua_type = 'Mobile';
                      saveUserAgentType('Mobile');
                      this.change_userAgent();
                      this.refreshWeb();
                    }
                  })
                  .height(20)
                Text("手机")
                  .fontSize(14)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                  .onClick(() => {
                    if (this.ua_type == 'custom') {
                      this.c_ua_temp = this.getuseragentbytype('Mobile');
                    }
                  })

                Radio({ value: 'PC', group: 'ua_type_group' })
                  .checked(this.ua_type === 'PC')
                  .onChange((isChecked) => {
                    if (isChecked) {
                      this.ua_type = 'PC';
                      saveUserAgentType('PC');
                      this.change_userAgent();
                      this.refreshWeb();
                    }
                  })
                  .height(20)
                Text("电脑")
                  .fontSize(14)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                  .onClick(() => {
                    if (this.ua_type == 'custom') {
                      this.c_ua_temp = this.getuseragentbytype('PC');
                    }
                  })

                Radio({ value: 'custom', group: 'ua_type_group' })
                  .checked(this.ua_type === 'custom')
                  .onChange((isChecked) => {
                    if (isChecked) {
                      this.ua_type = 'custom';
                      saveUserAgentType('custom');
                      this.change_userAgent();
                      this.refreshWeb();
                    }
                  })
                  .height(20)
                Text("自定义")
                  .fontSize(14)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                  .onClick(() => {
                    if (this.ua_type == 'custom') {
                      this.c_ua_temp = this.getuseragentbytype('custom');
                    }
                  })
              }
              .justifyContent(FlexAlign.SpaceAround)
              .width('100%')

              Row() {
                TextArea({
                  text: this.c_ua_temp,
                  placeholder: '请输入UA(可不填)，确认才保存。点击上方[手机][电脑][自定义]文字可将其UA复制到此处。'
                })
                  .height(130)
                  .textAlign(TextAlign.Start)
                  .width("80%")
                  .backgroundColor(this.isDarkActive ? '#2C2C2E' : '#FFFFFF')
                  .fontColor(this.isDarkActive ? '#FFFFFF' : '#1A1A1A')
                  .placeholderColor(this.isDarkActive ? '#777777' : '#999999')
                  .onChange((value) => {
                    this.c_ua_temp = value;
                  })

                Text().width(6)

                Button('保存')
                  .height(34)
                  .width("18%")
                  .type(ButtonType.Capsule)
                  .backgroundColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .fontColor(this.isDarkActive ? '#000000' : '#FFFFFF')
                  .onClick(() => {
                    if (this.c_ua_temp) {
                      this.c_pg_ua = this.c_ua_temp;
                      saveUserAgent(this.c_pg_ua);
                      this.change_userAgent()
                      this.refreshWeb();
                    }
                  })
              }
              .visibility(this.ua_type == 'custom' ? Visibility.Visible : Visibility.None)
              .margin({ top: 8 })

              Divider()
                .color(this.isDarkActive ? '#2A2A2A' : '#E8E8E8')
                .margin({ top: 12, bottom: 12 })

              // 开关选项组
              Row() {
                Text("横屏禁止刷新")
                  .width("50%")
                  .height(32)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Toggle({ type: ToggleType.Switch, isOn: this.get_isLSRefresh() })
                  .height(24)
                  .selectedColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .onChange((isOn: boolean) => {
                    if (isOn) {
                      this.isLSRefresh = 'true';
                      saveLSRefresh(this.isLSRefresh);
                      this.isdrag = this.isLandscape ? 0 : 1;
                    } else {
                      this.isLSRefresh = 'false';
                      saveLSRefresh(this.isLSRefresh);
                      this.isdrag = 1;
                    }
                  })
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')

              Row() {
                Text("全屏模式")
                  .width("50%")
                  .height(32)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Toggle({ type: ToggleType.Switch, isOn: this.get_isfull() })
                  .height(24)
                  .selectedColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .onChange((isOn: boolean) => {
                    this.isFull = isOn ? 'true' : 'false';
                    saveIsfull(this.isFull);
                    this.setSystemFull(this.isFull, this.isHidestatus, this.isHidebar);
                  })
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')

              Row() {
                Text("显示状态栏")
                  .width("50%")
                  .height(32)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Toggle({ type: ToggleType.Switch, isOn: this.get_isHideStatus() })
                  .height(24)
                  .selectedColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .onChange((isOn: boolean) => {
                    this.isHidestatus = isOn ? 'true' : 'false';
                    saveIshidestatus(this.isHidestatus);
                    this.setSystemFull(this.isFull, this.isHidestatus, this.isHidebar);
                  })
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')

              Row() {
                Text("显示底部导航条")
                  .width("50%")
                  .height(32)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Toggle({ type: ToggleType.Switch, isOn: this.get_isHideBar() })
                  .height(24)
                  .selectedColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .onChange((isOn: boolean) => {
                    this.isHidebar = isOn ? 'true' : 'false';
                    saveIshidebar(this.isHidebar);
                    this.setSystemFull(this.isFull, this.isHidestatus, this.isHidebar);
                  })
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')

              // 下拉灵敏度
              Row() {
                Text("下拉灵敏度")
                  .width("28%")
                  .height(32)
                  .fontSize(15)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                Slider({
                  value: this.slide_num * 100,
                  step: 10,
                  min: 10,
                  style: SliderStyle.InSet
                })
                  .width('58%')
                  .height(25)
                  .showSteps(true)
                  .selectedColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .onChange((value: number, mode: SliderChangeMode) => {
                    this.slide_num = value / 100;
                    saveSlidenum(value / 100);
                  })
                Text((this.slide_num * 100).toFixed(0))
                  .width('12%')
                  .height(32)
                  .fontSize(14)
                  .fontColor(this.isDarkActive ? '#E5E5EA' : '#1A1A1A')
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .margin({ top: 4 })

              Divider()
                .color(this.isDarkActive ? '#2A2A2A' : '#E8E8E8')
                .margin({ top: 12, bottom: 8 })

              Row() {
                Text("Version: 1.1.0")
                  .width('100%')
                  .fontSize(12)
                  .fontColor(this.isDarkActive ? '#666666' : '#999999')
                  .textAlign(TextAlign.Center)
              }
              .margin({ bottom: 12 })

              Row() {
                Button('完成')
                  .type(ButtonType.Capsule)
                  .backgroundColor(this.isDarkActive ? '#FFFFFF' : '#000000')
                  .fontColor(this.isDarkActive ? '#000000' : '#FFFFFF')
                  .onClick(() => {
                    this.showSetting = false
                    this.c_ua_temp = this.c_pg_ua;
                  })
                  .height(38)
                  .width(130)
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
            }
            .padding({ top: 18, bottom: 18, left: 18, right: 18 })
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width("90%")
        .constraintSize({ maxHeight: '82%' })
        .backgroundColor(this.isDarkActive ? '#121212' : '#FFFFFF')
        .border({
          width: 1,
          color: this.isDarkActive ? '#262626' : '#E8E8E8'
        })
        .borderRadius(18)
        .shadow({
          radius: 24,
          color: this.isDarkActive ? '#40000000' : '#20000000',
          offsetX: 0,
          offsetY: 8
        })
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.isDarkActive ? '#80000000' : '#40000000')
      .visibility(this.showSetting ? Visibility.Visible : Visibility.None)

    }
    .height('100%')
    .width('100%')
    .backgroundColor(this.isDarkActive ? '#000000' : '#F5F5F7')
  }

  onBackPress() {
    if (this.controller.accessStep(-1)) {
      this.controller.backward();
      return true
    } else {
      return false
    }
  }

  onRefreshing() {
    this.refreshTimerId = setTimeout(() => {
      this.list = Array(20).fill(Date.now());
      this.refreshing = false;

      if (!this.is_home) {
        this.refreshWeb();
        this.is_home = false;
        promptAction.showToast({ message: '刷新成功' });
      }
    }, 1000);
  }

  private clearRefreshTimer() {
    if (this.refreshTimerId !== null) {
      clearTimeout(this.refreshTimerId);
      this.refreshTimerId = null;
    }
  }

  private refreshWeb() {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.controller.refresh();
    setTimeout(() => {
      this.isRefreshing = false;
    }, 1000);
  }

  private cancelRefresh() {
    this.clearRefreshTimer();
    this.isRefreshing = true;
    this.refreshing = true;
    this.controller.stop();
  }

  // 解析目标地址（支持 IPv4 / IPv6 模式调度）
  async resolveTargetUrl(targetUrl: string): Promise<string> {
    if (!targetUrl || targetUrl.startsWith('/') || targetUrl.startsWith('file://')) {
      return targetUrl;
    }
    if (this.ipResolveMode === 'auto') {
      return targetUrl;
    }

    // 注意：HTTPS 服务严重依赖 SNI (Server Name Indication) 协商正确证书。
    // 如果把 URL 替换为 IP（例如 https://123.56.28.195:8000），TLS 客户端 ClientHello
    // 发送的 ServerName 会变成 IP 地址，服务端将回退到默认自签名证书或重置握手导致加载失败。
    // 因此对于 HTTPS 站点，不直接篡改 URL 里的域名。
    if (targetUrl.toLowerCase().startsWith('https://')) {
      return targetUrl;
    }

    try {
      // 提取协议、主机名及端口与路径
      let protoMatch = targetUrl.match(/^https?:\/\//i);
      let proto = protoMatch ? protoMatch[0] : 'http://';
      let rest = targetUrl.substring(proto.length);
      let slashIdx = rest.indexOf('/');
      let authority = slashIdx !== -1 ? rest.substring(0, slashIdx) : rest;
      let pathAndQuery = slashIdx !== -1 ? rest.substring(slashIdx) : '';

      let host = authority;
      let port = '';
      if (authority.includes(':') && !authority.startsWith('[')) {
        let parts = authority.split(':');
        host = parts[0];
        port = ':' + parts[1];
      } else if (authority.startsWith('[')) {
        // 已经是 IPv6 字面量
        return targetUrl;
      }

      // 如果本身就是 IPv4 地址，直接返回
      if (/^(\d{1,3}\.){3}\d{1,3}$/.test(host)) {
        return targetUrl;
      }

      // 使用 connection.getAddressesByName 解析 DNS
      let addresses = await connection.getAddressesByName(host);
      if (!addresses || addresses.length === 0) {
        return targetUrl;
      }

      let chosenIp = '';
      if (this.ipResolveMode === 'v6') {
        let v6Obj = addresses.find(item => item.address && item.address.includes(':'));
        if (v6Obj) {
          chosenIp = `[${v6Obj.address}]`;
        } else {
          promptAction.showToast({ message: '未找到该域名的IPv6解析，回退默认' });
          return targetUrl;
        }
      } else if (this.ipResolveMode === 'v4') {
        let v4Obj = addresses.find(item => item.address && item.address.includes('.') && !item.address.includes(':'));
        if (v4Obj) {
          chosenIp = v4Obj.address;
        } else {
          promptAction.showToast({ message: '未找到该域名的IPv4解析，回退默认' });
          return targetUrl;
        }
      }

      if (chosenIp) {
        this.originalTargetHost = host;
        let resolvedUrl = `${proto}${chosenIp}${port}${pathAndQuery}`;
        return resolvedUrl;
      }
    } catch (e) {
      console.error(`DNS resolve failed: ${e}`);
    }

    return targetUrl;
  }

  // 返回首页 / 加载目标 URL
  async backToHome() {
    let finalUrl = await this.resolveTargetUrl(this.saved_home_url);
    if (this.originalTargetHost && finalUrl !== this.saved_home_url) {
      // 传递 Host 请求头
      this.controller.loadUrl(finalUrl, [{ headerKey: 'Host', headerValue: this.originalTargetHost }]);
    } else {
      this.controller.loadUrl(finalUrl);
    }
  }

  get_isLSRefresh() {
    return this.isLSRefresh == 'true';
  }

  get_isHideBar() {
    return this.isHidebar == 'true';
  }

  get_isHideStatus() {
    return this.isHidestatus == 'true';
  }

  get_isfull() {
    return this.isFull == 'true';
  }

  getuseragentbytype(type: string) {
    let default_userAgent = this.controller.getUserAgent();
    let mobile_userAgent = default_userAgent.replace('PC', 'Mobile').replace('PC', 'Phone');
    let pc_userAgent = default_userAgent.replace('Mobile', 'PC').replace('Phone', 'PC');
    let custom_userAgent = this.c_pg_ua;
    let ua: string = '';
    switch (type) {
      case 'Mobile':
        ua = mobile_userAgent;
        break;
      case 'PC':
        ua = pc_userAgent;
        break;
      case 'custom':
        ua = custom_userAgent;
        break;
      default:
        ua = 'error';
        break;
    }
    return ua;
  }

  change_userAgent() {
    let default_userAgent = this.controller.getUserAgent();
    let mobile_userAgent = default_userAgent.replace('PC', 'Mobile').replace('PC', 'Phone');
    let pc_userAgent = default_userAgent.replace('Mobile', 'PC').replace('Phone', 'PC');
    let custom_userAgent = this.c_pg_ua;

    if (this.ua_type == 'Mobile') {
      this.userAgent = mobile_userAgent;
    }
    if (this.ua_type == 'PC') {
      this.userAgent = pc_userAgent;
    }
    if (this.ua_type == 'custom') {
      this.userAgent = custom_userAgent;
    }
    this.controller.setCustomUserAgent(this.userAgent);
  }
}
