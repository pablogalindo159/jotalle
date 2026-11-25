<?php

use App\Http\Controllers\LoginController;
use App\Http\Controllers\PainelController;
use Illuminate\Support\Facades\Route;

Route::get('/login', [LoginController::class, 'form'])->name('login');
Route::post('/login', [LoginController::class, 'entrar'])->middleware('throttle:8,1')->name('login.entrar');
Route::post('/sair', [LoginController::class, 'sair'])->name('sair');

Route::middleware('auth')->group(function () {
    Route::get('/', [PainelController::class, 'index'])->name('painel');
    Route::get('/registros/{registro}/arquivo', [PainelController::class, 'arquivo'])->name('registro.arquivo');
    Route::get('/registros/{registro}/baixar', [PainelController::class, 'download'])->name('registro.baixar');
});
