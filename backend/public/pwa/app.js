'use strict';
/* App web (PWA) Jotalle — foto carimbada + digitalização de documentos. Sem dependências. */

const $ = s => document.querySelector(s);
const pad = n => String(n).padStart(2, '0');
const limpaPlaca = s => (s || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
const DIAS = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];

/* ---------- navegação ---------- */
const views = ['home', 'foto', 'doc'];
function ir(id) { views.forEach(v => $('#' + v).classList.toggle('hidden', v !== id)); window.scrollTo(0, 0); }
document.querySelectorAll('[data-voltar]').forEach(b => b.onclick = () => ir('home'));
$('#goFoto').onclick = () => { limpaFormFoto(); ir('foto'); };
$('#goDoc').onclick = () => ir('doc');
/** Os 3 campos começam sempre vazios (nada é lembrado entre fotos). */
function limpaFormFoto() {
  ['#motorista', '#placa', '#carreta'].forEach(i => { $(i).value = ''; });
  msg($('#fMsg'), '');
}

function msg(el, texto, tipo) {
  el.className = 'msg' + (tipo ? ' ' + tipo : '');
  el.innerHTML = texto;
  el.classList.toggle('hidden', !texto);
}

/* ---------- fila offline (IndexedDB) ---------- */
const dbp = new Promise((res, rej) => {
  const r = indexedDB.open('jotalle', 1);
  r.onupgradeneeded = () => r.result.createObjectStore('fila', { keyPath: 'id' });
  r.onsuccess = () => res(r.result);
  r.onerror = () => rej(r.error);
});
const req = r => new Promise((res, rej) => { r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); });
const store = async m => (await dbp).transaction('fila', m).objectStore('fila');
const putItem = async i => req((await store('readwrite')).put(i));
const allItems = async () => req((await store('readonly')).getAll());
const delItem = async id => req((await store('readwrite')).delete(id));

/** Guarda na fila, tenta enviar e devolve { status: 'enviado' | 'pendente' | 'rejeitado', motivo }. */
async function enfileirar(meta, blob, nome) {
  await putItem({ id: meta.device_uuid, meta, nome, mime: blob.type, buf: await blob.arrayBuffer() });
  renderPend();
  await flush();
  if (rejeitados[meta.device_uuid]) return { status: 'rejeitado', motivo: rejeitados[meta.device_uuid] };
  const pend = (await allItems()).some(i => i.id === meta.device_uuid);
  return { status: pend ? 'pendente' : 'enviado', motivo: '' };
}

const rejeitados = {};   // id -> motivo (servidor recusou)
let fluxo = null;
function flush() {
  if (!navigator.onLine) return Promise.resolve(0);
  if (fluxo) return fluxo.then(() => flush());
  fluxo = (async () => {
    let ok = 0;
    for (const it of await allItems()) {
      const fd = new FormData();
      Object.entries(it.meta).forEach(([k, v]) => { if (v !== null && v !== undefined && v !== '') fd.append(k, v); });
      fd.append('arquivo', new Blob([it.buf], { type: it.mime }), it.nome);
      const h = { Accept: 'application/json' };
      const key = localStorage.getItem('apiKey');
      if (key) h['X-Api-Key'] = key;
      let r;
      try { r = await fetch('/api/registros', { method: 'POST', body: fd, headers: h }); } catch (e) { break; }
      if (r.ok) { await delItem(it.id); ok++; }
      else if (r.status === 422) {
        let m = 'dados inválidos';
        try { m = (await r.json()).message || m; } catch (e) { /* ignora */ }
        rejeitados[it.id] = m; await delItem(it.id);   // não trava a fila; o arquivo continua na tela para salvar
      } else break;
    }
    return ok;
  })().catch(() => 0).finally(() => { fluxo = null; renderPend(); });
  return fluxo;
}

