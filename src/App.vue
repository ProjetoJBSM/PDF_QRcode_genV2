<template>
  <div>
    <header class="app-header">
      <h1>Client-side QR Batch → PDF</h1>
      <p class="hint">
        Cole URLs (uma por linha), escolha um template (imagem ou PDF opcional), defina a posição/tamanho do QR e gere um PDF com uma página por URL — tudo no navegador.
      </p>
    </header> 

  <div class="main-layout" :class="{ 'loader-view': view === 'loader' }">
  <form @submit.prevent class="form-section" :class="{ 'form-section--fullscreen': view === 'loader' }">
      <fieldset v-if="view === 'loader'">
        <legend>Dados</legend>
        <label>
          URL
          <textarea
            v-model="urls"
            placeholder="https://example.com/one"
            :disabled="csvData.length>0"
          ></textarea>
        </label> 

        <div class="data-source-separator">
          <span>OU</span>
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
          <button type="button" class="btn btn-neutral" @click="backToLoader">← Voltar</button>
          <h3 style="margin:0; font-size:1rem; color:#333;">Editor de Template</h3>
        </div>

        <fieldset class="config-card">
        <legend>Configurações do Template e QR Code</legend>

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
      </fieldset>

        <hr class="card-divider" />

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
                    <input v-model.number="posX" type="range" min="0" :max="maxPosX" step="1" @input="onSliderChange" @change="generatePreview" />
                    <span class="small">{{ posX }} pt</span>
                  </div>
                </label>
                <label class="qr-control qr-position">
                  Posição Y - Topo (pt)
                  <div style="display:flex; gap:0.5rem; align-items:center;">
                    <input v-model.number="posY" type="range" min="0" :max="maxPosY" step="1" @input="onSliderChange" @change="generatePreview" />
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
      </fieldset>
      

      <fieldset class="config-card spaced-section">
        <legend>Opções Avançadas</legend>

        <div class="advanced-toggle">
          <button 
            type="button" 
            class="advanced-toggle-btn" 
            @click="showAdvancedQR = !showAdvancedQR"
          >
            {{ showAdvancedQR ? '▼' : '▶' }} Configurações Avançadas do QR
          </button>
        </div>
        <div v-show="showAdvancedQR" class="qr-advanced-settings" style="padding-bottom: 1rem; border-bottom: 1px solid #eee;">
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

        <fieldset style="border: none; padding: 0; margin: 0;">
          <div class="advanced-toggle" style="margin-top: 0.5rem;">
            <button 
              type="button" 
              class="advanced-toggle-btn" 
              @click="showTextFields = !showTextFields"
            >
              {{ showTextFields ? '▼' : '▶' }} Campos de Texto (Opcional)
            </button>
          </div>
          <div v-show="showTextFields" style="padding-bottom: 1rem; border-bottom: 1px solid #eee;">
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
          </div>
        </fieldset>

        <fieldset style="border: none; padding: 0; margin: 0;">
          <div class="advanced-toggle" style="margin-top: 0.5rem;">
            <button 
              type="button" 
              class="advanced-toggle-btn" 
              @click="showCustomFonts = !showCustomFonts"
            >
              {{ showCustomFonts ? '▼' : '▶' }} Fontes Customizadas (Opcional)
            </button>
          </div>
          <div v-show="showCustomFonts">
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
          </div>
        </fieldset>

      </fieldset>

        <div v-if="templateInfo" class="template-info">
          {{ templateInfo }}
        </div>
        <div class="config-actions spaced-section">
          <button 
            type="button" 
            class="btn btn-neutral" 
            @click="exportConfiguration"
            title="Exportar todas as configurações do template"
          >
            📥 Exportar Configurações
          </button>
          
          <label class="btn btn-secondary import-btn">
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
          <button class="btn btn-primary btn-full" type="button" @click="startGeneration">
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

      <!-- Live Preview Section -->
      <div class="preview-section">
        <h2>Pré-visualização em Tempo Real</h2>
        <div class="preview-info">
          <span class="small">Primeira página • Atualiza automaticamente  •  Ctrl + rolagem do mouse para zoom na página</span>
        </div>
        <div class="preview-container">
          <iframe 
            v-if="previewUrl" 
            :src="previewUrl + '#view=Fit&toolbar=0&navpanes=0'" 
            class="pdf-preview"
          ></iframe>
          <div v-else class="preview-placeholder">
            <p>A pré-visualização aparecerá aqui</p>
            <p class="small">Cole pelo menos uma URL para começar</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Hidden holder for QR generation -->
    <div ref="qrHolder" style="position: absolute; left: -9999px; top: -9999px;"></div>
  </div>
