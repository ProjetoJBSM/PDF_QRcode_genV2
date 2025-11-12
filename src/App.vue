<template>
  <div>
    <h1>Client-side QR Batch → PDF</h1>
    <p class="hint">
      Cole URLs (uma por linha), escolha um template (imagem ou PDF opcional), defina a posição/tamanho do QR e gere um PDF com uma página por URL — tudo no navegador.
    </p>

  <div class="main-layout" :class="{ 'loader-view': view === 'loader' }">
  <form @submit.prevent class="form-section" :class="{ 'form-section--fullscreen': view === 'loader' }">
      <fieldset v-if="view === 'loader'">
        <legend>Dados</legend>

        <!-- Left column: settings -->
          <div class="loader-left">
            <!-- Tab Navigation -->
            <div class="tab-navigation">
              <button 
                type="button" 
                class="tab-button" 
                :class="{ active: activeTab === 'manual' }"
                @click="activeTab = 'manual'"
              >
                Geração Manual
              </button>
              <button 
                type="button" 
                class="tab-button" 
                :class="{ active: activeTab === 'batch' }"
                @click="activeTab = 'batch'"
              >
                Geração em Batch
              </button>
            </div>

            <!-- Manual Generation Tab -->
            <div v-show="activeTab === 'manual'" class="tab-content">
              <label>
                Conteúdo do QR Code
                <textarea
                  v-model="manualInput"
                  placeholder="Digite a URL ou texto para o QR Code&#10;Exemplo: https://example.com"
                  rows="3"
                ></textarea>
              </label>
              <p class="small" style="margin-top: 0.5rem; color: #666;">
                Insira uma URL ou texto para gerar um único QR Code. Será gerado um PDF de uma página.
              </p>
            </div>

            <!-- Batch Generation Tab -->
            <div v-show="activeTab === 'batch'" class="tab-content">
              <label class="template-control template-file">
                Carregar arquivo CSV
                <input
                  ref="csvFileInput"
                  type="file"
                  accept=".csv"
                  @change="handleCsvUpload"
                />
                <span v-if="csvFileName" class="csv-info small">
                  Arquivo carregado: <strong>{{ csvFileName }}</strong> ({{ csvData.length }} linhas)
                </span>
              </label>

              <div v-if="csvData.length > 0" class="csv-column-select" style="margin-top: 1rem;">
                <label for="qrColumnSelect" style="font-weight: 600;">
                  1. Selecione a coluna para o QR Code:
                </label>
                <select id="qrColumnSelect" v-model="qrDataColumn" style="width: 100%; margin-top: 0.25rem;">
                  <option :value="null" disabled>-- Escolha a coluna com as URLs/textos --</option>
                  <option v-for="col in csvPreviewColumns" :key="col" :value="col">
                    {{ col }}
                  </option>
                </select>
                <p v-if="!qrDataColumn" class="small" style="color: #dc3545; margin-top: 0.25rem;">
                  ⚠️ É necessário selecionar uma coluna para continuar.
                </p>
              </div>

              <!-- Range selection for batch rows -->
              <div v-if="csvData.length > 0" class="range-selection" style="margin-top:1rem;">
                <label style="font-weight:600; display:block;">Linhas para gerar (ex.: 1-10,14,18-22)</label>
                <div style="display:flex; gap:0.5rem; align-items:center; margin-top:0.5rem;">
                  <input type="text" v-model="rangeSpec" placeholder="1-10,14,18-22" style="flex:1; min-width:0; padding:8px;" />
                  <button type="button" class="secondary" @click="setRangeAll">Todas</button>
                </div>
                <p class="small" style="margin-top:0.25rem; color:#666;">Use sintaxe de intervalo (impressão): <code>1-10,14,18-22</code>. Valores baseados em 1 (primeira linha = 1). Use <code>all</code> ou deixe vazio para todas.</p>
                <p v-if="rangeError" class="small" style="color:#dc3545; margin-top:0.25rem;">{{ rangeError }}</p>
              </div>

              <p class="small" style="margin-top: 0.5rem; color: #666;">
                Para gerar ZIP com nomes personalizados, adicione também a coluna <strong>"nome_arquivo"</strong>.
              </p>
              
              <label class="export-option-label" style="margin-top: 1rem;">
                Formato de Saída
                <select v-model="exportOption">
                  <option value="single_pdf">PDF Único com várias páginas</option>
                  <option value="multiple_pdfs_zip">ZIP com um PDF por página</option>
                </select>
              </label>
            </div>

            <div style="margin-top:1rem; display:flex; gap:0.5rem; align-items:center;">
              <button type="button" class="primary" @click="goToEditor">Editar Template →</button>
              <button type="button" class="secondary" @click="clearCsvData">Limpar CSV</button>
            </div>
          </div>
      </fieldset>
      <!-- (button removed - moved inside loader left column to avoid duplication) -->

      <div v-if="view === 'editor'">
        <div class="editor-topbar" style="display:flex; align-items:center; gap:0.5rem; margin-bottom:0.75rem;">
          <button type="button" class="secondary" @click="backToLoader">← Voltar — Dados</button>
          <h3 style="margin:0; font-size:1rem; color:#333;">Editor de Template</h3>
        </div>

        <div class="template-controls-row">
          <label class="template-control template-file">
            Template de fundo opcional (PDF, PNG ou JPG)
            <input
              type="file"
              accept="application/pdf,image/png,image/jpeg"
              @change="handleTemplateFile"
              ref="templateFileInput"
            />
          </label>
          <label class="template-control template-rotate">
            Rotacionar
            <button type="button" class="rotate-btn-square" @click="rotatePage">
              ↺
            </button>
          </label>
        </div>

        <div class="page-controls-row" v-if="!state.templateType || state.templateType !== 'pdf'">
          <label class="page-control page-size">
            Tamanho da página
            <select v-model="pageSize">
              <option value="A4">A4</option>
              <option value="Letter">Letter</option>
              <option value="Custom">Personalizado…</option>
            </select>
          </label>
          <label v-if="pageSize === 'Custom'" class="page-control page-dimension">
            Largura (pt)
            <input v-model.number="customW" type="number" min="100" />
          </label>
          <label v-if="pageSize === 'Custom'" class="page-control page-dimension">
            Altura (pt)
            <input v-model.number="customH" type="number" min="100" />
          </label>
          <label v-if="!state.templateType" class="page-control page-bg-color">
            Cor de fundo
            <input v-model="backgroundColor" type="color" />
          </label>
        </div>

      <fieldset>
        <legend>Configurações do QR Code</legend>
        
        <!-- Basic QR Settings - Always Visible -->
        <div class="qr-basic-settings">
          <div class="qr-controls-row">
                <label class="qr-control qr-size">
                  Tamanho do QR (pt)
                  <div style="display:flex; gap:0.5rem; align-items:center;">
                    <input v-model.number="qrSize" type="range" min="30" max="1000" step="1" @input="onSliderChange" @change="generatePreview" />
                    <span class="small">{{ qrSize }} pt</span>
                  </div>
                </label>
                <label class="qr-control qr-position">
                  Posição X - Esquerda (pt)
                  <div style="display:flex; gap:0.5rem; align-items:center;">
                    <input v-model.number="posX" type="range" min="0" max="2000" step="1" @input="onSliderChange" @change="generatePreview" />
                    <span class="small">{{ posX }} pt</span>
                  </div>
                </label>
                <label class="qr-control qr-position">
                  Posição Y - Topo (pt)
                  <div style="display:flex; gap:0.5rem; align-items:center;">
                    <input v-model.number="posY" type="range" min="0" max="2000" step="1" @input="onSliderChange" @change="generatePreview" />
                    <span class="small">{{ posY }} pt</span>
                  </div>
                </label>
            <label class="qr-text-control qr-color">
              Cor do QR Code
              <input v-model="qrColor" type="color" />
            </label>
            <label class="qr-text-control qr-checkbox-wrapper">
              <span class="checkbox-label-text">Fundo branco</span>
              <input v-model="qrBackground" type="checkbox" class="qr-checkbox" />
            </label>
          </div>
          <p class="small" style="margin-top: 0.5rem;">
            Dica: 72 pt ≈ 1 polegada; 1 mm ≈ 2.835 pt. A4 = 595×842 pt.
          </p>
        </div>

        <!-- Advanced Settings Toggle Button -->
        <div class="advanced-toggle">
          <button 
            type="button" 
            class="advanced-toggle-btn" 
            @click="showAdvancedQR = !showAdvancedQR"
          >
            {{ showAdvancedQR ? '▼' : '▶' }} Configurações Avançadas
          </button>
        </div>

        <!-- Advanced QR Settings - Collapsible -->
        <div v-show="showAdvancedQR" class="qr-advanced-settings">
          <div class="qr-controls-row">
            <label class="qr-control qr-ecc">
              Nível ECC (Correção de Erros)
              <select v-model="ecc">
                <option value="L">L - Baixo (7%)</option>
                <option value="M">M - Médio (15%)</option>
                <option value="Q">Q - Alto (25%)</option>
                <option value="H">H - Muito Alto (30%)</option>
              </select>
            </label>
            <label class="qr-control qr-margin">
              Zona quieta (módulos)
              <input v-model.number="margin" type="number" min="0" />
            </label>
          </div>
        </div>

      </fieldset>

      <fieldset>
        <legend>Campos de Texto</legend>
        <div class="text-fields-header">
          <p class="small">Adicione campos de texto personalizados ao PDF</p>
          <button type="button" class="add-field-btn" @click="addTextField">
            + Adicionar Campo de Texto
          </button>
        </div>

        <div v-if="textFields.length === 0" class="no-fields">
          <p class="small">Nenhum campo de texto adicionado ainda.</p>
        </div>

        <div v-for="(field, index) in textFields" :key="field.id" class="text-field-item">
          <div class="field-header">
            <strong>Campo {{ index + 1 }}</strong>
            <button type="button" class="remove-field-btn" @click="removeTextField(index)">Remover</button>
          </div>

          <label>
            Texto
            <input v-model="field.text" :disabled="field.useColumn" type="text" placeholder="Digite o texto aqui..." />
          </label>

          <div style="margin-top:0.5rem; display:flex; gap:0.5rem; align-items:center;">
            <label style="display:flex; align-items:center; gap:0.35rem;">
              <input type="checkbox" v-model="field.useColumn" /> Usar coluna CSV
            </label>
            <select v-if="field.useColumn" v-model="field.bindColumn" style="padding:4px 8px;">
              <option :value="null">-- selecione coluna --</option>
              <option v-for="col in csvPreviewColumns" :key="col" :value="col">{{ col }}</option>
            </select>
            <div class="small">Ex.: {{ csvData[0] && field.bindColumn ? csvData[0][field.bindColumn] : '-' }}</div>
          </div>

            <div class="text-field-controls">
            <label class="control-item control-flex">
              Esquerda (pt)
              <div style="display:flex; gap:0.5rem; align-items:center;">
                <input v-model.number="field.x" type="range" min="0" max="2000" step="1" @input="onSliderChange" @change="generatePreview" />
                <span class="small">{{ field.x || 0 }}</span>
              </div>
            </label>
            <label class="control-item control-flex">
              Topo (pt)
              <div style="display:flex; gap:0.5rem; align-items:center;">
                <input v-model.number="field.y" type="range" min="0" max="2000" step="1" @input="onSliderChange" @change="generatePreview" />
                <span class="small">{{ field.y || 0 }}</span>
              </div>
            </label>
            <label class="control-item control-font">
              Família da Fonte
              <select v-model="field.fontFamily">
                <optgroup label="Fontes Padrão">
                  <option value="Helvetica">Helvetica</option>
                  <option value="Times">Times Roman</option>
                  <option value="Courier">Courier</option>
                </optgroup>
                <optgroup v-if="customFonts.length > 0" label="Fontes Carregadas">
                  <option v-for="font in customFonts" :key="font.name" :value="font.name">{{ font.name }}</option>
                </optgroup>
              </select>
            </label>
            <label class="control-item control-flex">
              Tamanho (pt)
              <div style="display:flex; gap:0.5rem; align-items:center;">
                <input v-model.number="field.size" type="number" min="6" step="1" @change="generatePreview" />
              </div>
            </label>
            <label class="control-item control-color">
              Cor
              <input v-model="field.color" type="color" />
            </label>
            <label class="control-item control-format">
              Formatação
              <div class="format-buttons">
                <button type="button" class="format-btn" :class="{ active: field.bold }" @click="field.bold = !field.bold" title="Negrito"><strong>B</strong></button>
                <button type="button" class="format-btn" :class="{ active: field.italic }" @click="field.italic = !field.italic" title="Itálico"><em>I</em></button>
                <button type="button" class="format-btn" :class="{ active: field.underline }" @click="field.underline = !field.underline" title="Sublinhado"><span style="text-decoration: underline;">U</span></button>
              </div>
            </label>
          </div>
        </div>
      </fieldset>

      <fieldset>
        <legend>Fontes Customizadas</legend>
        <p class="small" style="margin-bottom: 1rem; color: #666;">
          Carregue arquivos de fonte .ttf ou .otf. 
          <strong>Nota:</strong> Cada arquivo contém apenas uma variante (regular, negrito, itálico). 
          Os botões de formatação não funcionam com fontes customizadas.
        </p>

        <div class="upload-font">
          <label class="upload-font-btn">
            Carregar Arquivo .ttf/.otf
            <input 
              type="file" 
              accept=".ttf,.otf" 
              @change="loadCustomFontFile"
              style="display: none;"
            />
          </label>
        </div>

        <div v-if="fontLoading" class="font-loading">
          <span class="small">Carregando fonte...</span>
        </div>

        <div v-if="fontLoadError" class="font-error">
          <span class="small">{{ fontLoadError }}</span>
        </div>

        <div v-if="customFonts.length > 0" class="custom-fonts-list">
          <label class="small" style="font-weight: 600; margin-bottom: 0.5rem; display: block;">
            Fontes Carregadas ({{ customFonts.length }}):
          </label>
          <div 
            v-for="(font, index) in customFonts" 
            :key="font.name" 
            class="custom-font-item"
          >
            <span class="font-name">
              {{ font.name }}
            </span>
            <button 
              type="button" 
              class="remove-font-btn" 
              @click="removeCustomFont(index)"
              title="Remover fonte"
            >
              x
            </button>
          </div>
        </div>

        <div v-else class="no-fonts">
          <p class="small">Nenhuma fonte customizada carregada ainda.</p>
        </div>
      </fieldset>

        <div v-if="templateInfo" class="template-info">
          {{ templateInfo }}
        </div>
        <div class="config-actions">
          <button 
            type="button" 
            class="secondary" 
            @click="exportConfiguration"
            title="Exportar todas as configurações do template"
          >
            📥 Exportar Configurações
          </button>
          <label class="secondary import-btn">
            📤 Importar Configurações
            <input 
              type="file" 
              accept=".json"
              @change="importConfiguration"
              style="display: none;"
            />
          </label>
        </div>
        <div class="actions" v-if="view === 'editor'">
          <button class="primary" type="button" @click="startGeneration">
            {{ getGenerateButtonText() }}
          </button>
          <a
            v-if="downloadUrl"
            :href="downloadUrl"
            :download="exportOption === 'single_pdf' ? 'qrs.pdf' : 'qrs.zip'"
          >
            Download {{ exportOption === 'single_pdf' ? 'PDF' : 'ZIP' }} ({{ urlCount }} {{ urlCount > 1 ? 'páginas' : 'página' }}/arquivos)
          </a>
          <span class="small">{{ status }}</span>
        </div>
      </div>
      </form>

      <!-- CSV preview shown in the right column when on loader view -->
      <div v-if="view === 'loader'" class="loader-preview-column">
        <div v-if="csvData.length" class="csv-preview" style="margin-top:0;">
          <div class="small" style="margin-bottom:0.5rem; display:flex; align-items:center; justify-content:space-between; gap:0.5rem;">
            <div>Preview do CSV — mostrando primeiras {{ csvPreviewRows.length }} linhas ({{ selectedCsvData.length }} no total)</div>
            <div style="display:flex; align-items:center; gap:0.5rem;">
              <label class="small" style="display:flex; align-items:center; gap:0.35rem;">Mostrar
                <select v-model.number="previewCount" style="font-size:0.9rem; padding:2px 6px;">
                  <option :value="5">5</option>
                  <option :value="10">10</option>
                  <option :value="25">25</option>
                  <option :value="50">50</option>
                  <option :value="100">100</option>
                </select>
              </label>
            </div>
          </div>
          <div class="csv-table-wrapper" style="overflow:auto; max-width:100%; border:1px solid #e3e3e3; border-radius:4px;">
            <table style="border-collapse:collapse; width:100%; min-width:400px;">
              <thead style="background:#fafafa;">
                <tr>
                  <th v-for="col in csvPreviewColumns" :key="col" style="text-align:left; padding:6px 8px; border-bottom:1px solid #eee;">{{ col }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(r, idx) in csvPreviewRows" :key="idx">
                  <td v-for="col in csvPreviewColumns" :key="col + '-' + idx" style="padding:6px 8px; border-bottom:1px solid #f5f5f5;">{{ r[col] }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-if="csvPreviewRemaining > 0" class="small" style="margin-top:0.4rem; color:#666;">... e mais {{ csvPreviewRemaining }} linhas</div>
        </div>
        <div v-else class="csv-empty-placeholder" style="padding:1rem; color:#666;">Nenhum CSV carregado — carregue um arquivo para visualizar</div>
      </div>

      <!-- Live Preview Section (only in editor view) -->
      <div class="preview-section" v-if="view === 'editor'">
        <h2>Pré-visualização em Tempo Real</h2>
        <div class="preview-info">
          <span class="small">Primeira página • Atualiza automaticamente  •  Ctrl + rolagem do mouse para zoom na página</span>
        </div>
        <div class="preview-container">
          <!-- Live DOM preview: lightweight layout-only rendering for snappy feedback -->
          <div ref="livePreviewContainer" class="live-preview-wrapper" style="width:100%; display:flex; justify-content:center;">
            <div v-if="!canShowLivePreview" class="preview-placeholder">
              <p>A pré-visualização aparecerá aqui</p>
              <p class="small">Cole pelo menos uma URL ou carregue um CSV para começar</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Hidden holder for QR generation -->
    <div ref="qrHolder" style="position: absolute; left: -9999px; top: -9999px;"></div>
  </div>
</template>

<script setup>
import { ref, watch, watchEffect, computed } from 'vue'
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib'
import fontkit from '@pdf-lib/fontkit'
import Papa from 'papaparse'
import JSZip from 'jszip'
import './style.css'

// Algumas builds do pacote 'qrcodejs' (npm) não expõem a propriedade "CorrectLevel".
// Definimos manualmente o mapeamento de níveis ECC conforme implementação original:
// L = 1, M = 0, Q = 3, H = 2
// (ordem interna é diferente do esperado mas corresponde à lib qrcodejs)
const QR_CORRECT_LEVEL = { L: 1, M: 0, Q: 3, H: 2 }

// Debounce helper
let previewTimeout = null

// Quick slider debounce interval (ms) — small for snappy feedback
const SLIDER_DEBOUNCE_MS = 80

// Data refs
const activeTab = ref('manual') // 'manual' or 'batch'
const manualInput = ref('') // Input for manual generation
const urls = ref('') // Kept for backward compatibility with batch
const csvData = ref([]) //teste de correcao
const csvFileName = ref('')
const previewCount = ref(50)
const qrDataColumn = ref(null)
const rangeSpec = ref('')
const rangeError = ref('')
const previewSelectedOnly = ref(true)
const pageSize = ref('A4')
const pageRotation = ref(0) // 0, 90, 180, 270
const customW = ref(595)
const customH = ref(842)
const backgroundColor = ref('#FFFFFF')

watch(urls, (newUrls) => { //limpa o CSV se o usuario digitar no text area
  if (newUrls && newUrls.length > 0 && csvData.value.length > 0) {
    csvData.value = [];
    csvFileName.value = '';
    //reseta a opção de exportação para o padrão
    exportOption.value = 'single_pdf';
  }
});

// QR placement refs
const qrSize = ref(180)
const posX = ref(60)
const posY = ref(120)
const ecc = ref('M')
const margin = ref(4)
const renderText = ref('no')
const fontSize = ref(12)
const maxChars = ref(64)
const qrColor = ref('#000000')
const qrBackground = ref(true)

// Template state
const templateFileInput = ref(null)
const templateInfo = ref('')
const state = ref({
  templateBytes: null,
  templateType: null,
  templateImage: null,
  templatePdf: null,
})

// Text fields state
const textFields = ref([])
let textFieldIdCounter = 0
const exportOption = ref('single_pdf') //para o batch

// Custom fonts state
const customFonts = ref([])
const fontLoading = ref(false)
const fontLoadError = ref('')

// Output state
const downloadUrl = ref('')
const urlCount = ref(0)
const status = ref('')
const previewUrl = ref('')
const livePreviewContainer = ref(null)
const canShowLivePreview = computed(() => {
  // show live preview when we have at least one data source (manual or csv)
  return (
    (activeTab.value === 'manual' && manualInput.value && manualInput.value.trim()) ||
    (activeTab.value === 'batch' && csvData.value && csvData.value.length > 0)
  )
})

// UI state
const showAdvancedQR = ref(false)

// Hidden QR holder
const qrHolder = ref(null)

// View state: 'loader' (CSV/manual) or 'editor' (template editor)
const view = ref('loader')

const canEnterEditor = () => {
  // Require at least one URL via manual input, legacy textarea `urls`, or CSV data
  return (
    (manualInput.value && manualInput.value.trim().length > 0) ||
    (urls.value && urls.value.trim().length > 0) ||
    (csvData.value && csvData.value.length > 0)
  )
}

const goToEditor = () => {
  if (!canEnterEditor()) {
    status.value = '⚠️ Carregue pelo menos uma URL (manual ou CSV) antes de editar o template.'
    setTimeout(() => { status.value = '' }, 3000)
    return
  }
  view.value = 'editor'
}

const backToLoader = () => {
  view.value = 'loader'
}

// CSV preview helpers
const csvPreviewColumns = computed(() => {
  if (!csvData.value || csvData.value.length === 0) return []
  return Object.keys(csvData.value[0])
})

const csvPreviewRows = computed(() => {
  if (!csvData.value || csvData.value.length === 0) return []
  // previewSelectedOnly is always true (hidden setting) — show selected rows
  const sel = selectedCsvData.value || []
  return sel.slice(0, previewCount.value)
})

const csvPreviewRemaining = computed(() => {
  const total = previewSelectedOnly.value ? (selectedCsvData.value ? selectedCsvData.value.length : 0) : (csvData.value ? csvData.value.length : 0)
  return Math.max(0, total - csvPreviewRows.value.length)
})

// Parse printing-style range spec like "1-10,14,18-22" and return selected rows
function parseRangeSpec(spec, max) {
  const out = []
  const used = new Set()
  rangeError.value = ''
  if (!spec || String(spec).trim() === '') {
    // default: all
    for (let i = 0; i < max; i++) used.add(i)
    return Array.from(used).sort((a,b)=>a-b)
  }

  const s = String(spec).trim()
  if (s === '*' || s.toLowerCase() === 'all') {
    for (let i = 0; i < max; i++) used.add(i)
    return Array.from(used).sort((a,b)=>a-b)
  }

  const parts = s.split(',')
  const errors = []
  for (let part of parts) {
    part = part.trim()
    if (!part) continue
    const m = part.match(/^(\d+)\s*-\s*(\d+)$/)
    if (m) {
      let a = parseInt(m[1], 10)
      let b = parseInt(m[2], 10)
      // interpret as 1-based ranges; convert to 0-based
      let start = Math.min(a, b) - 1
      let end = Math.max(a, b) - 1
      if (isNaN(start) || isNaN(end)) { errors.push(part); continue }
      if (end < 0 || start > max - 1) continue
      start = Math.max(0, start)
      end = Math.min(max - 1, end)
      for (let i = start; i <= end; i++) used.add(i)
    } else if (/^\d+$/.test(part)) {
      let n = parseInt(part, 10)
      let idx = n - 1 // 1-based
      if (isNaN(idx)) { errors.push(part); continue }
      if (idx < 0) idx = 0
      if (idx > max - 1) continue
      used.add(idx)
    } else {
      errors.push(part)
    }
  }

  if (errors.length > 0) {
    rangeError.value = 'Aviso: tokens inválidos ignorados: ' + errors.join(', ')
  } else {
    rangeError.value = ''
  }

  return Array.from(used).sort((a,b)=>a-b)
}

// Computed subset of CSV data based on the printing-style range spec
const selectedCsvData = computed(() => {
  if (!csvData.value || csvData.value.length === 0) return []
  const max = csvData.value.length
  const indices = parseRangeSpec(rangeSpec.value, max)
  if (!indices || indices.length === 0) return []
  return indices.map(i => csvData.value[i]).filter(Boolean)
})

// Rotate page by 90 degrees
const rotatePage = () => {
  pageRotation.value = (pageRotation.value + 90) % 360
}

// Add text field
const addTextField = () => {
  textFields.value.push({
    id: textFieldIdCounter++,
    text: '',
    x: 100,
    y: 200,
    size: 14,
    fontFamily: 'Helvetica',
    bold: false,
    italic: false,
    underline: false,
    color: '#000000',
    useColumn: false,
    bindColumn: null
  })
}

// Remove text field
const removeTextField = (index) => {
  textFields.value.splice(index, 1)
}

// Create text fields automatically from CSV columns
const createFieldsFromColumns = () => {
  const cols = csvPreviewColumns.value
  if (!cols || cols.length === 0) return
  for (const col of cols) {
    textFields.value.push({
      id: textFieldIdCounter++,
      text: '',
      x: 40,
      y: 40,
      size: 12,
      fontFamily: 'Helvetica',
      bold: false,
      italic: false,
      underline: false,
      color: '#000000',
      bindColumn: col,
      useColumn: true
    })
  }
}

// Load custom font from file upload
const loadCustomFontFile = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  fontLoading.value = true
  fontLoadError.value = ''

  try {
    const fontBytes = await file.arrayBuffer()
    const fontName = file.name.replace(/\.(ttf|otf)$/i, '')
    
    // Check if font already loaded
    if (customFonts.value.some(f => f.name === fontName)) {
      fontLoadError.value = `Fonte "${fontName}" já foi carregada.`
      fontLoading.value = false
      return
    }

    customFonts.value.push({
      name: fontName,
      bytes: new Uint8Array(fontBytes)
    })

    // Clear input
    event.target.value = ''
  } catch (err) {
    console.error(err)
    fontLoadError.value = 'Erro ao carregar fonte: ' + err.message
  } finally {
    fontLoading.value = false
  }
}

// Remove custom font
const removeCustomFont = (index) => {
  const fontName = customFonts.value[index].name
  
  // Remove from custom fonts list
  customFonts.value.splice(index, 1)
  
  // Reset any text fields using this font to Helvetica
  textFields.value.forEach(field => {
    if (field.fontFamily === fontName) {
      field.fontFamily = 'Helvetica'
    }
  })
}

// Get generate button text based on active tab and export option
const getGenerateButtonText = () => {
  if (activeTab.value === 'manual') {
    return 'Gerar QR Code'
  } else {
    return exportOption.value === 'single_pdf' 
      ? 'Gerar PDF Completo' 
      : 'Gerar Arquivo .ZIP'
  }
}
// Export configuration to JSON file
const exportConfiguration = () => {
  try {
    const config = {
      version: '1.0',
      exportDate: new Date().toISOString(),
      pageSettings: {
        pageSize: pageSize.value,
        pageRotation: pageRotation.value,
        customWidth: customW.value,
        customHeight: customH.value,
        backgroundColor: backgroundColor.value
      },
      qrSettings: {
        qrSize: qrSize.value,
        posX: posX.value,
        posY: posY.value,
        ecc: ecc.value,
        margin: margin.value,
        renderText: renderText.value,
        fontSize: fontSize.value,
        maxChars: maxChars.value,
        qrColor: qrColor.value,
        qrBackground: qrBackground.value
      },
      textFields: textFields.value.map(field => ({
        text: field.text,
        x: field.x,
        y: field.y,
        size: field.size,
        fontFamily: field.fontFamily,
        bold: field.bold,
        italic: field.italic,
        underline: field.underline,
        color: field.color,
        bindColumn: field.bindColumn || null,
        useColumn: field.useColumn || false
      })),
      customFonts: customFonts.value.map(font => ({
        name: font.name,
        // Convert Uint8Array to base64 for JSON serialization
        bytes: btoa(String.fromCharCode.apply(null, Array.from(font.bytes)))
      })),
      exportOption: exportOption.value
    }

    const json = JSON.stringify(config, null, 2)
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    
    const a = document.createElement('a')
    a.href = url
    a.download = `qr-template-config-${Date.now()}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    
    status.value = 'Configuração exportada com sucesso!'
    setTimeout(() => {
      status.value = ''
    }, 3000)
  } catch (err) {
    console.error('Erro ao exportar configuração:', err)
    status.value = 'Erro ao exportar configuração: ' + err.message
  }
}

// Import configuration from JSON file
const importConfiguration = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  try {
    const text = await file.text()  
    const config = JSON.parse(text)

    // Validate version (for future compatibility)
    if (!config.version) {
      throw new Error('Arquivo de configuração inválido: versão não encontrada')
    }

    // Restore page settings
    if (config.pageSettings) {
      pageSize.value = config.pageSettings.pageSize || 'A4'
      pageRotation.value = config.pageSettings.pageRotation || 0
      customW.value = config.pageSettings.customWidth || 595
      customH.value = config.pageSettings.customHeight || 842
      backgroundColor.value = config.pageSettings.backgroundColor || '#FFFFFF'
    }

    // Restore QR settings
    if (config.qrSettings) {
      qrSize.value = config.qrSettings.qrSize || 180
      posX.value = config.qrSettings.posX || 60
      posY.value = config.qrSettings.posY || 120
      ecc.value = config.qrSettings.ecc || 'M'
      margin.value = config.qrSettings.margin || 4
      renderText.value = config.qrSettings.renderText || 'no'
      fontSize.value = config.qrSettings.fontSize || 12
      maxChars.value = config.qrSettings.maxChars || 64
      qrColor.value = config.qrSettings.qrColor || '#000000'
      qrBackground.value = config.qrSettings.qrBackground !== undefined ? config.qrSettings.qrBackground : true
    }

    // Restore text fields
    if (config.textFields && Array.isArray(config.textFields)) {
      textFields.value = config.textFields.map(field => ({
        id: textFieldIdCounter++,
        text: field.text || '',
        x: field.x || 100,
        y: field.y || 200,
        size: field.size || 14,
        fontFamily: field.fontFamily || 'Helvetica',
        bold: field.bold || false,
        italic: field.italic || false,
        underline: field.underline || false,
        color: field.color || '#000000',
        bindColumn: field.bindColumn || null,
        useColumn: field.useColumn || false
      }))
    }

    // Restore custom fonts
    if (config.customFonts && Array.isArray(config.customFonts)) {
      customFonts.value = []
      for (const font of config.customFonts) {
        try {
          // Convert base64 back to Uint8Array
          const binaryString = atob(font.bytes)
          const bytes = new Uint8Array(binaryString.length)
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i)
          }
          
          customFonts.value.push({
            name: font.name,
            bytes: bytes
          })
        } catch (fontErr) {
          console.error(`Erro ao carregar fonte ${font.name}:`, fontErr)
        }
      }
    }

    // Restore export option
    if (config.exportOption) {
      exportOption.value = config.exportOption
    }

    // Clear file input
    event.target.value = ''

    status.value = 'Configuração importada com sucesso!'
    setTimeout(() => {
      status.value = ''
    }, 3000)
  } catch (err) {
    console.error('Erro ao importar configuração:', err)
    status.value = 'Erro ao importar configuração: ' + err.message
    event.target.value = ''
  }
}

//processar arquivo CSV
const handleCsvUpload = (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  manualInput.value = '' // Limpa o input manual
  urls.value = '' // Limpa o textarea para evitar confusão
  csvData.value = []
  csvFileName.value = ''
  status.value = ''
  qrDataColumn.value = null

  Papa.parse(file, {
    header: true,
    skipEmptyLines: true,
    complete: (results) => {
      if (results.data && results.data.length > 0 && results.meta.fields) {
        csvData.value = results.data; // Apenas carrega os dados
        csvFileName.value = file.name
        activeTab.value = 'batch'
  qrDataColumn.value = null
  // initialize range selection to full CSV (printing-style)
  rangeSpec.value = `1-${csvData.value.length}`
  rangeError.value = ''

        if (csvData.value.length > 0) {
          generatePreview()
        }
      } else {
        status.value = '⚠️ Erro: O CSV está vazio ou não possui um cabeçalho válido.' // Mensagem de erro atualizada
      }
    },
    error: (err) => {
      status.value = '⚠️ Erro ao ler o CSV: ' + err.message
    }
  })
}

// Convenience: set range to all rows
const setRangeAll = () => {
  if (csvData.value && csvData.value.length > 0) {
    rangeSpec.value = `1-${csvData.value.length}`
    rangeError.value = ''
  }
}

// Called on slider input for fast, debounced preview updates
const onSliderChange = () => {
  try {
    // immediate lightweight live preview
    try { renderLivePreview() } catch (e) { /* ignore */ }

    // debounce full PDF preview
    clearTimeout(previewTimeout)
    previewTimeout = setTimeout(() => {
      generatePreview()
    }, SLIDER_DEBOUNCE_MS)
  } catch (err) {
    // ignore
  }
}

//para limpar o espaço do csv
const csvFileInput = ref(null); // Adicione esta ref no topo do script junto com as outras
const clearCsvData = () => {

  //para limpar os dados do CSV e resetar o botao
  downloadUrl.value = '';
  urlCount.value = 0;

  csvData.value = [];
  csvFileName.value = '';
  exportOption.value = 'single_pdf';
  rangeSpec.value = ''
  rangeError.value = ''
  
  // Limpa o valor do input de arquivo para que o usuário possa carregar o mesmo arquivo novamente
  if (csvFileInput.value) {
    csvFileInput.value.value = null;
  }
};

// Handle template file upload
const handleTemplateFile = async (event) => {
  state.value = {
    templateBytes: null,
    templateType: null,
    templateImage: null,
    templatePdf: null,
  }
  templateInfo.value = ''

  const file = event.target.files?.[0]
  if (!file) return

  const buf = await file.arrayBuffer()
  state.value.templateBytes = new Uint8Array(buf)

  if (file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')) {
    state.value.templateType = 'pdf'
    const pdf = await PDFDocument.load(state.value.templateBytes)
    state.value.templatePdf = pdf
    const page = pdf.getPages()[0]
    templateInfo.value = `Template PDF carregado: ${file.name} — tamanho da página ${Math.round(page.getWidth())} × ${Math.round(page.getHeight())} pt`
  } else {
    state.value.templateType = 'image'
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      templateInfo.value = `Template de imagem carregado: ${file.name} — ${img.naturalWidth} × ${img.naturalHeight} px`
      URL.revokeObjectURL(url)
    }
    img.src = url
    state.value.templateImage = await new Promise((resolve) => {
      img.onload = () => resolve(img)
    })
  }
}

// Helper function to get page dimensions based on size and rotation
const getPageDimensions = () => {
  let baseW = 595
  let baseH = 842

  const sel = pageSize.value
  if (sel === 'Letter') {
    baseW = 612
    baseH = 792
  } else if (sel === 'Custom') {
    baseW = customW.value || 595
    baseH = customH.value || 842
  }

  // Swap dimensions if rotated 90° or 270°
  if (pageRotation.value === 90 || pageRotation.value === 270) {
    return { width: baseH, height: baseW }
  }
  return { width: baseW, height: baseH }
}

// (Removed page-based clamping — user requested unconstrained controls so values are fully editable)

// Utility: generate a recolored PNG data URL from the QR library canvas
const generateQrDataUrl = async (text, size) => {
  const holder = document.createElement('div')
  // keep offscreen
  holder.style.position = 'absolute'
  holder.style.left = '-9999px'
  holder.style.top = '-9999px'
  document.body.appendChild(holder)

  const QR = resolveQRCodeCtor()
  if (!QR) {
    document.body.removeChild(holder)
    return null
  }

  const qr = new QR(holder, {
    text: text || '',
    width: size,
    height: size,
    correctLevel: QR_CORRECT_LEVEL[ecc.value]
  })

  // allow render
  await tick()

  const canvas = holder.querySelector('canvas')
  if (!canvas) {
    document.body.removeChild(holder)
    return null
  }

  // Create a working canvas to produce transparent background and colored modules
  const tmp = document.createElement('canvas')
  tmp.width = canvas.width
  tmp.height = canvas.height
  const tctx = tmp.getContext('2d')
  tctx.clearRect(0, 0, tmp.width, tmp.height)
  tctx.drawImage(canvas, 0, 0)

  const imageData = tctx.getImageData(0, 0, tmp.width, tmp.height)
  const data = imageData.data

  // parse target color
  const hexColor = (qrColor.value || '#000000').replace('#', '')
  const rc = parseInt(hexColor.substring(0, 2), 16)
  const gc = parseInt(hexColor.substring(2, 4), 16)
  const bc = parseInt(hexColor.substring(4, 6), 16)

  for (let i = 0; i < data.length; i += 4) {
    const r = data[i]
    const g = data[i + 1]
    const b = data[i + 2]
    const a = data[i + 3]

    // If pixel is nearly white (background), make it transparent
    const isWhite = (r > 200 && g > 200 && b > 200) || a === 0
    if (isWhite) {
      if (qrBackground.value) {
        // keep white background as opaque white
        data[i] = 255
        data[i + 1] = 255
        data[i + 2] = 255
        data[i + 3] = 255
      } else {
        data[i + 3] = 0
      }
    } else {
      // dark module — recolor and ensure opaque
      data[i] = rc
      data[i + 1] = gc
      data[i + 2] = bc
      data[i + 3] = 255
    }
  }

  tctx.putImageData(imageData, 0, 0)

  // Optionally add padding for quiet zone
  const pad = Math.max(0, Math.round((margin.value || 0) * (tmp.width / 41)))
  if (pad > 0) {
    const padded = document.createElement('canvas')
    padded.width = tmp.width + pad * 2
    padded.height = tmp.height + pad * 2
    const pctx = padded.getContext('2d')
    if (qrBackground.value) {
      pctx.fillStyle = '#fff'
      pctx.fillRect(0, 0, padded.width, padded.height)
    }
    pctx.drawImage(tmp, pad, pad)
    const dataUrl = padded.toDataURL('image/png')
    document.body.removeChild(holder)
    return dataUrl
  }

  const dataUrl = tmp.toDataURL('image/png')
  document.body.removeChild(holder)
  return dataUrl
}

// Render a lightweight DOM preview (layout-only) into the livePreviewContainer
const renderLivePreview = async () => {
  if (!livePreviewContainer.value) return
  const container = livePreviewContainer.value
  // clear existing content
  container.innerHTML = ''

  if (!canShowLivePreview.value) {
    return
  }

  const dims = getPageDimensions()
  const pageW = dims.width
  const pageH = dims.height

  // wrapper to center the page and allow scaling
  const pageWrap = document.createElement('div')
  pageWrap.style.width = pageW + 'px'
  pageWrap.style.height = pageH + 'px'
  pageWrap.style.position = 'relative'
  pageWrap.style.boxShadow = '0 2px 6px rgba(0,0,0,0.12)'
  pageWrap.style.backgroundColor = backgroundColor.value || '#fff'
  pageWrap.style.overflow = 'hidden'
  pageWrap.style.border = '1px solid #ddd'

  // If template image is available, use it as background
  if (state.value.templateType === 'image' && state.value.templateImage) {
    pageWrap.style.backgroundImage = `url(${state.value.templateImage.src})`
    pageWrap.style.backgroundSize = 'contain'
    pageWrap.style.backgroundRepeat = 'no-repeat'
    pageWrap.style.backgroundPosition = 'center'
  }

  container.appendChild(pageWrap)

  // Determine sample data row for filling fields/QR
  let sampleRow = null
  if (activeTab.value === 'batch' && csvData.value.length > 0) {
    sampleRow = selectedCsvData.value && selectedCsvData.value.length > 0 ? selectedCsvData.value[0] : csvData.value[0]
  } else if (activeTab.value === 'manual') {
    sampleRow = { valor: manualInput.value }
  }

  // Add QR (as an image) — generate a recolored PNG quickly
  try {
    const qrText = activeTab.value === 'manual' ? (manualInput.value || '') : (sampleRow ? (sampleRow[qrDataColumn.value] || '') : '')
    if (qrText) {
      const dataUrl = await generateQrDataUrl(qrText, Math.round(qrSize.value || 180))
      if (dataUrl) {
        const img = document.createElement('img')
        img.src = dataUrl
        img.style.position = 'absolute'
        img.style.left = (posX.value || 0) + 'px'
        img.style.top = (posY.value || 0) + 'px'
        img.style.width = (qrSize.value || 180) + 'px'
        img.style.height = (qrSize.value || 180) + 'px'
        img.style.pointerEvents = 'none'
        pageWrap.appendChild(img)
      }
    }
  } catch (err) {
    console.warn('Erro ao gerar QR preview:', err)
  }

  // Add text fields
  for (const field of textFields.value) {
    const div = document.createElement('div')
    div.textContent = field.useColumn && sampleRow && field.bindColumn ? (sampleRow[field.bindColumn] || '') : (field.text || '')
    div.style.position = 'absolute'
    div.style.left = (field.x || 0) + 'px'
    div.style.top = (field.y || 0) + 'px'
    div.style.fontSize = (field.size || 14) + 'px'
    div.style.color = field.color || '#000'
    div.style.whiteSpace = 'pre-wrap'
    div.style.pointerEvents = 'none'
    pageWrap.appendChild(div)
  }
}


// Auto-update preview when parameters change
watchEffect(() => {
  // Watch all reactive values
    const deps = [
    manualInput.value,
    urls.value,
    activeTab.value,
    csvData.value.length,
    pageSize.value,
    pageRotation.value,
    customW.value,
    customH.value,
    backgroundColor.value,
    qrSize.value,
    posX.value,
    posY.value,
    ecc.value,
    margin.value,
    renderText.value,
    fontSize.value,
    maxChars.value,
    qrColor.value,
    qrBackground.value,
    state.value.templateBytes,
    	textFields.value.length,
    	...textFields.value.flatMap(f => [f.text, f.x, f.y, f.size, f.fontFamily, f.bold, f.italic, f.underline, f.color, f.useColumn, f.bindColumn]),
    customFonts.value.length,
    ...customFonts.value.map(f => f.name)
  ]

  // Render lightweight live preview immediately (fast)
  try { renderLivePreview() } catch (e) { /* ignore */ }

  // Debounce the full preview generation (slower, heavy)
  clearTimeout(previewTimeout)
  previewTimeout = setTimeout(() => {
    generatePreview()
  }, 600) // Wait 600ms after last change for full PDF preview
})

// Generate Preview (first page only)
const generatePreview = async () => {
  try {
    // Clear previous preview
    if (previewUrl.value) {
      URL.revokeObjectURL(previewUrl.value)
      previewUrl.value = ''
    }

    let urlList = []
    
    // Decide qual fonte de dados usar com base na aba ativa
    if (activeTab.value === 'manual') {
      // Modo manual: usa o input manual
      const input = manualInput.value.trim()
      if (input) {
        urlList = [input]
      }
    } else {
      // Modo batch: usa CSV
      if (csvData.value.length > 0) {
        urlList = csvData.value.map(item => item[qrDataColumn.value])
      }
    }

    if (urlList.length === 0) {
      // Don't show error, just return
      return
    }

    // Generate only first page
    const pdfDoc = await PDFDocument.create()
    pdfDoc.registerFontkit(fontkit)
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica)

    let pageW = 595
    let pageH = 842 // A4 default

    // Prepare a sample data row for preview (CSV first row or manual input)
    let sampleRow = null
    if (activeTab.value === 'batch' && csvData.value.length > 0) {
      sampleRow = csvData.value[0]
    } else if (activeTab.value === 'manual' && manualInput.value && manualInput.value.trim()) {
      sampleRow = { valor: manualInput.value.trim() }
    }

    if (state.value.templateType === 'pdf') {
      const src = state.value.templatePdf
      const first = src.getPages()[0]
      const baseW = first.getWidth()
      const baseH = first.getHeight()
      
      // Calculate page dimensions based on rotation
      if (pageRotation.value === 90 || pageRotation.value === 270) {
        pageW = baseH
        pageH = baseW
      } else {
        pageW = baseW
        pageH = baseH
      }

      const [embedded] = await pdfDoc.embedPdf(state.value.templateBytes, [0])
      const page = pdfDoc.addPage([pageW, pageH])
      
      // Draw with rotation
      const drawOptions = {
        x: 0,
        y: 0,
        width: baseW,
        height: baseH
      }
      
      if (pageRotation.value !== 0) {
        drawOptions.rotate = { type: 'degrees', angle: pageRotation.value }
        
        // Adjust position based on rotation
        if (pageRotation.value === 90) {
          drawOptions.x = pageW
          drawOptions.y = 0
        } else if (pageRotation.value === 180) {
          drawOptions.x = pageW
          drawOptions.y = pageH
        } else if (pageRotation.value === 270) {
          drawOptions.x = 0
          drawOptions.y = pageH
        }
      }
      
      page.drawPage(embedded, drawOptions)
      await drawQrOnPage(pdfDoc, page, urlList[0], font)
      await drawTextFields(pdfDoc, page, sampleRow)
    } else {
      // Use helper function for page dimensions
      const dims = getPageDimensions()
      pageW = dims.width
      pageH = dims.height

      let bgBytes = null
      if (state.value.templateType === 'image') {
        const pngBytes = await imageElementToPngBytes(state.value.templateImage)
        bgBytes = pngBytes
      }

      const page = pdfDoc.addPage([pageW, pageH])
      
      // Draw background color if no template
      if (!bgBytes) {
        const hex = backgroundColor.value.replace('#', '')
        const r = parseInt(hex.substring(0, 2), 16) / 255
        const g = parseInt(hex.substring(2, 4), 16) / 255
        const b = parseInt(hex.substring(4, 6), 16) / 255
        page.drawRectangle({
          x: 0,
          y: 0,
          width: pageW,
          height: pageH,
          color: rgb(r, g, b),
        })
      }
      
      if (bgBytes) {
        const png = await pdfDoc.embedPng(bgBytes)
        const dims = png.scale(Math.min(pageW / png.width, pageH / png.height))
        page.drawImage(png, {
          x: (pageW - dims.width) / 2,
          y: (pageH - dims.height) / 2,
          width: dims.width,
          height: dims.height,
        })
      }
      await drawQrOnPage(pdfDoc, page, urlList[0], font)
      await drawTextFields(pdfDoc, page, sampleRow)
    }

    const pdfBytes = await pdfDoc.save()
    const blob = new Blob([pdfBytes], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    previewUrl.value = url
  } catch (err) {
    console.error(err)
    // Silent fail for preview - don't disturb the user
  }
}

//funcao para organizar a geracao do PDF
const startGeneration = async () => {
  status.value = '⏳ Iniciando...'
  downloadUrl.value = ''

  // Lógica diferente para cada aba
  if (activeTab.value === 'manual') {
    // Modo manual: gera sempre um PDF único com uma página
    const input = manualInput.value.trim();
    
    if (!input) {
      status.value = 'Erro: Insira um conteúdo para o QR Code.';
      return;
    }
    
    // Sempre gera um PDF único no modo manual
    await generateSinglePDF([input]);
    } else {
    // Modo batch: usa CSV e respeita a opção de exportação
    if (csvData.value.length === 0) {
      status.value = 'Erro: Carregue um arquivo CSV para geração em batch.';
      return;
    }
    if (!qrDataColumn.value) {
    status.value = 'Erro: Por favor, selecione a coluna que contém os dados do QR Code.';
    return;
    }
      // Use the selected CSV subset based on range controls
      const subset = selectedCsvData.value || []
      if (subset.length === 0) {
        status.value = 'Erro: O intervalo selecionado não contém linhas. Verifique a seleção.'
        return
      }

      if (exportOption.value === 'single_pdf') {
        // Passa os objetos CSV (para permitir preencher campos via colunas)
        await generateSinglePDF(subset);
      } else if (exportOption.value === 'multiple_pdfs_zip') {
        await generateZipWithMultiplePDFs(subset);
      }
  }
}


//funcao para criar um PDF unico
const generateSinglePDF = async (urlList) => { 
  try {
    status.value = 'Gerando PDF único…'
    downloadUrl.value = ''
  
    if (urlList.length === 0) {
      throw new Error('Nenhuma URL encontrada para gerar o PDF.')
    }

    const pdfDoc = await PDFDocument.create()
    pdfDoc.registerFontkit(fontkit)
    const font = await pdfDoc.embedFont(StandardFonts.Helvetica)


    let pageW = 595
    let pageH = 842

    if (state.value.templateType === 'pdf') {
      const src = state.value.templatePdf; const first = src.getPages()[0]
      const baseW = first.getWidth(); const baseH = first.getHeight()
      if (pageRotation.value === 90 || pageRotation.value === 270) { pageW = baseH; pageH = baseW } else { pageW = baseW; pageH = baseH }
      const [embedded] = await pdfDoc.embedPdf(state.value.templateBytes, [0])
      const drawOptions = { x: 0, y: 0, width: baseW, height: baseH }
      if (pageRotation.value !== 0) {
        drawOptions.rotate = { type: 'degrees', angle: pageRotation.value }
        if (pageRotation.value === 90) { drawOptions.x = pageW } else if (pageRotation.value === 180) { drawOptions.x = pageW; drawOptions.y = pageH } else if (pageRotation.value === 270) { drawOptions.y = pageH }
      }

      for (const item of urlList) {
        // item can be either a string (manual mode) or an object (CSV row)
        const u = typeof item === 'string' ? item : (item[qrDataColumn.value] || '')
        const page = pdfDoc.addPage([pageW, pageH])
        page.drawPage(embedded, drawOptions)
        await drawQrOnPage(pdfDoc, page, u, font)
        await drawTextFields(pdfDoc, page, typeof item === 'object' ? item : null)
      }
    } else {
      const dims = getPageDimensions(); pageW = dims.width; pageH = dims.height
      let bgBytes = null
      if (state.value.templateType === 'image') {
        bgBytes = await imageElementToPngBytes(state.value.templateImage)
      }

      for (const item of urlList) {
        const u = typeof item === 'string' ? item : (item[qrDataColumn.value] || '')
        const page = pdfDoc.addPage([pageW, pageH])
        if (!bgBytes) {
          const hex = backgroundColor.value.replace('#', ''); const r = parseInt(hex.substring(0, 2), 16) / 255, g = parseInt(hex.substring(2, 4), 16) / 255, b = parseInt(hex.substring(4, 6), 16) / 255
          page.drawRectangle({ x: 0, y: 0, width: pageW, height: pageH, color: rgb(r, g, b) })
        }
        if (bgBytes) {
          const png = await pdfDoc.embedPng(bgBytes)
          const dims = png.scale(Math.min(pageW / png.width, pageH / png.height))
          page.drawImage(png, { x: (pageW - dims.width) / 2, y: (pageH - dims.height) / 2, width: dims.width, height: dims.height })
        }
        await drawQrOnPage(pdfDoc, page, u, font)
        await drawTextFields(pdfDoc, page, typeof item === 'object' ? item : null)
      }
    }

    const pdfBytes = await pdfDoc.save()
    const blob = new Blob([pdfBytes], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    downloadUrl.value = url
    urlCount.value = urlList.length
    status.value = '✅ Concluído.'

    setTimeout(() => {
      const a = document.createElement('a'); a.href = url; a.download = 'qrs.pdf';
      document.body.appendChild(a); a.click(); document.body.removeChild(a)
    }, 100)
  } catch (err) {
    console.error(err)
    status.value = 'Erro: ' + err.message
  }
}

//funcao para criar varios PDFs e zipar
const generateZipWithMultiplePDFs = async (dataList) => {
  try {
    status.value = 'Iniciando geração do ZIP...'
    downloadUrl.value = ''
    const zip = new JSZip()
    
    let counter = 1
    for (const item of dataList) {
      status.value = `Gerando PDF ${counter} de ${dataList.length}...`
      const u = item[qrDataColumn.value]

      const pdfDoc = await PDFDocument.create()
      pdfDoc.registerFontkit(fontkit)
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica)
      
      // A lógica de criação de página é repetida aqui para cada PDF individual
      let pageW = 595, pageH = 842
      if (state.value.templateType === 'pdf') {
        const src = state.value.templatePdf; const first = src.getPages()[0]
        const baseW = first.getWidth(); const baseH = first.getHeight()
        if (pageRotation.value === 90 || pageRotation.value === 270) { pageW = baseH; pageH = baseW }
        else { pageW = baseW; pageH = baseH }
        const [embedded] = await pdfDoc.embedPdf(state.value.templateBytes, [0])
        const page = pdfDoc.addPage([pageW, pageH])
        const drawOptions = { x: 0, y: 0, width: baseW, height: baseH }
        if (pageRotation.value !== 0) {
          drawOptions.rotate = { type: 'degrees', angle: pageRotation.value }
          if (pageRotation.value === 90) { drawOptions.x = pageW }
          else if (pageRotation.value === 180) { drawOptions.x = pageW; drawOptions.y = pageH }
          else if (pageRotation.value === 270) { drawOptions.y = pageH }
        }
        page.drawPage(embedded, drawOptions)
    await drawQrOnPage(pdfDoc, page, u, font); await drawTextFields(pdfDoc, page, item)
      } else {
        const dims = getPageDimensions(); pageW = dims.width; pageH = dims.height
        const page = pdfDoc.addPage([pageW, pageH])
        if (state.value.templateType === 'image') {
          const bgBytes = await imageElementToPngBytes(state.value.templateImage)
          const png = await pdfDoc.embedPng(bgBytes)
          const dims = png.scale(Math.min(pageW / png.width, pageH / png.height))
          page.drawImage(png, { x: (pageW - dims.width) / 2, y: (pageH - dims.height) / 2, width: dims.width, height: dims.height })
        } else {
          const hex = backgroundColor.value.replace('#', '')
          const r = parseInt(hex.substring(0, 2), 16) / 255, g = parseInt(hex.substring(2, 4), 16) / 255, b = parseInt(hex.substring(4, 6), 16) / 255
          page.drawRectangle({ x: 0, y: 0, width: pageW, height: pageH, color: rgb(r, g, b) })
        }
  await drawQrOnPage(pdfDoc, page, u, font); await drawTextFields(pdfDoc, page, item)
      }

      const pdfBytes = await pdfDoc.save()

      let filename = item.nome_arquivo || `qrcode-${counter}`;
      if (!filename.toLowerCase().endsWith('.pdf')) {
        filename = filename.replace(/\.(png|jpe?g|gif)$/i, '') + '.pdf';
      }
      zip.file(filename, pdfBytes)
      counter++
    }

    status.value = 'Compactando arquivos no ZIP...'
    const content = await zip.generateAsync({ type: 'blob' })
    const url = URL.createObjectURL(content)
    downloadUrl.value = url
    urlCount.value = dataList.length
    status.value = '✅ Concluído.'

    setTimeout(() => {
      const a = document.createElement('a'); a.href = url; a.download = 'qrs.zip';
      document.body.appendChild(a); a.click(); document.body.removeChild(a)
    }, 100)
  } catch (err) {
    console.error(err)
    status.value = 'Erro: ' + err.message
  }
}

// Draw text fields on page
// Accepts an optional dataRow (object) to fill fields bound to CSV columns
const drawTextFields = async (pdfDoc, page, dataRow = null) => {
  for (const field of textFields.value) {
    // Determine the text to render: priority
    // 1) bound column (field.bindColumn) with dataRow
    // 2) template in field.text using {{col}}
    // 3) static field.text
    let displayText = ''

    if (field.useColumn && field.bindColumn && dataRow && dataRow[field.bindColumn] !== undefined) {
      displayText = dataRow[field.bindColumn]
    } else if (field.text && dataRow) {
      // Replace any {{col}} occurrences
      displayText = String(field.text).replace(/{{\s*([^}]+)\s*}}/g, (m, p1) => {
        return dataRow[p1] !== undefined ? String(dataRow[p1]) : ''
      })
    } else if (field.text) {
      displayText = field.text
    }

    if (!displayText) continue // nothing to draw

    // Parse color from hex
    const hex = (field.color || '#000000').replace('#', '')
    const r = parseInt(hex.substring(0, 2), 16) / 255
    const g = parseInt(hex.substring(2, 4), 16) / 255
    const b = parseInt(hex.substring(4, 6), 16) / 255

    // Determine font based on family and styles
    const family = field.fontFamily || 'Helvetica'
    const isBold = field.bold || false
    const isItalic = field.italic || false

    let textFont

    // Check if it's a custom font
    const customFont = customFonts.value.find(f => f.name === family)

    if (customFont) {
      // Use custom font (custom fonts don't support bold/italic variants)
      textFont = await pdfDoc.embedFont(customFont.bytes)
    } else {
      // Use standard fonts with variants
      let fontToEmbed

      if (family === 'Helvetica') {
        if (isBold && isItalic) {
          fontToEmbed = StandardFonts.HelveticaBoldOblique
        } else if (isBold) {
          fontToEmbed = StandardFonts.HelveticaBold
        } else if (isItalic) {
          fontToEmbed = StandardFonts.HelveticaOblique
        } else {
          fontToEmbed = StandardFonts.Helvetica
        }
      } else if (family === 'Times') {
        if (isBold && isItalic) {
          fontToEmbed = StandardFonts.TimesRomanBoldItalic
        } else if (isBold) {
          fontToEmbed = StandardFonts.TimesBold
        } else if (isItalic) {
          fontToEmbed = StandardFonts.TimesRomanItalic
        } else {
          fontToEmbed = StandardFonts.TimesRoman
        }
      } else if (family === 'Courier') {
        if (isBold && isItalic) {
          fontToEmbed = StandardFonts.CourierBoldOblique
        } else if (isBold) {
          fontToEmbed = StandardFonts.CourierBold
        } else if (isItalic) {
          fontToEmbed = StandardFonts.CourierOblique
        } else {
          fontToEmbed = StandardFonts.Courier
        }
      } else {
        // Fallback: Helvetica
        fontToEmbed = StandardFonts.Helvetica
      }

      textFont = await pdfDoc.embedFont(fontToEmbed)
    }

    const yPos = page.getHeight() - field.y - field.size

    // Draw text
    page.drawText(String(displayText), {
      x: field.x,
      y: yPos,
      size: field.size,
      font: textFont,
      color: rgb(r, g, b),
    })

    // Draw underline if enabled
    if (field.underline) {
      const textWidth = textFont.widthOfTextAtSize(String(displayText), field.size)
      const underlineY = yPos - 2 // Slightly below the text baseline
      page.drawLine({
        start: { x: field.x, y: underlineY },
        end: { x: field.x + textWidth, y: underlineY },
        thickness: Math.max(1, field.size / 12),
        color: rgb(r, g, b),
      })
    }
  }
}

// Draw QR code on page
const drawQrOnPage = async (pdfDoc, page, urlText, font) => {
  const size = qrSize.value || 180
  const x = posX.value || 0
  const y = posY.value || 0
  const eccLevel = ecc.value
  const marginVal = Math.max(0, margin.value || 0)
  const showText = renderText.value === 'yes'
  const fontSizeVal = fontSize.value || 12
  const maxCharsVal = maxChars.value || 64

  // Generate QR on a temporary canvas via qrcodejs
  const holder = document.createElement('div')
  qrHolder.value.appendChild(holder)

  const QR = resolveQRCodeCtor()
  if(!QR){
    throw new Error('Biblioteca de QRCode não carregada. Verifique sua conexão ou o script CDN.')
  }
  const qr = new QR(holder, {
    text: urlText,
    width: size,
    height: size,
    // Usamos nosso próprio mapa de níveis para evitar erro "Cannot read properties of undefined (reading 'L')"
    correctLevel: QR_CORRECT_LEVEL[eccLevel],
  })

  await tick() // allow canvas render

  const canvas = holder.querySelector('canvas')
  
  // Apply custom color to QR code
  const tempCanvas = document.createElement('canvas')
  tempCanvas.width = canvas.width
  tempCanvas.height = canvas.height
  const tempCtx = tempCanvas.getContext('2d')
  
  // Always start with transparent canvas
  tempCtx.clearRect(0, 0, tempCanvas.width, tempCanvas.height)
  
  // Draw original QR code
  tempCtx.drawImage(canvas, 0, 0)
  
  // Get image data to change colors
  const imageData = tempCtx.getImageData(0, 0, tempCanvas.width, tempCanvas.height)
  const data = imageData.data
  
  // Parse custom QR color
  const hexColor = qrColor.value.replace('#', '')
  const r = parseInt(hexColor.substring(0, 2), 16)
  const g = parseInt(hexColor.substring(2, 4), 16)
  const b = parseInt(hexColor.substring(4, 6), 16)
  
  // Replace dark modules with custom color and make the background transparent (or white)
  for (let i = 0; i < data.length; i += 4) {
    const rr = data[i]
    const gg = data[i + 1]
    const bb = data[i + 2]
    const aa = data[i + 3]

    // Consider pixel as background if it's nearly white or fully transparent
    const isWhite = (rr > 200 && gg > 200 && bb > 200) || aa === 0

    if (isWhite) {
      if (qrBackground.value) {
        data[i] = 255
        data[i + 1] = 255
        data[i + 2] = 255
        data[i + 3] = 255
      } else {
        // make transparent
        data[i + 3] = 0
      }
    } else {
      // module -> recolor
      data[i] = r
      data[i + 1] = g
      data[i + 2] = b
      data[i + 3] = 255
    }
  }
  
  tempCtx.putImageData(imageData, 0, 0)
  
  // Manual quiet zone: draw colored canvas onto a padded canvas
  const padded = document.createElement('canvas')
  const padPx = Math.round(marginVal * (tempCanvas.width / 41)) // 41 is typical module count
  padded.width = tempCanvas.width + padPx * 2
  padded.height = tempCanvas.height + padPx * 2
  const ctx = padded.getContext('2d')
  
  // Fill padding area only if background is enabled
  if (qrBackground.value) {
    ctx.fillStyle = '#fff'
    ctx.fillRect(0, 0, padded.width, padded.height)
  }
  
  ctx.drawImage(tempCanvas, padPx, padPx)

  const dataUrl = padded.toDataURL('image/png')
  qrHolder.value.removeChild(holder)

  const png = await pdfDoc.embedPng(dataUrl)
  page.drawImage(png, {
    x: x,
    y: page.getHeight() - y - size,
    width: size,
    height: size,
  })

  if (showText) {
    const text = ellipsize(urlText, maxCharsVal)
    page.drawText(text, {
      x: x,
      y: page.getHeight() - y - size - (fontSizeVal + 6),
      size: fontSizeVal,
      font,
      color: rgb(0, 0, 0),
    })
  }
}

// Helper functions
const ellipsize = (s, n) => {
  if (s.length <= n) return s
  return s.slice(0, Math.max(0, n - 1)) + '…'
}

const tick = () => {
  return new Promise((resolve) => setTimeout(resolve, 0))
}

const imageElementToPngBytes = async (img) => {
  const canvas = document.createElement('canvas')
  canvas.width = img.naturalWidth
  canvas.height = img.naturalHeight
  const ctx = canvas.getContext('2d')
  ctx.drawImage(img, 0, 0)
  const dataUrl = canvas.toDataURL('image/png')
  const res = await fetch(dataUrl)
  return new Uint8Array(await res.arrayBuffer())
}

// Resolve construtor de QRCode considerando diferentes formatos de bundle
function resolveQRCodeCtor(){
  if(typeof window !== 'undefined'){
    if(window.QRCode && typeof window.QRCode === 'function') return window.QRCode
    // Algumas variantes expõem window.QRCode.QRCode
    if(window.QRCode && typeof window.QRCode.QRCode === 'function') return window.QRCode.QRCode
  }
  return null
}
</script>
