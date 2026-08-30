import { execFile, spawn } from 'child_process';
import { logger } from './logger';

export interface SunshineMonitorOptions {
  sunshinePath: string;
  checkIntervalMs: number;
  onStatusChange: (running: boolean) => void;
}

/** Verifica periódicamente si sunshine.exe está en ejecución. */
function isSunshineRunning(): Promise<boolean> {
  return new Promise((resolve) => {
    execFile('tasklist', ['/FI', 'IMAGENAME eq sunshine.exe', '/NH'], (error, stdout) => {
      if (error) {
        resolve(false);
        return;
      }
      resolve(stdout.toLowerCase().includes('sunshine.exe'));
    });
  });
}

function launchSunshine(path: string): void {
  try {
    const child = spawn(path, [], { detached: true, stdio: 'ignore' });
    child.unref();
    logger.info('Sunshine reiniciado automáticamente', { path });
  } catch (err) {
    logger.error('No se pudo iniciar Sunshine', err);
  }
}

/**
 * Monitor de Sunshine: comprueba el proceso de forma periódica y lo reinicia
 * automáticamente si se detiene.
 */
export class SunshineMonitor {
  private timer: NodeJS.Timeout | null = null;
  private lastStatus = false;

  constructor(private readonly options: SunshineMonitorOptions) {}

  start(): void {
    void this.check();
    this.timer = setInterval(() => void this.check(), this.options.checkIntervalMs);
    this.timer.unref();
    logger.info('Monitor de Sunshine iniciado', {
      intervalMs: this.options.checkIntervalMs,
    });
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async check(): Promise<void> {
    const running = await isSunshineRunning();
    if (running !== this.lastStatus) {
      this.lastStatus = running;
      this.options.onStatusChange(running);
      logger.info(`Sunshine ${running ? 'en ejecución' : 'detenido'}`);
    }
    if (!running) {
      launchSunshine(this.options.sunshinePath);
    }
  }
}
