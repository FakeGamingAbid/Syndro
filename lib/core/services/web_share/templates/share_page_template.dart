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
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0A0A0F 0%, #141420 50%, #1E1E2E 100%);
            min-height: 100vh;
            color: #F8FAFC;
            padding: 20px;
        }

        .container {
            max-width: 600px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            padding: 40px 0;
        }

        .logo {
            width: 80px;
            height: 80px;
            background: linear-gradient(135deg, rgba(91, 141, 239, 0.2), rgba(123, 94, 242, 0.2));
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 20px;
            border: 1px solid rgba(123, 94, 242, 0.3);
        }

        .logo svg {
            width: 40px;
            height: 40px;
            fill: #7B5EF2;
        }

        h1 {
            font-size: 28px;
            margin-bottom: 8px;
            background: linear-gradient(135deg, #5B8DEF, #7B5EF2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .subtitle {
            color: #94A3B8;
            font-size: 14px;
        }

        /* NEW: Viewer IP display */
        .viewer-ip {
            color: #64748B;
            font-size: 12px;
            margin-top: 12px;
            font-family: 'Courier New', monospace;
            background: rgba(123, 94, 242, 0.1);
            padding: 8px 16px;
            border-radius: 8px;
            display: inline-block;
            border: 1px solid rgba(123, 94, 242, 0.2);
        }

        .viewer-ip svg {
            width: 14px;
            height: 14px;
            fill: #7B5EF2;
            vertical-align: middle;
            margin-right: 6px;
        }

        .file-list {
            background: rgba(20, 20, 32, 0.8);
            border-radius: 16px;
            padding: 8px;
            margin-top: 24px;
            border: 1px solid rgba(123, 94, 242, 0.2);
        }

        .file-item {
            display: flex;
            align-items: center;
            padding: 12px;
            border-radius: 12px;
            margin-bottom: 8px;
            background: rgba(30, 30, 46, 0.5);
            transition: all 0.2s;
            border: 1px solid transparent;
        }

        .file-item:last-child {
            margin-bottom: 0;
        }

        .file-item:hover {
            background: rgba(30, 30, 46, 0.8);
            border-color: rgba(123, 94, 242, 0.3);
        }

        .file-icon {
            width: 56px;
            height: 56px;
            background: rgba(123, 94, 242, 0.15);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 16px;
            flex-shrink: 0;
        }

        .file-icon svg {
            width: 28px;
            height: 28px;
            fill: #7B5EF2;
        }

        .file-icon.image svg { fill: #F472B6; }
        .file-icon.video { background: rgba(251, 146, 60, 0.15); }
        .file-icon.video svg { fill: #FB923C; }
        .file-icon.audio { background: rgba(167, 139, 250, 0.15); }
        .file-icon.audio svg { fill: #A78BFA; }
        .file-icon.document { background: rgba(91, 141, 239, 0.15); }
        .file-icon.document svg { fill: #5B8DEF; }
        .file-icon.archive { background: rgba(248, 113, 113, 0.15); }
        .file-icon.archive svg { fill: #F87171; }
        .file-icon.code { background: rgba(45, 212, 191, 0.15); }
        .file-icon.code svg { fill: #2DD4BF; }
        .file-icon.apk { background: rgba(163, 230, 53, 0.15); }
        .file-icon.apk svg { fill: #A3E635; }
        .file-icon.executable { background: rgba(129, 140, 248, 0.15); }
        .file-icon.executable svg { fill: #818CF8; }
        .file-icon.file { background: rgba(148, 163, 184, 0.15); }
        .file-icon.file svg { fill: #94A3B8; }

        .file-thumbnail {
            width: 56px;
            height: 56px;
            border-radius: 12px;
            margin-right: 16px;
            flex-shrink: 0;
            overflow: hidden;
            background: rgba(0, 0, 0, 0.3);
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            position: relative;
        }

        .file-thumbnail:hover {
            transform: scale(1.08);
            box-shadow: 0 4px 16px rgba(123, 94, 242, 0.4);
        }

        .file-thumbnail::after {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(123, 94, 242, 0);
            transition: background 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .file-thumbnail:hover::after {
            background: rgba(123, 94, 242, 0.2);
        }

        .file-thumbnail img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .file-info {
            flex: 1;
            min-width: 0;
        }

        .file-name {
            font-weight: 500;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            margin-bottom: 4px;
        }

        .file-size {
            color: #94A3B8;
            font-size: 13px;
        }

        .download-btn {
            background: linear-gradient(135deg, #5B8DEF, #7B5EF2);
            color: white;
            border: none;
            padding: 12px 20px;
            border-radius: 10px;
            font-weight: 500;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 8px;
            flex-shrink: 0;
        }

        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(123, 94, 242, 0.3);
        }

        .download-btn svg {
            width: 18px;
            height: 18px;
            fill: currentColor;
        }

        .loading {
            text-align: center;
            padding: 40px;
            color: #94A3B8;
        }

        .loading-spinner {
            width: 40px;
            height: 40px;
            border: 3px solid rgba(123, 94, 242, 0.2);
            border-top-color: #7B5EF2;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 16px;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .empty {
            text-align: center;
            padding: 40px;
            color: #94A3B8;
        }

        .footer {
            text-align: center;
            padding: 24px;
            color: #64748B;
            font-size: 12px;
        }

        .footer a {
            color: #7B5EF2;
            text-decoration: none;
        }

        /* Download All Button */
        .download-all-container {
            text-align: center;
            margin: 24px 0;
            padding: 0 20px;
        }

        .download-all-btn {
            background: linear-gradient(135deg, #22C55E, #10B981);
            color: white;
            border: none;
            padding: 14px 28px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 15px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 10px;
            transition: all 0.2s;
            box-shadow: 0 4px 12px rgba(34, 197, 94, 0.2);
        }

        .download-all-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(34, 197, 94, 0.4);
        }

        .download-all-btn:disabled {
            background: #475569;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .download-all-btn svg {
            width: 20px;
            height: 20px;
            fill: currentColor;
        }

        .download-all-btn .spinner {
            width: 16px;
            height: 16px;
            border: 2px solid rgba(255, 255, 255, 0.3);
            border-top-color: white;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }

        .download-progress {
            margin-top: 12px;
            color: #94A3B8;
            font-size: 13px;
            min-height: 20px;
        }

        /* LIGHTBOX STYLES */
        .lightbox {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.95);
            z-index: 1000;
            justify-content: center;
            align-items: center;
            flex-direction: column;
            padding: 20px;
            animation: fadeIn 0.2s ease;
        }

        .lightbox.active {
            display: flex;
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }

        .lightbox-content {
            display: flex;
            flex-direction: column;
            align-items: center;
            max-width: 100%;
            max-height: 100%;
        }

        .lightbox-image-container {
            position: relative;
            display: flex;
            align-items: center;
            justify-content: center;
            max-width: 90vw;
            max-height: 70vh;
        }

        .lightbox-image {
            max-width: 100%;
            max-height: 70vh;
            object-fit: contain;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
            animation: zoomIn 0.3s ease;
        }

        @keyframes zoomIn {
            from { opacity: 0; transform: scale(0.9); }
            to { opacity: 1; transform: scale(1); }
        }

        .lightbox-close {
            position: absolute;
            top: 20px;
            right: 20px;
            width: 48px;
            height: 48px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 50%;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            z-index: 1001;
        }

        .lightbox-close:hover {
            background: rgba(255, 255, 255, 0.2);
            transform: scale(1.1);
        }

        .lightbox-close svg {
            width: 24px;
            height: 24px;
            fill: white;
        }

        .lightbox-info {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-top: 20px;
            gap: 12px;
        }

        .lightbox-filename {
            color: white;
            font-size: 16px;
            font-weight: 500;
            text-align: center;
            max-width: 90vw;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .lightbox-filesize {
            color: #94A3B8;
            font-size: 14px;
        }

        .lightbox-actions {
            display: flex;
            gap: 12px;
            margin-top: 8px;
        }

        .lightbox-download {
            background: linear-gradient(135deg, #5B8DEF, #7B5EF2);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 500;
            font-size: 14px;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s;
        }

        .lightbox-download:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(123, 94, 242, 0.4);
        }

        .lightbox-download svg {
            width: 18px;
            height: 18px;
            fill: currentColor;
        }

        .lightbox-nav {
            position: absolute;
            top: 50%;
            transform: translateY(-50%);
            width: 48px;
            height: 48px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 50%;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            z-index: 1001;
        }

        .lightbox-nav:hover {
            background: rgba(255, 255, 255, 0.2);
            transform: translateY(-50%) scale(1.1);
        }

        .lightbox-nav.disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }

        .lightbox-nav.disabled:hover {
            transform: translateY(-50%);
            background: rgba(255, 255, 255, 0.1);
        }

        .lightbox-nav svg {
            width: 24px;
            height: 24px;
            fill: white;
        }

        .lightbox-prev { left: 20px; }
        .lightbox-next { right: 20px; }

        .lightbox-counter {
            position: absolute;
            top: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(10px);
            padding: 8px 16px;
            border-radius: 20px;
            color: white;
            font-size: 14px;
            z-index: 1001;
        }

        .click-hint {
            position: absolute;
            bottom: 4px;
            right: 4px;
            width: 20px;
            height: 20px;
            background: rgba(123, 94, 242, 0.9);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            opacity: 0;
            transition: opacity 0.2s;
        }

        .file-thumbnail:hover .click-hint {
            opacity: 1;
        }

        .click-hint svg {
            width: 12px;
            height: 12px;
            fill: white;
        }

        @media (max-width: 600px) {
            .download-btn span { display: none; }
            .download-btn { padding: 12px; }
            .lightbox-nav { width: 40px; height: 40px; }
            .lightbox-prev { left: 10px; }
            .lightbox-next { right: 10px; }
            .lightbox-close { top: 10px; right: 10px; width: 40px; height: 40px; }
            .lightbox-counter { top: 10px; left: 10px; padding: 6px 12px; font-size: 12px; }
            .lightbox-image { max-height: 60vh; }
            .lightbox-download { padding: 10px 20px; font-size: 13px; }
        }
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
            <!-- NEW: Viewer IP display -->
            <div id="viewer-ip" class="viewer-ip" style="display: none;">
                <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
                <span id="viewer-ip-text">Loading...</span>
            </div>
        </div>

        <div id="download-all-container" class="download-all-container" style="display: none;">
            <button id="download-all-btn" class="download-all-btn" onclick="downloadAllFiles()">
                <svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>
                <span id="download-all-text">Download All Files</span>
            </button>
            <div id="download-progress" class="download-progress"></div>
        </div>

        <div id="file-list" class="file-list">
            <div class="loading">
                <div class="loading-spinner"></div>
                Loading files...
            </div>
        </div>

        <div class="footer">
            Powered by <a href="#">Syndro</a>
        </div>
    </div>

    <!-- LIGHTBOX MODAL -->
    <div id="lightbox" class="lightbox" onclick="handleLightboxClick(event)">
        <button class="lightbox-close" onclick="closeLightbox()" aria-label="Close preview">
            <svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
        </button>
        <div id="lightbox-counter" class="lightbox-counter">1 / 1</div>
        <button id="lightbox-prev" class="lightbox-nav lightbox-prev" onclick="navigateLightbox(-1)" aria-label="Previous image">
            <svg viewBox="0 0 24 24"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>
        </button>
        <button id="lightbox-next" class="lightbox-nav lightbox-next" onclick="navigateLightbox(1)" aria-label="Next image">
            <svg viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>
        </button>
        <div class="lightbox-content">
            <div class="lightbox-image-container">
                <img id="lightbox-image" class="lightbox-image" src="" alt="Preview">
            </div>
            <div class="lightbox-info">
                <div id="lightbox-filename" class="lightbox-filename"></div>
                <div id="lightbox-filesize" class="lightbox-filesize"></div>
                <div class="lightbox-actions">
                    <a id="lightbox-download" class="lightbox-download" href="" download>
                        <svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>
                        Download
                    </a>
                </div>
            </div>
        </div>
    </div>

    <script>
        const icons = {
            image: '<svg viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>',
            video: '<svg viewBox="0 0 24 24"><path d="M18 4l2 4h-3l-2-4h-2l2 4h-3l-2-4H8l2 4H7L5 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4h-4z"/></svg>',
            audio: '<svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>',
            document: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>',
            archive: '<svg viewBox="0 0 24 24"><path d="M20.54 5.23l-1.39-1.68C18.88 3.21 18.47 3 18 3H6c-.47 0-.88.21-1.16.55L3.46 5.23C3.17 5.57 3 6.02 3 6.5V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6.5c0-.48-.17-.93-.46-1.27zM12 17.5L6.5 12H10v-2h4v2h3.5L12 17.5zM5.12 5l.81-1h12l.94 1H5.12z"/></svg>',
            code: '<svg viewBox="0 0 24 24"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z"/></svg>',
            apk: '<svg viewBox="0 0 24 24"><path d="M17.6 11.48L19.75 9.35 18.33 7.93 16.2 10.06C15.28 9.4 14.17 9 13 9V6H11V9C9.83 9 8.72 9.4 7.8 10.06L5.67 7.93 4.25 9.35 6.4 11.48C5.53 12.53 5 13.87 5 15.33V16H19V15.33C19 13.87 18.47 12.53 17.6 11.48ZM9 14C8.45 14 8 13.55 8 13S8.45 12 9 12 10 12.45 10 13 9.55 14 9 14ZM15 14C14.45 14 14 13.55 14 13S14.45 12 15 12 16 12.45 16 13 15.55 14 15 14Z"/></svg>',
            executable: '<svg viewBox="0 0 24 24"><path d="M20 6h-8l-2-2H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-6 10H6v-2h8v2zm4-4H6v-2h12v2z"/></svg>',
            file: '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>',
            download: '<svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>',
            folder: '<svg viewBox="0 0 24 24"><path d="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"/></svg>',
            zoom: '<svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14zm.5-7H9v2H7v1h2v2h1v-2h2V9h-2V7z"/></svg>'
        };

        let allFiles = [];
        let imageFiles = [];
        let currentImageIndex = 0;

        // NEW: Load viewer IP
        async function loadViewerIP() {
            try {
                const response = await fetch('/api/client-info');
                const data = await response.json();
                const ipElement = document.getElementById('viewer-ip');
                const ipTextElement = document.getElementById('viewer-ip-text');
                
                if (data.ip) {
                    ipTextElement.textContent = 'Your IP: ' + data.ip;
                    ipElement.style.display = 'inline-block';
                }
            } catch (e) {
                console.log('Could not load client IP');
            }
        }

        function openLightbox(fileId) {
            const imageIndex = imageFiles.findIndex(f => f.id === fileId);
            if (imageIndex === -1) return;
            currentImageIndex = imageIndex;
            showCurrentImage();
            document.getElementById('lightbox').classList.add('active');
            document.body.style.overflow = 'hidden';
            updateNavigationButtons();
        }

        function showCurrentImage() {
            const file = imageFiles[currentImageIndex];
            if (!file) return;
            const lightboxImage = document.getElementById('lightbox-image');
            const lightboxFilename = document.getElementById('lightbox-filename');
            const lightboxFilesize = document.getElementById('lightbox-filesize');
            const lightboxDownload = document.getElementById('lightbox-download');
            const lightboxCounter = document.getElementById('lightbox-counter');
            lightboxImage.style.opacity = '0.5';
            lightboxImage.src = file.thumbnailUrl;
            lightboxImage.alt = file.name;
            lightboxImage.onload = () => { lightboxImage.style.opacity = '1'; };
            lightboxFilename.textContent = file.name;
            lightboxFilesize.textContent = file.sizeFormatted;
            lightboxDownload.href = file.downloadUrl;
            lightboxCounter.textContent = (currentImageIndex + 1) + ' / ' + imageFiles.length;
            updateNavigationButtons();
        }

        function updateNavigationButtons() {
            const prevBtn = document.getElementById('lightbox-prev');
            const nextBtn = document.getElementById('lightbox-next');
            const counter = document.getElementById('lightbox-counter');
            if (imageFiles.length <= 1) {
                prevBtn.style.display = 'none';
                nextBtn.style.display = 'none';
                counter.style.display = 'none';
            } else {
                prevBtn.style.display = 'flex';
                nextBtn.style.display = 'flex';
                counter.style.display = 'block';
                prevBtn.classList.toggle('disabled', currentImageIndex === 0);
                nextBtn.classList.toggle('disabled', currentImageIndex === imageFiles.length - 1);
            }
        }

        function navigateLightbox(direction) {
            const newIndex = currentImageIndex + direction;
            if (newIndex < 0 || newIndex >= imageFiles.length) return;
            currentImageIndex = newIndex;
            showCurrentImage();
        }

        function closeLightbox() {
            document.getElementById('lightbox').classList.remove('active');
            document.body.style.overflow = '';
        }

        function handleLightboxClick(event) {
            if (event.target.id === 'lightbox') closeLightbox();
        }

        document.addEventListener('keydown', (e) => {
            const lightbox = document.getElementById('lightbox');
            if (!lightbox.classList.contains('active')) return;
            switch (e.key) {
                case 'Escape': closeLightbox(); break;
                case 'ArrowLeft': navigateLightbox(-1); break;
                case 'ArrowRight': navigateLightbox(1); break;
            }
        });

        let touchStartX = 0;
        let touchEndX = 0;
        document.getElementById('lightbox').addEventListener('touchstart', (e) => {
            touchStartX = e.changedTouches[0].screenX;
        }, { passive: true });
        document.getElementById('lightbox').addEventListener('touchend', (e) => {
            touchEndX = e.changedTouches[0].screenX;
            handleSwipe();
        }, { passive: true });

        function handleSwipe() {
            const swipeThreshold = 50;
            const diff = touchStartX - touchEndX;
            if (Math.abs(diff) > swipeThreshold) {
                if (diff > 0) navigateLightbox(1);
                else navigateLightbox(-1);
            }
        }

        async function downloadAllFiles() {
            if (allFiles.length === 0) return;
            const btn = document.getElementById('download-all-btn');
            const btnText = document.getElementById('download-all-text');
            const progress = document.getElementById('download-progress');
            btn.disabled = true;
            btnText.innerHTML = '<div class="spinner"></div> <span>Downloading...</span>';
            const totalFiles = allFiles.length;
            let downloaded = 0;
            for (const file of allFiles) {
                try {
                    progress.textContent = `Downloading ${downloaded + 1} of ${totalFiles}: ${file.name}`;
                    const a = document.createElement('a');
                    a.href = file.downloadUrl;
                    a.download = file.name;
                    a.style.display = 'none';
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    downloaded++;
                    if (downloaded < totalFiles) {
                        await new Promise(resolve => setTimeout(resolve, 500));
                    }
                } catch (error) {
                    console.error('Error downloading file:', file.name, error);
                }
            }
            progress.textContent = `✅ All ${totalFiles} files downloaded!`;
            btnText.textContent = 'Download All Files';
            setTimeout(() => {
                btn.disabled = false;
                progress.textContent = '';
            }, 2000);
        }

        async function loadFiles() {
            try {
                const response = await fetch('/api/files');
                const data = await response.json();
                const container = document.getElementById('file-list');
                if (data.files.length === 0) {
                    container.innerHTML = '<div class="empty">' + icons.folder + '<p>No files available</p></div>';
                    return;
                }
                allFiles = data.files;
                imageFiles = data.files.filter(f => f.isImage);
                if (allFiles.length > 1) {
                    document.getElementById('download-all-container').style.display = 'block';
                }
                container.innerHTML = data.files.map(file => {
                    if (file.isImage) {
                        return '<div class="file-item">' +
                            '<div class="file-thumbnail" onclick="openLightbox(' + file.id + ')" title="Click to preview">' +
                                '<img src="' + file.thumbnailUrl + '" alt="' + escapeHtml(file.name) + '" loading="lazy">' +
                                '<div class="click-hint">' + icons.zoom + '</div>' +
                            '</div>' +
                            '<div class="file-info">' +
                                '<div class="file-name">' + escapeHtml(file.name) + '</div>' +
                                '<div class="file-size">' + file.sizeFormatted + '</div>' +
                            '</div>' +
                            '<a href="' + file.downloadUrl + '" class="download-btn" download>' +
                                icons.download + '<span>Download</span>' +
                            '</a>' +
                        '</div>';
                    } else {
                        return '<div class="file-item">' +
                            '<div class="file-icon ' + file.type + '">' + (icons[file.type] || icons.file) + '</div>' +
                            '<div class="file-info">' +
                                '<div class="file-name">' + escapeHtml(file.name) + '</div>' +
                                '<div class="file-size">' + file.sizeFormatted + '</div>' +
                            '</div>' +
                            '<a href="' + file.downloadUrl + '" class="download-btn" download>' +
                                icons.download + '<span>Download</span>' +
                            '</a>' +
                        '</div>';
                    }
                }).join('');
            } catch (error) {
                console.error('Error loading files:', error);
                document.getElementById('file-list').innerHTML = '<div class="empty">' + icons.file + '<p>Error loading files</p></div>';
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        loadFiles();
        loadViewerIP();
    </script>
</body>
</html>
''';
  }
}