async function renderPend() {
  const n = (await allItems()).length;
  const el = $('#pend');
  el.classList.toggle('hidden', n === 0);
  el.innerHTML = n ? `${n} pendente(s) <button id="envNow">Enviar agora</button>` : '';
  if (n) $('#envNow').onclick = async () => { el.textContent = 'Enviando…'; const k = await flush(); if (k === 0) renderPend(); };
}
addEventListener('online', flush);
document.addEventListener('visibilitychange', () => { if (!document.hidden) flush(); });

/* ---------- localização / endereço / mapa ---------- */
function getPos() {
  return new Promise((res, rej) => {
    if (!navigator.geolocation) return rej(new Error('Este aparelho não tem GPS.'));
    navigator.geolocation.getCurrentPosition(p => res(p.coords),
      e => rej(new Error(e.code === 1 ? 'Sem permissão de localização (Ajustes > Safari > Localização).' : 'Não foi possível obter a localização.')),
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
  });
}

async function fetchT(url, ms = 10000) {
  const c = new AbortController();
  const t = setTimeout(() => c.abort(), ms);
  try { return await fetch(url, { signal: c.signal }); } finally { clearTimeout(t); }
}

async function endOsm(lat, lng) {
  try {
    const r = await fetchT(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}&addressdetails=1&zoom=18&accept-language=pt-BR`);
    if (!r.ok) return null;
    const a = (await r.json()).address || {};
    const pri = (...ks) => { for (const k of ks) if (a[k]) return a[k]; return ''; };
    const iso = a['ISO3166-2-lvl4'] || '';
    return {
      rua: pri('road', 'pedestrian', 'highway'), numero: a.house_number || '',
      bairro: pri('suburb', 'neighbourhood', 'quarter', 'city_district'),
      cidade: pri('city', 'town', 'village', 'municipality'),
      estado: iso.includes('-') ? iso.split('-').pop() : (a.state || ''),
    };
  } catch (e) { return null; }
}

async function endGoogle(lat, lng) {
  const key = localStorage.getItem('googleKey');
  if (!key) return null;
  try {
    const r = await fetchT(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&language=pt-BR&key=${encodeURIComponent(key)}`);
    const comps = ((await r.json()).results || [])[0]?.address_components || [];
    const get = (t, curto) => { const c = comps.find(x => x.types.includes(t)); return c ? (curto ? c.short_name : c.long_name) : ''; };
    return {
      rua: get('route'), numero: get('street_number'),
      bairro: get('sublocality_level_1') || get('sublocality'),
      cidade: get('administrative_area_level_2'), estado: get('administrative_area_level_1', true),
    };
  } catch (e) { return null; }
}

/** Endereço com número da casa: OpenStreetMap primeiro; se faltar o número, tenta o Google (se houver chave). */
async function endereco(lat, lng) {
  let e = await endOsm(lat, lng);
  if (!e || !e.rua || !e.numero) {
    const g = await endGoogle(lat, lng);
    if (g && g.rua) e = !e || !e.rua ? g : { ...e, numero: e.numero || g.numero };
  }
  return e;
}

async function obterLocal() {
  const c = await getPos();
  const end = (navigator.onLine && await endereco(c.latitude, c.longitude)) || { rua: '', bairro: '', cidade: '', estado: '' };
  return { lat: c.latitude, lng: c.longitude, end };
}
const ruaNum = e => (e.rua && e.numero ? `${e.rua}, ${e.numero}` : e.rua || '');
const linhaEnd = e => [ruaNum(e), e.bairro, e.cidade, e.estado].filter(Boolean).join(', ');

function dms(v, pos, neg) {
  const h = v < 0 ? neg : pos, a = Math.abs(v), g = Math.floor(a), mf = (a - g) * 60, m = Math.floor(mf), s = (mf - m) * 60;
  return `${g}°${pad(m)}'${s.toFixed(1).padStart(4, '0')}"${h}`;
}

function carregaImg(url) {
  return new Promise((res, rej) => { const i = new Image(); i.crossOrigin = 'anonymous'; i.onload = () => res(i); i.onerror = rej; i.src = url; });
}

