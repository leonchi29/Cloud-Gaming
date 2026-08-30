import { Server, Socket } from 'socket.io';
import { SessionManager } from './sessionManager';
import { logger } from './logger';
import type { HostStatus, InputEvent, SignalPayload, StreamFrame } from './types';

interface RegisterAgentPayload {
  token: string;
}

interface SunshineStatusPayload {
  running: boolean;
}

export function registerSocketHandlers(
  io: Server,
  sessions: SessionManager,
  agentToken: string,
): void {
  const broadcastStatus = (): void => {
    const status: HostStatus = {
      online: sessions.isHostOnline(),
      sunshineRunning: sessions.isSunshineRunning(),
      sessionActive: sessions.hasActiveSession(),
    };
    io.emit('host:status', status);
  };

  const notifyAgent = (event: string, payload?: unknown): void => {
    const agentId = sessions.getAgentSocketId();
    if (agentId) io.to(agentId).emit(event, payload);
  };

  io.on('connection', (socket: Socket) => {
    logger.info('Socket conectado', { id: socket.id });

    // Estado inicial para cualquier cliente nuevo
    socket.emit('host:status', {
      online: sessions.isHostOnline(),
      sunshineRunning: sessions.isSunshineRunning(),
      sessionActive: sessions.hasActiveSession(),
    } satisfies HostStatus);

    // ---------- AGENTE ----------

    socket.on('agent:register', (payload: RegisterAgentPayload) => {
      if (!payload || payload.token !== agentToken) {
        logger.warn('Registro de agente rechazado: token inválido', { id: socket.id });
        socket.emit('agent:rejected', { reason: 'invalid_token' });
        socket.disconnect(true);
        return;
      }
      // Solo un agente: reemplaza cualquier registro anterior
      const previous = sessions.getAgentSocketId();
      if (previous && previous !== socket.id) {
        sessions.unregisterAgent(previous);
        io.sockets.sockets.get(previous)?.disconnect(true);
      }
      sessions.registerAgent(socket.id);
      socket.data.role = 'agent';
      socket.emit('agent:registered');
      broadcastStatus();
    });

    socket.on('agent:sunshine-status', (payload: SunshineStatusPayload) => {
      if (socket.data.role !== 'agent') return;
      sessions.setSunshineRunning(Boolean(payload?.running));
      broadcastStatus();
    });

    // Agente → frames de vídeo hacia el cliente de la sesión
    socket.on('stream:frame', (frame: StreamFrame) => {
      if (socket.data.role !== 'agent') return;
      const clientId = sessions.getActiveClientId();
      if (clientId) io.to(clientId).emit('stream:frame', frame);
    });

    // ---------- CLIENTE (NAVEGADOR) ----------

    socket.on('session:request', () => {
      if (!sessions.isHostOnline()) {
        socket.emit('session:denied', { reason: 'host_offline' });
        return;
      }
      const granted = sessions.openSession(socket.id);
      if (!granted) {
        socket.emit('session:denied', { reason: 'session_busy' });
        return;
      }
      socket.data.role = 'client';
      socket.emit('session:granted');
      notifyAgent('session:started', { clientId: socket.id });
      broadcastStatus();
    });

    socket.on('session:end', () => {
      if (sessions.closeSession(socket.id)) {
        notifyAgent('session:ended', { clientId: socket.id });
        socket.emit('session:ended');
        broadcastStatus();
      }
    });

    // Cliente → eventos de entrada hacia el agente
    socket.on('input:event', (event: InputEvent) => {
      if (sessions.getActiveClientId() !== socket.id) return;
      notifyAgent('input:event', event);
    });

    // ---------- SEÑALIZACIÓN WEBRTC ----------

    // Relay genérico de señalización entre el cliente activo y el agente.
    socket.on('signal', (payload: SignalPayload) => {
      if (!payload || !payload.kind) return;
      if (socket.data.role === 'agent') {
        const clientId = sessions.getActiveClientId();
        if (clientId) io.to(clientId).emit('signal', payload);
      } else if (sessions.getActiveClientId() === socket.id) {
        notifyAgent('signal', payload);
      }
    });

    // ---------- DESCONEXIÓN ----------

    socket.on('disconnect', (reason: string) => {
      logger.info('Socket desconectado', { id: socket.id, reason });
      if (socket.data.role === 'agent') {
        sessions.unregisterAgent(socket.id);
        const clientId = sessions.getActiveClientId();
        if (clientId) {
          io.to(clientId).emit('session:ended', { reason: 'host_disconnected' });
          sessions.closeSession(clientId);
        }
      } else if (sessions.closeSession(socket.id)) {
        notifyAgent('session:ended', { clientId: socket.id });
      }
      broadcastStatus();
    });
  });
}
