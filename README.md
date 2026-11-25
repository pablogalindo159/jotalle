# Jotalle

Registro de fotos de caminhão (placa + carreta, data/hora, endereço, coordenadas, PIP de mapa e foto extra) e digitalização de documentos em PDF. App Android (Flutter) + API e painel web (Laravel).

- `backend/` — Laravel 13: `POST /api/registros` (upload) e painel em `/` com tela de login (filtrar, ver e baixar).
- `app/` — Flutter (Android).
- `deploy/` — Nginx e script de deploy.

## Backend (VPS Ubuntu, `jotalle.infosaojose.com.br`)
```bash
sudo apt install nginx php8.3-fpm php8.3-{cli,mbstring,xml,curl,sqlite3,zip} composer git
sudo git clone https://github.com/pablogalindo159/jotalle /var/www/jotalle
cd /var/www/jotalle
sudo bash deploy/deploy.sh          # 1ª vez cria o .env; edite PAINEL_USER/PAINEL_PASSWORD e rode de novo
sudo cp deploy/nginx-jotalle.conf /etc/nginx/sites-available/jotalle
sudo ln -s /etc/nginx/sites-available/jotalle /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d jotalle.infosaojose.com.br
```
No `php.ini` (fpm): `upload_max_filesize=40M` e `post_max_size=40M`.
Opcional: `APP_API_KEY` no `.env` exige o header `X-Api-Key` (informe a mesma chave em Configurações do app).

## App
```bash
cd app && ./setup.sh     # cria android/, aplica permissões, flutter pub get
flutter run              # ou: flutter build apk --release
```
URL padrão do servidor: `https://jotalle.infosaojose.com.br` (muda em Configurações do app).

## App web (iPhone/Android pelo navegador)
Abra `https://jotalle.infosaojose.com.br/app/` no Safari → Compartilhar → *Adicionar à Tela de Início*. Mesmas funções do app (foto carimbada, PDF de documento, fila offline); código em `backend/public/pwa/`.

## Como funciona
- **FOTO**: digita placa e carreta → foto principal → (opcional) foto extra → gera JPG com PLACA/CARRETA, dia da semana, data e hora, rua/bairro/cidade/estado e coordenadas (S/W). PIP no topo: esquerda = print do mapa (OpenStreetMap; Google opcional), direita = foto extra.
- **DIGITALIZAR**: scanner com recorte de bordas → PDF → abre no aparelho e vai ao servidor.
- **Offline**: tudo entra numa fila local e é enviado quando a internet volta (sem duplicar). Sem internet no momento da foto, o endereço e o mapa não são obtidos (só coordenadas do GPS).
