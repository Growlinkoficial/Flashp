"use client";

import React, { useState, useRef, useEffect } from "react";

interface FileStatus {
  file: File;
  id: string;
  progress: number;
  status: "idle" | "converting" | "done" | "error";
  resultUrl?: string;
  resultSize?: number;
  error?: string;
}

const SUPPORTED_FORMATS = ["PNG", "JPEG", "JPG", "BMP", "TIFF", "GIF"];

export default function Converter() {
  const [files, setFiles] = useState<FileStatus[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [notification, setNotification] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Limpa notificação após 5 segundos
  useEffect(() => {
    if (notification) {
      const timer = setTimeout(() => setNotification(null), 5000);
      return () => clearTimeout(timer);
    }
  }, [notification]);

  const addFiles = (newFiles: FileList | null) => {
    if (!newFiles) return;
    const mapped: FileStatus[] = Array.from(newFiles).map((file) => ({
      file,
      id: Math.random().toString(36).substring(7),
      progress: 0,
      status: "idle",
    }));
    setFiles((prev) => [...prev, ...mapped]);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    addFiles(e.dataTransfer.files);
  };


  const convertToWebP = async (fileStatus: FileStatus) => {
    if (fileStatus.status === "done") return;

    setFiles((prev) =>
      prev.map((f) =>
        f.id === fileStatus.id ? { ...f, status: "converting", progress: 30 } : f
      )
    );

    try {
      const img = new Image();
      img.src = URL.createObjectURL(fileStatus.file);
      await new Promise((resolve, reject) => {
        img.onload = resolve;
        img.onerror = reject;
      });

      const canvas = document.createElement("canvas");
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("Não foi possível obter o contexto do canvas");

      ctx.drawImage(img, 0, 0);

      setFiles((prev) =>
        prev.map((f) =>
          f.id === fileStatus.id ? { ...f, progress: 70 } : f
        )
      );

      const blob = await new Promise<Blob | null>((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error("Timeout na conversão")), 15000);
        canvas.toBlob((b) => {
          clearTimeout(timeout);
          resolve(b);
        }, "image/webp", 0.85);
      });

      if (!blob) throw new Error("Falha na conversão");

      const fileName = fileStatus.file.name.replace(/\.[^/.]+$/, "") + ".webp";
      const resultUrl = URL.createObjectURL(blob);

      setFiles((prev) =>
        prev.map((f) =>
          f.id === fileStatus.id
            ? { ...f, status: "done", progress: 100, resultUrl, resultSize: blob.size }
            : f
        )
      );

      // Se todas as imagens que estavam em processamento acabaram, mostra notificação
      checkAllDone();
    } catch (err: any) {
      setFiles((prev) =>
        prev.map((f) =>
          f.id === fileStatus.id
            ? { ...f, status: "error", error: err.message }
            : f
        )
      );
    }
  };

  const checkAllDone = () => {
    // Usamos um timeout pequeno para garantir que o estado 'files' tenha atualizado
    setTimeout(() => {
      setFiles((currentFiles) => {
        const convertingCount = currentFiles.filter(f => f.status === "converting").length;
        const doneCount = currentFiles.filter(f => f.status === "done").length;
        if (convertingCount === 0 && doneCount > 0) {
          setNotification(`Sucesso! ${doneCount} imagens convertidas.`);
        }
        return currentFiles;
      });
    }, 100);
  };

  const startAll = () => {
    const toProcess = files.filter((f) => f.status === "idle");
    if (toProcess.length === 0) return;
    toProcess.forEach(convertToWebP);
  };

  const downloadAll = () => {
    files.filter((f) => f.status === "done").forEach((f) => {
      const a = document.createElement("a");
      a.href = f.resultUrl!;
      a.download = f.file.name.replace(/\.[^/.]+$/, "") + ".webp";
      a.click();
    });
  };

  const removeFile = (id: string) => {
    setFiles((prev) => prev.filter((f) => f.id !== id));
  };

  const anyDone = files.some(f => f.status === "done");
  const anyIdle = files.some(f => f.status === "idle");

  return (
    <div className="converter-container">
      {notification && (
        <div className="notification-toast gradient-success">
          {notification}
        </div>
      )}

      <div
        className={`upload-zone glass-card ${isDragging ? "dragging" : ""}`}
        onDragOver={(e) => { e.preventDefault(); setIsDragging(true); }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <input
          type="file"
          multiple
          ref={fileInputRef}
          onChange={(e) => addFiles(e.target.files)}
          style={{ display: "none" }}
          accept="image/*"
        />
        <div className="upload-content">
          <div className="upload-icon">⚡</div>
          <h3>Arraste suas imagens aqui</h3>
          <p>ou clique para selecionar arquivos</p>
          <div className="supported-formats">
            Formatos suportados: {SUPPORTED_FORMATS.join(", ")}
          </div>
        </div>
      </div>


      {files.length > 0 && (
        <div className="file-list-container">
          <div className="actions">
            {anyIdle && (
              <button className="btn gradient-bg" onClick={startAll}>
                {files.length === 1 ? "Converter" : "Converter Tudo"}
              </button>
            )}
            {anyDone && (
              <button className="btn gradient-success enabled" onClick={downloadAll}>
                {files.filter(f => f.status === "done").length === 1 ? "Baixar (WebP)" : "Baixar Todos (WebP)"}
              </button>
            )}
            <button className="btn danger" onClick={() => { setFiles([]); setNotification(null); }}>
              Limpar
            </button>
          </div>

          <div className="file-grid">
            {files.map((f) => (
              <div key={f.id} className="file-card glass-card">
                <div className="file-info">
                  <div className="file-name">{f.file.name}</div>
                  <div className="file-sizes">
                    <span className="size-label">Original: {(f.file.size / 1024).toFixed(1)} KB</span>
                    {f.resultSize && (
                      <span className="size-result">
                        → WebP: {(f.resultSize / 1024).toFixed(1)} KB
                        <span className="savings">
                          (-{Math.round((1 - f.resultSize / f.file.size) * 100)}%)
                        </span>
                      </span>
                    )}
                  </div>
                </div>

                <div className="progress-bar-bg">
                  <div
                    className={`progress-bar-fill ${f.status === 'done' ? 'gradient-success' : 'gradient-bg'}`}
                    style={{ width: `${f.progress}%` }}
                  ></div>
                </div>

                <div className="file-actions">
                  {f.status === "done" && f.resultUrl ? (
                    <a
                      href={f.resultUrl}
                      download={f.file.name.replace(/\.[^/.]+$/, "") + ".webp"}
                      className="btn-download-green"
                    >
                      Baixar WebP
                    </a>
                  ) : f.status === "idle" ? (
                    <button onClick={() => convertToWebP(f)} className="btn-small">Processar</button>
                  ) : f.status === "converting" ? (
                    <span className="status-tag">Convertendo...</span>
                  ) : null}
                  <button onClick={() => removeFile(f.id)} className="btn-icon">×</button>
                </div>
                {f.status === "error" && <p className="error-text">{f.error}</p>}
              </div>
            ))}
          </div>
        </div>
      )}

      <style jsx>{`
        .converter-container {
          width: 100%;
          max-width: 800px;
          margin: 0 auto;
          position: relative;
        }
        .notification-toast {
          position: fixed;
          top: 20px;
          right: 20px;
          padding: 16px 24px;
          border-radius: 12px;
          color: white;
          font-weight: 400;
          z-index: 1000;
          box-shadow: 0 10px 40px rgba(0,0,0,0.8);
          animation: slideInRight 0.3s ease-out;
        }
        .upload-zone {
          padding: 60px;
          text-align: center;
          cursor: pointer;
          transition: all 0.3s ease;
          border: 1px dashed var(--border-color);
          margin-bottom: 20px;
          background: rgba(255, 255, 255, 0.02);
          border-radius: 24px;
        }
        .upload-zone:hover, .upload-zone.dragging {
          border-color: #ffffff;
          background: rgba(255, 255, 255, 0.05);
          transform: translateY(-2px);
        }
        .supported-formats {
          margin-top: 15px;
          font-size: 12px;
          color: rgba(255, 255, 255, 0.4);
          font-weight: 500;
          letter-spacing: 0.5px;
        }
        .folder-selection {
          margin-bottom: 40px;
          text-align: center;
        }
        .hint {
          font-size: 11px;
          color: rgba(255, 255, 255, 0.3);
          margin-top: 6px;
        }
        .file-list-container {
          animation: fadeIn 0.5s ease;
        }
        .actions {
          display: flex;
          gap: 12px;
          margin-bottom: 24px;
          justify-content: center;
        }
        .file-grid {
          display: grid;
          grid-template-columns: 1fr;
          gap: 16px;
        }
        .file-card {
          padding: 16px 20px;
          display: flex;
          align-items: center;
          gap: 20px;
        }
        .file-info {
          flex: 1;
          display: flex;
          flex-direction: column;
          gap: 4px;
        }
        .file-name {
          font-weight: 300;
          font-size: 15px;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          max-width: 200px;
        }
        .file-sizes {
          display: flex;
          flex-direction: column;
          font-size: 11px;
          line-height: 1.4;
        }
        .size-label {
          color: rgba(255, 255, 255, 0.3);
        }
        .size-result {
          color: #00c853;
          font-weight: 500;
        }
        .savings {
          margin-left: 6px;
          background: rgba(0, 200, 83, 0.1);
          padding: 1px 6px;
          border-radius: 10px;
          font-size: 10px;
        }
        .progress-bar-bg {
          flex: 2;
          height: 4px;
          background: rgba(255, 255, 255, 0.05);
          border-radius: 2px;
          overflow: hidden;
        }
        .btn {
          padding: 10px 24px;
          border-radius: 30px;
          border: none;
          color: white;
          font-weight: 700;
          cursor: pointer;
          transition: all 0.2s;
        }
        .btn.gradient-bg {
          color: #000000;
          font-weight: 700;
        }
        .btn:hover {
          opacity: 0.9;
          transform: translateY(-1px);
        }
        .btn.outline {
          background: rgba(255, 255, 255, 0.05);
          border: 1px solid var(--border-color);
          color: rgba(255, 255, 255, 0.8);
        }
        .btn.outline:hover {
          border-color: #ffffff;
          color: #ffffff;
          background: rgba(255, 255, 255, 0.1);
        }
        .btn.danger {
          background: transparent;
          color: rgba(255, 77, 77, 0.5);
          font-size: 12px;
          opacity: 0.8;
        }
        .btn.danger:hover {
          color: #ff4d4d;
          opacity: 1;
        }
        .btn.enabled:hover {
          box-shadow: var(--green-shadow);
        }
        .btn-download-green {
          background: var(--grad-success);
          color: white;
          padding: 6px 16px;
          border-radius: 20px;
          font-weight: 500;
          font-size: 12px;
          text-decoration: none;
          transition: all 0.2s;
          display: inline-block;
        }
        .btn-download-green:hover {
          transform: scale(1.02);
          box-shadow: 0 0 35px rgba(0, 200, 83, 0.5);
        }
        .btn-small {
          background: rgba(255, 255, 255, 0.1);
          border: none;
          color: #ffffff;
          font-weight: 400;
          font-size: 11px;
          padding: 6px 14px;
          border-radius: 20px;
          cursor: pointer;
        }
        .status-tag {
          font-size: 11px;
          color: rgba(255, 255, 255, 0.4);
          font-weight: 300;
        }
        .btn-icon {
          background: transparent;
          border: none;
          color: rgba(255, 255, 255, 0.4);
          font-size: 24px;
          cursor: pointer;
          padding: 0 10px;
        }
        @keyframes slideInRight {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        @keyframes fadeIn {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
      `}</style>
    </div>
  );
}
