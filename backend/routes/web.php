<?php

use App\Http\Controllers\LoginController;
use App\Http\Controllers\PainelController;
use Illuminate\Support\Facades\Route;

// App web (PWA) para iPhone/Android: abre em /app/ (sem login, como o app)
Route::get('/app', fn () => response()->file(public_path('pwa/index.html'), ['Cache-Control' => 'no-cache']));
Route::get('/app/sw.js', fn () => response()->file(public_path('pwa/sw.js'), [
    'Content-Type' => 'application/javascript', 'Cache-Control' => 'no-cache',
]));

Route::get('/login', [LoginController::class, 'form'])->name('login');
Route::post('/login', [LoginController::class, 'entrar'])->middleware('throttle:8,1')->name('login.entrar');
Route::post('/sair', [LoginController::class, 'sair'])->name('sair');

Route::middleware('painel')->group(function () {
    Route::get('/', [PainelController::class, 'index'])->name('painel');
    Route::get('/registros/{registro}/arquivo', [PainelController::class, 'arquivo'])->name('registro.arquivo');
    Route::get('/registros/{registro}/baixar', [PainelController::class, 'download'])->name('registro.baixar');
    Route::delete('/registros/{registro}', [PainelController::class, 'excluir'])->name('registro.excluir');
});
