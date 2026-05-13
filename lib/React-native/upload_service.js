import RNFS from 'react-native-fs';
import ReactNativeBlobUtil from 'react-native-blob-util';












export const doHttpRequest = async (config) => {
    const {
      endpoint,
      method = 'GET',
      body = null,
      contentType = 'application/json',
      requiresAuth = true,
      customHeaders = {},
      responseType = RESPONSE_TYPES.JSON,
      onProgress = null,
      range = null,
      customUrl = null,
    } = config;
  
    // Validate config
    if (!endpoint && !customUrl) {
      throw new Error('Either endpoint or customUrl must be provided');
    }
  
    const maxAttempts = requiresAuth ? 2 : 1;
    let attempt = 0;
    let currentToken = requiresAuth ? await getAccessToken() : null;
    let lastError = null;
  
    const requestUrl = customUrl
      ? customUrl
      : endpoint && endpoint.startsWith('http')
        ? endpoint
        : `${API_BASE_URL}/${endpoint || ''}`;
  
        console.log("WE CALLED THIS : : : ",requestUrl);
  
    while (attempt < maxAttempts) {
      try {
        const responseData = await performRequest({
          endpoint,
          method,
          body,
          contentType,
          requiresAuth,
          customHeaders,
          responseType,
          onProgress,
          range,
          accessToken: currentToken,
          requestUrl,
        });
  
        maybeShowSuccessMessage(endpoint, responseData);
     
        return responseData;
      } catch (error) {
        lastError = error;
  
        const canRefreshToken =
          requiresAuth && attempt === 0 && shouldAttemptTokenRefresh(error);
  
        if (canRefreshToken) {
          
          try {
            const newToken = await getRefreshToken();
            if (newToken) {
          
              currentToken = newToken;
          
              attempt += 1;
              continue;
            } else {
              
              throw new Error('Failed to refresh access token: Empty token received');
            }
          } catch (refreshError) {
            // Handle refresh token errors gracefully
            const refreshStatus = refreshError.response?.status || refreshError.status;
            if (refreshStatus === 401 || refreshStatus === 403) {
  
              const expiredTokenError = new Error('Session expired. Please login again.');
              expiredTokenError.status = refreshStatus;
              expiredTokenError.isTokenExpired = true;
              lastError = expiredTokenError;
            } else {
              console.error('Failed to refresh token:', refreshError.message);
              lastError = refreshError;
            }
          }
        }
  
        break;
      }
    }
  
    const errorMessage =
      (lastError && lastError.message) ||
      (typeof lastError === 'string' ? lastError : 'Something went wrong. Please try again.');
  
    const errorStatus = lastError?.status || lastError?.response?.status;
    const isServerError = errorStatus >= 500 && errorStatus < 600;
    const isClientError = errorStatus >= 400 && errorStatus < 500;
    const isTokenExpired = lastError?.isTokenExpired === true;
  
    
  
    
    if (isClientError && !isTokenExpired) {
     
    } else if (isServerError) {
      // Log server errors but don't show snackbar
      console.warn('⚠️ Server error (5xx) - Service temporarily unavailable');
    } else if (isTokenExpired) {
      // Token expiration will be handled by calling code (logout)
      console.warn('⚠️ Token expired - User will be logged out');
    }
  
    if (lastError instanceof Error) {
      throw lastError;
    }
  
    throw new Error(errorMessage);
  };


















export const DEFAULT_PART_SIZE = 10 * 1024 * 1024;
export const API_BASE_URL = 'https://stolityapi.infomanav.in/api/aws';
const canceledFileKeys = new Set();
const activeMultipartByFileKey = new Map();

const getFileKey = (file) => file?.uri || file?.name;

const isCancelError = (error) => error?.code === 'UPLOAD_CANCELLED';

const createCancelError = (fileKey) => {
	const error = new Error('Upload cancelled');
	error.code = 'UPLOAD_CANCELLED';
	error.fileKey = fileKey;
	return error;
};


// Yield to the UI thread so touch events, animations, and navigation stay responsive
const yieldToUI = () => new Promise(resolve => setTimeout(resolve, 0));

const normalizePath = (value) => (typeof value === 'string' ? value.replace(/^\/+|\/+$/g, '') : '');

