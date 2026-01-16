---
priority: high
domain: image_processing
dependencies: []
conflicts_with: []
last_updated: 2026-01-16
---

# Desenvolvimento do Flashp PWA

## Goal
Manter e expandir o conversor de imagens Flashp, garantindo privacidade (client-side) e estética premium (monocromática).

## Success Criteria
- [ ] Conversões ocorrem 100% no navegador (Canvas API).
- [ ] Interface segue o padrão Branco/Preto com fontes suaves (Outfit/Inter peso 300).
- [ ] Suporte a múltiplos formatos (PNG, JPG, BMP, etc) para WebP.
- [x] Funcionalidade de download via fluxo nativo do navegador (Simplicidade > Complexidade).

## Inputs
- Imagens de diversos formatos.
- Configurações de qualidade (atualmente fixas em 0.85).

## Execution Steps
1. Modificar `src/components/Converter.tsx` para ajustes de lógica ou UI.
2. Atualizar `src/app/globals.css` para mudanças globais de design.
3. Validar mudanças via `npm run dev` e testes manuais de conversão.

## Edge Cases
- Navegadores sem suporte a `showDirectoryPicker` (ex: Safari, Firefox).
- Imagens muito grandes que podem estourar a memória do Canvas.
- Timeouts em conversões complexas (implementado limite de 15s).

## Learnings
- 2026-01-15: Implementado timeout e sistema de fallback para evitar travamentos no `canvas.toBlob`.
- 2026-01-15: Descoberta a necessidade de verificar permissões em diretórios, mas optou-se por remover a função em favor do download nativo para melhor UX.
- 2026-01-15: Implementados rótulos dinâmicos (singular/plural) e tipografia bold para melhorar a semântica visual dos botões de ação.
- 2026-01-15: Refinamento estético: uso de gradientes Verde para Verde Escuro (sem preto/amarelo) para representar sucesso de forma sóbria.
- 2026-01-15: Adicionada visualização comparativa de tamanhos (Antes/Depois) com cálculo de economia percentual.
- 2026-01-16: Criado script `execution/flashp_install.sh` para automação de deploy multi-plataforma (Bare Metal, Docker, Coolify, Easypanel).
- 2026-01-16: Implementada detecção de infraestrutura híbrida e lógica de domínio global para simplificar fluxos de instalação.
- 2026-01-16: Centralizada configuração de containers no arquivo `docker-compose.example.yml` para evitar redundâncias na documentação e scripts.