/** Print do mapa (OpenStreetMap, 3x3 tiles) 512x512 com marcador. Devolve canvas ou null. */
async function mapaCanvas(lat, lng) {
  const z = 17, n = 2 ** z;
  const x = (lng + 180) / 360 * n, lr = lat * Math.PI / 180;
  const y = (1 - Math.log(Math.tan(lr) + 1 / Math.cos(lr)) / Math.PI) / 2 * n;
  const tx = Math.floor(x), ty = Math.floor(y), fx = x - tx, fy = y - ty;
  const c = document.createElement('canvas'); c.width = c.height = 512;
  const g = c.getContext('2d');
  g.fillStyle = '#e5e3df'; g.fillRect(0, 0, 512, 512);
  const ox = 256 - (256 + fx * 256), oy = 256 - (256 + fy * 256);
  let ok = 0;
  const jobs = [];
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
    jobs.push(carregaImg(`https://tile.openstreetmap.org/${z}/${tx + dx}/${ty + dy}.png`)
      .then(im => { g.drawImage(im, ox + (dx + 1) * 256, oy + (dy + 1) * 256); ok++; }).catch(() => {}));
  }
  await Promise.race([Promise.all(jobs), new Promise(r => setTimeout(r, 12000))]);
  if (!ok) return null;
  g.fillStyle = '#fff'; g.beginPath(); g.arc(256, 256, 20, 0, 7); g.fill();
  g.fillStyle = '#e53935'; g.beginPath(); g.arc(256, 256, 14, 0, 7); g.fill();
  g.fillStyle = '#fff'; g.beginPath(); g.arc(256, 256, 5, 0, 7); g.fill();
  g.font = '16px sans-serif'; const t = '© OpenStreetMap', w = g.measureText(t).width;
  g.fillStyle = 'rgba(255,255,255,.8)'; g.fillRect(512 - w - 12, 512 - 24, w + 12, 24);
  g.fillStyle = '#222'; g.fillText(t, 512 - w - 6, 512 - 7);
  return c;
}

/* ---------- imagens ---------- */
/** Lê um arquivo de imagem (respeitando a rotação EXIF) e devolve um canvas com largura máxima maxW. */
async function lerImagem(file, maxW) {
  let src, w, h;
  try {
    src = await createImageBitmap(file, { imageOrientation: 'from-image' });
    w = src.width; h = src.height;
  } catch (e) {
    const url = URL.createObjectURL(file);
    src = await carregaImg(url); w = src.naturalWidth; h = src.naturalHeight;
    URL.revokeObjectURL(url);
  }
  const k = Math.min(1, maxW / Math.max(w, 1));
  const c = document.createElement('canvas');
  c.width = Math.round(w * k); c.height = Math.round(h * k);
  c.getContext('2d').drawImage(src, 0, 0, c.width, c.height);
  if (src.close) src.close();
  return c;
}

const paraBlob = (canvas, q = 0.88) => new Promise((res, rej) => canvas.toBlob(b => b ? res(b) : rej(new Error('Falha ao gerar imagem')), 'image/jpeg', q));

function quebra(g, texto, maxW, maxLinhas) {
  const palavras = texto.split(' '), linhas = [];
  let atual = '';
  for (const p of palavras) {
    const t = atual ? atual + ' ' + p : p;
    if (g.measureText(t).width > maxW && atual) { linhas.push(atual); atual = p; } else atual = t;
  }
  if (atual) linhas.push(atual);
  if (linhas.length > maxLinhas) { linhas.length = maxLinhas; linhas[maxLinhas - 1] += '…'; }
  return linhas;
}

function pip(g, im, x, y, lado, s) {
  const l = Math.min(im.width, im.height), sx = (im.width - l) / 2, sy = (im.height - l) / 2;
  g.fillStyle = '#fff'; g.fillRect(x - 5 * s, y - 5 * s, lado + 10 * s, lado + 10 * s);
  g.drawImage(im, sx, sy, l, l, x, y, lado, lado);
}

