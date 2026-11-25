<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Retenção: apaga fotos/PDFs e registros com mais de RETENCAO_APAGAR_DIAS (35) dias, todo dia às 03:00.
Schedule::command('registros:limpar')->dailyAt('03:00')->withoutOverlapping();
