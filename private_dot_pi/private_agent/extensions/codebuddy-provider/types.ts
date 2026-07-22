import type { OAuthCredential } from "@earendil-works/pi-ai";

// ── API response envelope ──────────────────────────────────────────────────
export type ApiResponse<T> = {
  code?: number;
  message?: string;
  msg?: string;
  data?: T;
};

// ── Auth state response ──────────────────────────────────────────────────────
export type AuthStateData = {
  state?: string;
  authUrl?: string;
  auth_url?: string;
  url?: string;
};

// ── Token response ──────────────────────────────────────────────────────────
export type TokenData = {
  accessToken?: string;
  access_token?: string;
  refreshToken?: string;
  refresh_token?: string;
  expiresAt?: number;
  expiresIn?: number;
  domain?: string;
};

// ── Accounts response ────────────────────────────────────────────────────────
export type AccountEntry = {
  uid?: string;
  id?: string;
  nickname?: string;
  label?: string;
  name?: string;
  email?: string;
  enterpriseId?: string;
  enterprise_id?: string;
  enterpriseName?: string;
  enterprise_name?: string;
  departmentFullName?: string;
  department_full_name?: string;
  deptFullName?: string;
  lastLogin?: boolean;
  pluginEnabled?: boolean;
};

export type AccountsData = {
  accounts?: AccountEntry[];
  Accounts?: AccountEntry[];
};

// ── Auth platform ────────────────────────────────────────────────────────────
export type AuthPlatform = "cli" | "ide";

// ── Credentials type ─────────────────────────────────────────────────────────
export type CodebuddyOAuthCredentials = {
  userId?: string;
  uid?: string;
  email?: string;
  nickname?: string;
  enterpriseId?: string;
  enterpriseName?: string;
  departmentFullName?: string;
  domain?: string;
  authBaseUrl?: string;
  authPlatform?: AuthPlatform;
  accountBaseUrl?: string;
} & OAuthCredential;

// ── Shared internal types ─────────────────────────────────────────────────────
export type AuthState = {
  baseUrl: string;
  platform: AuthPlatform;
  state: string;
  authUrl: string;
};

export type TokenPayload = {
  accessToken: string;
  refreshToken: string;
  expires: number;
  domain?: string;
};

export type Profile = {
  userId?: string;
  uid?: string;
  email?: string;
  nickname?: string;
  enterpriseId?: string;
  enterpriseName?: string;
  departmentFullName?: string;
};