/** Desenha PLACA/CARRETA, dia/data/hora, endereço e coordenadas; PIPs no topo (mapa à esquerda, foto extra à direita). */
async function carimbar({ principal, extra, mapa, motorista, placa, carreta, quando, local }) {
  const base = await lerImagem(principal, 1600);
  const w = base.width, h = base.height, s = w / 1080, m = 24 * s;
  const g = base.getContext('2d');

  const lado = w * 0.30;
  if (mapa) pip(g, mapa, m, m, lado, s);
  if (extra) pip(g, await lerImagem(extra, 800), w - m - lado, m, lado, s);

  const fam = '-apple-system, "Helvetica Neue", Arial, sans-serif';
  const linhas = [];
  const add = (txt, tam, bold, maxL = 1) => {
    g.font = `${bold ? '800' : '500'} ${tam}px ${fam}`;
    quebra(g, txt, w - 2 * m, maxL).forEach(l => linhas.push({ l, tam, bold }));
  };
  add(`MOTORISTA: ${motorista}`, 50 * s, true);
  add(`PLACA CAVALO: ${placa}`, 50 * s, true);
  add(`PLACA CARRETA: ${carreta || '-'}`, 50 * s, true);
  add(`${DIAS[quando.getDay()]}, ${pad(quando.getDate())}/${pad(quando.getMonth() + 1)}/${quando.getFullYear()} ${pad(quando.getHours())}:${pad(quando.getMinutes())}:${pad(quando.getSeconds())}`, 36 * s, false);
  add(local && linhaEnd(local.end) ? linhaEnd(local.end) : 'Endereço indisponível', 34 * s, false, 2);
  add(local ? `${dms(local.lat, 'N', 'S')}  ${dms(local.lng, 'E', 'W')}` : 'Coordenadas indisponíveis', 34 * s, false);

  const gap = 8 * s;
  const alt = linhas.reduce((a, l) => a + l.tam * 1.15, 0) + gap * (linhas.length - 1);
  const faixa = alt + 2 * m * 0.8;
  g.fillStyle = 'rgba(0,0,0,.7)'; g.fillRect(0, h - faixa, w, faixa);
  g.fillStyle = '#fff'; g.textBaseline = 'top';
  let y = h - faixa + m * 0.8;
  for (const l of linhas) {
    g.font = `${l.bold ? '800' : '500'} ${l.tam}px ${fam}`;
    g.fillText(l.l, m, y);
    y += l.tam * 1.15 + gap;
  }
  return paraBlob(base, 0.88);
}

/* ---------- metadados ---------- */
const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16); }));
const isoLocal = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
function metaBase(tipo, motorista, placa, carreta, quando, local) {
  return {
    device_uuid: uuid(), tipo, motorista, placa_cavalo: placa, placa_carreta: carreta, tirado_em: isoLocal(quando),
    rua: local && ruaNum(local.end), bairro: local && local.end.bairro, cidade: local && local.end.cidade, estado: local && local.end.estado,
    endereco: local && linhaEnd(local.end), latitude: local && local.lat, longitude: local && local.lng,
  };
}

async function compartilhar(blob, nome, tipoMime) {
  const f = new File([blob], nome, { type: tipoMime });
  if (navigator.canShare && navigator.canShare({ files: [f] })) { await navigator.share({ files: [f] }); return true; }
  return false;
}

/* ---------- FOTO ---------- */
const F = { principal: null, extra: null, quando: null, fixP: null, resultado: null };

function atualizaSlot(slot, x, file) {
  slot.classList.toggle('tem', !!file);
  slot.style.backgroundImage = file ? `url(${URL.createObjectURL(file)})` : '';
  x.classList.toggle('hidden', !file);
  $('#fGerar').disabled = !F.principal;
}

