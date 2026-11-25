<?php

use App\Http\Controllers\Api\RegistroApiController;
use Illuminate\Support\Facades\Route;

Route::middleware(['api.key', 'throttle:120,1'])->group(function () {
    Route::get('/ping', fn () => ['ok' => true]);
    Route::post('/registros', [RegistroApiController::class, 'store']);
});
