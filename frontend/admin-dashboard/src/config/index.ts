// API configuration and utilities for Admin Dashboard
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';
const API_VERSION = process.env.REACT_APP_API_VERSION || 'v1';

export const apiConfig = {
  baseUrl: API_BASE_URL,
  version: API_VERSION,
  timeout: 30000, // 30 seconds
  retries: 3,
};

export const endpoints = {
  health: `${API_BASE_URL}/api/${API_VERSION}/health`,
  admin: {
    users: `${API_BASE_URL}/api/${API_VERSION}/admin/users`,
    analytics: `${API_BASE_URL}/api/${API_VERSION}/admin/analytics`,
    system: `${API_BASE_URL}/api/${API_VERSION}/admin/system`,
    logs: `${API_BASE_URL}/api/${API_VERSION}/admin/logs`,
    settings: `${API_BASE_URL}/api/${API_VERSION}/admin/settings`,
  },
  auth: {
    login: `${API_BASE_URL}/api/${API_VERSION}/auth/admin/login`,
    logout: `${API_BASE_URL}/api/${API_VERSION}/auth/admin/logout`,
    refresh: `${API_BASE_URL}/api/${API_VERSION}/auth/admin/refresh`,
    twoFactor: `${API_BASE_URL}/api/${API_VERSION}/auth/admin/2fa`,
  },
  loads: {
    list: `${API_BASE_URL}/api/${API_VERSION}/admin/loads`,
    details: (id: string) => `${API_BASE_URL}/api/${API_VERSION}/admin/loads/${id}`,
  },
  carriers: {
    list: `${API_BASE_URL}/api/${API_VERSION}/admin/carriers`,
    details: (id: string) => `${API_BASE_URL}/api/${API_VERSION}/admin/carriers/${id}`,
  },
};

// Environment utilities
export const isDevelopment = process.env.NODE_ENV === 'development';
export const isProduction = process.env.NODE_ENV === 'production';

// Admin-specific feature flags
export const features = {
  adminAnalytics: process.env.REACT_APP_ENABLE_ADMIN_ANALYTICS === 'true',
  userManagement: process.env.REACT_APP_ENABLE_USER_MANAGEMENT === 'true',
  systemMonitoring: process.env.REACT_APP_ENABLE_SYSTEM_MONITORING === 'true',
  twoFactorAuth: process.env.REACT_APP_REQUIRE_2FA === 'true',
  serviceWorker: process.env.REACT_APP_ENABLE_SERVICE_WORKER === 'true',
};

// Logging configuration
export const logLevel = process.env.REACT_APP_LOG_LEVEL || (isDevelopment ? 'debug' : 'info');

// Admin logger with enhanced security logging
export const logger = {
  debug: (...args: any[]) => {
    if (logLevel === 'debug') console.debug('[ADMIN DEBUG]', ...args);
  },
  info: (...args: any[]) => {
    if (['debug', 'info'].includes(logLevel)) console.info('[ADMIN INFO]', ...args);
  },
  warn: (...args: any[]) => {
    if (['debug', 'info', 'warn'].includes(logLevel)) console.warn('[ADMIN WARN]', ...args);
  },
  error: (...args: any[]) => {
    console.error('[ADMIN ERROR]', ...args);
    // In production, admin errors should be logged with high priority
    if (isProduction) {
      // Example: Send to admin monitoring service
    }
  },
  security: (...args: any[]) => {
    console.warn('[ADMIN SECURITY]', ...args);
    // All security events should be logged regardless of level
    if (isProduction) {
      // Example: Send to security monitoring service
    }
  },
};