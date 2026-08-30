import { useCallback, useEffect, useRef, useState } from 'react';
import { getSocket } from './socket';
import { StreamViewer } from './components/StreamViewer';
import type { HostStatus, SessionState } from './types';

export default function App(): JSX.Element {
  const [socketConnected, setSocketConnected] = useState(false);
  const [hostStatus, setHostStatus] = useState<HostStatus>({
    online: false,
    sunshineRunning: false,
    sessionActive: false,
  });
  const [sessionState, setSessionState] = useState<SessionState>('idle');
  const [deniedReason, setDeniedReason] = useState<string | null>(null);
  const sessionStateRef = useRef<SessionState>('idle');
  sessionStateRef.current = sessionState;

  const requestSession = useCallback(() => {
    setDeniedReason(null);
    setSessionState('connecting');
    getSocket().emit('session:request');
  }, []);

  const endSession = useCallback(() => {
    getSocket().emit('session:end');
    setSessionState('idle');
  }, []);

  useEffect(() => {
    const socket = getSocket();

    const onConnect = (): void => {
      setSocketConnected(true);
      // Reconexión automática de la sesión si estaba activa
      if (sessionStateRef.current === 'connected' || sessionStateRef.current === 'connecting') {
        socket.emit('session:request');
      }
    };
    const onDisconnect = (): void => setSocketConnected(false);
    const onHostStatus = (status: HostStatus): void => setHostStatus(status);
    const onGranted = (): void => setSessionState('connected');
    const onDenied = (payload: { reason: string }): void => {
      setSessionState('denied');
      setDeniedReason(payload.reason);
    };
    const onEnded = (): void => {
      setSessionState('ended');
    };

    socket.on('connect', onConnect);
    socket.on('disconnect', onDisconnect);
    socket.on('host:status', onHostStatus);
    socket.on('session:granted', onGranted);
    socket.on('session:denied', onDenied);
    socket.on('session:ended', onEnded);
    setSocketConnected(socket.connected);

    return () => {
      socket.off('connect', onConnect);
      socket.off('disconnect', onDisconnect);
      socket.off('host:status', onHostStatus);
      socket.off('session:granted', onGranted);
      socket.off('session:denied', onDenied);
      socket.off('session:ended', onEnded);
    };
  }, []);

  const hostOnline = hostStatus.online;
  const connected = sessionState === 'connected';

  return (
    <div className="app">
      <header className="header">
        <h1>Cloud Gaming</h1>
        <div className="indicators">
          <span className={`badge ${socketConnected ? 'badge-green' : 'badge-red'}`}>
            Servidor: {socketConnected ? 'conectado' : 'desconectado'}
          </span>
          <span className={`badge ${hostOnline ? 'badge-green' : 'badge-gray'}`}>
            Host: {hostOnline ? 'online' : 'offline'}
          </span>
          {hostOnline && (
            <span className={`badge ${hostStatus.sunshineRunning ? 'badge-green' : 'badge-yellow'}`}>
              Sunshine: {hostStatus.sunshineRunning ? 'activo' : 'detenido'}
            </span>
          )}
          {connected && <span className="badge badge-blue">Sesión activa</span>}
        </div>
      </header>

      <main className="main">
        {!connected ? (
          <div className="panel">
            {sessionState === 'ended' && (
              <p className="notice">La sesión remota ha finalizado.</p>
            )}
            {sessionState === 'denied' && (
              <p className="notice notice-error">
                {deniedReason === 'host_offline'
                  ? 'El host está offline. Enciende el PC y espera a que el agente se conecte.'
                  : 'Ya hay una sesión remota activa. Solo se permite una sesión simultánea.'}
              </p>
            )}
            <button
              className="connect-button"
              disabled={!socketConnected || !hostOnline || sessionState === 'connecting'}
              onClick={requestSession}
            >
              {sessionState === 'connecting' ? 'Conectando…' : 'Conectar'}
            </button>
            {!hostOnline && (
              <p className="hint">Esperando a que el host Windows se conecte…</p>
            )}
          </div>
        ) : (
          <StreamViewer onDisconnect={endSession} />
        )}
      </main>
    </div>
  );
}
