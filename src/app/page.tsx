"use client";

import Converter from "@/components/Converter";

export default function Home() {
  return (
    <main className="main-container">
      <header className="hero">
        <h1 className="gradient-text">Flashp</h1>
        <p className="subtitle">Conversor de Imagens de Alta Performance & Privado</p>
      </header>

      <section className="content">
        <Converter />
      </section>

      <footer className="footer">
        <p>&copy; 2026 Flashp. Suas imagens nunca saem do seu navegador.</p>
      </footer>

      <style jsx>{`
        .main-container {
          min-height: 100vh;
          padding: 40px 20px;
          display: flex;
          flex-direction: column;
          align-items: center;
          background: radial-gradient(circle at top, #111111 0%, #000000 100%);
        }
        .hero {
          text-align: center;
          margin-bottom: 60px;
          animation: slideDown 0.8s ease-out;
        }
        .hero h1 {
          font-size: 84px;
          font-weight: 300;
          letter-spacing: -3px;
          margin-bottom: 12px;
        }
        .subtitle {
          font-size: 20px;
          color: rgba(255, 255, 255, 0.4);
          font-weight: 300;
          letter-spacing: 1px;
        }
        .content {
          width: 100%;
          flex: 1;
        }
        .footer {
          margin-top: 80px;
          padding: 20px;
          color: rgba(255, 255, 255, 0.3);
          font-size: 14px;
        }
        @keyframes slideDown {
          from { opacity: 0; transform: translateY(-30px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @media (max-width: 768px) {
          .hero h1 {
            font-size: 48px;
          }
          .subtitle {
            font-size: 16px;
          }
        }
      `}</style>
    </main>
  );
}


