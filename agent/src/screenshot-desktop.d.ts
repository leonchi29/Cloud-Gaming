/**
 * Declaración de tipos local para screenshot-desktop.
 * Cubre únicamente la API utilizada por el agente.
 */
declare module 'screenshot-desktop' {
  export interface ScreenshotOptions {
    format?: 'png' | 'jpg';
    screen?: number | string;
    filename?: string;
  }

  /** Captura la pantalla y devuelve un Buffer con la imagen. */
  function screenshot(options?: ScreenshotOptions): Promise<Buffer>;

  export default screenshot;
}
