<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Jotalle — Fotos e Documentos</title>
<style>
  :root { --bg:#f4f5f7; --card:#fff; --txt:#1c1f24; --mut:#667085; --pri:#0b5cff; --bd:#e3e6eb; }
  * { box-sizing:border-box } body { margin:0; font:15px/1.4 system-ui,sans-serif; background:var(--bg); color:var(--txt) }
  header { background:#111827; color:#fff; padding:14px 20px; font-weight:600; font-size:18px }
  main { max-width:1200px; margin:0 auto; padding:16px }
  form { display:flex; flex-wrap:wrap; gap:10px; background:var(--card); padding:14px; border:1px solid var(--bd); border-radius:10px; margin-bottom:16px }
  label { display:flex; flex-direction:column; font-size:12px; color:var(--mut); gap:4px }
  input, select { padding:8px 10px; border:1px solid var(--bd); border-radius:8px; font-size:14px }
  button, .btn { background:var(--pri); color:#fff; border:0; padding:9px 16px; border-radius:8px; font-size:14px; cursor:pointer; text-decoration:none; align-self:flex-end }
  .btn.sec { background:#eef2ff; color:var(--pri) }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:14px }
  .card { background:var(--card); border:1px solid var(--bd); border-radius:10px; overflow:hidden; display:flex; flex-direction:column }
  .thumb { height:180px; background:#e5e7eb; display:flex; align-items:center; justify-content:center; overflow:hidden }
  .thumb img { width:100%; height:100%; object-fit:cover }
  .thumb span { font-size:42px }
  .info { padding:10px 12px; font-size:13px; flex:1 }
  .info b { font-size:15px }
  .tag { display:inline-block; font-size:11px; padding:2px 8px; border-radius:99px; background:#eef2ff; color:var(--pri); margin-bottom:6px }
  .tag.doc { background:#fef3c7; color:#92400e }
  .mut { color:var(--mut) }
  .acoes { display:flex; gap:8px; padding:0 12px 12px }
  .acoes .btn { flex:1; text-align:center; align-self:auto }
  nav { margin-top:18px } nav svg { height:18px }
</style>
</head>
<body>
<header>Jotalle — Fotos e Documentos</header>
<main>
  <form method="get">
    <label>Placa (cavalo ou carreta)<input name="placa" value="{{ request('placa') }}" placeholder="ABC1D23"></label>
    <label>Tipo
      <select name="tipo">
        <option value="">Todos</option>
        <option value="foto" @selected(request('tipo')==='foto')>Fotos</option>
        <option value="documento" @selected(request('tipo')==='documento')>Documentos (PDF)</option>
      </select>
    </label>
    <label>De<input type="date" name="de" value="{{ request('de') }}"></label>
    <label>Até<input type="date" name="ate" value="{{ request('ate') }}"></label>
    <label>Cidade<input name="cidade" value="{{ request('cidade') }}"></label>
    <button>Filtrar</button>
    <a class="btn sec" href="{{ route('painel') }}">Limpar</a>
  </form>

  <p class="mut">{{ $registros->total() }} registro(s)</p>

  <div class="grid">
    @forelse ($registros as $r)
      <div class="card">
        <a class="thumb" href="{{ route('registro.arquivo', $r) }}" target="_blank">
          @if ($r->tipo === 'foto')
            <img src="{{ route('registro.arquivo', $r) }}" loading="lazy" alt="">
          @else
            <span>📄</span>
          @endif
        </a>
        <div class="info">
          <span class="tag {{ $r->tipo === 'documento' ? 'doc' : '' }}">{{ $r->tipo === 'foto' ? 'Foto' : 'Documento' }}</span><br>
          @if ($r->placa_cavalo || $r->placa_carreta)
            <b>{{ $r->placa_cavalo }}</b>@if($r->placa_carreta) · carreta {{ $r->placa_carreta }}@endif<br>
          @endif
          {{ $r->tirado_em->format('d/m/Y H:i') }}<br>
          <span class="mut">
            {{ collect([$r->rua, $r->bairro, $r->cidade, $r->estado])->filter()->implode(', ') ?: 'Sem endereço' }}
          </span>
          @if ($r->latitude !== null)
            <br><a class="mut" target="_blank" href="https://www.google.com/maps?q={{ $r->latitude }},{{ $r->longitude }}">{{ number_format($r->latitude,5) }}, {{ number_format($r->longitude,5) }}</a>
          @endif
        </div>
        <div class="acoes">
          <a class="btn sec" href="{{ route('registro.arquivo', $r) }}" target="_blank">Abrir</a>
          <a class="btn" href="{{ route('registro.baixar', $r) }}">Baixar</a>
        </div>
      </div>
    @empty
      <p>Nenhum registro encontrado.</p>
    @endforelse
  </div>

  <nav>{{ $registros->links() }}</nav>
</main>
</body>
</html>
