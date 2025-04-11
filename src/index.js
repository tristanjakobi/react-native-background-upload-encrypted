// @flow
/**
 * Handles HTTP background file transfers (upload and download) from an iOS or Android device.
 */
import {
  NativeModules,
  DeviceEventEmitter,
  NativeEventEmitter,
  Platform,
} from 'react-native';

/**
 * @typedef {'progress' | 'error' | 'completed' | 'cancelled'} UploadEvent
 */

/**
 * @typedef {Object} NotificationArgs
 * @property {boolean} enabled
 */

/**
 * @typedef {Object} StartUploadArgs
 * @property {string} url
 * @property {string} path
 * @property {'PUT' | 'POST'} [method]
 * @property {'raw' | 'multipart'} [type]
 * @property {string} [field]
 * @property {string} [customUploadId]
 * @property {Object.<string, string>} [parameters]
 * @property {Object} [headers]
 * @property {NotificationArgs} [notification]
 * @property {Object} [encryption]
 * @property {string} encryption.key
 * @property {string} encryption.nonce
 */

const { TristanFileStreamer } = NativeModules;

const eventEmitter = new NativeEventEmitter(TristanFileStreamer);

const FileStreamer = {
  startUpload(options) {
    return TristanFileStreamer.startUpload(options);
  },

  startDownload(options) {
    return TristanFileStreamer.startDownload(options);
  },

  cancelUpload(transferId) {
    return TristanFileStreamer.cancelUpload(transferId);
  },

  cancelDownload(transferId) {
    return TristanFileStreamer.cancelDownload(transferId);
  },

  getFileInfo(path) {
    return TristanFileStreamer.getFileInfo(path);
  },

  addListener(eventType, transferId, listener) {
    return eventEmitter.addListener(eventType, (data) => {
      if (transferId && data.id !== transferId) {
        return;
      }

      // Type narrow based on event type
      switch (eventType) {
        case 'progress':
          if ('progress' in data) {
            listener(data);
          }
          break;
        case 'error':
          if ('error' in data) {
            listener(data);
          }
          break;
        case 'completed':
          if ('responseCode' in data && 'responseBody' in data) {
            listener(data);
          }
          break;
        case 'cancelled':
          if ('id' in data) {
            listener(data);
          }
          break;
      }
    });
  },

  // Android only
  getUploads() {
    if (Platform.OS === 'android') {
      return TristanFileStreamer.getUploads();
    }
    return Promise.resolve([]);
  },

  // Android only
  getDownloads() {
    if (Platform.OS === 'android') {
      return TristanFileStreamer.getDownloads();
    }
    return Promise.resolve([]);
  },
};

export default FileStreamer;
