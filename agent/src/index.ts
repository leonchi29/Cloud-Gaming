import { io, Socket } from 'socket.io-client';
import { loadConfig } from './config';
import { logger } from './logger';
import { SunshineMonitor } from './sunshineMonitor';
import { ScreenStreamer } from './streamer';
import { applyInputEvent, releaseAllInputs } from './inputController';
import type { InputEvent, SignalPayload, StreamFrame } from './types';

const config = loadConfig();

let socket: Socket | null = null;
let sessionActive = false;

const streamer = new ScreenStreamer({
  fps: config.streamFps,
  onFrame: (frame: StreamFrame) => {
    if (socket?.connected && sessionActive) {
      socket.emit('stream:frame', frame);
    }
  },
});

const sunshineMonitor = new SunshineMonitor({
  sunshinePath: config.sunshinePath,
  checkIntervalMs: config.sunshineCheckIntervalMs,
  onStatusChange: (running: boolean) => {
    if (socket?.connected) {
      socket.emit('agent:sunshine-status', { running });
    }
  },
});

function connect(): void {
  logger.info('Conectando al backend', { url: config.backendUrl });

  socket = io(config.backendUrl, {
    transports: ['websocket'],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 15000,
    timeout: 20000,
  });

  socket.on('connect', () => {
    logger.info('Conectado al backend', { id: socket?.id });
    socket?.emit('agent:register', { token: config.agentToken });
  });

  socket.on('agent:registered', () => {
    logger.info('Agente registrado correctamente en el backend');
  });

  socket.on('agent:rejected', (payload: { reason: string }) => {
    logger.error('Registro rechazado por el backend', payload);
  });

  socket.on('session:started', (payload: { clientId: string }) => {
    logger.info('Sesión remota iniciada', payload);
    sessionActive = true;
    streamer.start();
  });

  socket.on('session:ended', (payload: { clientId: string }) => {
    logger.info('Sesión remota finalizada', payload);
    sessionActive = false;
    streamer.stop();
    releaseAllInputs();
  });

  socket.on('input:event', (event: InputEvent) => {
    if (sessionActive) applyInputEvent(event);
  });

  // Señalización WebRTC (disponible para transporte nativo de baja latencia)
  socket.on('signal', (payload: SignalPayload) => {
    logger.info('Mensaje de señalización recibido', { kind: payload?.kind });
  });

  socket.on('disconnect', (reason: string) => {
    logger.warn('Desconectado del backend', { reason });
    sessionActive = false;
    streamer.stop();
    releaseAllInputs();
  });

  socket.on('connect_error', (err: Error) => {
    logger.error('Error de conexión con el backend', { err: err.message });
  });
}

function shutdown(signal: string): void {
  logger.info(`Señal ${signal} recibida, apagando agente...`);
  sunshineMonitor.stop();
  streamer.stop();
  releaseAllInputs();
  socket?.disconnect();
  process.exit(0);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('unhandledRejection', (reason) => {
  logger.error('unhandledRejection', { reason: String(reason) });
});
process.on('uncaughtException', (err) => {
  logger.error('uncaughtException', { err: err.message });
});

sunshineMonitor.start();
connect();
logger.info('Agente Cloud Gaming iniciado');
