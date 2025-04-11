declare module 'tristans-file-streamer' {
  export interface FileInfo {
    name: string;
    exists: boolean;
    size?: number;
    extension?: string;
    mimeType?: string;
  }

  export interface TransferOptions {
    url: string;
    path: string;
    method?: string;
    headers?: Record<string, string>;
    customTransferId?: string;
    notification?: {
      enabled?: boolean;
      autoClear?: boolean;
      notificationChannel?: string;
      enableRingTone?: boolean;
      onProgressTitle?: string;
      onProgressMessage?: string;
      onCompleteTitle?: string;
      onCompleteMessage?: string;
      onErrorTitle?: string;
      onErrorMessage?: string;
      onCancelledTitle?: string;
      onCancelledMessage?: string;
    };
    appGroup?: string;
  }

  export interface UploadOptions extends TransferOptions {
    useUtf8Charset?: boolean;
  }

  export interface DownloadOptions extends TransferOptions {
    // Add any download-specific options here
  }

  export interface ProgressEvent {
    id: string;
    progress: number;
  }

  export interface ErrorEvent {
    id: string;
    error: string;
  }

  export interface CompletedEvent {
    id: string;
    responseCode: number;
    responseBody: string;
  }

  export interface CancelledEvent {
    id: string;
  }

  export type TransferEvent = 'progress' | 'error' | 'completed' | 'cancelled';

  const FileStreamer: {
    startUpload(options: UploadOptions): Promise<string>;
    startDownload(options: DownloadOptions): Promise<string>;
    cancelUpload(transferId: string): Promise<boolean>;
    cancelDownload(transferId: string): Promise<boolean>;
    getFileInfo(path: string): Promise<FileInfo>;
    addListener(
      eventType: TransferEvent,
      transferId: string,
      listener: (
        data: ProgressEvent | ErrorEvent | CompletedEvent | CancelledEvent,
      ) => void,
    ): { remove: () => void };
    getUploads(): Promise<Array<{ id: string; state: string }>>;
    getDownloads(): Promise<Array<{ id: string; state: string }>>;
  };

  export default FileStreamer;
}
