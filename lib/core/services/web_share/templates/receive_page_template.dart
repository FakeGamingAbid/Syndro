/// HTML template for the file receiving/upload page
class ReceivePageTemplate {
  static String generate() {
    return r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Syndro - Send Files</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 50%, #334155 100%);
      min-height: 100vh;
      color: #F8FAFC;
      padding: 20px;
    }
    .container { max-width: 500px; margin: 0 auto; }
    .header { text-align: center; padding: 30px 0; }
    .logo {
      width: 70px; height: 70px;
      background: rgba(99, 102, 241, 0.2);
      border-radius: 18px;
      display: flex; align-items: center; justify-content: center;
      margin: 0 auto 16px;
    }
    .logo svg { width: 36px; height: 36px; fill: #6366F1; }
    h1 { font-size: 24px; margin-bottom: 6px; }
    .subtitle { color: #94A3B8; font-size: 13px; }
    .upload-area {
      background: rgba(30, 41, 59, 0.8);
      border: 2px dashed #6366F1;
      border-radius: 16px;
      padding: 32px 24px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
      margin-top: 20px;
    }
    .upload-area:hover, .upload-area.dragover {
      background: rgba(99, 102, 241, 0.1);
      border-color: #818CF8;
    }
    .upload-area svg { width: 40px; height: 40px; fill: #6366F1; margin-bottom: 12px; }
    .upload-area p { margin-bottom: 6px; font-size: 15px; }
    .upload-area .hint { color: #94A3B8; font-size: 12px; }
    input[type="file"] { display: none; }
    .file-list {
      margin-top: 20px;
      background: rgba(30, 41, 59, 0.8);
      border-radius: 16px;
      overflow: hidden;
      display: none;
    }
    .file-list.has-files { display: block; }
    .file-list-header {
      padding: 14px 16px;
      background: rgba(99, 102, 241, 0.1);
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(148, 163, 184, 0.1);
    }
    .file-list-header h3 { font-size: 14px; font-weight: 600; }
    .file-count {
      background: #6366F1;
      color: white;
      padding: 2px 10px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 600;
    }
    .file-item {
      display: flex;
      align-items: center;
      padding: 12px 16px;
      border-bottom: 1px solid rgba(148, 163, 184, 0.1);
      transition: background 0.2s;
    }
    .file-item:last-child { border-bottom: none; }
    .file-item:hover { background: rgba(51, 65, 85, 0.5); }
    .file-thumbnail {
      width: 48px; height: 48px;
      border-radius: 10px;
      margin-right: 14px;
      flex-shrink: 0;
      overflow: hidden;
      background: rgba(0, 0, 0, 0.3);
    }
    .file-thumbnail img { width: 100%; height: 100%; object-fit: cover; }
    .file-icon {
      width: 48px; height: 48px;
      border-radius: 10px;
      margin-right: 14px;
      flex-shrink: 0;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .file-icon svg { width: 26px; height: 26px; }
    .file-icon.video { background: rgba(251, 146, 60, 0.15); }
    .file-icon.video svg { fill: #FB923C; }
    .file-icon.audio { background: rgba(167, 139, 250, 0.15); }
    .file-icon.audio svg { fill: #A78BFA; }
    .file-icon.document { background: rgba(96, 165, 250, 0.15); }
    .file-icon.document svg { fill: #60A5FA; }
    .file-icon.archive { background: rgba(248, 113, 113, 0.15); }
    .file-icon.archive svg { fill: #F87171; }
    .file-icon.code { background: rgba(45, 212, 191, 0.15); }
    .file-icon.code svg { fill: #2DD4BF; }
    .file-icon.apk { background: rgba(163, 230, 53, 0.15); }
    .file-icon.apk svg { fill: #A3E635; }
    .file-icon.exe { background: rgba(129, 140, 248, 0.15); }
    .file-icon.exe svg { fill: #818CF8; }
    .file-icon.file { background: rgba(148, 163, 184, 0.15); }
    .file-icon.file svg { fill: #94A3B8; }
    .file-info { flex: 1; min-width: 0; }
    .file-name {
      font-size: 14px;
      font-weight: 500;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-bottom: 3px;
    }
    .file-size { color: #94A3B8; font-size: 12px; }
    .file-remove {
      width: 32px; height: 32px;
      border-radius: 8px;
      border: none;
      background: rgba(248, 113, 113, 0.1);
      color: #F87171;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
      flex-shrink: 0;
    }
    .file-remove:hover { background: rgba(248, 113, 113, 0.2); }
    .file-remove svg { width: 18px; height: 18px; fill: currentColor; }
    .send-section { margin-top: 20px; display: none; }
    .send-section.visible { display: block; }
    .total-size { text-align: center; color: #94A3B8; font-size: 13px; margin-bottom: 12px; }
    .send-btn {
      width: 100%;
      padding: 16px 24px;
      border: none;
      border-radius: 12px;
      background: #6366F1;
      color: white;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      transition: all 0.2s;
    }
    .send-btn:hover { background: #4F46E5; }
    .send-btn:disabled { background: #475569; cursor: not-allowed; }
    .send-btn svg { width: 20px; height: 20px; fill: currentColor; }
    .progress { margin-top: 20px; display: none; }
    .progress.visible { display: block; }
    .progress-bar { height: 8px; background: #334155; border-radius: 4px; overflow: hidden; }
    .progress-fill {
      height: 100%;
      background: linear-gradient(90deg, #6366F1, #8B5CF6);
      width: 0%;
      transition: width 0.3s;
    }
    .progress-text { margin-top: 10px; text-align: center; font-size: 13px; color: #94A3B8; }
    .status { margin-top: 20px; padding: 16px; border-radius: 12px; text-align: center; display: none; }
    .status.visible { display: block; }
    .status.success { background: rgba(52, 211, 153, 0.1); border: 1px solid rgba(52, 211, 153, 0.3); }
    .status.success svg { fill: #34D399; }
    .status.error { background: rgba(248, 113, 113, 0.1); border: 1px solid rgba(248, 113, 113, 0.3); }
    .status.error svg { fill: #F87171; }
    .status svg { width: 40px; height: 40px; margin-bottom: 10px; }
    .status p { font-size: 14px; }
    .status .hint { color: #94A3B8; font-size: 12px; margin-top: 6px; }
    .reset-btn {
      margin-top: 16px;
      padding: 10px 20px;
      border: 1px solid #6366F1;
      border-radius: 8px;
      background: transparent;
      color: #6366F1;
      font-size: 14px;
      cursor: pointer;
      transition: all 0.2s;
    }
    .reset-btn:hover { background: rgba(99, 102, 241, 0.1); }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">
        <svg viewBox="0 0 24 24"><path d="M9 16h6v-6h4l-7-7-7 7h4v6zm-4 2h14v2H5v-2z"/></svg>
      </div>
      <h1>Send Files</h1>
      <p class="subtitle">Select files to send to this device</p>
    </div>

    <div class="upload-area" id="uploadArea" onclick="document.getElementById('fileInput').click()">
      <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
      <p>Click or drag files here</p>
      <p class="hint">Images, videos, documents, and more</p>
    </div>

    <input type="file" id="fileInput" multiple onchange="addFiles(this.files)">

    <div class="file-list" id="fileList">
      <div class="file-list-header">
        <h3>Selected Files</h3>
        <span class="file-count" id="fileCount">0</span>
      </div>
      <div id="fileItems"></div>
    </div>

    <div class="send-section" id="sendSection">
      <p class="total-size">Total: <span id="totalSize">0 B</span></p>
      <button class="send-btn" id="sendBtn" onclick="sendFiles()">
        <svg viewBox="0 0 24 24"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/></svg>
        Send Files
      </button>
    </div>

    <div class="progress" id="progress">
      <div class="progress-bar">
        <div class="progress-fill" id="progressFill"></div>
      </div>
      <p class="progress-text" id="progressText">Uploading... 0%</p>
    </div>

    <div class="status success" id="successStatus">
      <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
      <p>Files sent successfully!</p>
      <p class="hint">Files have been received by the device</p>
      <button class="reset-btn" onclick="resetForm()">Send More Files</button>
    </div>

    <div class="status error" id="errorStatus">
      <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
      <p id="errorMessage">Upload failed</p>
      <button class="reset-btn" onclick="resetForm()">Try Again</button>
    </div>
  </div>

  <script>
    const icons = {
      video: '<svg viewBox="0 0 24 24"><path d="M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L5 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z"/></svg>',
      audio: '<svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>',
      document: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>',
      archive: '<svg viewBox="0 0 24 24"><path d="M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM12 17.5L6.5 12H10v-2h4v2h3.5L12 17.5zM5.12 5l.81-1h12l.94 1H5.12z"/></svg>',
      code: '<svg viewBox="0 0 24 24"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z"/></svg>',
      apk: '<svg viewBox="0 0 24 24"><path d="M17.6 11.48L19.75 9.35 18.33 7.93 16.2 10.06C15.28 9.4 14.17 9 13 9V6H11V9C9.83 9 8.72 9.4 7.8 10.06L5.67 7.93 4.25 9.35 6.4 11.48C5.53 12.53 5 13.87 5 15.33V16H19V15.33C19 13.87 18.47 12.53 17.6 11.48ZM9 14C8.45 14 8 13.55 8 13S8.45 12 9 12 10 12.45 10 13 9.55 14 9 14ZM15 14C14.45 14 14 13.55 14 13S14.45 12 15 12 16 12.45 16 13 15.55 14 15 14Z"/></svg>',
      exe: '<svg viewBox="0 0 24 24"><path d="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-6 10H6v-2h8v2zm4-4H6v-2h12v2z"/></svg>',
      file: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>',
      remove: '<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>'
    };

    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'];
    const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'];
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'];
    const archiveExts = ['zip', 'rar', '7z', 'tar', 'gz'];
    const codeExts = ['dart', 'js', 'py', 'java', 'cpp', 'html', 'css', 'json', 'xml'];

    let selectedFiles = [];

    const uploadArea = document.getElementById('uploadArea');

    uploadArea.addEventListener('dragover', (e) => {
      e.preventDefault();
      uploadArea.classList.add('dragover');
    });

    uploadArea.addEventListener('dragleave', () => {
      uploadArea.classList.remove('dragover');
    });

    uploadArea.addEventListener('drop', (e) => {
      e.preventDefault();
      uploadArea.classList.remove('dragover');
      addFiles(e.dataTransfer.files);
    });

    function addFiles(files) {
      for (const file of files) {
        if (!selectedFiles.find(f => f.name === file.name && f.size === file.size)) {
          selectedFiles.push(file);
        }
      }
      renderFileList();
    }

    function removeFile(index) {
      selectedFiles.splice(index, 1);
      renderFileList();
    }

    function getFileType(filename) {
      const ext = filename.split('.').pop().toLowerCase();
      if (imageExts.includes(ext)) return 'image';
      if (videoExts.includes(ext)) return 'video';
      if (audioExts.includes(ext)) return 'audio';
      if (docExts.includes(ext)) return 'document';
      if (archiveExts.includes(ext)) return 'archive';
      if (codeExts.includes(ext)) return 'code';
      if (ext === 'apk') return 'apk';
      if (ext === 'exe' || ext === 'msi') return 'exe';
      return 'file';
    }

    function formatSize(bytes) {
      if (bytes < 1024) return bytes + ' B';
      if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
      if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
      return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
    }

    function renderFileList() {
      const fileList = document.getElementById('fileList');
      const fileItems = document.getElementById('fileItems');
      const fileCount = document.getElementById('fileCount');
      const sendSection = document.getElementById('sendSection');
      const totalSizeEl = document.getElementById('totalSize');

      if (selectedFiles.length === 0) {
        fileList.classList.remove('has-files');
        sendSection.classList.remove('visible');
        return;
      }

      fileList.classList.add('has-files');
      sendSection.classList.add('visible');
      fileCount.textContent = selectedFiles.length;

      let totalSize = 0;
      let html = '';

      selectedFiles.forEach((file, index) => {
        totalSize += file.size;
        const fileType = getFileType(file.name);
        const isImage = fileType === 'image';

        html += '<div class="file-item">';
        if (isImage) {
          html += '<div class="file-thumbnail"><img src="' + URL.createObjectURL(file) + '" alt="' + escapeHtml(file.name) + '"></div>';
        } else {
          html += '<div class="file-icon ' + fileType + '">' + (icons[fileType] || icons.file) + '</div>';
        }
        html += '<div class="file-info"><div class="file-name">' + escapeHtml(file.name) + '</div><div class="file-size">' + formatSize(file.size) + '</div></div>';
        html += '<button class="file-remove" onclick="removeFile(' + index + ')" title="Remove">' + icons.remove + '</button>';
        html += '</div>';
      });

      fileItems.innerHTML = html;
      totalSizeEl.textContent = formatSize(totalSize);
    }

    function escapeHtml(text) {
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    }

    async function sendFiles() {
      if (selectedFiles.length === 0) return;

      const progress = document.getElementById('progress');
      const progressFill = document.getElementById('progressFill');
      const progressText = document.getElementById('progressText');
      const successStatus = document.getElementById('successStatus');
      const errorStatus = document.getElementById('errorStatus');
      const uploadArea = document.getElementById('uploadArea');
      const fileList = document.getElementById('fileList');
      const sendSection = document.getElementById('sendSection');

      uploadArea.style.display = 'none';
      fileList.style.display = 'none';
      sendSection.style.display = 'none';
      successStatus.classList.remove('visible');
      errorStatus.classList.remove('visible');
      progress.classList.add('visible');
      progressFill.style.width = '0%';
      progressText.textContent = 'Uploading... 0%';

      const formData = new FormData();
      for (const file of selectedFiles) {
        formData.append('files', file);
      }

      try {
        const xhr = new XMLHttpRequest();

        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            const percent = Math.round((e.loaded / e.total) * 100);
            progressFill.style.width = percent + '%';
            progressText.textContent = 'Uploading... ' + percent + '%';
          }
        };

        xhr.onload = () => {
          progress.classList.remove('visible');
          if (xhr.status === 200) {
            try {
              const response = JSON.parse(xhr.responseText);
              console.log('Upload response:', response);
              if (response.status === 'success' && response.count > 0) {
                successStatus.classList.add('visible');
              } else {
                document.getElementById('errorMessage').textContent = 'No files were saved';
                errorStatus.classList.add('visible');
              }
            } catch (e) {
              successStatus.classList.add('visible');
            }
          } else {
            document.getElementById('errorMessage').textContent = 'Upload failed: ' + xhr.statusText;
            errorStatus.classList.add('visible');
          }
        };

        xhr.onerror = () => {
          progress.classList.remove('visible');
          document.getElementById('errorMessage').textContent = 'Network error occurred';
          errorStatus.classList.add('visible');
        };

        xhr.open('POST', '/upload');
        xhr.send(formData);
      } catch (e) {
        progress.classList.remove('visible');
        document.getElementById('errorMessage').textContent = 'Upload failed: ' + e.message;
        errorStatus.classList.add('visible');
      }
    }

    function resetForm() {
      selectedFiles = [];
      document.getElementById('fileInput').value = '';
      document.getElementById('uploadArea').style.display = '';
      document.getElementById('fileList').style.display = '';
      document.getElementById('fileList').classList.remove('has-files');
      document.getElementById('sendSection').style.display = '';
      document.getElementById('sendSection').classList.remove('visible');
      document.getElementById('progress').classList.remove('visible');
      document.getElementById('successStatus').classList.remove('visible');
      document.getElementById('errorStatus').classList.remove('visible');
      renderFileList();
    }
  </script>
</body>
</html>
''';
  }
}
