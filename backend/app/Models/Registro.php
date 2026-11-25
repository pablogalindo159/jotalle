<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Registro extends Model
{
    protected $guarded = [];

    protected $casts = [
        'tirado_em' => 'datetime',
        'latitude' => 'float',
        'longitude' => 'float',
    ];

    public function getExtensaoAttribute(): string
    {
        return strtolower(pathinfo($this->arquivo, PATHINFO_EXTENSION)) ?: 'jpg';
    }

    /** Nome amigável para download: foto_ABC1D23_2026-11-24_2135.jpg */
    public function getNomeDownloadAttribute(): string
    {
        $partes = [$this->tipo, $this->placa_cavalo, $this->placa_carreta, $this->tirado_em->format('Y-m-d_Hi')];

        return implode('_', array_filter($partes)).'.'.$this->extensao;
    }
}