function validaPlacas() {
  if ($('#motorista').value.trim().length < 3) { msg($('#fMsg'), 'Informe o nome do motorista.', 'erro'); return null; }
  const p = limpaPlaca($('#placa').value), c = limpaPlaca($('#carreta').value);
  if (p.length !== 7) { msg($('#fMsg'), 'A placa do caminhão precisa ter 7 caracteres.', 'erro'); return null; }
  if (c.length !== 7) { msg($('#fMsg'), 'A placa da carreta precisa ter 7 caracteres.', 'erro'); return null; }
  return { p, c };
}

$('#slotP').onclick = e => {
  if (e.target.id === 'xP') return;
  if (!validaPlacas()) return;
  msg($('#fMsg'), '');
  F.fixP = obterLocal(); F.fixP.catch(() => {});      // pede o GPS enquanto a câmera abre
  $('#inP').value = ''; $('#inP').click();
};
$('#slotE').onclick = e => { if (e.target.id === 'xE') return; $('#inE').value = ''; $('#inE').click(); };
$('#inP').onchange = e => {
  const f = e.target.files[0]; if (!f) return;
  F.principal = f; F.quando = new Date(); F.resultado = null;
  atualizaSlot($('#slotP'), $('#xP'), f);
  $('#fPrev').classList.add('hidden'); $('#fSalvar').classList.add('hidden');
};
$('#inE').onchange = e => { const f = e.target.files[0]; if (!f) return; F.extra = f; atualizaSlot($('#slotE'), $('#xE'), f); };
$('#xP').onclick = e => { e.stopPropagation(); F.principal = null; atualizaSlot($('#slotP'), $('#xP'), null); };
$('#xE').onclick = e => { e.stopPropagation(); F.extra = null; atualizaSlot($('#slotE'), $('#xE'), null); };

$('#fGerar').onclick = async () => {
  const pl = validaPlacas(); if (!pl || !F.principal) return;
  const motorista = $('#motorista').value.trim().toUpperCase();
  const btn = $('#fGerar'); btn.disabled = true;
  msg($('#fMsg'), '<span class="spin"></span>Gerando a foto…');
  $('#fPrev').classList.add('hidden'); $('#fSalvar').classList.add('hidden');
  try {
    let local = null, aviso = '';
    try { local = await F.fixP; } catch (e) { aviso = (e && e.message || 'Sem localização') + ' A foto sai sem localização.'; }
    const mapa = local && navigator.onLine ? await mapaCanvas(local.lat, local.lng) : null;
    const blob = await carimbar({ principal: F.principal, extra: F.extra, mapa, motorista, placa: pl.p, carreta: pl.c, quando: F.quando, local });
    const meta = metaBase('foto', motorista, pl.p, pl.c, F.quando, local);
    msg($('#fMsg'), '<span class="spin"></span>Enviando ao sistema…');
    const r = await enfileirar(meta, blob, `${meta.device_uuid}.jpg`);
    F.resultado = r.status === 'enviado' ? null : blob;
    if (r.status === 'enviado') {
      msg($('#fMsg'), '<b>✓ Enviado com sucesso!</b><br>A foto foi salva no servidor.' + (aviso ? '<br>' + aviso : ''), 'ok');
    } else {
      // não chegou ao servidor: mostra o motivo e oferece salvar no celular
      $('#fPrev').src = URL.createObjectURL(blob); $('#fPrev').classList.remove('hidden'); $('#fSalvar').classList.remove('hidden');
      msg($('#fMsg'), r.status === 'rejeitado'
        ? `<b>Não foi enviado.</b><br>O servidor recusou: ${r.motivo}. Salve no iPhone.`
        : '<b>Não foi enviado.</b><br>Sem conexão com o servidor. A foto ficou na fila e será enviada quando houver internet. Se quiser, salve no iPhone.', 'erro');
    }
    F.principal = F.extra = null;
    atualizaSlot($('#slotP'), $('#xP'), null); atualizaSlot($('#slotE'), $('#xE'), null);
  } catch (e) {
    msg($('#fMsg'), 'Erro: ' + (e && e.message || e), 'erro');
    btn.disabled = !F.principal;
  }
};
$('#fSalvar').onclick = async () => {
  if (!F.resultado) return;
  try { if (!await compartilhar(F.resultado, 'foto-jotalle.jpg', 'image/jpeg')) msg($('#fMsg'), 'Segure o dedo sobre a imagem e escolha "Adicionar às Fotos".'); }
  catch (e) { /* cancelado */ }
};

