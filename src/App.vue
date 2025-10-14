<template>
  <div>
    <h1>Client-side QR Batch → PDF</h1>
    <p class="hint">
      Cole URLs (uma por linha), escolha um template (imagem ou PDF opcional), defina a posição/tamanho do QR e gere um PDF com uma página por URL — tudo no navegador.
    </p>

    <div class="main-layout">
      <form @submit.prevent class="form-section">
      <fieldset>
        <legend>Dados</legend>
        <label>
          URL
          <textarea
            v-model="urls"
            placeholder="https://example.com/one"
          ></textarea>
        </label>
        
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

      <fieldset>
        <legend>Posicionamento do QR</legend>
        <div class="qr-controls-row">
          <label class="qr-control qr-size">
            Tamanho do QR (pt)
            <input v-model.number="qrSize" type="number" min="30" />
          </label>
          <label class="qr-control qr-position">
            Esquerda (pt da borda esquerda)
            <input v-model.number="posX" type="number" min="0" />
          </label>
          <label class="qr-control qr-position">
            Topo (pt do topo da página)
            <input v-model.number="posY" type="number" min="0" />
          </label>
          <label class="qr-control qr-ecc">
            Nível ECC
            <select v-model="ecc">
              <option value="L">L (7%)</option>
              <option value="M">M (15%)</option>
              <option value="Q">Q (25%)</option>
              <option value="H">H (30%)</option>
            </select>
          </label>
          <label class="qr-control qr-margin">
            Zona quieta (módulos)
            <input v-model.number="margin" type="number" min="0" />
          </label>
        </div>
        <div class="qr-text-controls-row">
          <label class="qr-text-control qr-render-text">
            Renderizar texto da URL sob o QR?
            <select v-model="renderText">
              <option value="no">Não</option>
              <option value="yes">Sim</option>
            </select>
          </label>
          <label class="qr-text-control qr-font-size">
            Tamanho da fonte do texto (pt)
            <input v-model.number="fontSize" type="number" min="6" />
          </label>
          <label class="qr-text-control qr-max-chars">
            Máx. caracteres da URL (reticências)
            <input v-model.number="maxChars" type="number" min="10" />
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
        <p class="small">
          Dica: O espaço do usuário PDF é em pontos (pt). 72 pt ≈ 1 polegada; 1 mm ≈ 2.835 pt. A4 = 595×842 pt.
        </p>
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
            <button type="button" class="remove-field-btn" @click="removeTextField(index)">
              Remover
            </button>
          </div>
          
          <label>
            Texto
            <input v-model="field.text" type="text" placeholder="Digite o texto aqui..." />
          </label>

          <div class="text-field-controls">
            <label class="control-item control-flex">
              Esquerda (pt)
              <input v-model.number="field.x" type="number" min="0" />
            </label>
            <label class="control-item control-flex">
              Topo (pt)
              <input v-model.number="field.y" type="number" min="0" />
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
                  <option v-for="font in customFonts" :key="font.name" :value="font.name">
                    {{ font.name }}
                  </option>
                </optgroup>
              </select>
            </label>
            <label class="control-item control-flex">
              Tamanho (pt)
              <input v-model.number="field.size" type="number" min="6" max="200" />
            </label>
            <label class="control-item control-color">
              Cor
              <input v-model="field.color" type="color" />
            </label>
            <label class="control-item control-format">
              Formatação
              <div class="format-buttons">
                <button 
                  type="button" 
                  class="format-btn" 
                  :class="{ active: field.bold }"
                  @click="field.bold = !field.bold"
                  title="Negrito"
                >
                  <strong>B</strong>
                </button>
                <button 
                  type="button" 
                  class="format-btn" 
                  :class="{ active: field.italic }"
                  @click="field.italic = !field.italic"
                  title="Itálico"
                >
                  <em>I</em>
                </button>
                <button 
                  type="button" 
                  class="format-btn" 
                  :class="{ active: field.underline }"
                  @click="field.underline = !field.underline"
                  title="Sublinhado"
                >
                  <span style="text-decoration: underline;">U</span>
                </button>
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
            📁 Carregar Arquivo .ttf/.otf
            <input 
              type="file" 
              accept=".ttf,.otf" 
              @change="loadCustomFontFile"
              style="display: none;"
            />
          </label>
        </div>

        <div v-if="fontLoading" class="font-loading">
          <span class="small">⏳ Carregando fonte...</span>
        </div>

        <div v-if="fontLoadError" class="font-error">
          <span class="small">⚠️ {{ fontLoadError }}</span>
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
              📄 {{ font.name }}
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

        <div class="actions">
          <button class="primary" type="button" @click="generatePDF">
            Gerar PDF Completo
          </button>
          <a
            v-if="downloadUrl"
            :href="downloadUrl"
            download="qrs.pdf"
          >
            Download PDF ({{ urlCount }} páginas)
          </a>
          <span class="small">{{ status }}</span>
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

