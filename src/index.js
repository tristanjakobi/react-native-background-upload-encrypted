// @flow
/**
 * Handles HTTP background file uploads from an iOS or Android device.
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

  cancelUpload(uploadId) {
    return TristanFileStreamer.cancelUpload(uploadId);
  },

  cancelDownload(downloadId) {
    return TristanFileStreamer.cancelDownload(downloadId);
  },

  getFileInfo(path) {
    return TristanFileStreamer.getFileInfo(path);
  },

  addListener(eventType, uploadId, listener) {
    return eventEmitter.addListener(eventType, (data) => {
      if (uploadId && data.id !== uploadId) {
        return;
      }
      listener(data);
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