/* ---------- DOCUMENTO (PDF) ---------- */
const D = { paginas: [], pdf: null };

/** Realce de documento: tons de cinza + esticamento de contraste (parece digitalizado). */
function realcar(canvas) {
  const g = canvas.getContext('2d');
  const im = g.getImageData(0, 0, canvas.width, canvas.height), d = im.data;
  const hist = new Uint32Array(256);
  for (let i = 0; i < d.length; i += 4) { const v = (d[i] * 299 + d[i + 1] * 587 + d[i + 2] * 114) / 1000 | 0; d[i] = d[i + 1] = d[i + 2] = v; hist[v]++; }
  const tot = d.length / 4;
  let acc = 0, lo = 0, hi = 255;
  for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc > tot * 0.01) { lo = v; break; } }
  acc = 0;
  for (let v = 255; v >= 0; v--) { acc += hist[v]; if (acc > tot * 0.25) { hi = v; break; } } // papel claro vira branco
  const k = 255 / Math.max(hi - lo, 1);
  for (let i = 0; i < d.length; i += 4) { const v = Math.max(0, Math.min(255, (d[i] - lo) * k)); d[i] = d[i + 1] = d[i + 2] = v; }
  g.putImageData(im, 0, 0);
}

function renderPags() {
  $('#dPags').innerHTML = '';
  D.paginas.forEach((p, i) => {
    const im = document.createElement('img'); im.src = p.thumb; im.title = 'Toque para remover';
    im.onclick = () => { if (confirm(`Remover a página ${i + 1}?`)) { D.paginas.splice(i, 1); renderPags(); } };
    $('#dPags').appendChild(im);
  });
  $('#dGerar').disabled = !D.paginas.length;
}

$('#dAdd').onclick = () => { $('#inD').value = ''; $('#inD').click(); };
$('#inD').onchange = async e => {
  const f = e.target.files[0]; if (!f) return;
  msg($('#dMsg'), '<span class="spin"></span>Processando página…');
  try {
    const c = await lerImagem(f, 1800);
    if ($('#dPb').checked) realcar(c);
    const blob = await paraBlob(c, 0.85);
    D.paginas.push({ w: c.width, h: c.height, jpeg: new Uint8Array(await blob.arrayBuffer()), thumb: URL.createObjectURL(blob) });
    msg($('#dMsg'), `${D.paginas.length} página(s). Fotografe a próxima ou gere o PDF.`);
    renderPags();
  } catch (err) { msg($('#dMsg'), 'Erro: ' + (err && err.message || err), 'erro'); }
};

