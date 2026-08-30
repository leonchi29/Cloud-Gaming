import screenshot from 'screenshot-desktop';
import robot from 'robotjs';
import { logger } from './logger';
import type { StreamFrame } from './types';

export interface StreamerOptions {
  fps: number;
  onFrame: (frame: StreamFrame) => void;
}

/**
 * Captura la pantalla del host de forma periódica y envía los frames
 * al backend para su retransmisión al navegador.
 */
export class ScreenStreamer {
  private timer: NodeJS.Timeout | null = null;
  private capturing = false;

  constructor(private readonly options: StreamerOptions) {}

  start(): void {
    if (this.timer) return;
    const intervalMs = Math.max(Math.round(1000 / this.options.fps), 33);
    this.timer = setInterval(() => void this.captureOnce(), intervalMs);
    this.timer.unref();
    logger.info('Streaming de pantalla iniciado', { fps: this.options.fps });
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
      logger.info('Streaming de pantalla detenido');
    }
  }

  isActive(): boolean {
    return this.timer !== null;
  }

  private async captureOnce(): Promise<void> {
    if (this.capturing) return; // evita solapamiento si la captura tarda más que el intervalo
    this.capturing = true;
    try {
      const buffer = await screenshot({ format: 'png' });
      const size = robot.getScreenSize();
      this.options.onFrame({
        data: buffer.toString('base64'),
        format: 'png',
        width: size.width,
        height: size.height,
        timestamp: Date.now(),
      });
    } catch (err) {
      logger.error('Error capturando pantalla', { err: String(err) });
    } finally {
      this.capturing = false;
    }
  }
}