const resolveFolderPath = (folderPath, shared) => {
	const cleanFolder = normalizePath(folderPath);
	const cleanShared = typeof shared === 'string' ? normalizePath(shared) : '';

	if (!cleanFolder) {
		return '';
	}

	if (cleanShared && cleanFolder === cleanShared) {
		return '';
	}

	if (cleanShared && cleanFolder.startsWith(`${cleanShared}/`)) {
		return cleanFolder.substring(cleanShared.length + 1);
	}

	return cleanFolder;
};

const normalizeFilePath = (filePath) => {
	if (!filePath) return '';
	// Keep content:// URIs as-is for Android
	if (filePath.startsWith('content://')) {
		return filePath;
	}

	const withoutScheme = filePath.startsWith('file://')
		? filePath.replace('file://', '')
		: filePath;

	try {
		return decodeURI(withoutScheme);
	} catch (_decodeError) {
		return withoutScheme;
	}
};

const sanitizeFileName = (value, fallback = 'file') => {
	if (typeof value !== 'string' || !value.trim()) return fallback;
	return value.replace(/[\\/:*?"<>|]+/g, '_').trim() || fallback;
};

const shouldCopyToStablePath = (sourceUri) => {
	if (typeof sourceUri !== 'string' || !sourceUri) return false;
	if (sourceUri.startsWith('content://')) return true;

	const normalizedSource = normalizeFilePath(sourceUri);
	return normalizedSource.includes('/tmp/') || normalizedSource.includes('/Inbox/');
};

const copyFileToStablePath = async (sourceUri, destinationPath) => {
	const normalizedSource = normalizeFilePath(sourceUri);
	try {
		await RNFS.copyFile(normalizedSource, destinationPath);
		await RNFS.stat(destinationPath);
		return true;
	} catch (_copyError) {
		try {
			await ReactNativeBlobUtil.fs.cp(normalizedSource, destinationPath);
			await RNFS.stat(destinationPath);
			return true;
		} catch (_blobCopyError) {
			return false;
		}
	}
};

export const ensureStablePathsForUpload = async (files = []) => {

	if (!Array.isArray(files) || files.length === 0) {
		return { files: [], copiedPaths: [], workingDir: null };
	}

	const workingDir = `${RNFS.CachesDirectoryPath}/stolity_upload_${Date.now()}`;
	const copiedPaths = [];
	const stableFiles = [];
	let createdWorkingDir = false;

	for (let index = 0; index < files.length; index += 1) {
		const file = files[index] || {};
		const sourceUri = file.uri || file.path || '';
		const requiresStableCopy = shouldCopyToStablePath(sourceUri);

		if (!sourceUri || !requiresStableCopy) {
			stableFiles.push(file);
			continue;
		}

		if (!createdWorkingDir) {
			try {
				await RNFS.mkdir(workingDir);
				createdWorkingDir = true;
			} catch (_mkdirError) {
				stableFiles.push(file);
				continue;
			}
		}

		const fileName = sanitizeFileName(file.name, `upload_${index}`);
		const destinationPath = `${workingDir}/${Date.now()}_${index}_${fileName}`;
		const copied = await copyFileToStablePath(sourceUri, destinationPath);

		if (!copied) {
			stableFiles.push(file);
			continue;
		}

		copiedPaths.push(destinationPath);
		stableFiles.push({
			...file,
			uri: destinationPath,
			path: destinationPath,
			name: file.name || fileName,
		});
	}

	const finalWorkingDir = copiedPaths.length > 0 ? workingDir : null;
	if (!finalWorkingDir && createdWorkingDir) {
		try {
			await RNFS.unlink(workingDir);
		} catch (_cleanupError) {}
	}

	return {
		files: stableFiles,
		copiedPaths,
		workingDir: finalWorkingDir,
	};
};

const getFileSize = async (filePath) => {
	const cleanPath = normalizeFilePath(filePath);
	const stat = await RNFS.stat(cleanPath);
	return stat.size;
};

const splitFileIntoChunks = async (filePath, chunkSize) => {
	const fileSize = await getFileSize(filePath);
	const chunks = [];
	for (let start = 0; start < fileSize; start += chunkSize) {
		const end = Math.min(start + chunkSize, fileSize);
		chunks.push({ start, end, size: end - start });
	}
	return { chunks, fileSize };
};

const readFileChunk = async (filePath, start, end) => {
	const cleanPath = normalizeFilePath(filePath);
	const length = end - start;
	if (length <= 0) {
		throw new Error(`Invalid chunk range: start=${start}, end=${end}`);
	}
	const base64Data = await RNFS.read(cleanPath, length, start, 'base64');
	return Buffer.from(base64Data, 'base64');
};

const buildEndpoint = (base, { shared } = {}) => {
	const params = [];
	if (typeof shared === 'string' && shared.trim() !== '') {
		params.push(`shared=${encodeURIComponent(shared)}`);
	}
	return params.length ? `${base}?${params.join('&')}` : base;
};

export const startMultipartUpload = async ({ fileName, folderPath, visibility = 'private', shared = false }) => {
	const resolvedFolderPath = resolveFolderPath(folderPath, shared);
	const endpoint = buildEndpoint('start-multipart-upload', {
		shared,
	});

	const requestBody = {
		fileName,
		visibility,
	};

	// Add folderPath to body if present (backend expects it in body, not query params)
	if (resolvedFolderPath) {
		requestBody.folderPath = resolvedFolderPath;
	}

	const response = await doHttpRequest({
		endpoint,
		method: 'POST',
		body: requestBody,
	});

	return response;
};

export const uploadPart = async ({ uploadId, partNumber, key, chunk, fileType }) => {
	const endpoint = `upload-part?partNumber=${partNumber}&uploadId=${encodeURIComponent(uploadId)}&key=${encodeURIComponent(key)}`;

	return doHttpRequest({
		endpoint,
		method: 'POST',
		body: chunk,
		contentType: fileType || 'application/octet-stream',
	});
};

// Native upload part using ReactNativeBlobUtil — keeps file I/O off the JS thread
const uploadPartNative = async ({ uploadId, partNumber, key, base64Data, fileType }) => {
	const endpoint = `upload-part?partNumber=${partNumber}&uploadId=${encodeURIComponent(uploadId)}&key=${encodeURIComponent(key)}`;
	const url = `${API_BASE_URL}/${endpoint}`;
	const accessToken = await getAccessToken();

	const response = await ReactNativeBlobUtil.fetch(
		'POST',
		url,
		{
			'Content-Type': fileType || 'application/octet-stream',
			...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
		},
		base64Data, // ReactNativeBlobUtil handles base64 → binary natively
	);

	const status = response.info().status;
	if (status < 200 || status >= 300) {
		throw new Error(`Upload part failed with status ${status}`);
	}

	const json = response.json();
	return json;
};

export const completeMultipartUpload = async ({ key, uploadId, parts }) => {

	const response = await doHttpRequest({
		endpoint: 'complete-multipart-upload',
		method: 'POST',
		body: { key, uploadId, parts },
	});

	return response;
};

export const abortMultipartUpload = async ({ key, uploadId }) => {

	const response = await doHttpRequest({
		endpoint: 'abort-multipart-upload',
		method: 'POST',
		body: { key, uploadId },
	});

	return response;
};

export const abortUpload = async ({ key, uploadId }) => {
	try {
		await abortMultipartUpload({ key, uploadId });
		return { success: true };
	} catch (error) {
		return { success: false, error };
	}
};

export const cancelFileUpload = async (fileKey) => {
	if (!fileKey) return { success: false, reason: 'missing-file-key' };

	canceledFileKeys.add(fileKey);
	const activeUpload = activeMultipartByFileKey.get(fileKey);

	if (activeUpload?.key && activeUpload?.uploadId) {
		try {
			await abortMultipartUpload({ key: activeUpload.key, uploadId: activeUpload.uploadId });
			activeMultipartByFileKey.delete(fileKey);
			return { success: true, aborted: true };
		} catch (error) {
			return { success: false, aborted: false, error };
		}
	}

	return { success: true, aborted: false };
};

export const uploadFilesMultipart = async ({
	files,
	folderPath = '',
	visibility = 'private',
	shared = false,
	partSize = DEFAULT_PART_SIZE,
	onFileProgress,
}) => {

	if (!Array.isArray(files) || files.length === 0) {
		return [];
	}

	const results = [];
	for (const file of files) {
		const fileKey = getFileKey(file);
		const originalName = file?.name || 'file';
		const basename = originalName.replace(/^.*[\\/]/, '');
		let workingFilePath = file?.uri || file?.path || '';
		let uploadId = null;
		let key = null;
		const partsArray = [];

		try {
			if (fileKey && canceledFileKeys.has(fileKey)) {
				throw createCancelError(fileKey);
			}

			if (!workingFilePath) {
				throw new Error('Missing file path');
			}

			// Verify file is accessible before proceeding
			try {
				await RNFS.stat(normalizeFilePath(workingFilePath));
			} catch (statError) {
				throw new Error(`Cannot access file: ${statError.message}`);
			}

			const startResp = await startMultipartUpload({
				fileName: basename,
				folderPath,
				visibility,
				shared,
			});

			key = startResp?.key || startResp?.data?.key;
			uploadId = startResp?.uploadId || startResp?.data?.uploadId;

			if (!key || !uploadId) {
				throw new Error('Invalid start-multipart response');
			}

			if (fileKey) {
				activeMultipartByFileKey.set(fileKey, { key, uploadId });
			}

			if (fileKey && canceledFileKeys.has(fileKey)) {
				throw createCancelError(fileKey);
			}

			const { chunks, fileSize } = await splitFileIntoChunks(workingFilePath, partSize);
			const totalSize = fileSize || file?.size || 0;
			const totalChunks = chunks.length;
			let lastProgressUpdate = 0; // Throttle progress updates to max ~250ms apart

			// Show initial progress (1%) when upload starts
			if (typeof onFileProgress === 'function') {
				onFileProgress(file, 1);
			}

			for (let partIndex = 0; partIndex < chunks.length; partIndex += 1) {
				if (fileKey && canceledFileKeys.has(fileKey)) {
					throw createCancelError(fileKey);
				}

				// Yield to UI thread before heavy work — keeps touches/navigation responsive
				await yieldToUI();

				if (fileKey && canceledFileKeys.has(fileKey)) {
					throw createCancelError(fileKey);
				}

				const chunkMeta = chunks[partIndex];
				const partNumber = partIndex + 1;

				// Read chunk as base64 (stays as string, no Buffer decode on JS thread)
				const cleanPath = normalizeFilePath(workingFilePath);
				const chunkLength = chunkMeta.end - chunkMeta.start;
				const base64Data = await RNFS.read(cleanPath, chunkLength, chunkMeta.start, 'base64');

				if (fileKey && canceledFileKeys.has(fileKey)) {
					throw createCancelError(fileKey);
				}

				// Yield again after file read before network call
				await yieldToUI();

				// Upload using native ReactNativeBlobUtil — no JS thread Buffer processing
				const partResp = await uploadPartNative({
					partNumber,
					uploadId,
					key,
					base64Data,
					fileType: 'application/octet-stream',
				});

				const etag = partResp?.ETag || partResp?.etag || partResp?.data?.ETag || partResp?.data?.etag;
				if (!etag) {
					throw new Error('No ETag returned for uploaded part');
				}

				partsArray.push({ ETag: etag, PartNumber: partNumber });

				// Throttled progress update — max once per 250ms to avoid excessive re-renders
				if (typeof onFileProgress === 'function' && totalChunks) {
					const now = Date.now();
					const completedChunks = partIndex + 1;
					const isLastChunk = completedChunks === totalChunks;
					if (isLastChunk || now - lastProgressUpdate >= 250) {
						lastProgressUpdate = now;
						const progress = Math.round((completedChunks / totalChunks) * 100);
						// Clamp to 1-99 during upload, 100 only when complete
						const clampedProgress = Math.min(99, Math.max(1, progress));
						onFileProgress(file, clampedProgress);
					}
				}
			}

			if (fileKey && canceledFileKeys.has(fileKey)) {
				throw createCancelError(fileKey);
			}

			await completeMultipartUpload({ key, uploadId, parts: partsArray });
			
			// Set final progress to 100%
			if (typeof onFileProgress === 'function') {
				onFileProgress(file, 100);
			}
			
			results.push({ file, status: 'fulfilled', value: 'success' });
		} catch (error) {
			// If cancellation was requested while a part request was in-flight,
			// treat any resulting transport/server error as a cancellation.
			if (fileKey && canceledFileKeys.has(fileKey)) {
				activeMultipartByFileKey.delete(fileKey);
				canceledFileKeys.delete(fileKey);
				results.push({ file, status: 'cancelled', reason: createCancelError(fileKey) });
				continue;
			}

			if (isCancelError(error)) {
				if (fileKey) {
					activeMultipartByFileKey.delete(fileKey);
					canceledFileKeys.delete(fileKey);
				}
				results.push({ file, status: 'cancelled', reason: error });
				continue;
			}

			// Abort the multipart upload if it was started
			if (key && uploadId) {
				try {
					await abortMultipartUpload({ key, uploadId });
				} catch (abortError) {
				}
			}
			results.push({ file, status: 'rejected', reason: error });
		} finally {
			if (fileKey) {
				activeMultipartByFileKey.delete(fileKey);
			}
		}
	}

	return results;
};
