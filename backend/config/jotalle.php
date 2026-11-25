<?php

return [
    'api_key' => env('APP_API_KEY'),
    'painel_user' => env('PAINEL_USER'),
    'painel_password' => env('PAINEL_PASSWORD'),
    // O painel mostra só os últimos N dias; registros mais antigos que M dias são apagados (arquivo + banco).
    'exibir_dias' => (int) env('RETENCAO_EXIBIR_DIAS', 30),
    'apagar_dias' => (int) env('RETENCAO_APAGAR_DIAS', 35),
];