</template>

<script setup>
import { ref, watch, watchEffect } from 'vue'
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib'
import fontkit from '@pdf-lib/fontkit'
import Papa from 'papaparse'
import JSZip from 'jszip'

// Algumas builds do pacote 'qrcodejs' (npm) não expõem a propriedade "CorrectLevel".
// Definimos manualmente o mapeamento de níveis ECC conforme implementação original:
// L = 1, M = 0, Q = 3, H = 2
// (ordem interna é diferente do esperado mas corresponde à lib qrcodejs)
const QR_CORRECT_LEVEL = { L: 1, M: 0, Q: 3, H: 2 }

// Debounce helper
let previewTimeout = null

// Data refs
const urls = ref('')
const csvData = ref([]) //teste de correcao
const csvFileName = ref('')
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
const showTextFields = ref(false)   // <-- ADICIONE ESTA LINHA
const showCustomFonts = ref(false)  // <-- ADICIONE ESTA LINHA

// Hidden QR holder
const qrHolder = ref(null)

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
    color: '#000000'
  })
}

// Remove text field
const removeTextField = (index) => {
  textFields.value.splice(index, 1)
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

//processar arquivo CSV
const handleCsvUpload = (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  //para zerar a contagem de pag por arquivo
  downloadUrl.value = '';
  urlCount.value = 0;

  urls.value = '' // Limpa o textarea para evitar confusão
  csvData.value = []
  csvFileName.value = ''

  Papa.parse(file, {
    header: true,
    skipEmptyLines: true,
    complete: (results) => {
      if (results.data && results.meta.fields.includes('valor')) {
        csvData.value = results.data.filter(row => row.valor && row.valor.trim() !== '');
        csvFileName.value = file.name

        // Força a atualização da pré-visualização com a primeira URL do CSV
        if (csvData.value.length > 0) {
          generatePreview()
        }

      } else {
        status.value = 'Erro: O CSV precisa ter uma coluna chamada "valor".'
      }
    },
    error: (err) => {
      status.value = 'Erro ao ler o CSV: ' + err.message
    }
  })
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

// Auto-update preview when parameters change
watchEffect(() => {
  // Watch all reactive values
  const deps = [
    urls.value,
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
    ...textFields.value.flatMap(f => [f.text, f.x, f.y, f.size, f.fontFamily, f.bold, f.italic, f.underline, f.color]),
    customFonts.value.length,
    ...customFonts.value.map(f => f.name)
  ]

  // Debounce the preview generation
  clearTimeout(previewTimeout)
  previewTimeout = setTimeout(() => {
    generatePreview()
  }, 500) // Wait 500ms after last change
})

// Generate Preview (first page only)
const generatePreview = async () => {
  try {
    // Clear previous preview
    if (previewUrl.value) {
      URL.revokeObjectURL(previewUrl.value)
      previewUrl.value = ''
    }

    //para suportar CSV
    let urlList = []
    if (csvData.value.length > 0) {
      // Pega as URLs do CSV
      urlList = csvData.value.map(item => item.valor)
    } else {
      // Senão, pega as URLs do textarea
      urlList = urls.value
        .split(/\r?\n/)
        .map((s) => s.trim())
        .filter(Boolean)
    }
    //continuação normal

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
      await drawTextFields(pdfDoc, page)
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
      await drawTextFields(pdfDoc, page)
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
  status.value = 'Iniciando...'
  downloadUrl.value = ''

  // Decide qual especialista chamar com base na opção do usuário
  if (exportOption.value === 'single_pdf') {
    let urlList = [];
    if (csvData.value.length > 0) {
      // Extrai APENAS as URLs para a função de PDF único
      urlList = csvData.value.map(item => item.valor);
    } else {
      urlList = urls.value.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
    }
    
    if (urlList.length === 0) {
      status.value = 'Erro: Nenhuma URL fornecida.';
      return;
    }
    // Chama a função antiga com a lista simples de URLs
    await generateSinglePDF(urlList);
  } else if (exportOption.value === 'multiple_pdfs_zip') {
    if (csvData.value.length === 0) {
      status.value = 'Erro: Para gerar um ZIP, por favor, carregue um arquivo CSV com a coluna "nome_arquivo".';
      return;
    }
    await generateZipWithMultiplePDFs(csvData.value);
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

      for (const u of urlList) {
        const page = pdfDoc.addPage([pageW, pageH])
        page.drawPage(embedded, drawOptions)
        await drawQrOnPage(pdfDoc, page, u, font)
        await drawTextFields(pdfDoc, page)
      }
    } else {
      const dims = getPageDimensions(); pageW = dims.width; pageH = dims.height
      let bgBytes = null
      if (state.value.templateType === 'image') {
        bgBytes = await imageElementToPngBytes(state.value.templateImage)
      }

      for (const u of urlList) {
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
        await drawTextFields(pdfDoc, page)
      }
    }

    const pdfBytes = await pdfDoc.save()
    const blob = new Blob([pdfBytes], { type: 'application/pdf' })
    const url = URL.createObjectURL(blob)
    downloadUrl.value = url
    urlCount.value = urlList.length
    status.value = 'Concluído.'

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
      const u = item.valor

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
        await drawQrOnPage(pdfDoc, page, u, font); await drawTextFields(pdfDoc, page)
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
        await drawQrOnPage(pdfDoc, page, u, font); await drawTextFields(pdfDoc, page)
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
    status.value = 'Concluído.'

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
const drawTextFields = async (pdfDoc, page) => {
  for (const field of textFields.value) {
    if (!field.text) continue // Skip empty fields
    
    // Parse color from hex
    const hex = field.color.replace('#', '')
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
    page.drawText(field.text, {
      x: field.x,
      y: yPos,
      size: field.size,
      font: textFont,
      color: rgb(r, g, b),
    })
    
    // Draw underline if enabled
    if (field.underline) {
      const textWidth = textFont.widthOfTextAtSize(field.text, field.size)
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
  
  // Replace black pixels with custom color and handle white pixels
  for (let i = 0; i < data.length; i += 4) {
    // Check if pixel is dark (QR code module)
    if (data[i] < 128 && data[i + 1] < 128 && data[i + 2] < 128) {
      data[i] = r     // Red
      data[i + 1] = g // Green
      data[i + 2] = b // Blue
      data[i + 3] = 255 // Fully opaque
    } else {
      // White/light pixel
      if (qrBackground.value) {
        // Keep white background
        data[i] = 255
        data[i + 1] = 255
        data[i + 2] = 255
        data[i + 3] = 255
      } else {
        // Make transparent
        data[i + 3] = 0
      }
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

<style scoped>
/* 1. Padronização de Cores e Estilos */
:main-layout {
  --primary-color: #007bff; /* Azul para ações principais */
  --primary-hover: #0056b3;
  --secondary-color: #28a745; /* Verde para ações "positivas" (Importar) */
  --secondary-hover: #218838;
  --neutral-color: #6c757d;  /* Cinza para ações "neutras" (Exportar) */
  --neutral-hover: #5a6268;
  --card-bg: #ffffff;
  --card-border-radius: 8px;
  --card-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}

/* 2. O CardView para as Configurações Principais */
.config-card {
  background: var(--card-bg);
  border-radius: var(--card-border-radius);
  box-shadow: var(--card-shadow);
  border: 1px solid #e9ecef;
  padding: 1.25rem 1.5rem;
  margin-top: 1rem;
}

/* Estiliza a legenda DENTRO do card */
.config-card > legend {
  font-size: 1.25rem;
  font-weight: 600;
  color: #333;
  padding: 0 0.5rem;
  margin-left: -0.5rem;
}

/* 3. Classe de Espaçamento para as outras seções */
.spaced-section {
  margin-top: 1.75rem; /* Aumenta o espaçamento entre as seções */
}


/* 4. Novo Sistema de Botões Padronizado (Design Amigável) */
.btn {
  display: inline-block;
  font-weight: 600;
  color: #ffffff; /* Garante que o texto seja branco */
  text-align: center;
  vertical-align: middle;
  cursor: pointer;
  background-color: transparent;
  border: 1px solid transparent;
  padding: 0.65rem 1rem;
  font-size: 0.95rem;
  line-height: 1.5;
  text-decoration: none; /* Para o link de download */
  
  /* --- A MÁGICA ACONTECE AQUI --- */
  
  /* Bordas arredondadas que você pediu */
  border-radius: 8px; 
  
  /* Sombra sutil para dar um leve relevo */
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  
  /* Animação suave para Clicar e passar o mouse */
  transition: all 0.2s ease-in-out; 
}

/* Efeito INTERATIVO ao passar o mouse */
.btn:hover {
  /* "Levanta" o botão levemente */
  transform: translateY(-2px); 
  
  /* Aumenta a sombra para um efeito 3D */
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1); 
}

/* Efeito ao Clicar (feedback visual) */
.btn:active {
  transform: translateY(1px);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}


/* Botão Principal (Azul) */
.btn-primary {
  background-color: #007bff;
  border-color: #007bff;
  color: #ffffff;
}
.btn-primary:hover {
  background-color: #0056b3;
  border-color: #0056b3;
  color: #ffffff;
}

/* Botão Secundário (Verde) */
.btn-secondary {
  background-color: #28a745;
  border-color: #28a745;
  color: #ffffff;
}
.btn-secondary:hover {
  background-color: #218838;
  border-color: #218838;
  color: #ffffff;
}

/* Botão Neutro (Cinza) */
.btn-neutral {
  background-color: #6c757d;
  border-color: #6c757d;
  color: #ffffff;
}
.btn-neutral:hover {
  background-color: #5a6268;
  border-color: #5a6268;
  color: #ffffff;
}

/* Botão de Largura Total (continua o mesmo) */
.btn-full {
  width: 100%;
}

/* 5. Organiza os botões de Importar/Exportar */
.config-actions {
  display: grid;
  grid-template-columns: 1fr 1fr; /* Duas colunas iguais */
  gap: 1rem; /* Espaço entre eles */
  margin-top: 1.75rem;
}


.app-header {
  background-color: #2c3e50; /* Um azul-escuro/cinza corporativo */
  color: #ffffff;
  padding: 1.5rem 2rem;
  border-radius: var(--card-border-radius);
  margin-bottom: 2rem;
  box-shadow: 0 4px 10px rgba(0,0,0,0.1);
}

.app-header h1 {
  margin: 0;
  font-size: 1.75rem;
  font-weight: 600;
  color: #ffffff; /* Garante a cor branca */
}

.app-header .hint {
  margin: 0.25rem 0 0 0;
  font-size: 1rem;
  color: #bdc3c7; /* Um cinza-claro para o subtítulo */
  font-weight: 400;
}

.card-divider {
  border: none;
  border-top: 1px solid #eee; /* Uma linha cinza clara */
  margin-top: 1.25rem;
  margin-bottom: 1.25rem;
}

</style>