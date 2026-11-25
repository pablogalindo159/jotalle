<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entrar — Jotalle Transportes</title>
<link rel="icon" href="/img/logo.png">
<style>
  :root { --azul:#3d8bd4; --azul-esc:#2f74b8; --navy:#061a38; --navy2:#0a2a55; }
  * { box-sizing:border-box }
  body {
    margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center; padding:20px;
    font:16px/1.4 "Roboto", system-ui, -apple-system, "Segoe UI", sans-serif; color:#fff;
    background:
      radial-gradient(1200px 600px at 20% -10%, rgba(61,139,212,.35), transparent 60%),
      radial-gradient(900px 500px at 110% 110%, rgba(61,139,212,.25), transparent 60%),
      linear-gradient(160deg, var(--navy2), var(--navy));
  }
  .box { width:100%; max-width:400px; text-align:center }
  .logo { width:240px; max-width:80%; margin:0 auto 28px; display:block }
  .card {
    background:rgba(255,255,255,.06); border:1px solid rgba(255,255,255,.12); backdrop-filter:blur(8px);
    border-radius:18px; padding:28px 24px; text-align:left; box-shadow:0 20px 50px rgba(0,0,0,.35);
  }
  h1 { margin:0 0 4px; font-size:22px; color:var(--azul); font-weight:700; letter-spacing:.3px }
  p.sub { margin:0 0 20px; color:rgba(255,255,255,.7); font-size:14px }
  label { display:block; font-size:13px; margin:14px 0 6px; color:rgba(255,255,255,.85) }
  .campo { position:relative }
  input[type=email], input[type=password], input[type=text] {
    width:100%; padding:13px 14px; font-size:16px; color:#fff; background:rgba(0,0,0,.28);
    border:1px solid rgba(255,255,255,.18); border-radius:10px; outline:none; transition:.15s;
  }
  input:focus { border-color:var(--azul); box-shadow:0 0 0 3px rgba(61,139,212,.3) }
  .ver { position:absolute; right:6px; top:50%; transform:translateY(-50%); background:none; border:0; color:rgba(255,255,255,.7); cursor:pointer; padding:8px; font-size:13px }
  .lembrar { display:flex; align-items:center; gap:8px; margin:16px 0 4px; font-size:14px; color:rgba(255,255,255,.8) }
  button.entrar {
    width:100%; margin-top:18px; padding:14px; font-size:16px; font-weight:700; letter-spacing:.5px; cursor:pointer;
    color:#fff; background:linear-gradient(180deg, var(--azul), var(--azul-esc)); border:0; border-radius:10px; transition:.15s;
  }
  button.entrar:hover { filter:brightness(1.1) }
  .erro { margin-top:14px; padding:10px 12px; border-radius:8px; background:rgba(229,57,53,.18); border:1px solid rgba(229,57,53,.5); font-size:14px }
  footer { margin-top:22px; font-size:12px; color:rgba(255,255,255,.5) }
</style>
</head>
<body>
  <div class="box">
    <img class="logo" src="/img/logo.png" alt="Jotalle Transportes">
    <div class="card">
      <h1>Acesso restrito</h1>
      <p class="sub">Fotos e documentos da frota</p>

      <form method="post" action="{{ route('login.entrar') }}">
        @csrf
        <label for="usuario">Usuário</label>
        <input id="usuario" type="text" name="usuario" value="{{ old('usuario') }}" autocomplete="username" autocapitalize="none" autofocus required>

        <label for="senha">Senha</label>
        <div class="campo">
          <input id="senha" type="password" name="senha" autocomplete="current-password" required>
          <button class="ver" type="button" onclick="var i=document.getElementById('senha');var m=i.type==='password';i.type=m?'text':'password';this.textContent=m?'Ocultar':'Mostrar'">Mostrar</button>
        </div>

        @if ($errors->any())
          <div class="erro">{{ $errors->first() }}</div>
        @endif

        <button class="entrar" type="submit">ENTRAR</button>
      </form>
    </div>
    <footer>© {{ date('Y') }} Jotalle Transportes</footer>
  </div>
</body>
</html>
