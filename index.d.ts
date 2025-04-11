declare module 'tristans-file-streamer' {
  import { EventSubscription } from 'react-native';

  export interface TransferOptions {
    url: string;
    path: string;
    method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
    headers?: Record<string, string>;
    customTransferId?: string;
    appGroup?: string;
    notification?: {
      enabled: boolean;
      autoClear: boolean;
      onProgressTitle?: string;
      onProgressMessage?: string;
      onCompleteTitle?: string;
      onCompleteMessage?: string;
      onErrorTitle?: string;
      onErrorMessage?: string;
      onCancelledTitle?: string;
      onCancelledMessage?: string;
    };
    encryption?: {
      key: string;
      nonce: string;
    };
  }

  export interface ProgressEvent {
    id: string;
    progress: number;
  }

  export interface CompletedEvent {
    id: string;
    responseCode: number;
    responseBody: string;
  }

  export interface ErrorEvent {
    id: string;
    error: string;
  }

  export interface CancelledEvent {
    id: string;
  }

  export type FileStreamerEvent =
    | ProgressEvent
    | CompletedEvent
    | ErrorEvent
    | CancelledEvent;

  export interface FileInfo {
    name: string;
    exists: boolean;
    size?: number;
    extension?: string;
    mimeType?: string;
  }

  export default class FileStreamer {
    static startUpload(options: TransferOptions): Promise<string>;
    static startDownload(options: TransferOptions): Promise<string>;
    static cancelUpload(transferId: string): Promise<boolean>;
    static cancelDownload(transferId: string): Promise<boolean>;
    static getFileInfo(path: string): Promise<FileInfo>;
    static addListener<T extends FileStreamerEvent>(
      event: T extends ProgressEvent
        ? 'TristanFileStreamer-progress'
        : T extends CompletedEvent
        ? 'TristanFileStreamer-completed'
        : T extends ErrorEvent
        ? 'TristanFileStreamer-error'
        : T extends CancelledEvent
        ? 'TristanFileStreamer-cancelled'
        : never,
      transferId: string | null,
      callback: (data: T) => void,
    ): EventSubscription;
  }
}
