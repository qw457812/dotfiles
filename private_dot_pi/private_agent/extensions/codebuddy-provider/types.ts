import type { OAuthCredentials } from "@earendil-works/pi-ai";

// ── Auth platform ────────────────────────────────────────────────────────────
export type CodebuddyAuthPlatform = "CLI" | "ide";

// ── Credentials type ─────────────────────────────────────────────────────────
export type CodebuddyOAuthCredentials = {
  userId?: string;
  uid?: string;
  email?: string;
  nickname?: string;
  enterpriseId?: string;
  enterpriseName?: string;
  domain?: string;
  authBaseUrl?: string;
  authPlatform?: CodebuddyAuthPlatform;
  accountBaseUrl?: string;
} & OAuthCredentials;

// ── Shared internal types ─────────────────────────────────────────────────────
export type CodebuddyAuthState = {
  baseUrl: string;
  platform: CodebuddyAuthPlatform;
  state: string;
  authUrl: string;
};

export type CodebuddyTokenPayload = {
  accessToken: string;
  refreshToken: string;
  expires: number;
  domain?: string;
};

export type CodebuddyProfile = {
  userId?: string;
  uid?: string;
  email?: string;
  nickname?: string;
  enterpriseId?: string;
  enterpriseName?: string;
};
