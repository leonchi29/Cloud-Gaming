export type InputEventType =
  | 'mousemove'
  | 'mousedown'
  | 'mouseup'
  | 'wheel'
  | 'keydown'
  | 'keyup';

export interface MouseInputEvent {
  type: 'mousemove' | 'mousedown' | 'mouseup';
  x: number;
  y: number;
  button: 'left' | 'middle' | 'right';
}

export interface WheelInputEvent {
  type: 'wheel';
  deltaX: number;
  deltaY: number;
}

export interface KeyboardInputEvent {
  type: 'keydown' | 'keyup';
  key: string;
  code: string;
}

export type InputEvent = MouseInputEvent | WheelInputEvent | KeyboardInputEvent;

export interface StreamFrame {
  data: string;
  format: 'jpeg' | 'png';
  width: number;
  height: number;
  timestamp: number;
}

export interface HostStatus {
  online: boolean;
  sunshineRunning: boolean;
  sessionActive: boolean;
}

export type SessionState =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'denied'
  | 'ended';

export interface SignalPayload {
  kind: 'offer' | 'answer' | 'ice';
  data: unknown;
}
