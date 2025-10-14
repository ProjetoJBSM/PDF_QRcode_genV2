# PDF QRCode Generator V2

Aplicação Vue 3 + Vite para geração de PDFs com QR Codes em lote.

## Funcionalidades

- ✅ Geração de múltiplos QR Codes a partir de uma lista de URLs
- ✅ Suporte para template de fundo (PDF, PNG ou JPG)
- ✅ Configuração completa de posicionamento e tamanho do QR Code
- ✅ Níveis de correção de erro (ECC) ajustáveis
- ✅ Opção de renderizar texto da URL abaixo do QR Code
- ✅ Processamento 100% no navegador (sem servidor)
- ✅ Suporte para tamanhos de página personalizados (A4, Letter, Custom)

## Instalação

```bash
npm install
```

## Desenvolvimento

```bash
npm run dev
```

## Build para Produção

```bash
npm run build
```

## Preview da Build

```bash
npm run preview
```

## Tecnologias Utilizadas

- **Vue 3** - Framework JavaScript progressivo
- **Vite** - Build tool e dev server
- **pdf-lib** - Manipulação de PDFs no navegador
- **qrcodejs** - Geração de QR Codes

## Como Usar

1. Cole as URLs (uma por linha) no campo de texto
2. Opcionalmente, faça upload de um template de fundo (PDF ou imagem)
3. Configure o tamanho e posição do QR Code
4. Ajuste as configurações de renderização
5. Clique em "Gerar PDF"
6. Faça o download do PDF gerado

## Estrutura do Projeto

```
PDF_QRcode_genV2/
├── src/
│   ├── App.vue          # Componente principal
│   ├── main.js          # Entry point
│   └── style.css        # Estilos globais
├── index.html           # HTML base
├── package.json         # Dependências
├── vite.config.js       # Configuração do Vite
└── README.md           # Este arquivo
```
