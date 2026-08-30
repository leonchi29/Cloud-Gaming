export type LogLevel = 'info' | 'warn' | 'error';

function timestamp(): string {
  return new Date().toISOString();
}

export const logger = {
  info(message: string, meta?: unknown): void {
    console.log(`[${timestamp()}] [INFO] ${message}`, meta !== undefined ? JSON.stringify(meta) : '');
  },
  warn(message: string, meta?: unknown): void {
    console.warn(`[${timestamp()}] [WARN] ${message}`, meta !== undefined ? JSON.stringify(meta) : '');
  },
  error(message: string, meta?: unknown): void {
    console.error(`[${timestamp()}] [ERROR] ${message}`, meta !== undefined ? JSON.stringify(meta) : '');
  },
};
