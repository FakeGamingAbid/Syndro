/// HTML template for the file sharing/download page
class SharePageTemplate {
  static String generate() {
    return r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Syndro - File Share</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 50%, #334155 100%);
      min-height: 100vh;
      color: #F8FAFC;
      padding: 20px;
    }
    .container { max-width: 600px; margin: 0 auto; }
    .header { text-align: center; padding: 40px 0; }
    .logo {
      width: 80px; height: 80px;
      background: rgba(99, 102, 241, 0.2);
      border-radius: 20px;
      display: flex; align-items: center; justify-content: center;
      margin: 0 auto 20px;
    }
    .logo svg { width: 40px; height: 40px; fill: #6366F1; }
    h1 { font-size: 28px; margin-bottom: 8px; }
    .subtitle { color: #94A3B8; font-size: 14px; }
    .file-list {
      background: rgba(30, 41, 59, 0.8);
      border-radius: 16px;
      padding: 8px;
      margin-top: 24px;
    }
    .file-item {
      display: flex; align-items: center;
      padding: 12px; border-radius: 12px; margin-bottom: 8px;
      background: rgba(51, 65, 85, 0.5);
      transition: background 0.2s;
    }
    .file-item:last-child { margin-bottom: 0; }
    .file-item:hover { background: rgba(51, 65, 85, 0.8); }
    .file-icon {
      width: 56px; height: 56px;
      background: rgba(99, 102, 241, 0.2);
      border-radius: 12px;
      display: flex; align-items: center; justify-content: center;
      margin-right: 16px; flex-shrink: 0;
    }
    .file-icon svg { width: 28px; height: 28px; }
    .file-icon.video svg { fill: #FB923C; }
    .file-icon.audio svg { fill: #A78BFA; }
    .file-icon.document svg { fill: #60A5FA; }
    .file-icon.archive svg { fill: #F87171; }
    .file-icon.code svg { fill: #2DD4BF; }
    .file-icon.apk svg { fill: #A3E635; }
    .file-icon.executable svg { fill: #818CF8; }
    .file-icon.file svg { fill: #94A3B8; }
    .file-thumbnail {
      width: 56px; height: 56px;
      border-radius: 12px; margin-right: 16px; flex-shrink: 0;
      overflow: hidden; background: rgba(0, 0, 0, 0.3);
    }
    .file-thumbnail img { width: 100%; height: 100%; object-fit: cover; }
    .file-info { flex: 1; min-width: 0; }
    .file-name {
      font-weight: 500;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      margin-bottom: 4px;
    }
    .file-size { color: #94A3B8; font-size: 13px; }
    .download-btn {
      background: #6366F1; color: white; border: none;
      padding: 12px 20px; border-radius: 10px;
      font-weight: 500; cursor: pointer; text-decoration: none;
      transition: background 0.2s;
      display: flex; align-items: center; gap: 8px; flex-shrink: 0;
    }
    .download-btn:hover { background: #4F46E5; }
    .download-btn svg { width: 18px; height: 18px; fill: currentColor; }
    .loading { text-align: center; padding: 40px; color: #94A3B8; }
    .loading-spinner {
      width: 40px; height: 40px;
      border: 3px solid rgba(99, 102, 241, 0.2);
      border-top-color: #6366F1;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin: 0 auto 16px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .empty { text-align: center; padding: 40px; color: #94A3B8; }
    .footer { text-align: center; padding: 24px; color: #64748B; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo">
        <svg viewBox="0 0 24 24"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6zm9 14H6V10h12v10zm-6-3c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z"/></svg>
      </div>
      <h1>Syndro</h1>
      <p class="subtitle">Secure File Share</p>
    </div>

    <div id="file-list" class="file-list">
      <div class="loading"><div class="loading-spinner"></div>Loading files...</div>
    </div>

    <div class="footer">Powered by Syndro</div>
  </div>

  <script>
    const icons = {
      video: '<svg viewBox="0 0 24 24"><path d="M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L5 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z"/></svg>',
      audio: '<svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>',
      document: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>',
      archive: '<svg viewBox="0 0 24 24"><path d="M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM12 17.5L6.5 12H10v-2h4v2h3.5L12 17.5zM5.12 5l.81-1h12l.94 1H5.12z"/></svg>',
      code: '<svg viewBox="0 0 24 24"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z"/></svg>',
      apk: '<svg viewBox="0 0 24 24"><path d="M17.6 11.48L19.75 9.35 18.33 7.93 16.2 10.06C15.28 9.4 14.17 9 13 9V6H11V9C9.83 9 8.72 9.4 7.8 10.06L5.67 7.93 4.25 9.35 6.4 11.48C5.53 12.53 5 13.87 5 15.33V16H19V15.33C19 13.87 18.47 12.53 17.6 11.48ZM9 14C8.45 14 8 13.55 8 13S8.45 12 9 12 10 12.45 10 13 9.55 14 9 14ZM15 14C14.45 14 14 13.55 14 13S14.45 12 15 12 16 12.45 16 13 15.55 14 15 14Z"/></svg>',
      executable: '<svg viewBox="0 0 24 24"><path d="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-6 10H6v-2h8v2zm4-4H6v-2h12v2z"/></svg>',
      file: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>',
      download: '<svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>',
      folder: '<svg viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>'
    };

    async function loadFiles() {
      try {
        const response = await fetch('/api/files');
        const data = await response.json();
        const container = document.getElementById('file-list');

        if (data.files.length === 0) {
          container.innerHTML = '<div class="empty">' + icons.folder + '<p>No files available</p></div>';
          return;
        }

        container.innerHTML = data.files.map(file =>
          '<div class="file-item">' +
            (file.isImage
              ? '<div class="file-thumbnail"><img src="' + file.thumbnailUrl + '" alt="' + file.name + '" loading="lazy"></div>'
              : '<div class="file-icon ' + file.type + '">' + (icons[file.type] || icons.file) + '</div>'
            ) +
            '<div class="file-info"><div class="file-name">' + file.name + '</div><div class="file-size">' + file.sizeFormatted + '</div></div>' +
            '<a href="' + file.downloadUrl + '" class="download-btn" download>' + icons.download + '<span>Download</span></a>' +
          '</div>'
        ).join('');
      } catch (error) {
        document.getElementById('file-list').innerHTML = '<div class="empty">' + icons.file + '<p>Error loading files</p></div>';
      }
    }

    loadFiles();
  </script>
</body>
</html>
''';
  }
}
