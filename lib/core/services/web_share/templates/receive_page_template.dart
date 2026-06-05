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
            max-width: 700px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            padding: 40px 0 30px;
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

        /* ========================================
           PICKER BUTTONS - SIDE BY SIDE
        ======================================== */
        .picker-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin: 24px 0;
        }

        @media (max-width: 400px) {
            .picker-row {
                grid-template-columns: 1fr;
            }
        }

        .picker-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 16px 20px;
            border-radius: 14px;
            cursor: pointer;
            transition: all 0.3s ease;
            border: 2px solid transparent;
            font-size: 15px;
            font-weight: 600;
            background: none;
        }

        .picker-btn svg {
            width: 22px;
            height: 22px;
        }

        .picker-btn.files {
            background: linear-gradient(135deg, rgba(91, 141, 239, 0.15), rgba(91, 141, 239, 0.05));
            border-color: rgba(91, 141, 239, 0.3);
            color: #5B8DEF;
        }

        .picker-btn.files:hover {
            background: linear-gradient(135deg, rgba(91, 141, 239, 0.25), rgba(91, 141, 239, 0.1));
            border-color: rgba(91, 141, 239, 0.6);
            transform: translateY(-2px);
        }

        .picker-btn.files svg {
            fill: #5B8DEF;
        }

        .picker-btn.media {
            background: linear-gradient(135deg, rgba(244, 114, 182, 0.15), rgba(251, 146, 60, 0.05));
            border-color: rgba(244, 114, 182, 0.3);
            color: #F472B6;
        }

        .picker-btn.media:hover {
            background: linear-gradient(135deg, rgba(244, 114, 182, 0.25), rgba(251, 146, 60, 0.1));
            border-color: rgba(244, 114, 182, 0.6);
            transform: translateY(-2px);
        }

        .picker-btn.media svg {
            fill: #F472B6;
        }

        .picker-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
        }

        /* Hidden file inputs */
        .file-input {
            display: none;
        }

        /* ========================================
           FILE LIST
        ======================================== */
        .file-list {
            background: rgba(20, 20, 32, 0.8);
            border-radius: 16px;
            padding: 8px;
            margin-top: 20px;
            border: 1px solid rgba(123, 94, 242, 0.2);
            display: none;
        }

        .file-list.active {
            display: block;
        }

        .file-list-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px;
            border-bottom: 1px solid rgba(123, 94, 242, 0.1);
            margin-bottom: 8px;
        }

        .file-list-title {
            font-weight: 600;
            font-size: 14px;
            color: #94A3B8;
        }

        .clear-all-btn {
            background: rgba(248, 113, 113, 0.15);
            border: none;
            color: #F87171;
            padding: 6px 12px;
            border-radius: 8px;
            font-size: 12px;
            cursor: pointer;
            transition: all 0.2s;
        }

        .clear-all-btn:hover {
            background: rgba(248, 113, 113, 0.25);
        }

        .file-item {
            padding: 12px;
            border-radius: 12px;
            margin-bottom: 8px;
            background: rgba(30, 30, 46, 0.5);
        }

        .file-item:last-child {
            margin-bottom: 0;
        }

        .file-item-content {
            display: flex;
            align-items: center;
        }

        .file-thumb {
            width: 48px;
            height: 48px;
            border-radius: 10px;
            margin-right: 14px;
            overflow: hidden;
            background: rgba(123, 94, 242, 0.15);
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            cursor: pointer;
            position: relative;
        }

        .file-thumb img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }

        .file-thumb svg {
            width: 24px;
            height: 24px;
            fill: #7B5EF2;
        }

        .file-thumb.photo {
            background: rgba(244, 114, 182, 0.15);
        }

        .file-thumb.photo svg {
            fill: #F472B6;
        }

        .file-thumb.video {
            background: rgba(251, 146, 60, 0.15);
        }

        .file-thumb.video svg {
            fill: #FB923C;
        }

        .file-thumb .zoom-icon {
            position: absolute;
            bottom: 2px;
            right: 2px;
            background: rgba(0, 0, 0, 0.6);
            border-radius: 4px;
            padding: 2px;
            display: none;
        }

        .file-thumb.photo .zoom-icon {
            display: block;
        }

        .file-thumb .zoom-icon svg {
            width: 12px;
            height: 12px;
            fill: white;
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
            font-size: 14px;
        }

        .file-meta {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .file-size {
            color: #94A3B8;
            font-size: 12px;
        }

        .file-status {
            font-size: 11px;
            font-weight: 600;
            padding: 2px 6px;
            border-radius: 4px;
        }

        .file-status.pending {
            background: rgba(251, 191, 36, 0.15);
            color: #FBBF24;
        }

        .file-status.preparing {
            background: rgba(167, 139, 250, 0.15);
            color: #A78BFA;
        }

        .file-status.uploading {
            background: rgba(91, 141, 239, 0.15);
            color: #5B8DEF;
        }

        .file-status.success {
            background: rgba(34, 197, 94, 0.15);
            color: #22C55E;
        }

        .file-status.error {
            background: rgba(248, 113, 113, 0.15);
            color: #F87171;
        }

        .file-remove {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: rgba(248, 113, 113, 0.15);
            border: none;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
            flex-shrink: 0;
            margin-left: 12px;
        }

        .file-remove:hover {
            background: rgba(248, 113, 113, 0.3);
        }

        .file-remove:disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }

        .file-remove svg {
            width: 18px;
            height: 18px;
            fill: #F87171;
        }

        /* Progress bar under each file */
        .file-progress {
            margin-top: 10px;
            display: none;
        }

        .file-progress.active {
            display: block;
        }

        .file-progress-bar {
            height: 6px;
            background: rgba(123, 94, 242, 0.2);
            border-radius: 3px;
            overflow: hidden;
        }

        .file-progress-fill {
            height: 100%;
            background: linear-gradient(135deg, #5B8DEF, #7B5EF2);
            border-radius: 3px;
            transition: width 0.3s ease;
            width: 0%;
        }

        .file-progress-fill.success {
            background: linear-gradient(135deg, #22C55E, #16A34A);
        }

        .file-progress-fill.error {
            background: linear-gradient(135deg, #F87171, #EF4444);
        }

        .file-progress-text {
            font-size: 11px;
            color: #94A3B8;
            margin-top: 4px;
            text-align: right;
        }

        /* ========================================
           IMAGE PREVIEW MODAL
        ======================================== */
        .image-modal {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.95);
            z-index: 1000;
            align-items: center;
            justify-content: center;
            flex-direction: column;
        }

        .image-modal.active {
            display: flex;
        }

        .image-modal-header {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            padding: 16px;
            background: linear-gradient(to bottom, rgba(0,0,0,0.7), transparent);
            display: flex;
            align-items: center;
            z-index: 1001;
        }

        .image-modal-close {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.1);
            border: none;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
        }

        .image-modal-close:hover {
            background: rgba(255, 255, 255, 0.2);
        }

        .image-modal-close svg {
            width: 24px;
            height: 24px;
            fill: white;
        }

        .image-modal-info {
            margin-left: 16px;
            flex: 1;
        }

        .image-modal-name {
            color: white;
            font-weight: 600;
            font-size: 16px;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .image-modal-meta {
            color: rgba(255, 255, 255, 0.7);
            font-size: 12px;
            margin-top: 2px;
        }

        .image-modal-content {
            max-width: 90%;
            max-height: 80%;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .image-modal-content img {
            max-width: 100%;
            max-height: 80vh;
            object-fit: contain;
            border-radius: 8px;
        }

        .image-modal-nav {
            position: absolute;
            top: 50%;
            transform: translateY(-50%);
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.1);
            border: none;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s;
        }

        .image-modal-nav:hover {
            background: rgba(255, 255, 255, 0.2);
        }

        .image-modal-nav svg {
            width: 32px;
            height: 32px;
            fill: white;
        }

        .image-modal-nav.prev {
            left: 16px;
        }

        .image-modal-nav.next {
            right: 16px;
        }

        .image-modal-nav:disabled {
            opacity: 0.3;
            cursor: not-allowed;
        }

        .image-modal-dots {
            position: absolute;
            bottom: 24px;
            left: 50%;
            transform: translateX(-50%);
            display: flex;
            gap: 8px;
        }

        .image-modal-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.3);
            transition: all 0.2s;
        }

        .image-modal-dot.active {
            width: 24px;
            border-radius: 4px;
            background: white;
        }

        /* ========================================
           SUMMARY
        ======================================== */
        .summary {
            margin-top: 20px;
            padding: 16px;
            background: rgba(34, 197, 94, 0.1);
            border: 1px solid rgba(34, 197, 94, 0.3);
            border-radius: 12px;
            display: none;
        }

        .summary.active {
            display: block;
        }

        .summary-title {
            font-weight: 600;
            color: #22C55E;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .summary-title svg {
            width: 20px;
            height: 20px;
            fill: #22C55E;
        }

        .summary-text {
            color: #94A3B8;
            font-size: 14px;
        }

        .summary.has-errors {
            background: rgba(251, 191, 36, 0.1);
            border-color: rgba(251, 191, 36, 0.3);
        }

        .summary.has-errors .summary-title {
            color: #FBBF24;
        }

        .summary.has-errors .summary-title svg {
            fill: #FBBF24;
        }

        /* ========================================
           DROP ZONE
        ======================================== */
        .drop-zone {
            border: 2px dashed rgba(123, 94, 242, 0.4);
            border-radius: 20px;
            padding: 40px 20px;
            text-align: center;
            margin: 24px 0;
            transition: all 0.3s ease;
            background: rgba(123, 94, 242, 0.05);
            cursor: pointer;
            position: relative;
            overflow: hidden;
        }

        .drop-zone::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(135deg, rgba(91, 141, 239, 0.1), rgba(123, 94, 242, 0.1));
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .drop-zone:hover {
            border-color: rgba(123, 94, 242, 0.6);
            background: rgba(123, 94, 242, 0.1);
        }

        .drop-zone:hover::before {
            opacity: 1;
        }

        .drop-zone.drag-over {
            border-color: #7B5EF2;
            background: rgba(123, 94, 242, 0.2);
            transform: scale(1.02);
            box-shadow: 0 0 30px rgba(123, 94, 242, 0.3);
        }

        .drop-zone.drag-over::before {
            opacity: 1;
        }

        .drop-zone-icon {
            width: 64px;
            height: 64px;
            margin: 0 auto 16px;
            background: linear-gradient(135deg, rgba(91, 141, 239, 0.2), rgba(123, 94, 242, 0.2));
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: transform 0.3s ease;
        }

        .drop-zone:hover .drop-zone-icon {
            transform: scale(1.1);
        }

        .drop-zone.drag-over .drop-zone-icon {
            transform: scale(1.2);
        }

        .drop-zone-icon svg {
            width: 32px;
            height: 32px;
            fill: #7B5EF2;
            transition: transform 0.3s ease;
        }

        .drop-zone.drag-over .drop-zone-icon svg {
            transform: translateY(-4px);
        }

        .drop-zone-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 8px;
            color: #F8FAFC;
        }

        .drop-zone-subtitle {
            font-size: 14px;
            color: #94A3B8;
            margin-bottom: 16px;
        }

        .drop-zone-hint {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            font-size: 12px;
            color: #64748B;
            background: rgba(100, 116, 139, 0.1);
            padding: 6px 12px;
            border-radius: 20px;
        }

        .drop-zone-hint svg {
            width: 14px;
            height: 14px;
            fill: #64748B;
        }

        /* Mobile adjustments for drop zone */
        @media (max-width: 500px) {
            .drop-zone {
                padding: 30px 16px;
            }
            
            .drop-zone-icon {
                width: 56px;
                height: 56px;
            }
            
            .drop-zone-icon svg {
                width: 28px;
                height: 28px;
            }
            
            .drop-zone-title {
                font-size: 16px;
            }
            
            .drop-zone-subtitle {
                font-size: 13px;
            }
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
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">
                <svg viewBox="0 0 24 24"><path d="M9 16h6v-6h4l-7-7-7 7h4v6zm-4 2h14v2H5v-2z"/></svg>
            </div>
            <h1>Send Files</h1>
            <p class="subtitle">Select files to send automatically</p>
        </div>

        <!-- Main Content -->
        <div id="main-content">
            <!-- Drop Zone -->
            <div class="drop-zone" id="drop-zone">
                <div class="drop-zone-icon">
                    <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
                </div>
                <div class="drop-zone-title">Drop files here</div>
                <div class="drop-zone-subtitle">or click to browse</div>
                <div class="drop-zone-hint">
                    <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>
                    Supports all file types
                </div>
            </div>

            <!-- Picker Buttons - Side by Side -->
            <div class="picker-row" id="picker-row">
                <button type="button" class="picker-btn files" id="files-btn">
                    <svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>
                    Select Files
                </button>
                <button type="button" class="picker-btn media" id="media-btn">
                    <svg viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>
                    Select Media
                </button>
            </div>

            <!-- Hidden File Inputs -->
            <input type="file" id="files-input" class="file-input" multiple>
            <input type="file" id="media-input" class="file-input" multiple accept="image/*,video/*">

            <!-- File List -->
            <div id="file-list" class="file-list">
                <div class="file-list-header">
                    <span class="file-list-title" id="file-count">0 files selected</span>
                    <button type="button" class="clear-all-btn" id="clear-all-btn">Clear All</button>
                </div>
                <div id="file-items"></div>
            </div>

            <!-- Summary -->
            <div id="summary" class="summary">
                <div class="summary-title">
                    <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>
                    <span id="summary-title-text">All files sent!</span>
                </div>
                <div class="summary-text" id="summary-text">Your files have been sent successfully</div>
            </div>
        </div>

        <!-- Image Preview Modal -->
        <div id="image-modal" class="image-modal">
            <div class="image-modal-header">
                <button type="button" class="image-modal-close" id="modal-close">
                    <svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
                </button>
                <div class="image-modal-info">
                    <div class="image-modal-name" id="modal-name">image.jpg</div>
                    <div class="image-modal-meta" id="modal-meta">1 of 5 • 2.5 MB</div>
                </div>
            </div>
            <div class="image-modal-content">
                <img id="modal-image" src="" alt="">
            </div>
            <button type="button" class="image-modal-nav prev" id="modal-prev">
                <svg viewBox="0 0 24 24"><path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>
            </button>
            <button type="button" class="image-modal-nav next" id="modal-next">
                <svg viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>
            </button>
            <div class="image-modal-dots" id="modal-dots"></div>
        </div>

        <div class="footer">
            Powered by <a href="#">Syndro</a>
        </div>
    </div>

    <script>
        // File data structure: { file, status, progress, error, url }
        let fileItems = [];
        let isUploading = false;

        // Media file extensions
        const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg'];
        const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'm4v', '3gp', 'wmv'];

        // DOM Elements
        let filesInput = document.getElementById('files-input');
        let mediaInput = document.getElementById('media-input');
        const filesBtn = document.getElementById('files-btn');
        const mediaBtn = document.getElementById('media-btn');
        const dropZone = document.getElementById('drop-zone');
        const fileList = document.getElementById('file-list');
        const fileItemsContainer = document.getElementById('file-items');
        const fileCount = document.getElementById('file-count');
        const clearAllBtn = document.getElementById('clear-all-btn');
        const summary = document.getElementById('summary');
        const summaryTitleText = document.getElementById('summary-title-text');
        const summaryText = document.getElementById('summary-text');

        // Image modal elements
        const imageModal = document.getElementById('image-modal');
        const modalClose = document.getElementById('modal-close');
        const modalImage = document.getElementById('modal-image');
        const modalName = document.getElementById('modal-name');
        const modalMeta = document.getElementById('modal-meta');
        const modalPrev = document.getElementById('modal-prev');
        const modalNext = document.getElementById('modal-next');
        const modalDots = document.getElementById('modal-dots');
        let currentImageIndex = 0;
        let imageFiles = [];

        // ========================================
        // EVENT LISTENERS
        // ========================================

        filesBtn.addEventListener('click', function(e) {
            e.preventDefault();
            filesInput.click();
        });

        mediaBtn.addEventListener('click', function(e) {
            e.preventDefault();
            mediaInput.click();
        });

        // Drop zone click to open file picker
        dropZone.addEventListener('click', function(e) {
            // Don't trigger if clicking on hint text
            if (e.target.closest('.drop-zone-hint')) return;
            filesInput.click();
        });

        filesInput.addEventListener('change', handleFileSelect);
        mediaInput.addEventListener('change', handleFileSelect);

        clearAllBtn.addEventListener('click', clearAllFiles);

        // Modal events
        modalClose.addEventListener('click', closeImageModal);
        modalPrev.addEventListener('click', showPrevImage);
        modalNext.addEventListener('click', showNextImage);
        imageModal.addEventListener('click', function(e) {
            if (e.target === imageModal) closeImageModal();
        });

        // Keyboard navigation for modal
        document.addEventListener('keydown', function(e) {
            if (!imageModal.classList.contains('active')) return;
            if (e.key === 'Escape') closeImageModal();
            if (e.key === 'ArrowLeft') showPrevImage();
            if (e.key === 'ArrowRight') showNextImage();
        });

        // Touch swipe for modal
        let touchStartX = 0;
        imageModal.addEventListener('touchstart', function(e) {
            touchStartX = e.touches[0].clientX;
        });
        imageModal.addEventListener('touchend', function(e) {
            const touchEndX = e.changedTouches[0].clientX;
            const diff = touchStartX - touchEndX;
            if (Math.abs(diff) > 50) {
                if (diff > 0) showNextImage();
                else showPrevImage();
            }
        });

        // ========================================
        // FILE HANDLING
        // ========================================

        function handleFileSelect(event) {
            const files = Array.from(event.target.files);
            if (!files || files.length === 0) return;

            // Add files that aren't already in the list
            files.forEach(file => {
                const exists = fileItems.some(f => f.file.name === file.name && f.file.size === file.size);
                if (!exists) {
                    const url = isImage(file.name) ? URL.createObjectURL(file) : null;
                    fileItems.push({
                        file: file,
                        status: 'pending', // pending, uploading, success, error
                        progress: 0,
                        error: null,
                        url: url
                    });
                }
            });

            // Clear the input
            event.target.value = '';

            renderFileList();
            
            // Auto-upload new files
            uploadPendingFiles();
        }

        function isImage(filename) {
            const ext = filename.split('.').pop().toLowerCase();
            return imageExtensions.includes(ext);
        }

        function isVideo(filename) {
            const ext = filename.split('.').pop().toLowerCase();
            return videoExtensions.includes(ext);
        }

        function formatSize(bytes) {
            if (bytes < 1024) return bytes + ' B';
            if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
            if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
            return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function renderFileList() {
            if (fileItems.length === 0) {
                fileList.classList.remove('active');
                summary.classList.remove('active');
                return;
            }

            fileList.classList.add('active');

            // Update count
            const pendingCount = fileItems.filter(f => f.status === 'pending').length;
            const uploadingCount = fileItems.filter(f => f.status === 'uploading').length;
            const successCount = fileItems.filter(f => f.status === 'success').length;
            const errorCount = fileItems.filter(f => f.status === 'error').length;
            
            let countText = `${fileItems.length} file${fileItems.length > 1 ? 's' : ''}`;
            if (uploadingCount > 0) {
                countText += ` • ${uploadingCount} uploading`;
            }
            if (successCount > 0) {
                countText += ` • ${successCount} sent`;
            }
            fileCount.textContent = countText;

            // Update image files list for modal
            imageFiles = fileItems.filter(f => isImage(f.file.name));

            // Render file items
            fileItemsContainer.innerHTML = fileItems.map((item, index) => {
                const file = item.file;
                const isImg = isImage(file.name);
                const isVid = isVideo(file.name);

                let thumbHtml = '';
                if (isImg && item.url) {
                    thumbHtml = `
                        <div class="file-thumb photo" onclick="openImageModal(${index})">
                            <img src="${item.url}" alt="">
                            <div class="zoom-icon">
                                <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
                            </div>
                        </div>`;
                } else if (isVid) {
                    thumbHtml = `
                        <div class="file-thumb video">
                            <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                        </div>`;
                } else {
                    thumbHtml = `
                        <div class="file-thumb">
                            <svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm4 18H6V4h7v5h5v11z"/></svg>
                        </div>`;
                }

                let statusHtml = '';
                if (item.status === 'pending') {
                    statusHtml = '<span class="file-status pending">PENDING</span>';
                } else if (item.status === 'uploading') {
                    statusHtml = '<span class="file-status uploading">UPLOADING</span>';
                } else if (item.status === 'success') {
                    statusHtml = '<span class="file-status success">SENT</span>';
                } else if (item.status === 'error') {
                    statusHtml = '<span class="file-status error">FAILED</span>';
                }

                let progressHtml = '';
                if (item.status === 'uploading' || item.status === 'success' || item.status === 'error') {
                    let progressClass = '';
                    if (item.status === 'success') progressClass = 'success';
                    if (item.status === 'error') progressClass = 'error';
                    
                    let progressText = '';
                    if (item.status === 'uploading') {
                        progressText = `${item.progress}%`;
                    } else if (item.status === 'success') {
                        progressText = 'Completed';
                    } else if (item.status === 'error') {
                        progressText = item.error || 'Failed';
                    }

                    progressHtml = `
                        <div class="file-progress active">
                            <div class="file-progress-bar">
                                <div class="file-progress-fill ${progressClass}" style="width: ${item.progress}%"></div>
                            </div>
                            <div class="file-progress-text">${progressText}</div>
                        </div>`;
                }

                const canRemove = item.status !== 'uploading';

                return `
                    <div class="file-item" data-index="${index}">
                        <div class="file-item-content">
                            ${thumbHtml}
                            <div class="file-info">
                                <div class="file-name">${escapeHtml(file.name)}</div>
                                <div class="file-meta">
                                    <span class="file-size">${formatSize(file.size)}</span>
                                    ${statusHtml}
                                </div>
                            </div>
                            <button type="button" class="file-remove" ${canRemove ? '' : 'disabled'} onclick="removeFile(${index})">
                                <svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
                            </button>
                        </div>
                        ${progressHtml}
                    </div>
                `;
            }).join('');

            // Show summary if all files processed
            const allProcessed = fileItems.every(f => f.status === 'success' || f.status === 'error');
            if (allProcessed && fileItems.length > 0) {
                summary.classList.add('active');
                if (errorCount > 0) {
                    summary.classList.add('has-errors');
                    summaryTitleText.textContent = 'Transfer Complete';
                    summaryText.textContent = `${successCount} sent, ${errorCount} failed`;
                } else {
                    summary.classList.remove('has-errors');
                    summaryTitleText.textContent = 'All files sent!';
                    summaryText.textContent = 'Your files have been sent successfully';
                }
            } else {
                summary.classList.remove('active');
            }
        }

        function removeFile(index) {
            const item = fileItems[index];
            if (item.status === 'uploading') return;
            
            // Revoke object URL if exists
            if (item.url) {
                URL.revokeObjectURL(item.url);
            }
            
            fileItems.splice(index, 1);
            renderFileList();
        }

        function clearAllFiles() {
            // Only clear files that are not uploading
            const uploadingFiles = fileItems.filter(f => f.status === 'uploading');
            
            // Revoke all object URLs
            fileItems.forEach(item => {
                if (item.url && item.status !== 'uploading') {
                    URL.revokeObjectURL(item.url);
                }
            });
            
            fileItems = uploadingFiles;
            renderFileList();
        }

        // ========================================
        // UPLOAD
        // ========================================

        async function uploadPendingFiles() {
            if (isUploading) return;
            
            const pendingFiles = fileItems.filter(f => f.status === 'pending');
            if (pendingFiles.length === 0) return;

            isUploading = true;

            for (const item of pendingFiles) {
                // Check if item still exists and is pending
                const currentIndex = fileItems.indexOf(item);
                if (currentIndex === -1 || item.status !== 'pending') continue;

                // Show "preparing" status for large files (> 100MB)
                const LARGE_FILE_THRESHOLD = 100 * 1024 * 1024;
                if (item.file.size > LARGE_FILE_THRESHOLD) {
                    item.status = 'preparing';
                    item.progress = 0;
                    item.statusText = 'Preparing...';
                    renderFileList();
                    
                    // Allow UI to update
                    await new Promise(resolve => setTimeout(resolve, 100));
                }

                item.status = 'uploading';
                item.progress = 0;
                item.statusText = null;
                renderFileList();

                try {
                    await uploadFile(item);
                    item.status = 'success';
                    item.progress = 100;
                } catch (error) {
                    item.status = 'error';
                    item.error = error.message || 'Upload failed';
                    item.progress = 100;
                }
                
                renderFileList();
            }

            isUploading = false;
            
            // Check if there are new pending files added during upload
            const newPending = fileItems.filter(f => f.status === 'pending');
            if (newPending.length > 0) {
                uploadPendingFiles();
            }
        }

        function uploadFile(item) {
            return new Promise((resolve, reject) => {
                const xhr = new XMLHttpRequest();
                const formData = new FormData();
                formData.append('file', item.file, item.file.name);

                xhr.upload.addEventListener('progress', function(e) {
                    if (e.lengthComputable) {
                        item.progress = Math.round((e.loaded / e.total) * 100);
                        renderFileList();
                    }
                });

                xhr.addEventListener('load', function() {
                    if (xhr.status >= 200 && xhr.status < 300) {
                        try {
                            const result = JSON.parse(xhr.responseText);
                            if (result.status === 'error') {
                                reject(new Error(result.message || 'Upload failed'));
                            } else {
                                resolve(result);
                            }
                        } catch (e) {
                            resolve({});
                        }
                    } else {
                        reject(new Error(`Server error: ${xhr.status}`));
                    }
                });

                xhr.addEventListener('error', function() {
                    reject(new Error('Network error'));
                });

                xhr.addEventListener('abort', function() {
                    reject(new Error('Upload cancelled'));
                });

                xhr.open('POST', '/upload');
                xhr.send(formData);
            });
        }

        // ========================================
        // IMAGE MODAL
        // ========================================

        function openImageModal(fileIndex) {
            const item = fileItems[fileIndex];
            if (!item || !isImage(item.file.name) || !item.url) return;

            // Find index in imageFiles array
            currentImageIndex = imageFiles.findIndex(f => f === item);
            if (currentImageIndex === -1) return;

            updateModalContent();
            imageModal.classList.add('active');
            document.body.style.overflow = 'hidden';
        }

        function closeImageModal() {
            imageModal.classList.remove('active');
            document.body.style.overflow = '';
        }

        function showPrevImage() {
            if (currentImageIndex > 0) {
                currentImageIndex--;
                updateModalContent();
            }
        }

        function showNextImage() {
            if (currentImageIndex < imageFiles.length - 1) {
                currentImageIndex++;
                updateModalContent();
            }
        }

        function updateModalContent() {
            const item = imageFiles[currentImageIndex];
            if (!item) return;

            modalImage.src = item.url;
            modalName.textContent = item.file.name;
            modalMeta.textContent = `${currentImageIndex + 1} of ${imageFiles.length} • ${formatSize(item.file.size)}`;

            // Update navigation buttons
            modalPrev.disabled = currentImageIndex === 0;
            modalNext.disabled = currentImageIndex === imageFiles.length - 1;

            // Update dots
            modalDots.innerHTML = imageFiles.map((_, i) => 
                `<div class="image-modal-dot ${i === currentImageIndex ? 'active' : ''}"></div>`
            ).join('');
        }

        // ========================================
        // DRAG & DROP
        // ========================================

        let dragCounter = 0;

        // Prevent default drag behaviors on document
        document.addEventListener('dragover', (e) => {
            e.preventDefault();
        });

        document.addEventListener('drop', (e) => {
            e.preventDefault();
        });

        // Drop zone drag enter
        dropZone.addEventListener('dragenter', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dragCounter++;
            dropZone.classList.add('drag-over');
        });

        // Drop zone drag leave
        dropZone.addEventListener('dragleave', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dragCounter--;
            if (dragCounter === 0) {
                dropZone.classList.remove('drag-over');
            }
        });

        // Drop zone drag over
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.stopPropagation();
        });

        // Drop zone drop
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            e.stopPropagation();
            dragCounter = 0;
            dropZone.classList.remove('drag-over');

            const files = Array.from(e.dataTransfer.files);
            handleDroppedFiles(files);
        });

        // Also support dropping anywhere on the page (fallback)
        document.body.addEventListener('drop', (e) => {
            e.preventDefault();
            const files = Array.from(e.dataTransfer.files);
            if (files.length > 0) {
                handleDroppedFiles(files);
            }
        });

        function handleDroppedFiles(files) {
            if (!files || files.length === 0) return;

            files.forEach(file => {
                const exists = fileItems.some(f => f.file.name === file.name && f.file.size === file.size);
                if (!exists) {
                    const url = isImage(file.name) ? URL.createObjectURL(file) : null;
                    fileItems.push({
                        file: file,
                        status: 'pending',
                        progress: 0,
                        error: null,
                        url: url
                    });
                }
            });

            renderFileList();
            uploadPendingFiles();
        }
    </script>
</body>
</html>
''';
  }
}
