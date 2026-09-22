/**
 * Dependency-free spreadsheet writers.
 *
 * The admin reporting suite needs real Excel output, not CSV renamed to .xlsx.
 * Rather than add a heavyweight dependency (exceljs is ~2MB with a large tree),
 * this writes the minimal valid OOXML package by hand: the spreadsheet parts
 * zipped with the built-in zlib.
 *
 * What this emits is a genuine .xlsx that Excel, Google Sheets and LibreOffice
 * open natively: a bold frozen header row, an autofilter, sized columns, and
 * numeric cells stored as real numbers (not strings), so sums and charts work
 * on open.
 *
 * Deliberate simplification: date cells are written as ISO-8601 text rather
 * than serial numbers. Serial dates bring the 1900 leap-year quirk and
 * timezone drift; ISO text round-trips unambiguously. Numbers — the values
 * that matter in financial reports — are always real numeric cells.
 */

const zlib = require('zlib');

// ── zip container ────────────────────────────────────────────────────────────

let CRC_TABLE = null;
function crcTable() {
  if (CRC_TABLE) return CRC_TABLE;
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  CRC_TABLE = table;
  return table;
}

function crc32(buf) {
  const table = crcTable();
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i += 1) c = table[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

/** DOS date/time pair used in zip local headers. */
function dosDateTime(date) {
  const d = date || new Date();
  const year = Math.max(1980, d.getFullYear());
  return {
    date: ((year - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate(),
    time: (d.getHours() << 11) | (d.getMinutes() << 5) | Math.floor(d.getSeconds() / 2),
  };
}

/**
 * Build a zip archive from {name, data} entries.
 *
 * Entries are deflated (method 8); the central directory is written at the end
 * as the spec requires.
 */
function buildZip(entries) {
  const { date, time } = dosDateTime();
  const locals = [];
  const central = [];
  let offset = 0;

  const flagUtf8 = 0x0800; // filenames are UTF-8

  for (const entry of entries) {
    const nameBuf = Buffer.from(entry.name, 'utf8');
    const data = Buffer.isBuffer(entry.data) ? entry.data : Buffer.from(entry.data, 'utf8');
    const deflated = zlib.deflateRawSync(data);
    const crc = crc32(data);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(flagUtf8, 6);
    local.writeUInt16LE(8, 8);
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(date, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(deflated.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);

    locals.push(local, nameBuf, deflated);

    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(0x02014b50, 0);
    cd.writeUInt16LE(20, 4);
    cd.writeUInt16LE(20, 6);
    cd.writeUInt16LE(flagUtf8, 8);
    cd.writeUInt16LE(8, 10);
    cd.writeUInt16LE(time, 12);
    cd.writeUInt16LE(date, 14);
    cd.writeUInt32LE(crc, 16);
    cd.writeUInt32LE(deflated.length, 20);
    cd.writeUInt32LE(data.length, 24);
    cd.writeUInt16LE(nameBuf.length, 28);
    cd.writeUInt16LE(0, 30); // extra len
    cd.writeUInt16LE(0, 32); // comment len
    cd.writeUInt16LE(0, 34); // disk number
    cd.writeUInt16LE(0, 36); // internal attrs
    cd.writeUInt32LE(0, 38); // external attrs
    cd.writeUInt32LE(offset, 42);

    central.push(cd, nameBuf);
    offset += local.length + nameBuf.length + deflated.length;
  }

  const centralBuf = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20);

  return Buffer.concat([...locals, centralBuf, end]);
}

// ── XML helpers ──────────────────────────────────────────────────────────────

function escapeXml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
    // Control characters are illegal in XML 1.0 and make Excel reject the file.
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, '');
}

/** A1-style column reference for a zero-based index. */
function colLetter(index) {
  let n = index;
  let out = '';
  do {
    out = String.fromCharCode(65 + (n % 26)) + out;
    n = Math.floor(n / 26) - 1;
  } while (n >= 0);
  return out;
}

/** Excel forbids []:*?/\ in sheet names and caps them at 31 chars. */
function safeSheetName(name) {
  const cleaned = String(name || 'Report').replace(/[[\]:*?/\\]/g, ' ').trim();
  return (cleaned || 'Report').slice(0, 31);
}

// Style indexes into styles.xml cellXfs.
const STYLE_DEFAULT = 0;
const STYLE_HEADER = 1;
const STYLE_NUMBER = 2;

/**
 * Render one spreadsheet worksheet.
 *
 * `columns` is [{ key, label, type }]; `rows` is an array of plain objects.
 * Numeric-typed columns become real numeric cells, everything else inline text.
 */
function sheetXml(columns, rows, sheetName) {
  const parts = [];
  parts.push('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
  parts.push(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
  );

  // Column widths: header label drives the width, clamped to a readable range.
  parts.push('<cols>');
  columns.forEach((col, i) => {
    const width = Math.min(40, Math.max(12, String(col.label || '').length + 6));
    parts.push(`<col min="${i + 1}" max="${i + 1}" width="${width}" customWidth="1"/>`);
  });
  parts.push('</cols>');

  parts.push('<sheetData>');

  // Header row.
  parts.push('<row r="1" s="0" customFormat="0" ht="18" customHeight="1">');
  columns.forEach((col, i) => {
    const ref = `${colLetter(i)}1`;
    parts.push(
      `<c r="${ref}" s="${STYLE_HEADER}" t="inlineStr"><is><t xml:space="preserve">${escapeXml(col.label)}</t></is></c>`,
    );
  });
  parts.push('</row>');

  // Data rows.
  rows.forEach((row, r) => {
    const rowNum = r + 2;
    parts.push(`<row r="${rowNum}">`);
    columns.forEach((col, i) => {
      const ref = `${colLetter(i)}${rowNum}`;
      const raw = row[col.key];
      if (raw === null || raw === undefined || raw === '') {
        parts.push(`<c r="${ref}" s="${STYLE_DEFAULT}"/>`);
        return;
      }
      if (col.type === 'number' || col.type === 'currency') {
        const num = Number(raw);
        if (Number.isFinite(num)) {
          parts.push(`<c r="${ref}" s="${STYLE_NUMBER}"><v>${num}</v></c>`);
          return;
        }
      }
      parts.push(
        `<c r="${ref}" s="${STYLE_DEFAULT}" t="inlineStr"><is><t xml:space="preserve">${escapeXml(raw)}</t></is></c>`,
      );
    });
    parts.push('</row>');
  });

  parts.push('</sheetData>');

  const lastCol = colLetter(Math.max(0, columns.length - 1));
  const lastRow = rows.length + 1;
  // Freeze the header and let the user filter/sort in place.
  parts.push('<autoFilter ref="A1:' + lastCol + lastRow + '"/>');
  parts.push('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>');

  parts.push('</worksheet>');
  return parts.join('');
}

const STYLES_XML =
  '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
  '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00"/></numFmts>' +
  '<fonts count="2">' +
  '<font><sz val="11"/><name val="Calibri"/></font>' +
  '<font><b/><sz val="11"/><name val="Calibri"/></font>' +
  '</fonts>' +
  '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>' +
  '<borders count="1"><border/></borders>' +
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
  '<cellXfs count="3">' +
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' +
  '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' +
  '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>' +
  '</cellXfs>' +
  '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' +
  '</styleSheet>';

/**
 * Build a single-sheet .xlsx workbook.
 *
 * @param {{sheetName?: string, columns: Array, rows: Array}} opts
 * @returns {Buffer}
 */
function toXlsx({ sheetName, columns, rows }) {
  const name = safeSheetName(sheetName);
  const contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    '</Types>';

  const rootRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '</Relationships>';

  const workbook =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
    `<sheets><sheet name="${escapeXml(name)}" sheetId="1" r:id="rId1"/></sheets>` +
    '</workbook>';

  const workbookRels =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
    '</Relationships>';

  return buildZip([
    { name: '[Content_Types].xml', data: contentTypes },
    { name: '_rels/.rels', data: rootRels },
    { name: 'xl/workbook.xml', data: workbook },
    { name: 'xl/_rels/workbook.xml.rels', data: workbookRels },
    { name: 'xl/styles.xml', data: STYLES_XML },
    { name: 'xl/worksheets/sheet1.xml', data: sheetXml(columns, rows, name) },
  ]);
}

// ── CSV ──────────────────────────────────────────────────────────────────────

function csvCell(value) {
  const s = value === null || value === undefined ? '' : String(value);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/**
 * CSV output using the same column spec as the xlsx writer.
 *
 * A UTF-8 BOM is prepended so Excel does not mangle the naira sign and other
 * non-ASCII characters on a double-click open.
 */
function toCsv({ columns, rows }) {
  const lines = [columns.map((c) => csvCell(c.label)).join(',')];
  for (const row of rows) {
    lines.push(columns.map((c) => csvCell(row[c.key])).join(','));
  }
  return '\ufeff' + lines.join('\r\n');
}

module.exports = {
  toXlsx,
  toCsv,
  buildZip,
  crc32,
  colLetter,
  escapeXml,
  safeSheetName,
  // exported so tests can assert on the generated XML without unzipping
  sheetXml,
};
