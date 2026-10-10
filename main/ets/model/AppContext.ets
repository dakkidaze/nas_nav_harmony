import { common } from '@kit.AbilityKit';
import { UIContext } from '@kit.ArkUI';

/** 全局上下文持有者：替代 globalThis 与已弃用的 getContext() */
export class AppContext {
  static ctx: common.UIAbilityContext | undefined = undefined;
  static uiContext: UIContext | undefined = undefined;
}
