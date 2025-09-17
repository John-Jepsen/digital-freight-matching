// API configuration and utilities
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
  rateLimitStatus: `${API_BASE_URL}/api/${API_VERSION}/rate_limit/status`,
  auth: {
    login: `${API_BASE_URL}/api/${API_VERSION}/auth/login`,
    logout: `${API_BASE_URL}/api/${API_VERSION}/auth/logout`,
    refresh: `${API_BASE_URL}/api/${API_VERSION}/auth/refresh`,
  },
  loads: {
    list: `${API_BASE_URL}/api/${API_VERSION}/loads`,
    create: `${API_BASE_URL}/api/${API_VERSION}/loads`,
    details: (id: string) => `${API_BASE_URL}/api/${API_VERSION}/loads/${id}`,
  },
  carriers: {
    list: `${API_BASE_URL}/api/${API_VERSION}/carriers`,
    create: `${API_BASE_URL}/api/${API_VERSION}/carriers`,
    details: (id: string) => `${API_BASE_URL}/api/${API_VERSION}/carriers/${id}`,
  },
};

// Environment utilities
export const isDevelopment = process.env.NODE_ENV === 'development';
export const isProduction = process.env.NODE_ENV === 'production';

// Feature flags
export const features = {
  analytics: process.env.REACT_APP_ENABLE_ANALYTICS === 'true',
  errorReporting: process.env.REACT_APP_ENABLE_ERROR_REPORTING === 'true',
  performanceMonitoring: process.env.REACT_APP_ENABLE_PERFORMANCE_MONITORING === 'true',
  serviceWorker: process.env.REACT_APP_ENABLE_SERVICE_WORKER === 'true',
};

// Logging configuration
export const logLevel = process.env.REACT_APP_LOG_LEVEL || (isDevelopment ? 'debug' : 'warn');

// Simple logger with environment-aware levels
export const logger = {
  debug: (...args: any[]) => {
    if (logLevel === 'debug') console.debug('[DEBUG]', ...args);
  },
  info: (...args: any[]) => {
    if (['debug', 'info'].includes(logLevel)) console.info('[INFO]', ...args);
  },
  warn: (...args: any[]) => {
    if (['debug', 'info', 'warn'].includes(logLevel)) console.warn('[WARN]', ...args);
  },
  error: (...args: any[]) => {
    console.error('[ERROR]', ...args);
    // In production, you would send this to error reporting service
    if (features.errorReporting && isProduction) {
      // Example: Sentry.captureException(new Error(args.join(' ')));
    }
  },
};