/** PDF mínimo (A4) com uma imagem JPEG por página. */
function montaPdf(paginas) {
  const enc = new TextEncoder(), partes = [], offs = [];
  let len = 0;
  const push = d => { const u = typeof d === 'string' ? enc.encode(d) : d; partes.push(u); len += u.length; };
  const obj = (n, corpo) => { offs[n] = len; push(`${n} 0 obj\n`); corpo(); push('\nendobj\n'); };
  const W = 595.28, H = 841.89, M = 18;
  const nObj = 2 + paginas.length * 3;

  push('%PDF-1.4\n');
  obj(1, () => push('<< /Type /Catalog /Pages 2 0 R >>'));
  obj(2, () => push(`<< /Type /Pages /Count ${paginas.length} /Kids [${paginas.map((_, i) => `${3 + i * 3} 0 R`).join(' ')}] >>`));
  paginas.forEach((p, i) => {
    const pg = 3 + i * 3, ct = pg + 1, im = pg + 2;
    const k = Math.min((W - 2 * M) / p.w, (H - 2 * M) / p.h), dw = p.w * k, dh = p.h * k, x = (W - dw) / 2, y = (H - dh) / 2;
    const cont = `q ${dw.toFixed(2)} 0 0 ${dh.toFixed(2)} ${x.toFixed(2)} ${y.toFixed(2)} cm /Im0 Do Q`;
    obj(pg, () => push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /XObject << /Im0 ${im} 0 R >> >> /Contents ${ct} 0 R >>`));
    obj(ct, () => push(`<< /Length ${cont.length} >>\nstream\n${cont}\nendstream`));
    obj(im, () => {
      push(`<< /Type /XObject /Subtype /Image /Width ${p.w} /Height ${p.h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${p.jpeg.length} >>\nstream\n`);
      push(p.jpeg); push('\nendstream');
    });
  });
  const xref = len;
  push(`xref\n0 ${nObj + 1}\n0000000000 65535 f \n`);
  for (let n = 1; n <= nObj; n++) push(`${String(offs[n]).padStart(10, '0')} 00000 n \n`);
  push(`trailer\n<< /Size ${nObj + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`);
  return new Blob(partes, { type: 'application/pdf' });
}

$('#dGerar').onclick = async () => {
  const btn = $('#dGerar'); btn.disabled = true;
  msg($('#dMsg'), '<span class="spin"></span>Gerando PDF…');
  try {
    const quando = new Date();
    let local = null;
    try { local = await obterLocal(); } catch (e) { /* segue sem localização */ }
    const placa = limpaPlaca($('#dPlaca').value);
    const pdf = montaPdf(D.paginas);
    const meta = metaBase('documento', $('#dMotorista').value.trim().toUpperCase(), placa, '', quando, local);
    const n = D.paginas.length;
    $('#dAbrir').classList.add('hidden'); $('#dComp').classList.add('hidden');
    msg($('#dMsg'), '<span class="spin"></span>Enviando ao sistema…');
    const r = await enfileirar(meta, pdf, `${meta.device_uuid}.pdf`);
    D.pdf = r.status === 'enviado' ? null : pdf;
    if (r.status === 'enviado') {
      msg($('#dMsg'), `<b>✓ Enviado com sucesso!</b><br>O PDF (${n} página(s)) foi salvo no servidor.`, 'ok');
    } else {
      // não chegou ao servidor: mostra o motivo e oferece abrir/salvar no celular
      const a = $('#dAbrir'); a.href = URL.createObjectURL(pdf); a.download = `documento-${quando.getTime()}.pdf`; a.classList.remove('hidden');
      $('#dComp').classList.remove('hidden');
      msg($('#dMsg'), r.status === 'rejeitado'
        ? `<b>Não foi enviado.</b><br>O servidor recusou: ${r.motivo}. Salve o PDF no iPhone.`
        : `<b>Não foi enviado.</b><br>Sem conexão com o servidor. O PDF (${n} página(s)) ficou na fila e será enviado quando houver internet. Se quiser, salve no iPhone.`, 'erro');
    }
    D.paginas = []; renderPags(); btn.disabled = true;
  } catch (e) {
    msg($('#dMsg'), 'Erro: ' + (e && e.message || e), 'erro'); btn.disabled = !D.paginas.length;
  }
};
$('#dComp').onclick = async () => {
  if (!D.pdf) return;
  try { if (!await compartilhar(D.pdf, 'documento-jotalle.pdf', 'application/pdf')) msg($('#dMsg'), 'Use "Abrir / baixar PDF".'); } catch (e) { /* cancelado */ }
};

/* ---------- início ---------- */
if ('serviceWorker' in navigator) navigator.serviceWorker.register('/app/sw.js', { scope: '/app/' }).catch(() => {});
renderPend();
flush();
