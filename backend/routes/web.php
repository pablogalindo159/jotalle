<?php

use App\Http\Controllers\PainelController;
use Illuminate\Support\Facades\Route;

Route::middleware('painel')->group(function () {
    Route::get('/', [PainelController::class, 'index'])->name('painel');
    Route::get('/registros/{registro}/arquivo', [PainelController::class, 'arquivo'])->name('registro.arquivo');
    Route::get('/registros/{registro}/baixar', [PainelController::class, 'download'])->name('registro.baixar');
});