// Algumas builds do pacote 'qrcodejs' (npm) não expõem a propriedade "CorrectLevel".
// Definimos manualmente o mapeamento de níveis ECC conforme implementação original:
// L = 1, M = 0, Q = 3, H = 2
// (ordem interna é diferente do esperado mas corresponde à lib qrcodejs)
const QR_CORRECT_LEVEL = { L: 1, M: 0, Q: 3, H: 2 }

// Debounce helper
let previewTimeout = null

// Data refs
const urls = ref('')
const pageSize = ref('A4')
const pageRotation = ref(0) // 0, 90, 180, 270
const customW = ref(595)
const customH = ref(842)
const backgroundColor = ref('#FFFFFF')

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

// Custom fonts state
const customFonts = ref([])
const fontLoading = ref(false)
const fontLoadError = ref('')

// Output state
const downloadUrl = ref('')
const urlCount = ref(0)
const status = ref('')
const previewUrl = ref('')

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

    const urlList = urls.value
      .split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean)

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

// Generate PDF
const generatePDF = async () => {
  try {
    status.value = 'Gerando…'
    downloadUrl.value = ''

    const urlList = urls.value
      .split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean)

    if (urlList.length === 0) {
      throw new Error('Por favor, cole pelo menos uma URL.')
    }

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

      // Embed the template page ONCE, reuse for all pages
      const [embedded] = await pdfDoc.embedPdf(state.value.templateBytes, [0])
      
      // Draw options with rotation
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

      for (const u of urlList) {
        const page = pdfDoc.addPage([pageW, pageH])
        page.drawPage(embedded, drawOptions)
        await drawQrOnPage(pdfDoc, page, u, font)
        await drawTextFields(pdfDoc, page)
      }
    } else {
      // Use helper function for page dimensions
      const dims = getPageDimensions()
      pageW = dims.width
      pageH = dims.height

      let bgBytes = null
      if (state.value.templateType === 'image') {
        // Convert image to PNG bytes for pdf-lib
        const pngBytes = await imageElementToPngBytes(state.value.templateImage)
        bgBytes = pngBytes
      }

      for (const u of urlList) {
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
        
        // Draw background image (fit to page)
        if (bgBytes) {
          const png = await pdfDoc.embedPng(bgBytes)
          const dims = png.scale(Math.min(pageW / png.width, pageH / png.height))
          // center-fit
          page.drawImage(png, {
            x: (pageW - dims.width) / 2,
            y: (pageH - dims.height) / 2,
            width: dims.width,
            height: dims.height,
          })
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

    // Download automático
    setTimeout(() => {
      const a = document.createElement('a')
      a.href = url
      a.download = 'qrs.pdf'
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
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
/* Main Layout - Two columns */
.main-layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
  margin-top: 1.5rem;
}

@media (max-width: 1200px) {
  .main-layout {
    grid-template-columns: 1fr;
  }
}

/* Form Section */
.form-section {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.template-info {
  padding: 0.75rem;
  background-color: #e7f3ff;
  border-left: 4px solid #0066cc;
  border-radius: 4px;
  font-size: 0.9rem;
  color: #333;
}

.actions {
  display: flex;
  gap: 1rem;
  align-items: center;
  flex-wrap: wrap;
  padding-top: 1rem;
  border-top: 2px solid #eee;
}

button.primary {
  background-color: #0066cc;
  color: white;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 600;
  transition: background-color 0.2s;
}

button.primary:hover {
  background-color: #0052a3;
}

/* Preview Section - Sticky */
.preview-section {
  position: sticky;
  top: 1rem;
  height: fit-content;
  max-height: calc(100vh - 2rem);
  display: flex;
  flex-direction: column;
}

.preview-section h2 {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  color: #333;
}

.preview-info {
  margin-bottom: 1rem;
}

.preview-container {
  flex: 1;
  min-height: 80vh;
  max-height: 80vh;
  border: 2px solid #ddd;
  border-radius: 8px;
  overflow: hidden;
  background-color: #f5f5f5;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.pdf-preview {
  width: 100%;
  height: 80vh;
  border: none;
  background-color: white;
}

.preview-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
  padding: 2rem;
  text-align: center;
}

.preview-placeholder p {
  margin: 0.5rem 0;
}

.small {
  font-size: 0.875rem;
  color: #666;
}

/* Improve form readability */
fieldset {
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 1rem;
  margin: 0;
}

legend {
  font-weight: 600;
  padding: 0 0.5rem;
  color: #333;
}

label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
  color: #555;
}

input, select, textarea {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-family: inherit;
  font-size: 0.95rem;
}

textarea {
  min-height: 100px;
  resize: vertical;
}

.rotate-btn {
  max-width: 40px;
  max-height: 40px;
  padding: 0.75rem 1rem;
  background-color: #818181;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1.5rem;
  font-weight: 400;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  white-space: nowrap;
}

.rotate-btn:hover {
  background-color: #4a4a4a;
  transform: translateY(-1px);
  box-shadow: 0 2px 8px rgba(23, 162, 184, 0.3);
}

.rotate-btn:active {
  transform: translateY(0) scale(0.98);
}

/* Template Controls Row */
.template-controls-row {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
}

.template-control {
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.template-control input,
.template-control select {
  width: 100%;
}

/* Template file input - flexible */
.template-file {
  flex: 1;
  min-width: 0;
}

/* Rotate button - aligned to right */
.template-rotate {
  flex-shrink: 0;
  align-items: flex-end;
}

.rotate-btn-square {
  width: 60px;
  height: 42px;
  padding: 0;
  background-color: #818181;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1.5rem;
  font-weight: 400;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-left: auto;
}

.rotate-btn-square:hover {
  background-color: #4a4a4a;
  transform: translateY(-1px);
  box-shadow: 0 2px 8px rgba(23, 162, 184, 0.3);
}

.rotate-btn-square:active {
  transform: translateY(0) scale(0.98);
}

/* Page Controls Row */
.page-controls-row {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
}

.page-control {
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.page-control input,
.page-control select {
  width: 100%;
}

/* Page size - flexible */
.page-size {
  flex: 1;
  min-width: 150px;
}

/* Page dimensions - flexible */
.page-dimension {
  flex: 1;
  min-width: 120px;
}

/* Background color - fixed 80px */
.page-bg-color {
  width: 80px;
  flex-shrink: 0;
}

.page-bg-color input[type="color"] {
  height: 42px;
  padding: 0.25rem;
}

.row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-top: 0.5rem;
}

.inline {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.inline input {
  width: auto;
  flex: 1;
}

input[type="color"] {
  cursor: pointer;
  height: 42px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-weight: 500;
  color: #555;
  width: 50px;
}

.checkbox-label input[type="checkbox"] {
  width: auto;
  height: auto;
  cursor: pointer;
  margin: 0;
  transform: scale(1.2);
}

/* QR Controls - Single Row Layout */
.qr-controls-row {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
}

.qr-control {
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.qr-control input,
.qr-control select {
  width: 100%;
}

/* QR Size - min 130px, flexible */
.qr-size {
  flex: 1;
  min-width: 130px;
}

/* Position fields - min 180px, flexible */
.qr-position {
  flex: 1.4;
  min-width: 180px;
}

/* ECC Level - min 100px, flexible */
.qr-ecc {
  flex: 0.8;
  min-width: 100px;
}

/* Margin - min 130px, flexible */
.qr-margin {
  flex: 1;
  min-width: 130px;
}

/* QR Text Controls - Second Row Layout */
.qr-text-controls-row {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  margin-top: 0.5rem;
  margin-bottom: 0.5rem;
}

.qr-text-control {
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.qr-text-control input,
.qr-text-control select {
  width: 100%;
}

/* Render text - min 200px, flexible */
.qr-render-text {
  flex: 1;
  min-width: 200px;
}

/* Font size - min 200px, flexible */
.qr-font-size {
  flex: 1;
  min-width: 200px;
}

/* Max chars - min 200px, flexible */
.qr-max-chars {
  flex: 1;
  min-width: 200px;
}

/* QR Color - min 90px, fixed */
.qr-color {
  width: 90px;
  flex-shrink: 0;
}

.qr-color input[type="color"] {
  height: 42px;
  padding: 0.25rem;
}

/* Checkbox wrapper - fixed 50px for text width */
.qr-checkbox-wrapper {
  width: 50px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 0.25rem;
  cursor: pointer;
}

.checkbox-label-text {
  font-size: 0.75rem;
  text-align: center;
  line-height: 1.1;
  word-wrap: break-word;
  font-weight: 500;
  color: #555;
  margin-bottom: 0.25rem;
}

.qr-checkbox {
  width: auto !important;
  height: auto !important;
  cursor: pointer;
  transform: scale(1.2);
  margin: 0;
}

/* Text Fields Section */
.text-fields-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  gap: 1rem;
}

.add-field-btn {
  background-color: #28a745;
  color: white;
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9rem;
  font-weight: 500;
  white-space: nowrap;
  transition: background-color 0.2s;
}

.add-field-btn:hover {
  background-color: #218838;
}

.no-fields {
  padding: 2rem;
  text-align: center;
  background-color: #f8f9fa;
  border: 2px dashed #ddd;
  border-radius: 4px;
  color: #999;
}

.text-field-item {
  margin-bottom: 1.5rem;
  padding: 1rem;
  background-color: #f8f9fa;
  border: 1px solid #ddd;
  border-radius: 6px;
}

.field-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid #e0e0e0;
}

.field-header strong {
  color: #333;
  font-size: 1rem;
}

.remove-field-btn {
  background-color: #dc3545;
  color: white;
  padding: 0.4rem 0.8rem;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85rem;
  transition: background-color 0.2s;
}

.remove-field-btn:hover {
  background-color: #c82333;
}

.text-field-item label {
  margin-bottom: 0.75rem;
}

/* Text Field Controls - Single Row Layout */
.text-field-controls {
  display: flex;
  gap: 0.75rem;
  align-items: flex-end;
  margin-top: 0.5rem;
}

.control-item {
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.control-item input,
.control-item select {
  width: 100%;
}

/* Flexible width items (Esquerda, Topo, Tamanho) */
.control-flex {
  flex: 1;
  min-width: 0;
}

/* Fixed width for font family */
.control-font {
  width: 200px;
  flex-shrink: 0;
}

/* Fixed width for color */
.control-color {
  width: 60px;
  flex-shrink: 0;
}

.control-color input[type="color"] {
  height: 42px;
  padding: 0.25rem;
}

/* Format buttons container */
.control-format {
  flex-shrink: 0;
}

.control-format .format-buttons {
  margin-top: 0.25rem;
}

/* Formatting Buttons */
.formatting-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-top: 1rem;
  padding: 0.75rem;
  background-color: white;
  border-radius: 4px;
  border: 1px solid #ddd;
}

.format-label {
  margin: 0;
  font-weight: 600;
  color: #555;
}

.format-buttons {
  display: flex;
  gap: 0.5rem;
}

.format-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: white;
  border: 2px solid #ccc;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1.1rem;
  font-weight: 600;
  transition: all 0.2s;
  color: #555;
}

.format-btn:hover:not(:disabled) {
  border-color: #999;
  background-color: #f5f5f5;
}

.format-btn.active {
  background-color: #0066cc;
  border-color: #0066cc;
  color: white;
}

.format-btn:active:not(:disabled) {
  transform: scale(0.95);
}

.format-btn:disabled,
.format-btn.disabled {
  opacity: 0.4;
  cursor: not-allowed;
  background-color: #f5f5f5;
  border-color: #ddd;
}

.format-btn strong,
.format-btn em,
.format-btn span {
  pointer-events: none;
}

/* Custom Fonts Section */
.upload-font {
  margin-bottom: 1rem;
}

.upload-font-btn {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  background-color: #6c757d;
  color: white;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 500;
  transition: background-color 0.2s;
}

.upload-font-btn:hover {
  background-color: #5a6268;
}

.upload-font-btn input[type="file"] {
  display: none;
}

.font-loading {
  padding: 0.75rem;
  background-color: #fff3cd;
  border-left: 4px solid #ffc107;
  border-radius: 4px;
  color: #856404;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.font-error {
  padding: 0.75rem;
  background-color: #f8d7da;
  border-left: 4px solid #dc3545;
  border-radius: 4px;
  color: #721c24;
  margin-bottom: 1rem;
}

.custom-fonts-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.custom-font-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem;
  background-color: white;
  border: 1px solid #ddd;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.custom-font-item:hover {
  background-color: #f8f9fa;
}

.custom-font-item span {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 500;
  color: #333;
}

.custom-font-item button {
  padding: 0.4rem 0.8rem;
  background-color: #dc3545;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
  transition: background-color 0.2s;
}

.custom-font-item button:hover {
  background-color: #c82333;
}

.no-fonts {
  padding: 1.5rem;
  text-align: center;
  background-color: #f8f9fa;
  border: 2px dashed #ddd;
  border-radius: 4px;
  color: #999;
  font-style: italic;
}
</style>
