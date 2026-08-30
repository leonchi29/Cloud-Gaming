import { useCallback, useEffect, useRef, useState } from 'react';
import { getSocket } from '../socket';
import type { InputEvent, StreamFrame } from '../types';

interface Props {
  onDisconnect: () => void;
}

const BUTTON_MAP: Record<number, 'left' | 'middle' | 'right'> = {
  0: 'left',
  1: 'middle',
  2: 'right',
};

export function StreamViewer({ onDisconnect }: Props): JSX.Element {
  const imgRef = useRef<HTMLImageElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [frameSize, setFrameSize] = useState<{ width: number; height: number } | null>(null);
  const [lastFrameAt, setLastFrameAt] = useState<number>(0);
  const frameUrlRef = useRef<string | null>(null);

  // Recepción de frames
  useEffect(() => {
    const socket = getSocket();
    const onFrame = (frame: StreamFrame): void => {
      if (!imgRef.current) return;
      const src = frame.data.startsWith('data:')
        ? frame.data
        : `data:image/${frame.format};base64,${frame.data}`;
      if (frameUrlRef.current) URL.revokeObjectURL(frameUrlRef.current);
      imgRef.current.src = src;
      setFrameSize({ width: frame.width, height: frame.height });
      setLastFrameAt(Date.now());
    };
    socket.on('stream:frame', onFrame);
    return () => {
      socket.off('stream:frame', onFrame);
    };
  }, []);

  const sendInput = useCallback((event: InputEvent): void => {
    getSocket().emit('input:event', event);
  }, []);

  const normalizedCoords = useCallback((e: React.MouseEvent): { x: number; y: number } => {
    const img = imgRef.current;
    if (!img) return { x: 0, y: 0 };
    const rect = img.getBoundingClientRect();
    const x = Math.min(Math.max((e.clientX - rect.left) / rect.width, 0), 1);
    const y = Math.min(Math.max((e.clientY - rect.top) / rect.height, 0), 1);
    return { x, y };
  }, []);

  const onMouseMove = useCallback(
    (e: React.MouseEvent): void => {
      const { x, y } = normalizedCoords(e);
      sendInput({ type: 'mousemove', x, y, button: 'left' });
    },
    [normalizedCoords, sendInput],
  );

  const onMouseDown = useCallback(
    (e: React.MouseEvent): void => {
      e.preventDefault();
      const { x, y } = normalizedCoords(e);
      sendInput({ type: 'mousedown', x, y, button: BUTTON_MAP[e.button] ?? 'left' });
    },
    [normalizedCoords, sendInput],
  );

  const onMouseUp = useCallback(
    (e: React.MouseEvent): void => {
      e.preventDefault();
      const { x, y } = normalizedCoords(e);
      sendInput({ type: 'mouseup', x, y, button: BUTTON_MAP[e.button] ?? 'left' });
    },
    [normalizedCoords, sendInput],
  );

  const onWheel = useCallback(
    (e: React.WheelEvent): void => {
      sendInput({ type: 'wheel', deltaX: e.deltaX, deltaY: e.deltaY });
    },
    [sendInput],
  );

  // Teclado: capturar a nivel de ventana mientras la sesión está activa
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent): void => {
      e.preventDefault();
      sendInput({ type: 'keydown', key: e.key, code: e.code });
    };
    const onKeyUp = (e: KeyboardEvent): void => {
      e.preventDefault();
      sendInput({ type: 'keyup', key: e.key, code: e.code });
    };
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
    };
  }, [sendInput]);

  const toggleFullscreen = useCallback((): void => {
    const container = containerRef.current;
    if (!container) return;
    if (document.fullscreenElement) {
      void document.exitFullscreen();
    } else {
      void container.requestFullscreen();
    }
  }, []);

  const streaming = lastFrameAt > 0 && Date.now() - lastFrameAt < 5000;

  return (
    <div className="stream-container" ref={containerRef}>
      <div className="stream-toolbar">
        <span className={`badge ${streaming ? 'badge-green' : 'badge-yellow'}`}>
          {streaming ? 'Streaming activo' : 'Esperando vídeo…'}
        </span>
        {frameSize && (
          <span className="badge badge-gray">
            {frameSize.width}×{frameSize.height}
          </span>
        )}
        <div className="toolbar-actions">
          <button className="tool-button" onClick={toggleFullscreen}>
            Pantalla completa
          </button>
          <button className="tool-button tool-button-danger" onClick={onDisconnect}>
            Desconectar
          </button>
        </div>
      </div>
      <div className="stream-area">
        <img
          ref={imgRef}
          className="stream-video"
          alt="Escritorio remoto"
          draggable={false}
          onMouseMove={onMouseMove}
          onMouseDown={onMouseDown}
          onMouseUp={onMouseUp}
          onWheel={onWheel}
          onContextMenu={(e) => e.preventDefault()}
        />
        {!streaming && (
          <div className="stream-placeholder">
            <p>Conectando con el host…</p>
          </div>
        )}
      </div>
    </div>
  );
}
