<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Registro;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class RegistroApiController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $d = $request->validate([
            'device_uuid' => 'required|uuid',
            'tipo' => 'required|in:foto,documento',
            'placa_cavalo' => 'nullable|string|max:10|required_if:tipo,foto',
            'placa_carreta' => 'nullable|string|max:10',
            'tirado_em' => 'required|date',
            'rua' => 'nullable|string|max:255',
            'bairro' => 'nullable|string|max:255',
            'cidade' => 'nullable|string|max:255',
            'estado' => 'nullable|string|max:40',
            'endereco' => 'nullable|string|max:1000',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'arquivo' => 'required|file|mimes:jpg,jpeg,png,pdf|max:30720',
        ]);

        // Reenvio da fila offline: devolve o que já existe, sem duplicar.
        if ($existente = Registro::where('device_uuid', $d['device_uuid'])->first()) {
            return response()->json(['id' => $existente->id, 'duplicado' => true]);
        }

        $arquivo = $request->file('arquivo');
        $tirado = Carbon::parse($d['tirado_em']);
        $ext = strtolower($arquivo->getClientOriginalExtension() ?: $arquivo->extension());
        $path = $arquivo->storeAs(
            'registros/'.$tirado->format('Y/m'),
            $d['device_uuid'].'.'.$ext,
            'local'
        );

        $registro = Registro::create([
            'device_uuid' => $d['device_uuid'],
            'tipo' => $d['tipo'],
            'placa_cavalo' => self::placa($d['placa_cavalo'] ?? null),
            'placa_carreta' => self::placa($d['placa_carreta'] ?? null),
            'tirado_em' => $tirado,
            'rua' => $d['rua'] ?? null,
            'bairro' => $d['bairro'] ?? null,
            'cidade' => $d['cidade'] ?? null,
            'estado' => $d['estado'] ?? null,
            'endereco' => $d['endereco'] ?? null,
            'latitude' => $d['latitude'] ?? null,
            'longitude' => $d['longitude'] ?? null,
            'arquivo' => $path,
            'mime' => $arquivo->getMimeType(),
            'tamanho' => $arquivo->getSize(),
        ]);

        return response()->json(['id' => $registro->id], 201);
    }

    private static function placa(?string $p): ?string
    {
        $p = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $p));

        return $p === '' ? null : $p;
    }
}
