import vibrator from '@ohos.vibrator';

@Component
export struct FloatBall {
  @Prop isDark: boolean = true;
  // 父容器实测尺寸(由 Index 传入)，替代不可靠的窗口查询
  @Prop @Watch('onContainerResize') containerWidth: number = 0;
  @Prop @Watch('onContainerResize') containerHeight: number = 0;
  onOpenSettings: () => void = () => {};
  onRefresh: () => void = () => {};

  @State private posX: number = 0;
  @State private posY: number = 200;
  @State private isCollapsed: boolean = false;
  @State private collapseSide: 'left' | 'right' = 'right';

  private ballSize: number = 44;
  private peekWidth: number = 20;
  private marginEdge: number = 12;
  private startDragX: number = 0;
  private startDragY: number = 0;
  private autoCollapseTimer: number = -1;
  private isDragging: boolean = false;
  private placed: boolean = false;

  aboutToAppear(): void {
    this.onContainerResize();
    this.resetCollapseTimer();
  }

  aboutToDisappear(): void {
    this.clearCollapseTimer();
  }

  // 父容器尺寸确定/变化时：首次放到右侧默认位，之后把球夹回可视范围
  onContainerResize(): void {
    if (this.containerWidth <= 0) {
      return;
    }
    if (!this.placed) {
      this.posX = this.containerWidth - this.ballSize - this.marginEdge;
      this.placed = true;
    }
    this.clampToScreen();
  }

  private clearCollapseTimer(): void {
    if (this.autoCollapseTimer !== -1) {
      clearTimeout(this.autoCollapseTimer);
      this.autoCollapseTimer = -1;
    }
  }

  private resetCollapseTimer(): void {
    this.clearCollapseTimer();
    this.autoCollapseTimer = setTimeout(() => {
      this.collapseToSide();
    }, 3000);
  }

