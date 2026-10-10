import preferences from '@ohos.data.preferences';

let prefs: preferences.Preferences;

async function getPreferences() {
  if (!prefs) {
    prefs = await preferences.getPreferences(globalThis.getContext(), 'app_config');
  }
  return prefs;
}

export async function saveHomeUrl(page_url: string) {
  const store = await getPreferences();
  await store.put('homepage_url', page_url);
  await store.flush(); // 刷新保存
}

export async function getHomeUrl(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('homepage_url', ''));
}

export async function saveUserAgent(page_ua: string) {
  const store = await getPreferences();
  await store.put('c_userAgent', page_ua);
  await store.flush(); // 刷新保存
}

export async function getUserAgent(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('c_userAgent', ''));
}

export async function saveUserAgentType(page_ua_type: string) {
  const store = await getPreferences();
  await store.put('userAgent_type', page_ua_type);
  await store.flush(); // 刷新保存
}

export async function getUserAgentType(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('userAgent_type', ''));
}

export async function saveIshidebar(ishidebar: string) {
  const store = await getPreferences();
  await store.put('is_hidebar', ishidebar);
  await store.flush(); // 刷新保存
}

export async function getIshidebar(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('is_hidebar', ''));
}

export async function saveIshidestatus(ishidestatus: string) {
  const store = await getPreferences();
  await store.put('is_hidestatus', ishidestatus);
  await store.flush(); // 刷新保存
}

export async function getIshidestatus(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('is_hidestatus', ''));
}

export async function saveIsfull(isfull: string) {
  const store = await getPreferences();
  await store.put('is_full', isfull);
  await store.flush(); // 刷新保存
}

export async function getIsfull(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('is_full', ''));
}

export async function saveSlidenum(slidenum: number) {
  const store = await getPreferences();
  await store.put('slide_num', slidenum);
  await store.flush(); // 刷新保存
}

export async function getSlidenum(): Promise<number> {
  const store = await getPreferences();
  return Number(await store.get('slide_num', 0));
}

// IP解析模式: 'auto' (系统默认) | 'v4' (IPv4优先/仅v4) | 'v6' (IPv6优先/仅v6)
export async function saveIpResolveMode(mode: string) {
  const store = await getPreferences();
  await store.put('ip_resolve_mode', mode);
  await store.flush();
}

export async function getIpResolveMode(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('ip_resolve_mode', 'auto'));
}

// 主题模式: 'system' (跟随系统) | 'light' (亮色) | 'dark' (AMOLED纯黑)
export async function saveThemeMode(theme: string) {
  const store = await getPreferences();
  await store.put('theme_mode', theme);
  await store.flush();
}

export async function getThemeMode(): Promise<string> {
  const store = await getPreferences();
  return String(await store.get('theme_mode', 'system'));
}

