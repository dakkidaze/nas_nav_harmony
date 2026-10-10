import preferences from '@ohos.data.preferences';
import { AppContext } from './AppContext';

let prefs: preferences.Preferences;

async function getPreferences(): Promise<preferences.Preferences | undefined> {
  if (!prefs) {
    if (!AppContext.ctx) {
      console.error('StorageService AppContext.ctx is undefined');
      return undefined;
    }
    try {
      prefs = await preferences.getPreferences(AppContext.ctx!, 'app_config');
    } catch (e) {
      console.error('StorageService getPreferences error:', JSON.stringify(e));
      return undefined;
    }
  }
  return prefs;
}

export async function saveHomeUrl(page_url: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('homepage_url', page_url);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveHomeUrl error:', JSON.stringify(e));
  }
}

export async function getHomeUrl(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('homepage_url', ''));
    }
  } catch (e) {
    console.error('getHomeUrl error:', JSON.stringify(e));
  }
  return '';
}

export async function saveUserAgent(page_ua: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('c_userAgent', page_ua);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveUserAgent error:', JSON.stringify(e));
  }
}

export async function getUserAgent(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('c_userAgent', ''));
    }
  } catch (e) {
    console.error('getUserAgent error:', JSON.stringify(e));
  }
  return '';
}

export async function saveUserAgentType(page_ua_type: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('userAgent_type', page_ua_type);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveUserAgentType error:', JSON.stringify(e));
  }
}

export async function getUserAgentType(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('userAgent_type', ''));
    }
  } catch (e) {
    console.error('getUserAgentType error:', JSON.stringify(e));
  }
  return '';
}

export async function saveIshidebar(ishidebar: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('is_hidebar', ishidebar);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveIshidebar error:', JSON.stringify(e));
  }
}

export async function getIshidebar(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('is_hidebar', ''));
    }
  } catch (e) {
    console.error('getIshidebar error:', JSON.stringify(e));
  }
  return '';
}

export async function saveIshidestatus(ishidestatus: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('is_hidestatus', ishidestatus);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveIshidestatus error:', JSON.stringify(e));
  }
}

export async function getIshidestatus(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('is_hidestatus', ''));
    }
  } catch (e) {
    console.error('getIshidestatus error:', JSON.stringify(e));
  }
  return '';
}

export async function saveIsfull(isfull: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('is_full', isfull);
      await store.flush(); // 刷新保存
    }
  } catch (e) {
    console.error('saveIsfull error:', JSON.stringify(e));
  }
}

export async function getIsfull(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('is_full', ''));
    }
  } catch (e) {
    console.error('getIsfull error:', JSON.stringify(e));
  }
  return '';
}

export async function saveIpResolveMode(mode: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('ip_resolve_mode', mode);
      await store.flush();
    }
  } catch (e) {
    console.error('saveIpResolveMode error:', JSON.stringify(e));
  }
}

export async function getIpResolveMode(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('ip_resolve_mode', 'auto'));
    }
  } catch (e) {
    console.error('getIpResolveMode error:', JSON.stringify(e));
  }
  return 'auto';
}

// 主题模式: 'system' (跟随系统) | 'light' (亮色) | 'dark' (AMOLED纯黑)
export async function saveThemeMode(theme: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('theme_mode', theme);
      await store.flush();
    }
  } catch (e) {
    console.error('saveThemeMode error:', JSON.stringify(e));
  }
}

export async function getThemeMode(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('theme_mode', 'system'));
    }
  } catch (e) {
    console.error('getThemeMode error:', JSON.stringify(e));
  }
  return 'system';
}

// 网页反色: 'off' (默认关闭) | 'app' (跟随应用)
export async function saveWebDarkMode(mode: string) {
  try {
    const store = await getPreferences();
    if (store) {
      await store.put('web_dark_mode', mode);
      await store.flush();
    }
  } catch (e) {
    console.error('saveWebDarkMode error:', JSON.stringify(e));
  }
}

export async function getWebDarkMode(): Promise<string> {
  try {
    const store = await getPreferences();
    if (store) {
      return String(await store.get('web_dark_mode', 'off'));
    }
  } catch (e) {
    console.error('getWebDarkMode error:', JSON.stringify(e));
  }
  return 'off';
}