  private collapseToSide(): void {
    if (this.isDragging || this.isCollapsed || this.containerWidth <= 0) {
      return;
    }
    const middle = this.containerWidth / 2;
    const currentCenter = this.posX + this.ballSize / 2;
    this.collapseSide = currentCenter < middle ? 'left' : 'right';

    this.getUIContext().animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.isCollapsed = true;
      if (this.collapseSide === 'left') {
        this.posX = 0;
      } else {
        this.posX = this.containerWidth - this.peekWidth;
      }
    });
    console.info(`[FloatBall] collapse side=${this.collapseSide} posX=${this.posX} w=${this.containerWidth}`);
  }

  private restoreFromCollapsed(): void {
    this.getUIContext().animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
      this.isCollapsed = false;
      if (this.collapseSide === 'left') {
        this.posX = this.marginEdge;
      } else {
        this.posX = this.containerWidth - this.ballSize - this.marginEdge;
      }
    });
    this.resetCollapseTimer();
  }

  private snapToNearestSide(): void {
    if (this.containerWidth <= 0) {
      return;
    }
    const middle = this.containerWidth / 2;
    const currentCenter = this.posX + this.ballSize / 2;
    const snapToLeft = currentCenter < middle;
    this.collapseSide = snapToLeft ? 'left' : 'right';

    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      if (snapToLeft) {
        this.posX = this.marginEdge;
      } else {
        this.posX = this.containerWidth - this.ballSize - this.marginEdge;
      }
    });
    this.resetCollapseTimer();
  }

  // 把球夹回可视范围（拖动/收起过程中不干预）
  private clampToScreen(): void {
    if (this.containerWidth <= 0 || this.isDragging || this.isCollapsed) {
      return;
    }
    const maxX = this.containerWidth - this.ballSize - this.marginEdge;
    if (this.posX < this.marginEdge) {
      this.posX = this.marginEdge;
    } else if (this.posX > maxX) {
      this.posX = maxX;
    }
    if (this.containerHeight > 0) {
      const maxY = this.containerHeight - this.ballSize - 40;
      if (this.posY < 40) {
        this.posY = 40;
      } else if (this.posY > maxY) {
        this.posY = maxY;
      }
    }
  }

  // 触发一次短震动（刷新反馈）
  private hapticFeedback(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' })
        .catch(() => {});
    } catch (e) {
      console.error('FloatBall vibrate error:', JSON.stringify(e));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isCollapsed) {
        // 折叠侧边小抓手指示条
        Row()
          .width(3)
          .height(18)
          .borderRadius(2)
          .backgroundColor(this.isDark ? '#B3FFFFFF' : '#8C000000')
      } else {
        // 齿轮中心图标
        Image($r('app.media.settings'))
          .width(22)
          .height(22)
          .fillColor(this.isDark ? '#FFFFFF' : '#1A1A1A')
          .objectFit(ImageFit.Contain)
          .draggable(false)
          .copyOption(CopyOptions.None)
      }
    }
    .width(this.isCollapsed ? this.peekWidth : this.ballSize)
    .height(this.ballSize)
    .borderRadius(this.isCollapsed ? this.peekWidth / 2 : this.ballSize / 2)
    .backgroundColor(
      this.isDark
        ? (this.isCollapsed ? '#66222224' : '#882A2A2E')
        : (this.isCollapsed ? '#77F0F0F2' : '#99FFFFFF')
    )
    .backgroundBlurStyle(
      BlurStyle.Thin,
      { colorMode: this.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT }
    )
    .border({
      width: 1,
      color: this.isDark ? '#33FFFFFF' : '#22000000'
    })
    .shadow({
      radius: this.isCollapsed ? 8 : 14,
      color: this.isDark ? '#55000000' : '#26000000',
      offsetX: 0,
      offsetY: 3
    })
    .position({ x: this.posX, y: this.posY })
    .draggable(false)
    .gesture(
      GestureGroup(
        GestureMode.Exclusive,
        PanGesture()
          .onActionStart(() => {
            this.clearCollapseTimer();
            console.info(`[FloatBall] pan start collapsed=${this.isCollapsed} posX=${this.posX} w=${this.containerWidth}`);
            this.isDragging = true;
            if (this.isCollapsed) {
              this.isCollapsed = false;
            }
            this.startDragX = this.posX;
            this.startDragY = this.posY;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.containerWidth <= 0) {
              return;
            }
            let nextX = this.startDragX + event.offsetX;
            let nextY = this.startDragY + event.offsetY;

            // 限制在容器可视范围内
            if (nextX < 0) {
              nextX = 0;
            } else if (nextX > this.containerWidth - this.ballSize) {
              nextX = this.containerWidth - this.ballSize;
            }

            const minY = 40;
            const maxY = (this.containerHeight > 0 ? this.containerHeight : 780) - this.ballSize - 40;
            if (nextY < minY) {
              nextY = minY;
            } else if (nextY > maxY) {
              nextY = maxY;
            }

            this.posX = nextX;
            this.posY = nextY;
          })
          .onActionEnd(() => {
            console.info(`[FloatBall] pan end posX=${this.posX}`);
            this.isDragging = false;
            this.snapToNearestSide();
          })
          .onActionCancel(() => {
            console.info(`[FloatBall] pan cancel posX=${this.posX}`);
            this.isDragging = false;
            this.snapToNearestSide();
          }),
        LongPressGesture({ repeat: false, duration: 500 })
          .onAction(() => {
            if (this.isCollapsed) {
              this.restoreFromCollapsed();
              return;
            }
            this.resetCollapseTimer();
            this.hapticFeedback();
            this.onRefresh();
          }),
        TapGesture({ count: 1 })
          .onAction(() => {
            if (this.isCollapsed) {
              this.restoreFromCollapsed();
            } else {
              this.resetCollapseTimer();
              this.onOpenSettings();
            }
          })
      )
    )
  }
}
