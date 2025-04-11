// @flow
/**
 * Handles HTTP background file uploads from an iOS or Android device.
 */
import { NativeModules, DeviceEventEmitter } from 'react-native';

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

const NativeModule =
  NativeModules.VydiaRNFileUploader || NativeModules.RNFileUploader;

const eventPrefix = 'RNFileUploader-';

// iOS event registration (required for DeviceEventEmitter)
if (NativeModules.VydiaRNFileUploader) {
  NativeModule.addListener(eventPrefix + 'progress');
  NativeModule.addListener(eventPrefix + 'error');
  NativeModule.addListener(eventPrefix + 'cancelled');
  NativeModule.addListener(eventPrefix + 'completed');
}

/**
 * Gets file information for the path specified.
 * @param {string} path
 * @returns {Promise<Object>}
 */
export const getFileInfo = (path) => {
  return NativeModule.getFileInfo(path).then((data) => {
    if (data.size) {
      data.size = +data.size; // Convert to number (Android returns string)
    }
    return data;
  });
};

/**
 * Starts uploading a file to an HTTP endpoint.
 * @param {StartUploadArgs} options
 * @returns {Promise<string>}
 */
export const startUpload = (options) => NativeModule.startUpload(options);

/**
 * Cancels an active upload.
 * @param {string} cancelUploadId
 * @returns {Promise<boolean>}
 */
export const cancelUpload = (cancelUploadId) => {
  if (typeof cancelUploadId !== 'string') {
    return Promise.reject(new Error('Upload ID must be a string'));
  }
  return NativeModule.cancelUpload(cancelUploadId);
};

/**
 * Adds an event listener for a specific upload event.
 * @param {UploadEvent} eventType
 * @param {string} uploadId
 * @param {Function} listener
 */
export const addListener = (eventType, uploadId, listener) => {
  return DeviceEventEmitter.addListener(eventPrefix + eventType, (data) => {
    if (!uploadId || !data || !data.id || data.id === uploadId) {
      listener(data);
    }
  });
};

/**
 * Optional helper: Encrypt-aware upload wrapper.
 * @param {StartUploadArgs & { encryption: { key: string, nonce: string } }} options
 */
export const startEncryptedUpload = ({ key, nonce, ...uploadOptions }) => {
  return startUpload({
    ...uploadOptions,
    encryption: {
      key,
      nonce,
    },
  });
};

/**
 * Downloads an encrypted file and decrypts it using AES-256-CTR.
 * @param {{
 *   url: string,
 *   destination: string,
 *   headers?: Object.<string, string>,
 *   encryption: {
 *     key: string,     // base64
 *     nonce: string    // base64
 *   }
 * }} options
 * @returns {Promise<{ path: string }>}
 */
export const downloadAndDecrypt = (options) => {
  return NativeModule.downloadAndDecrypt(options);
};

export default {
  startUpload,
  startEncryptedUpload,
  cancelUpload,
  addListener,
  getFileInfo,
  downloadAndDecrypt,
};
