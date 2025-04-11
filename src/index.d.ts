declare module 'tristans-file-streamer' {
  export interface FileInfo {
    name: string;
    exists: boolean;
    size?: number;
    extension?: string;
    mimeType?: string;
  }

  export interface UploadOptions {
    url: string;
    path: string;
    method?: string;
    type?: 'raw' | 'multipart';
    customUploadId?: string;
    headers?: Record<string, string>;
    field?: string;
    parameters?: Record<string, string>;
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
    useUtf8Charset?: boolean;
    appGroup?: string;
  }

  export interface DownloadOptions {
    url: string;
    path: string;
    method?: string;
    headers?: Record<string, string>;
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

  export type UploadEvent = 'progress' | 'error' | 'completed' | 'cancelled';
  export type DownloadEvent = 'progress' | 'error' | 'completed' | 'cancelled';

  const FileStreamer: {
    startUpload(options: UploadOptions): Promise<string>;
    startDownload(options: DownloadOptions): Promise<string>;
    cancelUpload(uploadId: string): Promise<boolean>;
    cancelDownload(downloadId: string): Promise<boolean>;
    getFileInfo(path: string): Promise<FileInfo>;
    addListener(
      eventType: UploadEvent | DownloadEvent,
      uploadId: string,
      listener: (
        data: ProgressEvent | ErrorEvent | CompletedEvent | CancelledEvent,
      ) => void,
    ): { remove: () => void };
    getUploads(): Promise<Array<{ id: string; state: string }>>;
    getDownloads(): Promise<Array<{ id: string; state: string }>>;
  };

  export default FileStreamer;
}
